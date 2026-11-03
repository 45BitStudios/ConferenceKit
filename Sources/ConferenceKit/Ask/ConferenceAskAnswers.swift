import Foundation

public enum ConferenceAskKind: String, Sendable, Equatable {
    case whenSpeaking
    case nextInRoom
    case whatsNext
    case summarizeNotes
    case favorites
    case unknown

    public var skillID: String { rawValue }
}

public struct ConferenceAskCatalog: Sendable, Equatable {
    public var manifest: ConferenceManifest
    public var notes: [SessionNote]
    public var favoriteSessionIDs: Set<String>
    public var now: Date

    public init(
        manifest: ConferenceManifest,
        notes: [SessionNote] = [],
        favoriteSessionIDs: Set<String> = [],
        now: Date = .now
    ) {
        self.manifest = manifest
        self.notes = notes
        self.favoriteSessionIDs = favoriteSessionIDs
        self.now = now
    }
}

public struct ConferenceAskAnswer: Sendable, Equatable {
    public var kind: ConferenceAskKind
    public var slots: [String: String]
    public var spoken: String
    public var facts: String

    public init(kind: ConferenceAskKind, slots: [String: String], spoken: String, facts: String) {
        self.kind = kind
        self.slots = slots
        self.spoken = spoken
        self.facts = facts
    }
}

/// Answers conference questions from the manifest, notes, and favorites.
/// AskKit skills call this. The model is not asked to invent a time.
public enum ConferenceAskAnswers {
    public static func classify(_ utterance: String) -> (kind: ConferenceAskKind, slots: [String: String]) {
        let text = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        if lower.contains("note") {
            return (.summarizeNotes, ["day": daySlot(in: lower)])
        }
        if lower.contains("favorite") || lower.contains("save") || lower.contains("my schedule") {
            return (.favorites, [:])
        }
        if let room = roomPhrase(in: lower), lower.contains("next") || lower.contains("on now") || lower.contains("happening") {
            return (.nextInRoom, ["room": room])
        }
        if let name = speakerPhrase(in: text) {
            return (.whenSpeaking, ["speaker": name])
        }
        if lower.contains("next") || lower.contains("on now") || lower.contains("happening") || lower.contains("what's on") || lower.contains("whats on") {
            return (.whatsNext, [:])
        }
        return (.unknown, [:])
    }

