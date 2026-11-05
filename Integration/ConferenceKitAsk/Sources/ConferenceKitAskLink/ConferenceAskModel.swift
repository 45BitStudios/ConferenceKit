import ConferenceKit
import Foundation
#if CONFERENCEKIT_ASK && canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
import FoundationModels
#endif

// Built only in Integration/ConferenceKitAsk (27.0 minimums); the root ConferenceKitAsk target skips it.
#if CONFERENCEKIT_ASK

/// What an Ask answer came from.
public enum ConferenceAskEngine: String, Sendable, Equatable {
    case foundationModels
    case rules
}

public struct ConferenceAskResponse: Sendable, Equatable {
    public var text: String
    public var sessionIDs: [String]
    public var engine: ConferenceAskEngine
}

/// Answers with the on-device model when it's available, and with ConferenceAskAnswers otherwise.
/// One responder keeps one model session, so follow-ups ("and the one after that?") see earlier turns.
@MainActor
public final class ConferenceAskResponder {
    private let catalog: @MainActor @Sendable () -> ConferenceAskCatalog
    private let allowModel: Bool
    #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
    private var modelSession: AnyObject?
    #endif

    /// `allowModel: false` forces the rules path (tests, or a setting).
    public init(allowModel: Bool = true, catalog: @escaping @MainActor @Sendable () -> ConferenceAskCatalog) {
        self.catalog = catalog
        self.allowModel = allowModel
    }

    public var modelIsAvailable: Bool {
        #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
        guard allowModel else { return false }
        // The package minimum is 27.0, so this always passes today; it keeps the gate explicit if
        // the minimum drops. Availability covers Apple Intelligence off, device not eligible, model not ready.
        guard #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) else { return false }
        return SystemLanguageModel.default.availability == .available
        #else
        return false
        #endif
    }

    public func answer(_ utterance: String) async -> ConferenceAskResponse {
        #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
        if modelIsAvailable, let response = try? await modelAnswer(utterance) {
            return response
        }
        #endif
        return Self.rulesAnswer(utterance, catalog: catalog())
    }

    /// Starts a new conversation.
    public func reset() {
        #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
        modelSession = nil
        #endif
    }

    public static func rulesAnswer(_ utterance: String, catalog: ConferenceAskCatalog) -> ConferenceAskResponse {
        let answer = ConferenceAskAnswers.reply(utterance: utterance, catalog: catalog)
        return ConferenceAskResponse(text: answer.spoken, sessionIDs: [], engine: .rules)
    }

    #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
    private func modelAnswer(_ utterance: String) async throws -> ConferenceAskResponse {
        let session: LanguageModelSession
        if let existing = modelSession as? LanguageModelSession {
            session = existing
        } else {
            let snapshot = catalog()
            let manifest = snapshot.manifest
            session = LanguageModelSession(
                tools: ConferenceAskTools.all(catalog: catalog),
                instructions: ConferenceAskPrompts.instructions(
                    conference: manifest.conference.name,
                    timezone: manifest.conference.timezone,
                    today: manifest.clock.dayString(snapshot.now)
                )
            )
            modelSession = session
        }
        let response = try await session.respond(to: utterance, generating: AskAnswer.self)
        let known = Set(catalog().manifest.sessions.map(\.id))
        return ConferenceAskResponse(
            text: response.content.answer,
            sessionIDs: response.content.sessionIDs.filter(known.contains),
            engine: .foundationModels
        )
    }
    #endif
}

#if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
/// The model's structured answer.
@Generable
public struct AskAnswer: Sendable {
    @Guide(description: "The answer, one to three sentences, using only facts from the tools.")
    public var answer: String
    @Guide(description: "Ids of the sessions the answer mentions, as the tools returned them.")
    public var sessionIDs: [String]
    @Guide(description: "Why these sessions answer the question, in a few words.")
    public var reason: String
}

public enum ConferenceAskTools {
    @MainActor
    public static func all(catalog: @escaping @MainActor @Sendable () -> ConferenceAskCatalog) -> [any Tool] {
        let provider = CatalogProvider(catalog)
        return [ScheduleLookupTool(provider: provider), SpeakerLookupTool(provider: provider), NotesLookupTool(provider: provider)]
    }
}

/// Reads the live catalog on the main actor, so tools see current favorites and notes.
public struct CatalogProvider: Sendable {
    let read: @MainActor @Sendable () -> ConferenceAskCatalog

    public init(_ catalog: @escaping @MainActor @Sendable () -> ConferenceAskCatalog) {
        read = catalog
    }

    public init(fixed: ConferenceAskCatalog) {
        read = { fixed }
    }

    func current() async -> ConferenceAskCatalog { await read() }
}

/// Lines of "id | title | when | room" so the model can cite session ids.
enum ToolFormat {
    static func sessions(_ sessions: [Session], catalog: ConferenceAskCatalog) -> String {
        guard !sessions.isEmpty else { return "No sessions." }
        let clock = catalog.manifest.clock
        let days = ConferenceAskAnswers.scheduleDays(catalog.manifest)
        return sessions.map { session in
            let day = days.firstIndex { $0.contains { $0.id == session.id } }.map { "Day \($0 + 1)" } ?? ""
            let room = session.roomID.flatMap { catalog.manifest.room(id: $0)?.name } ?? ""
            let saved = catalog.favoriteSessionIDs.contains(session.id) ? " | saved" : ""
            return "\(session.id) | \(session.title) | \(day) \(clock.rangeString(from: session.startTime, to: session.endTime)) | \(room)\(saved)"
        }.joined(separator: "\n")
    }
}

