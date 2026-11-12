import SwiftUI

// Layout tokens for ConferenceKitUI. Names match the ConferenceKit design system.
// Colour is not here: neutrals are the system's semantic styles, and the one hue is the
// conference accent, applied as tint by `conferenceTheme(_:)`.

/// Corner radii. Controls are capsules; these are for content shapes.
enum CKRadius {
    /// Photos inside a note. `radius-inset`.
    static let inset: CGFloat = 8
    /// Note cards, the note field, hover shapes. `radius-card`.
    static let card: CGFloat = 12
    /// Maps and other full-width media. `radius-media`.
    static let media: CGFloat = 16
}

enum CKSize {
    /// Minimum hit target on touch platforms. `hit-target`.
    static let hitTarget: CGFloat = 44
}
