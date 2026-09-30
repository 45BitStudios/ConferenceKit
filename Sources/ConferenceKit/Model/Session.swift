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

    public init(
        id: String,
        title: String,
        synopsis: String,
        startTime: Date,
        endTime: Date,
        speakerIDs: [String] = [],
        trackID: String? = nil,
        roomID: String? = nil,
        kind: SessionKind = .talk
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
}
