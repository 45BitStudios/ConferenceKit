import ConferenceKit
import SwiftUI

struct ScheduleList: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var push: Bool
    var favoritesOnly = false
    var workshopsOnly = false

    private var sessions: [Session] {
        store.filteredSessions(filter: SessionFilter(
            query: store.searchText,
            trackID: router.trackID,
            roomID: router.roomID,
            kind: workshopsOnly ? .workshop : nil,
            favoritesOnly: favoritesOnly,
            day: router.day
        ))
    }

    var body: some View {
        List {
            if !store.searchText.isEmpty, let hits = store.notesStore?.search(store.searchText, manifest: store.manifest), !hits.isEmpty {
                Section("Notes") {
                    ForEach(hits) { note in
                        Button {
                            router.openSession(note.sessionID, push: push)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(store.session(id: note.sessionID)?.title ?? "Session")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(note.body.isEmpty ? "Photo" : note.body)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Section(favoritesOnly ? "Saved" : (workshopsOnly ? "Workshops" : "Sessions")) {
                if sessions.isEmpty {
                    Text(favoritesOnly ? "Star a session and it lands here." : "Nothing matches.")
                        .foregroundStyle(.secondary)
                }
                ForEach(sessions) { session in
                    Button {
                        router.openSession(session.id, push: push)
                    } label: {
                        SessionRow(session: session, store: store, emphasized: session.isHappening())
                    }
                    .buttonStyle(.plain)
                    #if os(visionOS)
                    .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 12))
                    .hoverEffect()
                    #endif
                    .scheduleScrollFade()
                    .accessibilityHint("Opens session")
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if !favoritesOnly && !workshopsOnly {
                DayStrip(
                    days: store.conferenceDays,
                    clock: store.clock,
                    selection: Binding(get: { router.day }, set: { router.day = $0 })
                )
            }
        }
        .navigationTitle(favoritesOnly ? "My Schedule" : (workshopsOnly ? "Workshops" : "Schedule"))
        .refreshable { await store.load() }
        .toolbar { filterMenu }
    }

    @ViewBuilder
    private var filterMenu: some View {
        #if os(watchOS)
        // watchOS has no Menu; the same filters as pickers on a pushed list.
        NavigationLink {
            List {
                Picker("Track", selection: Binding(get: { router.trackID }, set: { router.trackID = $0 })) {
                    Text("All tracks").tag(String?.none)
                    ForEach(store.tracks) { track in
                        Text(track.name).tag(Optional(track.id))
                    }
                }
                Picker("Room", selection: Binding(get: { router.roomID }, set: { router.roomID = $0 })) {
                    Text("All rooms").tag(String?.none)
                    ForEach(store.rooms) { room in
                        Text(room.name).tag(Optional(room.id))
                    }
                }
            }
            .navigationTitle("Filter")
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease")
        }
        #else
        Menu {
            Button("All tracks") { router.trackID = nil }
            ForEach(store.tracks) { track in
                Button(track.name) { router.trackID = track.id }
            }
            Divider()
            Button("All rooms") { router.roomID = nil }
            ForEach(store.rooms) { room in
                Button(room.name) { router.roomID = room.id }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease")
        }
        #endif
    }
}

struct SessionDetail: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var session: Session
    var push: Bool
    var showsInlineNotes: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(session.title)
                    .font(.title.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        meta
                    }
                    VStack(alignment: .leading, spacing: 8) { meta }
                }
                Text(session.synopsis)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                speakers
                links
                if showsInlineNotes {
                    Text("Notes")
                        .font(.title2.weight(.semibold))
                    NotesEditor(store: store, session: session)
                        .frame(minHeight: 280)
                }
            }
            .padding()
        }
        .navigationTitle(session.kind.label)
        .toolbar { toolbar }
        #if os(visionOS)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            SessionActionsOrnament(store: store, router: router, session: session)
        }
        #endif
        #if SIRI_AI_PREVIEW && os(iOS)
        .siriSessionContext(
            sessionID: session.id,
            title: session.title,
            room: store.roomName(for: session) ?? ""
        )
        #endif
    }

    @ViewBuilder
    private var meta: some View {
        TimeRangeLabel(session: session, store: store)
        if let room = store.room(for: session) {
            Label(room.name, systemImage: "mappin.and.ellipse")
        }
        if let track = store.track(for: session) {
            Text(track.name).font(.subheadline)
        }
        if let level = session.level {
            Text(level).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var speakers: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(store.speakers(for: session)) { speaker in
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
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var links: some View {
        if let slides = session.slidesURL {
            Link(destination: slides) { Label("Slides", systemImage: "rectangle.on.rectangle") }
        }
        if let recording = session.recordingURL {
            Link(destination: recording) { Label("Recording", systemImage: "play.rectangle") }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        #if !os(visionOS)
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await ConferenceActions.toggleFavorite(store, sessionID: session.id) }
            } label: {
                Label(
                    store.favorites.contains(session.id) ? "Saved" : "Save",
                    systemImage: store.favorites.contains(session.id) ? "star.fill" : "star"
                )
            }
            .accessibilityLabel(store.favorites.contains(session.id) ? "Remove from My Schedule" : "Add to My Schedule")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { router.statusMessage = await ConferenceActions.addToCalendar(store, sessions: [session]) }
            } label: {
                Label("Calendar", systemImage: "calendar.badge.plus")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await SessionActionRunner.remind(store, router: router, session: session) }
            } label: {
                Label("Remind", systemImage: "alarm")
            }
        }
        #endif
        #if os(iOS) || os(macOS) || os(visionOS)
        if let url = store.shareURL(for: .session(session.id)) {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
            }
        }
        #endif
        if ConferenceWindowRegistration.sessions {
            ToolbarItem(placement: .primaryAction) {
                NewSessionWindowButton(sessionID: session.id)
            }
        }
    }
}

