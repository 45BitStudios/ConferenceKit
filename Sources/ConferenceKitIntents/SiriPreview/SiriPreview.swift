#if SIRI_AI_PREVIEW && (os(iOS) || os(macOS) || os(visionOS))
import AppIntents
import ConferenceKit
import CoreSpotlight
import Foundation
import SwiftUI

// Siri AI Developer Preview (iOS 27.3 / macOS 27.3 / visionOS 27.3).
// This file is excluded from the Xcode 27.2 build unless SIRI_AI_PREVIEW is set.
// Checked against the Xcode 27.3 beta (27C5020n) AppIntents swiftinterface:
//   @AppIntent(.tool) adds ToolIntent; @AppEntity(.generable) adds GenerableEntity
//   (a TransientAppEntity; iOS/macOS/visionOS 27.3, not watchOS/tvOS).
//   @Property / @ComputedProperty / @DeferredProperty take title:description:
//   authenticationPolicy:visibility: and, on iOS/macOS/visionOS, indexingKey:.
//   The property macros emit a stored `_name` peer, so they must sit in the type
//   body (not an extension), and the enclosing type must itself be 27.3-only:
//   the macro rejects a per-property @available. ConferenceKit's entities ship to
//   iOS 17, so the preview exposes 27.3-only mirror entities below instead of
//   annotating SessionEntity / SpeakerEntity / SessionNoteEntity.
//   DisplayRepresentation is ExpressibleByStringLiteral only, not interpolation.
//   SnippetIntent + ShowsSnippetView `.result(view:)` is unchanged from iOS 26.

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
@AppIntent(.tool)
public struct WhatsNextTool: AppIntent {
    public static let title: LocalizedStringResource = "What's Next"
    public static let description = IntentDescription(
        LocalizedStringResource("Reports the session that is on now, or the next one if nothing is live."),
        searchKeywords: [LocalizedStringResource("what's on"), LocalizedStringResource("happening now"), LocalizedStringResource("up next")]
    )

    @Parameter(title: "Favorites Only", description: LocalizedStringResource("Limit the answer to sessions the person saved."), default: false)
    public var favoritesOnly: Bool

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let intent = WhatsNextIntent(favoritesOnly: favoritesOnly)
        _ = try await intent.perform()
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(dialog: IntentDialog("No conference is loaded."))
        }
        let favoriteIDs = await IntentCatalog.favoriteSessionIDs()
        let pool = favoritesOnly
            ? manifest.sessions.filter { favoriteIDs.contains($0.id) }
            : manifest.sessions
        let session = ConferenceSearch.liveSessions(in: pool).first ?? ConferenceSearch.nextUp(in: pool).first
        let spoken = session.map { "\($0.title)" } ?? "Nothing else is scheduled."
        return .result(dialog: IntentDialog(stringLiteral: spoken))
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
@AppIntent(.tool)
public struct FindSessionTool: AppIntent {
    public static let title: LocalizedStringResource = "Find Session"
    public static let description = IntentDescription(
        LocalizedStringResource("Finds sessions by title, speaker, room, or track."),
        searchKeywords: [LocalizedStringResource("talk"), LocalizedStringResource("session"), LocalizedStringResource("who is speaking")]
    )

    @Parameter(title: "Query", description: LocalizedStringResource("Words from the session, the speaker, or the room."))
    public var query: String

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[SessionEntity]> & ProvidesDialog {
        _ = try await SearchSessionsIntent(query: query).perform()
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(value: [], dialog: IntentDialog("No conference is loaded."))
        }
        let matches = ConferenceSearch.sessions(in: manifest, matching: SessionFilter(query: query))
        let entities = matches.prefix(8).map { SessionEntity($0, manifest: manifest) }
        if entities.isEmpty == false {
            return .result(
                value: Array(entities),
                dialog: IntentDialog(stringLiteral: "Found \(matches.count) sessions.")
            )
        }
        return .result(value: [], dialog: IntentDialog("No matching session."))
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
@AppIntent(.tool)
public struct FavoriteSessionTool: AppIntent {
    public static let title: LocalizedStringResource = "Favorite Session"
    public static let description = IntentDescription(
        LocalizedStringResource("Saves a session on My Schedule, or removes it."),
        searchKeywords: [LocalizedStringResource("favorite"), LocalizedStringResource("save"), LocalizedStringResource("my schedule")]
    )

