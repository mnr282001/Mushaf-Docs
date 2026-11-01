import SwiftUI

struct SidebarColumn: View {
    var page: MushafPage
    var notes: [Annotation]
    var readOnly: [Annotation]
    var hue: NotebookHue
    var paper: Color
    var rule: Color
    var ink: Color
    var secondary: Color
    var leadsRight: Bool
    var onAdd: (Int) -> Void
    var onText: (Annotation, Data) -> Void
    var onDelete: (Annotation) -> Void

    var body: some View {
        GeometryReader { geo in
            let placed = frames(in: geo.size.height)
            ZStack(alignment: .topLeading) {
                leaders(placed, width: geo.size.width)
                ForEach(placed) { item in
                    card(item)
                        .frame(width: geo.size.width - 20, height: item.height)
                        .position(x: geo.size.width / 2, y: item.y + item.height / 2)
                }
                if notes.isEmpty && readOnly.isEmpty {
                    Text("No notes on this page.")
                        .font(MushafType.uiSmall)
                        .foregroundStyle(secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .overlay(alignment: .top) {
                Button {
                    onAdd(nextLine)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(hue.ink)
                .background(paper, in: Circle())
                .overlay { Circle().strokeBorder(hue.tint.opacity(0.35), lineWidth: 0.5) }
                .padding(.top, 8)
                .accessibilityLabel("Add a sidebar note")
            }
        }
    }

    private var nextLine: Int {
        let used = Set(notes.compactMap(\.line))
        return page.lines.first { $0.kind == "ayah" && !used.contains($0.number) }?.number
            ?? page.lines.first { $0.kind == "ayah" }?.number
            ?? 1
    }

    private func frames(in height: CGFloat) -> [SidebarFrame] {
        let marginY = height * 0.055
        let pitch = (height - marginY * 2) / CGFloat(max(page.lines.count, 1))
        let sorted = (notes + readOnly).sorted { ($0.line ?? 0) < ($1.line ?? 0) }
        var cursor: CGFloat = 52
        return sorted.map { note in
            let index = page.lines.firstIndex { $0.number == note.line } ?? 0
            let anchor = marginY + (CGFloat(index) + 0.5) * pitch
            let cardHeight = max(88, Notes.textHeight(note.text, width: 240) + 28)
            let y = max(anchor - 24, cursor)
            cursor = y + cardHeight + 8
            let editable = notes.contains { $0.id == note.id }
            return SidebarFrame(id: note.id, note: note, anchor: anchor, y: y, height: cardHeight, editable: editable)
        }
    }

    private func leaders(_ placed: [SidebarFrame], width: CGFloat) -> some View {
        Canvas { context, _ in
            let edge: CGFloat = leadsRight ? width - 1 : 1
            for item in placed {
                var path = Path()
                path.move(to: CGPoint(x: edge, y: item.anchor))
                path.addLine(to: CGPoint(x: edge, y: item.y + item.height / 2))
                path.addLine(to: CGPoint(x: leadsRight ? width - 8 : 8, y: item.y + item.height / 2))
                context.stroke(path, with: .color(hue.tint.opacity(0.7)), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }

    private func card(_ item: SidebarFrame) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !item.editable, let title = item.note.notebook?.title {
                Text(title)
                    .font(MushafType.uiSmall)
                    .foregroundStyle(secondary)
            }
            SidebarText(textData: item.note.text ?? Data(), ink: hue.ink.uiColor, editable: item.editable) {
                onText(item.note, $0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if item.editable {
                HStack {
                    Spacer()
                    Button { onDelete(item.note) } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(secondary)
                    .accessibilityLabel("Delete sidebar note")
                }
            }
        }
        .padding(10)
        .background(paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(rule, lineWidth: 0.5)
        }
        .overlay(alignment: leadsRight ? .trailing : .leading) {
            Rectangle().fill(hue.tint).frame(width: 2)
        }
        .opacity(item.editable ? 1 : 0.55)
    }
}

private struct SidebarFrame: Identifiable {
    var id: UUID
    var note: Annotation
    var anchor: CGFloat
    var y: CGFloat
    var height: CGFloat
    var editable: Bool
}

private struct SidebarText: UIViewRepresentable {
    var textData: Data
    var ink: UIColor
    var editable: Bool
    var onChange: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isScrollEnabled = false
        view.textAlignment = .natural
        view.font = Notes.noteFont
        view.textColor = ink
        view.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        view.delegate = context.coordinator
        view.attributedText = Notes.attributed(textData) ?? NSAttributedString(string: "")
        view.font = Notes.noteFont
        view.textColor = ink
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.onChange = onChange
        view.isEditable = editable
        view.textColor = ink
        guard !context.coordinator.editing else { return }
        let next = Notes.attributed(textData) ?? NSAttributedString(string: "")
        if view.attributedText.string != next.string {
            view.attributedText = next
            view.font = Notes.noteFont
            view.textColor = ink
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onChange: (Data) -> Void
        var editing = false
        init(onChange: @escaping (Data) -> Void) { self.onChange = onChange }

        func textViewDidChange(_ textView: UITextView) {
            editing = true
            let data = Notes.rtf(textView.attributedText ?? NSAttributedString(string: "")) ?? Data()
            let change = onChange
            Task { @MainActor in
                change(data)
                editing = false
            }
        }
    }
}
