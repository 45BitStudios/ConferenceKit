#if SIRI_AI_PREVIEW
import Evaluations
import SiriEvaluations
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
        try await SiriService.run(scenario: sample)
    }

    var evaluators: Evaluators {
        SiriExpectationEvaluator()
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        Self.computeSiriMetrics(into: &aggregator)
    }
}

let conferenceIntents = IntentDefinitions(bundleIdentifier: "com.example.Conference")

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
#endif