struct SpeakerDetail: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var speaker: Speaker
    var push: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    SpeakerAvatar(speaker: speaker, diameter: 72)
                    VStack(alignment: .leading) {
                        Text(speaker.name).font(.title2.weight(.semibold))
                        if !speaker.affiliation.isEmpty {
                            Text(speaker.affiliation).foregroundStyle(.secondary)
                        }
                    }
                }
                Text(speaker.bio).font(.body).frame(maxWidth: .infinity, alignment: .leading)
                ForEach(speaker.social) { link in
                    Link(destination: link.url) { Label(link.platform.label, systemImage: "link") }
                }
                Text("Sessions").font(.title3.weight(.semibold))
                ForEach(store.manifest?.sessions(for: speaker.id) ?? []) { session in
                    Button {
                        router.openSession(session.id, push: push)
                    } label: {
                        SessionRow(session: session, store: store)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(speaker.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    _ = store.favorites.toggleSpeaker(speaker.id)
                    store.publishFavorites()
                } label: {
                    Label(
                        "Favorite",
                        systemImage: store.favorites.containsSpeaker(speaker.id) ? "star.fill" : "star"
                    )
                }
            }
            #if os(iOS) || os(macOS) || os(visionOS)
            if let url = store.shareURL(for: .speaker(speaker.id)) {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                }
            }
            #endif
        }
    }
}

struct LiveSessionStage: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var session: Session?
    var tilt: Double = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            stage(now: context.date)
        }
    }

    @ViewBuilder
    private func stage(now: Date) -> some View {
        if let session {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(session.isHappening(at: now) ? "Live" : session.kind.label)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(store.theme.accentColor.opacity(0.2), in: Capsule())
                        Spacer()
                        Button {
                            router.setFollowLive(!router.followLive)
                        } label: {
                            Label(router.followLive ? "Following" : "Follow live", systemImage: "dot.radiowaves.left.and.right")
                        }
                        .accessibilityAddTraits(router.followLive ? .isSelected : [])
                        .buttonStyle(.bordered)
                    }
                    Text(session.title)
                        .font(.largeTitle.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .rotation3DEffect(.degrees(tilt), axis: (x: 1, y: 0, z: 0))
                    TimeRangeLabel(session: session, store: store)
                    ProgressView(value: SessionProgress.fraction(session: session, now: now))
                        .accessibilityLabel(SessionProgress.remainingLabel(session: session, now: now))
                    Text(SessionProgress.remainingLabel(session: session, now: now))
                        .font(.title3.monospacedDigit())
                    if let room = store.room(for: session) {
                        Label(room.name, systemImage: "mappin.and.ellipse")
                    }
                    speakers
                    if let next = nextSession(after: session) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next").font(.caption).foregroundStyle(.secondary)
                            Text(next.title).font(.headline)
                            Text(store.clock.timeString(next.startTime, style: store.timeDisplay))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let slides = session.slidesURL {
                        Link(destination: slides) { Label("Slides", systemImage: "rectangle.on.rectangle") }
                    }
                    if let recording = session.recordingURL {
                        Link(destination: recording) { Label("Link", systemImage: "link") }
                    }
                }
                .padding()
            }
        } else {
            EmptyPane(title: "No session", systemImage: "calendar", message: "The schedule doesn’t have a current session.")
        }
    }

    private var speakers: some View {
        HStack(alignment: .top, spacing: 12) {
            if let session {
                ForEach(store.speakers(for: session)) { speaker in
                    VStack {
                        SpeakerAvatar(speaker: speaker, diameter: 64)
                        Text(speaker.name)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func nextSession(after session: Session) -> Session? {
        store.sessions.first { $0.startTime >= session.endTime && $0.id != session.id }
    }
}
