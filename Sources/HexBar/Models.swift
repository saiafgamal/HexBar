import AppKit
import SwiftUI

struct Swatch: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var hex: String
}

struct Palette: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var swatches: [Swatch]
}

enum CopyFormat: String, CaseIterable, Identifiable {
    case hash, plain, rgb

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hash: "#29366C"
        case .plain: "29366C"
        case .rgb: "rgb(41, 54, 108)"
        }
    }

    func format(_ hex: String) -> String {
        switch self {
        case .hash: hex.uppercased()
        case .plain: String(hex.dropFirst()).uppercased()
        case .rgb: Hex.rgb(hex)
        }
    }

    static var current: CopyFormat {
        CopyFormat(rawValue: UserDefaults.standard.string(forKey: "copyFormat") ?? "") ?? .hash
    }
}

enum Hex {
    /// Accepts "#abc", "#aabbcc", "aabbcc", "#aabbccdd". Bare 3-digit input is rejected
    /// so words like "bed" or "add" stay searches. Returns "#aabbcc" or "#aabbccdd".
    static func normalize(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hadHash = s.hasPrefix("#")
        if hadHash { s.removeFirst() }
        guard !s.isEmpty, s.allSatisfy(\.isHexDigit) else { return nil }
        switch s.count {
        case 3 where hadHash: return "#" + s.map { "\($0)\($0)" }.joined()
        case 6, 8: return "#" + s
        default: return nil
        }
    }

    static func color(_ hex: String) -> Color {
        Color(nsColor: nsColor(hex))
    }

    static func nsColor(_ hex: String) -> NSColor {
        let s = hex.dropFirst()
        let v = UInt64(s, radix: 16) ?? 0
        let hasAlpha = s.count == 8
        let r = Double((v >> (hasAlpha ? 24 : 16)) & 0xff) / 255
        let g = Double((v >> (hasAlpha ? 16 : 8)) & 0xff) / 255
        let b = Double((v >> (hasAlpha ? 8 : 0)) & 0xff) / 255
        let a = hasAlpha ? Double(v & 0xff) / 255 : 1
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    static func from(_ color: NSColor) -> String? {
        guard let c = color.usingColorSpace(.sRGB) else { return nil }
        let r = Int((c.redComponent * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        return String(format: "#%02x%02x%02x", r, g, b)
    }

    static func rgb(_ hex: String) -> String {
        let c = nsColor(hex)
        return "rgb(\(Int((c.redComponent * 255).rounded())), \(Int((c.greenComponent * 255).rounded())), \(Int((c.blueComponent * 255).rounded())))"
    }

    static func isLight(_ hex: String) -> Bool {
        let c = nsColor(hex)
        return 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent > 0.62
    }
}

enum Seed {
    /// One example brand. Rename it, edit it, or delete it.
    static let palettes: [Palette] = [
        Palette(name: "Example Brand", swatches: [
            Swatch(name: "Primary", hex: "#2f5bea"),
            Swatch(name: "Primary Dark", hex: "#1e3a9e"),
            Swatch(name: "Secondary", hex: "#3fbf9f"),
            Swatch(name: "Accent", hex: "#f5c542"),
            Swatch(name: "Alert", hex: "#ef5b5b"),
            Swatch(name: "Ink", hex: "#16181d"),
            Swatch(name: "Muted", hex: "#6b7280"),
            Swatch(name: "Surface", hex: "#e8ebef"),
            Swatch(name: "Background", hex: "#fafaf7"),
        ]),
    ]
}
