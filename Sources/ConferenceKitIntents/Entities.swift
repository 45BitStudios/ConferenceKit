import AppIntents
import ConferenceKit
import Foundation

public enum SessionKindAppEnum: String, AppEnum {
    case keynote, talk, workshop, panel, lightning, breakout, meal, social, other

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Session Kind")

    public static var caseDisplayRepresentations: [SessionKindAppEnum: DisplayRepresentation] = [
        .keynote: "Keynote",
        .talk: "Talk",
        .workshop: "Workshop",
        .panel: "Panel",
        .lightning: "Lightning",
        .breakout: "Breakout",
        .meal: "Break",
        .social: "Social",
        .other: "Session"
    ]

    public init(_ kind: SessionKind) {
        self = SessionKindAppEnum(rawValue: kind.rawValue) ?? .other
    }

    public var kind: SessionKind {
        SessionKind(rawValue: rawValue) ?? .other
    }
}

public enum SponsorTierAppEnum: String, AppEnum {
    case title, diamond, gold, silver, community, other

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sponsor Tier")

    public static var caseDisplayRepresentations: [SponsorTierAppEnum: DisplayRepresentation] = [
        .title: "Title",
        .diamond: "Diamond",
        .gold: "Gold",
        .silver: "Silver",
        .community: "Community",
        .other: "Sponsor"
    ]
}

public enum ReminderLeadAppEnum: String, AppEnum {
    case atStart
    case fiveMinutes
    case tenMinutes
    case fifteenMinutes
    case thirtyMinutes

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Reminder Lead Time")

    public static var caseDisplayRepresentations: [ReminderLeadAppEnum: DisplayRepresentation] = [
        .atStart: "When it starts",
        .fiveMinutes: "5 minutes before",
        .tenMinutes: "10 minutes before",
        .fifteenMinutes: "15 minutes before",
        .thirtyMinutes: "30 minutes before"
    ]

    public var seconds: TimeInterval {
        switch self {
        case .atStart: 0
        case .fiveMinutes: 5 * 60
        case .tenMinutes: 10 * 60
        case .fifteenMinutes: 15 * 60
        case .thirtyMinutes: 30 * 60
        }
    }
}

public struct ConferenceEntity: AppEntity {
    public var id: String
    public var name: String
    public var tagline: String?

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Conference")
    public static var defaultQuery = ConferenceEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: tagline.map { "\($0)" } ?? "")
    }

    public init(id: String, name: String, tagline: String?) {
        self.id = id
        self.name = name
        self.tagline = tagline
    }

    public init(_ info: ConferenceInfo) {
        self.init(id: info.id, name: info.name, tagline: info.tagline)
    }
}

public struct ConferenceEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [ConferenceEntity.ID]) async throws -> [ConferenceEntity] {
        guard let info = await IntentCatalog.manifest()?.conference else { return [] }
        let entity = ConferenceEntity(info)
        return identifiers.contains(entity.id) ? [entity] : []
    }

    public func suggestedEntities() async throws -> [ConferenceEntity] {
        guard let info = await IntentCatalog.manifest()?.conference else { return [] }
        return [ConferenceEntity(info)]
    }

    public func entities(matching string: String) async throws -> [ConferenceEntity] {
        guard let info = await IntentCatalog.manifest()?.conference else { return [] }
        let entity = ConferenceEntity(info)
        guard string.isEmpty || info.name.localizedStandardContains(string) else { return [] }
        return [entity]
    }
}

