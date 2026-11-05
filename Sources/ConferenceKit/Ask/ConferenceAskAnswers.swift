import Foundation

public enum ConferenceAskKind: String, Sendable, Equatable {
    case whenSpeaking
    case nextInRoom
    case whatsNext
    case summarizeNotes
    case dayAgenda
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
        if let day = dayNumberPhrase(in: lower) {
            return (.dayAgenda, ["day": day])
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
        case .dayAgenda:
            spoken = dayAgenda(day: merged["day"] ?? "", catalog: catalog)
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
        let days = scheduleDays(catalog.manifest)
        let day = resolveDayIndex(query, days: days, catalog: catalog)
        let sessions = day.map { days[$0] } ?? catalog.manifest.sessions
        let order = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.startTime) })
        let notes = catalog.notes.filter { order[$0.sessionID] != nil }.sorted {
            let a = order[$0.sessionID]!, b = order[$1.sessionID]!
            return a == b ? $0.createdAt < $1.createdAt : a < b
        }
        guard !notes.isEmpty else {
            if catalog.notes.isEmpty { return "You don’t have notes yet." }
            return day.map { "You don’t have notes for day \($0 + 1)." } ?? "You don’t have notes yet."
        }
        let lines = notes.prefix(8).map { note in
            let title = catalog.manifest.session(id: note.sessionID)?.title ?? "Session"
            let stamp = note.offsetFromStart.map { " \(SessionProgress.offsetLabel($0))" } ?? ""
            let mark = note.isTakeaway ? "Takeaway: " : ""
            return "\(title)\(stamp): \(mark)\(note.body)"
        }
        let label = day.map { dayLabel($0, days: days, catalog: catalog) } ?? "the conference"
        return "Notes from \(label). " + lines.joined(separator: " ")
    }

    /// Every session on one conference day, in time order, with the day named.
    public static func dayAgenda(day query: String, catalog: ConferenceAskCatalog) -> String {
        let days = scheduleDays(catalog.manifest)
        guard !days.isEmpty else { return "Nothing is scheduled." }
        guard let index = resolveDayIndex(query, days: days, catalog: catalog) else {
            return "The conference has \(days.count) day\(days.count == 1 ? "" : "s")."
        }
        let clock = catalog.manifest.clock
        let lines = days[index].map { session in
            let room = session.roomID.flatMap { catalog.manifest.room(id: $0)?.name }
            return [clock.timeString(session.startTime), session.title, room].compactMap { $0 }.joined(separator: " ")
        }
        return "\(dayLabel(index, days: days, catalog: catalog)): " + lines.joined(separator: "; ") + "."
    }

    /// Sessions grouped into conference days, in time order. A new day starts after a gap of
    /// six hours or more, so a schedule that crosses midnight (the demo shifts times to "now")
    /// still counts as one day.
    public static func scheduleDays(_ manifest: ConferenceManifest) -> [[Session]] {
        let sorted = manifest.sessions.sorted { $0.startTime < $1.startTime }
        var days: [[Session]] = []
        var lastEnd: Date?
        for session in sorted {
            if let lastEnd, session.startTime.timeIntervalSince(lastEnd) < 6 * 3600, !days.isEmpty {
                days[days.count - 1].append(session)
            } else {
                days.append([session])
            }
            lastEnd = max(lastEnd ?? session.endTime, session.endTime)
        }
        return days
    }

    /// "Day 2, Friday, April 17" style label.
    public static func dayLabel(_ index: Int, days: [[Session]], catalog: ConferenceAskCatalog) -> String {
        guard let first = days[index].first else { return "Day \(index + 1)" }
        return "Day \(index + 1), \(catalog.manifest.clock.dayString(first.startTime))"
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
        if let exact = catalog.manifest.rooms.first(where: { $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return exact
        }
        return catalog.manifest.rooms.first { room in
            room.name.localizedStandardContains(trimmed) || trimmed.localizedStandardContains(room.name)
        }
    }

    private static let dayWords = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "first": 1, "second": 2, "third": 3]

    private static func resolveDayIndex(_ query: String, days: [[Session]], catalog: ConferenceAskCatalog) -> Int? {
        guard !days.isEmpty else { return nil }
        let lower = query.lowercased()
        if lower.contains("today") {
            let index = days.firstIndex { day in
                guard let last = day.map(\.endTime).max() else { return false }
                return catalog.now <= last
            }
            return index ?? days.count - 1
        }
        let number = lower.split(whereSeparator: { !$0.isNumber }).first.flatMap { Int($0) }
            ?? dayWords.first { lower.split(separator: " ").contains(Substring($0.key)) }?.value
        if let number { return number >= 1 && number <= days.count ? number - 1 : nil }
        return 0
    }

    /// "day 2", "day two", "second day" -> the day slot text.
    private static func dayNumberPhrase(in lower: String) -> String? {
        let words = lower.replacingOccurrences(of: "?", with: " ").split(separator: " ").map(String.init)
        for (i, word) in words.enumerated() {
            if word == "day", i + 1 < words.count, Int(words[i + 1]) != nil || dayWords[words[i + 1]] != nil {
                return words[i + 1]
            }
            if word == "day" || word == "day's", i > 0, dayWords[words[i - 1]] != nil {
                return words[i - 1]
            }
        }
        return nil
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
