import Foundation

/// Checks a note that a model or a person drafted before it is saved.
public enum SessionNoteDraftRules {
    public static let maximumLength = 2_000

    public enum Problem: Error, Equatable, Sendable {
        case empty
        case tooLong(count: Int)
    }

    /// Returns the trimmed text, or the reason it can't be saved.
    public static func validated(_ text: String) -> Result<String, Problem> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard trimmed.count <= maximumLength else { return .failure(.tooLong(count: trimmed.count)) }
        return .success(trimmed)
    }
}

/// Plain text used when a session or speaker is shared. It never includes the person's notes.
public enum ConferenceShareText {
    public static func session(title: String, when: String, room: String?, speakers: String) -> String {
        var lines = [title]
        let place = [when, room].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " · ")
        if !place.isEmpty { lines.append(place) }
        if !speakers.isEmpty { lines.append(speakers) }
        return lines.joined(separator: "\n")
    }

    public static func speaker(name: String, affiliation: String) -> String {
        affiliation.isEmpty ? name : "\(name), \(affiliation)"
    }
}
