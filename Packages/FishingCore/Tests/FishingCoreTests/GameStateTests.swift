import XCTest
@testable import FishingCore

final class GameStateTests: XCTestCase {
    let config = EconomyConfig()
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testInitialState() {
        let s = GameState(config: config, now: t0)
        XCTAssertEqual(s.coins, 50)
        XCTAssertEqual(s.captains.count, 1)
        XCTAssertEqual(s.unlockedAreaIDs, ["bay"])
    }

    func testTripDurationAndPhases() {
        var s = GameState(config: config, now: t0)
        let c = s.captains[0]
        // bay: 6 / 1.0 out, 5*1.0 fishing, 6 back, 2 unload = 19
        XCTAssertEqual(GameState.tripDuration(c, config), 19, accuracy: 1e-9)
        s.advance(by: 7, config: config)
        XCTAssertEqual(s.captains[0].phase, .fishing)
        XCTAssertEqual(s.captains[0].phaseElapsed, 1, accuracy: 1e-9)
        XCTAssertEqual(s.coins, 50)
    }

    func testOneTripEarnsCoins() {
        var s = GameState(config: config, now: t0)
        let earned = s.advance(by: 19, config: config)
        XCTAssertGreaterThanOrEqual(earned, 5 * 2)
        XCTAssertLessThanOrEqual(earned, 5 * 8)
        XCTAssertEqual(s.coins, 50 + earned)
        XCTAssertEqual(s.captains[0].tripsCompleted, 1)
        XCTAssertEqual(s.captains[0].phase, .sailingOut)
        XCTAssertEqual(s.recentCatches.count, 1)
    }

    func testOfflineProgressCappedAndExpectedValue() {
        var s = GameState(config: config, now: t0)
        let r = s.applyElapsed(now: t0.addingTimeInterval(100 * 3600), config: config)
        XCTAssertEqual(r.seconds, 8 * 3600)
        let trips = Double(8 * 3600) / 19
        let expected = trips * 5 * config.areas[0].averageFishValue
        XCTAssertEqual(Double(r.coins), expected, accuracy: expected * 0.02)
        XCTAssertEqual(s.captains[0].tripsCompleted, Int(trips))
    }

    func testBulkMatchesStepwise() {
        var a = GameState(config: config, now: t0)
        var b = GameState(config: config, now: t0)
        a.advance(by: 1000, config: config)
        for _ in 0..<1000 { b.advance(by: 1, config: config) }
        XCTAssertEqual(a.captains[0].tripsCompleted, b.captains[0].tripsCompleted)
        XCTAssertEqual(a.captains[0].phase, b.captains[0].phase)
        XCTAssertEqual(a.captains[0].phaseElapsed, b.captains[0].phaseElapsed, accuracy: 1e-6)
        XCTAssertEqual(Double(a.coins), Double(b.coins), accuracy: Double(b.coins) * 0.15)
    }

    func testUpgradesAndCosts() throws {
        var s = GameState(config: config, now: t0)
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
        var s = GameState(config: config, now: t0)
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
        var s = GameState(config: config, now: t0)
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
