import AppIntents
import ConferenceKit
import Foundation

public struct AttendeeEntity: AppEntity {
    public var id: String
    public var displayName: String
    public var affiliation: String
    public var bio: String

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Attendee")
    public static let defaultQuery = AttendeeEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(affiliation)")
    }

    public init(id: String, displayName: String, affiliation: String, bio: String) {
        self.id = id
        self.displayName = displayName
        self.affiliation = affiliation
        self.bio = bio
    }

    /// Maps a directory record. Contact fields are not copied onto the entity.
    public init(_ attendee: Attendee) {
        let visible = attendee.hidingPrivateContactFields()
        self.init(
            id: visible.id,
            displayName: visible.displayName,
            affiliation: visible.affiliation,
            bio: visible.bio
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
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

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
    public static let description = IntentDescription("Find people who opted into the attendee directory. Names and roles only.")
    public static let openAppWhenRun = true
    /// Directory names are not contact fields. This intent runs on device, including while offline.
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

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
        let answer = AttendeeDirectoryAnswers.reply(query: query, manifest: manifest, profile: profile)
        let matches = ConferenceSearch.attendees(in: manifest, matching: AttendeeFilter(query: query), profile: profile)
        return .result(
            value: matches.map(AttendeeEntity.init),
            dialog: IntentDialog(stringLiteral: answer.spoken)
        )
    }
}

/// Reads email, phone, and social links that the attendee marked public.
///
/// Authentication is the lock-screen gate (`requiresLocalDeviceAuthentication`).
/// It is not the privacy flag and it is not messaging consent. Opted-out fields
/// are already absent from the directory record. `requestConfirmation` runs
/// before the fields are spoken. This is an ordinary App Intent, not a Siri custom tool.
public struct ReadPublicAttendeeContactIntent: AppIntent {
    public static let title: LocalizedStringResource = "Read Public Contact"
    public static let description = IntentDescription("Reads the email, phone, and social links an attendee marked public, after the device is unlocked.")
    public static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "Attendee")
    public var target: AttendeeEntity

    public init() {}

    public init(target: AttendeeEntity) {
        self.target = target
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Read the public contact fields for \(\.$target)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(dialog: IntentDialog("No conference is loaded."))
        }
        let profile = await ConferenceCatalog.shared.currentAttendee()
        guard let contact = AttendeeContactDisclosure.make(attendeeID: target.id, in: manifest, profile: profile) else {
            return .result(dialog: IntentDialog("That person isn’t in the directory."))
        }
        try await requestConfirmation(
            actionName: .confirm,
            dialog: IntentDialog(stringLiteral: "Show the public contact fields for \(contact.displayName)?")
        )
        return .result(dialog: IntentDialog(stringLiteral: contact.spoken))
    }
}
