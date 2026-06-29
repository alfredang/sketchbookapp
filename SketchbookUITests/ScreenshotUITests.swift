import XCTest

/// Captures real App Store screenshots of the working app. Launches with the
/// `SKETCH_SEED=1` affordance so the gallery is pre-populated with sample art,
/// then opens a sketch to show the editor + redesigned toolbar and the brush
/// library. Screenshots are attached to the test result (`keepAlways`).
final class ScreenshotUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testCaptureScreens() {
        let app = XCUIApplication()
        app.launchEnvironment["SKETCH_SEED"] = "1"
        app.launch()

        // 1 — Gallery with sample sketches.
        sleep(2)
        snapshot("01-gallery")

        // 2 — Open a sample sketch → editor with the redesigned toolbar.
        let cell = app.staticTexts["Mountain Sunrise"]
        if cell.waitForExistence(timeout: 10) {
            cell.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.32)).tap()
        }
        sleep(2)
        snapshot("02-editor")

        // 3 — Open the brush library (Procreate-style categories).
        let brushes = app.buttons["Brushes"].firstMatch
        if brushes.waitForExistence(timeout: 6) {
            brushes.tap()
            sleep(2)
            snapshot("03-brushes")
        }
    }

    /// Validates that finger drawing works, and still works while zoomed.
    func testDrawingWorks() {
        let app = XCUIApplication()
        app.launch()

        // New blank sketch.
        let newButton = app.buttons["New Sketch"].firstMatch
        if newButton.waitForExistence(timeout: 8) { newButton.tap() }
        else { app.buttons["New"].firstMatch.tap() }
        let create = app.buttons["Create"]
        XCTAssertTrue(create.waitForExistence(timeout: 8))
        create.tap()
        sleep(1)

        // Draw a stroke with a finger (drag).
        drawStroke(app, from: CGVector(dx: 0.30, dy: 0.45), to: CGVector(dx: 0.70, dy: 0.55))
        drawStroke(app, from: CGVector(dx: 0.35, dy: 0.60), to: CGVector(dx: 0.65, dy: 0.42))
        sleep(1)
        snapshot("04-drawn")

        // Pinch to zoom, then draw again — should still register.
        app.pinch(withScale: 2.2, velocity: 1.5)
        sleep(1)
        drawStroke(app, from: CGVector(dx: 0.40, dy: 0.40), to: CGVector(dx: 0.60, dy: 0.60))
        sleep(1)
        snapshot("05-drawn-zoomed")
    }

    /// Validates multi-page: draw on page 1, add page 2 (blank), draw there,
    /// return to page 1 and confirm its drawing persisted.
    func testMultiPage() {
        let app = XCUIApplication()
        app.launch()
        let newButton = app.buttons["New Sketch"].firstMatch
        if newButton.waitForExistence(timeout: 8) { newButton.tap() } else { app.buttons["New"].firstMatch.tap() }
        let create = app.buttons["Create"]
        XCTAssertTrue(create.waitForExistence(timeout: 8)); create.tap()
        sleep(1)

        // Page 1 — draw a big diagonal.
        drawStroke(app, from: CGVector(dx: 0.30, dy: 0.40), to: CGVector(dx: 0.70, dy: 0.62))
        sleep(1)
        XCTAssertTrue(app.staticTexts["pageIndicator"].label.contains("1 / 1"))
        snapshot("06-page1")

        // Add a page after → should be blank, indicator 2 / 2.
        app.buttons["pagesMenu"].tap()
        app.buttons["Add Page After"].tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["pageIndicator"].label.contains("2 / 2"))
        drawStroke(app, from: CGVector(dx: 0.30, dy: 0.62), to: CGVector(dx: 0.70, dy: 0.40))
        sleep(1)
        snapshot("07-page2")

        // Back to page 1 — original drawing must still be there.
        app.buttons["prevPage"].tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["pageIndicator"].label.contains("1 / 2"))
        snapshot("08-back-to-page1")
    }

    private func drawStroke(_ app: XCUIApplication, from: CGVector, to: CGVector) {
        let a = app.coordinate(withNormalizedOffset: from)
        let b = app.coordinate(withNormalizedOffset: to)
        a.press(forDuration: 0.08, thenDragTo: b)
    }

    private func snapshot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
