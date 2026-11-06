# Siri device checklist

Not a test result. Nothing in this file has been run. `swift test` does not compile `SiriPreview/Evaluations/ConferenceSiriEvaluation.swift`, and a passing package test does not mean Siri indexed `Skills.skillsbundle`.

Run these on a signed device with the Siri preview flag on. Do not treat an unsigned compile as a pass for any row.

| Check | What to look for |
| --- | --- |
| Discovery | Ask “what can I do with this app”. The answer should mention the schedule, notes, and the attendee directory without reading a script of skill names. |
| Paraphrase, schedule | “Anything happening right now?” uses the what’s-next tool, not a made-up session. |
| Paraphrase, directory | “Who’s around?” uses the attendee lookup and does not read an email. |
| Speaker versus attendee | “When is Maya speaking?” stays on the schedule. “Is Maya in the directory?” stays on the directory. |
| Snippet | A session, speaker, or attendee card shows the title and the role or speakers. The attendee card does not show an email or a phone number. |
| Lock screen | Searching the directory can run while the phone is locked. Asking for a public email asks for unlock, then asks before the address is spoken. Cancelling shows nothing. |
| Confirmation | Saving a drafted note asks first. Saying no leaves the notes unchanged. |
| Offline or unavailable | With Siri’s connection off, a custom tool does not run. The Schedule, My Notes, and Attendees screens in the app still open. The app must not say it checked a server. |
| Messages | Sending from the app shows that the message stayed on this device. Siri does not claim it was delivered. |
