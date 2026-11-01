import SwiftUI

enum AnchorLevel {
    case page, line, ayah, word
}

enum Placement {
    case belowLine, margin, overlay, floating, popover
}

struct KindSpec: Identifiable, Hashable {
    var id: String
    var displayName: String
    var anchors: Set<AnchorLevel>
    var placement: Placement
}

enum AnnotationRegistry {
    static let kinds: [KindSpec] = [
        KindSpec(id: "interlinear", displayName: "Interlinear", anchors: [.line, .ayah], placement: .belowLine),
        KindSpec(id: "sidebar", displayName: "Sidebar", anchors: [.line, .ayah], placement: .margin),
        KindSpec(id: "sticky", displayName: "Sticky", anchors: [.page], placement: .floating),
        KindSpec(id: "highlight", displayName: "Highlight", anchors: [.word], placement: .overlay),
        KindSpec(id: "dictionary", displayName: "Dictionary", anchors: [.word], placement: .popover),
    ]

    static func spec(for id: String) -> KindSpec? {
        kinds.first { $0.id == id }
    }

    static func knows(_ id: String) -> Bool {
        spec(for: id) != nil
    }
}

struct UnsupportedNotes: View {
    var notes: [Annotation]
    var paper: Color
    var ink: Color
    var page: CGSize
    var room: CGFloat

    var body: some View {
        let textX = page.width * 0.078
        let width = min(168, max(120, textX + room - 16))
        let originX = max(-(room - 8), textX - width - 8)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(notes, id: \.id) { note in
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.kind)
                        .font(.system(size: 13, weight: .medium))
                    Text("Unsupported note")
                        .font(.system(size: 11))
                }
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(paper, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(ink.opacity(0.28), lineWidth: 0.5)
                }
                .accessibilityLabel("Unsupported note, \(note.kind)")
            }
        }
        .frame(width: width, alignment: .leading)
        .position(x: originX + width / 2, y: page.height * 0.36)
    }
}