    @Parameter(title: "Session", description: LocalizedStringResource("The session to save or remove."))
    public var session: SessionEntity

    @Parameter(title: "Favorite", description: LocalizedStringResource("True saves the session. False removes it."), default: true)
    public var favorite: Bool

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try await requestConfirmation(
            actionName: favorite ? .add : .set,
            dialog: IntentDialog(stringLiteral: favorite
                ? "Save \(session.title) on My Schedule?"
                : "Remove \(session.title) from My Schedule?")
        )
        let message = await FavoriteMutator.setSession(id: session.id, favorite: favorite)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
@AppIntent(.tool)
public struct AddNoteTool: AppIntent {
    public static let title: LocalizedStringResource = "Add Note"
    public static let description = IntentDescription(
        LocalizedStringResource("Adds a note to the session on screen, or to the session that is live."),
        searchKeywords: [LocalizedStringResource("note"), LocalizedStringResource("jot down")]
    )

    @Parameter(title: "Note", description: LocalizedStringResource("The sentence to save."))
    public var text: String

    @Parameter(title: "Session", description: LocalizedStringResource("Optional. Omit this to use the session on screen or the live session."))
    public var session: SessionEntity?

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let intent = AddNoteToCurrentSessionIntent(text: text, session: session)
        _ = try await intent.perform()
        return .result(dialog: IntentDialog("Noted."))
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
@AppIntent(.tool)
public struct ShowNotesTool: AppIntent {
    public static let title: LocalizedStringResource = "Show Notes"
    public static let description = IntentDescription(
        LocalizedStringResource("Shows the notes saved for one session."),
        searchKeywords: [LocalizedStringResource("my notes"), LocalizedStringResource("what did I write")]
    )

    @Parameter(title: "Session", description: LocalizedStringResource("The session whose notes to read."))
    public var session: SessionEntity

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        _ = try await ShowSessionNotesIntent(session: session).perform()
        return .result(dialog: IntentDialog(stringLiteral: "Notes for \(session.title)."))
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
@AppIntent(.tool)
public struct ExportNotesTool: AppIntent {
    public static let title: LocalizedStringResource = "Export Notes"
    public static let description = IntentDescription(
        LocalizedStringResource("Exports every note as Markdown, grouped by day and session."),
        searchKeywords: [LocalizedStringResource("export notes"), LocalizedStringResource("share notes")]
    )

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(value: "", dialog: IntentDialog("No conference is loaded."))
        }
        let markdown = await MainActor.run { notesStore(manifest: manifest).markdown(manifest: manifest) }
        return .result(value: markdown, dialog: IntentDialog("Exported conference notes."))
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
@AppEntity(.generable)
public struct SessionQueryEntity: TransientAppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Session Search"

    @Property(title: "Words", description: "Title, speaker, room, or track to look for.")
    public var words: String

    public var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(words)") }

    public init() { words = "" }
}

/// Preview-only mirror of `SessionEntity`, so the 27.3 property macros can live in
/// the type body. Hidden from Spotlight results (SessionEntity already shows there);
/// it stays in the semantic index for Siri.
@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct SiriSessionEntity: IndexedEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Session")
    public static let defaultQuery = SiriSessionEntityQuery()

    public var id: String
    public var title: String
    public var speakerNames: String
    var synopsisText: String

    @ComputedProperty(
        title: "Synopsis",
        description: "What the session is about.",
        indexingKey: \.contentDescription
    )
    public var synopsis: String { synopsisText }

    @DeferredProperty(
        title: "Saved",
        description: "Whether this session is on My Schedule."
    )
    public var saved: String {
        get async throws {
            let ids = await IntentCatalog.favoriteSessionIDs()
            return ids.contains(id) ? "favorite" : "not favorite"
        }
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(speakerNames)")
    }

    public var hideInSpotlight: Bool { true }

