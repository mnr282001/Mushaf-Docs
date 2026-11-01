import PencilKit
import SwiftData
import SwiftUI

struct ReadLayer: Identifiable {
    var notebook: Notebook
    var notes: [Annotation]
    var id: UUID { notebook.id }
}

private struct LineRead: Identifiable {
    var note: Annotation
    var layer: ReadLayer
    var first: Bool
    var id: UUID { note.id }
}

struct InterlinearPage: View {
    var page: MushafPage
    var notebook: Notebook
    var notes: [Annotation]
    var others: [ReadLayer] = []
    var onSwitch: (Notebook) -> Void = { _ in }
    var washes: [WordWash] = []
    var onWord: (Int) -> Void = { _ in }
    var typeLine: Int? = nil
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var made: [Int: Annotation] = [:]
    @State private var keyboard: CGFloat = 0
    @State private var reveal = 0

    var body: some View {
        GeometryReader { geo in
            let closed = geo.size.width * 1.62
            let marginY = closed * 0.055
            let pitch = (closed - marginY * 2) / CGFloat(max(page.lines.count, 1))
            let hue = NotebookSession.hue(hex: notebook.colorHex).resolved(night: palette.isNight)
            let textWidth = geo.size.width * 0.844
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: marginY)
                    ForEach(page.lines) { line in
                        VStack(spacing: 0) {
                            PageCanvas(page: page, palette: palette, line: line.number, washes: washes, onWord: onWord)
                                .frame(height: pitch)
                                .accessibilityLabel(line.spoken)
                                .overlay(alignment: .trailing) {
                                    if !bandOpen(line.number) {
                                        addNote(line, hue: hue, margin: geo.size.width * 0.078) {
                                            if reduceMotion {
                                                proxy.scrollTo(line.id, anchor: .center)
                                            } else {
                                                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(line.id, anchor: .center) }
                                            }
                                        }
                                    }
                                }
                            if bandOpen(line.number) {
                                NoteBand(
                                    pitch: pitch,
                                    width: textWidth,
                                    margin: geo.size.width * 0.078,
                                    ink: hue.ink,
                                    tint: hue.tint,
                                    wash: hue.wash,
                                    washOpacity: hue.washOpacity,
                                    surface: palette.desk,
                                    paper: palette.paper,
                                    rule: hue.tint.opacity(0.28),
                                    drawing: note(line.number)?.drawing ?? Data(),
                                    text: note(line.number)?.text ?? Data(),
                                    manual: Notes.layout(of: note(line.number)?.layout).manual,
                                    startsTyping: line.number == typeLine,
                                    onDrawing: { setDrawing($0, line: line) },
                                    onText: { setText($0, line: line) },
                                    onManual: { setManual($0, line: line) },
                                    onHide: { setHidden(true, line: line.number) },
                                    onDelete: { remove(line.number) },
                                    onEdit: {
                                        if reduceMotion {
                                            proxy.scrollTo(line.id, anchor: .center)
                                        } else {
                                            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(line.id, anchor: .center) }
                                        }
                                    }
                                )
                                .padding(.top, 6)
                                .padding(.bottom, 12)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            ForEach(readNotes(on: line.number)) { item in
                                ReadOnlyNote(
                                    title: item.layer.notebook.title,
                                    showTitle: item.first,
                                    pitch: pitch,
                                    width: textWidth,
                                    margin: geo.size.width * 0.078,
                                    hue: NotebookSession.hue(hex: item.layer.notebook.colorHex).resolved(night: palette.isNight),
                                    surface: palette.desk,
                                    paper: palette.paper,
                                    drawing: item.note.drawing ?? Data(),
                                    text: item.note.text ?? Data(),
                                    manual: Notes.layout(of: item.note.layout).manual,
                                    onSwitch: { onSwitch(item.layer.notebook) }
                                )
                                .padding(.top, 6)
                                .padding(.bottom, 8)
                            }
                        }
                        .id(line.id)
                    }
                    Color.clear.frame(height: marginY + keyboard)
                }
            }
            }
            .scrollIndicators(.hidden)
            .background(palette.paper)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.45, dampingFraction: 0.85), value: notes.count)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.45, dampingFraction: 0.85), value: made.count)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.45, dampingFraction: 0.85), value: reveal)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.45, dampingFraction: 0.85), value: others.map(\.id))
        }
            .background(palette.paper)
            .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                      let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                keyboard = max(0, scene.screen.bounds.maxY - frame.minY)
            }
    }

    private func readNotes(on line: Int) -> [LineRead] {
        others.compactMap { layer in
            guard let note = layer.notes.first(where: { $0.line == line }) else { return nil }
            let first = layer.notes.compactMap(\.line).min() == line
            return LineRead(note: note, layer: layer, first: first)
        }
    }

    private func note(_ line: Int) -> Annotation? {
        made[line] ?? notes.first { $0.line == line }
    }

    private func bandOpen(_ line: Int) -> Bool {
        guard let item = note(line) else { return false }
        return !Notes.layout(of: item.layout).hidden
    }

    private func addNote(_ line: MushafLine, hue: NotebookHue, margin: CGFloat, scroll: @escaping () -> Void) -> some View {
        let hidden = note(line.number).map { Notes.layout(of: $0.layout).hidden } ?? false
        return Button {
            if hidden {
                setHidden(false, line: line.number)
            } else {
                setManual(Notes.starterHeight, line: line)
            }
            scroll()
        } label: {
            NoteTool(symbol: "plus", ink: hue.ink, plate: palette.paper, rule: hue.tint.opacity(0.35))
        }
        .buttonStyle(.plain)
        .padding(.trailing, max(0, (margin - 36) / 2))
        .accessibilityLabel(hidden ? "Show note on line \(line.number)" : "Add a note on line \(line.number)")
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
        guard item.modelContext != nil else { return }
        InkText.schedule(item)
    }

    private func setManual(_ manual: CGFloat?, line: MushafLine) {
        let item = ensure(line)
        var layout = Notes.layout(of: item.layout)
        layout.manual = manual.map(Double.init)
        item.layout = Notes.encoded(layout)
        item.updatedAt = Date()
        dropIfEmpty(item, line: line.number)
    }

    private func setText(_ data: Data, line: MushafLine) {
        let item = ensure(line)
        item.text = data
        item.updatedAt = Date()
        dropIfEmpty(item, line: line.number)
    }

    private func setHidden(_ hidden: Bool, line: Int) {
        guard let item = note(line) else { return }
        var layout = Notes.layout(of: item.layout)
        layout.hidden = hidden
        item.layout = Notes.encoded(layout)
        item.updatedAt = Date()
        reveal += 1
    }

    private func remove(_ line: Int) {
        guard let item = note(line) else { return }
        context.delete(item)
        made[line] = nil
        reveal += 1
    }

    private func dropIfEmpty(_ item: Annotation, line: Int) {
        let layout = Notes.layout(of: item.layout)
        guard !layout.hidden, !Notes.hasInk(item.drawing), !Notes.hasText(item.text), layout.manual == nil else { return }
        context.delete(item)
        made[line] = nil
    }
}

