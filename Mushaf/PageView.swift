import SwiftUI
import UIKit

struct PageMark: Identifiable {
    var id: String
    var line: Int
    var color: Color
    var label: String
}

struct MushafPageView: View {
    var page: MushafPage
    var markedLines: Set<Int> = []
    var mark: Color = Color(hex: 0x2E7D6B)
    var marks: [PageMark] = []
    @Environment(\.palette) private var palette

    var body: some View {
        PageCanvas(page: page, palette: palette)
            .background(palette.paper)
            .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
            .overlay { markDots }
    }

    private var markDots: some View {
        GeometryReader { geo in
            let marginY = geo.size.height * 0.055
            let pitch = (geo.size.height - marginY * 2) / CGFloat(max(page.lines.count, 1))
            let rows = Dictionary(grouping: shownMarks, by: \.line)
            ForEach(page.lines) { line in
                let row = rows[line.number] ?? []
                let index = page.lines.firstIndex { $0.number == line.number } ?? 0
                ForEach(Array(row.enumerated()), id: \.element.id) { offset, item in
                    Circle()
                        .fill(item.color)
                        .frame(width: 4, height: 4)
                        .position(x: 14 + CGFloat(offset) * 8, y: marginY + (CGFloat(index) + 0.5) * pitch)
                        .accessibilityLabel(item.label)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var shownMarks: [PageMark] {
        if !marks.isEmpty { return marks }
        return markedLines.sorted().map { PageMark(id: "line-\($0)", line: $0, color: mark, label: "Note on line \($0)") }
    }
}

struct PageCanvas: UIViewRepresentable {
    var page: MushafPage
    var palette: Palette
    var line: Int? = nil

    func makeUIView(context: Context) -> PageDrawView {
        let view = PageDrawView()
        view.isOpaque = false
        view.backgroundColor = .clear
        view.contentMode = .redraw
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: PageDrawView, context: Context) {
        view.page = page
        view.palette = palette
        view.line = line
        view.hold(page.number)
        view.setNeedsDisplay()
    }
}

final class PageDrawView: UIView {
    var page: MushafPage?
    var palette: Palette = .paper
    var line: Int?
    private let qpc = QPCRenderer()
    private let uthmani = UthmaniRenderer()
    private var held: Int?
    private(set) var wordFrames: [WordFrame] = []

    func hold(_ page: Int?) {
        let next = window == nil ? nil : page
        guard held != next else { return }
        if let held { FontBook.shared.release(held) }
        if let next { FontBook.shared.retain(next) }
        held = next
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        hold(page?.number)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let page, let ctx = UIGraphicsGetCurrentContext() else { return }
        let marginX = bounds.width * 0.078
        let focused = line.flatMap { number in page.lines.firstIndex { $0.number == number } }
        let marginY = focused == nil ? bounds.height * 0.055 : 0
        let textWidth = bounds.width - marginX * 2
        let textHeight = bounds.height - (focused == nil ? bounds.height * 0.055 * 2 : 0)
        let count = max(page.lines.count, 1)
        let pitch = focused == nil ? textHeight / CGFloat(count) : bounds.height
        let renderer: MushafRendering = FontBook.shared.pageFont(page.number) == nil ? uthmani : qpc
        let fontSize = fittedSize(page, renderer: renderer, textWidth: textWidth)

        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textMatrix = .identity

        var frames: [WordFrame] = []
        var elements: [UIAccessibilityElement] = []
        for (index, line) in page.lines.enumerated() {
            if let focused, index != focused { continue }
            let top = focused == nil ? marginY + CGFloat(index) * pitch : 0
            let baseline = bounds.height - (top + pitch * 0.70)
            let slot = CGRect(x: marginX, y: top, width: textWidth, height: pitch)
            switch line.kind {
            case "surah_header":
                if let scalar = surahScalar(line.surah) {
                    drawPhrase(String(scalar), font: FontBook.shared.surahNames, slot: slot, baseline: baseline, widthRatio: 0.72, heightRatio: 0.96, in: ctx)
                }
            case "bismillah":
                drawPhrase("بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ", font: FontBook.shared.uthmanic, slot: slot, baseline: baseline, widthRatio: 0.58, heightRatio: 0.55, in: ctx)
            case "ayah":
                let natural = renderer.measure(line, fontSize: fontSize)
                let gaps = CGFloat(max(line.words.count - 1, 1))
                let extra = renderer.expandsToWidth && !line.centered ? max(0, textWidth - natural) / gaps : 0
                let used = natural + extra * CGFloat(max(line.words.count - 1, 0))
                let right = line.centered ? marginX + (textWidth + used) / 2 : marginX + textWidth
                let placed = renderer.draw(line, fontSize: fontSize, right: right, baseline: baseline, extraGap: extra, palette: palette, in: ctx)
                frames.append(contentsOf: placed.map { WordFrame(wordID: $0.wordID, rect: CGRect(x: $0.x, y: top, width: $0.width, height: pitch)) })
            default:
                break
            }
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = line.spoken
            element.accessibilityFrameInContainerSpace = slot
            elements.append(element)
        }
        ctx.restoreGState()
        wordFrames = frames
        accessibilityElements = elements
    }

    private func fittedSize(_ page: MushafPage, renderer: MushafRendering, textWidth: CGFloat) -> CGFloat {
        let trial: CGFloat = 48
        let widest = page.lines.filter { $0.kind == "ayah" }.map { renderer.measure($0, fontSize: trial) }.max() ?? 0
        guard widest > 1 else { return 24 }
        return trial * textWidth / widest
    }

    private func surahScalar(_ surah: Int?) -> UnicodeScalar? {
        guard let surah, let scalar = UnicodeScalar(0xE000 + surah) else { return nil }
        return scalar
    }

    private func drawPhrase(_ text: String, font cg: CGFont?, slot: CGRect, baseline: CGFloat, widthRatio: CGFloat, heightRatio: CGFloat, in ctx: CGContext) {
        guard let font = FontBook.shared.font(cg, size: 100) else { return }
        let width = GlyphRun.width(text, font)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
        CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        let height = max(ascent + descent, 1)
        let size = 100 * min(slot.width * widthRatio / max(width, 1), slot.height * heightRatio / height)
        guard let fitted = FontBook.shared.font(cg, size: size) else { return }
        let fittedWidth = GlyphRun.width(text, fitted)
        let x = slot.minX + (slot.width - fittedWidth) / 2
        let color = palette.quranInk.uiColor.cgColor
        GlyphRun.draw(text, font: fitted, color: color, at: CGPoint(x: x, y: baseline), in: ctx)
    }
}

struct WordFrame: Hashable {
    var wordID: Int
    var rect: CGRect
}
