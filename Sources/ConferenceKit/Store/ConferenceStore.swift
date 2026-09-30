import Foundation
import Observation

@Observable
@MainActor
public final class ConferenceStore {
    public private(set) var manifest: ConferenceManifest?
    public private(set) var isLoading = false
    public private(set) var lastError: String?
    public let favorites: FavoritesStore
    public var selectedSessionID: String?
    public var selectedSpeakerID: String?

    private let loader = ConferenceLoader()
    private let source: ConferenceSource

    public init(source: ConferenceSource, favorites: FavoritesStore = FavoritesStore()) {
        self.source = source
        self.favorites = favorites
    }

    public var conferenceName: String {
        manifest?.conference.name ?? "Conference"
    }

    public var theme: ConferenceTheme {
        manifest?.theme ?? ConferenceTheme()
    }

    public var speakers: [Speaker] {
        manifest?.speakers ?? []
    }

    public var sessions: [Session] {
        (manifest?.sessions ?? []).sorted { $0.startTime < $1.startTime }
    }

    public var days: [(day: Date, sessions: [Session])] {
        manifest?.sessionsByDay ?? []
    }

    public var nowAndNext: (now: Session?, next: Session?) {
        let now = Date()
        let current = sessions.first { $0.isHappening(at: now) }
        let upcoming = sessions.first { $0.isUpcoming(at: now) }
        return (current, upcoming)
    }

    public func session(id: String) -> Session? {
        sessions.first { $0.id == id }
    }

    public func speaker(id: String) -> Speaker? {
        speakers.first { $0.id == id }
    }

    public func speakers(for session: Session) -> [Speaker] {
        manifest?.speakers(ids: session.speakerIDs) ?? []
    }

    public func roomName(for session: Session) -> String? {
        session.roomID.flatMap { manifest?.room(id: $0)?.name }
    }

    public func track(for session: Session) -> Track? {
        session.trackID.flatMap { manifest?.track(id: $0) }
    }

    public func load() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let loaded = try await loader.load(source)
            manifest = loaded
            favorites.scope(to: loaded.conference.id)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
