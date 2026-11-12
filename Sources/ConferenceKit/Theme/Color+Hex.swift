import SwiftUI

extension Color {
    /// Accepts `#RGB`, `#RRGGBB`, or `#RRGGBBAA`.
    public init?(hex: String) {
        guard let parsed = HexColor(hex) else { return nil }
        self.init(.sRGB, red: parsed.red, green: parsed.green, blue: parsed.blue, opacity: parsed.alpha)
    }
}

/// sRGB components of a hex colour, so contrast can be checked before a `Color` is made.
struct HexColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Accepts `#RGB`, `#RRGGBB`, or `#RRGGBBAA`.
    init?(_ hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw.removeFirst() }

        var value: UInt64 = 0
        guard Scanner(string: raw).scanHexInt64(&value) else { return nil }

        switch raw.count {
        case 3:
            red = Double((value >> 8) & 0xF) / 15
            green = Double((value >> 4) & 0xF) / 15
            blue = Double(value & 0xF) / 15
            alpha = 1
        case 6:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = 1
        case 8:
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        default:
            return nil
        }
    }

    /// WCAG relative luminance.
    var luminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio against a ground of the given luminance.
    func contrast(againstLuminance ground: Double) -> Double {
        let lighter = max(luminance, ground)
        let darker = min(luminance, ground)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// The same hue moved toward black (on a light ground) or white (on a dark one)
    /// until it holds `ratio` against the ground. Unchanged when it already does.
    func toned(againstLuminance ground: Double, ratio: Double = 4.5) -> HexColor {
        let towardBlack = ground > 0.18
        var result = self
        var step = 0.0
        while result.contrast(againstLuminance: ground) < ratio, step < 1 {
            step += 0.05
            func mix(_ channel: Double) -> Double {
                towardBlack ? channel * (1 - step) : channel + (1 - channel) * step
            }
            result = HexColor(red: mix(red), green: mix(green), blue: mix(blue), alpha: alpha)
        }
        return result
    }
}
