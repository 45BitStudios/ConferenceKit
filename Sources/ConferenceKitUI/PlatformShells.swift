import ConferenceKit
import SwiftUI

// Platform-native shells. Each platform leans on its own idiom:
// visionOS tab bar ornament, iPad sidebar-adaptable tabs, tvOS focus cards,
// watchOS vertical pages, macOS split view + toolbar + commands.

extension ConferenceRouter {
    /// The session after the selected one, or the next upcoming session.
    func nextSessionID(in store: ConferenceStore, now: Date = .now) -> String? {
        let sorted = store.sessions.sorted { $0.startTime < $1.startTime }
        if let current = selectedSessionID, let index = sorted.firstIndex(where: { $0.id == current }) {
            return sorted.indices.contains(index + 1) ? sorted[index + 1].id : nil
        }
        return sorted.first { $0.startTime >= now }?.id ?? sorted.first?.id
    }
}

extension ConferenceStore {
    func upcomingSession(now: Date = .now) -> Session? {
        sessions.sorted { $0.startTime < $1.startTime }.first { $0.startTime > now }
    }
}

/// Keyboard search request (macOS ⌘F) wired to `searchFocused` where it exists.
struct SearchFocusRequest: ViewModifier {
    var request: Int
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        #if os(iOS) || os(macOS) || os(visionOS)
        if #available(iOS 18, macOS 15, visionOS 2, *) {
            content
                .searchFocused($focused)
                .onChange(of: request) { _, _ in focused = true }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

#if os(visionOS)
/// visionOS: no sidebar. The TabView's tabs live in the leading ornament; each tab
/// is its own NavigationStack driven by the router's selection.
struct VisionShell: View {
    @Bindable var store: ConferenceStore
    @Bindable var router: ConferenceRouter

    var body: some View {
        TabView(selection: $router.section) {
            stack(.schedule) { ScheduleList(store: store, router: router, push: false) }
            stack(.speakers) { SpeakerList(store: store, router: router, push: false) }
            stack(.favorites) { ScheduleList(store: store, router: router, push: false, favoritesOnly: true) }
            NavigationStack {
                InfoMenu(router: router, push: false)
                    .navigationDestination(item: Binding(get: { router.infoSelection }, set: { router.infoSelection = $0 })) { route in
                        InfoDetail(store: store, router: router, route: route, push: false)
                    }
            }
            .tabItem { Label(ConferenceSection.info.title, systemImage: ConferenceSection.info.systemImage) }
            .tag(ConferenceSection.info)
        }
    }

    private func stack<Content: View>(_ section: ConferenceSection, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationDestination(item: Binding(
                    get: { router.section == section && section != .speakers ? router.selectedSessionID : nil },
                    set: { router.selectedSessionID = $0 }
                )) { id in
                    if let session = store.session(id: id) {
                        SessionDetail(store: store, router: router, session: session, push: false, showsInlineNotes: true)
                    }
                }
                .navigationDestination(item: Binding(
                    get: { router.section == .speakers && section == .speakers ? router.selectedSpeakerID : nil },
                    set: { router.selectedSpeakerID = $0 }
                )) { id in
                    if let speaker = store.speaker(id: id) {
                        SpeakerDetail(store: store, router: router, speaker: speaker, push: false)
                    }
                }
        }
        .searchable(text: $store.searchText, prompt: "Sessions, speakers, notes")
        .tabItem { Label(section.title, systemImage: section.systemImage) }
        .tag(section)
    }
}

/// Bottom ornament with the session actions, on glass.
struct SessionActionsOrnament: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var session: Session
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let saved = store.favorites.contains(session.id)
        HStack(spacing: 12) {
            Button {
                Task { await ConferenceActions.toggleFavorite(store, sessionID: session.id) }
            } label: {
                Label(saved ? "Saved" : "Save", systemImage: saved ? "star.fill" : "star")
            }
            .accessibilityLabel(saved ? "Remove from My Schedule" : "Add to My Schedule")
            Button {
                Task { await SessionActionRunner.remind(store, router: router, session: session) }
            } label: { Label("Remind", systemImage: "alarm") }
            Button {
                Task { router.statusMessage = await ConferenceActions.addToCalendar(store, sessions: [session]) }
            } label: { Label("Calendar", systemImage: "calendar.badge.plus") }
            if ConferenceWindowRegistration.notes {
                Button {
                    openWindow(id: ConferenceSceneID.notes, value: session.id)
                } label: { Label("Notes", systemImage: "note.text") }
            }
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.borderless)
        .padding(12)
        .glassBackgroundEffect()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session.ornament")
    }
}
#endif

@MainActor
enum SessionActionRunner {
    static func remind(_ store: ConferenceStore, router: ConferenceRouter, session: Session) async {
        store.setRemindersEnabled(true)
        if !store.favorites.contains(session.id) {
            await ConferenceActions.toggleFavorite(store, sessionID: session.id)
        } else {
            await ConferenceActions.syncReminders(store)
        }
        router.statusMessage = "Reminder follows this favorite."
    }
}

#if os(iOS)
/// iPad: sidebar-adaptable tabs (tab bar that expands into a sidebar), each tab a
/// content/detail split so notes still sit beside the session.
@available(iOS 18, *)
struct PadTabShell: View {
    @Bindable var store: ConferenceStore
    @Bindable var router: ConferenceRouter

