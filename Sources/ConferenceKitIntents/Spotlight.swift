import ConferenceKit
import Foundation
import AppIntents
#if canImport(CoreSpotlight) && !os(tvOS)
import CoreSpotlight

@available(iOS 18.0, macOS 15.0, watchOS 11.0, visionOS 2.0, *)
extension SessionEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = title
        attributes.contentDescription = synopsis
        attributes.comment = speakerNames
        return attributes
    }
}

@available(iOS 18.0, macOS 15.0, watchOS 11.0, visionOS 2.0, *)
extension SpeakerEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = name
        attributes.contentDescription = bio
        attributes.comment = affiliation
        return attributes
    }
}

@available(iOS 18.0, macOS 15.0, watchOS 11.0, visionOS 2.0, *)
extension ConferenceNewsItemEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = title
        attributes.contentDescription = body
        attributes.keywords = isPinned ? ["news", "pinned"] : ["news"]
        return attributes
    }
}

@available(iOS 18.0, macOS 15.0, watchOS 11.0, visionOS 2.0, *)
extension ConferenceResourceEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = title
        attributes.contentDescription = "\(category) \(kind)"
        attributes.keywords = ["resource", category, kind]
        return attributes
    }
}
#endif

public enum ConferenceSpotlight {
    public static func reindex(_ manifest: ConferenceManifest) async {
        #if canImport(CoreSpotlight) && !os(tvOS)
        guard #available(iOS 18.0, macOS 15.0, watchOS 11.0, visionOS 2.0, *) else { return }
        let index = CSSearchableIndex(name: "ConferenceKit")
        try? await index.deleteAllSearchableItems()
        let sessions = manifest.sessions.map { SessionEntity($0, manifest: manifest) }
        let speakers = manifest.speakers.map(SpeakerEntity.init)
        try? await index.indexAppEntities(sessions)
        try? await index.indexAppEntities(speakers)
        try? await index.indexAppEntities(NewsFeed.sorted(manifest.news).map(ConferenceNewsItemEntity.init))
        try? await index.indexAppEntities(manifest.resources.map(ConferenceResourceEntity.init))
        #endif
    }
}