public struct ScheduleLookupTool: Tool {
    public let name = "scheduleLookup"
    public let description = "Looks up conference sessions: what is on now or next, in one room, on a numbered day, or the person's saved sessions."
    let provider: CatalogProvider

    public init(provider: CatalogProvider) { self.provider = provider }

    @Generable
    public struct Arguments {
        @Guide(description: "A room name, such as Main Stage. Empty for any room.")
        public var room: String
        @Guide(description: "A conference day number starting at 1. 0 for any day.")
        public var day: Int
        @Guide(description: "True to return only sessions the person saved (my schedule).")
        public var saved: Bool
        @Guide(description: "True to return only sessions on now or still ahead.")
        public var upcoming: Bool

        public init(room: String = "", day: Int = 0, saved: Bool = false, upcoming: Bool = false) {
            self.room = room; self.day = day; self.saved = saved; self.upcoming = upcoming
        }
    }

    public func call(arguments: Arguments) async throws -> String {
        lookup(arguments, catalog: await provider.current())
    }

    public func lookup(_ arguments: Arguments, catalog: ConferenceAskCatalog) -> String {
        let manifest = catalog.manifest
        let days = ConferenceAskAnswers.scheduleDays(manifest)
        var sessions = manifest.sessions.sorted { $0.startTime < $1.startTime }
        if arguments.day > 0 {
            guard arguments.day <= days.count else { return "The conference has \(days.count) days." }
            sessions = days[arguments.day - 1]
        }
        let room = arguments.room.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty {
            let match = manifest.rooms.first { $0.name.compare(room, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
                ?? manifest.rooms.first { $0.name.localizedStandardContains(room) || room.localizedStandardContains($0.name) }
            guard let match else { return "No room called \(room)." }
            sessions = sessions.filter { $0.roomID == match.id }
        }
        if arguments.saved { sessions = sessions.filter { catalog.favoriteSessionIDs.contains($0.id) } }
        if arguments.upcoming { sessions = sessions.filter { $0.endTime > catalog.now } }
        if arguments.saved && sessions.isEmpty { return "The person hasn't saved any sessions." }
        return ToolFormat.sessions(sessions, catalog: catalog)
    }
}

public struct SpeakerLookupTool: Tool {
    public let name = "speakerLookup"
    public let description = "Finds a speaker by name and returns their sessions with times and rooms."
    let provider: CatalogProvider

    public init(provider: CatalogProvider) { self.provider = provider }

    @Generable
    public struct Arguments {
        @Guide(description: "The speaker's name or part of it.")
        public var name: String
        public init(name: String) { self.name = name }
    }

    public func call(arguments: Arguments) async throws -> String {
        lookup(arguments, catalog: await provider.current())
    }

    public func lookup(_ arguments: Arguments, catalog: ConferenceAskCatalog) -> String {
        let name = arguments.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              let speaker = catalog.manifest.speakers.first(where: { $0.name.localizedStandardContains(name) || name.localizedStandardContains($0.name) })
        else { return "No speaker named \(name)." }
        let sessions = catalog.manifest.sessions(for: speaker.id).sorted { $0.startTime < $1.startTime }
        return "\(speaker.name)\n" + ToolFormat.sessions(sessions, catalog: catalog)
    }
}

public struct NotesLookupTool: Tool {
    public let name = "notesLookup"
    public let description = "Returns the person's own notes, for one conference day or one session, in session order."
    let provider: CatalogProvider

    public init(provider: CatalogProvider) { self.provider = provider }

    @Generable
    public struct Arguments {
        @Guide(description: "A conference day number starting at 1. 0 for every day.")
        public var day: Int
        @Guide(description: "A session id from schedule lookup. Empty for every session.")
        public var sessionID: String
        public init(day: Int = 0, sessionID: String = "") { self.day = day; self.sessionID = sessionID }
    }

    public func call(arguments: Arguments) async throws -> String {
        lookup(arguments, catalog: await provider.current())
    }

    public func lookup(_ arguments: Arguments, catalog: ConferenceAskCatalog) -> String {
        let days = ConferenceAskAnswers.scheduleDays(catalog.manifest)
        var sessions = catalog.manifest.sessions.sorted { $0.startTime < $1.startTime }
        if arguments.day > 0 {
            guard arguments.day <= days.count else { return "The conference has \(days.count) days." }
            sessions = days[arguments.day - 1]
        }
        if !arguments.sessionID.isEmpty { sessions = sessions.filter { $0.id == arguments.sessionID } }
        let order = Dictionary(uniqueKeysWithValues: sessions.enumerated().map { ($1.id, $0) })
        let notes = catalog.notes.filter { order[$0.sessionID] != nil }.sorted {
            let a = order[$0.sessionID]!, b = order[$1.sessionID]!
            return a == b ? $0.createdAt < $1.createdAt : a < b
        }
        guard !notes.isEmpty else { return "No notes." }
        return notes.map { note in
            let title = catalog.manifest.session(id: note.sessionID)?.title ?? "Session"
            return "\(note.sessionID) | \(title) | \(note.isTakeaway ? "takeaway: " : "")\(note.body.isEmpty ? "(photo)" : note.body)"
        }.joined(separator: "\n")
    }
}
#endif
#endif
