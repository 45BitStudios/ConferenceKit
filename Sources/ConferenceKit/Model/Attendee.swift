import Foundation

/// Someone at the conference. Sensitive contact fields stay off every public
/// surface unless that attendee’s privacy flags say otherwise.
public struct Attendee: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var role: String?
    public var company: String?
    public var bio: String
    public var email: String?
    public var phone: String?
    public var social: [SocialLink]
    /// Name of an image in the host asset catalog. Optional.
    public var avatarAsset: String?
    public var avatarURL: URL?
    public var ticket: AttendeeTicket?
    public var privacy: AttendeePrivacy
    /// Separate from directory listing. Both sides must consent before a message can be composed.
    public var messagingConsent: Bool
    /// The manifest may mark the signed-in sample profile. The device profile store can override it.
    public var isCurrentUser: Bool

    public init(
        id: String,
        displayName: String,
        role: String? = nil,
        company: String? = nil,
        bio: String = "",
        email: String? = nil,
        phone: String? = nil,
        social: [SocialLink] = [],
        avatarAsset: String? = nil,
        avatarURL: URL? = nil,
        ticket: AttendeeTicket? = nil,
        privacy: AttendeePrivacy = AttendeePrivacy(),
        messagingConsent: Bool = false,
        isCurrentUser: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.company = company
        self.bio = bio
        self.email = email
        self.phone = phone
        self.social = social
        self.avatarAsset = avatarAsset
        self.avatarURL = avatarURL
        self.ticket = ticket
        self.privacy = privacy
        self.messagingConsent = messagingConsent
        self.isCurrentUser = isCurrentUser
    }

    public var affiliation: String {
        [role, company].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    public var initials: String {
        let parts = displayName.split(whereSeparator: \.isWhitespace).prefix(2)
        let letters = parts.compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    /// Drops email, phone, and social links that are not marked public.
    /// Name, role, company, bio, ticket, and avatar stay. Those are not contact fields.
    public func hidingPrivateContactFields() -> Attendee {
        var copy = self
        if !privacy.showsEmail { copy.email = nil }
        if !privacy.showsPhone { copy.phone = nil }
        if !privacy.showsSocial { copy.social = [] }
        return copy
    }

    /// Directory search. Uses only fields that would be shown publicly.
    public func matchesDirectoryQuery(_ query: String) -> Bool {
        let visible = hidingPrivateContactFields()
        let fields: [String?] = [
            visible.displayName,
            visible.role,
            visible.company,
            visible.bio,
            visible.email,
            visible.phone,
            visible.ticket?.label,
            visible.ticket?.kind
        ]
        if fields.contains(where: { $0?.localizedStandardContains(query) == true }) { return true }
        return visible.social.contains {
            $0.platform.label.localizedStandardContains(query) || $0.url.absoluteString.localizedStandardContains(query)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, displayName, role, company, bio, email, phone, social
        case avatarAsset, avatarURL, ticket, privacy, messagingConsent, isCurrentUser
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        company = try container.decodeIfPresent(String.self, forKey: .company)
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        social = try container.decodeIfPresent([SocialLink].self, forKey: .social) ?? []
        avatarAsset = try container.decodeIfPresent(String.self, forKey: .avatarAsset)
        avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
        ticket = try container.decodeIfPresent(AttendeeTicket.self, forKey: .ticket)
        // Missing privacy means hidden, and every contact field stays private.
        privacy = try container.decodeIfPresent(AttendeePrivacy.self, forKey: .privacy) ?? AttendeePrivacy()
        messagingConsent = try container.decodeIfPresent(Bool.self, forKey: .messagingConsent) ?? false
        isCurrentUser = try container.decodeIfPresent(Bool.self, forKey: .isCurrentUser) ?? false
    }
}

public struct AttendeeTicket: Codable, Hashable, Sendable {
    public var kind: String
    public var label: String?

    public init(kind: String, label: String? = nil) {
        self.kind = kind
        self.label = label
    }

    public var display: String {
        label ?? kind
    }
}

/// Visibility for one attendee. Every flag defaults to off.
public struct AttendeePrivacy: Codable, Hashable, Sendable {
    public var discoverable: Bool
    public var showsEmail: Bool
    public var showsPhone: Bool
    public var showsSocial: Bool

    public init(
        discoverable: Bool = false,
        showsEmail: Bool = false,
        showsPhone: Bool = false,
        showsSocial: Bool = false
    ) {
        self.discoverable = discoverable
        self.showsEmail = showsEmail
        self.showsPhone = showsPhone
        self.showsSocial = showsSocial
    }

    private enum CodingKeys: String, CodingKey {
        case discoverable, showsEmail, showsPhone, showsSocial
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        discoverable = try container.decodeIfPresent(Bool.self, forKey: .discoverable) ?? false
        showsEmail = try container.decodeIfPresent(Bool.self, forKey: .showsEmail) ?? false
        showsPhone = try container.decodeIfPresent(Bool.self, forKey: .showsPhone) ?? false
        showsSocial = try container.decodeIfPresent(Bool.self, forKey: .showsSocial) ?? false
    }
}

public struct AttendeeFilter: Hashable, Sendable {
    public var query: String
    public var ticketKind: String?

    public init(query: String = "", ticketKind: String? = nil) {
        self.query = query
        self.ticketKind = ticketKind
    }
}

extension ConferenceManifest {
    public func attendee(id: String) -> Attendee? {
        attendees.first { $0.id == id }
    }

    /// People who opted into the directory, with private contact fields removed.
    /// `profile` replaces the matching manifest record so My Profile edits show up on this device.
    public func directoryAttendees(profile: Attendee? = nil) -> [Attendee] {
        var records = attendees
        if let profile {
            if let index = records.firstIndex(where: { $0.id == profile.id }) {
                records[index] = profile
            } else {
                records.append(profile)
            }
        }
        return records
            .filter(\.privacy.discoverable)
            .map { $0.hidingPrivateContactFields() }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}

extension ConferenceSearch {
    public static func attendees(
        in manifest: ConferenceManifest,
        matching filter: AttendeeFilter = AttendeeFilter(),
        profile: Attendee? = nil
    ) -> [Attendee] {
        let query = filter.query.trimmingCharacters(in: .whitespacesAndNewlines)
        return manifest.directoryAttendees(profile: profile).filter { attendee in
            if let ticketKind = filter.ticketKind, attendee.ticket?.kind != ticketKind { return false }
            if query.isEmpty { return true }
            return attendee.matchesDirectoryQuery(query)
        }
    }
}
