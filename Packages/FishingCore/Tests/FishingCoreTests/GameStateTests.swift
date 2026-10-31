import XCTest
@testable import FishingCore

final class GameStateTests: XCTestCase {
    /// 关闭事件、等级加成的“纯净”配置，用于验证基础经济
    let config: EconomyConfig = {
        var c = EconomyConfig()
        c.fishSchoolChance = 0; c.stormChance = 0; c.treasureChance = 0
        c.levelValueBonus = 0; c.levelSpeedBonus = 0
        return c
    }()
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func plainState() -> GameState {
        var s = GameState(config: config, now: t0)
        s.captains[0].trait = .veteran   // 在近海无效果
        return s
    }

    func testInitialState() {
        let s = plainState()
        XCTAssertEqual(s.coins, 50)
        XCTAssertEqual(s.captains.count, 1)
        XCTAssertEqual(s.unlockedAreaIDs, ["bay"])
    }

    func testTripDurationAndPhases() {
        var s = plainState()
        let c = s.captains[0]
        // bay: 6 / 1.0 out, 5*1.0 fishing, 6 back, 2 unload = 19
        XCTAssertEqual(GameState.tripDuration(c, config), 19, accuracy: 1e-9)
        s.advance(by: 7, config: config)
        XCTAssertEqual(s.captains[0].phase, .fishing)
        XCTAssertEqual(s.captains[0].phaseElapsed, 1, accuracy: 1e-9)
        XCTAssertEqual(s.coins, 50)
    }

    func testOneTripEarnsCoins() {
        var s = plainState()
        let earned = s.advance(by: 19, config: config)
        XCTAssertGreaterThanOrEqual(earned, 5 * 2)
        XCTAssertLessThanOrEqual(earned, 5 * 8 + 200) // 可能含图鉴奖励
        XCTAssertEqual(s.coins, 50 + earned)
        XCTAssertEqual(s.captains[0].tripsCompleted, 1)
        XCTAssertEqual(s.captains[0].phase, .sailingOut)
        XCTAssertEqual(s.recentCatches.count, 1)
    }

    func testOfflineProgressCappedAndExpectedValue() {
        var s = plainState()
        let r = s.applyElapsed(now: t0.addingTimeInterval(100 * 3600), config: config)
        XCTAssertEqual(r.seconds, 8 * 3600)
        let trips = Double(8 * 3600) / 19
        let expected = trips * 5 * config.areas[0].averageFishValue * 1.1 // 很快集齐图鉴，+10%
        XCTAssertEqual(Double(r.coins), expected, accuracy: expected * 0.02)
        XCTAssertEqual(s.captains[0].tripsCompleted, Int(trips))
    }

    func testBulkMatchesStepwise() {
        var a = plainState()
        var b = plainState()
        a.advance(by: 1000, config: config)
        for _ in 0..<1000 { b.advance(by: 1, config: config) }
        XCTAssertEqual(a.captains[0].tripsCompleted, b.captains[0].tripsCompleted)
        XCTAssertEqual(a.captains[0].phase, b.captains[0].phase)
        XCTAssertEqual(a.captains[0].phaseElapsed, b.captains[0].phaseElapsed, accuracy: 1e-6)
        XCTAssertEqual(a.coins, b.coins)   // 同一随机序列，结果完全一致
    }

    func testUpgradesAndCosts() throws {
        var s = plainState()
        let id = s.captains[0].id
        try s.upgradeCapacity(captain: id, config: config) // 30
        XCTAssertEqual(s.coins, 20)
        XCTAssertEqual(s.captains[0].boat.capacity(config), 8)
        XCTAssertThrowsError(try s.upgradeSpeed(captain: id, config: config)) {
            XCTAssertEqual($0 as? GameError, .notEnoughCoins)
        }
        s.coins = 1000
        try s.upgradeSpeed(captain: id, config: config)
        XCTAssertEqual(s.captains[0].boat.speed(config), 1.25, accuracy: 1e-9)
        XCTAssertEqual(config.speedUpgradeCost(level: 2), 64)
    }

    func testHireAndUnlockAndAssign() throws {
        var s = plainState()
        s.coins = 10_000
        try s.hireCaptain(config: config)
        XCTAssertEqual(s.captains.count, 2)
        XCTAssertEqual(s.coins, 10_000 - 150)
        XCTAssertThrowsError(try s.assign(captain: s.captains[1].id, to: "reef", config: config))
        try s.unlockArea("reef", config: config)
        try s.assign(captain: s.captains[1].id, to: "reef", config: config)
        XCTAssertEqual(s.captains[1].areaID, "reef")
        XCTAssertThrowsError(try s.unlockArea("reef", config: config))
        for _ in 0..<4 { s.coins = 1_000_000; try s.hireCaptain(config: config) }
        XCTAssertNil(s.nextHireCost(config: config))
        XCTAssertThrowsError(try s.hireCaptain(config: config))
    }

    func testPickFishWeights() {
        let bay = config.areas[0]
        XCTAssertEqual(bay.pickFish(roll: 0)?.id, "sardine")
        XCTAssertEqual(bay.pickFish(roll: 0.99)?.id, "crab")
        XCTAssertEqual(bay.averageFishValue, 3.2, accuracy: 1e-9)
    }

    func testPersistenceRoundTrip() throws {
        var s = plainState()
        s.advance(by: 30, config: config)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fi_test_\(UUID()).json")
        let store = SaveStore(url: url)
        try store.save(s)
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.coins, s.coins)
        XCTAssertEqual(loaded.captains, s.captains)
        XCTAssertEqual(loaded.lastUpdate, s.lastUpdate)
        try? FileManager.default.removeItem(at: url)
    }
}
