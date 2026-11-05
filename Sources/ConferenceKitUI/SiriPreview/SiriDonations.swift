import ConferenceKit
#if SIRI_AI_PREVIEW && (os(iOS) || os(macOS) || os(visionOS))
import AppIntents
import ConferenceKitIntents
#endif

/// Donates in-app actions as the matching Siri tools, so Siri learns what the person does.
/// Does nothing unless the Siri preview flag is on and the OS is 27.3.
@MainActor
enum SiriDonations {
    static func favorite(_ store: ConferenceStore, sessionID: String) {
        #if SIRI_AI_PREVIEW && (os(iOS) || os(macOS) || os(visionOS))
        guard #available(iOS 27.3, macOS 27.3, visionOS 27.3, *),
              let manifest = store.manifest, let session = store.session(id: sessionID) else { return }
        let intent = FavoriteSessionTool()
        intent.session = SessionEntity(session, manifest: manifest)
        intent.favorite = store.favorites.contains(sessionID)
        Task { _ = try? await IntentDonationManager.shared.donate(intent: intent) }
        #endif
    }

    static func note(_ store: ConferenceStore, text: String, session: Session) {
        #if SIRI_AI_PREVIEW && (os(iOS) || os(macOS) || os(visionOS))
        guard #available(iOS 27.3, macOS 27.3, visionOS 27.3, *), let manifest = store.manifest else { return }
        var draft = SessionNoteDraft()
        draft.text = text
        let intent = CreateSessionNoteIntent()
        intent.draft = draft
        intent.session = SessionEntity(session, manifest: manifest)
        Task { _ = try? await IntentDonationManager.shared.donate(intent: intent) }
        #endif
    }
}
