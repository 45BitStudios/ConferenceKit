import Foundation

/// How the shell should arrange itself.
///
/// Fold poses come from the reserved division region, not the hinge angle
/// and not the device orientation. A horizontal band is laptop mode (top
/// half upright, bottom half flat). A vertical band is book mode.
public enum DuoPose: String, Sendable, Hashable, CaseIterable {
    /// Outer display, or any compact-width container.
    case compact
    /// Flat inner display, iPad, Mac, or another regular-width window.
    case regular
    /// Partially folded with a vertical crease. Schedule and detail sit on either side.
    case book
    /// Partially folded with a horizontal crease. Session stage above, notes on the deck.
    case laptop
}

/// The fold's reserved division, in the container's coordinate space.
public struct DivisionMeasurement: Hashable, Sendable {
    public var active: Bool
    public var width: Double
    public var height: Double
    public var minX: Double
    public var minY: Double

    public init(active: Bool, width: Double, height: Double, minX: Double = 0, minY: Double = 0) {
        self.active = active
        self.width = width
        self.height = height
        self.minX = minX
        self.minY = minY
    }

    public static let inactive = DivisionMeasurement(active: false, width: 0, height: 0)

    /// The crease runs across the display. That is laptop mode.
    public var isHorizontalFold: Bool {
        active && width > height && width > 0 && height > 0
    }

    /// The crease runs from top to bottom. That is book mode.
    public var isVerticalFold: Bool {
        active && height >= width && width > 0 && height > 0
    }
}

public enum DuoLayout {
    /// `division` is an active reserved division region. Its own width and
    /// height decide laptop versus book. Container aspect is only a fallback
    /// when the region is known to be active but its size was not measured.
    public static func pose(
        containerWidth: Double,
        containerHeight: Double,
        horizontallyCompact: Bool,
        division: DivisionMeasurement = .inactive
    ) -> DuoPose {
        if division.isHorizontalFold { return .laptop }
        if division.isVerticalFold { return .book }
        if division.active, containerWidth > 0, containerHeight > 0 {
            return containerWidth >= containerHeight ? .book : .laptop
        }
        return horizontallyCompact ? .compact : .regular
    }
}

/// Where to put the two panes so they sit on either side of the crease.
public struct FoldSplit: Hashable, Sendable {
    public enum Axis: String, Sendable, Hashable {
        case horizontal
        case vertical
        case none
    }

    public var axis: Axis
    /// Space before the crease, from the top (horizontal fold) or leading edge (vertical fold).
    public var primaryExtent: Double
    public var band: Double

    public init(axis: Axis, primaryExtent: Double, band: Double) {
        self.axis = axis
        self.primaryExtent = primaryExtent
        self.band = band
    }

    public static func measure(containerWidth: Double, containerHeight: Double, division: DivisionMeasurement) -> FoldSplit {
        if division.isHorizontalFold {
            let primary = min(max(0, division.minY), max(0, containerHeight - division.height))
            return FoldSplit(axis: .horizontal, primaryExtent: primary, band: division.height)
        }
        if division.isVerticalFold {
            let primary = min(max(0, division.minX), max(0, containerWidth - division.width))
            return FoldSplit(axis: .vertical, primaryExtent: primary, band: division.width)
        }
        return FoldSplit(axis: .none, primaryExtent: 0, band: 0)
    }
}

/// Which session the laptop stage and its notes should follow.
public enum LiveSessionFollow {
    public static func sessionID(
        sessions: [Session],
        pinnedID: String?,
        followLive: Bool,
        now: Date
    ) -> String? {
        if followLive {
            if let live = ConferenceSearch.liveSessions(in: sessions, at: now).first {
                return live.id
            }
            if let next = ConferenceSearch.nextUp(in: sessions, at: now).first {
                return next.id
            }
        }
        if let pinnedID, sessions.contains(where: { $0.id == pinnedID }) {
            return pinnedID
        }
        return ConferenceSearch.liveSessions(in: sessions, at: now).first?.id
            ?? ConferenceSearch.nextUp(in: sessions, at: now).first?.id
    }
}

public enum SessionProgress {
    public static func fraction(session: Session, now: Date) -> Double {
        let span = session.endTime.timeIntervalSince(session.startTime)
        guard span > 0 else { return session.endTime <= now ? 1 : 0 }
        return min(1, max(0, now.timeIntervalSince(session.startTime) / span))
    }

    public static func offset(from start: Date, to date: Date) -> TimeInterval {
        date.timeIntervalSince(start)
    }

    public static func offsetLabel(_ offset: TimeInterval) -> String {
        let sign = offset < 0 ? "−" : "+"
        let total = Int(abs(offset).rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%@%d:%02d:%02d", sign, hours, minutes, seconds)
        }
        return String(format: "%@%d:%02d", sign, minutes, seconds)
    }

    public static func remainingLabel(session: Session, now: Date) -> String {
        if now < session.startTime {
            let minutes = Int(session.startTime.timeIntervalSince(now) / 60)
            return minutes < 1 ? "Starts now" : "Starts in \(minutes) min"
        }
        if now > session.endTime { return "Ended" }
        let minutes = Int(session.endTime.timeIntervalSince(now) / 60)
        return minutes < 1 ? "Ending" : "\(minutes) min left"
    }
}
