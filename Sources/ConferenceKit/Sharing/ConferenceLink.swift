import Foundation

public enum ConferenceLink: Hashable, Sendable {
    case session(String)
    case speaker(String)
    case schedule
    case favorites
    case info

    public func url(conference: ConferenceInfo) -> URL {
        if let base = conference.url {
            return url(base: base)
        }
        return fallbackURL
    }

    public static func parse(_ url: URL) -> ConferenceLink? {
        let parts = url.pathComponents.filter { $0 != "/" }
        if url.scheme == "conferencekit" {
            return parse(host: url.host, parts: parts)
        }
        guard parts.count >= 1 else { return nil }
        if let host = url.host, host == "session" || host == "speaker" {
            return parse(host: host, parts: parts)
        }
        if parts.count >= 2 {
            return parse(host: parts[parts.count - 2], parts: [parts[parts.count - 1]])
        }
        return parse(host: parts.last, parts: [])
    }

    private func url(base: URL) -> URL {
        switch self {
        case .session(let id):
            return base.appending(path: "session").appending(path: id)
        case .speaker(let id):
            return base.appending(path: "speaker").appending(path: id)
        case .schedule:
            return base.appending(path: "schedule")
        case .favorites:
            return base.appending(path: "favorites")
        case .info:
            return base.appending(path: "info")
        }
    }

    private var fallbackURL: URL {
        switch self {
        case .session(let id):
            return URL(string: "conferencekit://session/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)")!
        case .speaker(let id):
            return URL(string: "conferencekit://speaker/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)")!
        case .schedule:
            return URL(string: "conferencekit://schedule")!
        case .favorites:
            return URL(string: "conferencekit://favorites")!
        case .info:
            return URL(string: "conferencekit://info")!
        }
    }

    private static func parse(host: String?, parts: [String]) -> ConferenceLink? {
        switch host {
        case "session":
            guard let id = parts.first, !id.isEmpty else { return nil }
            return .session(id)
        case "speaker":
            guard let id = parts.first, !id.isEmpty else { return nil }
            return .speaker(id)
        case "schedule":
            return .schedule
        case "favorites":
            return .favorites
        case "info":
            return .info
        default:
            return nil
        }
    }
}

public enum StableIdentifier {
    /// Stable UUID for alarms and notification ids. Same input, same id.
    public static func uuid(namespace: String, value: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        let source = Array("\(namespace)#\(value)".utf8)
        for (index, byte) in source.enumerated() {
            bytes[index % 16] ^= byte
            bytes[(index * 7 + 3) % 16] = bytes[(index * 7 + 3) % 16] &+ byte &+ UInt8(index % 251)
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
