import AppIntents
import ConferenceKit
import Foundation

public struct ConferenceNewsItemEntity: AppEntity {
    public var id: String
    public var title: String
    public var body: String
    public var publishedAt: Date
    public var isPinned: Bool

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "News Item")
    public static let defaultQuery = ConferenceNewsItemEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        let when = publishedAt.formatted(date: .abbreviated, time: .shortened)
        let subtitle = isPinned ? "Pinned · \(when)" : when
        return DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }

    public init(id: String, title: String, body: String, publishedAt: Date, isPinned: Bool) {
        self.id = id
        self.title = title
        self.body = body
        self.publishedAt = publishedAt
        self.isPinned = isPinned
    }

    public init(_ item: ConferenceNewsItem) {
        self.init(id: item.id, title: item.title, body: item.body, publishedAt: item.publishedAt, isPinned: item.isPinned)
    }
}

public struct ConferenceNewsItemEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [ConferenceNewsItemEntity.ID]) async throws -> [ConferenceNewsItemEntity] {
        let items = await all()
        return identifiers.compactMap { id in items.first { $0.id == id } }
    }

    public func suggestedEntities() async throws -> [ConferenceNewsItemEntity] {
        await all()
    }

    public func entities(matching string: String) async throws -> [ConferenceNewsItemEntity] {
        let items = await all()
        guard !string.isEmpty else { return items }
        return items.filter {
            $0.title.localizedStandardContains(string) || $0.body.localizedStandardContains(string)
        }
    }

    private func all() async -> [ConferenceNewsItemEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        return NewsFeed.sorted(manifest.news).map(ConferenceNewsItemEntity.init)
    }
}

public struct ShowLatestNewsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show Latest News"
    public static let description = IntentDescription("Shows conference news, pinned items first, then the newest.")
    public static let openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        ConferenceNavigation.shared.showDestination(.news)
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(dialog: IntentDialog("No conference is loaded."))
        }
        guard let top = NewsFeed.sorted(manifest.news).first else {
            return .result(dialog: IntentDialog("There’s no news yet."))
        }
        let pinned = top.isPinned ? "Pinned. " : ""
        return .result(dialog: IntentDialog(stringLiteral: "\(pinned)\(top.title). \(AnnouncementPlanner.excerpt(top.body, limit: 140))"))
    }
}

public struct ConferenceResourceEntity: AppEntity {
    public var id: String
    public var title: String
    public var kind: String
    public var category: String

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Resource")
    public static let defaultQuery = ConferenceResourceEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(ResourceTransfer.categoryLabel(category)) · \(kind)")
    }

    public init(id: String, title: String, kind: String, category: String) {
        self.id = id
        self.title = title
        self.kind = kind
        self.category = category
    }

    public init(_ resource: ConferenceResource) {
        self.init(id: resource.id, title: resource.title, kind: resource.kind.label, category: resource.category)
    }
}

public struct ConferenceResourceEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [ConferenceResourceEntity.ID]) async throws -> [ConferenceResourceEntity] {
        let items = await all()
        return identifiers.compactMap { id in items.first { $0.id == id } }
    }

    public func suggestedEntities() async throws -> [ConferenceResourceEntity] {
        await all()
    }

    public func entities(matching string: String) async throws -> [ConferenceResourceEntity] {
        let items = await all()
        guard !string.isEmpty else { return items }
        return items.filter {
            $0.title.localizedStandardContains(string)
                || $0.category.localizedStandardContains(string)
                || $0.kind.localizedStandardContains(string)
        }
    }

    private func all() async -> [ConferenceResourceEntity] {
        guard let manifest = await IntentCatalog.manifest() else { return [] }
        return manifest.resources.map(ConferenceResourceEntity.init)
    }
}

public struct ShowResourcesIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show Resources"
    public static let description = IntentDescription("Shows downloadable conference documents, grouped by category.")
    public static let openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        ConferenceNavigation.shared.showDestination(.resources)
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(dialog: IntentDialog("No conference is loaded."))
        }
        let groups = ResourceTransfer.grouped(manifest.resources)
        guard !groups.isEmpty else {
            return .result(dialog: IntentDialog("There are no resources yet."))
        }
        let summary = groups.map { "\($0.resources.count) \($0.label.lowercased())" }.joined(separator: ", ")
        return .result(dialog: IntentDialog(stringLiteral: "Resources: \(summary)."))
    }
}
