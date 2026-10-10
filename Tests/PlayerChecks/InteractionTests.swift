import XCTest

final class InteractionTests: XCTestCase {
    private func launch(quality: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PHInteractionFixtures"] + (quality ? ["-PHQualityFixture"] : [])
        app.launch()
        return app
    }

    func testHeaderHitRegionsAndSingleSheetOwner() {
        let app = launch()
        let menu = app.buttons["home.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        menu.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.25)).tap()
        XCTAssertTrue(app.navigationBars["菜单"].waitForExistence(timeout: 5))
        app.buttons["关闭"].tap()
        let search = app.buttons["home.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(search.frame.height, 44)
        // Empty trailing part of the search capsule, not the text/icon.
        search.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.textFields["search.input"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.buttons["取消"].tap()
        menu.tap()
        XCTAssertTrue(app.navigationBars["菜单"].waitForExistence(timeout: 5))
        app.buttons["分类"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["分类"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["菜单"].exists)
    }

    func testLandscapeQualityMenuActuallyChangesURLWithoutReadyPlayback() {
        let app = launch(quality: true)
        let quality = app.buttons["player.quality"]
        XCTAssertTrue(quality.waitForExistence(timeout: 15))
        app.buttons["横屏播放"].tap()
        XCTAssertTrue(app.buttons["退出横屏"].waitForExistence(timeout: 10))
        quality.tap()
        let hd = app.buttons["720p"]
        XCTAssertTrue(hd.waitForExistence(timeout: 5))
        hd.tap()
        expectation(for: NSPredicate(format: "value == %@", "720.mp4"), evaluatedWith: quality)
        waitForExpectations(timeout: 5)
        quality.tap()
        let sd = app.buttons["360p"]
        XCTAssertTrue(sd.waitForExistence(timeout: 5))
        sd.tap()
        expectation(for: NSPredicate(format: "value == %@", "360.mp4"), evaluatedWith: quality)
        waitForExpectations(timeout: 5)
        app.buttons["退出横屏"].tap()
        XCTAssertTrue(app.buttons["横屏播放"].waitForExistence(timeout: 10))
        XCTAssertEqual(quality.value as? String, "360.mp4")
    }
}
