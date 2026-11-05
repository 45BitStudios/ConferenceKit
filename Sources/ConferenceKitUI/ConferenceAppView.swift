import ConferenceKit
import ConferenceKitIntents
import SwiftUI
#if os(iOS)
import UIKit
#endif

public struct ConferenceAppView: View {
    @State private var store: ConferenceStore
    @State private var router = ConferenceRouter()
    @State private var containerSize: CGSize = .zero
    @State private var division = DivisionMeasurement.inactive
    @State private var hingeTilt = 0.0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    public init(source: ConferenceSource) {
        _store = State(initialValue: ConferenceStore(source: source))
    }

    public init(store: ConferenceStore) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        shell
            .conferenceTheme(store.theme)
            .modifier(ContainerMeasure(size: $containerSize, division: $division))
            .modifier(HingeTilt(tilt: $hingeTilt))
            .conferenceCoverCompanion(
                enabled: Binding(get: { router.coverCompanionEnabled }, set: { router.coverCompanionEnabled = $0 }),
                available: Binding(get: { router.coverCompanionAvailable }, set: { router.coverCompanionAvailable = $0 }),
                title: coverTitle
            )
            .task {
                router.followLive = FollowLivePreference.load(from: ConferenceKitConfiguration.shared.resolvedDefaults())
                ConferenceRuntime.shared.store = store
                ConferenceIntentsBootstrap.prepare()
                await store.load()
                await ConferenceIntentsBootstrap.didLoad(store)
            }
            .onChange(of: router.coverCompanionEnabled) { _, enabled in
                Task { await updateSlideCapture(enabled) }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, let id = store.manifest?.conference.id else { return }
                store.favorites.scope(to: id)
            }
            .onOpenURL { url in
                guard let link = ConferenceLink.parse(url) else { return }
                apply(link)
            }
            .onContinueUserActivity(ConferenceActivity.session) { activity in
                if let id = activity.userInfo?["sessionID"] as? String {
                    router.openSession(id, push: pose == .compact)
                }
            }
            .onContinueUserActivity(ConferenceActivity.speaker) { activity in
                if let id = activity.userInfo?["speakerID"] as? String {
                    router.openSpeaker(id, push: pose == .compact)
                }
            }
            .onChange(of: navigationToken) { _, _ in
                applyPendingNavigation()
            }
            .alert("Conference", isPresented: statusPresented) {
                Button("OK", role: .cancel) { router.statusMessage = nil }
            } message: {
                Text(router.statusMessage ?? "")
            }
            .alert("Couldn’t Open Window", isPresented: sceneErrorPresented) {
                Button("OK", role: .cancel) {
                    ConferenceNavigation.shared.sceneActivationError = nil
                }
            } message: {
                Text(ConferenceNavigation.shared.sceneActivationError ?? "")
            }
            .overlay(alignment: .top) {
                if store.isStale, let message = store.lastError {
                    StatusBanner(text: message)
                }
            }
    }

    private var pose: DuoPose {
        #if os(watchOS) || os(tvOS) || os(visionOS)
        return .compact
        #else
        return DuoLayout.pose(
            containerWidth: containerSize.width,
            containerHeight: containerSize.height,
            horizontallyCompact: horizontalSizeClass == .compact,
            division: division
        )
        #endif
    }

    @ViewBuilder
    private var shell: some View {
        if store.manifest == nil && store.lastError == nil {
            ProgressView("Loading \(store.conferenceName)")
        } else if store.manifest == nil {
            EmptyPane(
                title: "Couldn’t load",
                systemImage: "exclamationmark.triangle",
                message: store.lastError ?? "The conference JSON didn’t load."
            )
        } else {
            #if os(watchOS)
            WatchShell(store: store, router: router)
            #elseif os(tvOS)
            TVShell(store: store, router: router)
            #elseif os(visionOS)
            VisionShell(store: store, router: router)
            #else
            switch pose {
            case .compact:
                CompactShell(store: store, router: router)
            case .regular:
                #if os(iOS)
                if #available(iOS 18, *), UIDevice.current.userInterfaceIdiom == .pad {
                    PadTabShell(store: store, router: router)
                } else {
                    RegularShell(store: store, router: router)
                }
                #else
                RegularShell(store: store, router: router)
                #endif
            case .book:
                BookShell(store: store, router: router, division: division, container: containerSize)
            case .laptop:
                LaptopShell(store: store, router: router, division: division, container: containerSize, tilt: hingeTilt)
            }
            #endif
        }
    }

    private var navigationToken: String {
        let navigation = ConferenceNavigation.shared
        return [
            navigation.pendingSessionID ?? "",
            navigation.pendingSpeakerID ?? "",
            navigation.pendingSearch ?? "",
            navigation.pendingSection?.rawValue ?? "",
            navigation.pendingDestination?.rawValue ?? "",
            navigation.pendingShowsNotes ? "notes" : ""
        ].joined(separator: "|")
    }

    private var statusPresented: Binding<Bool> {
        Binding(get: { router.statusMessage != nil }, set: { if !$0 { router.statusMessage = nil } })
    }

    private var sceneErrorPresented: Binding<Bool> {
        Binding(
            get: { ConferenceNavigation.shared.sceneActivationError != nil },
            set: { if !$0 { ConferenceNavigation.shared.sceneActivationError = nil } }
        )
    }

    private func applyPendingNavigation() {
        let navigation = ConferenceNavigation.shared
        let push = pose == .compact
        if let section = navigation.pendingSection {
            router.section = section
            navigation.pendingSection = nil
        }
        if let destination = navigation.pendingDestination {
            router.open(destination.route, push: push)
            navigation.pendingDestination = nil
        }
        if let query = navigation.pendingSearch {
            store.searchText = query
            navigation.pendingSearch = nil
        }
        if let id = navigation.pendingSessionID {
            router.openSession(id, push: push)
            if navigation.pendingShowsNotes {
                router.showsNotes = true
            }
            navigation.pendingSessionID = nil
            navigation.pendingShowsNotes = false
        }
        if let id = navigation.pendingSpeakerID {
            router.openSpeaker(id, push: push)
            navigation.pendingSpeakerID = nil
        }
    }

    private var coverTitle: String {
        let id = router.selectedSessionID
        return id.flatMap { store.session(id: $0)?.title } ?? store.liveSessions.first?.title ?? store.conferenceName
    }

    private func updateSlideCapture(_ enabled: Bool) async {
        if enabled {
            let started = await SlideCaptureController.shared.start()
            if !started {
                router.coverCompanionEnabled = false
                router.statusMessage = SlideCaptureController.shared.statusMessage ?? "The camera could not start."
            }
        } else {
            SlideCaptureController.shared.stop()
        }
    }

    private func apply(_ link: ConferenceLink) {
        let push = pose == .compact
        switch link {
        case .session(let id): router.openSession(id, push: push)
        case .speaker(let id): router.openSpeaker(id, push: push)
        case .schedule: router.section = .schedule
        case .favorites: router.section = .favorites
        case .info: router.section = .info
        }
    }
}
