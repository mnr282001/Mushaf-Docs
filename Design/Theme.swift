import SwiftUI
import UIKit

enum MushafTheme: String, CaseIterable, Identifiable {
    case auto, paper, sepia, night
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    func palette(for scheme: ColorScheme) -> Palette {
        switch self {
        case .paper: .paper
        case .sepia: .sepia
        case .night: .night
        case .auto: scheme == .dark ? .night : .paper
        }
    }

    var preferredScheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .night: .dark
        case .paper, .sepia: .light
        }
    }
}

struct NotebookHue: Identifiable, Hashable {
    var name: String
    var tint: Color
    var wash: Color
    var washOpacity: Double
    var ink: Color
    var id: String { name }

    func resolved(night: Bool) -> NotebookHue {
        guard night else { return self }
        var ink = self.ink
        var amount = 0.30
        while wcag(ink.lightened(amount), Palette.night.paper) < 4.5, amount < 0.8 {
            amount += 0.04
        }
        return NotebookHue(name: name, tint: tint, wash: wash, washOpacity: 0.22, ink: ink.lightened(amount))
    }
}

struct Palette: Equatable {
    var name: String
    var desk: Color
    var paper: Color
    var quranInk: Color
    var ayahMarker: Color
    var rule: Color
    var uiInk: Color
    var uiSecondary: Color
    var accent: Color
    var isNight: Bool

    func notebooks(contrast: Bool) -> [NotebookHue] {
        NotebookHue.all.map { hue in
            var hue = hue.resolved(night: isNight)
            if contrast { hue.washOpacity = min(1, hue.washOpacity + 0.08) }
            return hue
        }
    }

    static let paper = Palette(
        name: "Paper",
        desk: Color(hex: 0xECE7DD),
        paper: Color(hex: 0xFBF8F1),
        quranInk: Color(hex: 0x1B1B18),
        ayahMarker: Color(hex: 0x1F6F5C),
        rule: Color(hex: 0x1B1B18, opacity: 0.08),
        uiInk: Color(hex: 0x3A3A36),
        uiSecondary: Color(hex: 0x6A6761),
        accent: Color(hex: 0x1F6F5C),
        isNight: false
    )
    static let sepia = Palette(
        name: "Sepia",
        desk: Color(hex: 0xE3D6BC),
        paper: Color(hex: 0xF4E9D2),
        quranInk: Color(hex: 0x2A2116),
        ayahMarker: Color(hex: 0x6B4E1E),
        rule: Color(hex: 0x2A2116, opacity: 0.10),
        uiInk: Color(hex: 0x43382A),
        uiSecondary: Color(hex: 0x675C4A),
        accent: Color(hex: 0x7A5A22),
        isNight: false
    )
    static let night = Palette(
        name: "Night",
        desk: Color(hex: 0x0F1110),
        paper: Color(hex: 0x1A1C1B),
        quranInk: Color(hex: 0xE6E1D6),
        ayahMarker: Color(hex: 0x7FBFA8),
        rule: Color(hex: 0xE6E1D6, opacity: 0.10),
        uiInk: Color(hex: 0xC9C4B9),
        uiSecondary: Color(hex: 0x85837C),
        accent: Color(hex: 0x7FBFA8),
        isNight: true
    )
    static let all = [paper, sepia, night]
}

enum MushafType {
    static let noteEnglish = Font.system(size: 17, design: .serif)
    static let noteArabic = Font.system(size: 19)
    static let ui = Font.system(size: 15)
    static let uiSmall = Font.system(size: 13)
    static let juz = Font.system(size: 13).smallCaps()
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.paper
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    func lightened(_ amount: Double) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(.sRGB, red: Double(r) + (1 - Double(r)) * amount, green: Double(g) + (1 - Double(g)) * amount, blue: Double(b) + (1 - Double(b)) * amount, opacity: Double(a))
    }

    var uiColor: UIColor { UIColor(self) }
}

func wcag(_ foreground: Color, _ background: Color) -> Double {
    func channel(_ v: CGFloat) -> Double {
        let x = Double(v)
        return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
    }
    func lum(_ color: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
    let lighter = max(lum(foreground), lum(background))
    let darker = min(lum(foreground), lum(background))
    return (lighter + 0.05) / (darker + 0.05)
}

extension NotebookHue {
    static let all: [NotebookHue] = [
        .init(name: "Teal", tint: Color(hex: 0x2E7D6B), wash: Color(hex: 0x2E7D6B), washOpacity: 0.14, ink: Color(hex: 0x1F5C4F)),
        .init(name: "Indigo", tint: Color(hex: 0x4A5A9C), wash: Color(hex: 0x4A5A9C), washOpacity: 0.14, ink: Color(hex: 0x34407A)),
        .init(name: "Saffron", tint: Color(hex: 0xC8902E), wash: Color(hex: 0xE3B04B), washOpacity: 0.22, ink: Color(hex: 0x8A5F14)),
        .init(name: "Rose", tint: Color(hex: 0xB5566A), wash: Color(hex: 0xB5566A), washOpacity: 0.14, ink: Color(hex: 0x8A3B4C)),
        .init(name: "Olive", tint: Color(hex: 0x7A8A3A), wash: Color(hex: 0x7A8A3A), washOpacity: 0.16, ink: Color(hex: 0x56622A)),
        .init(name: "Slate", tint: Color(hex: 0x5E6B73), wash: Color(hex: 0x5E6B73), washOpacity: 0.14, ink: Color(hex: 0x3F4A50)),
        .init(name: "Plum", tint: Color(hex: 0x7D4F82), wash: Color(hex: 0x7D4F82), washOpacity: 0.14, ink: Color(hex: 0x5A375E)),
        .init(name: "Clay", tint: Color(hex: 0xA8673F), wash: Color(hex: 0xA8673F), washOpacity: 0.14, ink: Color(hex: 0x7A4A2C)),
    ]
}
