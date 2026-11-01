import Foundation
import SQLite3

struct MushafWord: Identifiable, Hashable {
    var id: Int
    var idx: Int
    var surah: Int
    var ayah: Int
    var pos: Int
    var kind: String
    var text: String
    var code: String
}

struct MushafLine: Identifiable, Hashable {
    var page: Int
    var number: Int
    var kind: String
    var surah: Int?
    var centered: Bool
    var words: [MushafWord]
    var id: Int { page * 20 + number }

    var spoken: String {
        let arabic = words.map(\.text).joined(separator: " ")
        let ayah = words.first.map { "\($0.surah):\($0.ayah)" } ?? ""
        switch kind {
        case "surah_header": return "Surah header"
        case "bismillah": return "Bismillah"
        case "empty": return ""
        default: return "\(arabic), ayah \(ayah), line \(number)"
        }
    }
}

struct MushafPage: Identifiable, Hashable {
    var number: Int
    var juz: Int
    var hizb: Int
    var firstAyah: String
    var lastAyah: String
    var surahName: String
    var lines: [MushafLine]
    var id: Int { number }
    var opening: Bool { number <= 2 }
}

struct SurahInfo: Identifiable, Hashable {
    var id: Int
    var name: String
    var translit: String
    var arabic: String
    var page: Int
}

struct FindHit: Identifiable, Hashable {
    enum Kind: String { case page = "Page", surah = "Surah", ayah = "Ayah" }
    var id: String
    var kind: Kind
    var title: String
    var detail: String
    var page: Int
}

@MainActor
final class MushafStore {
    private var db: OpaquePointer?
    let surahs: [SurahInfo]
    let juzPages: [Int]
    let error: String?
    private var cache: [Int: MushafPage] = [:]

