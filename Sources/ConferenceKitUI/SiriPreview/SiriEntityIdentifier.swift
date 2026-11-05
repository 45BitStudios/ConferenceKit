import SwiftUI
#if SIRI_AI_PREVIEW && (os(iOS) || os(macOS) || os(visionOS))
import AppIntents
import ConferenceKitIntents
#endif

/// Which App Intents entity a row shows, so Siri can resolve "this session" on screen.
enum SiriRowEntity {
    case session(String)
    case speaker(String)
    case note(UUID)
    case news(String)
    case resource(String)
}

extension View {
    /// Tags the row with `appEntityIdentifier` in the Siri preview on 27.3. Otherwise does nothing.
    @ViewBuilder
    func siriEntity(_ entity: SiriRowEntity) -> some View {
        #if SIRI_AI_PREVIEW && (os(iOS) || os(macOS) || os(visionOS))
        if #available(iOS 27.3, macOS 27.3, visionOS 27.3, *) {
            switch entity {
            case .session(let id):
                appEntityIdentifier(EntityIdentifier(for: SessionEntity.self, identifier: id))
            case .speaker(let id):
                appEntityIdentifier(EntityIdentifier(for: SpeakerEntity.self, identifier: id))
            case .note(let id):
                appEntityIdentifier(EntityIdentifier(for: SessionNoteEntity.self, identifier: id.uuidString))
            case .news(let id):
                appEntityIdentifier(EntityIdentifier(for: ConferenceNewsItemEntity.self, identifier: id))
            case .resource(let id):
                appEntityIdentifier(EntityIdentifier(for: ConferenceResourceEntity.self, identifier: id))
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
}
