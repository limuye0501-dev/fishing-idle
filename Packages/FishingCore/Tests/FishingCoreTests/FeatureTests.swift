import XCTest
@testable import FishingCore

final class FeatureTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 2_000_000)

    func quietConfig() -> EconomyConfig {
        var c = EconomyConfig()
        c.fishSchoolChance = 0; c.stormChance = 0; c.treasureChance = 0
        return c
    }

    // MARK: 图鉴

    func testCodexRecordsSpeciesAndCompletionReward() {
        let cfg = quietConfig()
        var s = GameState(config: cfg, now: t0)
        s.applyElapsed(now: t0.addingTimeInterval(3600), config: cfg)
        let bay = cfg.areas[0]
        XCTAssertEqual(s.codexProgress(bay).caught, 3)
        XCTAssertTrue(s.completedAreaIDs.contains("bay"))
        let total = bay.fish.reduce(0) { $0 + (s.codex[$1.id]?.count ?? 0) }
        XCTAssertEqual(total, s.totalFishCaught)
        for f in bay.fish {
            let e = s.codex[f.id]!
            XCTAssertGreaterThanOrEqual(e.bestKg, f.baseKg * 0.6)
            XCTAssertLessThanOrEqual(e.bestKg, f.baseKg * 1.8)
            XCTAssertGreaterThanOrEqual(e.firstCaught, t0)
        }
        XCTAssertTrue(s.eventLog.contains { $0.text.contains("集齐") })
        // 奖励只发一次
        XCTAssertEqual(s.eventLog.filter { $0.text.contains("集齐「宁静海湾」") }.count, 1)
    }

    func testCompletionBonusMultiplier() {
        let cfg = quietConfig()
        var s = GameState(config: cfg, now: t0)
        s.captains[0].trait = .veteran
        let base = s.valueMultiplier(s.captains[0], config: cfg)
        s.completedAreaIDs = ["bay"]
        XCTAssertEqual(s.valueMultiplier(s.captains[0], config: cfg), base * 1.1, accuracy: 1e-9)
    }

    // MARK: 等级与特性

    func testXPAndLevelUp() {
        let cfg = quietConfig()
        var s = GameState(config: cfg, now: t0)
        XCTAssertEqual(s.captains[0].xpToNext, 40)
        let trip = GameState.tripDuration(s.captains[0], cfg)
        s.advance(by: trip * 4 + 0.01, config: cfg)   // 4 趟 × 10 XP = 40 → Lv2
        XCTAssertEqual(s.captains[0].level, 2)
        XCTAssertEqual(s.captains[0].xp, 0)
        XCTAssertGreaterThan(GameState.speed(s.captains[0], cfg), s.captains[0].boat.speed(cfg))
        XCTAssertTrue(s.eventLog.contains { $0.text.contains("Lv2") })
    }

    func testTraits() {
        let cfg = quietConfig()
        var s = GameState(config: cfg, now: t0)
        var c = s.captains[0]
        c.trait = .veteran
        let normalFishing = GameState.phaseDuration(c, .fishing, cfg)
        c.trait = .quickHands
        XCTAssertEqual(GameState.phaseDuration(c, .fishing, cfg), normalFishing * 0.75, accuracy: 1e-9)

        c.trait = .veteran; c.areaID = "deep"
        XCTAssertEqual(s.valueMultiplier(c, config: cfg), 1.3, accuracy: 1e-9)
        c.areaID = "bay"
        XCTAssertEqual(s.valueMultiplier(c, config: cfg), 1.0, accuracy: 1e-9)

        c.trait = .homebody; c.streak = 5
        XCTAssertEqual(s.valueMultiplier(c, config: cfg), 1.10, accuracy: 1e-9)
        c.streak = 100
        XCTAssertEqual(s.valueMultiplier(c, config: cfg), 1.40, accuracy: 1e-9)

        // 幸运：最贵鱼权重翻倍
        let bay = cfg.areas[0]
        XCTAssertEqual(bay.pickFish(roll: 0.85)?.id, "mackerel")       // 普通：0.85*10=8.5 落在鲭鱼
        XCTAssertEqual(bay.pickFish(roll: 0.85, rareBoost: 2)?.id, "crab") // 幸运：0.85*11=9.35 落在螃蟹

        // 换海域清零连续出海
        s.coins = 10_000
        try? s.unlockArea("reef", config: cfg)
        s.captains[0].streak = 7
        try? s.assign(captain: s.captains[0].id, to: "reef", config: cfg)
        XCTAssertEqual(s.captains[0].streak, 0)
    }

    func testHiredCaptainsGetTraits() throws {
        let cfg = quietConfig()
        var s = GameState(config: cfg, now: t0)
        s.coins = 10_000_000
        for _ in 0..<5 { try s.hireCaptain(config: cfg) }
        XCTAssertEqual(s.captains.count, 6)
        XCTAssertGreaterThan(Set(s.captains.map(\.trait)).count, 1)
    }

    // MARK: 海上事件

    func testStormDelaysAndAddsFish() {
        let cfg = quietConfig()
        var c = GameState(config: cfg, now: t0).captains[0]
        c.trait = .veteran
        let normal = GameState.phaseDuration(c, .fishing, cfg)
        c.tripEvent = .storm
        XCTAssertEqual(GameState.phaseDuration(c, .fishing, cfg), normal * 1.5, accuracy: 1e-9)
        XCTAssertEqual(GameState.catchCount(c, cfg), 5 + 2)
        c.trait = .stormRider
        XCTAssertEqual(GameState.phaseDuration(c, .fishing, cfg), normal, accuracy: 1e-9)
        XCTAssertEqual(GameState.catchCount(c, cfg), 5 + 5)
        c.tripEvent = .fishSchool
        XCTAssertEqual(GameState.catchCount(c, cfg), 8) // 7.5 四舍五入
    }

    func testEventsHappenOfflineAtRoughRates() {
        var cfg = EconomyConfig()
        cfg.maxOfflineSeconds = 24 * 3600
        var s = GameState(config: cfg, now: t0)
        s.captains[0].trait = .veteran
        s.applyElapsed(now: t0.addingTimeInterval(24 * 3600), config: cfg)
        XCTAssertGreaterThan(s.gems, 0, "宝箱应带来宝石")
        XCTAssertGreaterThan(s.eventCounter, 100)
        XCTAssertEqual(s.eventLog.count, 30)  // 日志有上限
    }

    func testDeterministicOffline() {
        let cfg = EconomyConfig()
        var a = GameState(config: cfg, now: t0)
        var b = GameState(config: cfg, now: t0)
        a.applyElapsed(now: t0.addingTimeInterval(7200), config: cfg)
        b.applyElapsed(now: t0.addingTimeInterval(7200), config: cfg)
        XCTAssertEqual(a.coins, b.coins)
        XCTAssertEqual(a.gems, b.gems)
        XCTAssertEqual(a.codex, b.codex)
    }

    // MARK: 存档兼容

    func testDecodesV1Save() throws {
        let id = UUID()
        let json = """
        {"coins":123,"captains":[{"id":"\(id.uuidString)","name":"老王","boat":{"speedLevel":2,"capacityLevel":1},
        "areaID":"bay","phase":"fishing","phaseElapsed":1.5,"tripsCompleted":4}],
        "unlockedAreaIDs":["bay"],"lastUpdate":1000000,"totalFishCaught":20,"rngState":42,"recentCatches":[]}
        """
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        let s = try dec.decode(GameState.self, from: Data(json.utf8))
        XCTAssertEqual(s.coins, 123)
        XCTAssertEqual(s.gems, 0)
        XCTAssertEqual(s.captains[0].id, id)
        XCTAssertEqual(s.captains[0].level, 1)
        XCTAssertEqual(s.captains[0].trait, .veteran)
        XCTAssertNil(s.captains[0].tripEvent)
        XCTAssertTrue(s.codex.isEmpty)
        XCTAssertEqual(s.eventCounter, 0)
    }
}
