import ConferenceKit
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum IntentCatalog {
    static func manifest() async -> ConferenceManifest? {
        if let current = await ConferenceCatalog.shared.current() {
            return current
        }
        guard let snapshot = ConferenceSnapshotStore.load() else { return nil }
        await ConferenceCatalog.shared.update(
            manifest: snapshot.manifest,
            favoriteSessionIDs: Set(snapshot.favoriteSessionIDs),
            favoriteSpeakerIDs: Set(snapshot.favoriteSpeakerIDs)
        )
        return snapshot.manifest
    }

    static func favoriteSessionIDs() async -> Set<String> {
        if let manifest = await ConferenceCatalog.shared.current() {
            let stored = FavoritesStore.readSessionIDs(
                conferenceID: manifest.conference.id,
                defaults: ConferenceKitConfiguration.shared.resolvedDefaults()
            )
            if !stored.isEmpty || await ConferenceCatalog.shared.favoriteSessionIDs().isEmpty {
                return stored
            }
        }
        return await ConferenceCatalog.shared.favoriteSessionIDs()
    }
}

enum FavoriteMutator {
    @MainActor
    static func setSession(id: String, favorite: Bool) async -> String {
        if let store = ConferenceRuntime.shared.store {
            store.favorites.set(id, favorite: favorite)
            store.publishFavorites()
            if let manifest = store.manifest {
                _ = await SessionReminderCenter.shared.sync(
                    manifest: manifest,
                    favoriteIDs: store.favorites.ids,
                    preferences: store.reminderPreferences,
                    defaults: ConferenceKitConfiguration.shared.resolvedDefaults()
                )
            }
            reloadWidgets()
            let title = store.session(id: id)?.title ?? "Session"
            return favorite ? "Saved \(title)." : "Removed \(title) from My Schedule."
        }
        return await setSessionWithoutStore(id: id, favorite: favorite)
    }

    @MainActor
    static func setSpeaker(id: String, favorite: Bool) async -> String {
        if let store = ConferenceRuntime.shared.store {
            if favorite {
                if !store.favorites.containsSpeaker(id) { _ = store.favorites.toggleSpeaker(id) }
            } else if store.favorites.containsSpeaker(id) {
                _ = store.favorites.toggleSpeaker(id)
            }
            store.publishFavorites()
            reloadWidgets()
            let name = store.speaker(id: id)?.name ?? "Speaker"
            return favorite ? "Saved \(name)." : "Removed \(name)."
        }
        guard var snapshot = ConferenceSnapshotStore.load() else { return "No conference is loaded." }
        var ids = Set(snapshot.favoriteSpeakerIDs)
        if favorite { ids.insert(id) } else { ids.remove(id) }
        let defaults = ConferenceKitConfiguration.shared.resolvedDefaults()
        defaults.set(ids.sorted(), forKey: FavoritesStore.speakerKey(conferenceID: snapshot.manifest.conference.id))
        snapshot.favoriteSpeakerIDs = ids.sorted()
        try? ConferenceSnapshotStore.save(snapshot)
        await ConferenceCatalog.shared.updateFavorites(sessions: Set(snapshot.favoriteSessionIDs), speakers: ids)
        reloadWidgets()
        return favorite ? "Saved speaker." : "Removed speaker."
    }

    private static func setSessionWithoutStore(id: String, favorite: Bool) async -> String {
        guard var snapshot = ConferenceSnapshotStore.load() else { return "No conference is loaded." }
        var ids = Set(snapshot.favoriteSessionIDs)
        if favorite { ids.insert(id) } else { ids.remove(id) }
        let defaults = ConferenceKitConfiguration.shared.resolvedDefaults()
        defaults.set(ids.sorted(), forKey: FavoritesStore.sessionKey(conferenceID: snapshot.manifest.conference.id))
        snapshot.favoriteSessionIDs = ids.sorted()
        try? ConferenceSnapshotStore.save(snapshot)
        await ConferenceCatalog.shared.update(
            manifest: snapshot.manifest,
            favoriteSessionIDs: ids,
            favoriteSpeakerIDs: Set(snapshot.favoriteSpeakerIDs)
        )
        let preferences = ReminderPreferences(leadTime: snapshot.reminderLeadTime, enabled: snapshot.remindersEnabled)
        _ = await SessionReminderCenter.shared.sync(
            manifest: snapshot.manifest,
            favoriteIDs: ids,
            preferences: preferences,
            defaults: defaults
        )
        reloadWidgets()
        let title = snapshot.manifest.session(id: id)?.title ?? "Session"
        return favorite ? "Saved \(title)." : "Removed \(title) from My Schedule."
    }

    static func reloadWidgets() {
        #if canImport(WidgetKit) && !os(tvOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