    public static func reply(utterance: String, slots: [String: String] = [:], catalog: ConferenceAskCatalog) -> ConferenceAskAnswer {
        let classified = classify(utterance)
        var merged = classified.slots
        for (key, value) in slots where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merged[key] = value
        }
        let kind = classified.kind == .unknown && merged["speaker"] != nil ? ConferenceAskKind.whenSpeaking : classified.kind
        let spoken: String
        switch kind {
        case .whenSpeaking:
            spoken = whenSpeaking(named: merged["speaker"] ?? "", catalog: catalog)
        case .nextInRoom:
            spoken = nextInRoom(named: merged["room"] ?? "", catalog: catalog)
        case .whatsNext:
            spoken = whatsNext(catalog: catalog)
        case .summarizeNotes:
            spoken = summarizeNotes(day: merged["day"] ?? "", catalog: catalog)
        case .favorites:
            spoken = favorites(catalog: catalog)
        case .unknown:
            spoken = "I can tell you when someone is speaking, what’s next, what’s next in a room, your saved sessions, or a summary of your notes."
        }
        return ConferenceAskAnswer(kind: kind, slots: merged, spoken: spoken, facts: spoken)
    }

    public static func whenSpeaking(named query: String, catalog: ConferenceAskCatalog) -> String {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "Which speaker?" }
        let speakers = catalog.manifest.speakers.filter {
            $0.name.localizedStandardContains(name) || name.localizedStandardContains($0.name)
        }
        guard let speaker = speakers.first else { return "I don’t see a speaker named \(name)." }
        let sessions = catalog.manifest.sessions(for: speaker.id)
        guard !sessions.isEmpty else { return "\(speaker.name) isn’t on the schedule." }
        let clock = catalog.manifest.clock
        let lines = sessions.map { session in
            let when = clock.rangeString(from: session.startTime, to: session.endTime)
            let room = session.roomID.flatMap { catalog.manifest.room(id: $0)?.name }
            return [session.title, when, room].compactMap { $0 }.joined(separator: ", ")
        }
        return "\(speaker.name) is speaking at \(lines.joined(separator: "; "))."
    }

    public static func nextInRoom(named query: String, catalog: ConferenceAskCatalog) -> String {
        guard let room = matchRoom(query, catalog: catalog) else {
            return query.isEmpty ? "Which room?" : "I don’t see a room called \(query)."
        }
        let inRoom = catalog.manifest.sessions.filter { $0.roomID == room.id }
        if let live = ConferenceSearch.liveSessions(in: inRoom, at: catalog.now).first {
            return "\(live.title) is on now in \(room.name)."
        }
        if let next = ConferenceSearch.nextUp(in: inRoom, at: catalog.now).first {
            let when = catalog.manifest.clock.timeString(next.startTime)
            return "Next in \(room.name) is \(next.title) at \(when)."
        }
        return "Nothing else is scheduled in \(room.name)."
    }

    public static func whatsNext(catalog: ConferenceAskCatalog) -> String {
        if let live = ConferenceSearch.liveSessions(in: catalog.manifest.sessions, at: catalog.now).first {
            let room = live.roomID.flatMap { catalog.manifest.room(id: $0)?.name }
            return room.map { "\(live.title) is on now in \($0)." } ?? "\(live.title) is on now."
        }
        if let next = ConferenceSearch.nextUp(in: catalog.manifest.sessions, at: catalog.now).first {
            let when = catalog.manifest.clock.timeString(next.startTime)
            return "Next is \(next.title) at \(when)."
        }
        return "Nothing else is scheduled."
    }

    public static func summarizeNotes(day query: String, catalog: ConferenceAskCatalog) -> String {
        let day = resolveDay(query, catalog: catalog)
        let sessions = day.map { catalog.manifest.sessions(on: $0) } ?? catalog.manifest.sessions
        let ids = Set(sessions.map(\.id))
        let notes = catalog.notes.filter { ids.contains($0.sessionID) }.sorted { $0.createdAt < $1.createdAt }
        guard !notes.isEmpty else {
            return day == nil ? "You don’t have notes yet." : "You don’t have notes for that day."
        }
        let clock = catalog.manifest.clock
        let lines = notes.prefix(8).map { note in
            let title = catalog.manifest.session(id: note.sessionID)?.title ?? "Session"
            let stamp = note.offsetFromStart.map { " \(SessionProgress.offsetLabel($0))" } ?? ""
            let mark = note.isTakeaway ? "Takeaway: " : ""
            return "\(title)\(stamp): \(mark)\(note.body)"
        }
        let label = day.map { clock.dayString($0) } ?? "the conference"
        return "Notes from \(label). " + lines.joined(separator: " ")
    }

    public static func favorites(catalog: ConferenceAskCatalog) -> String {
        let saved = catalog.manifest.sessions.filter { catalog.favoriteSessionIDs.contains($0.id) }
        guard !saved.isEmpty else { return "You haven’t saved any sessions." }
        let clock = catalog.manifest.clock
        let lines = saved.sorted { $0.startTime < $1.startTime }.map { session in
            "\(session.title) at \(clock.timeString(session.startTime))"
        }
        return "You saved \(lines.joined(separator: "; "))."
    }

    private static func matchRoom(_ query: String, catalog: ConferenceAskCatalog) -> Room? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return catalog.manifest.rooms.first { room in
            room.name.localizedStandardContains(trimmed) || trimmed.localizedStandardContains(room.name)
        }
    }

    private static func resolveDay(_ query: String, catalog: ConferenceAskCatalog) -> Date? {
        let days = catalog.manifest.conferenceDays
        let lower = query.lowercased()
        if let number = lower.split(whereSeparator: { !$0.isNumber }).first, let index = Int(number), index >= 1, index <= days.count {
            return days[index - 1].start
        }
        if lower.contains("today") { return catalog.manifest.clock.startOfDay(for: catalog.now) }
        return days.first?.start
    }

    private static func daySlot(in lower: String) -> String {
        if let range = lower.range(of: "day ") {
            return String(lower[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if lower.contains("today") { return "today" }
        return "1"
    }

    private static func roomPhrase(in lower: String) -> String? {
        let markers = ["in room ", "in the ", "in "]
        for marker in markers {
            guard let range = lower.range(of: marker) else { continue }
            var phrase = String(lower[range.upperBound...])
            for tail in ["?", ".", "!"] {
                if let end = phrase.range(of: tail) { phrase = String(phrase[..<end.lowerBound]) }
            }
            phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            if !phrase.isEmpty { return phrase }
        }
        return nil
    }

    private static func speakerPhrase(in text: String) -> String? {
        let lower = text.lowercased()
        let patterns = ["when is ", "when does ", "when's ", "whens "]
        for pattern in patterns {
            guard let range = lower.range(of: pattern) else { continue }
            var name = String(text[range.upperBound...])
            let stops = [" speaking", " speak", " talks", " talk", " on", "?"]
            let lowerName = name.lowercased()
            for stop in stops {
                if let end = lowerName.range(of: stop) {
                    name = String(name[..<end.lowerBound])
                    break
                }
            }
            name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
        }
        return nil
    }
}
