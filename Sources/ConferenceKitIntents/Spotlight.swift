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
        #endif
    }
}
