import ConferenceKit
import ConferenceKitIntents
import Foundation
import Testing

@Test func sampleManifestDecodes() async throws {
    let manifest = try await ConferenceLoader().load(.sample)
    #expect(manifest.sessions.count == 4)
    #expect(manifest.sponsors.count == 2)
    #expect(manifest.wifi?.networkName == "SampleConf")
    #expect(manifest.conferenceDays.count == 2)
    #expect(manifest.validate().isEmpty)
}

@Test func minimalManifestOmitsNewerFields() throws {
    let json = """
    {"conference":{"id":"mini","name":"Mini","timezone":"Asia/Singapore","startDate":"2027-01-20","endDate":"2027-01-22"}}
    """.data(using: .utf8)!
    let manifest = try ConferenceLoader().decode(data: json)
    #expect(manifest.sessions.isEmpty)
    #expect(manifest.sponsors.isEmpty)
    #expect(manifest.wifi == nil)
    #expect(manifest.schemaVersion == "1.0")
}

@Test func daysFollowConferenceTimeZone() throws {
    let instant = try #require(ConferenceLoader.parseISO8601("2026-01-21T00:30:00+08:00"))
    let session = Session(
        id: "midnight",
        title: "After midnight in Singapore",
        synopsis: "Still the previous evening in California.",
        startTime: instant,
        endTime: instant.addingTimeInterval(3600)
    )
    let manifest = ConferenceManifest(
        conference: ConferenceInfo(
            id: "sg",
            name: "SG",
            timezone: "Asia/Singapore",
            startDate: "2026-01-21",
            endDate: "2026-01-21"
        ),
        sessions: [session]
    )
    let day = try #require(manifest.conferenceDays.first?.start)
    let singapore = ConferenceClock(timeZoneIdentifier: "Asia/Singapore")
    let losAngeles = ConferenceClock(timeZoneIdentifier: "America/Los_Angeles")
    #expect(singapore.isSameDay(day, instant))
    #expect(day != losAngeles.startOfDay(for: instant))
}

@Test func searchFindsSpeakerAndTrack() async throws {
    let manifest = try await ConferenceLoader().load(.sample)
    let matches = ConferenceSearch.sessions(in: manifest, matching: SessionFilter(query: "Ada"))
    #expect(matches.map(\.id) == ["layout-talk"])
    let workshops = ConferenceSearch.sessions(in: manifest, matching: SessionFilter(kind: .workshop))
    #expect(workshops.map(\.id) == ["intents-lab"])
}

@Test @MainActor func favoritesRoundTrip() {
    let defaults = UserDefaults(suiteName: "conferencekit-tests-\(UUID().uuidString)")!
    let store = FavoritesStore(defaults: defaults)
    store.scope(to: "sg-2027")
    #expect(store.toggle("opening") == true)
    #expect(store.contains("opening"))
    let reloaded = FavoritesStore(defaults: defaults)
    reloaded.scope(to: "sg-2027")
    #expect(reloaded.contains("opening"))
    #expect(FavoritesStore.readSessionIDs(conferenceID: "sg-2027", defaults: defaults) == ["opening"])
}

@Test func reminderPlansSkipThePast() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let soon = Session(
        id: "soon",
        title: "Soon",
        synopsis: "",
        startTime: now.addingTimeInterval(30 * 60),
        endTime: now.addingTimeInterval(90 * 60)
    )
    let already = Session(
        id: "now",
        title: "Now",
        synopsis: "",
        startTime: now.addingTimeInterval(-60),
        endTime: now.addingTimeInterval(30 * 60)
    )
    let plan = ReminderScheduler.plan(session: soon, conferenceID: "sg", leadTime: 10 * 60, now: now)
    #expect(plan?.fireDate == soon.startTime.addingTimeInterval(-10 * 60))
    #expect(ReminderScheduler.plan(session: soon, conferenceID: "sg", leadTime: 45 * 60, now: now) == nil)
    #expect(ReminderScheduler.plan(session: already, conferenceID: "sg", leadTime: 10 * 60, now: now) == nil)
    let again = ReminderScheduler.plan(session: soon, conferenceID: "sg", leadTime: 10 * 60, now: now)
    #expect(plan?.alarmID == again?.alarmID)
    let other = ReminderScheduler.plan(
        session: Session(id: "other", title: "Other", synopsis: "", startTime: soon.startTime, endTime: soon.endTime),
        conferenceID: "sg",
        leadTime: 10 * 60,
        now: now
    )
    #expect(plan?.alarmID != other?.alarmID)
}

@Test func shareLinksRoundTrip() {
    let info = ConferenceInfo(
        id: "sg",
        name: "iOS Conf SG",
        timezone: "Asia/Singapore",
        startDate: "2027-01-20",
        endDate: "2027-01-22",
        url: URL(string: "https://iosconf.sg/2027")
    )
    let url = ConferenceLink.session("opening keynote").url(conference: info)
    #expect(ConferenceLink.parse(url) == .session("opening keynote"))
    let fallback = ConferenceLink.speaker("vince").url(conference: ConferenceInfo(id: "x", name: "X", timezone: "UTC", startDate: "2027-01-20", endDate: "2027-01-20"))
    #expect(ConferenceLink.parse(fallback) == .speaker("vince"))
}

@Test func calendarDraftUsesConferenceName() async throws {
    let manifest = try await ConferenceLoader().load(.sample)
    let session = try #require(manifest.session(id: "opening-keynote"))
    let draft = CalendarDrafts.make(session: session, manifest: manifest)
    #expect(draft.title.contains("Sample Conf"))
    #expect(draft.location?.contains("Main Stage") == true)
}

