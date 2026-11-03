import Foundation

public struct SessionFilter: Hashable, Sendable {
    public var query: String
    public var trackID: String?
    public var roomID: String?
    public var kind: SessionKind?
    public var favoritesOnly: Bool
    public var day: Date?

    public init(
        query: String = "",
        trackID: String? = nil,
        roomID: String? = nil,
        kind: SessionKind? = nil,
        favoritesOnly: Bool = false,
        day: Date? = nil
    ) {
        self.query = query
        self.trackID = trackID
        self.roomID = roomID
        self.kind = kind
        self.favoritesOnly = favoritesOnly
        self.day = day
    }

    public var isNarrowing: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || trackID != nil
            || roomID != nil
            || kind != nil
            || favoritesOnly
            || day != nil
    }
}

public enum ConferenceSearch {
    public static func sessions(
        in manifest: ConferenceManifest,
        matching filter: SessionFilter,
        favoriteIDs: Set<String> = [],
        clock: ConferenceClock? = nil
    ) -> [Session] {
        let zoneClock = clock ?? ConferenceClock(timeZoneIdentifier: manifest.conference.timezone)
        let query = filter.query.trimmingCharacters(in: .whitespacesAndNewlines)
        return manifest.sessions
            .filter { session in
                if filter.favoritesOnly && !favoriteIDs.contains(session.id) { return false }
                if let trackID = filter.trackID, session.trackID != trackID { return false }
                if let roomID = filter.roomID, session.roomID != roomID { return false }
                if let kind = filter.kind, session.kind != kind { return false }
                if let day = filter.day, !zoneClock.isSameDay(session.startTime, day) { return false }
                if query.isEmpty { return true }
                if session.contains(query) { return true }
                let speakers = manifest.speakers(ids: session.speakerIDs)
                if speakers.contains(where: { $0.matches(query) }) { return true }
                if let track = session.trackID.flatMap({ manifest.track(id: $0) }),
                   track.name.localizedStandardContains(query) {
                    return true
                }
                if let room = session.roomID.flatMap({ manifest.room(id: $0) }),
                   room.name.localizedStandardContains(query) {
                    return true
                }
                return false
            }
            .sorted { $0.startTime < $1.startTime }
    }

    public static func speakers(in manifest: ConferenceManifest, matching query: String) -> [Speaker] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return manifest.speakers.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        return manifest.speakers
            .filter { $0.matches(trimmed) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public static func liveSessions(in sessions: [Session], at date: Date = .now) -> [Session] {
        sessions.filter { $0.isHappening(at: date) }.sorted { $0.startTime < $1.startTime }
    }

    /// The next start boundary after `date`, and every session that starts then.
    public static func nextUp(in sessions: [Session], at date: Date = .now) -> [Session] {
        let upcoming = sessions.filter { $0.startTime > date }.sorted { $0.startTime < $1.startTime }
        guard let first = upcoming.first else { return [] }
        return upcoming.filter { $0.startTime == first.startTime }
    }
}

extension Speaker {
    func matches(_ query: String) -> Bool {
        let fields: [String?] = [name, title, company, bio]
        return fields.contains { $0?.localizedStandardContains(query) == true }
            || social.contains { $0.platform.label.localizedStandardContains(query) }
    }
}
