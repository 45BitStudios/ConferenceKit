import ConferenceKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

public enum ConferenceSceneID {
    public static let session = "conferencekit.session"
    public static let speaker = "conferencekit.speaker"
}

enum ConferenceActivity {
    static let session = "studio45.conferencekit.open-session"
    static let speaker = "studio45.conferencekit.open-speaker"

    static func makeSession(_ id: String) -> NSUserActivity {
        let activity = NSUserActivity(activityType: session)
        activity.title = "Session"
        activity.userInfo = ["sessionID": id]
        return activity
    }

    static func makeSpeaker(_ id: String) -> NSUserActivity {
        let activity = NSUserActivity(activityType: speaker)
        activity.title = "Speaker"
        activity.userInfo = ["speakerID": id]
        return activity
    }
}

enum ConferenceWindowRegistration {
    static var sessions = false
    static var speakers = false
}

struct NewSessionWindowButton: View {
    var sessionID: String
    @Environment(\.openWindow) private var openWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

    var body: some View {
        #if os(iOS)
        SessionActivationButton(sessionID: sessionID)
        #elseif os(macOS) || os(visionOS)
        if supportsMultipleWindows {
            Button {
                openWindow(id: ConferenceSceneID.session, value: sessionID)
            } label: {
                Label("New Window", systemImage: "plus.rectangle.on.rectangle")
            }
        }
        #endif
    }
}

#if os(iOS)
/// Uses `UIWindowScene.ActivationAction`, which the system hides when a new
/// window cannot be created (the outer display of iPhone Duo).
struct SessionActivationButton: UIViewRepresentable {
    var sessionID: String

    func makeUIView(context: Context) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "New Window"
        configuration.image = UIImage(systemName: "plus.rectangle.on.rectangle")
        configuration.imagePadding = 4
        let button = UIButton(configuration: configuration)
        let activity = ConferenceActivity.makeSession(sessionID)
        let action = UIWindowScene.ActivationAction(configurationProvider: { _ in
            UIWindowScene.ActivationConfiguration(userActivity: activity)
        })
        button.addAction(action, for: .primaryActionTriggered)
        button.accessibilityLabel = "New Window"
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}
}
#endif

#if os(iOS) || os(macOS) || os(visionOS)
public struct ConferenceSessionScene: Scene {
    let store: ConferenceStore

    public init(store: ConferenceStore) {
        self.store = store
        ConferenceWindowRegistration.sessions = true
    }

    public var body: some Scene {
        WindowGroup(id: ConferenceSceneID.session, for: String.self) { $sessionID in
            ConferenceSessionWindow(store: store, sessionID: sessionID.wrappedValue)
        }
    }
}

public struct ConferenceSpeakerScene: Scene {
    let store: ConferenceStore

    public init(store: ConferenceStore) {
        self.store = store
        ConferenceWindowRegistration.speakers = true
    }

    public var body: some Scene {
        WindowGroup(id: ConferenceSceneID.speaker, for: String.self) { $speakerID in
            ConferenceSpeakerWindow(store: store, speakerID: speakerID.wrappedValue)
        }
    }
}

struct ConferenceSessionWindow: View {
    var store: ConferenceStore
    var sessionID: String?
    @State private var router = ConferenceRouter()

    var body: some View {
        NavigationStack {
            if let sessionID, let session = store.session(id: sessionID) {
                SessionDetail(store: store, router: router, session: session, push: true, showsInlineNotes: true)
            } else {
                EmptyPane(title: "Session", systemImage: "calendar", message: "This window doesn’t have a session.")
            }
        }
        .conferenceTheme(store.theme)
    }
}

struct ConferenceSpeakerWindow: View {
    var store: ConferenceStore
    var speakerID: String?
    @State private var router = ConferenceRouter()

    var body: some View {
        NavigationStack {
            if let speakerID, let speaker = store.speaker(id: speakerID) {
                SpeakerDetail(store: store, router: router, speaker: speaker, push: true)
            } else {
                EmptyPane(title: "Speaker", systemImage: "person", message: "This window doesn’t have a speaker.")
            }
        }
        .conferenceTheme(store.theme)
    }
}
#endif
