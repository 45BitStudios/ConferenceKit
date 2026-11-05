import ConferenceKit
import Testing

@Test func noteDraftTrimsAndAccepts() {
    #expect(SessionNoteDraftRules.validated("  ask about the fold \n") == .success("ask about the fold"))
}

@Test func noteDraftRejectsEmptyAndTooLong() {
    #expect(SessionNoteDraftRules.validated(" \n\t") == .failure(.empty))
    let long = String(repeating: "a", count: SessionNoteDraftRules.maximumLength + 1)
    #expect(SessionNoteDraftRules.validated(long) == .failure(.tooLong(count: SessionNoteDraftRules.maximumLength + 1)))
    let limit = String(repeating: "a", count: SessionNoteDraftRules.maximumLength)
    #expect(SessionNoteDraftRules.validated(limit) == .success(limit))
}

@Test func shareTextOmitsEmptyPartsAndNotes() {
    #expect(ConferenceShareText.session(title: "Keynote", when: "9:00", room: "Main Stage", speakers: "Ada")
        == "Keynote\n9:00 · Main Stage\nAda")
    #expect(ConferenceShareText.session(title: "Keynote", when: "", room: nil, speakers: "") == "Keynote")
    #expect(ConferenceShareText.speaker(name: "Ada", affiliation: "") == "Ada")
    #expect(ConferenceShareText.speaker(name: "Ada", affiliation: "Studio45") == "Ada, Studio45")
}
