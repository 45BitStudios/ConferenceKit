#if SIRI_AI_PREVIEW
import ConferenceKit
import Evaluations
import Foundation
import SiriEvaluations
import Testing

// Device suite for ConferenceKitDemoSiriEvaluations. Not part of `swift test`.
//
// Symbols used, from the Xcode 27.3 device SDK. This file does not call any others:
//   Evaluation
//   SiriScenarioLoader
//   SiriScenario
//   UserTurn
//   Calls
//   SiriResponse.contains
//   SiriService.run(scenario:)
//   SiriScenarioSubject
//   SiriExpectationEvaluator
//   Evaluators
//   MetricsAggregator
//   Evaluation.computeSiriMetrics
//   EvaluationContext
//   Test.evaluates
//   IntentDefinitions
//   Issue.record
//
// `Calls` names the intent. It does not match parameter values, and it cannot
// say that a tool was not called. `mustNotCall` stays in ConferenceSiriEvalCatalog
// for the host tests. Lock screen and Siri's connection are not parameters of
// `SiriService.run`. Those rows use includeInDeviceScenario == false and are
// not passed to `named`. Each device turn is a literal `UserTurn`, because
// `SiriScenario` and `UserTurn` are result builders.

struct ConferenceSiriEvaluation: Evaluation {
    let name: String
    let dataset: SiriScenarioLoader

