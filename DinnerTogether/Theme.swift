import SwiftUI
import UIKit

/// Warm editorial palette, with corresponding warm surfaces in Dark Mode.
enum Theme {
    private static func adaptive(_ light: (Double, Double, Double), _ dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat(rgb.0), green: CGFloat(rgb.1), blue: CGFloat(rgb.2), alpha: 1)
        })
    }
    static let cream = adaptive((0.980, 0.965, 0.929), (0.102, 0.098, 0.086))
    static let paper = adaptive((0.999, 0.992, 0.973), (0.153, 0.145, 0.125))
    // Text colors come from RecipePalette.swift — Dark Mode from PageText,
    // Light Mode from PaleText: deep recipe pages draw in Dark Mode, pale
    // ones in Light Mode, and the Linux tests check those values.
    static let ink = adaptive(PaleText.ink.tuple, PageText.ink.tuple)
    static let tomato = adaptive(PaleText.accent.tuple, (0.950, 0.540, 0.420))
    static let olive = adaptive(PaleText.olive.tuple, PageText.olive.tuple)
    static let muted = adaptive(PaleText.muted.tuple, PageText.muted.tuple)
    static let line = adaptive((0.902, 0.875, 0.824), (0.270, 0.255, 0.220))
    // Filled buttons retain the darker tomato so white labels stay legible.
    static let buttonFill = Color(red: 0.659, green: 0.220, blue: 0.153)
    // Restrained reading surface; opaque colors keep text contrast predictable.
    static let recipeWash = adaptive((0.945, 0.920, 0.865), (0.135, 0.150, 0.115))
    static var recipeBackground: LinearGradient {
        LinearGradient(colors: [cream, recipeWash, cream],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static let warning = adaptive(PaleText.warning.tuple, PageText.warning.tuple)
    /// Timer chips and step labels on a colored recipe page (see PageText.accent).
    static let pageAccent = PageText.accent.color
    /// Light-mode ink, fixed: text on the light button of a deep page.
    static let inkOnLight = PaleText.ink.color
}

extension RGB {
    var tuple: (Double, Double, Double) { (r, g, b) }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.caption.weight(.semibold))
            .foregroundStyle(Theme.muted).tracking(1.4)
            .accessibilityAddTraits(.isHeader)
    }
}

struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(22)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

extension View {
    func dtCard() -> some View { modifier(Card()) }
}

struct BigButtonStyle: ButtonStyle {
    /// On a deep recipe page the button is a light pill with dark text
    /// (12:1) rather than tomato on a deep, possibly red, gradient. A pale
    /// page keeps the classic tomato button.
    let onColoredPage: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    // Explicit: private wrappers would make the memberwise init file-private.
    init(onColoredPage: Bool = false) { self.onColoredPage = onColoredPage }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline.weight(.semibold))
            .padding(.horizontal, 18).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(onColoredPage ? Theme.inkOnLight : .white)
            .background(onColoredPage ? PageText.ink.color : Theme.buttonFill,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(Theme.ink)
            .background(Theme.ink.opacity(configuration.isPressed ? 0.09 : 0.045),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12).frame(minHeight: 44)
            .foregroundStyle(Theme.ink)
            .background(Theme.ink.opacity(configuration.isPressed ? 0.09 : 0.04),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
    }
}
