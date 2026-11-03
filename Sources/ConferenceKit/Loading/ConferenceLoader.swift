import Foundation

public enum RemoteLoadPolicy: Sendable, Hashable {
    /// Download every time. Fail if the network fails.
    case networkOnly
    /// Show the last good JSON immediately, then replace it when the download succeeds.
    case cacheThenRefresh
    /// Never touch the network. Fail if nothing is cached.
    case cacheOnly
}

public enum ConferenceSource: Sendable {
    /// JSON file in the *host app* bundle (`conference.json`).
    case bundled(name: String, bundle: Bundle = .main)
    /// JSON shipped inside ConferenceKit (used for previews and first run).
    case sample
    /// Remote schedule the organizer can update without shipping a binary.
    case remote(URL, policy: RemoteLoadPolicy = .cacheThenRefresh)
    /// Already-decoded document.
    case manifest(ConferenceManifest)

    var refreshesFromNetwork: Bool {
        if case .remote(_, .cacheThenRefresh) = self { return true }
        if case .remote(_, .networkOnly) = self { return false }
        return false
    }
}

public enum ConferenceLoadError: LocalizedError, Equatable, Sendable {
    case missingResource(String)
    case decoding(String)
    case network(String)
    case emptyCache

    public var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            "Could not find conference JSON named “\(name)”."
        case .decoding(let message):
            "Conference JSON could not be read: \(message)"
        case .network(let message):
            "Could not download conference JSON: \(message)"
        case .emptyCache:
            "No saved conference JSON is available offline."
        }
    }
}

public struct ConferenceLoader: Sendable {
    private let cacheDirectoryOverride: URL?
    private let configuration: ConferenceKitConfiguration

    public init(cacheDirectory: URL? = nil, configuration: ConferenceKitConfiguration = .shared) {
        self.cacheDirectoryOverride = cacheDirectory
        self.configuration = configuration
    }

    public func load(_ source: ConferenceSource) async throws -> ConferenceManifest {
        try await loadReportingCache(source).manifest
    }

    /// `fromCache` is true when a disk copy was returned and a network refresh may still be newer.
    public func loadReportingCache(_ source: ConferenceSource) async throws -> (manifest: ConferenceManifest, fromCache: Bool) {
        switch source {
        case .manifest(let manifest):
            return (manifest, false)
        case .sample:
            return (try decode(data: try sampleData()), false)
        case .bundled(let name, let bundle):
            guard let url = bundle.url(forResource: name, withExtension: "json") else {
                throw ConferenceLoadError.missingResource(name)
            }
            return (try decode(data: try Data(contentsOf: url)), false)
        case .remote(let url, let policy):
            switch policy {
            case .networkOnly:
                return (try await download(url), false)
            case .cacheOnly:
                guard let cached = cached(for: url) else { throw ConferenceLoadError.emptyCache }
                return (cached, true)
            case .cacheThenRefresh:
                if let cached = cached(for: url) { return (cached, true) }
                return (try await download(url), false)
            }
        }
    }

    public func refresh(_ source: ConferenceSource) async throws -> ConferenceManifest {
        guard case .remote(let url, _) = source else {
            return try await load(source)
        }
        return try await download(url)
    }

    public func decode(data: Data) throws -> ConferenceManifest {
        do {
            return try Self.makeDecoder().decode(ConferenceManifest.self, from: data)
        } catch {
            throw ConferenceLoadError.decoding(error.localizedDescription)
        }
    }

    public func decodeSnapshot(_ data: Data) throws -> ConferenceSnapshot {
        try Self.makeDecoder().decode(ConferenceSnapshot.self, from: data)
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = Self.parseISO8601(raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized ISO-8601 date: \(raw)"
            )
        }
        return decoder
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.formatISO8601(date))
        }
        return encoder
    }

    public static func parseISO8601(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: raw)
    }

    public static func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func download(_ url: URL) async throws -> ConferenceManifest {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw ConferenceLoadError.network("The server returned an error.")
            }
            let manifest = try decode(data: data)
            try? data.write(to: cacheURL(for: url), options: .atomic)
            return manifest
        } catch let error as ConferenceLoadError {
            throw error
        } catch {
            throw ConferenceLoadError.network(error.localizedDescription)
        }
    }

    private func cached(for url: URL) -> ConferenceManifest? {
        guard let data = try? Data(contentsOf: cacheURL(for: url)) else { return nil }
        return try? decode(data: data)
    }

    private func cacheURL(for url: URL) -> URL {
        let directory = cacheDirectoryOverride ?? configuration.cacheDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = stableFilename(for: url)
        return directory.appendingPathComponent(name)
    }

    private func stableFilename(for url: URL) -> String {
        let raw = Array(url.absoluteString.utf8)
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in raw {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "remote-\(String(hash, radix: 16)).json"
    }

    private func sampleData() throws -> Data {
        guard let url = Bundle.module.url(forResource: "SampleConference", withExtension: "json") else {
            throw ConferenceLoadError.missingResource("SampleConference")
        }
        return try Data(contentsOf: url)
    }
}
