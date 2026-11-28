import XCTest

final class PatrolUITests: XCTestCase {
    func testLoginAndLocalPatrol() {
        let app = XCUIApplication()
        app.launchArguments.append("--patrol-ui-test")
        app.launch()
        func screenshot(_ name: String) {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name
            shot.lifetime = .keepAlways
            add(shot)
        }
        XCTAssertTrue(app.buttons["设置"].waitForExistence(timeout: 15))
        screenshot("01-login")
        app.buttons["设置"].tap()
        app.buttons["本地巡检演示"].tap()
        let daily = app.buttons["shift-daily"]
        XCTAssertTrue(daily.waitForExistence(timeout: 10))
        screenshot("02-daily")
        app.buttons["temporaryTab"].tap()
        XCTAssertTrue(app.buttons["shift-temp"].exists)
        XCTAssertFalse(daily.exists)
        app.buttons["dailyTab"].tap()
        daily.tap()
        let point = app.buttons["point-daily-0"]
        XCTAssertTrue(point.waitForExistence(timeout: 10))
        XCTAssertEqual(point.value as? String, "待巡检")
        point.tap()
        XCTAssertEqual(point.value as? String, "已完成")
        screenshot("03-point")
        app.buttons["返回任务列表"].tap()
        XCTAssertTrue(daily.waitForExistence(timeout: 10))
        app.buttons["退出演示"].tap()
        XCTAssertTrue(app.buttons["登录"].waitForExistence(timeout: 10))
    }
}