public struct DayEntity: AppEntity {
    public var id: String
    public var title: String

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Conference Day")
    public static var defaultQuery = DayEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct DayEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [DayEntity.ID]) async throws -> [DayEntity] {
        let days = await all()
        return identifiers.compactMap { id in days.first { $0.id == id } }
    }

    public func suggestedEntities() async throws -> [DayEntity] { await all() }

    public func entities(matching string: String) async throws -> [DayEntity] {
        let days = await all()
        guard !string.isEmpty else { return days }
        return days.filter { $0.title.localizedStandardContains(string) || $0.id.localizedStandardContains(string) }
    }

    private func all() async -> [DayEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        let clock = manifest.clock
        return manifest.conferenceDays.map { day in
            DayEntity(id: Self.identifier(for: day.start, clock: clock), title: clock.dayString(day.start))
        }
    }

    static func identifier(for date: Date, clock: ConferenceClock) -> String {
        let formatter = DateFormatter()
        formatter.calendar = clock.calendar
        formatter.timeZone = clock.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

public struct SessionEntity: AppEntity {
    public var id: String
    public var title: String
    public var synopsis: String
    public var startTime: Date
    public var endTime: Date
    public var roomName: String?
    public var speakerNames: String
    public var kind: SessionKindAppEnum

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Session")
    public static var defaultQuery = SessionEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        let time = startTime.formatted(date: .abbreviated, time: .shortened)
        let subtitle = [roomName, speakerNames.isEmpty ? nil : speakerNames, time]
            .compactMap { $0 }
            .joined(separator: " · ")
        return DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }

    public init(
        id: String,
        title: String,
        synopsis: String,
        startTime: Date,
        endTime: Date,
        roomName: String?,
        speakerNames: String,
        kind: SessionKindAppEnum
    ) {
        self.id = id
        self.title = title
        self.synopsis = synopsis
        self.startTime = startTime
        self.endTime = endTime
        self.roomName = roomName
        self.speakerNames = speakerNames
        self.kind = kind
    }

    public init(_ session: Session, manifest: ConferenceManifest) {
        self.init(
            id: session.id,
            title: session.title,
            synopsis: session.synopsis,
            startTime: session.startTime,
            endTime: session.endTime,
            roomName: session.roomID.flatMap { manifest.room(id: $0)?.name },
            speakerNames: manifest.speakers(ids: session.speakerIDs).map(\.name).joined(separator: ", "),
            kind: SessionKindAppEnum(session.kind)
        )
    }
}

public struct SessionEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [SessionEntity.ID]) async throws -> [SessionEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        return identifiers.compactMap { id in
            manifest.session(id: id).map { SessionEntity($0, manifest: manifest) }
        }
    }

    public func suggestedEntities() async throws -> [SessionEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        let upcoming = manifest.sessions.filter { $0.endTime >= .now }.sorted { $0.startTime < $1.startTime }
        let pool = upcoming.isEmpty ? manifest.sessions.sorted { $0.startTime < $1.startTime } : upcoming
        return pool.prefix(8).map { SessionEntity($0, manifest: manifest) }
    }

    public func entities(matching string: String) async throws -> [SessionEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        return ConferenceSearch.sessions(in: manifest, matching: SessionFilter(query: string))
            .prefix(25)
            .map { SessionEntity($0, manifest: manifest) }
    }
}

public struct SpeakerEntity: AppEntity {
    public var id: String
    public var name: String
    public var affiliation: String
    public var bio: String

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Speaker")
    public static var defaultQuery = SpeakerEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(affiliation)")
    }

    public init(id: String, name: String, affiliation: String, bio: String) {
        self.id = id
        self.name = name
        self.affiliation = affiliation
        self.bio = bio
    }

    public init(_ speaker: Speaker) {
        self.init(id: speaker.id, name: speaker.name, affiliation: speaker.affiliation, bio: speaker.bio)
    }
}

public struct SpeakerEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [SpeakerEntity.ID]) async throws -> [SpeakerEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        return identifiers.compactMap { manifest.speaker(id: $0).map(SpeakerEntity.init) }
    }

    public func suggestedEntities() async throws -> [SpeakerEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        return manifest.speakers.map(SpeakerEntity.init)
    }

    public func entities(matching string: String) async throws -> [SpeakerEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        return ConferenceSearch.speakers(in: manifest, matching: string).map(SpeakerEntity.init)
    }
}

