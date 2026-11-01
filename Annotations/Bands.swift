import PencilKit
import SwiftData
import SwiftUI

struct InterlinearPage: View {
    var page: MushafPage
    var notebook: Notebook
    var notes: [Annotation]
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var made: [Int: Annotation] = [:]

    var body: some View {
        GeometryReader { geo in
            let closed = geo.size.width * 1.62
            let marginY = closed * 0.055
            let pitch = (closed - marginY * 2) / CGFloat(max(page.lines.count, 1))
            let hue = (NotebookHue.all.first { $0.name == "Teal" } ?? NotebookHue.all[0]).resolved(night: palette.isNight)
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: marginY)
                    ForEach(page.lines) { line in
                        PageCanvas(page: page, palette: palette, line: line.number)
                            .frame(height: pitch)
                            .accessibilityLabel(line.spoken)
                        NoteBand(
                            pitch: pitch,
                            ink: hue.ink,
                            tint: hue.tint,
                            rule: palette.rule,
                            drawing: note(line.number)?.drawing ?? Data(),
                            manual: Notes.layout(of: note(line.number)?.layout).manual,
                            onDrawing: { setDrawing($0, line: line) },
                            onManual: { setManual($0, line: line) }
                        )
                        .padding(.horizontal, geo.size.width * 0.078)
                        .transition(.opacity)
                    }
                    Color.clear.frame(height: marginY)
                }
            }
            .scrollIndicators(.hidden)
            .background(palette.paper)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.45, dampingFraction: 0.85), value: notes.count)
        }
        .background(palette.paper)
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
    }

    private func note(_ line: Int) -> Annotation? {
        made[line] ?? notes.first { $0.line == line }
    }

    private func ensure(_ line: MushafLine) -> Annotation {
        if let existing = note(line.number) { return existing }
        let madeNote = Annotation()
        madeNote.notebook = notebook
        madeNote.kind = "interlinear"
        madeNote.page = page.number
        madeNote.line = line.number
        if let first = line.words.first, let last = line.words.last {
            madeNote.ayahStart = "\(first.surah):\(first.ayah)"
            madeNote.ayahEnd = "\(last.surah):\(last.ayah)"
            madeNote.wordStart = first.pos
            madeNote.wordEnd = last.pos
        }
        context.insert(madeNote)
        made[line.number] = madeNote
        return madeNote
    }

    private func setDrawing(_ data: Data, line: MushafLine) {
        let item = ensure(line)
        item.drawing = data
        item.updatedAt = Date()
        dropIfEmpty(item, line: line.number)
    }

    private func setManual(_ manual: CGFloat?, line: MushafLine) {
        let item = ensure(line)
        var layout = Notes.layout(of: item.layout)
        layout.manual = manual.map(Double.init)
        item.layout = Notes.encoded(layout)
        item.updatedAt = Date()
        dropIfEmpty(item, line: line.number)
    }

    private func dropIfEmpty(_ item: Annotation, line: Int) {
        guard !Notes.hasInk(item.drawing), Notes.layout(of: item.layout).manual == nil else { return }
        context.delete(item)
        made[line] = nil
    }
}

struct NoteBand: View {
    var pitch: CGFloat
    var ink: Color
    var tint: Color
    var rule: Color
    var drawing: Data
    var manual: Double?
    var onDrawing: (Data) -> Void
    var onManual: (CGFloat?) -> Void
    @State private var dragStart: CGFloat?

    private var height: CGFloat { Notes.bandHeight(pitch: pitch, drawing: drawing, manual: manual) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RuledLines(spacing: Notes.rulePitch, color: rule)
            BandCanvas(drawingData: drawing, ink: ink.uiColor, onChange: onDrawing)
            Rectangle().fill(tint).frame(width: 1)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onManual(height + Notes.rulePitch)
                    } label: {
                        Image(systemName: "plus")
                            .font(MushafType.ui)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ink)
                    .accessibilityLabel("Add a ruled line")
                }
                Spacer()
                Capsule()
                    .fill(tint.opacity(0.7))
                    .frame(width: 36, height: 5)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .contentShape(Rectangle())
                    .gesture(resize)
                    .onTapGesture(count: 2) { onManual(nil) }
                    .accessibilityLabel("Resize note")
                    .accessibilityHint("Drag to make the band taller. Double-tap to fit the writing.")
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .contain)
    }

    private var resize: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragStart == nil { dragStart = height }
                onManual(max(pitch * 0.6, (dragStart ?? height) + value.translation.height))
            }
            .onEnded { _ in dragStart = nil }
    }
}

private struct RuledLines: View {
    var spacing: CGFloat
    var color: Color

    var body: some View {
        Canvas { context, size in
            var y = spacing
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 8, y: y))
                path.addLine(to: CGPoint(x: size.width - 8, y: y))
                context.stroke(path, with: .color(color), lineWidth: 0.5)
                y += spacing
            }
        }
    }
}

private struct BandCanvas: UIViewRepresentable {
    var drawingData: Data
    var ink: UIColor
    var onChange: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .pencilOnly
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: ink, width: 2.5)
        canvas.delegate = context.coordinator
        canvas.drawing = (try? PKDrawing(data: drawingData)) ?? PKDrawing()
        PencilShelf.picker.addObserver(canvas)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.onChange = onChange
        let current = canvas.drawing.dataRepresentation()
        guard current != drawingData else { return }
        canvas.drawing = (try? PKDrawing(data: drawingData)) ?? PKDrawing()
    }
}

@MainActor
private enum PencilShelf {
    static let picker = PKToolPicker()
}

private final class Coordinator: NSObject, PKCanvasViewDelegate {
    var onChange: (Data) -> Void
    init(onChange: @escaping (Data) -> Void) { self.onChange = onChange }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        let data = canvasView.drawing.dataRepresentation()
        let change = onChange
        Task { @MainActor in change(data) }
    }
}
