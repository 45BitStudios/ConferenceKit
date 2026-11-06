# Run the Siri evaluations on a signed device

This file is the procedure. It is not a result. Nothing here has been run from this repository's cloud environment, and this environment has no Apple toolchain. Do not read a green `swift test` as a green device run.

The suite is the scheme `ConferenceKitDemoSiriEvaluations`. Its test action builds `ConferenceKitDemo` and the eval target, then runs that target. `xcodebuild test` uses the Debug configuration, which is what includes `ResetDemoDataIntent`. `SiriEvaluations` is in the iOS 27.3 device SDK. It is not in the simulator SDK. The package tests do not compile the eval file. They check the fixture catalog.

## Symbols the eval file calls

`SiriPreview/Evaluations/ConferenceSiriEvaluation.swift` uses only these, from the Xcode 27.3 device SDK:

- `Evaluation`
- `SiriScenarioLoader`
- `SiriScenario`
- `UserTurn`
- `Calls`
- `SiriResponse.contains`
- `SiriService.run(scenario:)`
- `SiriScenarioSubject`
- `SiriExpectationEvaluator`
- `Evaluators`
- `MetricsAggregator`
- `Evaluation.computeSiriMetrics`
- `EvaluationContext`
- `Test.evaluates` (the Swift Testing `.evaluates` trait)
- `IntentDefinitions`
- `Issue.record`

`Calls` names the intent type through `IntentDefinitions`. It does not match parameter values. Those words are `ConferenceSiriEvalCase.parameterNote`, and `swift test` checks that the note is present. `Calls` also cannot say that a tool was not used. `mustNotCall` is checked only as a list of real tool names.

`SiriService.run(scenario:)` has no argument that locks the phone or turns Siri's connection off. Cases with `includeInDeviceScenario == false` are the network-off pass below. They are not sent to `SiriService` while the connection is up.

Each device turn is a literal `UserTurn` inside `SiriScenario`. The utterance and the expected intent come from `ConferenceSiriEvalCatalog` through `named`. `SiriScenario` and `UserTurn` are result builders, so the file does not put a `for` or an `if` inside them. The host test checks that every device case id appears there and that the five network-off ids do not.

## Before the device

1. On a Mac with the Swift tools, from the repo root:

   ```sh
   swift test --filter SiriEvalCatalogTests
   ```

   That checks every canonical skill folder has cases, ids are unique, every referenced custom tool is one of the eight names in `SiriCustomToolCatalog.names`, and `ReadPublicAttendeeContactIntent` is the ordinary intent used for the email case.

2. The custom tools are compiled only when `SIRI_AI_PREVIEW` is set on `ConferenceKitIntents` and `ConferenceKitUI`. The default `Package.swift` does not set it. The eval target sets `-DSIRI_AI_PREVIEW` for its own file. That does not compile the tools into the host app.

   For this run only, add `swiftSettings: [.define("SIRI_AI_PREVIEW")]` to those two targets in `Package.swift`. Do not commit that edit. Xcode 27.2 does not have the macros. Leave the flag unset for every other build.

3. Generate the demo project. Do not change the team or the signing settings in `project.yml`. They stay blank, and `CODE_SIGNING_ALLOWED` stays `NO` in that file. The signature for this run is the one you apply locally for your own device, outside the repo.

   ```sh
   cd Examples/ConferenceKitDemo
   xcodegen generate
   ```

4. The eval target's `CONFERENCE_HOST_BUNDLE_IDENTIFIER` is `studio45.conferencekit.demo`. `IntentDefinitions` loads intents from that app.

## On the device

Connect a phone with the 27.3 Siri preview. Use your own signing in Xcode for this one run. Do not commit the team id.

```sh
xcodebuild test \
  -project Examples/ConferenceKitDemo/ConferenceKitDemo.xcodeproj \
  -scheme ConferenceKitDemoSiriEvaluations \
  -destination 'platform=iOS,id=YOUR_DEVICE_UDID'
```

Replace `YOUR_DEVICE_UDID`. The five evaluations are Plan the afternoon, Write notes, Recall notes, Export notes, and Find an attendee. Each one runs `ResetDemoDataIntent`, then one `SiriScenario`, then checks `intentsAllPass`.

Two turns ask before they finish. Accept the prompt if you want the final dialog. Saying no is the manual check in the last section, not a separate `SiriService` case.

- Favorite: `FavoriteSessionTool` asks `Save Opening Keynote on My Schedule?` and then says `Saved Opening Keynote.`
- Create a session note: `CreateSessionNoteIntent` asks `Save this note on <session>?` The eval fragment is `Save this note`. After a yes the tool says `Saved a note on <session>.`
- Maya's email: `ReadPublicAttendeeContactIntent` uses `IntentAuthenticationPolicy.requiresLocalDeviceAuthentication`, then asks `Show the public contact fields for Maya Chen?` The eval fragment is `public contact`. After a yes the spoken line includes `maya@example.com`. `FindAttendeeTool` does not return that address.

Negative turns expect the skill's wording (`in the app`, `this device`, `empty`, `No matching session`). That wording is not a fixed tool dialog except `No matching session`, which is what `FindSessionTool` returns. If Siri answers with different words, the case fails. That is the evaluation, not a fixture mismatch.

## Network off

Do this by hand. The scheme cannot do it. Turn Siri's connection off, then speak the utterance whose catalog kind is `offlineFallback`:

| Skill | Utterance | What should happen |
| --- | --- | --- |
| plan-afternoon | What's next? | `WhatsNextTool` does not run. Open Schedule in the app. |
| write-notes | Add a note: ask about the fold | `AddNoteTool` does not run. Type the note on the session screen. |
| recall-notes | Show my notes for the opening keynote | `ShowNotesTool` does not run. Open My Notes. |
| export-notes | Export my notes | `ExportNotesTool` does not run. Use My Notes from Info. |
| find-attendee | Who is attending? | `FindAttendeeTool` does not run. Open Attendees. |

The app must not say it reached a server. The screens still open.

## What this still cannot prove

A green `xcodebuild test` does not prove the lock screen, a snippet's pixels, or that cancelling a confirmation writes nothing. `SiriResponse.contains` sees the text the evaluator returns. It is not a separate check of the confirmation dialog versus the final line. After the scheme run, on the same signed phone:

- Ask for Maya's email while the phone is locked. It should ask you to unlock, then ask before any address is spoken. Cancel that prompt and confirm nothing was spoken.
- Ask to create a session note and cancel the save. The notes screen should not gain that line.
- Ask "what can I do with this app" and confirm it mentions the schedule, notes, and the directory.

`docs/SiriDeviceChecklist.md` is the same list in shorter form. Copying `Skills.skillsbundle` into the app is not proof Siri indexed it.
