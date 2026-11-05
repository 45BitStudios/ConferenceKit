#if SIRI_AI_PREVIEW && (os(iOS) || os(macOS) || os(visionOS))
import AppIntents
import ConferenceKit
import SwiftUI

// Entity snippets (iOS 27.3 / macOS 27.3 / visionOS 27.3).
// Public DocC, beta in the 27.3 SDK:
//   https://developer.apple.com/documentation/appintents/snippetrepresentableentity
//   https://developer.apple.com/documentation/appintents/cardsnippet
// SDK declaration, from the 27.3 symbol graph:
//   associatedtype Body: EntitySnippetContent where Self == Self.Body.Entity
//   @EntitySnippetContentBuilder<Self> static var snippet: Self.Body { get }
// The DocC sample writes `some EntitySnippetContent`. That does not fix Body.Entity
// to Self, so the compiler reports a missing Body. `some EntitySnippetContent<Self>`
// is the witness that satisfies the where clause.
// `SnippetRepresentableEntity.snippet` returns a `CardSnippet` for
// `CardSnippetFamily.standard`. The system archives the view ahead of time, so the
// closure only reads fields already on the entity. Buttons run app intents; after
// one runs, the system archives the card again. Other families fall back to the
// entity's display representation when they are not listed in `supportedFamilies`.
// `CardSnippetFamily` is a struct. The layout branches with `==`, which is the
// equality form of the family switch in the `CardSnippet` initializer docs.
// Larder does not adopt this API. Its recipe card is a result `SnippetIntent`.
// watchOS and tvOS are outside this preview, same as the tool intents, even though
// the symbols are marked 27.3 there. Xcode 27.2 has none of these symbols, so the
// file stays behind `SIRI_AI_PREVIEW`.

