#if SIRI_AI_PREVIEW && (os(iOS) || os(macOS) || os(visionOS))
import AppIntents
import ConferenceKit
import CoreLocation
import CoreTransferable
import Foundation
import SwiftUI

// Patterns adapted from the Larder sample by Artem Novichkov (MIT). See THIRD_PARTY_NOTICES.md.
// Generable drafts, Button(intent:) snippets, Transferable entities, a journal schema tool,
// and a DEBUG reset intent for Siri evaluations.

/// What the model fills in before CreateSessionNoteIntent saves a note.
@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
@AppEntity(.generable)
public struct SessionNoteDraft: TransientAppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Session Note Draft"

    @Property(title: "Text", description: "The note, in the person's words. One or two sentences.")
    public var text: String

    public var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(text)") }

    public init() { text = "" }
}

/// Errors Siri reads back. Each says what to try next, because the model retries with it.
struct SiriActionError: Error, CustomLocalizedStringResourceConvertible {
    enum Reason { case emptyNote, noteTooLong(Int), noSession }
    var reason: Reason

    init(problem: SessionNoteDraftRules.Problem) {
        switch problem {
        case .empty: reason = .emptyNote
        case .tooLong(let count): reason = .noteTooLong(count)
        }
    }

    init(_ reason: Reason) { self.reason = reason }

    var localizedStringResource: LocalizedStringResource {
        switch reason {
        case .emptyNote:
            "The note is empty. Ask what they want to write, then try again with that text."
        case .noteTooLong(let count):
            "The note is \(count) characters. Shorten it to under \(SessionNoteDraftRules.maximumLength) and try again."
        case .noSession:
            "No session is on screen or live. Use the Find Session tool to pick the session, then try again with it."
        }
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
@AppIntent(.tool)
public struct CreateSessionNoteIntent: AppIntent {
    public static let title: LocalizedStringResource = "Create Session Note"
    public static let description = IntentDescription(
        LocalizedStringResource("Writes a note from the request and saves it on a session after checking it."),
        searchKeywords: [LocalizedStringResource("note"), LocalizedStringResource("write down")]
    )

    @Parameter(title: "Draft", description: LocalizedStringResource("The note to save."))
    public var draft: SessionNoteDraft

    @Parameter(title: "Session", description: LocalizedStringResource("Optional. Omit this to use the session on screen or the live session."))
    public var session: SessionEntity?

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<SessionNoteEntity> & ProvidesDialog {
        let text: String
        switch SessionNoteDraftRules.validated(draft.text) {
        case .success(let value): text = value
        case .failure(let problem): throw SiriActionError(problem: problem)
        }
        guard let pair = await resolveSession(explicit: session) else { throw SiriActionError(.noSession) }
        try await requestConfirmation(
            actionName: .add,
            dialog: IntentDialog(stringLiteral: "Save this note on \(pair.session.title)? “\(text)”")
        )
        let note = notesStore(manifest: pair.manifest).add(body: text, session: pair.session, kind: .text)
        return .result(
            value: SessionNoteEntity(note, manifest: pair.manifest),
            dialog: IntentDialog(stringLiteral: "Saved a note on \(pair.session.title).")
        )
    }
}

/// The journal schema is Shortcuts-only; `.tool` brings "log what I learned" to Siri.
/// Each entry is saved as a takeaway note on the session on screen or the live session.
@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
@AppEntity(schema: .journal.entry)
public struct LearnedEntryEntity {
    public static let defaultQuery = LearnedEntryQuery()

    public let id: String
    public var title: String?
    public var message: AttributedString?
    public var mediaItems: [IntentFile]
    public var entryDate: Date?
    public var location: CLPlacemark?

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title ?? "What I learned")")
    }

    init(_ note: SessionNoteEntity, date: Date) {
        id = note.id
        title = note.sessionTitle
        message = AttributedString(note.text)
        mediaItems = []
        entryDate = date
        location = nil
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct LearnedEntryQuery: EntityQuery {
    public init() {}

    @MainActor
    public func entities(for identifiers: [LearnedEntryEntity.ID]) async throws -> [LearnedEntryEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        let store = notesStore(manifest: manifest)
        return identifiers.compactMap { id in
            guard let uuid = UUID(uuidString: id), let note = store.note(id: uuid), note.isTakeaway else { return nil }
            return LearnedEntryEntity(SessionNoteEntity(note, manifest: manifest), date: note.createdAt)
        }
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
@AppIntent(.tool, schema: .journal.createEntry)
struct LogLearnedIntent {  // internal: the schema macro synthesizes a non-public init()
    var title: String?
    var message: AttributedString
    var mediaItems: [IntentFile]
    var entryDate: Date?
    var location: CLPlacemark?

    @MainActor
    func perform() async throws -> some ReturnsValue<LearnedEntryEntity> {
        let text: String
        switch SessionNoteDraftRules.validated(String(message.characters)) {
        case .success(let value): text = value
        case .failure(let problem): throw SiriActionError(problem: problem)
        }
        guard let pair = await resolveSession(explicit: nil) else { throw SiriActionError(.noSession) }
        let now = entryDate ?? .now
        try await requestConfirmation(
            actionName: .add,
            dialog: IntentDialog(stringLiteral: "Log this takeaway on \(pair.session.title)?")
        )
        let note = notesStore(manifest: pair.manifest).add(body: text, session: pair.session, takeaway: true, now: now)
        return .result(value: LearnedEntryEntity(SessionNoteEntity(note, manifest: pair.manifest), date: now))
    }
}

extension SessionEntity: Transferable {
    /// Title, time, room, and speakers. Notes are never part of a shared session.
    public var shareText: String {
        ConferenceShareText.session(
            title: title,
            when: "\(startTime.formatted(date: .abbreviated, time: .shortened))",
            room: roomName,
            speakers: speakerNames
        )
    }

    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.shareText)
    }
}

extension SpeakerEntity: Transferable {
    public var shareText: String { ConferenceShareText.speaker(name: name, affiliation: affiliation) }

    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.shareText)
    }
}

/// Snippet actions. The session card only reads; these buttons run the existing intents.
/// Used by the result snippet and by the entity card. The entity card is archived, then
/// archived again after a button runs.
@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
struct SessionSnippetActions: View {
    var session: SessionEntity

    var body: some View {
        HStack {
            Button(intent: SetSessionFavoriteByIDIntent(sessionID: session.id, favorite: true)) {
                Label("Favorite", systemImage: "star")
            }
            Button(intent: SetSessionReminderIntent(session: session, lead: .tenMinutes)) {
                Label("Remind", systemImage: "bell")
            }
            Button(intent: AddSessionToCalendarIntent(session: session)) {
                Label("Calendar", systemImage: "calendar.badge.plus")
            }
        }
        .buttonStyle(.bordered)
        .font(.caption)
    }
}

#if DEBUG
/// Test fixture for Siri evaluations: they run out of process, so they arrange known data by
/// running this intent in the app. Clears favorites and notes for the loaded conference.
@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct ResetDemoDataIntent: AppIntent {
    public static let title: LocalizedStringResource = "Reset Demo Data"
    public static let description = IntentDescription("Clears favorites and notes for the loaded conference.")
    public static let isDiscoverable = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        guard let manifest = await IntentCatalog.manifest() else { return .result() }
        for id in await IntentCatalog.favoriteSessionIDs() {
            _ = await FavoriteMutator.setSession(id: id, favorite: false)
        }
        let store = notesStore(manifest: manifest)
        for note in store.notes { store.delete(note.id) }
        return .result()
    }
}
#endif
#endif
