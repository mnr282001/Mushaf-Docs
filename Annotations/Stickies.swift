import SwiftUI

struct StickyBoard: View {
    var notes: [Annotation]
    var hue: NotebookHue
    var paper: Color
    var ink: Color
    var room: CGFloat = 80
    var onMove: (Annotation, Double, Double, Bool) -> Void
    var onText: (Annotation, Data) -> Void
    var onDelete: (Annotation) -> Void

    private func cardSize(text: CGRect) -> CGSize {
        let side = min(200, max(120, text.minX + room - 16))
        return CGSize(width: side, height: side)
    }

    var body: some View {
        GeometryReader { geo in
            let text = textBlock(in: geo.size)
            let card = cardSize(text: text)
            ZStack(alignment: .topLeading) {
                ForEach(notes, id: \.id) { note in
                    sticky(note, page: geo.size, text: text, card: card)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .environment(\.layoutDirection, .leftToRight)
        .allowsHitTesting(true)
    }

    private func textBlock(in size: CGSize) -> CGRect {
        let x = size.width * 0.078
        let y = size.height * 0.055
        return CGRect(x: x, y: y, width: size.width - x * 2, height: size.height - y * 2)
    }

    private func origin(of note: Annotation, page: CGSize, text: CGRect, card: CGSize) -> CGPoint {
        let layout = Notes.layout(of: note.layout)
        let raw = CGPoint(x: CGFloat(layout.x ?? -0.04) * page.width, y: CGFloat(layout.y ?? 0.12) * page.height)
        return snap(raw, page: page, text: text, card: card)
    }

    private func snap(_ origin: CGPoint, page: CGSize, text: CGRect, card: CGSize) -> CGPoint {
        var rect = CGRect(origin: origin, size: card)
        let limit = max(0, room - 8)
        if rect.intersects(text) {
            let x = rect.midX < page.width / 2 ? text.minX - card.width - 8 : text.maxX + 8
            rect.origin.x = x
        }
        let x = min(max(rect.origin.x, -limit), page.width - 36)
        let y = min(max(rect.origin.y, 8), page.height - 48)
        return CGPoint(x: x, y: y)
    }

    @ViewBuilder
    private func sticky(_ note: Annotation, page: CGSize, text: CGRect, card: CGSize) -> some View {
        let layout = Notes.layout(of: note.layout)
        let place = origin(of: note, page: page, text: text, card: card)
        if layout.collapsed {
            Button {
                onMove(note, place.x / page.width, place.y / page.height, false)
            } label: {
                Circle().fill(hue.tint).frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
            .position(x: min(max(place.x + 6, 10), page.width - 10), y: min(max(place.y + 6, 10), page.height - 10))
            .accessibilityLabel("Expand sticky")
        } else {
            DraggableSticky(origin: place, page: page, text: text, card: card, snap: { snap($0, page: $1, text: $2, card: card) }) { next in
                onMove(note, next.x / page.width, next.y / page.height, false)
            } content: {
                StickyCard(note: note, hue: hue, paper: paper, ink: ink, onText: { onText(note, $0) }, onDelete: { onDelete(note) }, onCollapse: {
                    onMove(note, place.x / page.width, place.y / page.height, true)
                })
            }
        }
    }
}

private struct DraggableSticky<Content: View>: View {
    var origin: CGPoint
    var page: CGSize
    var text: CGRect
    var card: CGSize
    var snap: (CGPoint, CGSize, CGRect) -> CGPoint
    var onEnd: (CGPoint) -> Void
    @ViewBuilder var content: () -> Content
    @State private var drag: CGSize = .zero

    var body: some View {
        content()
            .frame(width: card.width, height: card.height)
            .position(x: origin.x + card.width / 2 + drag.width, y: origin.y + card.height / 2 + drag.height)
            .gesture(
                DragGesture()
                    .onChanged { drag = $0.translation }
                    .onEnded { value in
                        let next = snap(CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height), page, text)
                        drag = .zero
                        onEnd(next)
                    }
            )
    }
}

private struct StickyCard: View {
    var note: Annotation
    var hue: NotebookHue
    var paper: Color
    var ink: Color
    var onText: (Data) -> Void
    var onDelete: () -> Void
    var onCollapse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle().fill(hue.tint).frame(width: 8, height: 8)
                Spacer()
                Button(action: onCollapse) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Collapse sticky")
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete sticky")
            }
            StickyText(textData: note.text ?? Data(), ink: ink.uiColor, onChange: onText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(paper, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hue.wash.opacity(hue.washOpacity)) }
        .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(hue.tint.opacity(0.35), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}

private struct StickyText: UIViewRepresentable {
    var textData: Data
    var ink: UIColor
    var onChange: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.font = Notes.noteFont
        view.textColor = ink
        view.textContainerInset = .zero
        view.delegate = context.coordinator
        view.attributedText = Notes.attributed(textData) ?? NSAttributedString(string: "")
        view.font = Notes.noteFont
        view.textColor = ink
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.onChange = onChange
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
