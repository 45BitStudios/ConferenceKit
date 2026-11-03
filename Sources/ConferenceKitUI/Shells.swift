import ConferenceKit
import SwiftUI

struct CompactShell: View {
    @Bindable var store: ConferenceStore
    @Bindable var router: ConferenceRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            TabView(selection: $router.section) {
                ScheduleList(store: store, router: router, push: true)
                    .tabItem { Label(ConferenceSection.schedule.title, systemImage: ConferenceSection.schedule.systemImage) }
                    .tag(ConferenceSection.schedule)
                SpeakerList(store: store, router: router, push: true)
                    .tabItem { Label(ConferenceSection.speakers.title, systemImage: ConferenceSection.speakers.systemImage) }
                    .tag(ConferenceSection.speakers)
                ScheduleList(store: store, router: router, push: true, favoritesOnly: true)
                    .tabItem { Label(ConferenceSection.favorites.title, systemImage: ConferenceSection.favorites.systemImage) }
                    .tag(ConferenceSection.favorites)
                InfoMenu(router: router, push: true)
                    .tabItem { Label(ConferenceSection.info.title, systemImage: ConferenceSection.info.systemImage) }
                    .tag(ConferenceSection.info)
            }
            .navigationDestination(for: ConferenceRoute.self) { route in
                RoutedDetail(store: store, router: router, route: route, push: true, inlineNotes: true)
            }
        }
        .searchable(text: $store.searchText, prompt: "Sessions, speakers, notes")
    }
}

struct RegularShell: View {
    @Bindable var store: ConferenceStore
    @Bindable var router: ConferenceRouter

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(ConferenceSection.allCases.filter { $0 != .workshops }) { section in
                    Button {
                        router.section = section
                    } label: {
                        Label(section.title, systemImage: section.systemImage)
                            .font(router.section == section ? .headline : .body)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(router.section == section ? .isSelected : [])
                }
            }
            .navigationTitle(store.conferenceName)
        } content: {
            content
        } detail: {
            detail
        }
        .searchable(text: $store.searchText, prompt: "Sessions, speakers, notes")
    }

    @ViewBuilder
    private var content: some View {
        switch router.section {
        case .schedule:
            ScheduleList(store: store, router: router, push: false)
        case .speakers:
            SpeakerList(store: store, router: router, push: false)
        case .favorites:
            ScheduleList(store: store, router: router, push: false, favoritesOnly: true)
        case .workshops:
            ScheduleList(store: store, router: router, push: false, workshopsOnly: true)
        case .info:
            InfoMenu(router: router, push: false)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if router.section == .info, let route = router.infoSelection {
            InfoDetail(store: store, router: router, route: route, push: false)
        } else if router.section == .speakers, let id = router.selectedSpeakerID, let speaker = store.speaker(id: id) {
            SpeakerDetail(store: store, router: router, speaker: speaker, push: false)
        } else if let id = router.selectedSessionID, let session = store.session(id: id) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    SessionDetail(store: store, router: router, session: session, push: false, showsInlineNotes: false)
                        .frame(minWidth: 320)
                    Divider()
                    NotesEditor(store: store, session: session)
                        .frame(minWidth: 280)
                }
                SessionDetail(store: store, router: router, session: session, push: false, showsInlineNotes: true)
            }
        } else {
            EmptyPane(title: store.conferenceName, systemImage: "calendar", message: "Choose something from the schedule.")
        }
    }
}

struct WatchShell: View {
    @Bindable var store: ConferenceStore
    @Bindable var router: ConferenceRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            List {
                if let live = store.liveSessions.first {
                    Section("Now") {
                        Button {
                            router.openSession(live.id, push: true)
                        } label: {
                            SessionRow(session: live, store: store, emphasized: true)
                        }
                    }
                }
                Section("Browse") {
                    Button("Schedule") { router.section = .schedule }
                    Button("Speakers") { router.section = .speakers }
                    Button("My Schedule") { router.section = .favorites }
                }
                if router.section == .speakers {
                    ForEach(store.speakers) { speaker in
                        NavigationLink(value: ConferenceRoute.speaker(speaker.id)) {
                            Text(speaker.name)
                        }
                    }
                } else {
                    ForEach(router.section == .favorites ? store.favoriteSessions : store.sessions) { session in
                        NavigationLink(value: ConferenceRoute.session(session.id)) {
                            SessionRow(session: session, store: store)
                        }
                    }
                }
            }
            .navigationTitle(store.conferenceName)
            .navigationDestination(for: ConferenceRoute.self) { route in
                RoutedDetail(store: store, router: router, route: route, push: true, inlineNotes: true)
            }
        }
    }
}

struct TVShell: View {
    @Bindable var store: ConferenceStore
    @Bindable var router: ConferenceRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            TabView(selection: $router.section) {
                ScheduleList(store: store, router: router, push: true)
                    .tabItem { Label("Schedule", systemImage: "calendar") }
                    .tag(ConferenceSection.schedule)
                SpeakerList(store: store, router: router, push: true)
                    .tabItem { Label("Speakers", systemImage: "person.2") }
                    .tag(ConferenceSection.speakers)
                ScheduleList(store: store, router: router, push: true, favoritesOnly: true)
                    .tabItem { Label("My Schedule", systemImage: "star") }
                    .tag(ConferenceSection.favorites)
                InfoMenu(router: router, push: true)
                    .tabItem { Label("Info", systemImage: "info.circle") }
                    .tag(ConferenceSection.info)
            }
            .navigationDestination(for: ConferenceRoute.self) { route in
                RoutedDetail(store: store, router: router, route: route, push: true, inlineNotes: true)
            }
        }
    }
}

struct RoutedDetail: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var route: ConferenceRoute
    var push: Bool
    var inlineNotes: Bool

    var body: some View {
        switch route {
        case .session(let id):
            if let session = store.session(id: id) {
                SessionDetail(store: store, router: router, session: session, push: push, showsInlineNotes: inlineNotes)
            }
        case .speaker(let id):
            if let speaker = store.speaker(id: id) {
                SpeakerDetail(store: store, router: router, speaker: speaker, push: push)
            }
        default:
            InfoDetail(store: store, router: router, route: route, push: push)
        }
    }
}
