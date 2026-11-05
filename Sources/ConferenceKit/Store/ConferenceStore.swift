import Foundation
import Observation

@Observable
@MainActor
public final class ConferenceStore {
    public private(set) var manifest: ConferenceManifest?
    public private(set) var isLoading = false
    public private(set) var isRefreshing = false
    public private(set) var isStale = false
    public private(set) var lastError: String?
    public private(set) var validationIssues: [ManifestIssue] = []
    public let favorites: FavoritesStore
    public var selectedSessionID: String?
    public var selectedSpeakerID: String?
    public private(set) var notesStore: NotesStore?
    public var searchText = ""
    public var timeDisplay: TimeDisplay = .conference
    public var reminderPreferences = ReminderPreferences.default
    public private(set) var announcementNotificationsEnabled: Bool
    public private(set) var resourceLibrary: ResourceLibrary?

    private let loader: ConferenceLoader
    private let source: ConferenceSource
    private let configuration: ConferenceKitConfiguration

    public init(
        source: ConferenceSource,
        favorites: FavoritesStore? = nil,
        configuration: ConferenceKitConfiguration = .shared,
        loader: ConferenceLoader = ConferenceLoader()
    ) {
        self.source = source
        self.configuration = configuration
        self.loader = loader
        self.favorites = favorites ?? FavoritesStore(defaults: configuration.resolvedDefaults())
        if let stored = ReminderPreferences.load(from: configuration.resolvedDefaults()) {
            reminderPreferences = stored
        }
        announcementNotificationsEnabled = AnnouncementLedger.isEnabled(configuration.resolvedDefaults())
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

    public var conferenceDays: [ConferenceDay] {
        manifest?.conferenceDays ?? []
    }

    public var clock: ConferenceClock {
        manifest?.clock ?? ConferenceClock(timeZone: .current)
    }

    public var tracks: [Track] { manifest?.tracks ?? [] }
    public var rooms: [Room] { manifest?.rooms ?? [] }
    public var sponsors: [Sponsor] { manifest?.sponsors ?? [] }
    public var organizers: [Organizer] { manifest?.organizers ?? [] }
    public var announcements: [Announcement] {
        (manifest?.announcements ?? []).sorted { $0.postedAt > $1.postedAt }
    }
    public var newsItems: [ConferenceNewsItem] {
        NewsFeed.sorted(manifest?.news ?? [])
    }
    public var resources: [ConferenceResource] { manifest?.resources ?? [] }
    public var conferencePass: ConferencePass? { manifest?.pass }
    public var workshops: [Session] { manifest?.workshops ?? [] }

    public var liveSessions: [Session] {
        ConferenceSearch.liveSessions(in: sessions)
    }

    public var nextSessions: [Session] {
        ConferenceSearch.nextUp(in: sessions)
    }

    public var nowAndNext: (now: Session?, next: Session?) {
        (liveSessions.first, nextSessions.first)
    }

    public var favoriteSessions: [Session] {
        favorites.favoriteSessions(from: sessions)
    }

    public func filteredSessions(filter: SessionFilter) -> [Session] {
        guard let manifest else { return [] }
        return ConferenceSearch.sessions(
            in: manifest,
            matching: filter,
            favoriteIDs: favorites.ids,
            clock: clock
        )
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

    public func room(for session: Session) -> Room? {
        session.roomID.flatMap { manifest?.room(id: $0) }
    }

    public func roomName(for session: Session) -> String? {
        room(for: session)?.name
    }

    public func track(for session: Session) -> Track? {
        session.trackID.flatMap { manifest?.track(id: $0) }
    }

    public func shareURL(for link: ConferenceLink) -> URL? {
        guard let conference = manifest?.conference else { return nil }
        return link.url(conference: conference)
    }

    public func load() async {
        isLoading = manifest == nil
        lastError = nil
        defer { isLoading = false }
        let servedFromCache: Bool
        do {
            let loaded = try await loader.loadReportingCache(source)
            servedFromCache = loaded.fromCache
            apply(loaded.manifest, stale: servedFromCache)
        } catch {
            lastError = error.localizedDescription
            return
        }

        guard servedFromCache, source.refreshesFromNetwork else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let fresh = try await loader.refresh(source)
            apply(fresh, stale: false)
        } catch {
            isStale = manifest != nil
            lastError = error.localizedDescription
        }
    }

    public func setRemindersEnabled(_ enabled: Bool) {
        reminderPreferences.enabled = enabled
        persistReminderPreferences()
    }

    public func setReminderLeadTime(_ leadTime: TimeInterval) {
        reminderPreferences.leadTime = leadTime
        persistReminderPreferences()
    }

    public func setAnnouncementNotificationsEnabled(_ enabled: Bool) {
        announcementNotificationsEnabled = enabled
        AnnouncementLedger.setEnabled(enabled, defaults: configuration.resolvedDefaults())
    }

    private func persistReminderPreferences() {
        reminderPreferences.save(to: configuration.resolvedDefaults())
        publishSnapshot()
    }

    private func apply(_ loaded: ConferenceManifest, stale: Bool) {
        manifest = loaded
        isStale = stale
        validationIssues = loaded.validate()
        favorites.scope(to: loaded.conference.id)
        if notesStore?.conferenceID != loaded.conference.id {
            notesStore = NotesStore(conferenceID: loaded.conference.id, configuration: configuration)
        }
        resourceLibrary = ResourceLibrary(
            directory: configuration.resourcesDirectory(conferenceID: loaded.conference.id),
            resources: loaded.resources
        )
        publishSnapshot()
        let sessions = favorites.ids
        let speakers = favorites.speakerIDs
        Task {
            await ConferenceCatalog.shared.update(
                manifest: loaded,
                favoriteSessionIDs: sessions,
                favoriteSpeakerIDs: speakers
            )
        }
    }

    public func publishFavorites() {
        publishSnapshot()
        guard let manifest else { return }
        let sessions = favorites.ids
        let speakers = favorites.speakerIDs
        Task {
            await ConferenceCatalog.shared.updateFavorites(sessions: sessions, speakers: speakers)
            await ConferenceCatalog.shared.update(
                manifest: manifest,
                favoriteSessionIDs: sessions,
                favoriteSpeakerIDs: speakers
            )
        }
    }

    private func publishSnapshot() {
        guard let manifest else { return }
        let snapshot = ConferenceSnapshot(
            manifest: manifest,
            favoriteSessionIDs: favorites.ids.sorted(),
            favoriteSpeakerIDs: favorites.speakerIDs.sorted(),
            reminderLeadTime: reminderPreferences.leadTime,
            remindersEnabled: reminderPreferences.enabled
        )
        try? ConferenceSnapshotStore.save(snapshot, configuration: configuration)
    }
}

public struct ReminderPreferences: Codable, Hashable, Sendable {
    public var leadTime: TimeInterval
    public var enabled: Bool

    public static let `default` = ReminderPreferences(leadTime: 10 * 60, enabled: true)

    public init(leadTime: TimeInterval, enabled: Bool) {
        self.leadTime = leadTime
        self.enabled = enabled
    }

    public static let storageKey = "conferencekit.reminderPreferences"

    public static func load(from defaults: UserDefaults) -> ReminderPreferences? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(ReminderPreferences.self, from: data)
    }

    public func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
