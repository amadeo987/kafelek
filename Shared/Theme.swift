import SwiftUI
import AppKit

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r, g, b, a: Double
        switch s.count {
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.black
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        let a = Int(round(ns.alphaComponent * 255))
        if a < 255 {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

extension NSColor {
    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? NSColor.gray
        return String(format: "#%02X%02X%02X",
                      Int(round(c.redComponent * 255)),
                      Int(round(c.greenComponent * 255)),
                      Int(round(c.blueComponent * 255)))
    }
}

extension WeightChoice {
    var fontWeight: Font.Weight {
        switch self {
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

extension TextAlign {
    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

extension FontChoice {
    func font(size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .system: return .system(size: size, weight: weight, design: .default)
        case .rounded: return .system(size: size, weight: weight, design: .rounded)
        case .serif: return .system(size: size, weight: weight, design: .serif)
        case .mono: return .system(size: size, weight: weight, design: .monospaced)
        default: return Font.custom(rawValue, size: size).weight(weight)
        }
    }
}

extension Style {
    var text: Color { Color(hex: textColor) }
    var secondary: Color { Color(hex: textColor).opacity(0.62) }
    var tertiary: Color { Color(hex: textColor).opacity(0.35) }
    var accent: Color { Color(hex: accentColor) }

    /// Czcionka wg stylu, przeskalowana suwakiem „Wielkość tekstu”.
    func font(_ size: CGFloat, _ weight: Font.Weight? = nil) -> Font {
        font.font(size: size * textScale, weight: weight ?? self.weight.fontWeight)
    }

    /// Czcionka dla drobnych podpisów – zawsze czytelna.
    func caption(_ size: CGFloat = 11, _ weight: Font.Weight = .medium) -> Font {
        let base: FontChoice = (font == .mono) ? .mono : (font == .rounded ? .rounded : .system)
        return base.font(size: size * min(textScale, 1.3), weight: weight)
    }
}

// MARK: - Motywy (szybkie zestawy kolorów)

struct ThemePreset: Identifiable {
    let id: String
    let name: String
    let background: BackgroundKind
    let color1: String
    let color2: String
    let text: String
    let accent: String
    var font: FontChoice? = nil

    func apply(to style: inout Style) {
        style.background = background == .photo ? .solid : background
        style.color1 = color1
        style.color2 = color2
        style.textColor = text
        style.accentColor = accent
        if let font { style.font = font }
    }

    static let all: [ThemePreset] = [
        ThemePreset(id: "black", name: "Czerń", background: .solid, color1: "#000000", color2: "#1C1C1E", text: "#FFFFFF", accent: "#FF9F0A"),
        ThemePreset(id: "glass", name: "Szkło", background: .glass, color1: "#000000", color2: "#1C1C1E", text: "#FFFFFF", accent: "#30D158"),
        ThemePreset(id: "graphite", name: "Grafit", background: .solid, color1: "#1C1C1E", color2: "#1C1C1E", text: "#FFFFFF", accent: "#64D2FF"),
        ThemePreset(id: "white", name: "Biel", background: .solid, color1: "#FFFFFF", color2: "#F2F2F7", text: "#1C1C1E", accent: "#FF3B30"),
        ThemePreset(id: "paper", name: "Papier", background: .solid, color1: "#F3EBDD", color2: "#E8DCC6", text: "#2B2118", accent: "#1F4FD8", font: .serif),
        ThemePreset(id: "claude", name: "Claude", background: .gradient, color1: "#2B1A14", color2: "#141110", text: "#F5EDE6", accent: "#D97757"),
        ThemePreset(id: "ocean", name: "Ocean", background: .gradient, color1: "#0A84FF", color2: "#002E6B", text: "#FFFFFF", accent: "#7FDBFF"),
        ThemePreset(id: "sunset", name: "Zachód", background: .gradient, color1: "#FF5E3A", color2: "#7B1FA2", text: "#FFFFFF", accent: "#FFD60A"),
        ThemePreset(id: "forest", name: "Las", background: .gradient, color1: "#1E5631", color2: "#0B2414", text: "#F0FFF4", accent: "#A4DE02"),
        ThemePreset(id: "neon", name: "Neon", background: .solid, color1: "#0B0B12", color2: "#151525", text: "#E8F7FF", accent: "#39FF14", font: .mono),
        ThemePreset(id: "klein", name: "Klein", background: .solid, color1: "#1F3FD1", color2: "#0F239A", text: "#FFFFFF", accent: "#F3EBDD"),
        ThemePreset(id: "rose", name: "Róż", background: .gradient, color1: "#FFD1DC", color2: "#FF8FAB", text: "#3D0A1A", accent: "#C9184A", font: .rounded),
        ThemePreset(id: "mint", name: "Mięta", background: .solid, color1: "#D8F3DC", color2: "#B7E4C7", text: "#081C15", accent: "#2D6A4F", font: .rounded),
    ]
}