    public init(_ session: SessionEntity) {
        id = session.id
        title = session.title
        speakerNames = session.speakerNames
        synopsisText = session.synopsis
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct SiriSessionEntityQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [SiriSessionEntity.ID]) async throws -> [SiriSessionEntity] {
        try await SessionEntityQuery().entities(for: identifiers).map(SiriSessionEntity.init)
    }

    public func suggestedEntities() async throws -> [SiriSessionEntity] {
        try await SessionEntityQuery().suggestedEntities().map(SiriSessionEntity.init)
    }
}

/// Preview-only mirror of `SpeakerEntity`.
@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct SiriSpeakerEntity: IndexedEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Speaker")
    public static let defaultQuery = SiriSpeakerEntityQuery()

    public var id: String
    public var name: String
    var bioText: String

    @ComputedProperty(title: "Bio", description: "The speaker biography.", indexingKey: \.contentDescription)
    public var bio: String { bioText }

    public var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    public var hideInSpotlight: Bool { true }

    public init(_ speaker: SpeakerEntity) {
        id = speaker.id
        name = speaker.name
        bioText = speaker.bio
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct SiriSpeakerEntityQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [SiriSpeakerEntity.ID]) async throws -> [SiriSpeakerEntity] {
        try await SpeakerEntityQuery().entities(for: identifiers).map(SiriSpeakerEntity.init)
    }
}

/// Preview-only mirror of `SessionNoteEntity`.
@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct SiriNoteEntity: IndexedEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Session Note")
    public static let defaultQuery = SiriNoteEntityQuery()

    public var id: String
    public var sessionTitle: String
    var noteText: String

    @ComputedProperty(
        title: "Note",
        description: "The text the person wrote.",
        authenticationPolicy: .requiresLocalDeviceAuthentication,
        indexingKey: \.contentDescription
    )
    public var text: String { noteText }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(noteText)", subtitle: "\(sessionTitle)")
    }

    public var hideInSpotlight: Bool { true }

    public init(_ note: SessionNoteEntity) {
        id = note.id
        sessionTitle = note.sessionTitle
        noteText = note.text
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct SiriNoteEntityQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [SiriNoteEntity.ID]) async throws -> [SiriNoteEntity] {
        try await SessionNoteEntityQuery().entities(for: identifiers).map(SiriNoteEntity.init)
    }
}

@available(iOS 18.0, macOS 15.0, visionOS 2.0, *)
extension ConferenceEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = name
        attributes.contentDescription = tagline
        return attributes
    }
}

@available(iOS 18.0, macOS 15.0, visionOS 2.0, *)
extension DayEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = title
        return attributes
    }
}

@available(iOS 18.0, macOS 15.0, visionOS 2.0, *)
extension TrackEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = name
        return attributes
    }
}

@available(iOS 18.0, macOS 15.0, visionOS 2.0, *)
extension RoomEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = name
        attributes.contentDescription = floor
        return attributes
    }
}

@available(iOS 18.0, macOS 15.0, visionOS 2.0, *)
extension VenueEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = name
        attributes.contentDescription = address
        return attributes
    }
}

@available(iOS 18.0, macOS 15.0, visionOS 2.0, *)
extension SponsorEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = name
        attributes.contentDescription = blurb
        return attributes
    }
}

@available(iOS 18.0, macOS 15.0, visionOS 2.0, *)
extension SessionNoteEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = sessionTitle
        attributes.contentDescription = text
        attributes.keywords = isStarred ? ["favorite", "note"] : ["note"]
        return attributes
    }
}