private struct ReadOnlyNote: View {
    var title: String
    var showTitle: Bool
    var pitch: CGFloat
    var width: CGFloat
    var margin: CGFloat
    var hue: NotebookHue
    var surface: Color
    var paper: Color
    var drawing: Data
    var text: Data
    var manual: Double?
    var onSwitch: () -> Void
    @State private var confirming = false

    private var height: CGFloat {
        Notes.bandHeight(pitch: pitch, drawing: drawing, text: text, width: width, manual: manual)
    }

    var body: some View {
        Button { confirming = true } label: {
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    RuledLines(spacing: Notes.rulePitch, color: hue.tint.opacity(0.28))
                    BandCanvas(drawingData: drawing, ink: hue.ink.uiColor, acceptsPencil: false, onChange: { _ in }, onBegin: {})
                    if let raw = Notes.attributed(text), !raw.string.isEmpty {
                        Text(AttributedString(raw))
                            .font(Font(Notes.noteFont))
                            .foregroundStyle(hue.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, showTitle ? 32 : 4)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .frame(height: height + (showTitle ? 28 : 0))
                .background { slip }
                .environment(\.layoutDirection, .rightToLeft)
                .opacity(0.55)
                if showTitle {
                    Text(title)
                        .font(MushafType.uiSmall)
                        .foregroundStyle(hue.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(paper, in: Capsule())
                        .overlay { Capsule().strokeBorder(hue.tint.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [2, 2])) }
                        .padding(8)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            .padding(.horizontal, margin)
            .environment(\.layoutDirection, .leftToRight)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Switch to \(title)?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Switch to \(title)") { onSwitch() }
            Button("Cancel", role: .cancel) {}
        }
        .accessibilityLabel("\(title), read only")
        .accessibilityHint("Switches to this notebook")
    }

    private var slip: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(surface)
            .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hue.wash.opacity(hue.washOpacity)) }
            .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(hue.tint.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3])) }
            .overlay(alignment: .leading) {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [2, 3]))
                    .foregroundStyle(hue.tint)
                    .frame(width: 4)
                    .padding(.vertical, 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct NoteBand: View {
    var pitch: CGFloat
    var width: CGFloat
    var margin: CGFloat
    var ink: Color
    var tint: Color
    var wash: Color
    var washOpacity: Double
    var surface: Color
    var paper: Color
    var rule: Color
    var drawing: Data
    var text: Data
    var manual: Double?
    var startsTyping = false
    var onDrawing: (Data) -> Void
    var onText: (Data) -> Void
    var onManual: (CGFloat?) -> Void
    var onHide: () -> Void
    var onDelete: () -> Void
    var onEdit: () -> Void
    @State private var dragStart: CGFloat?
    @State private var focused = false
    @State private var typing = false

    private var height: CGFloat { Notes.bandHeight(pitch: pitch, drawing: drawing, text: text, width: width, manual: manual) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                Color.clear.frame(width: margin)
                writing
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                Color.clear.frame(width: margin)
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .overlay(alignment: .topLeading) {
            toolbar
                .padding(.leading, margin + 8)
                .padding(.top, 6)
                .environment(\.layoutDirection, .leftToRight)
        }
        .overlay(alignment: .bottomLeading) {
            resizeHandle
                .padding(.leading, max(0, (margin - 36) / 2))
                .environment(\.layoutDirection, .leftToRight)
        }
        .onAppear {
            guard startsTyping else { return }
            focused = true
            typing = true
            onEdit()
        }
        .accessibilityElement(children: .contain)
    }

    private var writing: some View {
        ZStack(alignment: .topLeading) {
            RuledLines(spacing: Notes.rulePitch, color: rule)
            BandCanvas(drawingData: drawing, ink: ink.uiColor, acceptsPencil: !typing, onChange: onDrawing, onBegin: {
                focused = true
                typing = false
            })
            BandText(textData: text, ink: ink.uiColor, typing: typing, onChange: onText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background { slip }
        .environment(\.layoutDirection, .rightToLeft)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture { focused = true }
    }

    private var slip: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(surface)
            .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).fill(wash.opacity(washOpacity)) }
            .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(tint.opacity(0.55), lineWidth: 1) }
            .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 4) }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            Button(action: onHide) {
                NoteTool(symbol: "minus", ink: ink)
            }
            .accessibilityLabel("Hide note")
            hairline
            Button(action: onDelete) {
                NoteTool(symbol: "trash", ink: ink)
            }
            .accessibilityLabel("Delete note")
            if focused {
                hairline
                Button {
                    typing.toggle()
                    if typing { onEdit() }
                } label: {
                    NoteTool(symbol: typing ? "pencil.tip" : "keyboard", ink: ink)
                }
                .accessibilityLabel(typing ? "Pen" : "Keyboard")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 2)
        .background(paper, in: Capsule())
        .overlay { Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 0.5) }
    }

    private var hairline: some View {
        Rectangle().fill(tint.opacity(0.28)).frame(width: 0.5, height: 14)
    }

    private var resizeHandle: some View {
        NoteTool(symbol: "arrow.up.and.down", ink: ink, plate: paper, rule: tint.opacity(0.35))
            .contentShape(Rectangle())
            .gesture(resize)
            .onTapGesture(count: 2) { onManual(nil) }
            .accessibilityLabel("Resize note")
            .accessibilityHint("Drag to change the height. Double-tap to fit the writing.")
            .accessibilityAdjustableAction { direction in
                if direction == .increment {
                    onManual(height + Notes.rulePitch)
                } else {
                    onManual(max(pitch * 0.6, height - Notes.rulePitch))
                }
            }
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

private struct NoteTool: View {
    var symbol: String
    var ink: Color
    var plate: Color? = nil
    var rule: Color = .clear

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(ink)
            .frame(width: 36, height: 36)
            .background { if let plate { Circle().fill(plate) } }
            .overlay { Circle().strokeBorder(rule, lineWidth: plate == nil ? 0 : 0.5) }
            .contentShape(Circle())
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
    var acceptsPencil: Bool
    var onChange: (Data) -> Void
    var onBegin: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange, onBegin: onBegin) }

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
        context.coordinator.onBegin = onBegin
        canvas.isUserInteractionEnabled = acceptsPencil
        let current = canvas.drawing.dataRepresentation()
        guard current != drawingData else { return }
        canvas.drawing = (try? PKDrawing(data: drawingData)) ?? PKDrawing()
    }
}

