import SwiftUI

public struct ConferenceTheme: Codable, Hashable, Sendable {
    public var accent: String
    public var primary: String
    public var secondary: String
    public var background: String
    public var surface: String
    public var onAccent: String
    public var preferredColorScheme: ColorSchemePreference

    public init(
        accent: String = "#FF6A00",
        primary: String = "#1C1C1E",
        secondary: String = "#8E8E93",
        background: String = "#F2F2F7",
        surface: String = "#FFFFFF",
        onAccent: String = "#FFFFFF",
        preferredColorScheme: ColorSchemePreference = .system
    ) {
        self.accent = accent
        self.primary = primary
        self.secondary = secondary
        self.background = background
        self.surface = surface
        self.onAccent = onAccent
        self.preferredColorScheme = preferredColorScheme
    }

    public var accentColor: Color { Color(hex: accent) ?? .orange }
    public var primaryColor: Color { Color(hex: primary) ?? .primary }
    public var secondaryColor: Color { Color(hex: secondary) ?? .secondary }
    public var backgroundColor: Color { Color(hex: background) ?? fallbackBackground }
    public var surfaceColor: Color { Color(hex: surface) ?? fallbackSurface }

    private var fallbackBackground: Color {
        #if canImport(UIKit) && !os(watchOS)
        Color(uiColor: .systemBackground)
        #elseif canImport(AppKit) && !os(watchOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.black.opacity(0.04)
        #endif
    }

    private var fallbackSurface: Color {
        #if canImport(UIKit) && !os(watchOS)
        Color(uiColor: .secondarySystemBackground)
        #elseif canImport(AppKit) && !os(watchOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color.black.opacity(0.08)
        #endif
    }
    public var onAccentColor: Color { Color(hex: onAccent) ?? .white }

    public var colorScheme: ColorScheme? {
        switch preferredColorScheme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

public enum ColorSchemePreference: String, Codable, Hashable, Sendable {
    case system
    case light
    case dark
}

private struct ConferenceThemeKey: EnvironmentKey {
    static let defaultValue = ConferenceTheme()
}

extension EnvironmentValues {
    public var conferenceTheme: ConferenceTheme {
        get { self[ConferenceThemeKey.self] }
        set { self[ConferenceThemeKey.self] = newValue }
    }
}

extension View {
    public func conferenceTheme(_ theme: ConferenceTheme) -> some View {
        environment(\.conferenceTheme, theme)
            .tint(theme.accentColor)
            .preferredColorScheme(theme.colorScheme)
    }
}