public struct TrackEntity: AppEntity {
    public var id: String
    public var name: String

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Track")
    public static var defaultQuery = TrackEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public init(_ track: Track) { self.init(id: track.id, name: track.name) }
}

public struct TrackEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [TrackEntity.ID]) async throws -> [TrackEntity] {
        await all().filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [TrackEntity] { await all() }

    public func entities(matching string: String) async throws -> [TrackEntity] {
        let tracks = await all()
        guard !string.isEmpty else { return tracks }
        return tracks.filter { $0.name.localizedStandardContains(string) }
    }

    private func all() async -> [TrackEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        return manifest.tracks.map(TrackEntity.init)
    }
}

public struct RoomEntity: AppEntity {
    public var id: String
    public var name: String
    public var floor: String?

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Room")
    public static var defaultQuery = RoomEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: floor.map { "\($0)" } ?? "")
    }

    public init(id: String, name: String, floor: String?) {
        self.id = id
        self.name = name
        self.floor = floor
    }

    public init(_ room: Room) { self.init(id: room.id, name: room.name, floor: room.floor) }
}

public struct RoomEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [RoomEntity.ID]) async throws -> [RoomEntity] {
        await all().filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [RoomEntity] { await all() }

    public func entities(matching string: String) async throws -> [RoomEntity] {
        let rooms = await all()
        guard !string.isEmpty else { return rooms }
        return rooms.filter { $0.name.localizedStandardContains(string) }
    }

    private func all() async -> [RoomEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        return manifest.rooms.map(RoomEntity.init)
    }
}

public struct VenueEntity: AppEntity {
    public var id: String
    public var name: String
    public var address: String

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Venue")
    public static var defaultQuery = VenueEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(address)")
    }

    public init(id: String, name: String, address: String) {
        self.id = id
        self.name = name
        self.address = address
    }
}

public struct VenueEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [VenueEntity.ID]) async throws -> [VenueEntity] {
        guard let entity = await venue(), identifiers.contains(entity.id) else { return [] }
        return [entity]
    }

    public func suggestedEntities() async throws -> [VenueEntity] {
        guard let entity = await venue() else { return [] }
        return [entity]
    }

    public func entities(matching string: String) async throws -> [VenueEntity] {
        guard let entity = await venue() else { return [] }
        guard string.isEmpty
            || entity.name.localizedStandardContains(string)
            || entity.address.localizedStandardContains(string) else { return [] }
        return [entity]
    }

    private func venue() async -> VenueEntity? {
        guard let manifest = await IntentCatalog.manifest(), let venue = manifest.conference.venue else { return nil }
        return VenueEntity(id: "venue", name: venue.name, address: venue.postalAddress)
    }
}

public struct SponsorEntity: AppEntity {
    public var id: String
    public var name: String
    public var tier: SponsorTierAppEnum
    public var blurb: String?

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sponsor")
    public static var defaultQuery = SponsorEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(tier.rawValue.capitalized)")
    }

    public init(id: String, name: String, tier: SponsorTierAppEnum, blurb: String?) {
        self.id = id
        self.name = name
        self.tier = tier
        self.blurb = blurb
    }

    public init(_ sponsor: Sponsor) {
        self.init(
            id: sponsor.id,
            name: sponsor.name,
            tier: SponsorTierAppEnum(rawValue: sponsor.tier.rawValue) ?? .other,
            blurb: sponsor.blurb
        )
    }
}

public struct SponsorEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [SponsorEntity.ID]) async throws -> [SponsorEntity] {
        await all().filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [SponsorEntity] { await all() }

    public func entities(matching string: String) async throws -> [SponsorEntity] {
        let sponsors = await all()
        guard !string.isEmpty else { return sponsors }
        return sponsors.filter {
            $0.name.localizedStandardContains(string) || ($0.blurb?.localizedStandardContains(string) == true)
        }
    }

    private func all() async -> [SponsorEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        return manifest.sponsors.map(SponsorEntity.init)
    }
}