private struct BandText: UIViewRepresentable {
    var textData: Data
    var ink: UIColor
    var typing: Bool
    var onChange: (Data) -> Void

    func makeCoordinator() -> TextCoordinator { TextCoordinator(onChange: onChange) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isScrollEnabled = false
        view.textAlignment = .natural
        view.font = Notes.noteFont
        view.textColor = ink
        view.textContainerInset = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 36)
        view.delegate = context.coordinator
        view.attributedText = Notes.attributed(textData) ?? NSAttributedString(string: "")
        view.font = Notes.noteFont
        view.textColor = ink
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.onChange = onChange
        let wasTyping = context.coordinator.typing
        context.coordinator.typing = typing
        view.isEditable = typing
        view.isUserInteractionEnabled = typing
        view.textColor = ink
        if !context.coordinator.editing {
            let next = Notes.attributed(textData) ?? NSAttributedString(string: "")
            if view.attributedText.string != next.string {
                view.attributedText = next
                view.font = Notes.noteFont
                view.textColor = ink
            }
        }
        if typing, !wasTyping { view.becomeFirstResponder() }
        if !typing, wasTyping { view.resignFirstResponder() }
    }
}

private final class TextCoordinator: NSObject, UITextViewDelegate {
    var onChange: (Data) -> Void
    var typing = false
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

@MainActor
private enum PencilShelf {
    static let picker = PKToolPicker()
}

private final class Coordinator: NSObject, PKCanvasViewDelegate {
    var onChange: (Data) -> Void
    var onBegin: () -> Void
    init(onChange: @escaping (Data) -> Void, onBegin: @escaping () -> Void) {
        self.onChange = onChange
        self.onBegin = onBegin
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        let data = canvasView.drawing.dataRepresentation()
        let change = onChange
        Task { @MainActor in change(data) }
    }

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        let begin = onBegin
        Task { @MainActor in begin() }
    }
}
