import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum PageExport {
    static func pdf(pages: [MushafPage], notes: [Annotation], palette: Palette) -> Data {
        let pageSize = CGSize(width: 560, height: 560 * 1.62)
        let column: CGFloat = 188
        let media = CGSize(width: column + 16 + pageSize.width + 16, height: pageSize.height + 24)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: media))
        return renderer.pdfData { context in
            for page in pages {
                context.beginPage()
                let ctx = context.cgContext
                ctx.setFillColor(palette.desk.uiColor.cgColor)
                ctx.fill(CGRect(origin: .zero, size: media))
                let paper = CGRect(x: column + 16, y: 12, width: pageSize.width, height: pageSize.height)
                ctx.setFillColor(palette.paper.uiColor.cgColor)
                ctx.fill(paper)
                ctx.saveGState()
                ctx.translateBy(x: paper.minX, y: paper.minY)
                let view = PageDrawView()
                view.bounds = CGRect(origin: .zero, size: pageSize)
                view.page = page
                view.palette = palette
                view.washes = washes(on: page, notes: notes)
                view.draw(view.bounds)
                ctx.restoreGState()
                ctx.setStrokeColor(palette.uiSecondary.uiColor.withAlphaComponent(0.45).cgColor)
                ctx.setLineWidth(0.5)
                ctx.stroke(paper)
                drawNotes(notes.filter { $0.page == page.number }, in: CGRect(x: 12, y: 12, width: column - 8, height: pageSize.height), ink: palette.uiInk.uiColor)
            }
        }
    }

    private static func washes(on page: MushafPage, notes: [Annotation]) -> [WordWash] {
        notes.compactMap { note in
            guard note.page == page.number, note.kind == "highlight", let wordID = note.wordStart else { return nil }
            let hue = NotebookSession.hue(hex: note.notebook?.colorHex ?? "#2E7D6B").resolved(night: false)
            return WordWash(wordID: wordID, color: hue.wash.uiColor.withAlphaComponent(hue.washOpacity))
        }
    }

    private static func drawNotes(_ notes: [Annotation], in column: CGRect, ink: UIColor) {
        let font = UIFont.systemFont(ofSize: 11)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: ink,
            .paragraphStyle: paragraph,
        ]
        var y = column.minY
        for note in notes.sorted(by: { ($0.line ?? 0) < ($1.line ?? 0) }) {
            let body = Notes.attributed(note.text)?.string ?? note.recognizedText ?? ""
            let line = body.isEmpty ? note.kind : "\(note.kind) · \(body)"
            let text = line as NSString
            let bounds = text.boundingRect(with: CGSize(width: column.width, height: 80), options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
            guard y + bounds.height <= column.maxY else { break }
            text.draw(with: CGRect(x: column.minX, y: y, width: column.width, height: bounds.height), options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
            y += bounds.height + 8
        }
    }
}

struct NotePDF: Transferable {
    var data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { $0.data }
            .suggestedFileName("Mushaf notes.pdf")
    }
}
