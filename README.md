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

There is no AskKit product. `https://github.com/45BitStudios/AskKit` was not readable (HTTP 404) when this package was built.

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

App Shortcuts are scanned from the **app target**, not from a package. Add this type to the app:

```swift
import AppIntents
import ConferenceKitIntents

struct HostShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] { ConferenceShortcutTemplate.shortcuts }
    static var shortcutTileColor: ShortcutTileColor = .orange
}
```

Call `ConferenceIntentsBootstrap.prepare()` yourself only if you are not using `ConferenceAppView`. The root view registers the AlarmKit backend and reindexes Spotlight after a load.

### Info.plist

| Key | Why |
| --- | --- |
| `NSCalendarsWriteOnlyAccessUsageDescription` | Adding a session, or all favorites, to Calendar. iOS 17 write-only access. |
| `NSAlarmKitUsageDescription` | Alarms before favorited sessions on iOS 26+. |
| `NSCameraUsageDescription` | Only if attendees photograph slides from the notes editor. |
| `ConferenceKitAppGroup` | App group id shared by the app and the widget extension. Same key in both Info.plists. |
| `NSUserActivityTypes` | `studio45.conferencekit.open-session`, `studio45.conferencekit.open-speaker`. |

AlarmKit also needs the AlarmKit capability. Apple reviews that entitlement. Without it, scheduling throws and the kit falls back to a local notification.

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

Follow Live moves the stage and the open notes to the next session when the current one ends. Opening a session from the schedule pins notes to that session until Follow Live is turned on again.

Book mode (a vertical crease) keeps the schedule and the session on opposite sides. A flat inner display, iPad, or Mac shows notes beside the session when the window is wide enough, and as a section on the session when it is not. The outer display and Apple Watch show notes on the session. Apple TV shows them read-only.

The hinge angle is only a slight tilt on the session title.

New windows use `ConferenceSessionScene` and `ConferenceSpeakerScene`. The iOS button is a `UIWindowScene.ActivationAction`, so it disappears on the outer display, where new windows are not allowed.

Settings has an opt-in “Outer display companion”. It registers a `CameraCaptureAccessory` for the cover display and does **not** start the camera. Tech talk 111464 only shows that accessory while a capture session is running.

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
Tests/ConferenceKitTests/       Swift Testing
docs/FeatureMatrix.md
schema/conference.schema.json
```

## Tests

`swift test` on a Mac with a current Xcode. The suite covers decoding, conference-zone day grouping, search, favorites, reminder plans, share links, calendar drafts, Duo pose and fold math, live-session follow, notes, and entity queries.

This package was written on Linux, where `xcodebuild` and the Apple frameworks are not available. Nothing here was compile-checked. The matrix in `docs/FeatureMatrix.md` is the list of what is implemented versus deliberately left out.
