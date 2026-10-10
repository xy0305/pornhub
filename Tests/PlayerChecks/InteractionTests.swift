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

    func testProfileSortRequestsPagingStaleResponsesAndRetry() {
        let app = XCUIApplication()
        app.launchArguments = ["-PHProfileFixture"]
        app.launch()
        let latest = app.buttons["profile.sort.最新"]
        XCTAssertTrue(latest.waitForExistence(timeout: 15))
        let request = app.staticTexts["profile.request"]
        func requestContains(_ value: String) {
            expectation(for: NSPredicate(format: "label CONTAINS %@", value), evaluatedWith: request)
            waitForExpectations(timeout: 8)
        }
        app.buttons["profile.sort.最多次观看"].tap()
        // A slow mv response is in flight when the next selection is made.
        app.buttons["profile.sort.最高分"].tap()
        requestContains("o=tr")
        let more = app.buttons["profile.more"]
        app.swipeUp()
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        requestContains("o=tr&page=2")
        XCTAssertTrue(app.staticTexts["Fixture tr page 2"].waitForExistence(timeout: 5))
        // Poll beyond the delayed mv response, then ensure it did not contaminate.
        let settled = expectation(description: "superseded response settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { settled.fulfill() }
        wait(for: [settled], timeout: 3)
        XCTAssertTrue(request.label.contains("o=tr&page=2"))
        XCTAssertFalse(app.staticTexts["Fixture mv page 1"].exists)
        app.swipeDown()
        latest.tap()
        requestContains("/model/fixture/videos")
        expectation(for: NSPredicate(format: "label == %@", "https://cn.pornhub.com/model/fixture/videos"), evaluatedWith: request)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.staticTexts["Fixture tr page 2"].exists)
        // The fixture's first lg request fails; native retry resends same selection.
        app.buttons["更多"].tap()
        app.buttons["最长"].tap()
        let retry = app.buttons["重试"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        retry.tap()
        requestContains("o=lg")
        XCTAssertTrue(app.staticTexts["Fixture lg page 1"].waitForExistence(timeout: 5))
    }

    func testLandscapeQualityMenuActuallyChangesURLWithoutReadyPlayback() {
        let app = launch(quality: true)
        let quality = app.buttons["player.quality"]
        XCTAssertTrue(quality.waitForExistence(timeout: 15))
        app.buttons["横屏播放"].tap()
        XCTAssertTrue(app.buttons["退出横屏"].waitForExistence(timeout: 10))
        let back = app.buttons["player.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 10)
        XCTAssertGreaterThanOrEqual(back.frame.width, 44)
        XCTAssertGreaterThanOrEqual(back.frame.height, 44)
        XCTAssertGreaterThanOrEqual(back.frame.minX, app.frame.minX)
        XCTAssertGreaterThanOrEqual(back.frame.minY, app.frame.minY)
        XCTAssertLessThan(back.frame.maxX, app.frame.width * 0.25)
        XCTAssertLessThan(back.frame.maxY, app.frame.height * 0.3)
        XCTAssertTrue(back.isHittable)
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
        back.tap()
        XCTAssertTrue(app.buttons["横屏播放"].waitForExistence(timeout: 10))
        XCTAssertEqual(quality.value as? String, "360.mp4")
    }
}
