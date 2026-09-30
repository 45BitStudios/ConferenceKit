import Foundation
import Observation

@Observable
@MainActor
public final class FavoritesStore {
    public private(set) var ids: Set<String> = []
    private var conferenceID = "default"
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

    public func toggle(_ sessionID: String) {
        if ids.contains(sessionID) {
            ids.remove(sessionID)
        } else {
            ids.insert(sessionID)
        }
        persist()
    }

    public func favoriteSessions(from sessions: [Session]) -> [Session] {
        sessions.filter { ids.contains($0.id) }.sorted { $0.startTime < $1.startTime }
    }

    private var storageKey: String {
        "conferencekit.favorites.\(conferenceID)"
    }

    private func reload() {
        let stored = defaults.stringArray(forKey: storageKey) ?? []
        ids = Set(stored)
    }

    private func persist() {
        defaults.set(Array(ids), forKey: storageKey)
    }
}
