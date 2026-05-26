//
//  SetLoopUITests.swift
//  SetLoopUITests
//
//  Created by Astor Ludueña  on 08/05/2026.
//

import XCTest

final class SetLoopUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_RESET_MOCK_DATA")
        app.launch()

        XCTAssertTrue(app.buttons["auth.submitButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["auth.demoButton"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
