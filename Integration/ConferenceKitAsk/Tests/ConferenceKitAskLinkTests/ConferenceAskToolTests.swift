import ConferenceKit
import ConferenceKitAskLink
import Foundation
import Testing

/// Day 1 starts at 22:00 local and crosses midnight, as DemoSchedule's shift does.
private func catalog(favorites: Set<String> = ["layout"], now offset: TimeInterval = 3700) -> ConferenceAskCatalog {
    let start = ISO8601DateFormatter().date(from: "2027-01-21T14:00:00Z")!
    func session(_ id: String, _ title: String, _ hours: Double, room: String, speakers: [String] = []) -> Session {
        let begin = start.addingTimeInterval(hours * 3600)
        return Session(id: id, title: title, synopsis: "", startTime: begin, endTime: begin.addingTimeInterval(3600), speakerIDs: speakers, roomID: room)
    }
    let manifest = ConferenceManifest(
        conference: ConferenceInfo(id: "sg", name: "iOS Conf SG", timezone: "Asia/Singapore", startDate: "2027-01-21", endDate: "2027-01-22"),
        rooms: [Room(id: "lab", name: "Lab"), Room(id: "main", name: "Main Stage")],
        speakers: [Speaker(id: "ada", name: "Ada Example", bio: "")],
        sessions: [
            session("day-two", "Day two keynote", 24, room: "main", speakers: ["ada"]),
            session("keynote", "Opening", 0, room: "main"),
            session("lab-talk", "Intents lab", 1.5, room: "lab"),
            session("layout", "Layout", 5, room: "main")
        ]
    )
    let notes = [
        SessionNote(sessionID: "layout", conferenceID: "sg", body: "Grids first", createdAt: start.addingTimeInterval(5 * 3600)),
        SessionNote(sessionID: "keynote", conferenceID: "sg", body: "Ship it", createdAt: start.addingTimeInterval(6 * 3600))
    ]
    return ConferenceAskCatalog(manifest: manifest, notes: notes, favoriteSessionIDs: favorites, now: start.addingTimeInterval(offset))
}

#if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
private let provider = CatalogProvider(fixed: catalog())

@Test func scheduleToolRoomExcludesOtherRooms() {
    let text = ScheduleLookupTool(provider: provider).lookup(.init(room: "Main Stage", upcoming: true), catalog: catalog())
    #expect(text.contains("Layout"))
    #expect(text.contains("Day two keynote"))
    #expect(!text.contains("Intents lab"))
}

@Test func scheduleToolDayIsOrderedAndLabelled() {
    let text = ScheduleLookupTool(provider: provider).lookup(.init(day: 1), catalog: catalog())
    let lines = text.split(separator: "\n")
    #expect(lines.map { $0.split(separator: "|")[0].trimmingCharacters(in: .whitespaces) } == ["keynote", "lab-talk", "layout"])
    #expect(lines.allSatisfy { $0.contains("Day 1") })
    #expect(ScheduleLookupTool(provider: provider).lookup(.init(day: 2), catalog: catalog()).contains("Day 2"))
}

@Test func scheduleToolSavedUsesFavorites() {
    let tool = ScheduleLookupTool(provider: provider)
    #expect(tool.lookup(.init(saved: true), catalog: catalog()) .contains("Layout"))
    #expect(tool.lookup(.init(saved: true), catalog: catalog(favorites: [])).contains("hasn't saved"))
}

@Test func speakerAndNotesTools() async throws {
    let speaker = try await SpeakerLookupTool(provider: provider).call(arguments: .init(name: "Ada"))
    #expect(speaker.contains("Day two keynote"))
    let notes = try await NotesLookupTool(provider: provider).call(arguments: .init(day: 1))
    #expect(notes.contains("Grids first"))
    #expect(notes.range(of: "Ship it")!.lowerBound < notes.range(of: "Grids first")!.lowerBound)
    #expect(try await NotesLookupTool(provider: provider).call(arguments: .init(day: 2)) == "No notes.")
}
#endif

@MainActor
@Test func responderFallsBackToRules() async {
    let fixed = catalog()
    let responder = ConferenceAskResponder(allowModel: false) { fixed }
    #expect(responder.modelIsAvailable == false)
    let room = await responder.answer("What's next in Main Stage?")
    #expect(room.engine == .rules)
    #expect(room.text.contains("Layout"))
    #expect(!room.text.contains("Lab"))
    let day = await responder.answer("What's on day 2?")
    #expect(day.text.hasPrefix("Day 2, "))
    let notes = await responder.answer("Summarize my notes from day 1")
    #expect(notes.text.contains("Grids first"))
    let saved = await responder.answer("My schedule")
    #expect(saved.text.contains("Layout"))
}
