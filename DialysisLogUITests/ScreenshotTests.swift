import XCTest

/// Captures App Store screenshots. Run with scripts/screenshots.sh DialysisLog.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAppScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-resetData", "-sampleData", "-skipOnboarding", "-uiTesting"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Dialysis log"].waitForExistence(timeout: 15))
        sleep(1)
        snap("01-today", app)

        // The exchange editor: the wrapping choices live here.
        app.buttons["Record an exchange"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New exchange"].waitForExistence(timeout: 6))
        sleep(1)
        snap("02-exchange", app)
        app.swipeUp()
        sleep(1)
        snap("03-how-it-looked", app)
        app.buttons["Cancel"].firstMatch.tap()
        sleep(1)

        app.buttons["More"].firstMatch.tap()
        app.buttons["My prescription"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["My prescription"].waitForExistence(timeout: 6))
        sleep(1)
        snap("04-prescription", app)
        app.buttons["Done"].firstMatch.tap()
        sleep(1)

        XCTAssertTrue(app.buttons["How do I use this app?"].waitForExistence(timeout: 6))
        app.buttons["How do I use this app?"].tap()
        sleep(1)
        snap("05-how-to", app)
    }

    func testPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-uiTesting", "-mockPrices"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Lifetime"].waitForExistence(timeout: 10))
        snap("paywall", app)
    }

    private func snap(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
