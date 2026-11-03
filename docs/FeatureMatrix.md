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

Follow Live advances the stage and the notes session when the current one ends. Opening a specific session pins notes there until Follow Live is turned back on. The hinge angle only tilts the title a few degrees.

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
| Announcements / news | Whova, conference Twitter/X feeds | Implemented as manifest items, not a social feed. |
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
| Scene accessory | Partial. Optional cover-display companion via `CameraCaptureAccessory`. It does not start the camera. The accessory stays unavailable until a capture session is active, which matches tech talk 111464. |
| Vertical toolbar | System-owned. Toolbars use standard placements so iOS 27.1 can move them under the status bar. The kit does not pin controls to a screen edge. |
| Apple Watch | Implemented. Now, schedule, saved, session notes as text. |
| Apple TV | Implemented. Tabs and read-only notes. |
| visionOS and Mac | Implemented. Regular split, notes beside the session. No Duo hardware APIs. |

## Intents, widgets, reminders, calendar

| Feature | Status |
| --- | --- |
| App entities | Implemented. Conference, Day, Session, Speaker, Track, Room, Venue, Sponsor, Session Note. String queries on each. |
| App enums | Implemented. Session kind, sponsor tier, reminder lead. |
| Intents | Implemented. Open session, open speaker, what’s next, my schedule today, search, favorite, unfavorite, favorite next, add one or all favorites to Calendar, set reminder, add note, show notes, export notes. |
| Assistant schema | Implemented for `system.search` on iOS, macOS, and visionOS. See the PR for the `criteria.term` assumption. |
| Spotlight | Implemented. `IndexedEntity` on sessions and speakers, iOS 18 / macOS 15 / watchOS 11 / visionOS 2, not tvOS. |
| App Shortcuts template | Implemented. The host app target must declare the provider. The package includes `ConferenceAppShortcuts` and `ConferenceShortcutTemplate`. |
| Widgets | Implemented for iOS, macOS, and watchOS. Up Next, Now, My Schedule, Countdown, Favorite (configurable), accessory families, watch corner complication, interactive favorite. |
| Control widget | Implemented. iOS 18 Favorite Next control. |
| AlarmKit | Implemented for iOS 26+ when the SDK has AlarmKit. Fixed alarms before favorited sessions, lead time, authorization. No countdown Live Activity. |
| Notification fallback | Implemented where UserNotifications exists. |
| Calendar | Implemented. Write-only access on iOS and visionOS, full access on macOS, legacy request on watchOS. Drafts are pure and tested. tvOS has no EventKit. |

## Not in the kit

| Feature | Why |
| --- | --- |
| AskKit | `https://github.com/45BitStudios/AskKit` returned 404. No other 45BitStudios AskKit source was readable, so nothing was wired against a guessed API. |
| Attendee messaging, meeting booking, people discovery | Whova and Grip. Needs accounts and a server. A JSON kit cannot do this honestly. |
| Push from a server | Host infrastructure. Local alarms and notifications cover the on-device case. |
| In-app video playback | Optional `recordingURL` opens out. A player, DRM, and offline video are a different product. |
| Tickets and registration | Commerce stays on the web. |
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