@Test func laptopPoseUsesHorizontalDivision() {
    let wideLaptop = DivisionMeasurement(active: true, width: 900, height: 40, minX: 0, minY: 400)
    #expect(DuoLayout.pose(containerWidth: 900, containerHeight: 500, horizontallyCompact: false, division: wideLaptop) == .laptop)
    let tallBook = DivisionMeasurement(active: true, width: 40, height: 700, minX: 400, minY: 0)
    #expect(DuoLayout.pose(containerWidth: 400, containerHeight: 800, horizontallyCompact: false, division: tallBook) == .book)
    #expect(DuoLayout.pose(containerWidth: 390, containerHeight: 800, horizontallyCompact: true) == .compact)
    #expect(DuoLayout.pose(containerWidth: 1100, containerHeight: 800, horizontallyCompact: false) == .regular)
    let split = FoldSplit.measure(containerWidth: 900, containerHeight: 840, division: wideLaptop)
    #expect(split.axis == .horizontal)
    #expect(split.primaryExtent == 400)
    #expect(split.band == 40)
}

@Test func liveFollowAdvancesWhenTheSessionEnds() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let first = Session(id: "a", title: "A", synopsis: "", startTime: start, endTime: start.addingTimeInterval(60 * 60))
    let second = Session(id: "b", title: "B", synopsis: "", startTime: start.addingTimeInterval(60 * 60), endTime: start.addingTimeInterval(120 * 60))
    let during = start.addingTimeInterval(10 * 60)
    let after = start.addingTimeInterval(60 * 60 + 1)
    #expect(LiveSessionFollow.sessionID(sessions: [first, second], pinnedID: "a", followLive: true, now: during) == "a")
    #expect(LiveSessionFollow.sessionID(sessions: [first, second], pinnedID: "a", followLive: true, now: after) == "b")
    #expect(LiveSessionFollow.sessionID(sessions: [first, second], pinnedID: "a", followLive: false, now: after) == "a")
    #expect(SessionProgress.offsetLabel(12 * 60 + 4) == "+12:04")
    #expect(SessionProgress.fraction(session: first, now: during) > 0)
    #expect(SessionProgress.fraction(session: first, now: during) < 1)
}

@Test @MainActor func notesPersistSearchAndExport() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = NotesStore(conferenceID: "sg", directory: directory)
    let session = Session(
        id: "talk",
        title: "Foundation Models",
        synopsis: "On device.",
        startTime: Date(timeIntervalSince1970: 1_800_000_000),
        endTime: Date(timeIntervalSince1970: 1_800_003_600),
        speakerIDs: ["daniel"]
    )
    let takenAt = session.startTime.addingTimeInterval(12 * 60 + 4)
    let note = store.add(body: "Ask the model for a title", session: session, kind: .timestamp, now: takenAt)
    _ = store.add(body: "Ship the workshop lab", session: session, kind: .takeaway, takeaway: true, now: takenAt.addingTimeInterval(60))
    #expect(note.offsetFromStart == 12 * 60 + 4)
    let reloaded = NotesStore(conferenceID: "sg", directory: directory)
    #expect(reloaded.notes(for: "talk").count == 2)
    #expect(reloaded.search("title").count == 1)
    let manifest = ConferenceManifest(
        conference: ConferenceInfo(id: "sg", name: "iOS Conf SG", timezone: "Asia/Singapore", startDate: "2027-01-21", endDate: "2027-01-21"),
        speakers: [Speaker(id: "daniel", name: "Daniel Steinberg", bio: "Author")],
        sessions: [session]
    )
    #expect(reloaded.search("Daniel", manifest: manifest).count == 2)
    let markdown = reloaded.markdown(manifest: manifest)
    #expect(markdown.contains("# iOS Conf SG"))
    #expect(markdown.contains("### Foundation Models"))
    #expect(markdown.contains("**Takeaway**"))
    #expect(markdown.contains("+12:04"))
    #expect(markdown.contains("Daniel Steinberg"))
}

@Test func entityQueriesResolveAndOmitMissingIDs() async throws {
    let manifest = try await ConferenceLoader().load(.sample)
    await ConferenceCatalog.shared.update(manifest: manifest, favoriteSessionIDs: ["opening-keynote"], favoriteSpeakerIDs: [])
    let sessions = SessionEntityQuery()
    let found = try await sessions.entities(matching: "Keynote")
    #expect(found.map(\.id) == ["opening-keynote"])
    let byID = try await sessions.entities(for: ["opening-keynote", "missing"])
    #expect(byID.map(\.id) == ["opening-keynote"])
    let speakers = try await SpeakerEntityQuery().entities(matching: "Ada")
    #expect(speakers.map(\.id) == ["guest-speaker"])
    let venue = try await VenueEntityQuery().suggestedEntities()
    #expect(venue.first?.name == "Navy Pier")
    let days = try await DayEntityQuery().suggestedEntities()
    #expect(days.count == 2)
    await ConferenceCatalog.shared.reset()
}

@Test func validationReportsBrokenReferences() {
    let manifest = ConferenceManifest(
        conference: ConferenceInfo(id: "x", name: "X", timezone: "Not/AZone", startDate: "2027-01-20", endDate: "2027-01-20"),
        sessions: [Session(id: "s", title: "S", synopsis: "", startTime: .now, endTime: .now.addingTimeInterval(-10), speakerIDs: ["nobody"])]
    )
    let messages = manifest.validate().map(\.message).joined(separator: " ")
    #expect(messages.contains("time zone"))
    #expect(messages.contains("ends before"))
    #expect(messages.contains("nobody"))
}
