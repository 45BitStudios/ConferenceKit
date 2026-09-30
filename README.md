# ConferenceKit

A Swift package that turns one JSON file into a conference app on Apple platforms.

Organizers fill in colors, speakers, rooms, and sessions. ConferenceKit owns the rest: schedule, speaker directory, favorites, iPhone tabs, iPad split (“duo”) layouts, and an Apple Watch next-up stack.

This is the framework extracted from the same problem as [SGConfDemo](https://github.com/vinced45/SGConfDemo) — stop rewriting the conference shell for every talk and every event.

## Platforms

iOS 17+, iPadOS 17+, macOS 14+, watchOS 10+, tvOS 17+, visionOS 1+

## Consume it

```swift
dependencies: [
    .package(url: "https://github.com/45BitStudios/ConferenceKit.git", branch: "main")
]
```

Host app, three lines:

```swift
import SwiftUI
import ConferenceKit

@main
struct SampleConfApp: App {
    var body: some Scene {
        WindowGroup {
            ConferenceAppView(source: .bundled(name: "conference"))
        }
    }
}
```

Put `conference.json` in the app target. That is the organizer job.

Other sources:

```swift
ConferenceAppView(source: .sample)                 // kit sample, useful in a demo
ConferenceAppView(source: .remote(scheduleURL))    // live schedule, no App Store resubmit
ConferenceAppView(source: .manifest(decoded))      // already in memory
```

## Manifest shape

See `schema/conference.schema.json` and `Sources/ConferenceKit/Resources/SampleConference.json`.

Minimum document:

```json
{
  "schemaVersion": "1.0",
  "conference": {
    "id": "your-conf-2026",
    "name": "Your Conf",
    "timezone": "America/Chicago",
    "startDate": "2026-04-16",
    "endDate": "2026-04-17"
  },
  "theme": {
    "accent": "#FF6A00",
    "primary": "#1C1C1E",
    "secondary": "#8E8E93",
    "background": "#F2F2F7",
    "surface": "#FFFFFF",
    "onAccent": "#FFFFFF",
    "preferredColorScheme": "system"
  },
  "tracks": [],
  "rooms": [],
  "speakers": [],
  "sessions": []
}
```

Session times are ISO-8601 (`2026-04-16T09:00:00-05:00`). Speakers, tracks, and rooms are referenced by `id`.

## What the kit handles

- Decode and validate the manifest
- Theme tokens → SwiftUI `Color` + tint + preferred color scheme
- Schedule grouped by day
- Speaker directory and session detail
- Favorites persisted per conference id
- Compact: tabbed iPhone shell
- Regular: three-column split for iPad / Mac
- watchOS: now / next, schedule, saved talks

## What stays in the host app (for now)

App Intents, Live Activities, widgets, push, and MapKit venue detail. Those were the interesting parts of SGConfDemo and they will move into the kit as optional modules so a watch-only target does not pull ActivityKit.

## Layout

```
Sources/ConferenceKit/
  Model/          Manifest, theme, speaker, session
  Loading/        Bundle, sample, remote
  Store/          Observable store + favorites
  Theme/          Hex colors, environment
  Views/          Drop-in shells per size class / watch
  Resources/      SampleConference.json
schema/           JSON Schema for organizers
```

## Status

v0 — consumable shell. Enough to stand a conference app up from JSON and start replacing SGConfDemo’s hardcoded models.
