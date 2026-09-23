//
//  VRC_OSC_ChatboxUITests.swift
//  VRC-OSC-ChatboxUITests
//
//  Created by WYH2004 on 2026/6/12.
//

import XCTest

final class VRC_OSC_ChatboxUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDraftSurvivesTabSwitching() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        dismissStartupPermissionAlerts()

        let messageField = app.descendants(matching: .any)["chatbox.message"]
        XCTAssertTrue(messageField.waitForExistence(timeout: 5))
        messageField.tap()
        messageField.typeText("Draft message")
        app.buttons["Done"].tap()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["Send History"].exists)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["Live preview typed text"].exists)
        app.tabBars.buttons["Send"].tap()
        XCTAssertEqual(messageField.value as? String, "Draft message")
    }

    @MainActor
    func testLaunchPerformance() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        dismissStartupPermissionAlerts()
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }

    @MainActor
    func testRequestsMicrophoneOnLaunchAndDoesNotRepeatDeniedPermission() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.resetAuthorizationStatus(for: .microphone)
        app.launch()

        let alerts = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts
        let microphoneAlert = alerts.firstMatch
        XCTAssertTrue(microphoneAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(microphoneAlert.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'microphone' OR label CONTAINS '麦克风' OR label CONTAINS '麥克風' OR label CONTAINS 'マイク'")
        ).firstMatch.exists)
        denyButton(in: microphoneAlert).tap()
        dismissStartupPermissionAlerts()

        app.terminate()
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["chatbox.message"].waitForExistence(timeout: 5))
        XCTAssertFalse(alerts.firstMatch.waitForExistence(timeout: 2))
    }

    @MainActor
    private func dismissStartupPermissionAlerts() {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        for _ in 0..<3 {
            guard alert.waitForExistence(timeout: 2) else { return }
            let deny = denyButton(in: alert)
            XCTAssertTrue(deny.exists, "Unexpected startup alert: \(alert.label)")
            deny.tap()
        }
    }

    @MainActor
    private func denyButton(in alert: XCUIElement) -> XCUIElement {
        alert.buttons.matching(NSPredicate(
            format: "label IN %@",
            ["Don't Allow", "Don’t Allow", "不允许", "不允許", "許可しない"]
        )).firstMatch
    }
}
