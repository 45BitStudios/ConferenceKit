import Foundation

/// A conference announcement. Codable on purpose: notes, sessions, and the
/// manifest are JSON so the same document works on every platform and in an
/// app group. SwiftData is not part of this package.
public struct ConferenceNewsItem: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var publishedAt: Date
    public var linkURL: URL?
    public var imageName: String?
    public var isPinned: Bool
    /// When true, a local notification can fire the first time this item is seen.
    public var announces: Bool

    public init(
        id: String,
        title: String,
        body: String,
        publishedAt: Date,
        linkURL: URL? = nil,
        imageName: String? = nil,
        isPinned: Bool = false,
        announces: Bool = false
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.publishedAt = publishedAt
        self.linkURL = linkURL
        self.imageName = imageName
        self.isPinned = isPinned
        self.announces = announces
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, body, publishedAt, linkURL, imageName, isPinned, announces
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        publishedAt = try container.decode(Date.self, forKey: .publishedAt)
        linkURL = try container.decodeIfPresent(URL.self, forKey: .linkURL)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        announces = try container.decodeIfPresent(Bool.self, forKey: .announces) ?? false
    }
}

public enum NewsFeed {
    /// Pinned items first. Inside each group, newest `publishedAt` first.
    /// Equal dates break ties by title so the order is stable.
    public static func sorted(_ items: [ConferenceNewsItem]) -> [ConferenceNewsItem] {
        items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.publishedAt != rhs.publishedAt { return lhs.publishedAt > rhs.publishedAt }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
}
