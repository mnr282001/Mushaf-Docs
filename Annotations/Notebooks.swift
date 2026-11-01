import SwiftData
import SwiftUI

enum NotebookSession {
    static let active = "mushaf.activeNotebook"
    static let visible = "mushaf.visibleNotebooks"
    static let archived = "mushaf.archivedNotebooks"

    static func ids(_ raw: String) -> [UUID] {
        raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
    }

    static func raw(_ ids: [UUID]) -> String {
        ids.map(\.uuidString).joined(separator: ",")
    }

    static func hue(hex: String) -> NotebookHue {
        let name = hexByName.first { $0.value.caseInsensitiveCompare(hex) == .orderedSame }?.key
        return NotebookHue.all.first { $0.name == name } ?? NotebookHue.all[0]
    }

    static func hex(of hue: NotebookHue) -> String {
        hexByName[hue.name] ?? "#2E7D6B"
    }

    private static let hexByName = [
        "Teal": "#2E7D6B",
        "Indigo": "#4A5A9C",
        "Saffron": "#C8902E",
        "Rose": "#B5566A",
        "Olive": "#7A8A3A",
        "Slate": "#5E6B73",
        "Plum": "#7D4F82",
        "Clay": "#A8673F",
    ]
}

struct NotebookSwitcher: View {
    var activeID: UUID?
    var currentPage: Int
    var onOpen: (Notebook) -> Void
    var onJump: (Notebook, Int) -> Void

    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Query(sort: \Notebook.createdAt) private var notebooks: [Notebook]
    @Query private var notes: [Annotation]
    @AppStorage(NotebookSession.visible) private var visibleRaw = ""
    @AppStorage(NotebookSession.archived) private var archivedRaw = ""
    @State private var creating = false
    @State private var newTitle = ""
    @State private var newHue = "Teal"
    @State private var renameID: UUID?
    @State private var draft = ""
    @State private var colourID: UUID?
    @State private var hitLimit = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { creating = true } label: {
                        Label("New notebook", systemImage: "plus")
                            .foregroundStyle(palette.uiInk)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }
                Section {
                    ForEach(openBooks) { book in
                        row(book)
                    }
                } footer: {
                    Text(hitLimit ? "Hide one notebook before showing another." : "Three notebooks can show on the page at once.")
                        .font(MushafType.uiSmall)
                        .foregroundStyle(palette.uiSecondary)
                }
                if !archivedBooks.isEmpty {
                    Section("Archived") {
                        ForEach(archivedBooks) { book in
                            row(book, archived: true)
                        }
                    }
                }
            }
            .navigationTitle("Notebooks")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $creating) { newNotebook }
        .sheet(isPresented: colourPresented) { colourSheet }
        .alert("Rename notebook", isPresented: renamePresented) {
            TextField("Name", text: $draft)
            Button("Save") { rename() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var openBooks: [Notebook] {
        notebooks.filter { !archived.contains($0.id) }
    }

    private var archivedBooks: [Notebook] {
        notebooks.filter { archived.contains($0.id) }
    }

    private var archived: Set<UUID> { Set(NotebookSession.ids(archivedRaw)) }
    private var visible: [UUID] { NotebookSession.ids(visibleRaw) }

    private var renamePresented: Binding<Bool> {
        Binding(get: { renameID != nil }, set: { if !$0 { renameID = nil } })
    }

    private var colourPresented: Binding<Bool> {
        Binding(get: { colourID != nil }, set: { if !$0 { colourID = nil } })
    }

    private func row(_ book: Notebook, archived: Bool = false) -> some View {
        let pages = pageNumbers(book)
        let hue = NotebookSession.hue(hex: book.colorHex).resolved(night: palette.isNight)
        return HStack(spacing: 12) {
            Circle().fill(hue.tint).frame(width: 12, height: 12)
                .accessibilityLabel(NotebookSession.hue(hex: book.colorHex).name)
            Button {
                guard !archived else { return }
                onOpen(book)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title).foregroundStyle(palette.uiInk)
                    Text(detail(book, pages: pages))
                        .font(MushafType.uiSmall)
                        .foregroundStyle(palette.uiSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(archived)
            if book.id == activeID {
                Image(systemName: "checkmark").foregroundStyle(palette.accent)
                    .accessibilityLabel("Writing in this notebook")
            }
            if !archived {
                NavigationLink {
                    NotebookIndex(book: book, pages: pages, notes: notes.filter { $0.notebook?.id == book.id }, onJump: { onJump(book, $0) })
                } label: {
                    Color.clear.frame(width: 44, height: 44)
                }
                .accessibilityLabel("Pages in \(book.title)")
                Button {
                    toggleVisible(book)
                } label: {
                    Image(systemName: visible.contains(book.id) ? "eye" : "eye.slash")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(book.id == activeID)
                .foregroundStyle(palette.uiInk)
                .accessibilityLabel(visible.contains(book.id) ? "Shown on the page" : "Hidden on the page")
            }
        }
        .swipeActions(edge: .trailing) {
            if archived {
                Button("Unarchive") { unarchive(book) }.tint(hue.tint)
            } else {
                Button("Archive", role: .destructive) { archive(book) }
                Button("Colour") { colourID = book.id }.tint(hue.tint)
                Button("Rename") {
                    draft = book.title
                    renameID = book.id
                }
            }
        }
    }

    private func detail(_ book: Notebook, pages: [Int]) -> String {
        let count = pages.count
        let word = count == 1 ? "page" : "pages"
        return "\(count) \(word) · last p. \(book.lastOpenedPage)"
    }

    private func pageNumbers(_ book: Notebook) -> [Int] {
        Array(Set(notes.filter { $0.notebook?.id == book.id }.map(\.page))).sorted()
    }

    private func toggleVisible(_ book: Notebook) {
        guard book.id != activeID else { return }
        var ids = visible.filter { $0 != book.id }
        if visible.contains(book.id) {
            visibleRaw = NotebookSession.raw(ids)
            hitLimit = false
            return
        }
        guard ids.count < 3 else {
            hitLimit = true
            return
        }
        ids.append(book.id)
        visibleRaw = NotebookSession.raw(ids)
        hitLimit = false
    }

    private func archive(_ book: Notebook) {
        var ids = NotebookSession.ids(archivedRaw)
        if !ids.contains(book.id) { ids.append(book.id) }
        archivedRaw = NotebookSession.raw(ids)
        visibleRaw = NotebookSession.raw(visible.filter { $0 != book.id })
    }

    private func unarchive(_ book: Notebook) {
        archivedRaw = NotebookSession.raw(NotebookSession.ids(archivedRaw).filter { $0 != book.id })
    }

    private func rename() {
        guard let renameID, let book = notebooks.first(where: { $0.id == renameID }) else { return }
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { book.title = title }
    }

    private var newNotebook: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $newTitle)
                hues(selected: newHue) { newHue = $0 }
            }
            .navigationTitle("New notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Cancel") { creating = false }
                Button("Add") { addNotebook() }
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .presentationDetents([.medium])
    }

    private var colourSheet: some View {
        let book = notebooks.first { $0.id == colourID }
        return NavigationStack {
            Form {
                hues(selected: NotebookSession.hue(hex: book?.colorHex ?? "").name) { name in
                    guard let hue = NotebookHue.all.first(where: { $0.name == name }) else { return }
                    book?.colorHex = NotebookSession.hex(of: hue)
                }
            }
            .navigationTitle("Colour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { colourID = nil } }
        }
        .presentationDetents([.medium])
    }

    private func hues(selected: String, choose: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(NotebookHue.all) { hue in
                Button { choose(hue.name) } label: {
                    Circle()
                        .fill(hue.resolved(night: palette.isNight).tint)
                        .frame(width: 36, height: 36)
                        .overlay {
                            if hue.name == selected {
                                Circle().stroke(palette.uiInk, lineWidth: 2).frame(width: 44, height: 44)
                            }
                        }
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hue.name)
                .accessibilityAddTraits(hue.name == selected ? .isSelected : [])
            }
        }
        .padding(.vertical, 8)
    }

    private func addNotebook() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let hue = NotebookHue.all.first(where: { $0.name == newHue }) else { return }
        let book = Notebook()
        book.title = title
        book.colorHex = NotebookSession.hex(of: hue)
        book.lastOpenedPage = currentPage
        context.insert(book)
        creating = false
        newTitle = ""
        onOpen(book)
    }
}

private struct NotebookIndex: View {
    var book: Notebook
    var pages: [Int]
    var notes: [Annotation]
    var onJump: (Int) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            if pages.isEmpty {
                Text("No notes in \(book.title) yet.")
                    .font(MushafType.ui)
                    .foregroundStyle(palette.uiSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(pages, id: \.self) { page in
                    Button { onJump(page) } label: {
                        HStack {
                            Text("Page \(page)")
                                .foregroundStyle(palette.uiInk)
                                .font(MushafType.ui.monospacedDigit())
                            Spacer()
                            Text("\(notes.filter { $0.page == page }.count)")
                                .font(MushafType.uiSmall.monospacedDigit())
                                .foregroundStyle(palette.uiSecondary)
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
