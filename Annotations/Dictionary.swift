import SwiftUI

struct DictionaryCard: View {
    var gloss: WordGloss
    var expanded: Bool
    var definition: String
    var paper: Color
    var ink: Color
    var secondary: Color
    var accent: Color
    var pageSize: CGSize
    var room: CGFloat
    var onExpand: () -> Void
    var onHighlight: () -> Void
    var onNote: () -> Void
    var onPage: (Int) -> Void
    var onDefinition: (String) -> Void
    var onClose: () -> Void
    @State private var draft = ""

    var body: some View {
        let width: CGFloat = 132
        let hang = min(max(room - 16, 36), 64)
        let originX = pageSize.width - (width - hang)
        card
            .frame(width: width, alignment: .leading)
            .position(x: originX + width / 2, y: pageSize.height * 0.34)
            .onAppear { draft = definition }
            .onChange(of: definition) { _, next in
                if draft != next { draft = next }
            }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(gloss.arabic)
                    .font(.system(size: 22))
                    .foregroundStyle(ink)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close word menu")
            }
            Text(gloss.gloss)
                .font(.system(size: 15))
                .foregroundStyle(ink)
            Text(gloss.root)
                .font(.system(size: 13))
                .foregroundStyle(secondary)
            VStack(alignment: .leading, spacing: 2) {
                menuButton("Highlight", action: onHighlight)
                menuButton(expanded ? "Less" : "Dictionary", action: onExpand)
                menuButton("Note", action: onNote)
            }
            if expanded {
                Text(gloss.translit)
                    .font(.system(size: 13))
                    .foregroundStyle(secondary)
                Text("\(gloss.lemma) · \(gloss.frequency)")
                    .font(.system(size: 13))
                    .foregroundStyle(ink)
                if !gloss.pages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(gloss.pages.prefix(4), id: \.self) { number in
                                Button {
                                    onPage(number)
                                } label: {
                                    Text("\(number)")
                                        .font(.system(size: 13).monospacedDigit())
                                        .frame(minWidth: 32, minHeight: 32)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(accent)
                            }
                        }
                    }
                }
                TextField("My definition", text: $draft)
                    .font(.system(size: 15))
                    .foregroundStyle(ink)
                    .onSubmit { onDefinition(draft) }
                    .onChange(of: draft) { _, next in onDefinition(next) }
            }
        }
        .padding(12)
        .background(paper, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(accent.opacity(0.35), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }

    private func menuButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .frame(minHeight: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(accent)
    }
}
