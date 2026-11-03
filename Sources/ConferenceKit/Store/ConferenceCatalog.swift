import Foundation

/// In-process manifest used by App Intents and tests.
/// Widgets in another process read `ConferenceSnapshotStore` instead.
public actor ConferenceCatalog {
    public static let shared = ConferenceCatalog()

    private var manifest: ConferenceManifest?
    private var favoriteSessionIDs: Set<String> = []
    private var favoriteSpeakerIDs: Set<String> = []

    public func update(
        manifest: ConferenceManifest,
        favoriteSessionIDs: Set<String>,
        favoriteSpeakerIDs: Set<String>
    ) {
        self.manifest = manifest
        self.favoriteSessionIDs = favoriteSessionIDs
        self.favoriteSpeakerIDs = favoriteSpeakerIDs
    }

    public func updateFavorites(sessions: Set<String>, speakers: Set<String>) {
        favoriteSessionIDs = sessions
        favoriteSpeakerIDs = speakers
    }

    public func current() -> ConferenceManifest? {
        manifest
    }

    public func favoriteSessionIDs() -> Set<String> {
        favoriteSessionIDs
    }

    public func favoriteSpeakerIDs() -> Set<String> {
        favoriteSpeakerIDs
    }

    /// Test and intent helper. Production UI publishes through the store.
    public func reset() {
        manifest = nil
        favoriteSessionIDs = []
        favoriteSpeakerIDs = []
    }
}
