import AppIntents
import ConferenceKit
import Foundation

public struct SessionNoteEntity: AppEntity {
    public var id: String
    public var text: String
    public var sessionID: String
    public var sessionTitle: String
    public var isStarred: Bool
    public var isTakeaway: Bool

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Session Note")
    public static let defaultQuery = SessionNoteEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(text)", subtitle: "\(sessionTitle)")
    }

    public init(id: String, text: String, sessionID: String, sessionTitle: String, isStarred: Bool, isTakeaway: Bool) {
        self.id = id
        self.text = text
        self.sessionID = sessionID
        self.sessionTitle = sessionTitle
        self.isStarred = isStarred
        self.isTakeaway = isTakeaway
    }

    public init(_ note: SessionNote, manifest: ConferenceManifest) {
        self.init(
            id: note.id.uuidString,
            text: note.body.isEmpty ? "Photo" : note.body,
            sessionID: note.sessionID,
            sessionTitle: manifest.session(id: note.sessionID)?.title ?? "Session",
            isStarred: note.isStarred,
            isTakeaway: note.isTakeaway
        )
    }
}

public struct SessionNoteEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [SessionNoteEntity.ID]) async throws -> [SessionNoteEntity] {
        await all().filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [SessionNoteEntity] {
        Array(await all().suffix(12))
    }

    public func entities(matching string: String) async throws -> [SessionNoteEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        let notes = await MainActor.run { notesStore(manifest: manifest).search(string, manifest: manifest) }
        return notes.map { SessionNoteEntity($0, manifest: manifest) }
    }

    private func all() async -> [SessionNoteEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        let notes = await MainActor.run { notesStore(manifest: manifest).notes }
        return notes.map { SessionNoteEntity($0, manifest: manifest) }
    }
}

public struct AddNoteToCurrentSessionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Note to Current Session"
    public static let description = IntentDescription("Save a note on the session that's on now, or the one open in the app.")

    @Parameter(title: "Note")
    public var text: String

    @Parameter(title: "Session")
    public var session: SessionEntity?

    public init() {}

    public init(text: String, session: SessionEntity? = nil) {
        self.text = text
        self.session = session
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$text) to the current session")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<SessionNoteEntity> & ProvidesDialog {
        guard let pair = await resolveSession(explicit: session) else {
            throw NoteIntentFailure()
        }
        let note = notesStore(manifest: pair.manifest).add(body: text, session: pair.session, kind: .timestamp)
        let entity = SessionNoteEntity(note, manifest: pair.manifest)
        ConferenceNavigation.shared.openNotes(sessionID: pair.session.id)
        let stamp = note.offsetFromStart.map { SessionProgress.offsetLabel($0) } ?? ""
        return .result(value: entity, dialog: IntentDialog(stringLiteral: "Noted \(stamp) on \(pair.session.title)."))
    }
}

public struct ShowSessionNotesIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show Session Notes"
    public static let description = IntentDescription("Open the notes for a session.")
    public static let openAppWhenRun = true

    @Parameter(title: "Session")
    public var session: SessionEntity

    public init() {}

    public init(session: SessionEntity) {
        self.session = session
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Show notes for \(\.$session)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[SessionNoteEntity]> & ProvidesDialog {
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(value: [], dialog: IntentDialog("No conference is loaded."))
        }
        ConferenceNavigation.shared.openNotes(sessionID: session.id)
        let notes = notesStore(manifest: manifest).notes(for: session.id).map { SessionNoteEntity($0, manifest: manifest) }
        return .result(value: notes, dialog: IntentDialog(stringLiteral: "\(notes.count) notes for \(session.title)."))
    }
}

public struct ExportConferenceNotesIntent: AppIntent {
    public static let title: LocalizedStringResource = "Export Conference Notes"
    public static let description = IntentDescription("Export every note as Markdown, grouped by day and session.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(value: "", dialog: IntentDialog("No conference is loaded."))
        }
        let markdown = notesStore(manifest: manifest).markdown(manifest: manifest)
        return .result(value: markdown, dialog: IntentDialog("Exported conference notes."))
    }
}

struct NoteIntentFailure: LocalizedError {
    var errorDescription: String? { "There isn’t a current session to attach that note to." }
}

@MainActor
func notesStore(manifest: ConferenceManifest) -> NotesStore {
    if let notes = ConferenceRuntime.shared.store?.notesStore, notes.conferenceID == manifest.conference.id {
        return notes
    }
    return NotesStore(conferenceID: manifest.conference.id)
}

@MainActor
func resolveSession(explicit: SessionEntity?) async -> (session: Session, manifest: ConferenceManifest)? {
    guard let manifest = await IntentCatalog.manifest() else { return nil }
    if let explicit, let session = manifest.session(id: explicit.id) {
        return (session, manifest)
    }
    if let selected = ConferenceRuntime.shared.store?.selectedSessionID, let session = manifest.session(id: selected) {
        return (session, manifest)
    }
    if let live = ConferenceSearch.liveSessions(in: manifest.sessions).first {
        return (live, manifest)
    }
    if let next = ConferenceSearch.nextUp(in: manifest.sessions).first {
        return (next, manifest)
    }
    return nil
}
