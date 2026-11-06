# Intelligence lab coverage

Two sources. The first is the Ernie-hosted Apple Intelligence Group Lab (YouTube `OnoWz-YKzzw`, full transcript attached for this change). The second is the later Shashank-hosted lab. What we have for the second is a parent-verified source extract, not the verbatim transcript. API names below were checked against Apple’s documentation or against types this package already compiles. Lab statements are labeled as lab guidance. Nothing in this file is a device or Siri runtime result.

This change did not run `swift test` or an Xcode build. The last green gate reported for `c9047a3` is unchanged by that fact: it was 27.2 build and 32 tests, 27.3 six platforms with the preview flag off and on, and the demo 4/4. Device and Siri runtime were not part of that gate.

## Channels

| Path | Where | Network |
| --- | --- | --- |
| Ordinary App Intents (`SearchAttendeesIntent`, `OpenAttendeeIntent`, `ReadPublicAttendeeContactIntent`) | `Sources/ConferenceKitIntents/AttendeeIntents.swift` | On device. `ConferenceAssistantAvailability` treats `.appIntent` as runnable when Private Cloud Compute is unreachable. |
| On-device Ask | `ConferenceAskAnswers` always. `Integration/ConferenceKitAsk` adds a Foundation Models session when the OS 27 package is linked and the system model is available. Rules are the fallback. | On device. No custom model backend was added. The lab discussed prewarming and Instruments traces. This package does not call a prewarm API. One `LanguageModelSession` is reused in `ConferenceAskResponder`. |
| Custom ToolIntents | `SiriPreview.swift` and `SiriPreviewLarder.swift`, only with `SIRI_AI_PREVIEW`, and only on iOS, macOS, and visionOS | Lab guidance: Siri invokes these through Private Cloud Compute. `ConferenceAssistantAvailability` returns false for `.siriCustomTool` when the caller passes `privateCloudComputeReachable: false`, and the fallback channel is `.appIntent`. The package does not itself probe Apple’s server. |

`SiriCustomToolCatalog.names` lists the eight custom tools. The lab’s preview cap is 40. Schema search is separate: `ConferenceInAppSearchIntent` adopts `system.search` in `AssistantSearch.swift`. There is no system schema for an attendee, so `FindAttendeeTool` is the custom tool. It returns an array of directory entities (names and roles), not one call per person. `EntityCollection` was not added. The lab’s “about 30 to 32 calls within a skill” is qualified guidance, not a limit this package enforces.

## Privacy

Consent is the attendee’s privacy flags and `messagingConsent`. Visibility, where the 27.3 property macros are used, is the existing note and favorites pattern (`authenticationPolicy` / `visibility` on `@ComputedProperty` and `@Property` in `SiriPreview.swift`). Authentication is `IntentAuthenticationPolicy` on an **intent**, which is the documented App Intent hook (`requiresLocalDeviceAuthentication` means the device running the intent must be unlocked). Those three are different.

- Opted-out people are absent from `directoryAttendees`, entity queries, directory wording, contact disclosure, and vCards.
- `AttendeeEntity` has no email or phone property, so query results, the attendee snippet, and the Spotlight attribute set cannot carry them.
- `AttendeeSnippetCopy` drops the name when the person is not discoverable.
- `ReadPublicAttendeeContactIntent` is the only intent that speaks public email, phone, and social links. Its policy is `.requiresLocalDeviceAuthentication`. `perform` asks for confirmation before the dialog: `requestConfirmation(actionName:dialog:)` on iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2, and `requestConfirmation(result:confirmationActionName:showPrompt:)` on the older deployment targets. The prompt is the question, not the contact fields. It is not a `@AppIntent(.tool)`.
- A profile edit that turns contact flags or messaging consent off is re-read from the stored profile by the directory projection, the vCard, and `AttendeeMessagingPolicy`. The demo transport still records `demoOnDevice` and the on-device notice. No server was added.

## Skills and context

Skills in `SiriPreview/Skills` are optional. `find-attendee` says the tool works without the skill, does not require a tool order, and does not roll anything back. `plan-afternoon` says the same about rollback.

The lab’s four ways a custom tool becomes eligible are: the app is named, the app is foreground, a Live Activity is up, or an app entity was retrieved through search. This package already indexes sessions, speakers, and discoverable attendees, tags rows with `appEntityIdentifier` under the preview flag, and starts a session Live Activity from the session screen under that flag. Attendee tools do not depend on the skill to enforce those gates. The app still checks directory membership and messaging consent itself.

## Execution, duration, watch

Intents live in the `ConferenceKitIntents` product so the app and an extension can link the same types. Apple’s documented heuristic is: if the app is already running, use it; otherwise launch the extension. This package does not set `ExecutionTargets`. It does not dispatch an action from iPhone to Mac. Each device runs its own copy.

`LongRunningIntent` exists (`performBackgroundTask`, progress, cancellation). No conference intent downloads or syncs a payload that needs more than a normal intent runtime. Manifest refresh stays on `ConferenceStore.load`. `LongRunningIntent` is not adopted.

watchOS does not compile the ToolIntent file. The lab did not announce watch ToolIntent support or a phone relay. Watch still shows the attendee directory, and the on-device Ask rules are not watch-excluded.

## Shipping, from the labs

Entity snippets were described as shipping with the 27.3 OS release. Custom ToolIntents and skills were described as a developer preview for internal TestFlight, with an App Store window described as spring. Those are lab statements, not a result from this repository.

## What `swift test` can execute

`Tests/ConferenceKitTests/IntelligenceLabTests.swift` checks the channel policy, the 40-name cap, directory wording, snippet text, contact disclosure, Spotlight text on OS versions that have the indexed entity, `SearchAttendeesIntent.perform`, the authentication policies, and a profile edit that re-checks the vCard and the message policy.

`SiriPreview/Evaluations/ConferenceSiriEvaluation.swift` has Siri evaluation scenarios using `SiriService.run(scenario:)`, including an attendee paraphrase and a missing-person turn. That file is not in the package test target. It has not been run here. Siri evaluation is not an Instruments trace and it is not a Foundation Models judge.

## Manual device checks, not run

- Ask Siri “what can I do with this app”.
- Custom tool online, then the same request with Siri’s connection unavailable. The on-device Search Attendees intent should still run.
- Lock screen: directory search can run. Reading a public email requires unlock and the confirmation.
- Snippet shows name and role, not an email.
- A sent message stays labeled as on this device.
- Watch: directory UI works. A custom ToolIntent is not offered, and the watch does not hand the request to the phone.