enum EntitySnippetDensity {
    case standard
    case compact
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
func entitySnippetDensity(_ context: CardSnippetContext) -> EntitySnippetDensity {
    context.family == .standard ? .standard : .compact
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension SessionEntity: SnippetRepresentableEntity {
    public static var snippet: some EntitySnippetContent<Self> {
        CardSnippet(supportedFamilies: [.standard]) { session, context in
            SessionEntityCard(session: session, density: entitySnippetDensity(context))
        }
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension SpeakerEntity: SnippetRepresentableEntity {
    public static var snippet: some EntitySnippetContent<Self> {
        CardSnippet(supportedFamilies: [.standard]) { speaker, context in
            SpeakerEntityCard(speaker: speaker, density: entitySnippetDensity(context))
        }
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension SessionNoteEntity: SnippetRepresentableEntity {
    public static var snippet: some EntitySnippetContent<Self> {
        CardSnippet(supportedFamilies: [.standard]) { note, context in
            SessionNoteEntityCard(note: note, density: entitySnippetDensity(context))
        }
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension ConferenceEntity: SnippetRepresentableEntity {
    public static var snippet: some EntitySnippetContent<Self> {
        CardSnippet(supportedFamilies: [.standard]) { conference, context in
            ConferenceEntityCard(conference: conference, density: entitySnippetDensity(context))
        }
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension RoomEntity: SnippetRepresentableEntity {
    public static var snippet: some EntitySnippetContent<Self> {
        CardSnippet(supportedFamilies: [.standard]) { room, context in
            RoomEntityCard(room: room, density: entitySnippetDensity(context))
        }
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension VenueEntity: SnippetRepresentableEntity {
    public static var snippet: some EntitySnippetContent<Self> {
        CardSnippet(supportedFamilies: [.standard]) { venue, context in
            VenueEntityCard(venue: venue, density: entitySnippetDensity(context))
        }
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension FavoriteScheduleEntity: SnippetRepresentableEntity {
    public static var snippet: some EntitySnippetContent<Self> {
        CardSnippet(supportedFamilies: [.standard]) { schedule, context in
            FavoriteScheduleEntityCard(schedule: schedule, density: entitySnippetDensity(context))
        }
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension SiriSessionEntity: SnippetRepresentableEntity {
    public static var snippet: some EntitySnippetContent<Self> {
        CardSnippet(supportedFamilies: [.standard]) { session, context in
            SiriSessionEntityCard(session: session, density: entitySnippetDensity(context))
        }
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension SiriSpeakerEntity: SnippetRepresentableEntity {
    public static var snippet: some EntitySnippetContent<Self> {
        CardSnippet(supportedFamilies: [.standard]) { speaker, context in
            SiriSpeakerEntityCard(speaker: speaker, density: entitySnippetDensity(context))
        }
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension SiriNoteEntity: SnippetRepresentableEntity {
    public static var snippet: some EntitySnippetContent<Self> {
        CardSnippet(supportedFamilies: [.standard]) { note, context in
            SiriNoteEntityCard(note: note, density: entitySnippetDensity(context))
        }
    }
}

/// Opens one session's notes from a card. The note entity has a session id, not a `SessionEntity`.
/// Not a Siri tool, and hidden from Shortcuts.
@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct ShowNotesForSessionIDIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show Notes for Session"
    public static let description = IntentDescription("Opens the notes for a session.")
    public static let isDiscoverable = false
    public static let openAppWhenRun = true

    @Parameter(title: "Session ID")
    public var sessionID: String

    public init() { sessionID = "" }

    public init(sessionID: String) { self.sessionID = sessionID }

    @MainActor
    public func perform() async throws -> some IntentResult {
        ConferenceNavigation.shared.openNotes(sessionID: sessionID)
        return .result()
    }
}

/// Stars or unstars one note from its card. Not a Siri tool, and hidden from Shortcuts.
@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
public struct ToggleSessionNoteStarIntent: AppIntent {
    public static let title: LocalizedStringResource = "Star Session Note"
    public static let description = IntentDescription("Stars or unstars one session note.")
    public static let isDiscoverable = false

    @Parameter(title: "Note ID")
    public var noteID: String

    public init() { noteID = "" }

    public init(noteID: String) { self.noteID = noteID }

    @MainActor
    public func perform() async throws -> some IntentResult {
        guard let manifest = await IntentCatalog.manifest(), let id = UUID(uuidString: noteID) else {
            return .result()
        }
        notesStore(manifest: manifest).toggleStar(id)
        return .result()
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
struct SessionEntityCard: View {
    var session: SessionEntity
    var density: EntitySnippetDensity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(session.kind.kind.label, systemImage: session.kind.kind.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(session.title)
                .font(.headline)
                .lineLimit(density == .standard ? 3 : 2)
            Text(Self.when(session))
                .font(.subheadline)
            if let room = session.roomName, room.isEmpty == false {
                Label(room, systemImage: "mappin")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if session.speakerNames.isEmpty == false {
                Label(session.speakerNames, systemImage: "person.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(density == .standard ? 2 : 1)
            }
            if density == .standard, session.synopsis.isEmpty == false {
                Text(session.synopsis)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if density == .standard {
                SessionSnippetActions(session: session)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private static func when(_ session: SessionEntity) -> String {
        let start = session.startTime.formatted(date: .abbreviated, time: .shortened)
        let end = session.endTime.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}

struct SpeakerEntityCard: View {
    var speaker: SpeakerEntity
    var density: EntitySnippetDensity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(speaker.name)
                .font(.title3.bold())
                .lineLimit(2)
            if speaker.affiliation.isEmpty == false {
                Text(speaker.affiliation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if speaker.bio.isEmpty == false {
                Text(speaker.bio)
                    .font(.subheadline)
                    .lineLimit(density == .standard ? 4 : 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
struct SessionNoteEntityCard: View {
    var note: SessionNoteEntity
    var density: EntitySnippetDensity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if note.isTakeaway || note.isStarred {
                HStack(spacing: 8) {
                    if note.isTakeaway {
                        Text("Takeaway")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                    if note.isStarred {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Starred")
                    }
                }
            }
            Text(note.text)
                .font(.body)
                .lineLimit(density == .standard ? 6 : 2)
            Text(note.sessionTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if density == .standard {
                HStack {
                    Button(intent: ShowNotesForSessionIDIntent(sessionID: note.sessionID)) {
                        Label("Notes", systemImage: "note.text")
                    }
                    Button(intent: ToggleSessionNoteStarIntent(noteID: note.id)) {
                        Label(note.isStarred ? "Starred" : "Star", systemImage: note.isStarred ? "star.fill" : "star")
                    }
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

struct ConferenceEntityCard: View {
    var conference: ConferenceEntity
    var density: EntitySnippetDensity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Conference")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(conference.name)
                .font(.title3.bold())
                .lineLimit(2)
            if let tagline = conference.tagline, tagline.isEmpty == false {
                Text(tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(density == .standard ? 3 : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

struct RoomEntityCard: View {
    var room: RoomEntity
    var density: EntitySnippetDensity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Room")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Label(room.name, systemImage: "mappin")
                .font(.title3.bold())
                .lineLimit(2)
            if density == .standard, let floor = room.floor, floor.isEmpty == false {
                Text(floor)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

struct VenueEntityCard: View {
    var venue: VenueEntity
    var density: EntitySnippetDensity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Venue")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(venue.name)
                .font(.title3.bold())
                .lineLimit(2)
            if venue.address.isEmpty == false {
                Label(venue.address, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(density == .standard ? 3 : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
struct FavoriteScheduleEntityCard: View {
    var schedule: FavoriteScheduleEntity
    var density: EntitySnippetDensity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("My Schedule", systemImage: "star.fill")
                .font(.headline)
            Text(schedule.summary.isEmpty ? "Nothing saved yet." : schedule.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(density == .standard ? 6 : 2)
            if density == .standard {
                Button(intent: AddFavoritesToCalendarIntent()) {
                    Label("Add to Calendar", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
struct SiriSessionEntityCard: View {
    var session: SiriSessionEntity
    var density: EntitySnippetDensity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.title)
                .font(.headline)
                .lineLimit(density == .standard ? 3 : 2)
            if session.speakerNames.isEmpty == false {
                Label(session.speakerNames, systemImage: "person.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if density == .standard, session.synopsis.isEmpty == false {
                Text(session.synopsis)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if density == .standard {
                SessionSnippetActions(session: sessionEntity(id: session.id, title: session.title))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
struct SiriSpeakerEntityCard: View {
    var speaker: SiriSpeakerEntity
    var density: EntitySnippetDensity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(speaker.name)
                .font(.title3.bold())
                .lineLimit(2)
            if speaker.bio.isEmpty == false {
                Text(speaker.bio)
                    .font(.subheadline)
                    .lineLimit(density == .standard ? 4 : 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

/// Text and session title only. The mirror entity has neither `isStarred` nor a session id,
/// so star and "show notes" stay on `SessionNoteEntity`.
@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
struct SiriNoteEntityCard: View {
    var note: SiriNoteEntity
    var density: EntitySnippetDensity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.text)
                .font(.body)
                .lineLimit(density == .standard ? 6 : 2)
            Text(note.sessionTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

/// Enough for an intent that resolves the session by id. Times and speakers are not on every mirror entity.
func sessionEntity(id: String, title: String) -> SessionEntity {
    SessionEntity(
        id: id,
        title: title,
        synopsis: "",
        startTime: .distantPast,
        endTime: .distantPast,
        roomName: nil,
        speakerNames: "",
        kind: .other
    )
}
#endif
