// Shared with FocusFound & FotoPhilter — change all (FotoPhilter: Packages/GGSBrand/Sources/GGSBrand/Theme.swift).

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Greater Good Software brand colours.
public enum Brand {
    public static let navy = Color(hex: 0x064A63)
    public static let navyDeep = Color(hex: 0x052F40)
    public static let navyBright = Color(hex: 0x0A5A78)
    public static let green = Color(hex: 0x14B37D)
    public static let blue = Color(hex: 0x1E8FE1)
    public static let slate = Color(hex: 0x5B6B78)
    public static let slateLight = Color(hex: 0xA9BAC6)
}

/// Semantic colours used by screens. Each adapts to light and dark mode.
/// "Calm" palette: navy + green, with blue reserved for breaks.
public enum Theme {
    public static let background = Color(light: 0xF6F8F9, dark: 0x0B1E28)
    public static let surface = Color(light: 0xFFFFFF, dark: 0x12293A)
    public static let surfaceMuted = Color(light: 0xEDF1F3, dark: 0x1A3446)
    public static let textPrimary = Color(light: 0x0E2733, dark: 0xE8F1F5)
    public static let textSecondary = Color(light: 0x4F6170, dark: 0x9FB0BC)
    public static let hairline = Color(light: 0xD9E1E6, dark: 0x274457)

    /// Accessible accent (≥ 4.5:1 against background) for text and buttons.
    public static let accent = Color(light: 0x0B7A57, dark: 0x2FD49A)
    /// Brand green for decoration (rings, marks) where contrast rules don't apply.
    public static let accentDecorative = Brand.green

    public static let focus = Color(light: 0x064A63, dark: 0x4FB3D9)
    public static let breakTime = Color(light: 0x1E6FB0, dark: 0x6BB8F0)
    public static let ringTrack = Color(light: 0xE3E9ED, dark: 0x1F3A4C)

    public static let focusGradient = LinearGradient(
        colors: [Brand.navyBright, Brand.green], startPoint: .topLeading, endPoint: .bottomTrailing
    )
    public static let breakGradient = LinearGradient(
        colors: [Brand.blue, Color(hex: 0x6BC8F0)], startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

public extension Color {
    /// `Color(hex: 0x14B37D)`
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// `Color(hexString: "#14B37D")` — used for user tag colours stored as strings.
    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        self.init(hex: UInt32(cleaned, radix: 16) ?? 0x5B6B78)
    }

    /// A colour that switches between two hex values for light and dark appearance.
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
        #else
        self.init(hex: light)
        #endif
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#elseif canImport(AppKit)
extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
