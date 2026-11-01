import CoreText
import UIKit

struct PlacedWord: Hashable {
    var wordID: Int
    var x: CGFloat
    var width: CGFloat
}

@MainActor
protocol MushafRendering: AnyObject {
    var expandsToWidth: Bool { get }
    func measure(_ line: MushafLine, fontSize: CGFloat) -> CGFloat
    func draw(_ line: MushafLine, fontSize: CGFloat, right: CGFloat, baseline: CGFloat, extraGap: CGFloat, palette: Palette, in ctx: CGContext) -> [PlacedWord]
}

@MainActor
final class FontBook {
    static let shared = FontBook()
    private var counts: [Int: Int] = [:]
    private var pages: [Int: CGFont] = [:]
    let uthmanic: CGFont?
    let surahNames: CGFont?
    let bismillah: CGFont?

    private init() {
        uthmanic = Self.load("UthmanicHafs1Ver18", "Fonts") ?? Self.load("UthmanicHafs1Ver18")
        surahNames = Self.load("surah-name-v2", "Fonts") ?? Self.load("surah-name-v2")
        bismillah = Self.load("bismillah", "Fonts") ?? Self.load("bismillah")
        for font in [uthmanic, surahNames, bismillah].compactMap({ $0 }) {
            CTFontManagerRegisterGraphicsFont(font, nil)
        }
    }

    func retain(_ page: Int) {
        for number in neighborhood(page) {
            counts[number, default: 0] += 1
            if pages[number] == nil, let font = Self.load("p\(number)", "Fonts") ?? Self.load("p\(number)") {
                CTFontManagerRegisterGraphicsFont(font, nil)
                pages[number] = font
            }
        }
    }

    func release(_ page: Int) {
        for number in neighborhood(page) {
            let next = (counts[number] ?? 1) - 1
            if next <= 0, let font = pages.removeValue(forKey: number) {
                counts[number] = nil
                CTFontManagerUnregisterGraphicsFont(font, nil)
            } else {
                counts[number] = next
            }
        }
    }

    func pageFont(_ page: Int) -> CGFont? { pages[page] }

    func font(_ cg: CGFont?, size: CGFloat) -> CTFont? {
        guard let cg else { return nil }
        return CTFontCreateWithGraphicsFont(cg, size, nil, nil)
    }

    private func neighborhood(_ page: Int) -> [Int] {
        [page - 1, page, page + 1].filter { (1...604).contains($0) }
    }

    private static func load(_ name: String, _ subdirectory: String? = nil) -> CGFont? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: subdirectory),
              let data = try? Data(contentsOf: url) as CFData,
              let provider = CGDataProvider(data: data)
        else { return nil }
        return CGFont(provider)
    }
}

enum GlyphRun {
    static func width(_ text: String, _ font: CTFont) -> CGFloat {
        let shown = text.filter { $0 != " " }
        guard !shown.isEmpty else { return 0 }
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(shown), attributes: [.font: font]))
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    static func draw(_ text: String, font: CTFont, color: CGColor, at point: CGPoint, in ctx: CGContext) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color]))
        ctx.textPosition = point
        CTLineDraw(line, ctx)
    }

    static func place(_ line: MushafLine, strings: [String], font: CTFont, right: CGFloat, baseline: CGFloat, extraGap: CGFloat, palette: Palette, in ctx: CGContext) -> [PlacedWord] {
        var cursor = right
        var placed: [PlacedWord] = []
        for (index, word) in line.words.enumerated() {
            let width = width(strings[index], font)
            cursor -= width
            let color = (word.kind == "end" ? palette.ayahMarker : palette.quranInk).uiColor.cgColor
            draw(strings[index].filter { $0 != " " }, font: font, color: color, at: CGPoint(x: cursor, y: baseline), in: ctx)
            placed.append(PlacedWord(wordID: word.id, x: cursor, width: width))
            if index < line.words.count - 1 { cursor -= extraGap }
        }
        return placed
    }
}

@MainActor
final class QPCRenderer: MushafRendering {
    let expandsToWidth = false

    func measure(_ line: MushafLine, fontSize: CGFloat) -> CGFloat {
        guard let font = FontBook.shared.font(FontBook.shared.pageFont(line.page), size: fontSize) else { return 0 }
        return line.words.reduce(0) { $0 + GlyphRun.width($1.code, font) }
    }

    func draw(_ line: MushafLine, fontSize: CGFloat, right: CGFloat, baseline: CGFloat, extraGap: CGFloat, palette: Palette, in ctx: CGContext) -> [PlacedWord] {
        guard let font = FontBook.shared.font(FontBook.shared.pageFont(line.page), size: fontSize) else { return [] }
        return GlyphRun.place(line, strings: line.words.map(\.code), font: font, right: right, baseline: baseline, extraGap: extraGap, palette: palette, in: ctx)
    }
}

@MainActor
final class UthmaniRenderer: MushafRendering {
    let expandsToWidth = true

    func measure(_ line: MushafLine, fontSize: CGFloat) -> CGFloat {
        guard let font = FontBook.shared.font(FontBook.shared.uthmanic, size: fontSize) else { return 0 }
        return line.words.reduce(0) { $0 + GlyphRun.width($1.text, font) }
    }

    func draw(_ line: MushafLine, fontSize: CGFloat, right: CGFloat, baseline: CGFloat, extraGap: CGFloat, palette: Palette, in ctx: CGContext) -> [PlacedWord] {
        guard let font = FontBook.shared.font(FontBook.shared.uthmanic, size: fontSize) else { return [] }
        return GlyphRun.place(line, strings: line.words.map(\.text), font: font, right: right, baseline: baseline, extraGap: extraGap, palette: palette, in: ctx)
    }
}
