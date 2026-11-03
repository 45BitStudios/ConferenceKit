import ConferenceKit
#if os(iOS)
import ConferenceKitIntents
#endif
import SwiftUI
#if canImport(MapKit) && !os(watchOS) && !os(tvOS)
import MapKit
#endif
#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

struct SpeakerList: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var push: Bool

    private var speakers: [Speaker] {
        guard let manifest = store.manifest else { return [] }
        return ConferenceSearch.speakers(in: manifest, matching: store.searchText)
    }

    var body: some View {
        List(speakers) { speaker in
            Button {
                router.openSpeaker(speaker.id, push: push)
            } label: {
                HStack {
                    SpeakerAvatar(speaker: speaker)
                    VStack(alignment: .leading) {
                        Text(speaker.name).font(.headline)
                        if !speaker.affiliation.isEmpty {
                            Text(speaker.affiliation).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Speakers")
    }
}

struct InfoMenu: View {
    var router: ConferenceRouter
    var push: Bool

    var body: some View {
        List(InfoRoute.allCases) { item in
            Button {
                router.open(item.route, push: push)
            } label: {
                Label(item.title, systemImage: item.systemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Info")
    }
}

struct InfoDetail: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var route: ConferenceRoute
    var push: Bool

    var body: some View {
        switch route {
        case .venue: VenueScreen(store: store)
        case .wifi: WiFiScreen(store: store)
        case .announcements: AnnouncementList(store: store, router: router, push: push)
        case .announcement(let id):
            if let item = store.announcements.first(where: { $0.id == id }) {
                AnnouncementDetail(item: item)
            }
        case .sponsors: SponsorList(store: store)
        case .organizers: OrganizerList(store: store)
        case .workshops: ScheduleList(store: store, router: router, push: push, workshopsOnly: true)
        case .notes: NotesSearchScreen(store: store, router: router, push: push)
        case .conduct: ConductScreen(store: store)
        case .settings: SettingsScreen(store: store, router: router)
        default: EmptyPane(title: "Info", systemImage: "info.circle", message: "Pick a topic.")
        }
    }
}

struct VenueScreen: View {
    let store: ConferenceStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let venue = store.manifest?.conference.venue {
                    Text(venue.name).font(.title2.weight(.semibold))
                    if !venue.postalAddress.isEmpty {
                        Text(venue.postalAddress)
                    }
                    if let directions = venue.directions {
                        Text(directions).font(.body)
                    }
                    #if canImport(MapKit) && !os(watchOS) && !os(tvOS)
                    if let coordinate = venue.coordinate {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        ))) {
                            Marker(venue.name, coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude))
                        }
                        .frame(minHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    #endif
                    if let url = venue.directionsURL {
                        Link(destination: url) { Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond") }
                    }
                } else {
                    Text("No venue is listed.")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Venue")
    }
}

struct WiFiScreen: View {
    let store: ConferenceStore
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let wifi = store.manifest?.wifi {
                LabeledContent("Network", value: wifi.networkName)
                if let password = wifi.password {
                    LabeledContent("Password", value: revealed ? password : "••••••••")
                    Button(revealed ? "Hide password" : "Show password") { revealed.toggle() }
                    Button { copy(password) } label: { Label("Copy password", systemImage: "doc.on.doc") }
                }
                if let notes = wifi.notes { Text(notes) }
            } else {
                Text("Wi-Fi details aren’t in this manifest.")
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Wi-Fi")
    }

    private func copy(_ value: String) {
        #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        UIPasteboard.general.string = value
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #endif
    }
}

struct AnnouncementList: View {
    let store: ConferenceStore
    var router: ConferenceRouter
    var push: Bool

    var body: some View {
        List(store.announcements) { item in
            Button {
                router.open(.announcement(item.id), push: push)
            } label: {
                VStack(alignment: .leading) {
                    Text(item.title).font(.headline)
                    Text(item.postedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Announcements")
    }
}

struct AnnouncementDetail: View {
    let item: Announcement
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title).font(.title2.weight(.semibold))
                Text(item.body)
                if let url = item.url {
                    Link(destination: url) { Label("Open link", systemImage: "link") }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("News")
    }
}

struct SponsorList: View {
    let store: ConferenceStore
    var body: some View {
        List {
            if let manifest = store.manifest {
                ForEach(manifest.sponsorsByTier, id: \.tier) { group in
                    Section(group.tier.label) {
                        ForEach(group.sponsors) { sponsor in
                            VStack(alignment: .leading) {
                                if let url = sponsor.url {
                                    Link(sponsor.name, destination: url).font(.headline)
                                } else {
                                    Text(sponsor.name).font(.headline)
                                }
                                if let blurb = sponsor.blurb { Text(blurb).font(.subheadline) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Sponsors")
    }
}

struct OrganizerList: View {
    let store: ConferenceStore
    var body: some View {
        List(store.organizers) { organizer in
            VStack(alignment: .leading) {
                Text(organizer.name).font(.headline)
                if let role = organizer.role { Text(role).foregroundStyle(.secondary) }
                if let bio = organizer.bio { Text(bio).font(.subheadline) }
                if let url = organizer.url {
                    Link(destination: url) { Label("Website", systemImage: "link") }
                }
            }
        }
        .navigationTitle("Organizers")
    }
}

struct ConductScreen: View {
    let store: ConferenceStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let conduct = store.manifest?.codeOfConduct {
                    Text(conduct.summary)
                    if let url = conduct.url {
                        Link(destination: url) { Label("Full code of conduct", systemImage: "safari") }
                    }
                    if let email = conduct.contactEmail, let url = URL(string: "mailto:\(email)") {
                        Link(destination: url) { Label(email, systemImage: "envelope") }
                    }
                } else {
                    Text("No code of conduct is in this manifest.")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Code of Conduct")
    }
}

struct NotesSearchScreen: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var push: Bool
    @State private var query = ""

    var body: some View {
        List {
            let notes = store.notesStore?.search(query, manifest: store.manifest) ?? []
            if notes.isEmpty {
                Text("No notes yet.")
            }
            ForEach(notes) { note in
                Button {
                    router.openSession(note.sessionID, push: push)
                } label: {
                    VStack(alignment: .leading) {
                        Text(store.session(id: note.sessionID)?.title ?? "Session")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(note.body.isEmpty ? "Photo" : note.body)
                        if let offset = note.offsetFromStart {
                            Text(SessionProgress.offsetLabel(offset)).font(.caption.monospacedDigit())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .searchable(text: $query, prompt: "Search notes")
        .navigationTitle("My Notes")
        .toolbar {
            #if os(iOS) || os(macOS) || os(visionOS)
            if let manifest = store.manifest, let notes = store.notesStore {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: notes.markdown(manifest: manifest)) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
            #endif
        }
    }
}

struct SettingsScreen: View {
    @Bindable var store: ConferenceStore
    @Bindable var router: ConferenceRouter

    var body: some View {
        Form {
            Picker("Times", selection: $store.timeDisplay) {
                ForEach(TimeDisplay.allCases, id: \.self) { style in
                    Text(style.label).tag(style)
                }
            }
            Toggle("Follow live session", isOn: Binding(
                get: { router.followLive },
                set: { router.setFollowLive($0) }
            ))
            Text("When this is on, laptop mode moves the stage and the open notes to the next session after the current one ends.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Toggle("Reminders for favorites", isOn: Binding(
                get: { store.reminderPreferences.enabled },
                set: { enabled in
                    store.setRemindersEnabled(enabled)
                    Task { await ConferenceActions.syncReminders(store) }
                }
            ))
            Picker("Lead time", selection: Binding(
                get: { store.reminderPreferences.leadTime },
                set: { lead in
                    store.setReminderLeadTime(lead)
                    Task { await ConferenceActions.syncReminders(store) }
                }
            )) {
                Text("At start").tag(0.0)
                Text("5 minutes").tag(5.0 * 60)
                Text("10 minutes").tag(10.0 * 60)
                Text("15 minutes").tag(15.0 * 60)
                Text("30 minutes").tag(30.0 * 60)
            }
            #if os(iOS)
            AlarmOptIn(store: store)
            Toggle("Outer display companion", isOn: $router.coverCompanionEnabled)
            Text("Starts the camera and shows the session title on the cover display. The Slide button saves a photo into the open session’s notes. The host app needs NSCameraUsageDescription.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            #endif
            Button("Add My Schedule to Calendar") {
                Task {
                    router.statusMessage = await ConferenceActions.addToCalendar(store, sessions: store.favoriteSessions)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#if os(iOS)
private struct AlarmOptIn: View {
    var store: ConferenceStore
    @State private var useAlarms = false

    var body: some View {
        Toggle("Alarms before sessions", isOn: $useAlarms)
            .onAppear { useAlarms = ConferenceKitConfiguration.shared.usesAlarmKit() }
            .onChange(of: useAlarms) { _, enabled in
                ConferenceKitConfiguration.shared.setUseAlarmKit(enabled)
                ConferenceIntentsBootstrap.prepare()
                Task { await ConferenceActions.syncReminders(store) }
            }
        Text("Off by default. AlarmKit needs an entitlement Apple has not approved for this app. Favorites use a notification until you turn this on.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
#endif
