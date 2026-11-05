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
                AttendeeDirectory(store: store, router: router, push: true)
                    .tabItem { Label(ConferenceSection.attendees.title, systemImage: ConferenceSection.attendees.systemImage) }
                    .tag(ConferenceSection.attendees)
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
        .searchable(text: $store.searchText, prompt: "Sessions, speakers, attendees, notes")
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
        #if os(macOS)
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Sessions, speakers, attendees, notes")
        .modifier(SearchFocusRequest(request: router.searchRequest))
        .toolbar { macToolbar }
        .focusedSceneValue(\.conferenceContext, ConferenceCommandContext(store: store, router: router))
        #else
        .searchable(text: $store.searchText, prompt: "Sessions, speakers, attendees, notes")
        #endif
    }

    @ViewBuilder
    private var content: some View {
        switch router.section {
        case .schedule:
            ScheduleList(store: store, router: router, push: false)
        case .speakers:
            SpeakerList(store: store, router: router, push: false)
        case .attendees:
            AttendeeDirectory(store: store, router: router, push: false)
        case .favorites:
            ScheduleList(store: store, router: router, push: false, favoritesOnly: true)
        case .workshops:
            ScheduleList(store: store, router: router, push: false, workshopsOnly: true)
        case .info:
            InfoMenu(router: router, push: false)
        }
    }

    private var detail: some View {
        SplitDetail(store: store, router: router)
    }

    #if os(macOS)
    @ToolbarContentBuilder
    private var macToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                if let live = store.liveSessions.first { router.openSession(live.id, push: false) }
            } label: {
                Label("Now", systemImage: "dot.radiowaves.left.and.right")
            }
            .help("Jump to the session happening now")
            .disabled(store.liveSessions.isEmpty)
            Button {
                if let id = router.nextSessionID(in: store) { router.openSession(id, push: false) }
            } label: {
                Label("Next Session", systemImage: "forward.end")
            }
            .help("Next session (⌘])")
        }
    }
    #endif
}

struct SplitDetail: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter

    var body: some View {
        detail
    }

    @ViewBuilder
    private var detail: some View {
        if router.section == .info, let route = router.infoSelection {
            InfoDetail(store: store, router: router, route: route, push: false)
        } else if router.section == .speakers, let id = router.selectedSpeakerID, let speaker = store.speaker(id: id) {
            SpeakerDetail(store: store, router: router, speaker: speaker, push: false)
        } else if router.section == .attendees {
            AttendeeColumn(store: store, router: router, push: false)
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

#if os(watchOS)
struct WatchShell: View {
    @Bindable var store: ConferenceStore
    @Bindable var router: ConferenceRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            TabView {
                WatchNowNext(store: store)
                List(store.sessions) { session in
                    NavigationLink(value: ConferenceRoute.session(session.id)) {
                        SessionRow(session: session, store: store, emphasized: session.isHappening())
                    }
                }
                .navigationTitle("Schedule")
                List {
                    if store.favoriteSessions.isEmpty {
                        Text("Star a session and it lands here.").foregroundStyle(.secondary)
                    }
                    ForEach(store.favoriteSessions) { session in
                        NavigationLink(value: ConferenceRoute.session(session.id)) {
                            SessionRow(session: session, store: store)
                        }
                    }
                }
                .navigationTitle("My Schedule")
                List(store.speakers) { speaker in
                    NavigationLink(value: ConferenceRoute.speaker(speaker.id)) {
                        Text(speaker.name)
                    }
                }
                .navigationTitle("Speakers")
                AttendeeDirectory(store: store, router: router, push: true)
            }
            .tabViewStyle(.verticalPage)
            .navigationDestination(for: ConferenceRoute.self) { route in
                RoutedDetail(store: store, router: router, route: route, push: true, inlineNotes: true)
            }
        }
    }
}

#endif

#if os(tvOS)
struct TVShell: View {
    @Bindable var store: ConferenceStore
    @Bindable var router: ConferenceRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            TabView(selection: $router.section) {
                TVSessionGrid(store: store, router: router)
                    .tabItem { Label("Schedule", systemImage: "calendar") }
                    .tag(ConferenceSection.schedule)
                TVSpeakerGrid(store: store, router: router)
                    .tabItem { Label("Speakers", systemImage: "person.2") }
                    .tag(ConferenceSection.speakers)
                TVAttendeeGrid(store: store, router: router)
                    .tabItem { Label("Attendees", systemImage: "person.3") }
                    .tag(ConferenceSection.attendees)
                TVSessionGrid(store: store, router: router, favoritesOnly: true)
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

#endif

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
        case .attendee(let id):
            if let attendee = store.visibleAttendee(id: id) {
                AttendeeDetail(store: store, router: router, attendee: attendee, push: push, allowsUnlisted: store.profileStore?.profile.id == id)
            }
        case .myProfile:
            MyProfileScreen(store: store, router: router)
        case .messages:
            ConversationList(store: store, router: router, push: push)
        case .conversation(let id):
            ConversationScreen(store: store, router: router, conversationID: id)
        default:
            InfoDetail(store: store, router: router, route: route, push: push)
        }
    }
}
