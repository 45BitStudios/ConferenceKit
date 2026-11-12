#if os(iOS)
import XCTest

/// Simulator pass for the Duo: laptop mode, the cover companion toggle,
/// reminders, and Ask. Screenshots go to `CK_SHOTS` (a host path; the
/// simulator shares the Mac file system) and into the result bundle.
@MainActor
final class SimPassUITests: XCTestCase {
    private var app: XCUIApplication!
    private let shots = ProcessInfo.processInfo.environment["CK_SHOTS"] ?? "/tmp/ck273/shots"

    override func setUp() async throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: shots, withIntermediateDirectories: true)
        app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "permissions") { alert in
            for label in ["Allow", "OK", "Allow While Using App"] where alert.buttons[label].firstMatch.exists {
                alert.buttons[label].firstMatch.tap()
                return true
            }
            return false
        }
    }

    private func shot(_ name: String) {
        let image = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? image.pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/\(name).png"))
    }

    private func log(_ text: String) {
        print("CKPASS \(text)")
        let url = URL(fileURLWithPath: "\(shots)/log.txt")
        let line = Data((text + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(line); try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }

    private var division: String {
        let label = app.staticTexts["demo.division"]
        return label.waitForExistence(timeout: 5) ? label.label : "missing"
    }

    private func setHinge(_ degrees: Double) {
        guard let hinge = XCUIDevice.shared.hinge else { log("hinge=nil"); return }
        hinge.angle = degrees * .pi / 180
        sleep(2)
        log("hinge set \(degrees)° read \(Int(hinge.angle * 180 / .pi))° division=\(division)")
    }

    private func allowSpringboardAlert() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: 4) {
            log("system alert: \(alert.label)")
            for label in ["Allow", "OK", "Allow While Using App"] where alert.buttons[label].exists {
                alert.buttons[label].firstMatch.tap(); break
            }
        }
    }

    private func dismissStatusAlert() {
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            log("app alert: \(alert.label) / \(alert.staticTexts.allElementsBoundByIndex.map(\.label))")
            alert.buttons.firstMatch.tap()
        }
    }

    func test1_LaptopMode() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        log("hinge initial=\(XCUIDevice.shared.hinge.map { "\(Int($0.angle * 180 / .pi))°" } ?? "nil") orientation=\(XCUIDevice.shared.orientation.rawValue) division=\(division)")
        shot("01_cover_closed_compact")
        setHinge(180)
        shot("02_hinge180_flat_regular")
        setHinge(100)
        shot("03_hinge100_portrait_book")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        log("landscapeLeft division=\(division)")
        shot("04_laptop_stage_top_schedule_bottom")
        // Taps don't land reliably after rotating the Duo (XCUI coordinates stay in the
        // portrait frame), so open the session flat, then fold back into laptop pose.
        XCUIDevice.shared.orientation = .portrait
        setHinge(180)
        let cell = app.cells.element(boundBy: 2)
        if cell.waitForExistence(timeout: 5) { cell.tap(); sleep(2) } else { log("no cells") }
        log("flat after open textViews=\(app.textViews.count) noteActions=\(app.buttons["Note actions"].exists)")
        shot("05a_flat_session_open")
        setHinge(100)
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        log("laptop after open division=\(division) textViews=\(app.textViews.count) scheduleButton=\(app.buttons["Schedule"].exists) followLive=\(app.buttons["Follow live"].exists || app.buttons["Following"].exists) noteActions=\(app.buttons["Note actions"].exists) sessionNote=\(app.descendants(matching: .any)["Session note"].exists)")
        shot("05_laptop_stage_top_notes_bottom")
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        setHinge(180)
    }

    private func openSettings() -> Bool {
        if app.tabBars.buttons["Info"].exists {
            app.tabBars.buttons["Info"].tap()
        } else {
            // Regular shell: NavigationSplitView, sidebar collapsed on the flat Duo.
            if !app.buttons["Info"].exists {
                for label in ["Show Sidebar", "ToggleSidebar", "Sidebar"] where app.buttons[label].exists {
                    app.buttons[label].tap(); sleep(1); break
                }
            }
            if !app.buttons["Info"].exists, app.navigationBars.buttons.count > 0 {
                app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
            }
            let info = app.buttons["Info"].firstMatch
            guard info.waitForExistence(timeout: 3) else {
                log("no Info button; nav buttons=\(app.navigationBars.buttons.allElementsBoundByIndex.map(\.label))")
                return false
            }
            info.tap()
        }
        sleep(1)
        let app = self.app!
        let toggle = app.switches["Outer display companion"].firstMatch
        let strategies: [(String, () -> Void)] = [
            ("venue-control", {
                app.buttons["Venue"].firstMatch.tap(); sleep(1)
                self.log("venue control: detail venue=\(app.navigationBars["Venue"].exists || app.staticTexts["Venue"].firstMatch.exists) staticTexts=\(app.staticTexts.count)")
                self.shot("09_info_venue_control")
                app.buttons["Settings"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.2)).tap()
            }),
            ("swipeUp+tap", {
                app.buttons["Venue"].firstMatch.swipeUp(); sleep(1)
                app.buttons["Settings"].firstMatch.tap()
            }),
        ]
        for (name, run) in strategies {
            guard app.buttons["Settings"].firstMatch.waitForExistence(timeout: 3) else { log("settings strategy \(name): no button"); continue }
            run()
            if toggle.waitForExistence(timeout: 3) { log("settings reached via \(name) orientation=\(XCUIDevice.shared.orientation.rawValue)"); return true }
            log("settings strategy \(name) failed")
        }
        return app.switches["Outer display companion"].firstMatch.waitForExistence(timeout: 5)
    }

    func test2_CameraCompanion() throws {
        app.launch()
        setHinge(180)
        // Taps land where the screenshot says only in landscapeLeft on the flat Duo.
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        log("companion division=\(division)")
        guard openSettings() else {
            log("settings not reachable")
            shot("10_settings_missing")
            return
        }
        let toggle = app.switches["Outer display companion"].firstMatch
        var tries = 0
        while !toggle.isHittable && tries < 6 { app.swipeUp(); tries += 1 }
        func flip() {
            let before = toggle.value as? String
            for attempt in 1...3 {
                let inner = toggle.switches.firstMatch
                (inner.exists ? inner : toggle).tap()
                sleep(1)
                let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
                if springboard.alerts.firstMatch.exists { return } // camera prompt handled by caller
                if (toggle.value as? String) != before { log("flip ok on attempt \(attempt)"); return }
            }
            log("flip did not change value")
        }
        if (toggle.value as? String) == "1" { log("companion was left on; turning off first"); flip(); sleep(1) }
        log("companion before=\(toggle.value as? String ?? "?")")
        shot("10_settings_companion_off")
        flip()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let cameraAlert = springboard.alerts.firstMatch
        if cameraAlert.waitForExistence(timeout: 4) {
            log("system alert: \(cameraAlert.label)")
            shot("11a_camera_permission_prompt")
            cameraAlert.buttons["Allow"].firstMatch.tap()
        }
        sleep(3)
        log("companion after-on=\(toggle.value as? String ?? "?") stillOnSettings=\(toggle.exists) timesRow=\(app.staticTexts["Times"].exists) lead=\(app.staticTexts["Lead time"].exists)")
        shot("11_settings_companion_on_state_kept")
        // The cover display is inactive while the inner one is in use, so XCUIScreen
        // can't capture it; the host grabs it with simctl after the run if possible.
        log("screens=\(XCUIScreen.screens.count)")
        sleep(8) // window for an external `simctl io screenshot` of the cover display
        flip()
        sleep(2)
        log("companion after-off=\(toggle.value as? String ?? "?") stillOnSettings=\(toggle.exists) timesRow=\(app.staticTexts["Times"].exists)")
        shot("12_settings_companion_off_again")
    }

    private func openDiagnostics(_ label: String) {
        app.buttons["demo.diagnostics"].tap()
        sleep(2)
        log("\(label) \(app.staticTexts["diag.auth"].label) \(app.staticTexts["diag.pending"].label)")
    }

    private func closeSheet() {
        app.swipeDown(velocity: .fast)
        sleep(1)
        if app.staticTexts["diag.auth"].exists { app.buttons["Done"].firstMatch.tap() }
    }

    private func tapRemind() -> Bool {
        // On iPhone and iPad, Remind sits under the More menu in the navigation bar.
        let more = app.buttons["More"].firstMatch
        if more.waitForExistence(timeout: 2) { more.tap() }
        let remind = app.buttons["Remind"].firstMatch
        guard remind.waitForExistence(timeout: 4) else { log("no Remind button"); return false }
        remind.tap()
        sleep(2)
        dismissStatusAlert()
        return true
    }

    func test3_Reminders() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        setHinge(180)
        let cell = app.cells.element(boundBy: 2)
        guard cell.waitForExistence(timeout: 5) else { log("no cells"); return }
        log("reminder session: \(cell.label)")
        cell.tap()
        sleep(1)
        _ = tapRemind()
        shot("20_remind_tapped_no_permission")
        allowSpringboardAlert()
        openDiagnostics("reminders before-permission")
        shot("21_diag_before_permission")
        let request = app.buttons["diag.requestAuth"]
        if request.exists {
            request.tap()
            allowSpringboardAlert()
            sleep(2)
            app.buttons["diag.refresh"].tap()
            sleep(1)
            log("reminders after-grant \(app.staticTexts["diag.auth"].label) \(app.staticTexts["diag.pending"].label)")
        }
        closeSheet()
        _ = tapRemind()
        shot("22_remind_tapped_with_permission")
        openDiagnostics("reminders after-remind")
        for text in app.staticTexts.allElementsBoundByIndex where text.label.hasPrefix("conferencekit.reminder") {
            log("pending: \(text.label)")
        }
        shot("23_diag_pending_notifications")
    }

    func test4_Ask() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        setHinge(180)
        app.buttons["demo.ask"].tap()
        let progress = app.staticTexts["ask.progress"]
        let deadline = Date().addingTimeInterval(90)
        while progress.waitForExistence(timeout: 2), progress.label != "answered=5", Date() < deadline { sleep(2) }
        log("ask linked=\(app.staticTexts["ask.linked"].label) \(progress.label)")
        var seen: [String] = []
        let rows = app.descendants(matching: .any).matching(identifier: "ask.row")
        for pass in 0..<4 {
            for element in rows.allElementsBoundByIndex where !seen.contains(element.label) {
                seen.append(element.label)
                log("ask row: \(element.label)")
            }
            if pass == 0 { shot("30_ask_answers_top") }
            app.swipeUp(); sleep(1)
        }
        shot("31_ask_answers_bottom")
    }
}
#endif
