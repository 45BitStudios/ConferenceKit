import ConferenceKit
import Foundation
#if CONFERENCEKIT_ASK
import AskKit
#endif

/// AskKit adapter.
///
/// AskKit’s package requires iOS 27, macOS 27, tvOS 27, watchOS 27, and visionOS 27.
/// This package stays on the older deployment targets, and SwiftPM rejects a dependency
/// whose minimum is higher than the parent’s. The root target therefore does not link AskKit.
/// `Integration/ConferenceKitAsk` is a second package with those 27.0 minimums. It compiles
/// this file with `CONFERENCEKIT_ASK` set and does link AskKit.
#if CONFERENCEKIT_ASK
public enum ConferenceAskLink {
    public static let isLinked = true
}
#else
public enum ConferenceAskLink {
    public static let isLinked = false
}
#endif

#if CONFERENCEKIT_ASK
@MainActor
public final class ConferenceAskSource {
    public var manifest: ConferenceManifest
    public var notes: [SessionNote]
    public var favoriteSessionIDs: Set<String>
    public var now: Date

    public init(
        manifest: ConferenceManifest,
        notes: [SessionNote] = [],
        favoriteSessionIDs: Set<String> = [],
        now: Date = .now
    ) {
        self.manifest = manifest
        self.notes = notes
        self.favoriteSessionIDs = favoriteSessionIDs
        self.now = now
    }

    public func catalog(at date: Date? = nil) -> ConferenceAskCatalog {
        ConferenceAskCatalog(
            manifest: manifest,
            notes: notes,
            favoriteSessionIDs: favoriteSessionIDs,
            now: date ?? now
        )
    }
}

@MainActor
public enum ConferenceAsk {
    public static func assistant(named name: String = "Conference", source: ConferenceAskSource) throws -> AskAssistant {
        let skills = Self.skills(source: source)
        return try AskAssistant(AskConfiguration(
            assistantName: name,
            persistence: .memory,
            domains: [
                AskDomain(
                    id: "schedule",
                    summary: "Conference schedule, rooms, speakers, favorites, and notes",
                    routingNotes: "Sessions, speakers, rooms, what is on now, saved talks, and the person’s notes."
                )
            ],
            skills: skills,
            context: {
                let clock = source.manifest.clock
                let today = clock.dayString(source.now)
                return AskContext(
                    promptBlock: "conference=\(source.manifest.conference.name) timezone=\(source.manifest.conference.timezone) today=\(today)",
                    values: [
                        "conference": source.manifest.conference.name,
                        "timezone": source.manifest.conference.timezone
                    ],
                    // No schedule digest: a rewrite that sees every session leaks other rooms into
                    // room answers. Answers come from the skills' FACTS only.
                    sections: []
                )
            },
            chips: { _ in
                [
                    AskChip(id: "next", skillID: ConferenceAskKind.whatsNext.skillID, title: "What’s next?"),
                    AskChip(id: "notes", skillID: ConferenceAskKind.summarizeNotes.skillID, title: "My notes"),
                    AskChip(id: "saved", skillID: ConferenceAskKind.favorites.skillID, title: "My schedule")
                ]
            },
            fastPath: { utterance in
                let classified = ConferenceAskAnswers.classify(utterance)
                guard classified.kind != .unknown else { return nil }
                return AskRoute(skillID: classified.kind.skillID, slots: classified.slots)
            },
            guide: AskGuide(
                routeRules: .append(ConferenceAskPrompts.routeRules),
                // Empty reply instructions turn off AskKit's model rewrite (writesReply == false), so the
                // deterministic answer is what the person sees. A rewrite also sent "my schedule" to the
                // calendar specialist, which fails when Calendar access is off.
                replyInstructions: .replace("")
            )
        ))
    }

    private static func skills(source: ConferenceAskSource) -> [AskSkill] {
        [
            skill(source, kind: .whenSpeaking, title: "When someone is speaking", summary: "Sessions for a speaker", slots: ["speaker"], notes: "When is a person speaking, and which talk."),
            skill(source, kind: .nextInRoom, title: "Next in a room", summary: "What is on now or next in one room", slots: ["room"], notes: "What’s next in a room, lab, or stage."),
            skill(source, kind: .whatsNext, title: "What’s next", summary: "The live session or the next one", notes: "What’s next, what’s on now, with no room named."),
            skill(source, kind: .summarizeNotes, title: "Summarize notes", summary: "The person’s notes for a conference day", slots: ["day"], notes: "Summarize notes, notes from day 1, notes today."),
            skill(source, kind: .dayAgenda, title: "A day's agenda", summary: "Every session on one conference day, in time order", slots: ["day"], notes: "What's on day 2, the day one schedule."),
            skill(source, kind: .favorites, title: "Saved sessions", summary: "The person’s favorites", notes: "My schedule, favorites, saved talks.")
        ]
    }

    private static func skill(
        _ source: ConferenceAskSource,
        kind: ConferenceAskKind,
        title: String,
        summary: String,
        slots: [String] = [],
        notes: String
    ) -> AskSkill {
        AskSkill(
            id: kind.skillID,
            domainID: "schedule",
            title: title,
            summary: summary,
            requiredSlots: slots,
            routingNotes: notes,
            fulfillment: .reply { invocation in
                let answer = ConferenceAskAnswers.reply(
                    utterance: invocation.utterance,
                    slots: invocation.slots,
                    catalog: source.catalog()
                )
                return AskReply(text: answer.spoken, spoken: answer.spoken, facts: answer.facts)
            }
        )
    }
}
#endif
