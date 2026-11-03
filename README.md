# ConferenceKit

A Swift package that turns one JSON file into a conference app on Apple platforms, including iPhone Duo.

Organizers fill in colors, speakers, rooms, and sessions. ConferenceKit owns the schedule, speaker directory, favorites, notes, theme, and the layouts: iPhone tabs, iPad and Mac split views, a watch list, and Duo book and laptop poses.

This is the framework extracted from the same problem as [SGConfDemo](https://github.com/vinced45/SGConfDemo).

## Platforms

iOS 17+, iPadOS 17+, macOS 14+, watchOS 10+, tvOS 17+, visionOS 1+.

Duo layout APIs (`ArrangementView`, reserved regions, hinge, scene accessories) need the iOS 27.1 SDK (Xcode 27.1). The deployment target stays iOS 17. Those calls are behind `#if os(iOS)` and `if #available(iOS 27.1, *)`.

## Products

| Product | Use it for |
| --- | --- |
| `ConferenceKit` | Models, loader, store, time zones, search, notes, calendar drafts, reminder planning |
| `ConferenceKitUI` | SwiftUI shells, including laptop mode. Depends on the intents product |
| `ConferenceKitIntents` | App entities, intents, Spotlight, AlarmKit backend |
| `ConferenceKitWidgets` | Widget views, timelines, and the iOS 18 control. Not built for tvOS or visionOS |
| `ConferenceKitAsk` | Question answering over the schedule, notes, and favorites. Does not link AskKit |

AskKit is a separate package, [45BitStudios/AskKit](https://github.com/45BitStudios/AskKit). It supports iOS, macOS, tvOS, watchOS, and visionOS, all at version 27 or later. SwiftPM will not let this package depend on it while ConferenceKit’s deployment targets stay on iOS 17, macOS 14, watchOS 10, tvOS 17, and visionOS 1. The adapter that builds an `AskAssistant` lives in `Integration/ConferenceKitAsk` (`ConferenceKitAskLink`). Add that package by path in an app whose deployment target is 27 or newer, next to AskKit. Questions such as “when is Ada speaking?”, “what’s next in the lab?”, and “summarize my notes from day 1” are answered by `ConferenceAskAnswers` in the core product, which the skills call. That part is what `swift test` covers.

## Host app

```swift
dependencies: [
    .package(url: "https://github.com/45BitStudios/ConferenceKit.git", branch: "main")
]
```

```swift
import SwiftUI
import ConferenceKit
import ConferenceKitUI

@main
struct SampleConfApp: App {
    @State private var store = ConferenceStore(source: .bundled(name: "conference"))

    var body: some Scene {
        WindowGroup {
            ConferenceAppView(store: store)
        }
        #if os(iOS) || os(macOS) || os(visionOS)
        ConferenceSessionScene(store: store)
        ConferenceSpeakerScene(store: store)
        #endif
    }
}
```

`ConferenceAppView(source: .sample)` loads the kit’s sample. `.remote(url)` caches JSON and refreshes it. `.manifest` uses a document you already decoded.

App Intents metadata is extracted from the **app target**. Include the package so its intents and entities are registered:

```swift
import AppIntents
import ConferenceKitIntents

struct HostIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [ConferenceIntentsPackage.self]
    }
}
```

`ConferenceAppShortcuts` declares the App Shortcut phrases. If the app needs its own `AppShortcutsProvider`, copy the `AppShortcut(...)` entries from `Shortcuts.swift` into its `@AppShortcutsBuilder` body; the builder only accepts literal entries, not an array returned from another type.

Call `ConferenceIntentsBootstrap.prepare()` yourself only if you are not using `ConferenceAppView`. The root view reindexes Spotlight after a load. It registers AlarmKit only after `ConferenceKitConfiguration.shared.setUseAlarmKit(true)`.

There is no hard-coded app group. Pass the id from the host, or set `ConferenceKitAppGroup` in the app and the widget extension. A nil id uses `UserDefaults.standard` and Application Support.

```swift
ConferenceKitConfiguration.shared.configure(appGroupIdentifier: nil)
ConferenceKitConfiguration.shared.setUseAlarmKit(false)
```

### Info.plist

| Key | Why |
| --- | --- |
| `NSCalendarsWriteOnlyAccessUsageDescription` | Adding a session, or all favorites, to Calendar. iOS 17 write-only access. |
| `NSAlarmKitUsageDescription` | Alarms before favorited sessions on iOS 26+. |
| `NSCameraUsageDescription` | Required to photograph a slide into the current session’s notes. The cover-display companion starts a rear-camera capture session. |
| `ConferenceKitAppGroup` | App group id shared by the app and the widget extension. Same key in both Info.plists. |
| `NSUserActivityTypes` | `studio45.conferencekit.open-session`, `studio45.conferencekit.open-speaker`. |

AlarmKit is off by default. Favorites use a local notification. Turning on “Alarms before sessions” calls AlarmKit, which needs the AlarmKit capability. That entitlement is not approved. Without it, scheduling fails and the kit still falls back to the notification.

### Widget extension

Link `ConferenceKit`, `ConferenceKitIntents`, and `ConferenceKitWidgets`. The extension target owns `@main`:

```swift
import ConferenceKitWidgets
import WidgetKit

@main
struct HostWidgets: WidgetBundle {
    var body: some Widget {
        UpNextWidget()
        NowLiveWidget()
        MyScheduleWidget()
        CountdownWidget()
        FavoriteWidget()
    }
}
```

`ConferenceFavoriteControl` is an iOS 18 control widget. Add it from an extension that deploys to iOS 18 or wrap it in its own `@available(iOS 18.0, *)` widget bundle. Widget bundle bodies cannot branch on availability.

On watchOS, use the same widgets. Accessory families, including the corner complication, are already on the widget configurations. Put the same `ConferenceKitAppGroup` value in the extension’s Info.plist so favorites and the snapshot are visible.

The app writes `conference-snapshot.json` into the app group (or the cache) whenever the manifest or favorites change.

## Manifest

See `schema/conference.schema.json` and `Sources/ConferenceKit/Resources/SampleConference.json`.

Schema 1.0 documents still decode. Sponsors, organizers, announcements, code of conduct, Wi-Fi, coordinates, `slidesURL`, and `recordingURL` are optional.

Session times are ISO-8601 with a numeric offset. Day grouping uses `conference.timezone`, not the device zone.

## iPhone Duo

Build the host with the iOS 27.1 SDK so the window fills the inner display and toolbars can sit in the vertical bar. Do not size from `UIScreen` or from idiom. The kit measures the container it was given.

Laptop mode is the signature layout. When the reserved division is a horizontal band, the top half shows the live session (title, speakers and photos, room, time remaining, progress, the next session, and a slides or recording link when the JSON has one). The bottom half is the notes editor:

- timestamped bullet, offset from the session start (`+12:04`)
- star
- key takeaway
- photo from the camera (iOS) or the photo library (iOS, Mac, visionOS)

Follow Live is a saved switch, off until someone turns it on (the laptop stage, the notes header, or Settings). While it is on, the stage and the open notes move to the next session when the current one ends. Opening a session does not change the switch.

Book mode (a vertical crease) keeps the schedule and the session on opposite sides. A flat inner display, iPad, or Mac shows notes beside the session when the window is wide enough, and as a section on the session when it is not. The outer display and Apple Watch show notes on the session. Apple TV shows them read-only.

The hinge angle is only a slight tilt on the session title.

New windows use `ConferenceSessionScene` and `ConferenceSpeakerScene`. The iOS button is a `UIWindowScene.ActivationAction`, so it disappears on the outer display, where new windows are not allowed.

Settings has an opt-in “Outer display companion”. On iOS it asks for camera permission, starts a rear `AVCaptureSession`, and registers a `CameraCaptureAccessory` so the cover display can show the session title. The Slide button writes a still into the open session’s notes. The accessory is only attached while that capture session is running, which is what tech talk 111464 requires. Add `NSCameraUsageDescription`.

Docs used for this layout:

- [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
- [Three steps to make your app shine on iPhone Duo](https://developer.apple.com/iphone-duo/prepare/)
- [Get ready for iPhone Duo](https://developer.apple.com/iphone-duo/)
- Tech talks 111461 (Prepare your app), 111463 (Strike a pose), 111464 (multiple displays and scenes)

## Notes

Notes are JSON files, not SwiftData, so the same store works on every platform the package declares and can live in the app group. Export from Info → My Notes, or with the Export Conference Notes intent. The Markdown is grouped by conference day and session and includes the room, speakers, timestamps, stars, and takeaways.

## Layout of the package

```
Sources/ConferenceKit/          models, loader, store, notes, clock, reminders
Sources/ConferenceKitUI/        shells, laptop mode, session and info screens
Sources/ConferenceKitIntents/   entities, intents, Spotlight, AlarmKit
Sources/ConferenceKitWidgets/   timelines and widget views
Integration/ConferenceKitAsk/   optional AskKit package, OS 27+
Tests/ConferenceKitTests/       Swift Testing
docs/FeatureMatrix.md
schema/conference.schema.json
```

## Tests

`swift test` on a Mac with a current Xcode. The suite covers decoding, conference-zone day grouping, search, favorites, reminder plans, share links, calendar drafts, Duo pose and fold math, live-session follow, notes, entity queries, and the Ask answers.

Xcode 27.2 already built the previous head (880385a) for iOS, iOS Simulator, macOS, watchOS, tvOS, and visionOS, and `swift test` passed. This follow-up was not compiled here. The matrix in `docs/FeatureMatrix.md` is the list of what is implemented versus deliberately left out.