    init() {
        guard let url = Bundle.main.url(forResource: "mushaf", withExtension: "sqlite")
            ?? Bundle.main.url(forResource: "mushaf", withExtension: "sqlite", subdirectory: "Resources")
        else {
            surahs = []
            juzPages = Array(repeating: 1, count: 31)
            error = "Mushaf data is missing. Run scripts/build_mushaf.py."
            return
        }
        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            surahs = []
            juzPages = Array(repeating: 1, count: 31)
            error = "Could not open the mushaf database."
            return
        }
        error = nil
        surahs = Self.surahs(db)
        juzPages = Self.juzPages(db)
    }

    func page(_ number: Int) -> MushafPage? {
        let number = min(604, max(1, number))
        if let cached = cache[number] { return cached }
        guard let db else { return nil }
        guard let row = Self.one(db, "SELECT juz, hizb, first_ayah, last_ayah FROM page WHERE page = ?", number) else { return nil }
        var lines: [MushafLine] = []
        Self.scan(db, "SELECT line, kind, surah, centered FROM line WHERE page = ? ORDER BY line", number) { stmt in
            let surahType = sqlite3_column_type(stmt, 2)
            lines.append(MushafLine(
                page: number,
                number: Int(sqlite3_column_int(stmt, 0)),
                kind: Self.column(stmt, 1),
                surah: surahType == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 2)),
                centered: sqlite3_column_int(stmt, 3) != 0,
                words: []
            ))
        }
        var words: [Int: [MushafWord]] = [:]
        Self.scan(db, "SELECT id, line, idx, surah, ayah, pos, kind, text_uthmani, code_v2 FROM word WHERE page = ? ORDER BY line, idx", number) { stmt in
            let line = Int(sqlite3_column_int(stmt, 1))
            words[line, default: []].append(MushafWord(
                id: Int(sqlite3_column_int64(stmt, 0)),
                idx: Int(sqlite3_column_int(stmt, 2)),
                surah: Int(sqlite3_column_int(stmt, 3)),
                ayah: Int(sqlite3_column_int(stmt, 4)),
                pos: Int(sqlite3_column_int(stmt, 5)),
                kind: Self.column(stmt, 6),
                text: Self.column(stmt, 7),
                code: Self.column(stmt, 8)
            ))
        }
        for index in lines.indices {
            lines[index].words = words[lines[index].number] ?? []
        }
        let surahID = lines.first(where: { $0.surah != nil })?.surah ?? lines.flatMap(\.words).first?.surah ?? 1
        let name = surahs.first(where: { $0.id == surahID })?.name ?? ""
        let page = MushafPage(number: number, juz: row.0, hizb: row.1, firstAyah: row.2, lastAyah: row.3, surahName: name, lines: lines)
        cache[number] = page
        if cache.count > 12, let drop = cache.keys.first(where: { abs($0 - number) > 3 }) {
            cache.removeValue(forKey: drop)
        }
        return page
    }

    func surahName(on page: Int) -> String {
        self.page(page)?.surahName ?? ""
    }

    /// Empty query returns nothing; the sheet shows the full surah list instead.
    /// A bare number yields the page and, when it is 1...114, the surah. `2:255` and `2.255` yield that ayah's first page.
    func search(_ raw: String) -> [FindHit] {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        if query.wholeMatch(of: /(\d{1,3})\s*[:.]\s*(\d{1,3})/) != nil {
            return ayahHit(query).map { [$0] } ?? []
        }
        if let numbered = numberHits(query) { return numbered }
        return nameHits(query)
    }

    private func ayahHit(_ query: String) -> FindHit? {
        guard let match = query.wholeMatch(of: /(\d{1,3})\s*[:.]\s*(\d{1,3})/),
              let surah = Int(match.1), let ayah = Int(match.2),
              let page = page(surah: surah, ayah: ayah)
        else { return nil }
        let name = surahs.first { $0.id == surah }?.translit ?? ""
        return FindHit(id: "ayah-\(surah)-\(ayah)", kind: .ayah, title: "\(surah):\(ayah)", detail: name, page: page)
    }

    private func numberHits(_ query: String) -> [FindHit]? {
        let lowered = query.lowercased()
        if let match = lowered.wholeMatch(of: /(?:surah|sura)\s*(\d{1,3})/), let n = Int(match.1) {
            return surahHit(n).map { [$0] } ?? []
        }
        if let match = lowered.wholeMatch(of: /(?:page|p)\s*(\d{1,3})/), let n = Int(match.1) {
            return (1...604).contains(n) ? [pageHit(n)] : []
        }
        guard query.allSatisfy(\.isNumber), let n = Int(query) else { return nil }
        var hits: [FindHit] = []
        if (1...604).contains(n) { hits.append(pageHit(n)) }
        if let surah = surahHit(n) { hits.append(surah) }
        return hits
    }

    private func pageHit(_ page: Int) -> FindHit {
        FindHit(id: "page-\(page)", kind: .page, title: "Page \(page)", detail: "", page: page)
    }

    private func surahHit(_ id: Int) -> FindHit? {
        guard let surah = surahs.first(where: { $0.id == id }) else { return nil }
        return FindHit(id: "surah-\(surah.id)", kind: .surah, title: surah.translit, detail: surah.name, page: surah.page)
    }

    private func nameHits(_ query: String) -> [FindHit] {
        let needle = Self.letters(query)
        guard !needle.isEmpty else { return [] }
        return surahs.compactMap { surah -> (Bool, FindHit)? in
            let keys = Self.keys(surah.translit) + Self.keys(surah.name) + Self.keys(surah.arabic)
            guard keys.contains(where: { $0.contains(needle) }) else { return nil }
            let hit = FindHit(id: "surah-\(surah.id)", kind: .surah, title: surah.translit, detail: surah.name, page: surah.page)
            return (keys.contains { $0.hasPrefix(needle) }, hit)
        }
        .sorted { lhs, rhs in
            if lhs.0 != rhs.0 { return lhs.0 }
            return lhs.1.page < rhs.1.page
        }
        .map(\.1)
    }

    private func page(surah: Int, ayah: Int) -> Int? {
        guard let db else { return nil }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT MIN(page) FROM ayah_span WHERE surah = ? AND ayah = ?", -1, &stmt, nil) == SQLITE_OK, let stmt else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(surah))
        sqlite3_bind_int(stmt, 2, Int32(ayah))
        guard sqlite3_step(stmt) == SQLITE_ROW, sqlite3_column_type(stmt, 0) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private static func letters(_ raw: String) -> String {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en"))
        var out = ""
        for scalar in folded.unicodeScalars {
            guard CharacterSet.letters.contains(scalar) else { continue }
            switch scalar {
            case "أ", "إ", "آ", "ٱ": out.unicodeScalars.append("ا")
            case "ى": out.unicodeScalars.append("ي")
            case "ة": out.unicodeScalars.append("ه")
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out.lowercased()
    }

    private static func keys(_ raw: String) -> [String] {
        let flat = letters(raw)
        guard !flat.isEmpty else { return [] }
        var out = [flat]
        for prefix in ["al", "ar", "an", "at", "as", "ad"] where flat.hasPrefix(prefix) && flat.count > prefix.count + 1 {
            out.append(String(flat.dropFirst(prefix.count)))
        }
        if flat.hasPrefix("ال"), flat.count > 2 {
            out.append(String(flat.dropFirst(2)))
        }
        return out
    }

    private static func surahs(_ db: OpaquePointer?) -> [SurahInfo] {
        var result: [SurahInfo] = []
        scan(db, "SELECT s.id, s.name_en, s.name_translit, s.name_ar, MIN(a.page) FROM src_surah s JOIN src_ayah a ON a.surah = s.id GROUP BY s.id ORDER BY s.id") { stmt in
            result.append(SurahInfo(
                id: Int(sqlite3_column_int(stmt, 0)),
                name: column(stmt, 1),
                translit: column(stmt, 2),
                arabic: column(stmt, 3),
                page: Int(sqlite3_column_int(stmt, 4))
            ))
        }
        return result
    }

    private static func juzPages(_ db: OpaquePointer?) -> [Int] {
        var pages = Array(repeating: 1, count: 31)
        scan(db, "SELECT juz, MIN(page) FROM src_ayah GROUP BY juz") { stmt in
            let juz = Int(sqlite3_column_int(stmt, 0))
            if (1...30).contains(juz) { pages[juz] = Int(sqlite3_column_int(stmt, 1)) }
        }
        return pages
    }

    private static func one(_ db: OpaquePointer?, _ sql: String, _ page: Int) -> (Int, Int, String, String)? {
        var found: (Int, Int, String, String)?
        scan(db, sql, page) { stmt in
            found = (Int(sqlite3_column_int(stmt, 0)), Int(sqlite3_column_int(stmt, 1)), column(stmt, 2), column(stmt, 3))
        }
        return found
    }

    private static func scan(_ db: OpaquePointer?, _ sql: String, _ page: Int? = nil, _ body: (OpaquePointer) -> Void) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return }
        defer { sqlite3_finalize(stmt) }
        if let page { sqlite3_bind_int(stmt, 1, Int32(page)) }
        while sqlite3_step(stmt) == SQLITE_ROW { body(stmt) }
    }

    private static func column(_ stmt: OpaquePointer, _ index: Int32) -> String {
        guard let raw = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: raw)
    }
}
