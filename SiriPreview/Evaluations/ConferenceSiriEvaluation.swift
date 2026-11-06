#if SIRI_AI_PREVIEW
import Evaluations
import SiriEvaluations
import Foundation
import Testing

// Sample for a UI testing target signed by the same team as the app.
// Confirmed from the Siri Evaluations docs (iOS 27.3): SiriService.run(scenario:),
// SiriScenario, UserTurn, Calls, SiriScenarioLoader, and Evaluation.subject(from:).
// IntentDefinitions, .evaluates, EvaluationContext, and computeSiriMetrics appear in
// Apple's SiriService sample and are treated as confirmed from that sample.
// This file is not part of the default package test target, so Xcode 27.2 never compiles it.

struct ConferenceSiriEvaluation: Evaluation {
    let name: String
    let dataset: SiriScenarioLoader

    func subject(from sample: SiriScenario) async throws -> SiriScenarioSubject {
        // Start and end each scenario from the same data (the DEBUG-only ResetDemoDataIntent).
        try await resetDemoData()
        let subject = try await SiriService.run(scenario: sample)
        do { try await resetDemoData() } catch { Issue.record(error) }
        return subject
    }

    private func resetDemoData() async throws {
        try await conferenceIntents.intents["ResetDemoDataIntent"].makeIntent().run()
    }

    var evaluators: Evaluators {
        SiriExpectationEvaluator()
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        Self.computeSiriMetrics(into: &aggregator)
    }
}

private final class EvaluationBundleMarker {}

/// The host app's bundle ID, from this target's Info.plist (CONFERENCE_HOST_BUNDLE_IDENTIFIER).
let conferenceHostBundleIdentifier: String = {
    guard let id = Bundle(for: EvaluationBundleMarker.self)
        .object(forInfoDictionaryKey: "ConferenceHostBundleIdentifier") as? String, !id.isEmpty
    else { fatalError("Set CONFERENCE_HOST_BUNDLE_IDENTIFIER for the evaluations target.") }
    return id
}()

let conferenceIntents = IntentDefinitions(bundleIdentifier: conferenceHostBundleIdentifier)

@Test(
    .evaluates(ConferenceSiriEvaluation(
        name: "What's next and a note",
        dataset: SiriScenarioLoader {
            SiriScenario {
                UserTurn("What's next?") {
                    Calls {
                        conferenceIntents.intents["WhatsNextTool"]
                    }
                }
                UserTurn("Add a note: ask about the fold") {
                    Calls {
                        conferenceIntents.intents["AddNoteTool"]
                    }
                    SiriResponse(.contains("Noted"))
                }
            }
        }
    ))
)
func whatsNextThenNote() async throws {
    let result = EvaluationContext.current.result
    #expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1)
}

// Not executed by `swift test`. The package test target does not compile this file.
// A signed evaluations target on 27.3 can run it. It is not a device QA pass and not an Instruments trace.
@Test(
    .evaluates(ConferenceSiriEvaluation(
        name: "Attendee directory",
        dataset: SiriScenarioLoader {
            SiriScenario {
                UserTurn("Who is attending?") {
                    Calls {
                        conferenceIntents.intents["FindAttendeeTool"]
                    }
                }
                UserTurn("Is Okonkwo in the directory?") {
                    Calls {
                        conferenceIntents.intents["FindAttendeeTool"]
                    }
                    SiriResponse(.contains("directory"))
                }
            }
        }
    ))
)
func attendeeDirectoryLookup() async throws {
    let result = EvaluationContext.current.result
    #expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1)
}
#endif