    func subject(from sample: SiriScenario) async throws -> SiriScenarioSubject {
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

let conferenceHostBundleIdentifier: String = {
    guard let id = Bundle(for: EvaluationBundleMarker.self)
        .object(forInfoDictionaryKey: "ConferenceHostBundleIdentifier") as? String, !id.isEmpty
    else { fatalError("Set CONFERENCE_HOST_BUNDLE_IDENTIFIER for the evaluations target.") }
    return id
}()

let conferenceIntents = IntentDefinitions(bundleIdentifier: conferenceHostBundleIdentifier)

private func named(_ id: String) -> ConferenceSiriEvalCase {
    guard let row = ConferenceSiriEvalCatalog.cases.first(where: { $0.id == id }) else {
        fatalError("Missing Siri eval case \(id)")
    }
    return row
}

private func scenario(skillName: String) -> SiriScenario {
    switch skillName {
    case "plan-afternoon":
        return SiriScenario {
            UserTurn(named("plan-next").utterance) {
                Calls {
                    conferenceIntents.intents[named("plan-next").toolName!]
                }
            }
            UserTurn(named("plan-next-paraphrase").utterance) {
                Calls {
                    conferenceIntents.intents[named("plan-next-paraphrase").toolName!]
                }
            }
            UserTurn(named("plan-find").utterance) {
                Calls {
                    conferenceIntents.intents[named("plan-find").toolName!]
                }
                SiriResponse(.contains(named("plan-find").responseContains!))
            }
            UserTurn(named("plan-find-paraphrase").utterance) {
                Calls {
                    conferenceIntents.intents[named("plan-find-paraphrase").toolName!]
                }
                SiriResponse(.contains(named("plan-find-paraphrase").responseContains!))
            }
            UserTurn(named("plan-favorite").utterance) {
                Calls {
                    conferenceIntents.intents[named("plan-favorite").toolName!]
                }
                SiriResponse(.contains(named("plan-favorite").responseContains!))
            }
            UserTurn(named("plan-out-of-scope").utterance) {
                SiriResponse(.contains(named("plan-out-of-scope").responseContains!))
            }
        }
    case "write-notes":
        return SiriScenario {
            UserTurn(named("write-add").utterance) {
                Calls {
                    conferenceIntents.intents[named("write-add").toolName!]
                }
                SiriResponse(.contains(named("write-add").responseContains!))
            }
            UserTurn(named("write-add-paraphrase").utterance) {
                Calls {
                    conferenceIntents.intents[named("write-add-paraphrase").toolName!]
                }
                SiriResponse(.contains(named("write-add-paraphrase").responseContains!))
            }
            UserTurn(named("write-create-confirm").utterance) {
                Calls {
                    conferenceIntents.intents[named("write-create-confirm").toolName!]
                }
                SiriResponse(.contains(named("write-create-confirm").responseContains!))
            }
            UserTurn(named("write-empty").utterance) {
                SiriResponse(.contains(named("write-empty").responseContains!))
            }
        }
    case "recall-notes":
        return SiriScenario {
            UserTurn(named("recall-show").utterance) {
                Calls {
                    conferenceIntents.intents[named("recall-show").toolName!]
                }
                SiriResponse(.contains(named("recall-show").responseContains!))
            }
            UserTurn(named("recall-paraphrase").utterance) {
                Calls {
                    conferenceIntents.intents[named("recall-paraphrase").toolName!]
                }
                SiriResponse(.contains(named("recall-paraphrase").responseContains!))
            }
            UserTurn(named("recall-missing").utterance) {
                Calls {
                    conferenceIntents.intents[named("recall-missing").toolName!]
                }
                SiriResponse(.contains(named("recall-missing").responseContains!))
            }
        }
    case "export-notes":
        return SiriScenario {
            UserTurn(named("export-all").utterance) {
                Calls {
                    conferenceIntents.intents[named("export-all").toolName!]
                }
                SiriResponse(.contains(named("export-all").responseContains!))
            }
            UserTurn(named("export-paraphrase").utterance) {
                Calls {
                    conferenceIntents.intents[named("export-paraphrase").toolName!]
                }
                SiriResponse(.contains(named("export-paraphrase").responseContains!))
            }
            UserTurn(named("export-to-someone").utterance) {
                SiriResponse(.contains(named("export-to-someone").responseContains!))
            }
        }
    case "find-attendee":
        return SiriScenario {
            UserTurn(named("attendee-list").utterance) {
                Calls {
                    conferenceIntents.intents[named("attendee-list").toolName!]
                }
                SiriResponse(.contains(named("attendee-list").responseContains!))
            }
            UserTurn(named("attendee-paraphrase").utterance) {
                Calls {
                    conferenceIntents.intents[named("attendee-paraphrase").toolName!]
                }
                SiriResponse(.contains(named("attendee-paraphrase").responseContains!))
            }
            UserTurn(named("attendee-missing").utterance) {
                Calls {
                    conferenceIntents.intents[named("attendee-missing").toolName!]
                }
                SiriResponse(.contains(named("attendee-missing").responseContains!))
            }
            UserTurn(named("attendee-email").utterance) {
                Calls {
                    conferenceIntents.intents[named("attendee-email").toolName!]
                }
                SiriResponse(.contains(named("attendee-email").responseContains!))
            }
            UserTurn(named("attendee-message").utterance) {
                SiriResponse(.contains(named("attendee-message").responseContains!))
            }
        }
    default:
        fatalError("No Siri scenario for \(skillName)")
    }
}

private func evaluation(skillName: String, title: String) -> ConferenceSiriEvaluation {
    ConferenceSiriEvaluation(
        name: title,
        dataset: SiriScenarioLoader {
            scenario(skillName: skillName)
        }
    )
}

@Test(.evaluates(evaluation(skillName: "plan-afternoon", title: "Plan the afternoon")))
func evaluatePlanAfternoon() async throws {
    let result = EvaluationContext.current.result
    #expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1)
}

@Test(.evaluates(evaluation(skillName: "write-notes", title: "Write notes")))
func evaluateWriteNotes() async throws {
    let result = EvaluationContext.current.result
    #expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1)
}

@Test(.evaluates(evaluation(skillName: "recall-notes", title: "Recall notes")))
func evaluateRecallNotes() async throws {
    let result = EvaluationContext.current.result
    #expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1)
}

@Test(.evaluates(evaluation(skillName: "export-notes", title: "Export notes")))
func evaluateExportNotes() async throws {
    let result = EvaluationContext.current.result
    #expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1)
}

@Test(.evaluates(evaluation(skillName: "find-attendee", title: "Find an attendee")))
func evaluateFindAttendee() async throws {
    let result = EvaluationContext.current.result
    #expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1)
}
#endif
