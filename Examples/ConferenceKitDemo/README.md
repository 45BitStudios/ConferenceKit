# ConferenceKitDemo

Multiplatform sample host app for ConferenceKit, used for the Xcode 27.3 simulator pass.

```sh
xcodegen generate   # writes ConferenceKitDemo.xcodeproj (not committed)
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild test -project ConferenceKitDemo.xcodeproj -scheme ConferenceKitDemo \
  -destination 'id=<iOS 27.3 Duo simulator UDID>'
```

`SimPassUITests` drives the hinge (cover, flat, book, laptop), the cover companion
toggle, reminders through UserNotifications, and Ask through `Integration/ConferenceKitAsk`.
Screenshots go to `/tmp/ck273/shots` (override with `CK_SHOTS` in the test environment).

One multiplatform app target (`supportedDestinations: [iOS, macOS, visionOS, tvOS]`, one set of
sources with platform `#if`s). watchOS is left out: it can't share an app target with the others.
The UI test target runs on iOS and visionOS. `VisionSmokeUITests` walks the schedule, a session, notes,
Settings, and Ask there; XCUIScreen captures are blank on the visionOS simulator, so the test logs
`SNAP <name>` lines and the host takes `simctl io screenshot` shots during the pause.
AskKitUI is left out because it needs the Metal Toolchain.
