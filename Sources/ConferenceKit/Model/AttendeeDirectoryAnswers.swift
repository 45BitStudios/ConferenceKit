import Foundation

/// Directory wording for search, Ask, and Siri. Names and roles only.
/// Email, phone, and social links are not included, even when the person marked them public.
/// Those fields go through `AttendeeContactDisclosure` after the device is unlocked.
public struct AttendeeDirectoryAnswer: Equatable, Sendable {
    public var ids: [String]
    public var spoken: String

    public init(ids: [String], spoken: String) {
        self.ids = ids
        self.spoken = spoken
    }
}

public enum AttendeeDirectoryAnswers {
    public static func reply(
        query: String,
        manifest: ConferenceManifest,
        profile: Attendee? = nil
    ) -> AttendeeDirectoryAnswer {
        let matches = ConferenceSearch.attendees(
            in: manifest,
            matching: AttendeeFilter(query: query),
            profile: profile
        )
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let spoken: String
        if matches.isEmpty {
            spoken = trimmed.isEmpty
                ? "No attendees are listed."
                : "I don’t see \(trimmed) in the attendee directory."
        } else {
            let lines = matches.map { person in
                person.affiliation.isEmpty ? person.displayName : "\(person.displayName), \(person.affiliation)"
            }
            spoken = lines.joined(separator: "; ") + "."
        }
        return AttendeeDirectoryAnswer(ids: matches.map(\.id), spoken: spoken)
    }
}

/// Snippet text. A person who is not discoverable contributes no name and no contact fields.
public enum AttendeeSnippetCopy {
    public static func title(for attendee: Attendee) -> String {
        guard attendee.privacy.discoverable else { return "Attendee" }
        let name = attendee.hidingPrivateContactFields().displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Attendee" : name
    }

    public static func detail(for attendee: Attendee) -> String {
        guard attendee.privacy.discoverable else { return "" }
        return attendee.hidingPrivateContactFields().affiliation
    }
}

/// Public contact fields for one directory id. Nil when that person is not listed.
/// The stored email can still exist on the profile; it is omitted unless `showsEmail` is on.
public struct AttendeePublicContact: Equatable, Sendable {
    public var attendeeID: String
    public var displayName: String
    public var email: String?
    public var phone: String?
    public var socialLabels: [String]
    public var spoken: String

    public init(
        attendeeID: String,
        displayName: String,
        email: String?,
        phone: String?,
        socialLabels: [String],
        spoken: String
    ) {
        self.attendeeID = attendeeID
        self.displayName = displayName
        self.email = email
        self.phone = phone
        self.socialLabels = socialLabels
        self.spoken = spoken
    }
}

public enum AttendeeContactDisclosure {
    public static func make(
        attendeeID: String,
        in manifest: ConferenceManifest,
        profile: Attendee? = nil
    ) -> AttendeePublicContact? {
        guard let person = manifest.directoryAttendees(profile: profile).first(where: { $0.id == attendeeID }) else {
            return nil
        }
        let visible = person.hidingPrivateContactFields()
        let social = visible.social.map { "\($0.platform.label) \($0.url.absoluteString)" }
        var pieces = [visible.displayName]
        if let email = visible.email, !email.isEmpty { pieces.append("Email \(email)") }
        if let phone = visible.phone, !phone.isEmpty { pieces.append("Phone \(phone)") }
        if !social.isEmpty { pieces.append(social.joined(separator: ", ")) }
        let spoken: String
        if visible.email == nil && visible.phone == nil && social.isEmpty {
            spoken = "\(visible.displayName) has no public contact fields."
        } else {
            spoken = pieces.joined(separator: ". ") + "."
        }
        return AttendeePublicContact(
            attendeeID: visible.id,
            displayName: visible.displayName,
            email: visible.email.flatMap { $0.isEmpty ? nil : $0 },
            phone: visible.phone.flatMap { $0.isEmpty ? nil : $0 },
            socialLabels: social,
            spoken: spoken
        )
    }
}
