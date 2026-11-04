import ConferenceKit
import ConferenceKitUI
import SwiftUI

/// Standalone watch host: the kit's watch shell (now/next first, vertical pages).
@main
struct ConferenceKitWatchDemoApp: App {
    init() {
        ConferenceKitConfiguration.shared.configure(appGroupIdentifier: nil)
    }

    var body: some Scene {
        WindowGroup {
            WatchDemoLoader()
        }
    }
}

struct WatchDemoLoader: View {
    @State private var store: ConferenceStore?

    var body: some View {
        Group {
            if let store {
                ConferenceAppView(store: store)
            } else {
                ProgressView()
            }
        }
        .task {
            guard store == nil else { return }
            if let manifest = try? await DemoSchedule.manifest() {
                store = ConferenceStore(source: .manifest(manifest))
            } else {
                store = ConferenceStore(source: .sample)
            }
        }
    }
}
