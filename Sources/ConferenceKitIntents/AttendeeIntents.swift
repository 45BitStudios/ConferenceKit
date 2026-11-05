import AppIntents
import ConferenceKit
import Foundation

public struct AttendeeEntity: AppEntity {
    public var id: String
    public var displayName: String
    public var affiliation: String
    public var bio: String
    public var email: String?
    public var phone: String?

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Attendee")
    public static let defaultQuery = AttendeeEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(affiliation)")
    }

    public init(
        id: String,
        displayName: String,
        affiliation: String,
        bio: String,
        email: String?,
        phone: String?
    ) {
        self.id = id
        self.displayName = displayName
        self.affiliation = affiliation
        self.bio = bio
        self.email = email
        self.phone = phone
    }

    /// Maps a directory record. Callers pass the public projection; private fields are already gone.
    public init(_ attendee: Attendee) {
        let visible = attendee.hidingPrivateContactFields()
        self.init(
            id: visible.id,
            displayName: visible.displayName,
            affiliation: visible.affiliation,
            bio: visible.bio,
            email: visible.email,
            phone: visible.phone
        )
    }
}

public struct AttendeeEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [AttendeeEntity.ID]) async throws -> [AttendeeEntity] {
        let people = await IntentCatalog.directoryAttendees()
        return identifiers.compactMap { id in people.first { $0.id == id }.map(AttendeeEntity.init) }
    }

    public func suggestedEntities() async throws -> [AttendeeEntity] {
        await IntentCatalog.directoryAttendees().map(AttendeeEntity.init)
    }

    public func entities(matching string: String) async throws -> [AttendeeEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        let profile = await ConferenceCatalog.shared.currentAttendee()
        return ConferenceSearch.attendees(
            in: manifest,
            matching: AttendeeFilter(query: string),
            profile: profile
        ).map(AttendeeEntity.init)
    }
}

public struct OpenAttendeeIntent: OpenIntent {
    public static let title: LocalizedStringResource = "Open Attendee"
    public static let description = IntentDescription("Open someone in the attendee directory.")
    public static let openAppWhenRun = true

    @Parameter(title: "Attendee")
    public var target: AttendeeEntity

    public init() {}

    public init(target: AttendeeEntity) {
        self.target = target
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        ConferenceNavigation.shared.openAttendee(id: target.id)
        return .result()
    }
}

/// Discoverable, but not an App Shortcut. The shortcut list is already at the ten-phrase cap.
public struct SearchAttendeesIntent: AppIntent {
    public static let title: LocalizedStringResource = "Search Attendees"
    public static let description = IntentDescription("Find people who opted into the attendee directory.")
    public static let openAppWhenRun = true

    @Parameter(title: "Query")
    public var query: String

    public init() {}

    public init(query: String) {
        self.query = query
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Search attendees for \(\.$query)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[AttendeeEntity]> & ProvidesDialog {
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(value: [], dialog: IntentDialog("No conference is loaded."))
        }
        ConferenceNavigation.shared.show(.attendees)
        ConferenceNavigation.shared.pendingSearch = query
        let profile = await ConferenceCatalog.shared.currentAttendee()
        let matches = ConferenceSearch.attendees(in: manifest, matching: AttendeeFilter(query: query), profile: profile)
        return .result(
            value: matches.map(AttendeeEntity.init),
            dialog: IntentDialog(stringLiteral: "Found \(matches.count) attendees.")
        )
    }
}
