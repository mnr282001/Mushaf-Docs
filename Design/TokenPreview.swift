import SwiftUI

struct TokenPreview: View {
    @Environment(\.colorSchemeContrast) private var contrast
    private let tokens: [(String, (Palette) -> Color)] = [
        ("desk", { $0.desk }),
        ("paper", { $0.paper }),
        ("quranInk", { $0.quranInk }),
        ("ayahMarker", { $0.ayahMarker }),
        ("rule", { $0.rule }),
        ("uiInk", { $0.uiInk }),
        ("uiSecondary", { $0.uiSecondary }),
        ("accent", { $0.accent }),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(Palette.all, id: \.name) { palette in
                    themeBlock(palette)
                }
            }
            .padding(24)
        }
        .background(Palette.paper.desk)
    }

    private func themeBlock(_ palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(palette.name).font(MushafType.ui).foregroundStyle(Palette.paper.uiInk)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(tokens, id: \.0) { name, key in
                    swatch(name, key(palette), on: palette.paper)
                }
            }
            contrastRow("uiInk on paper", wcag(palette.uiInk, palette.paper))
            contrastRow("uiSecondary on paper", wcag(palette.uiSecondary, palette.paper))
            contrastRow("uiSecondary on desk", wcag(palette.uiSecondary, palette.desk))
            contrastRow("uiInk on desk", wcag(palette.uiInk, palette.desk))
            let hues = palette.notebooks(contrast: contrast == .increased)
            ForEach(hues) { hue in
                HStack(spacing: 8) {
                    Circle().fill(hue.tint).frame(width: 10, height: 10)
                    Text(hue.name).font(MushafType.uiSmall).foregroundStyle(hue.ink)
                    Spacer()
                    contrastRow("ink", wcag(hue.ink, palette.paper))
                }
                .padding(.horizontal, 8)
                .frame(height: 36)
                .background(hue.wash.opacity(hue.washOpacity), in: RoundedRectangle(cornerRadius: 6))
            }
            Text("Note").font(MushafType.noteEnglish)
            Text("بِسْمِ").font(MushafType.noteArabic)
        }
        .padding(16)
        .background(palette.desk, in: RoundedRectangle(cornerRadius: 12))
    }

    private func swatch(_ name: String, _ color: Color, on paper: Color) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 28, height: 28)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(paper.opacity(0.4), lineWidth: 0.5))
            Text(name).font(MushafType.uiSmall).foregroundStyle(Palette.paper.uiInk)
            Spacer(minLength: 0)
        }
        .padding(6)
        .background(paper, in: RoundedRectangle(cornerRadius: 8))
    }

    private func contrastRow(_ label: String, _ ratio: Double) -> some View {
        let pass = ratio >= 4.5
        return HStack {
            Text(label).font(MushafType.uiSmall)
            Spacer()
            Text(String(format: "%.2f  %@", ratio, pass ? "AA" : "fail"))
                .font(MushafType.uiSmall.monospacedDigit())
                .foregroundStyle(pass ? Color(hex: 0x1F6F5C) : Color(hex: 0x8A3B4C))
        }
    }
}
