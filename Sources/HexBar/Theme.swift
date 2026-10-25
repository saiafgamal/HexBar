import AppKit
import CoreText
import SwiftUI

/// Neutral light UI so the swatches carry all the color.
enum Theme {
    static let bg = Hex.color("#f4f4f1")
    static let card = Color.white
    static let ink = Hex.color("#17181c")
    static let secondary = Hex.color("#5f636d")
    static let tertiary = Hex.color("#9a9da5")
    static let hairline = Color.black.opacity(0.08)
    static let hairlineStrong = Color.black.opacity(0.16)
    static let danger = Hex.color("#c2412d")

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: Readex Pro (bundled variable font, weight set on the wght axis)

    // Only touched from the main thread (view bodies).
    nonisolated(unsafe) private static let descriptor: CTFontDescriptor? = {
        guard let url = Bundle.main.url(forResource: "ReadexPro", withExtension: "ttf") else { return nil }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        return (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first
    }()

    nonisolated(unsafe) private static var cache: [String: Font] = [:]

    /// weight: 200 (ExtraLight) to 700 (Bold).
    static func font(_ size: CGFloat, _ weight: CGFloat = 400) -> Font {
        let key = "\(size)-\(weight)"
        if let f = cache[key] { return f }
        let font: Font
        if let descriptor {
            let wght = 0x7767_6874 // 'wght'
            let varied = CTFontDescriptorCreateCopyWithAttributes(
                descriptor, [kCTFontVariationAttribute: [wght: weight]] as CFDictionary)
            font = Font(CTFontCreateWithFontDescriptor(varied, size, nil))
        } else {
            font = .system(size: size)
        }
        cache[key] = font
        return font
    }
}

/// Small square icon button used in the top bar.
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.ink)
            .frame(width: 34, height: 34)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.hairline))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

/// Solid ink pill button.
struct InkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(12.5, 500))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(Theme.ink.opacity(isEnabled ? 1 : 0.3), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Quiet text button.
struct GhostButtonStyle: ButtonStyle {
    var tint: Color = Theme.secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(12, 500))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.black.opacity(configuration.isPressed ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
    }
}

/// White rounded input field shell.
struct FieldShell: ViewModifier {
    var focused = false

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(focused ? Theme.ink.opacity(0.35) : Theme.hairline)
            )
    }
}

extension View {
    func fieldShell(focused: Bool = false) -> some View { modifier(FieldShell(focused: focused)) }
}
