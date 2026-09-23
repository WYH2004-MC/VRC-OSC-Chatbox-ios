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
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
