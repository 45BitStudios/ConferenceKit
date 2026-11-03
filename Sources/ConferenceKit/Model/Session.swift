import Foundation

public struct Session: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var synopsis: String
    public var startTime: Date
    public var endTime: Date
    public var speakerIDs: [String]
    public var trackID: String?
    public var roomID: String?
    public var kind: SessionKind
    /// Optional video or feedback URL.
    public var recordingURL: URL?
    /// Optional slides or session link shown in the laptop-mode stage.
    public var slidesURL: URL?
    /// Free-form level such as "Beginner". Omitted when the organizer has none.
    public var level: String?

    public init(
        id: String,
        title: String,
        synopsis: String,
        startTime: Date,
        endTime: Date,
        speakerIDs: [String] = [],
        trackID: String? = nil,
        roomID: String? = nil,
        kind: SessionKind = .talk,
        recordingURL: URL? = nil,
        slidesURL: URL? = nil,
        level: String? = nil
    ) {
        self.id = id
        self.title = title
        self.synopsis = synopsis
        self.startTime = startTime
        self.endTime = endTime
        self.speakerIDs = speakerIDs
        self.trackID = trackID
        self.roomID = roomID
        self.kind = kind
        self.recordingURL = recordingURL
        self.slidesURL = slidesURL
        self.level = level
    }

    public var duration: Duration {
        Duration.seconds(max(0, endTime.timeIntervalSince(startTime)))
    }

    public func isHappening(at date: Date = .now) -> Bool {
        (startTime ... endTime).contains(date)
    }

    public func isUpcoming(at date: Date = .now) -> Bool {
        startTime > date
    }

    public func contains(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let fields: [String?] = [title, synopsis, level, kind.label]
        return fields.contains { $0?.localizedStandardContains(needle) == true }
    }
}

public enum SessionKind: String, Codable, Hashable, Sendable, CaseIterable {
    case keynote
    case talk
    case workshop
    case panel
    case lightning
    case breakout
    case meal
    case social
    case other

    public var label: String {
        switch self {
        case .keynote: "Keynote"
        case .talk: "Talk"
        case .workshop: "Workshop"
        case .panel: "Panel"
        case .lightning: "Lightning"
        case .breakout: "Breakout"
        case .meal: "Break"
        case .social: "Social"
        case .other: "Session"
        }
    }

    public var systemImage: String {
        switch self {
        case .keynote: "sparkles"
        case .talk: "bubble.left.and.bubble.right"
        case .workshop: "hammer"
        case .panel: "person.3"
        case .lightning: "bolt"
        case .breakout: "rectangle.split.2x1"
        case .meal: "cup.and.saucer"
        case .social: "party.popper"
        case .other: "calendar"
        }
    }
}
