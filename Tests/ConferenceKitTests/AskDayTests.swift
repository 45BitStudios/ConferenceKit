import ConferenceKit
import Foundation
import Testing

/// A schedule shifted the way DemoSchedule shifts it: day 1 starts late and crosses midnight.
private func shiftedCatalog(favorites: Set<String> = ["layout"], now offset: TimeInterval = 600) -> ConferenceAskCatalog {
    // 2027-01-21 22:00 in Singapore (UTC+8) = 14:00Z.
    let start = ISO8601DateFormatter().date(from: "2027-01-21T14:00:00Z")!
    func session(_ id: String, _ title: String, _ hours: Double, room: String) -> Session {
        let begin = start.addingTimeInterval(hours * 3600)
        return Session(id: id, title: title, synopsis: "", startTime: begin, endTime: begin.addingTimeInterval(3600), speakerIDs: [], roomID: room)
    }
    let manifest = ConferenceManifest(
        conference: ConferenceInfo(id: "sg", name: "iOS Conf SG", timezone: "Asia/Singapore", startDate: "2027-01-21", endDate: "2027-01-22"),
        rooms: [Room(id: "lab", name: "Lab"), Room(id: "main", name: "Main Stage")],
        speakers: [],
        sessions: [
            session("day-two", "Day two keynote", 24, room: "main"),
            session("keynote", "Opening", 0, room: "main"),
            session("lab-talk", "Intents lab", 1.5, room: "lab"),
            session("layout", "Layout", 5, room: "main") // 03:00 the next calendar day, still day 1
        ]
    )
    let note = SessionNote(sessionID: "layout", conferenceID: "sg", body: "Grids first", createdAt: start.addingTimeInterval(5 * 3600 + 60))
    let early = SessionNote(sessionID: "keynote", conferenceID: "sg", body: "Ship it", createdAt: start.addingTimeInterval(6 * 3600))
    return ConferenceAskCatalog(manifest: manifest, notes: [note, early], favoriteSessionIDs: favorites, now: start.addingTimeInterval(offset))
}

@Test func scheduleDaysClusterAcrossMidnight() {
    let days = ConferenceAskAnswers.scheduleDays(shiftedCatalog().manifest)
    #expect(days.map { $0.map(\.id) } == [["keynote", "lab-talk", "layout"], ["day-two"]])
}

@Test func nextInMainStageExcludesLab() {
    // Now is during Opening; the next session overall is in the Lab.
    let catalog = shiftedCatalog(now: 3700)
    let answer = ConferenceAskAnswers.reply(utterance: "What's next in Main Stage?", catalog: catalog)
    #expect(answer.kind == .nextInRoom)
    #expect(answer.spoken.contains("Layout"))
    #expect(!answer.spoken.contains("Intents lab"))
    #expect(!answer.spoken.contains("Lab"))
}

@Test func dayTwoAgendaIsTimeOrderedWithDayLabel() {
    let catalog = shiftedCatalog()
    let one = ConferenceAskAnswers.reply(utterance: "What's on day 1?", catalog: catalog)
    #expect(one.kind == .dayAgenda)
    #expect(one.spoken.hasPrefix("Day 1, "))
    let order = ["Opening", "Intents lab", "Layout"].map { one.spoken.range(of: $0)!.lowerBound }
    #expect(order == order.sorted())
    let two = ConferenceAskAnswers.reply(utterance: "what's on day two", catalog: catalog)
    #expect(two.kind == .dayAgenda)
    #expect(two.spoken.hasPrefix("Day 2, "))
    #expect(two.spoken.contains("Day two keynote"))
    #expect(!two.spoken.contains("Opening"))
    #expect(ConferenceAskAnswers.reply(utterance: "what's on day 3", catalog: catalog).spoken.contains("2 days"))
}

@Test func dayOneNotesFoundAfterMidnightShift() {
    let answer = ConferenceAskAnswers.reply(utterance: "Summarize my notes from day 1", catalog: shiftedCatalog())
    #expect(answer.kind == .summarizeNotes)
    #expect(answer.spoken.hasPrefix("Notes from Day 1"))
    #expect(answer.spoken.contains("Grids first"))
    // Ordered by session start, not by when the note was written.
    #expect(answer.spoken.range(of: "Ship it")!.lowerBound < answer.spoken.range(of: "Grids first")!.lowerBound)
}

@Test func myScheduleAnswersFromFavorites() {
    let answer = ConferenceAskAnswers.reply(utterance: "My schedule", catalog: shiftedCatalog())
    #expect(answer.kind == .favorites)
    #expect(answer.spoken.contains("Layout"))
    let empty = ConferenceAskAnswers.reply(utterance: "My schedule", catalog: shiftedCatalog(favorites: []))
    #expect(empty.spoken.contains("haven’t saved"))
}