/// One indexed row for My Schedule, so Siri can resolve "my favorites".
@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct FavoriteScheduleEntity: AppEntity, IndexedEntity {
    public var id: String

    @Property(title: "Summary", description: "The saved sessions.", visibility: .internal)
    public var summary: String

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Favorites")
    public static let defaultQuery = FavoriteScheduleEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "My Schedule", subtitle: "\(summary)")
    }

    public init(id: String, summary: String) {
        self.id = id
        self.summary = summary
    }

    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = "My Schedule"
        attributes.contentDescription = summary
        attributes.keywords = ["favorites", "saved"]
        return attributes
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct FavoriteScheduleEntityQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [FavoriteScheduleEntity.ID]) async throws -> [FavoriteScheduleEntity] {
        guard identifiers.contains("favorites"), let entity = await Self.make() else { return [] }
        return [entity]
    }

    public func suggestedEntities() async throws -> [FavoriteScheduleEntity] {
        guard let entity = await Self.make() else { return [] }
        return [entity]
    }

    /// Internal so ConferenceSiriPreviewIndex can index the same row.
    static func make() async -> FavoriteScheduleEntity? {
        guard let manifest = await IntentCatalog.manifest() else { return nil }
        let ids = await IntentCatalog.favoriteSessionIDs()
        let titles = manifest.sessions.filter { ids.contains($0.id) }.map(\.title)
        return FavoriteScheduleEntity(id: "favorites", summary: titles.joined(separator: ", "))
    }
}

enum ConferenceSiriPreviewIndex {
    static func reindex(_ manifest: ConferenceManifest) async {
        guard #available(iOS 27.3, macOS 27.3, visionOS 27.3, *) else { return }
        let index = CSSearchableIndex(name: "ConferenceKit")
        try? await index.indexAppEntities([ConferenceEntity(manifest.conference)])
        let clock = manifest.clock
        let days = manifest.conferenceDays.map { day in
            DayEntity(id: DayEntityQuery.identifier(for: day.start, clock: clock), title: clock.dayString(day.start))
        }
        try? await index.indexAppEntities(days)
        let sessions = manifest.sessions.map { SessionEntity($0, manifest: manifest) }
        try? await index.indexAppEntities(sessions)
        try? await index.indexAppEntities(sessions.map(SiriSessionEntity.init))
        let speakers = manifest.speakers.map(SpeakerEntity.init)
        try? await index.indexAppEntities(speakers)
        try? await index.indexAppEntities(speakers.map(SiriSpeakerEntity.init))
        try? await index.indexAppEntities(manifest.directoryAttendees().map(AttendeeEntity.init))
        try? await index.indexAppEntities(manifest.tracks.map(TrackEntity.init))
        try? await index.indexAppEntities(manifest.rooms.map(RoomEntity.init))
        if let venue = manifest.conference.venue {
            try? await index.indexAppEntities([
                VenueEntity(id: "venue", name: venue.name, address: venue.postalAddress)
            ])
        }
        try? await index.indexAppEntities(manifest.sponsors.map(SponsorEntity.init))
        let notes = await MainActor.run { notesStore(manifest: manifest).notes }
        let noteEntities = notes.map { SessionNoteEntity($0, manifest: manifest) }
        try? await index.indexAppEntities(noteEntities)
        try? await index.indexAppEntities(noteEntities.map(SiriNoteEntity.init))
        if let favorites = await FavoriteScheduleEntityQuery.make() {
            try? await index.indexAppEntities([favorites])
        }
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct SessionSnippetIntent: SnippetIntent {
    public static let title: LocalizedStringResource = "Session Card"

    @Parameter(title: "Session")
    public var session: SessionEntity

    public init() {}

    public init(session: SessionEntity) {
        self.session = session
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: VStack(spacing: 0) {
            SessionSnippetCard(title: session.title, detail: session.speakerNames)
            SessionSnippetActions(session: session)
        })
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct SpeakerSnippetIntent: SnippetIntent {
    public static let title: LocalizedStringResource = "Speaker Card"

    @Parameter(title: "Speaker")
    public var speaker: SpeakerEntity

    public init() {}

    public init(speaker: SpeakerEntity) {
        self.speaker = speaker
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: SessionSnippetCard(title: speaker.name, detail: speaker.affiliation))
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct AttendeeSnippetIntent: SnippetIntent {
    public static let title: LocalizedStringResource = "Attendee Card"

    @Parameter(title: "Attendee")
    public var attendee: AttendeeEntity

    public init() {}

    public init(attendee: AttendeeEntity) {
        self.attendee = attendee
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: SessionSnippetCard(title: attendee.displayName, detail: attendee.affiliation))
    }
}

struct SessionSnippetCard: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            if !detail.isEmpty {
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
#endif
