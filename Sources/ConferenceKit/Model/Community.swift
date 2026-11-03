import Foundation

public struct Sponsor: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var tier: SponsorTier
    public var url: URL?
    public var logoURL: URL?
    public var blurb: String?

    public init(
        id: String,
        name: String,
        tier: SponsorTier = .community,
        url: URL? = nil,
        logoURL: URL? = nil,
        blurb: String? = nil
    ) {
        self.id = id
        self.name = name
        self.tier = tier
        self.url = url
        self.logoURL = logoURL
        self.blurb = blurb
    }
}

public enum SponsorTier: String, Codable, Hashable, Sendable, CaseIterable {
    case title
    case diamond
    case gold
    case silver
    case community
    case other

    public var label: String {
        switch self {
        case .title: "Title"
        case .diamond: "Diamond"
        case .gold: "Gold"
        case .silver: "Silver"
        case .community: "Community"
        case .other: "Sponsor"
        }
    }
}

public struct Organizer: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var role: String?
    public var url: URL?
    public var bio: String?

    public init(id: String, name: String, role: String? = nil, url: URL? = nil, bio: String? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.url = url
        self.bio = bio
    }
}

public struct Announcement: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var postedAt: Date
    public var url: URL?

    public init(id: String, title: String, body: String, postedAt: Date, url: URL? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.postedAt = postedAt
        self.url = url
    }
}

public struct CodeOfConduct: Codable, Hashable, Sendable {
    public var summary: String
    public var url: URL?
    public var contactEmail: String?

    public init(summary: String, url: URL? = nil, contactEmail: String? = nil) {
        self.summary = summary
        self.url = url
        self.contactEmail = contactEmail
    }
}

public struct WiFiInfo: Codable, Hashable, Sendable {
    public var networkName: String
    public var password: String?
    public var notes: String?

    public init(networkName: String, password: String? = nil, notes: String? = nil) {
        self.networkName = networkName
        self.password = password
        self.notes = notes
    }
}

public struct ManifestIssue: Hashable, Sendable {
    public var message: String

    public init(message: String) {
        self.message = message
    }
}
