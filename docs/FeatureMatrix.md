# ConferenceKit feature matrix

Research for the iOS Conf SG app and the kit that should replace a one-off conference shell. Status is what this package implements.

## Sources

- [iOS Conf SG on the App Store](https://apps.apple.com/us/app/ios-conf-sg/id1164776307) (v3.0.4, January 2026). The listing is short: a free iPhone and iPad app, iOS 17, “keep up-to-date with the conference and workshop schedule.” Release notes for 3.0.4 say the 2026 edition (21–23 January 2026) plus bug fixes. Screenshot pixels were not readable from this environment.
- [iosconf.sg](https://www.iosconf.sg/) and the 2027 page: three days (workshop Wednesday, talks Thursday–Friday), Alliance Française de Singapour, nearest MRT Newton, speakers with sites and socials, sponsor tiers, community pricing.
- Peer apps used as a checklist, not a clone list: Apple Developer / WWDC (schedule, favorites, now/next, search, maps), try! Swift, Deep Dish Swift, NSSpain, SwiftLeeds, Swift Heroes (schedule, speakers, sponsors, venue, code of conduct), Sessionize’s attendee view (personal agenda, filters), Whova and Grip (networking and meetings, called out below as out of scope).

## Highlighted: iPhone Duo laptop mode

Laptop mode is the horizontal fold: the bottom half lies flat like a keyboard deck and the top half stays upright. The kit reads that from the **reserved division region** (a wide, short band), not from the hinge angle and not from device orientation.

| Pose | How it is detected | What you see |
| --- | --- | --- |
| Outer display / compact | Compact horizontal size class, no active division | Tabs. Notes are a section on the session. |
| Open inner display, iPad, Mac | Regular width, division inactive | Split view. Notes sit beside the session when the window is wide enough. |
| Book | Active division taller than it is wide | Schedule on one side of the crease, session on the other (`ArrangementView` split on the horizontal axis when the window is wide). |
| **Laptop** | Active division wider than it is tall | **Top:** live session (title, speaker photos, room, time remaining, progress, next session, slides or link). **Bottom:** the notes editor. |

Follow Live is a switch the person turns on. It is stored in `UserDefaults` and defaults to off. While it is on, the stage and the open notes move to the next session when the current one ends. Opening a session does not flip the switch. The hinge angle only tilts the title a few degrees.

Notes are per session, stored as JSON plus image files (app group when `ConferenceKitAppGroup` is set, otherwise Application Support). They are searchable, timestamped from the session start, and export as Markdown grouped by conference day and session. `SessionNote` is an App Entity. Intents: Add Note to Current Session, Show Session Notes, Export Conference Notes.

## Schedule and content

| Feature | Seen in | Status |
| --- | --- | --- |
| Schedule by day | iOS Conf SG, WWDC, Swift conferences | Implemented. Days use the conference time zone. |
| Filter by track and room | WWDC, Sessionize | Implemented. Toolbar filter. |
| Workshops | iOS Conf SG listing and site (workshop day) | Implemented. Session kind `workshop`, plus an Info entry. |
| Session detail | All of the reference apps | Implemented. Synopsis, speakers, room, track, level, slides, recording. |
| Speakers, bios, socials | iOS Conf SG site, every peer app | Implemented. |
| Favorites / My Schedule | WWDC, Sessionize | Implemented. Sessions and speakers, per conference id. |
| Now / next | WWDC, watch complications | Implemented. All sessions happening now, and the next start boundary. |
| Search | WWDC, Sessionize | Implemented. Sessions, speakers, rooms, tracks, and notes. |
| Venue, map, directions | iOS Conf SG (Alliance Française, MRT), WWDC | Implemented. Map on iOS, macOS, and visionOS. Directions URL everywhere. |
| Sponsors and tiers | iOS Conf SG prospectus, Swift conferences | Implemented. |
| Organizers | Conference sites | Implemented. |
| Code of conduct | try! Swift, SwiftLeeds, most community conferences | Implemented. |
| Announcements / news | Whova, conference Twitter/X feeds | Implemented. Manifest `announcements` stay. `news` is a separate feed: pinned first, then newest, with an optional link and symbol. List on iOS and watchOS, a column on macOS and visionOS, cards on tvOS. |
| Resources | Session slides, venue maps | Implemented. Grouped by category. PDF and doc download with progress and Quick Look on iOS, macOS, and visionOS. Links open in the browser. |
| Conference pass | Event ticket | Implemented as a barcode ticket. Add to Wallet on iOS once a pass is signed. Other platforms show a QR code. |
| Wi-Fi | Whova, attendee emails | Implemented. Reveal and copy the password. |
| Time zones | Anyone flying to Singapore | Implemented. Conference zone for days; toggle conference time vs device time; both shown when they differ. |
| Offline JSON and remote refresh | Organizers who change a room without an App Store release | Implemented. Cache, then refresh. Stale banner if refresh fails. |
| Share links | Sessionize, WWDC | Implemented. `conference.url` paths, or `conferencekit://`. |
| Theme, Dynamic Type, dark mode, VoiceOver | Platform baseline | Implemented. Semantic text, labels on controls, system colors when the theme follows the system. |
| Localizable strings | Platform baseline | English strings in the UI package. |

## iPhone Duo, windows, platforms

| Feature | Status |
| --- | --- |
| No layout from `UIScreen`, idiom, or orientation | Implemented. Size comes from the container (`onGeometryChange`, with a background geometry read on iOS 17). |
| System containers | Implemented. `TabView`, `NavigationSplitView`, and `ArrangementView` where the axis matches the window. |
| Reserved regions | Implemented. Division band places laptop and book panes. Occlusion regions pad the live stage. |
| Hinge | Implemented for a title tilt only. |
| New windows | Implemented. Session and speaker `WindowGroup`s. On iOS the control is `UIWindowScene.ActivationAction`, which hides when a new window is unavailable (outer display). |
| Scene accessory and slide camera | Implemented on iOS. Opt-in. Starts a rear `AVCaptureSession` after camera authorization and registers `CameraCaptureAccessory` while that session runs. The Slide button saves a still into the open session’s notes. Needs `NSCameraUsageDescription`. |
| Vertical toolbar | System-owned. Toolbars use standard placements so iOS 27.1 can move them under the status bar. The kit does not pin controls to a screen edge. |
| Apple Watch | Implemented. Now, schedule, saved, session notes as text. |
| Apple TV | Implemented. Tabs and read-only notes. |
| visionOS and Mac | Implemented. Regular split, notes beside the session. No Duo hardware APIs. |

## Intents, widgets, reminders, calendar

| Feature | Status |
| --- | --- |
| App entities | Implemented. Conference, Day, Session, Speaker, Track, Room, Venue, Sponsor, Session Note, News Item, Resource. String queries on each. |
| App enums | Implemented. Session kind, sponsor tier, reminder lead. |
| Intents | Implemented. Open session, open speaker, what’s next, my schedule today, search, favorite, unfavorite, favorite next, add one or all favorites to Calendar, set reminder, add note, show notes, export notes, show latest news, show resources. |
| Assistant schema | Implemented for `system.search` on iOS, macOS, and visionOS. See the PR for the `criteria.term` assumption. |
| Spotlight | Implemented for sessions and speakers. The Siri AI preview flag also indexes the conference, days, tracks, rooms, venue, sponsors, notes, and My Schedule. |
| App Shortcuts template | Implemented. The host app target must declare the provider. The package includes `ConferenceAppShortcuts` and `ConferenceShortcutTemplate`. |
| Widgets | Implemented for iOS, macOS, and watchOS. Up Next, Now, My Schedule, Countdown, Favorite (configurable), accessory families, watch corner complication, interactive favorite. |
| Control widget | Implemented. iOS 18 Favorite Next control. |
| AlarmKit | Implemented, off by default. `setUseAlarmKit(true)` registers it. The entitlement is not approved, so the default reminder is a local notification. Fixed alarms only. No countdown Live Activity. |
| Notification fallback | Implemented where UserNotifications exists. News announcements use that path only. AlarmKit is never used for them. |
| Calendar | Implemented. Write-only access on iOS and visionOS, full access on macOS, legacy request on watchOS. Drafts are pure and tested. tvOS has no EventKit. |

## Siri AI Developer Preview (opt-in, Xcode 27.3)

Off unless `SIRI_AI_PREVIEW` is set. The default Xcode 27.2 build does not compile these symbols and does not change behavior. Platforms: iOS, iPadOS, macOS, visionOS 27.3. Development-signed builds and internal TestFlight only. Not the App Store or external testers.

| Piece | Status |
| --- | --- |
| `@AppIntent(.tool)` for what’s next, find session, favorite, add note, show notes, export notes | In `SiriPreview.swift`, compiled only with the flag. |
| Indexing keys and traits on the main entities, including favorites | Same file. `@ComputedProperty` / `@DeferredProperty` and `IndexedEntity` for the types that were not already indexed. |
| `@AppEntity(.generable)` session search | `SessionQueryEntity`. |
| Result snippets | `SessionSnippetIntent` and `SpeakerSnippetIntent` (`SnippetIntent` / `ShowsSnippetView`, the iOS 26 result API). They render the same session and speaker cards as the entity snippets. |
| Entity snippets | `SnippetRepresentableEntity` + `CardSnippet` for `CardSnippetFamily.standard`, in `EntitySnippets.swift`. The 27.3 requirement is `associatedtype Body: EntitySnippetContent where Self == Self.Body.Entity` and `@EntitySnippetContentBuilder<Self> static var snippet: Self.Body`. Each witness is `some EntitySnippetContent<Self>`. Session, speaker, session note, conference, room, venue, My Schedule, and the preview mirror entities. Larder does not include this API. Session cards run the existing favorite, reminder, and calendar intents. Note cards run `ShowNotesForSessionIDIntent` and `ToggleSessionNoteStarIntent`, which are not tools and are not discoverable. watchOS and tvOS stay out of the preview. |
| Foreground context and Live Activity | Session screen sets a user activity and a Live Activity while the flag is on, so a note can attach to the session on screen. |
| App skills | `plan-afternoon` and `recall-notes` markdown for the host’s `Skills.skillsbundle`. Skills guide Siri. They do not force tool order. |
| Siri Evaluations | Sample file only. Not part of `swift test`. |

## Not in the kit

| Feature | Why |
| --- | --- |
| AskKit inside the iOS 17 package | AskKit supports every Apple platform at version 27 or later. SwiftPM rejects that dependency from a package whose deployment target is lower, so the root package does not link it. `ConferenceAskAnswers` answers speaker, room, notes, and favorites questions and is tested. `Integration/ConferenceKitAsk` links AskKit and builds the `AskAssistant` for an OS 27 host. |
| Attendee messaging, meeting booking, people discovery | Whova and Grip. Needs accounts and a server. A JSON kit cannot do this honestly. |
| Push from a server | Host infrastructure. Local alarms and notifications cover the on-device case. |
| In-app video playback | Optional `recordingURL` opens out. A player, DRM, and offline video are a different product. |
| Tickets and registration | Commerce and check-in stay on the web. The on-device ticket pass does not sell or validate tickets. |
| Surveys and session ratings | Needs a backend and a moderation story. |
| Indoor wayfinding | A pin, address, directions text, and an Apple Maps link. Not a floor plan. |
| Badge QR and check-in | Privacy-sensitive and needs the registration system. |
| AlarmKit countdown Live Activity | Fixed alarms do not require one. A countdown UI belongs in the host widget extension. |
| visionOS widgets | Widget families on visionOS 1 are not part of the contract this package can confirm. The UI still runs. |
| Translated catalogs | Strings are localizable. Only English is filled in. |
| Several conferences in one binary | One manifest at a time. Favorites are keyed by conference id so a later manifest does not mix them. |
| SwiftData / CloudKit notes | File JSON works on every declared platform and in an app group. Cloud sync can sit on top later. |
| Rich text as an attributed document | Notes are Markdown-friendly plain text plus photos, so export is the same bytes the editor stores. |

## Host pieces that stay outside the package

The widget extension’s `@main`, the app-target `AppShortcutsProvider`, Info.plist usage strings, the AlarmKit entitlement, the app group, and the extra `WindowGroup`s are documented in the README. The package cannot declare those for the host.
