import AppIntents
import ConferenceKit
import ConferenceKitIntents
import ConferenceKitUI
import SwiftUI

/// Registers the kit's intents and entities with this app target.
struct HostIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [ConferenceIntentsPackage.self]
    }
}

@main
struct ConferenceKitDemoApp: App {
    @State private var store: ConferenceStore

    init() {
        ConferenceKitConfiguration.shared.configure(appGroupIdentifier: nil)
        ConferenceKitConfiguration.shared.setUseAlarmKit(false)
        _store = State(initialValue: ConferenceStore(source: .sample))
    }

    var body: some Scene {
        WindowGroup {
            DemoLoader(fallback: store)
        }
        #if os(iOS) || os(macOS) || os(visionOS)
        // Detail windows; ConferenceKitUI doesn't ship them on tvOS.
        ConferenceSessionScene(store: store)
        ConferenceSpeakerScene(store: store)
        #endif
    }
}

/// Builds the store from the date-shifted sample, then shows the kit.
struct DemoLoader: View {
    var fallback: ConferenceStore
    @State private var store: ConferenceStore?

    var body: some View {
        Group {
            if let store {
                DemoRoot(store: store)
            } else {
                ProgressView("Loading sample")
            }
        }
        .task {
            guard store == nil else { return }
            if let manifest = try? await DemoSchedule.manifest() {
                store = ConferenceStore(source: .manifest(manifest))
            } else {
                store = fallback
            }
        }
    }
}

/// The kit's root view plus a small demo menu (Ask, diagnostics) and a pose readout.
struct DemoRoot: View {
    var store: ConferenceStore
    @State private var showsAsk = false
    @State private var showsDiagnostics = false
    @State private var division = "inactive"

    var body: some View {
        ConferenceAppView(store: store)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { division = Self.describe(proxy) }
                        .onChange(of: proxy.size) { _, _ in division = Self.describe(proxy) }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 8) {
                    Text(division)
                        .accessibilityIdentifier("demo.division")
                    Button("Ask") { showsAsk = true }
                        .accessibilityIdentifier("demo.ask")
                    Button("Diag") { showsDiagnostics = true }
                        .accessibilityIdentifier("demo.diagnostics")
                }
                .font(.caption2.monospaced())
                .padding(6)
                .background(.thinMaterial, in: Capsule())
                .padding(.leading, 12)
                .padding(.bottom, 2)
            }
            .sheet(isPresented: $showsAsk) { AskDemoView(store: store) }
            .sheet(isPresented: $showsDiagnostics) { DiagnosticsView(store: store) }
    }

    static func describe(_ proxy: GeometryProxy) -> String {
        let size = proxy.size
        var text = "\(Int(size.width))x\(Int(size.height))"
        #if os(iOS)
        // Division reserved regions are a Duo (iOS) concept; visionOS windows report size only.
        if #available(iOS 27.1, *) {
            let regions = proxy.reservedRegions(kind: .division)
            if let region = regions.first(where: \.isActive) ?? regions.first {
                let f = region.frame
                let axis = f.width > f.height ? "horizontal" : "vertical"
                text += " div \(region.isActive ? "on" : "off") \(axis) \(Int(f.width))x\(Int(f.height))@\(Int(f.minY))"
            } else {
                text += " div none"
            }
        }
        #endif
        return text
    }
}
