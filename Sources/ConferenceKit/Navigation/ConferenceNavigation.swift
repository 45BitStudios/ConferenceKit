import Foundation
import Observation

public enum ConferenceDestination: String, Codable, Hashable, Sendable {
    case news
    case resources
    case pass
}

public enum ConferenceSection: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case schedule
    case speakers
    case favorites
    case workshops
    case info

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .schedule: "Schedule"
        case .speakers: "Speakers"
        case .favorites: "My Schedule"
        case .workshops: "Workshops"
        case .info: "Info"
        }
    }

    public var systemImage: String {
        switch self {
        case .schedule: "calendar"
        case .speakers: "person.2"
        case .favorites: "star"
        case .workshops: "hammer"
        case .info: "info.circle"
        }
    }
}

/// Cross-feature navigation bus. Intents and widgets write here; the root
/// view applies the request to the visible shell.
@Observable
@MainActor
public final class ConferenceNavigation {
    public static let shared = ConferenceNavigation()

    public var pendingSessionID: String?
    public var pendingSpeakerID: String?
    public var pendingSearch: String?
    public var pendingSection: ConferenceSection?
    public var pendingDestination: ConferenceDestination?
    public var pendingShowsNotes = false
    public var sceneActivationError: String?
    public var reminderMessage: String?

    public func openSession(id: String) {
        pendingSessionID = id
        pendingSection = .schedule
    }

    public func openNotes(sessionID: String) {
        pendingSessionID = sessionID
        pendingShowsNotes = true
        pendingSection = .schedule
    }

    public func openSpeaker(id: String) {
        pendingSpeakerID = id
        pendingSection = .speakers
    }

    public func search(_ query: String) {
        pendingSearch = query
        pendingSection = .schedule
    }

    public func show(_ section: ConferenceSection) {
        pendingSection = section
    }

    public func showDestination(_ destination: ConferenceDestination) {
        pendingSection = .info
        pendingDestination = destination
    }

    public func reportSceneActivationFailure(_ message: String) {
        sceneActivationError = message
    }
}

/// The live store, when the UI has installed one. Intents prefer this over
/// the snapshot so a favorite toggled from Shortcuts updates the screen.
@MainActor
public final class ConferenceRuntime {
    public static let shared = ConferenceRuntime()
    public weak var store: ConferenceStore?
}
