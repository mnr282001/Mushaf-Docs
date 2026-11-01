import SwiftUI
import UniformTypeIdentifiers

struct ViewPreset: Codable {
    var interlinear: Bool
    var sidebar: Bool
    var stickies: Bool
    var highlights: Bool

    static func decode(_ data: Data?) -> ViewPreset? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(ViewPreset.self, from: data)
    }

    var data: Data? {
        try? JSONEncoder().encode(self)
    }
}

struct NoteBackup: Transferable {
    var data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
            .suggestedFileName("Mushaf notes.json")
    }
}

struct LayerToggles: View {
    @Binding var interlinear: Bool
    @Binding var sidebar: Bool
    @Binding var stickies: Bool
    @Binding var highlights: Bool
    var backup: Data
    var pdf: Data
    var onSave: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            pill("Interlinear", on: $interlinear)
            pill("Sidebar", on: $sidebar)
            pill("Stickies", on: $stickies)
            pill("Highlights", on: $highlights)
            Button(action: onSave) {
                Text("Save as preset")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.accent)
            ShareLink(item: NoteBackup(data: backup), preview: SharePreview("Notes")) {
                Text("Export notes")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.uiInk)
            ShareLink(item: NotePDF(data: pdf), preview: SharePreview("Pages")) {
                Text("Export PDF")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.uiInk)
        }
        .padding(16)
        .frame(width: 240)
        .background(palette.desk)
    }

    private func pill(_ title: String, on: Binding<Bool>) -> some View {
        Button {
            on.wrappedValue.toggle()
        } label: {
            Text(title)
                .font(MushafType.ui)
                .foregroundStyle(on.wrappedValue ? palette.paper : palette.uiInk)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(on.wrappedValue ? palette.accent : palette.paper, in: Capsule())
                .overlay { Capsule().strokeBorder(palette.uiSecondary.opacity(0.45), lineWidth: on.wrappedValue ? 0 : 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
