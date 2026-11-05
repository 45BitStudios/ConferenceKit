import Foundation

/// In-process manifest used by App Intents and tests.
/// Widgets in another process read `ConferenceSnapshotStore` instead.
public actor ConferenceCatalog {
    public static let shared = ConferenceCatalog()

    private var manifest: ConferenceManifest?
    private var storedFavoriteSessionIDs: Set<String> = []
    private var storedFavoriteSpeakerIDs: Set<String> = []
    private var storedCurrentAttendee: Attendee?

    public func update(
        manifest: ConferenceManifest,
        favoriteSessionIDs: Set<String>,
        favoriteSpeakerIDs: Set<String>
    ) {
        self.manifest = manifest
        storedFavoriteSessionIDs = favoriteSessionIDs
        storedFavoriteSpeakerIDs = favoriteSpeakerIDs
    }

    public func updateFavorites(sessions: Set<String>, speakers: Set<String>) {
        storedFavoriteSessionIDs = sessions
        storedFavoriteSpeakerIDs = speakers
    }

    public func current() -> ConferenceManifest? {
        manifest
    }

    public func favoriteSessionIDs() -> Set<String> {
        storedFavoriteSessionIDs
    }

    public func favoriteSpeakerIDs() -> Set<String> {
        storedFavoriteSpeakerIDs
    }

    public func updateCurrentAttendee(_ attendee: Attendee?) {
        storedCurrentAttendee = attendee
    }

    public func currentAttendee() -> Attendee? {
        storedCurrentAttendee
    }

    /// Test and intent helper. Production UI publishes through the store.
    public func reset() {
        manifest = nil
        storedFavoriteSessionIDs = []
        storedFavoriteSpeakerIDs = []
        storedCurrentAttendee = nil
    }
}
