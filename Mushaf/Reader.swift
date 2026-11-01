import SwiftData
import SwiftUI

struct ReaderView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @AppStorage("mushaf.theme") private var themeRaw = MushafTheme.auto.rawValue
    @AppStorage("mushaf.lastPage") private var lastPage = 1
    @AppStorage(NotebookSession.active) private var activeNotebookID = ""
    @AppStorage(NotebookSession.visible) private var visibleNotebookIDs = ""
    @AppStorage(NotebookSession.archived) private var archivedNotebookIDs = ""
    @Query(filter: #Predicate<Annotation> { $0.kind == "interlinear" }) private var writings: [Annotation]
    @Query(filter: #Predicate<Annotation> { $0.kind == "highlight" }) private var highlights: [Annotation]
    @State private var store = MushafStore()
    @State private var notebook: Notebook?
    @State private var page = ReaderView.initialPage
    @State private var interlinear = ReaderView.notesAtLaunch
    @State private var chrome = false
    @State private var showSurahs = false
    @State private var showNotebooks = ProcessInfo.processInfo.arguments.contains("-notebooks")
    @State private var findQuery = ""
    @State private var showJuz = false
    @State private var showTokens = false
    @State private var scrubbing = false
    @State private var scrub = Double(ReaderView.initialPage)
    private let screenshotLocked = ReaderView.locked

    private var theme: MushafTheme { Self.themeOverride ?? MushafTheme(rawValue: themeRaw) ?? .auto }
    private var palette: Palette { theme.palette(for: scheme) }

    var body: some View {
        Group {
            if ProcessInfo.processInfo.arguments.contains("-tokens") {
                TokenPreview()
            } else if let error = store.error {
                Text(error).font(MushafType.ui).foregroundStyle(palette.uiSecondary).padding(32)
            } else {
                reader
            }
        }
        .environment(\.palette, palette)
        .preferredColorScheme(theme.preferredScheme)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    private var reader: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                palette.desk.ignoresSafeArea()
                FingerPager(
                    index: pagerIndex(landscape),
                    count: landscape ? 302 : 604,
                    reduceMotion: reduceMotion,
                    page: { index in AnyView(spread(index, landscape: landscape, in: geo.size)) },
                    onIndex: { index in
                        page = landscape ? index * 2 + 1 : index + 1
                        if !scrubbing { scrub = Double(page) }
                    },
                    onTap: { chrome.toggle() }
                )
                .padding(.horizontal, landscape ? 16 : 28)
                .padding(.vertical, 76)
                if chrome {
                    VStack(spacing: 0) {
                        topBar(landscape)
                        Spacer()
                        scrubber
                    }
                    .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: chrome)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.45, dampingFraction: 0.85), value: interlinear)
        }
        .onChange(of: page) { _, new in
            if !screenshotLocked {
                lastPage = new
                notebook?.lastOpenedPage = new
            }
            if !scrubbing { scrub = Double(new) }
        }
        .onChange(of: archivedNotebookIDs) { _, _ in
            guard let notebook, NotebookSession.ids(archivedNotebookIDs).contains(notebook.id) else { return }
            self.notebook = nil
            prepareNotes()
        }
        .sheet(isPresented: $showSurahs, onDismiss: { findQuery = "" }) { surahSheet }
        .sheet(isPresented: $showNotebooks) {
            NotebookSwitcher(activeID: notebook?.id, currentPage: page, onOpen: { openNotebook($0) }, onJump: { book, destination in
                openNotebook(book)
                page = min(604, max(1, destination))
                showNotebooks = false
            })
        }
        .sheet(isPresented: $showJuz) { juzSheet }
        .sheet(isPresented: $showTokens) { TokenPreview() }
        .task { prepareNotes() }
    }

    private func spread(_ index: Int, landscape: Bool, in size: CGSize) -> some View {
        let numbers = landscape ? [index * 2 + 1, index * 2 + 2] : [index + 1]
        let pages = numbers.compactMap { store.page($0) }
        let fitted = pageSize(pages: pages.count, in: CGSize(width: size.width - (landscape ? 32 : 56), height: size.height - 152))
        return HStack(spacing: 18) {
            ForEach(pages) { item in
                pageFace(item, width: fitted.width, height: fitted.height)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pageFace(_ item: MushafPage, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if interlinear, let notebook {
                InterlinearPage(
                    page: item,
                    notebook: notebook,
                    notes: writings.filter { $0.page == item.number && $0.notebook?.id == notebook.id },
                    others: readLayers(on: item.number),
                    onSwitch: { activate($0) },
                    washes: wordWashes(on: item.number),
                    onWord: { toggleHighlight($0, on: item) },
                    typeLine: Self.typeAtLaunch ? 4 : nil
                )
            } else {
                MushafPageView(page: item, marks: marginMarks(on: item.number), washes: wordWashes(on: item.number), onWord: { toggleHighlight($0, on: item) })
            }
        }
        .frame(width: width, height: height)
    }

    private func readLayers(on page: Int) -> [ReadLayer] {
        let active = notebook?.id
        return NotebookSession.ids(visibleNotebookIDs).filter { $0 != active }.compactMap { id in
            let notes = writings.filter { $0.page == page && $0.notebook?.id == id && !Notes.layout(of: $0.layout).hidden }
            guard let book = notes.first?.notebook else { return nil }
            return ReadLayer(notebook: book, notes: notes)
        }
    }

    private func wordWashes(on page: Int) -> [WordWash] {
        let visible = Set(NotebookSession.ids(visibleNotebookIDs))
        return highlights.compactMap { note in
            guard note.page == page, let wordID = note.wordStart, let book = note.notebook, visible.contains(book.id) else { return nil }
            let hue = NotebookSession.hue(hex: book.colorHex).resolved(night: palette.isNight)
            return WordWash(wordID: wordID, color: hue.wash.uiColor.withAlphaComponent(hue.washOpacity))
        }
    }

    private func toggleHighlight(_ wordID: Int, on page: MushafPage) {
        prepareNotes()
        guard let notebook else { return }
        if let existing = highlights.first(where: { $0.page == page.number && $0.wordStart == wordID && $0.notebook?.id == notebook.id }) {
            context.delete(existing)
            return
        }
        guard let line = page.lines.first(where: { $0.words.contains { $0.id == wordID } }),
              let word = line.words.first(where: { $0.id == wordID }) else { return }
        let note = Annotation()
        note.notebook = notebook
        note.kind = "highlight"
        note.page = page.number
        note.line = line.number
        note.ayahStart = "\(word.surah):\(word.ayah)"
        note.ayahEnd = "\(word.surah):\(word.ayah)"
        note.wordStart = wordID
        note.wordEnd = wordID
        context.insert(note)
    }

    private func marginMarks(on page: Int) -> [PageMark] {
        let visible = Set(NotebookSession.ids(visibleNotebookIDs))
        var seen = Set<String>()
        return writings.compactMap { note in
            guard note.page == page, let line = note.line, let book = note.notebook, visible.contains(book.id) else { return nil }
            let key = "\(book.id.uuidString)-\(line)"
            guard seen.insert(key).inserted else { return nil }
            let hue = NotebookSession.hue(hex: book.colorHex).resolved(night: palette.isNight)
            return PageMark(id: key, line: line, color: hue.tint, label: "\(book.title), line \(line)")
        }
    }

    private func prepareNotes() {
        if notebook == nil {
            let archived = Set(NotebookSession.ids(archivedNotebookIDs))
            let books = (try? context.fetch(FetchDescriptor<Notebook>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
            let stored = UUID(uuidString: activeNotebookID)
            let chosen = books.first { $0.id == stored && !archived.contains($0.id) }
                ?? books.first { !archived.contains($0.id) }
                ?? Notebook()
            if chosen.modelContext == nil { context.insert(chosen) }
            notebook = chosen
            activeNotebookID = chosen.id.uuidString
            var visible = NotebookSession.ids(visibleNotebookIDs).filter { id in books.contains { $0.id == id } && !archived.contains(id) }
            if !visible.contains(chosen.id) { visible.insert(chosen.id, at: 0) }
            visibleNotebookIDs = NotebookSession.raw(Array(visible.prefix(3)))
        }
        guard let notebook else { return }
        if ProcessInfo.processInfo.arguments.contains("-notebooks") { seedClassNotebook() }
        if ProcessInfo.processInfo.arguments.contains("-highlight") { seedHighlight() }
        let existing = writings.first { $0.page == 1 && $0.line == 4 && $0.notebook?.id == notebook.id }
        if ProcessInfo.processInfo.arguments.contains("-sample-note"), existing == nil {
            let note = Annotation()
            note.notebook = notebook
            note.kind = "interlinear"
            note.page = 1
            note.line = 4
            note.ayahStart = "1:2"
            note.ayahEnd = "1:2"
            note.drawing = Notes.sampleDrawing()
            context.insert(note)
        }
        if Self.typeAtLaunch {
            let note = writings.first { $0.page == 1 && $0.line == 4 && $0.notebook?.id == notebook.id } ?? {
                let made = Annotation()
                made.notebook = notebook
                made.kind = "interlinear"
                made.page = 1
                made.line = 4
                made.ayahStart = "1:2"
                made.ayahEnd = "1:2"
                context.insert(made)
                return made
            }()
            if !Notes.hasText(note.text) {
                note.text = Notes.sampleText()
                note.updatedAt = Date()
            }
        }
    }

    private func pageSize(pages: Int, in available: CGSize) -> CGSize {
        let gap: CGFloat = pages > 1 ? 18 : 0
        let aspect: CGFloat = 1 / 1.62
        var width = (available.width - gap) / CGFloat(max(pages, 1))
        var height = width / aspect
        if height > available.height {
            height = available.height
            width = height * aspect
        }
        return CGSize(width: max(width, 1), height: max(height, 1))
    }

    private func pagerIndex(_ landscape: Bool) -> Int {
        landscape ? (page - 1) / 2 : page - 1
    }

    private func topBar(_ landscape: Bool) -> some View {
        let right = landscape ? ((page - 1) / 2) * 2 + 1 : page
        let label = landscape ? "\(right)–\(min(604, right + 1))" : "\(page)"
        let name = store.page(right)?.surahName ?? ""
        let juz = store.page(right)?.juz ?? 1
        return HStack(spacing: 8) {
            Button { showSurahs = true } label: {
                Text(name).lineLimit(1).truncationMode(.tail)
            }
            .frame(minHeight: 44)
            .layoutPriority(-1)
            Text("·").foregroundStyle(palette.uiSecondary)
            Button("Juz \(juz)") { showJuz = true }.font(MushafType.juz).frame(minHeight: 44).layoutPriority(1)
            Text("·").foregroundStyle(palette.uiSecondary)
            Text(label).font(MushafType.ui.monospacedDigit()).layoutPriority(1)
            Spacer(minLength: 8)
            Button { showSurahs = true } label: {
                Image(systemName: "magnifyingglass").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Find")
            Button { showNotebooks = true } label: {
                Image(systemName: "book.closed").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Notebooks")
            Button {
                prepareNotes()
                interlinear.toggle()
            } label: {
                Image(systemName: interlinear ? "pencil.line" : "pencil")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(interlinear ? "Close interlinear notes" : "Interlinear notes")
            Menu {
                ForEach(MushafTheme.allCases) { item in
                    Button(item.title) { themeRaw = item.rawValue }
                }
                Button("Colour tokens") { showTokens = true }
            } label: {
                Image(systemName: "circle.lefthalf.filled").frame(width: 44, height: 44)
            }
        }
        .font(MushafType.ui)
        .foregroundStyle(palette.uiInk)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Text("\(store.surahName(on: Int(scrub.rounded())))   \(Int(scrub.rounded()))")
                .font(MushafType.uiSmall)
                .foregroundStyle(palette.uiSecondary)
                .opacity(scrubbing ? 1 : 0)
            Slider(value: $scrub, in: 1...604, step: 1) { editing in
                scrubbing = editing
                if !editing { page = Int(scrub.rounded()) }
            }
            .tint(palette.accent)
            Canvas { context, size in
                for juz in 1...30 {
                    let start = store.juzPages[juz]
                    let x = (CGFloat(start) - 1) / 603 * size.width
                    let tick = CGRect(x: x, y: 0, width: 1, height: 8)
                    context.fill(Path(tick), with: .color(palette.uiSecondary.opacity(0.7)))
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var findQueryTrimmed: String {
        findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var findField: some View {
        TextField("Surah, page, or 2:255", text: $findQuery)
            .font(MushafType.ui)
            .foregroundStyle(palette.uiInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(palette.paper, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.uiSecondary.opacity(0.45), lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.go)
            .onSubmit {
                if let hit = store.search(findQuery).first { open(hit.page) }
            }
    }

    private func findLabel(_ hit: FindHit) -> some View {
        HStack {
            Text(hit.kind.rawValue)
                .font(MushafType.uiSmall)
                .foregroundStyle(palette.uiSecondary)
                .frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(hit.title).foregroundStyle(palette.uiInk)
                if !hit.detail.isEmpty {
                    Text(hit.detail)
                        .font(MushafType.uiSmall)
                        .foregroundStyle(palette.uiSecondary)
                }
            }
            Spacer()
            if hit.kind != .page {
                Text("\(hit.page)")
                    .font(MushafType.uiSmall.monospacedDigit())
                    .foregroundStyle(palette.uiSecondary)
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 20)
    }

    private var surahSheet: some View {
        let hits = store.search(findQuery)
        return NavigationStack {
            VStack(spacing: 0) {
                findField
                if !findQueryTrimmed.isEmpty && hits.isEmpty {
                    ContentUnavailableView.search(text: findQuery)
                } else {
                    List {
                        if findQueryTrimmed.isEmpty {
                            ForEach(store.surahs) { surah in
                                Button {
                                    open(surah.page)
                                } label: {
                                    HStack {
                                        Text("\(surah.id)")
                                            .font(MushafType.ui.monospacedDigit())
                                            .foregroundStyle(palette.uiSecondary)
                                            .frame(width: 32, alignment: .trailing)
                                        Text(surah.name).foregroundStyle(palette.uiInk)
                                        Spacer()
                                        Text("\(surah.page)")
                                            .font(MushafType.uiSmall.monospacedDigit())
                                            .foregroundStyle(palette.uiSecondary)
                                    }
                                    .frame(minHeight: 44)
                                }
                            }
                        } else {
                            ForEach(hits) { hit in
                                Button { open(hit.page) } label: { findLabel(hit).padding(.horizontal, -20) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Find")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func open(_ destination: Int) {
        page = destination
        showSurahs = false
        findQuery = ""
    }

    private func openNotebook(_ book: Notebook) {
        activate(book)
        page = min(604, max(1, book.lastOpenedPage))
        showNotebooks = false
    }

    private func activate(_ book: Notebook) {
        notebook = book
        activeNotebookID = book.id.uuidString
        var visible = NotebookSession.ids(visibleNotebookIDs).filter { $0 != book.id }
        visible.insert(book.id, at: 0)
        visibleNotebookIDs = NotebookSession.raw(Array(visible.prefix(3)))
    }

    private func seedHighlight() {
        guard let notebook, let page = store.page(1),
              let line = page.lines.first(where: { $0.kind == "ayah" }) else { return }
        for word in line.words where word.kind != "end" {
            guard !highlights.contains(where: { $0.wordStart == word.id && $0.notebook?.id == notebook.id }) else { continue }
            let note = Annotation()
            note.notebook = notebook
            note.kind = "highlight"
            note.page = 1
            note.line = line.number
            note.ayahStart = "\(word.surah):\(word.ayah)"
            note.ayahEnd = "\(word.surah):\(word.ayah)"
            note.wordStart = word.id
            note.wordEnd = word.id
            context.insert(note)
        }
    }

    private func seedClassNotebook() {
        let books = (try? context.fetch(FetchDescriptor<Notebook>())) ?? []
        let book = books.first { $0.title == "Sunday class" } ?? {
            let made = Notebook()
            made.title = "Sunday class"
            made.colorHex = "#4A5A9C"
            made.lastOpenedPage = 50
            context.insert(made)
            return made
        }()
        let note = (book.annotations ?? []).first { $0.page == 50 } ?? {
            let made = Annotation()
            made.notebook = book
            made.kind = "interlinear"
            made.page = 50
            made.line = 1
            made.ayahStart = "3:1"
            made.ayahEnd = "3:1"
            context.insert(made)
            return made
        }()
        if !Notes.hasText(note.text), !Notes.hasInk(note.drawing) {
            note.text = Notes.sampleText()
        }
        var visible = NotebookSession.ids(visibleNotebookIDs)
        if !visible.contains(book.id), visible.count < 3 {
            visible.append(book.id)
            visibleNotebookIDs = NotebookSession.raw(visible)
        }
    }

    private var juzSheet: some View {
        NavigationStack {
            List(1...30, id: \.self) { juz in
                Button {
                    page = store.juzPages[juz]
                    showJuz = false
                } label: {
                    HStack {
                        Text("Juz \(juz)").foregroundStyle(palette.uiInk)
                        Spacer()
                        Text("\(store.juzPages[juz])")
                            .font(MushafType.uiSmall.monospacedDigit())
                            .foregroundStyle(palette.uiSecondary)
                    }
                    .frame(minHeight: 44)
                }
            }
            .navigationTitle("Juz")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private static var initialPage: Int {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-page"), index + 1 < args.count, let number = Int(args[index + 1]) {
            return min(604, max(1, number))
        }
        let saved = UserDefaults.standard.integer(forKey: "mushaf.lastPage")
        return saved == 0 ? 1 : min(604, saved)
    }

    private static var themeOverride: MushafTheme? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-theme"), index + 1 < args.count else { return nil }
        return MushafTheme(rawValue: args[index + 1])
    }

    private static var locked: Bool {
        ProcessInfo.processInfo.arguments.contains("-page")
    }

    private static var notesAtLaunch: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-notes") || args.contains("-type")
    }

    private static var typeAtLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-type")
    }
}
