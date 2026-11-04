# ConferenceKitDemo

Sample host app for ConferenceKit, used for the Xcode 27.3 simulator pass.

```sh
xcodegen generate   # writes ConferenceKitDemo.xcodeproj (not committed)
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild test -project ConferenceKitDemo.xcodeproj -scheme ConferenceKitDemo \
  -destination 'id=<iOS 27.3 Duo simulator UDID>'
```

`SimPassUITests` drives the hinge (cover, flat, book, laptop), the cover companion
toggle, reminders through UserNotifications, and Ask through `Integration/ConferenceKitAsk`.
Screenshots go to `/tmp/ck273/shots` (override with `CK_SHOTS` in the test environment).
AskKitUI is left out because it needs the Metal Toolchain.
