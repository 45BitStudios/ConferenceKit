import Foundation
import Observation

@Observable
@MainActor
public final class FavoritesStore {
    public private(set) var ids: Set<String> = []
    public private(set) var speakerIDs: Set<String> = []
    public private(set) var conferenceID = "default"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
    }

    public func scope(to conferenceID: String) {
        self.conferenceID = conferenceID
        reload()
    }

    public func contains(_ sessionID: String) -> Bool {
        ids.contains(sessionID)
    }

    public func containsSpeaker(_ speakerID: String) -> Bool {
        speakerIDs.contains(speakerID)
    }

    @discardableResult
    public func toggle(_ sessionID: String) -> Bool {
        let favorite = !ids.contains(sessionID)
        set(sessionID, favorite: favorite)
        return favorite
    }

    public func set(_ sessionID: String, favorite: Bool) {
        if favorite {
            ids.insert(sessionID)
        } else {
            ids.remove(sessionID)
        }
        persist()
    }

    @discardableResult
    public func toggleSpeaker(_ speakerID: String) -> Bool {
        let favorite = !speakerIDs.contains(speakerID)
        if favorite {
            speakerIDs.insert(speakerID)
        } else {
            speakerIDs.remove(speakerID)
        }
        persist()
        return favorite
    }

    public func favoriteSessions(from sessions: [Session]) -> [Session] {
        sessions.filter { ids.contains($0.id) }.sorted { $0.startTime < $1.startTime }
    }

    public static func sessionKey(conferenceID: String) -> String {
        "conferencekit.favorites.\(conferenceID)"
    }

    public static func speakerKey(conferenceID: String) -> String {
        "conferencekit.speakerFavorites.\(conferenceID)"
    }

    public static func readSessionIDs(conferenceID: String, defaults: UserDefaults) -> Set<String> {
        Set(defaults.stringArray(forKey: sessionKey(conferenceID: conferenceID)) ?? [])
    }

    private var sessionStorageKey: String { Self.sessionKey(conferenceID: conferenceID) }
    private var speakerStorageKey: String { Self.speakerKey(conferenceID: conferenceID) }

    private func reload() {
        ids = Set(defaults.stringArray(forKey: sessionStorageKey) ?? [])
        speakerIDs = Set(defaults.stringArray(forKey: speakerStorageKey) ?? [])
    }

    private func persist() {
        defaults.set(Array(ids).sorted(), forKey: sessionStorageKey)
        defaults.set(Array(speakerIDs).sorted(), forKey: speakerStorageKey)
    }
}
