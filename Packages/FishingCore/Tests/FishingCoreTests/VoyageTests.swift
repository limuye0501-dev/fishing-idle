import XCTest
@testable import FishingCore

final class VoyageTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testOceansCoverAllSpeciesOnce() {
        let ids = VoyageConfig.allFish.map(\.id)
        XCTAssertEqual(ids.count, 39)
        XCTAssertEqual(Set(ids).count, 39)
        XCTAssertEqual(VoyageConfig.oceans.map(\.id), ["coastal", "atlantic", "pacific", "indian", "arctic", "southern"])
    }

    func testIdleFishingFillsHoldAndBurnsFuel() {
        var s = VoyageState(now: t0); s.weatherOverride = .sunny
        let r = s.advance(to: t0.addingTimeInterval(3600))
        XCTAssertGreaterThan(r.catches.count, 20)
        XCTAssertLessThanOrEqual(s.hold.count, s.holdCapacity)
        XCTAssertLessThan(s.fuel, 100)
        XCTAssertGreaterThan(s.codex.count, 0)
    }

    func testFullHoldReleasesInsteadOfOverflowing() {
        var s = VoyageState(now: t0); s.weatherOverride = .sunny
        s.advance(to: t0.addingTimeInterval(4 * 3600))
        XCTAssertEqual(s.hold.count, s.holdCapacity)
    }

    func testFreshnessDecaysToFloor() {
        let s = VoyageState(now: t0)
        let f = HoldFish(fishID: "mackerel", kg: 0.5, caughtAt: t0)
        XCTAssertEqual(s.freshness(f, now: t0), 1, accuracy: 0.001)
        XCTAssertEqual(s.freshness(f, now: t0.addingTimeInterval(3 * 3600)), 0.5, accuracy: 0.01)
        XCTAssertEqual(s.freshness(f, now: t0.addingTimeInterval(30 * 3600)), VoyageConfig.minFreshness, accuracy: 0.001)
    }

    func testCarrierPaysLessThanPortAndHasCooldown() throws {
        var a = VoyageState(now: t0); a.weatherOverride = .sunny
        a.hold = [HoldFish(fishID: "seabream", kg: 1.5, caughtAt: t0)]
        var b = a
        let sea = try a.sellAll(now: t0)
        a.hold = b.hold
        XCTAssertThrowsError(try a.sellAll(now: t0.addingTimeInterval(60))) { XCTAssertEqual($0 as? VoyageError, .carrierCooldown) }
        b.phase = .docked
        let port = try b.sellAll(now: t0)
        XCTAssertLessThan(sea, port)
    }

    func testSailToPortAndUpgrade() throws {
        var s = VoyageState(now: t0); s.weatherOverride = .sunny
        try s.sail(to: "port", now: t0)
        XCTAssertEqual(s.phase, .sailing)
        s.advance(to: t0.addingTimeInterval(s.sailTotal + 30))
        XCTAssertEqual(s.phase, .docked)
        s.coins = 10_000
        try s.upgrade(.hold, now: t0)
        XCTAssertEqual(s.holdCapacity, 60)
        try s.upgrade(.hold, now: t0)
        XCTAssertThrowsError(try s.upgrade(.hold, now: t0)) { XCTAssertEqual($0 as? VoyageError, .needsFullVersion) }
    }

    func testUpgradeRequiresPort() {
        var s = VoyageState(now: t0); s.coins = 10_000
        XCTAssertThrowsError(try s.upgrade(.engine, now: t0)) { XCTAssertEqual($0 as? VoyageError, .needsPort) }
    }

    func testOceanUnlockRules() throws {
        var s = VoyageState(now: t0); s.coins = 1_000_000
        XCTAssertThrowsError(try s.unlock("atlantic", now: t0)) { XCTAssertEqual($0 as? VoyageError, .needsSpecies(4)) }
        for id in ["mackerel", "crab", "seabream", "puffer"] { s.codex[id] = CodexEntry(count: 1, bestKg: 1, firstCaught: t0) }
        try s.unlock("atlantic", now: t0)
        XCTAssertThrowsError(try s.unlock("pacific", now: t0)) { XCTAssertEqual($0 as? VoyageError, .needsFullVersion) }
        s.isFullVersion = true
        for f in VoyageConfig.allFish { s.codex[f.id] = CodexEntry(count: 1, bestKg: 1, firstCaught: t0) }
        try s.unlock("pacific", now: t0); try s.unlock("indian", now: t0); try s.unlock("arctic", now: t0)
        XCTAssertEqual(s.canEnter(VoyageConfig.ocean("arctic")!), .needsHull(2))
    }

    func testOutOfFuelStillDrifts() {
        var s = VoyageState(now: t0); s.weatherOverride = .sunny; s.fuel = 0
        let r = s.advance(to: t0.addingTimeInterval(3600))
        XCTAssertGreaterThan(r.catches.count, 0)
        var full = VoyageState(now: t0); full.weatherOverride = .sunny
        XCTAssertLessThan(r.catches.count, full.advance(to: t0.addingTimeInterval(3600)).catches.count)
    }

    func testActiveCatchBetterThanIdle() {
        func avgValue(active: Bool) -> Double {
            var s = VoyageState(now: t0); s.weatherOverride = .sunny
            var total = 0.0
            for i in 0..<400 {
                let now = t0.addingTimeInterval(Double(i))
                if active { if let f = s.activeCatch(quality: 1, now: now) { total += Double(s.value(f, now: now)) }; s.hold.removeAll() }
            }
            if !active {
                let r = s.advance(to: t0.addingTimeInterval(400 * 90))
                total = r.catches.prefix(400).map { Double(s.value($0, now: $0.caughtAt)) }.reduce(0, +)
                return total / Double(min(400, r.catches.count))
            }
            return total / 400
        }
        XCTAssertGreaterThan(avgValue(active: true), avgValue(active: false) * 1.3)
        var s = VoyageState(now: t0)
        XCTAssertNotNil(s.activeCatch(quality: 0.05, now: t0))   // v8：失败也有鱼
    }

    func testQuestRewards() {
        var s = VoyageState(now: t0); s.weatherOverride = .sunny
        s.advance(to: t0.addingTimeInterval(3600))
        XCTAssertGreaterThanOrEqual(s.questIndex, 1)
        XCTAssertGreaterThanOrEqual(s.gems, 1)
    }

    func testWeatherDeterministicAndPolarIce() {
        var s = VoyageState(now: t0)
        XCTAssertEqual(s.weather(at: t0), s.weather(at: t0.addingTimeInterval(60)))
        s.oceanID = "arctic"
        let ws = (0..<200).map { s.weather(at: t0.addingTimeInterval(Double($0) * 3600)) }
        XCTAssertTrue(ws.contains(.ice))
        s.oceanID = "coastal"
        XCTAssertFalse((0..<200).map { s.weather(at: t0.addingTimeInterval(Double($0) * 3600)) }.contains(.ice))
    }

    func testDayParts() {
        XCTAssertEqual(DayPart.at(hour: 6), .dawn); XCTAssertEqual(DayPart.at(hour: 12), .day)
        XCTAssertEqual(DayPart.at(hour: 18), .dusk); XCTAssertEqual(DayPart.at(hour: 23), .night)
    }

    func testSkillsNeedPoints() throws {
        var s = VoyageState(now: t0)
        XCTAssertThrowsError(try s.learn(.angling))
        s.level = 3
        try s.learn(.angling); try s.learn(.cook)
        XCTAssertEqual(s.skillPoints, 0)
    }

    func testMigrationFromV1() throws {
        var old = GameState(now: t0)
        old.coins = 5000; old.gems = 7; old.isFullVersion = false
        old.codex["mackerel"] = CodexEntry(count: 3, bestKg: 1, firstCaught: t0)
        old.unlockedAreaIDs = EconomyConfig().areas.prefix(5).map(\.id)
        let s = VoyageState.migrate(old, now: t0)
        XCTAssertEqual(s.gems, 7); XCTAssertEqual(s.coins, 5200)
        XCTAssertEqual(s.codex["mackerel"]?.count, 3)
        XCTAssertEqual(s.unlockedOceans, ["coastal", "atlantic"])
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        let back = try dec.decode(VoyageState.self, from: enc.encode(s))
        XCTAssertEqual(back.coins, s.coins)
    }

    func testVoyageStoreMigratesLegacySave() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let legacy = SaveStore(url: dir.appendingPathComponent("fishing_idle_save.json"))
        var old = GameState(now: t0); old.coins = 999
        try legacy.save(old)
        let store = VoyageStore(url: dir.appendingPathComponent("fishing_v2_save.json"), legacy: legacy)
        let (s, migrated) = try XCTUnwrap(store.load(now: t0))
        XCTAssertTrue(migrated); XCTAssertEqual(s.coins, 1199)
        try store.save(s)
        XCTAssertEqual(store.load(now: t0)?.1, false)
    }

    func testEnglishNamesForNewSpecies() {
        CoreLang.english = true; defer { CoreLang.english = false }
        XCTAssertEqual(VoyageConfig.fish("krill")?.name, "Antarctic Krill")
        XCTAssertEqual(VoyageConfig.ocean("arctic")?.name, "Arctic Ocean")
    }
}
