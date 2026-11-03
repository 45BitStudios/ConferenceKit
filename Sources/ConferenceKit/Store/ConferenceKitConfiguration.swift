import Foundation

/// Process-local settings. The app group id is read again in the widget
/// extension, so put `ConferenceKitAppGroup` in both Info.plists or call
/// `configure` from each process at launch.
public final class ConferenceKitConfiguration: @unchecked Sendable {
    public static let shared = ConferenceKitConfiguration()

    public static let appGroupInfoKey = "ConferenceKitAppGroup"

    private let lock = NSLock()
    private var appGroupIdentifier: String?
    private var cacheDirectoryOverride: URL?

    public func configure(appGroupIdentifier: String?, cacheDirectory: URL? = nil) {
        lock.lock()
        self.appGroupIdentifier = appGroupIdentifier
        if let cacheDirectory {
            cacheDirectoryOverride = cacheDirectory
        }
        lock.unlock()
    }

    public func resolvedAppGroupIdentifier() -> String? {
        lock.lock()
        let explicit = appGroupIdentifier
        lock.unlock()
        if let explicit, !explicit.isEmpty { return explicit }
        return Bundle.main.object(forInfoDictionaryKey: Self.appGroupInfoKey) as? String
    }

    public func resolvedDefaults() -> UserDefaults {
        if let suite = resolvedAppGroupIdentifier(), let defaults = UserDefaults(suiteName: suite) {
            return defaults
        }
        return .standard
    }

    public func cacheDirectory() -> URL {
        lock.lock()
        let override = cacheDirectoryOverride
        lock.unlock()
        if let override { return override }
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("ConferenceKit", isDirectory: true)
    }

    public func appGroupContainer() -> URL? {
        guard let suite = resolvedAppGroupIdentifier() else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suite)
    }

    public func notesDirectory(conferenceID: String) -> URL {
        let root = appGroupContainer()
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? cacheDirectory()
        return root
            .appendingPathComponent("ConferenceKit", isDirectory: true)
            .appendingPathComponent("Notes", isDirectory: true)
            .appendingPathComponent(conferenceID, isDirectory: true)
    }
}