    var body: some View {
        TabView(selection: $router.section) {
            Tab(ConferenceSection.schedule.title, systemImage: ConferenceSection.schedule.systemImage, value: ConferenceSection.schedule) {
                split { ScheduleList(store: store, router: router, push: false) }
            }
            Tab(ConferenceSection.speakers.title, systemImage: ConferenceSection.speakers.systemImage, value: ConferenceSection.speakers) {
                split { SpeakerList(store: store, router: router, push: false) }
            }
            Tab(ConferenceSection.favorites.title, systemImage: ConferenceSection.favorites.systemImage, value: ConferenceSection.favorites) {
                split { ScheduleList(store: store, router: router, push: false, favoritesOnly: true) }
            }
            Tab(ConferenceSection.info.title, systemImage: ConferenceSection.info.systemImage, value: ConferenceSection.info) {
                split { InfoMenu(router: router, push: false) }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    private func split<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationSplitView {
            content()
        } detail: {
            SplitDetail(store: store, router: router)
        }
        .searchable(text: $store.searchText, prompt: "Sessions, speakers, notes")
    }
}
#endif

#if os(tvOS)
/// tvOS: large focusable cards in a grid.
struct TVSessionGrid: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var favoritesOnly = false

    private var sessions: [Session] { favoritesOnly ? store.favoriteSessions : store.sessions }

    var body: some View {
        ScrollView {
            if sessions.isEmpty {
                Text(favoritesOnly ? "Star a session and it lands here." : "Nothing scheduled.")
                    .foregroundStyle(.secondary)
                    .padding(60)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 520), spacing: 48)], spacing: 48) {
                ForEach(sessions) { session in
                    Button {
                        router.openSession(session.id, push: true)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                TimeRangeLabel(session: session, store: store)
                                    .font(.caption)
                                Spacer()
                                if session.isHappening() {
                                    Label("Live", systemImage: "dot.radiowaves.left.and.right")
                                        .font(.caption.bold())
                                        .foregroundStyle(.tint)
                                }
                                if store.favorites.contains(session.id) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.tint)
                                        .accessibilityLabel("Favorited")
                                }
                            }
                            Text(session.title)
                                .font(.headline)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Text(store.speakers(for: session).map(\.name).joined(separator: ", "))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if let room = store.roomName(for: session) {
                                Label(room, systemImage: "mappin.and.ellipse")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(28)
                        .frame(width: 520, height: 280, alignment: .topLeading)
                    }
                    .buttonStyle(.card)
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
    }
}

struct TVSpeakerGrid: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 48)], spacing: 48) {
                ForEach(store.speakers) { speaker in
                    Button {
                        router.openSpeaker(speaker.id, push: true)
                    } label: {
                        VStack(spacing: 12) {
                            SpeakerAvatar(speaker: speaker, diameter: 120)
                            Text(speaker.name).font(.headline).lineLimit(2)
                            Text(speaker.affiliation).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .padding(24)
                        .frame(width: 300, height: 300)
                    }
                    .buttonStyle(.card)
                }
            }
            .padding(60)
        }
    }
}
#endif

#if os(watchOS)
/// watchOS first page: what's on now and what's next.
struct WatchNowNext: View {
    @Bindable var store: ConferenceStore

    var body: some View {
        List {
            Section("Now") {
                if let live = store.liveSessions.first {
                    NavigationLink(value: ConferenceRoute.session(live.id)) {
                        SessionRow(session: live, store: store, emphasized: true)
                    }
                } else {
                    Text("Nothing live").foregroundStyle(.secondary)
                }
            }
            Section("Next") {
                if let next = store.upcomingSession() {
                    NavigationLink(value: ConferenceRoute.session(next.id)) {
                        SessionRow(session: next, store: store)
                    }
                } else {
                    Text("That’s a wrap").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(store.conferenceName)
    }
}
#endif

#if os(macOS)
/// Focused context for menu commands.
struct ConferenceCommandContext {
    var store: ConferenceStore
    var router: ConferenceRouter
}

extension FocusedValues {
    @Entry var conferenceContext: ConferenceCommandContext?
}

/// Menu bar commands: search, favorite, next session.
public struct ConferenceCommands: Commands {
    @FocusedValue(\.conferenceContext) private var context

    public init() {}

    public var body: some Commands {
        CommandMenu("Session") {
            Button("Find Sessions…") {
                context?.router.searchRequest += 1
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(context == nil)

            Button(favoriteTitle) {
                guard let context, let id = context.router.selectedSessionID else { return }
                Task { await ConferenceActions.toggleFavorite(context.store, sessionID: id) }
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(context?.router.selectedSessionID == nil)

            Button("Next Session") {
                guard let context, let id = context.router.nextSessionID(in: context.store) else { return }
                context.router.openSession(id, push: false)
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(context == nil)
        }
    }

    private var favoriteTitle: String {
        guard let context, let id = context.router.selectedSessionID else { return "Add to My Schedule" }
        return context.store.favorites.contains(id) ? "Remove from My Schedule" : "Add to My Schedule"
    }
}
#endif
