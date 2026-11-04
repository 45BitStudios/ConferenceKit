#if os(visionOS)
import XCTest

/// visionOS smoke pass: schedule, session detail, notes, settings, and Ask.
/// Screenshots go to `CK_SHOTS`/visionos (default /tmp/ck273/shots/visionos).
@MainActor
final class VisionSmokeUITests: XCTestCase {
    private var app: XCUIApplication!
    private let shots = (ProcessInfo.processInfo.environment["CK_SHOTS"] ?? "/tmp/ck273/shots") + "/visionos"

    override func setUp() async throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: shots, withIntermediateDirectories: true)
        app = XCUIApplication()
    }

    /// XCUIScreen captures come back blank on the visionOS simulator, so the host
    /// watches log.txt for SNAP lines and runs `simctl io screenshot` during the pause.
    private func shot(_ name: String) {
        log("SNAP \(name)")
        sleep(5)
    }

    private func log(_ text: String) {
        print("CKVISION \(text)")
        let url = URL(fileURLWithPath: "\(shots)/log.txt")
        let line = Data((text + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(line); try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }

    func test1_ScheduleDetailNotesSettings() throws {
        app.launch()
        sleep(4)
        log("division=\(app.staticTexts["demo.division"].label) cells=\(app.cells.count) buttons=\(app.buttons.count)")
        shot("40_schedule")
        let session = app.staticTexts["App Intents that actually ship"].firstMatch
        if session.waitForExistence(timeout: 5) {
            log("open session: \(session.label)")
            session.tap(); sleep(3)
        } else { log("session row missing") }
        shot("41_session_detail")
        let note = app.textViews.firstMatch
        log("textViews=\(app.textViews.count) sessionNote=\(note.exists) timestamp=\(app.buttons["Timestamp"].exists) camera=\(app.buttons["Camera"].exists)")
        if note.exists {
            note.tap(); sleep(1)
            note.typeText("visionOS smoke note")
            sleep(1)
            log("note value: \(note.value as? String ?? "nil")")
        }
        shot("42_session_notes")
        let info = app.buttons["Info"].firstMatch
        if info.exists { info.tap(); sleep(2); log("tapped Info") } else { log("Info missing") }
        shot("43a_info")
        // Settings sits below the fold of the Info list; drag the list up to reveal it.
        let conduct = app.buttons["Code of Conduct"].firstMatch
        let venue = app.buttons["Venue"].firstMatch
        if conduct.exists && venue.exists {
            conduct.press(forDuration: 0.2, thenDragTo: venue); sleep(2)
            log("dragged Info list; settings hittable=\(app.buttons["Settings"].firstMatch.isHittable)")
        } else { log("conduct=\(conduct.exists) venue=\(venue.exists)") }
        for candidate in [app.buttons["Settings"].firstMatch, app.staticTexts["Settings"].firstMatch, app.cells.containing(.staticText, identifier: "Settings").firstMatch] where candidate.exists {
            candidate.tap(); sleep(2); log("tapped Settings"); break
        }
        log("settings: leadTime=\(app.staticTexts["Lead time"].exists) reminders=\(app.switches["Reminders for favorites"].exists) companion=\(app.switches["Outer display companion"].exists) alarms=\(app.switches.matching(NSPredicate(format: "label BEGINSWITH 'Alarms'")).count)")
        shot("43_settings")
    }

    func test2_Ask() throws {
        app.launch()
        sleep(3)
        app.buttons["demo.ask"].tap()
        let progress = app.staticTexts["ask.progress"]
        let deadline = Date().addingTimeInterval(90)
        while progress.waitForExistence(timeout: 2), progress.label != "answered=5", Date() < deadline { sleep(2) }
        log("ask linked=\(app.staticTexts["ask.linked"].label) \(progress.label)")
        for element in app.descendants(matching: .any).matching(identifier: "ask.row").allElementsBoundByIndex {
            log("ask row: \(element.label)")
        }
        shot("44_ask_answers")
    }
}
#endif
