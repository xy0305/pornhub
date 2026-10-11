import XCTest

final class InteractionTests: XCTestCase {
    private func launch(quality: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PHInteractionFixtures"] + (quality ? ["-PHQualityFixture"] : [])
        app.launch()
        return app
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name + "-synthetic-fixture-not-live"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testHeaderHitRegionsAndSingleSheetOwner() {
        let app = launch()
        let menu = app.buttons["home.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        capture("Build11-home")
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
        // The new home shortcut shares the visible title; target the modal row,
        // not a firstMatch that may resolve to the covered root hierarchy.
        let category = app.buttons["menu.destination./categories"]
        XCTAssertTrue(category.isHittable)
        category.tap()
        XCTAssertTrue(app.navigationBars["分类"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["菜单"].exists)
    }

    func testDiscoveryQuickLinksAccountAndNativeDetail() {
        let app = launch()
        let history = app.buttons["home.quick.history"]
        XCTAssertTrue(history.waitForExistence(timeout: 15))
        XCTAssertGreaterThanOrEqual(history.frame.height, 44)
        history.tap()
        XCTAssertTrue(app.navigationBars["观看记录"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["home.account"].tap()
        XCTAssertTrue(app.secureTextFields["密码"].waitForExistence(timeout: 5))
        capture("Build11-account")
        app.buttons["完成"].tap()
        let card = app.buttons["home.video.design-fixture-1"]
        if !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        capture("Build11-home-content")
        card.tap()
        XCTAssertTrue(app.buttons["player.quality"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["点赞"].waitForExistence(timeout: 5))
        capture("Build11-detail")
        app.buttons["点赞"].tap()
        XCTAssertTrue(app.buttons["取消点赞"].exists)
        app.buttons["取消点赞"].tap()
    }

    func testLargeTypeDiscoveryRemainsScrollableAndAccountReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-PHInteractionFixtures", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let menu = app.buttons["home.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        XCTAssertGreaterThanOrEqual(menu.frame.height, 44)
        let account = app.buttons["home.account"]
        XCTAssertTrue(account.isHittable)
        XCTAssertLessThanOrEqual(account.frame.maxX, app.frame.maxX)
        capture("Build11-home-accessibilityXXXL")
        app.swipeUp()
        account.tap()
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()
    }

    func testProfileSortRequestsPagingStaleResponsesAndRetry() {
        let app = XCUIApplication()
        app.launchArguments = ["-PHProfileFixture"]
        app.launch()
        let latest = app.buttons["profile.sort.最新"]
        XCTAssertTrue(latest.waitForExistence(timeout: 15))
        capture("Build11-author")
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
        // The real native bar intentionally overflows horizontally, like the site.
        app.scrollViews["profile.filters"].swipeLeft()
        app.buttons["更多"].tap()
        app.buttons["最长"].tap()
        let retry = app.buttons["重试"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        retry.tap()
        requestContains("o=lg")
        XCTAssertTrue(app.staticTexts["Fixture lg page 1"].waitForExistence(timeout: 5))
    }

    func testServerSubscriptionFixtureRetryPagingRefreshAndAccountIsolation() {
        let app = XCUIApplication()
        app.launchArguments = ["-PHSubscriptionsFixture"]
        app.launch()
        let retry = app.buttons["重试"]
        XCTAssertTrue(retry.waitForExistence(timeout: 15))
        retry.tap()
        XCTAssertTrue(app.staticTexts["Subscription fixture A page 1"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Not a subscription"].exists)
        let more = app.buttons["subscriptions.more"]
        if !more.isHittable { app.swipeUp() }
        more.tap()
        XCTAssertTrue(app.staticTexts["Subscription fixture A page 2"].waitForExistence(timeout: 8))
        app.buttons["subscriptions.refresh"].tap()
        XCTAssertTrue(app.staticTexts["Subscription fixture A page 1"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Subscription fixture A page 2"].exists)
        if !more.isHittable { app.swipeUp() }
        more.tap()
        let account = app.buttons["subscriptions.fixture.account"]
        if !account.isHittable { app.swipeUp() }
        account.tap()
        XCTAssertTrue(app.staticTexts["Subscription fixture B page 1"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Subscription fixture A page 1"].exists)
        XCTAssertFalse(app.staticTexts["Subscription fixture A page 2"].exists)
        let logout = app.buttons["subscriptions.fixture.logout"]
        if !logout.isHittable { app.swipeUp() }
        logout.tap()
        XCTAssertTrue(app.staticTexts["subscriptions.login"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Subscription fixture B page 1"].exists)
    }

    func testLandscapeQualityMenuActuallyChangesURLWithoutReadyPlayback() {
        let app = launch(quality: true)
        let quality = app.buttons["player.quality"]
        XCTAssertTrue(quality.waitForExistence(timeout: 15))
        XCTAssertEqual(quality.value as? String, "720.mp4", "Highest real resolution wins over site default 360p")
        let pip = app.buttons["player.pip"]
        XCTAssertTrue(pip.exists)
        XCTAssertGreaterThanOrEqual(pip.frame.height, 44)
        pip.tap()
        XCTAssertTrue(app.staticTexts["视频就绪后可开启画中画"].exists || app.staticTexts["此设备或当前视频不支持画中画"].exists)
        capture("Build11-player")
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
        app.buttons["player.fixture.refresh"].tap()
        expectation(for: NSPredicate(format: "value == %@", "360.mp4"), evaluatedWith: quality)
        waitForExpectations(timeout: 5)
        quality.tap()
        XCTAssertTrue(app.buttons["720p"].waitForExistence(timeout: 5))
        app.buttons["720p"].tap()
        expectation(for: NSPredicate(format: "value == %@", "720.mp4"), evaluatedWith: quality)
        waitForExpectations(timeout: 5)
    }
}

// Synthetic output adapter: never evidence of Simulator/physical system volume.
extension InteractionTests {
    func testLandscapeAdjustmentRecognizerHUDAndOutputEvents() {
        let app = XCUIApplication()
        app.launchArguments = ["-PHInteractionFixtures", "-PHQualityFixture", "-PHGestureFixture"]
        app.launch()
        XCTAssertTrue(app.buttons["横屏播放"].waitForExistence(timeout: 15))
        app.buttons["横屏播放"].tap()
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 10)
        let hud = app.staticTexts["player.adjustmentHUD"]
        // Use middle video area, outside top/bottom native transport controls.
        func drag(_ x: CGFloat, _ from: CGFloat, _ to: CGFloat) {
            app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: from))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: to)), withVelocity: .slow, thenHoldForDuration: 0)
        }
        drag(0.25, 0.64, 0.38)
        XCTAssertTrue(hud.waitForExistence(timeout: 5))
        XCTAssertTrue(hud.label.contains("亮度"))
        let brightnessOutput = hud.value as? String ?? ""
        XCTAssertFalse(brightnessOutput.contains("brightness=0.5;"))
        XCTAssertTrue(brightnessOutput.contains("volume=0.5;events=0"))
        // Immediate next gesture works even while the HUD is visible.
        drag(0.75, 0.64, 0.38)
        XCTAssertTrue(hud.label.contains("音量"))
        let volumeOutput = hud.value as? String ?? ""
        XCTAssertFalse(volumeOutput.contains("volume=0.5;"))
        XCTAssertFalse(volumeOutput.hasSuffix("events=0"), "Production UISlider valueChanged submission reaches adapter")
        capture("Build11-adjustment-synthetic-output-not-system-volume")
        drag(0.75, 0.38, 0.64)
        XCTAssertTrue(hud.label.contains("音量"))
        app.buttons["player.back"].tap()
        XCTAssertTrue(app.buttons["横屏播放"].waitForExistence(timeout: 10))
    }
}
