import Foundation

public struct ConferenceSnapshot: Codable, Hashable, Sendable {
    public var manifest: ConferenceManifest
    public var favoriteSessionIDs: [String]
    public var favoriteSpeakerIDs: [String]
    public var savedAt: Date
    public var reminderLeadTime: TimeInterval
    public var remindersEnabled: Bool

    public init(
        manifest: ConferenceManifest,
        favoriteSessionIDs: [String],
        favoriteSpeakerIDs: [String],
        savedAt: Date = .now,
        reminderLeadTime: TimeInterval,
        remindersEnabled: Bool
    ) {
        self.manifest = manifest
        self.favoriteSessionIDs = favoriteSessionIDs
        self.favoriteSpeakerIDs = favoriteSpeakerIDs
        self.savedAt = savedAt
        self.reminderLeadTime = reminderLeadTime
        self.remindersEnabled = remindersEnabled
    }
}

public enum ConferenceSnapshotStore {
    public static let filename = "conference-snapshot.json"

    public static func save(_ snapshot: ConferenceSnapshot, configuration: ConferenceKitConfiguration = .shared) throws {
        let directory = directoryURL(configuration: configuration)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try ConferenceLoader.makeEncoder().encode(snapshot)
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
    }

    public static func load(configuration: ConferenceKitConfiguration = .shared) -> ConferenceSnapshot? {
        let url = directoryURL(configuration: configuration).appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? ConferenceLoader().decodeSnapshot(data)
    }

    private static func directoryURL(configuration: ConferenceKitConfiguration) -> URL {
        configuration.appGroupContainer() ?? configuration.cacheDirectory()
    }
}
