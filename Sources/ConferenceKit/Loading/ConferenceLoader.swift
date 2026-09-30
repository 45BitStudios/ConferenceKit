import Foundation

public enum ConferenceSource: Sendable {
    /// JSON file in the *host app* bundle (`conference.json`).
    case bundled(name: String, bundle: Bundle = .main)
    /// JSON shipped inside ConferenceKit (used for previews and first run).
    case sample
    /// Remote schedule the organizer can update without shipping a binary.
    case remote(URL)
    /// Already-decoded document.
    case manifest(ConferenceManifest)
}

public enum ConferenceLoadError: LocalizedError, Sendable {
    case missingResource(String)
    case decoding(Error)
    case network(Error)

    public var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            "Could not find conference JSON named \u201c\(name)\u201d."
        case .decoding(let error):
            "Conference JSON could not be read: \(error.localizedDescription)"
        case .network(let error):
            "Could not download conference JSON: \(error.localizedDescription)"
        }
    }
}

public struct ConferenceLoader: Sendable {
    public init() {}

    public func load(_ source: ConferenceSource) async throws -> ConferenceManifest {
        switch source {
        case .manifest(let manifest):
            return manifest
        case .sample:
            return try decode(data: try sampleData())
        case .bundled(let name, let bundle):
            guard let url = bundle.url(forResource: name, withExtension: "json") else {
                throw ConferenceLoadError.missingResource(name)
            }
            return try decode(data: try Data(contentsOf: url))
        case .remote(let url):
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                return try decode(data: data)
            } catch let error as ConferenceLoadError {
                throw error
            } catch {
                throw ConferenceLoadError.network(error)
            }
        }
    }

    public func decode(data: Data) throws -> ConferenceManifest {
        do {
            return try Self.makeDecoder().decode(ConferenceManifest.self, from: data)
        } catch {
            throw ConferenceLoadError.decoding(error)
        }
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = iso8601Fractional.date(from: raw) { return date }
            if let date = iso8601.date(from: raw) { return date }
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
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func sampleData() throws -> Data {
        guard let url = Bundle.module.url(forResource: "SampleConference", withExtension: "json") else {
            throw ConferenceLoadError.missingResource("SampleConference")
        }
        return try Data(contentsOf: url)
    }
}

private let iso8601: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

private let iso8601Fractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()
