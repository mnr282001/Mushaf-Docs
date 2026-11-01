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

    private static func surahs(_ db: OpaquePointer?) -> [SurahInfo] {
        var result: [SurahInfo] = []
        scan(db, "SELECT s.id, s.name_en, MIN(a.page) FROM src_surah s JOIN src_ayah a ON a.surah = s.id GROUP BY s.id ORDER BY s.id") { stmt in
            result.append(SurahInfo(id: Int(sqlite3_column_int(stmt, 0)), name: column(stmt, 1), page: Int(sqlite3_column_int(stmt, 2))))
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
