import Foundation

public struct Speaker: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var title: String?
    public var company: String?
    public var bio: String
    public var photoURL: URL?
    public var social: [SocialLink]

    public init(
        id: String,
        name: String,
        title: String? = nil,
        company: String? = nil,
        bio: String,
        photoURL: URL? = nil,
        social: [SocialLink] = []
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.company = company
        self.bio = bio
        self.photoURL = photoURL
        self.social = social
    }

    public var affiliation: String {
        [title, company].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

public struct SocialLink: Codable, Hashable, Identifiable, Sendable {
    public var platform: SocialPlatform
    public var url: URL

    public var id: String { "\(platform.rawValue)-\(url.absoluteString)" }

    public init(platform: SocialPlatform, url: URL) {
        self.platform = platform
        self.url = url
    }
}

public enum SocialPlatform: String, Codable, Hashable, Sendable, CaseIterable {
    case x
    case github
    case linkedin
    case mastodon
    case bluesky
    case website
    case youtube

    public var label: String {
        switch self {
        case .x: "X"
        case .github: "GitHub"
        case .linkedin: "LinkedIn"
        case .mastodon: "Mastodon"
        case .bluesky: "Bluesky"
        case .website: "Website"
        case .youtube: "YouTube"
        }
    }
}
