import XCTest
@testable import FishingCore

final class SeasonGearTests: XCTestCase {
    func testSeasonCycle() {
        let len = 86_400.0
        XCTAssertEqual(Season.at(Date(timeIntervalSince1970: 0), seasonSeconds: len), .spring)
        XCTAssertEqual(Season.at(Date(timeIntervalSince1970: len * 1 + 5), seasonSeconds: len), .summer)
        XCTAssertEqual(Season.at(Date(timeIntervalSince1970: len * 6), seasonSeconds: len), .autumn)
        XCTAssertEqual(Season.at(Date(timeIntervalSince1970: len * 7 + 1), seasonSeconds: len), .winter)
        XCTAssertEqual(Season.secondsUntilNext(Date(timeIntervalSince1970: len * 3 + 400), seasonSeconds: len), len - 400, accuracy: 1e-6)
    }

    func testCandidatesDependOnGearAndSeason() {
        let bay = EconomyConfig().area("bay")!
        XCTAssertEqual(Set(bay.candidates(gear: .rod, season: .spring).map(\.id)), ["sardine", "mackerel", "seabream"])
        XCTAssertEqual(Set(bay.candidates(gear: .rod, season: .winter).map(\.id)), ["sardine"])
        XCTAssertEqual(bay.candidates(gear: .trap, season: .winter).map(\.id), ["crab"])
        XCTAssertTrue(EconomyConfig().area("legend")!.candidates(gear: .rod, season: .spring).isEmpty)
    }

    func testWrongGearCatchesNothing() {
        var cfg = quietConfig()
        let t = date(in: .spring)
        var s = plainState(cfg, at: t)
        s.coins = 1_000_000
        try? s.unlockArea("mangrove", config: cfg); try? s.unlockArea("reef", config: cfg)
        try? s.unlockArea("kelp", config: cfg)
        try! s.assign(captain: s.captains[0].id, to: "kelp", config: cfg)
        // 海藻森林春季用鱼竿：只有叶海龙；夏天则什么都钓不到
        let t2 = date(in: .summer)
        var s2 = s
        let before = s2.coins
        s2.advance(by: 3600, config: cfg, now: t2.addingTimeInterval(3600))
        XCTAssertEqual(s2.coins, before)
        XCTAssertTrue(s2.eventLog.contains { $0.text.contains("空手而归") })
        // 买笼捕后能抓海胆
        try! s2.buyGear(.trap, captain: s2.captains[0].id, config: cfg)
        try! s2.equipGear(.trap, captain: s2.captains[0].id)
        s2.advance(by: 3600, config: cfg, now: t2.addingTimeInterval(7200))
        XCTAssertNotNil(s2.codex["urchin"])
        XCTAssertNotNil(s2.codex["abalone"], "夏季鲍鱼")
    }

    func testGearMultiplierAndUpgrades() throws {
        let cfg = quietConfig()
        var s = plainState(cfg, at: date(in: .spring))
        let id = s.captains[0].id
        XCTAssertEqual(GameState.catchCount(s.captains[0], cfg), 5)
        XCTAssertThrowsError(try s.buyGear(.trawl, captain: id, config: cfg))  // 钱不够
        s.coins = 100_000
        try s.buyGear(.trawl, captain: id, config: cfg)
        XCTAssertThrowsError(try s.buyGear(.trawl, captain: id, config: cfg)) // 已拥有
        try s.equipGear(.trawl, captain: id)
        XCTAssertEqual(GameState.catchCount(s.captains[0], cfg), 8)   // 5×1.5=7.5→8
        try s.upgradeGear(.trawl, captain: id, config: cfg)
        XCTAssertEqual(GameState.catchCount(s.captains[0], cfg), 9)   // 5×1.5×1.15=8.6→9
        XCTAssertThrowsError(try s.equipGear(.deepNet, captain: id))
        // 深海网只能用宝石买
        XCTAssertThrowsError(try s.buyGear(.deepNet, captain: id, config: cfg))
        s.gems = 25
        try s.buyGear(.deepNet, captain: id, config: cfg)
        XCTAssertEqual(s.gems, 0)
        for _ in 0..<4 { try? s.upgradeGear(.deepNet, captain: id, config: cfg) }
        XCTAssertEqual(s.captains[0].boat.gearLevel(.deepNet), cfg.maxGearLevel)
        XCTAssertThrowsError(try s.upgradeGear(.deepNet, captain: id, config: cfg))
    }

    func testSeasonModifiers() {
        let cfg = quietConfig()
        let s = plainState(cfg, at: date(in: .spring))
        let c = s.captains[0]
        XCTAssertEqual(s.valueMultiplier(c, config: cfg, season: .autumn), 1.1, accuracy: 1e-9)
        XCTAssertEqual(s.valueMultiplier(c, config: cfg, season: .spring), 1.0, accuracy: 1e-9)

        // 冬季风暴概率翻倍：统计大量出海
        var base = EconomyConfig()
        base.fishSchoolChance = 0; base.treasureChance = 0; base.stormChance = 0.1
        func storms(_ season: Season) -> Int {
            var st = plainState(base, at: date(in: season))
            st.captains[0].trait = .stormRider   // 不延误，便于计数
            st.advance(by: 19 * 2000, config: base, now: date(in: season).addingTimeInterval(19 * 2000))
            return st.eventCounter
        }
        let w = storms(.winter), sp = storms(.spring)
        XCTAssertGreaterThan(Double(w), Double(sp) * 1.5)
    }
}

final class ProgressionTests: XCTestCase {
    func testSlowLeveling() {
        let cfg = quietConfig()
        var c = GameState(config: cfg, now: date(in: .spring)).captains[0]
        XCTAssertEqual(c.xpToNext(cfg), 60)
        c.level = 10
        XCTAssertEqual(c.xpToNext(cfg), Int((60 * pow(10.0, 1.6)).rounded()))
        // 三小时近海挂机：等级应保持在个位数
        var s = GameState(config: EconomyConfig(), now: date(in: .spring))
        s.isFullVersion = true
        s.applyElapsed(now: date(in: .spring).addingTimeInterval(3 * 3600), config: EconomyConfig())
        XCTAssertLessThan(s.captains[0].level, 10)
        XCTAssertGreaterThan(s.captains[0].level, 1)
    }

    func testGemDropsReducedAndRush() throws {
        let cfg = EconomyConfig()
        let t = date(in: .summer)
        var s = GameState(config: cfg, now: t)
        s.isFullVersion = true
        s.captains[0].trait = .veteran
        s.applyElapsed(now: t.addingTimeInterval(3 * 3600), config: cfg)
        // ~568 趟 × 3% ≈ 17 颗
        XCTAssertLessThan(s.gems, 40)
        XCTAssertGreaterThan(s.gems, 3)
        // 加速
        let id = s.captains[0].id
        let trips = s.captains[0].tripsCompleted
        let g = s.gems
        try s.rushTrip(captain: id, config: cfg, now: t.addingTimeInterval(3 * 3600))
        XCTAssertEqual(s.captains[0].tripsCompleted, trips + 1)
        XCTAssertEqual(s.captains[0].phase, .sailingOut)
        XCTAssertEqual(s.gems, g - cfg.rushGemCost)
        s.gems = 1
        XCTAssertThrowsError(try s.rushTrip(captain: id, config: cfg, now: t))
    }

    func testTraitsAndEvents() {
        let cfg = quietConfig()
        var c = GameState(config: cfg, now: date(in: .spring)).captains[0]
        c.trait = .veteran
        let normal = GameState.phaseDuration(c, .fishing, cfg)
        c.trait = .quickHands
        XCTAssertEqual(GameState.phaseDuration(c, .fishing, cfg), normal * 0.75, accuracy: 1e-9)
        c.trait = .veteran; c.tripEvent = .storm
        XCTAssertEqual(GameState.phaseDuration(c, .fishing, cfg), normal * 1.5, accuracy: 1e-9)
        XCTAssertEqual(GameState.catchCount(c, cfg), 7)
        c.tripEvent = .fishSchool
        XCTAssertEqual(GameState.catchCount(c, cfg), 8)
        let s = GameState(config: cfg, now: date(in: .spring))
        c.tripEvent = nil; c.trait = .homebody; c.streak = 100
        XCTAssertEqual(s.valueMultiplier(c, config: cfg), 1.4, accuracy: 1e-9)
        c.trait = .veteran; c.areaID = "deep"
        XCTAssertEqual(s.valueMultiplier(c, config: cfg), 1.3, accuracy: 1e-9)
        // 幸运放大最贵鱼
        let pool = cfg.area("bay")!.candidates(gear: .rod, season: .spring) // 沙丁6 鲭3 真鲷1
        XCTAssertEqual(SeaArea.pick(from: pool, roll: 0.85)?.id, "mackerel")
        XCTAssertEqual(SeaArea.pick(from: pool, roll: 0.85, rareBoost: 2)?.id, "seabream")
    }

    func testCodexCompletionOnce() {
        let cfg = quietConfig()
        var s = plainState(cfg, at: date(in: .spring))
        s.coins = 100_000
        try! s.buyGear(.trap, captain: s.captains[0].id, config: cfg)
        s.advance(by: 3600, config: cfg, now: date(in: .spring).addingTimeInterval(3600))   // 鱼竿：沙丁/鲭/真鲷
        XCTAssertFalse(s.completedAreaIDs.contains("bay"))
        try! s.equipGear(.trap, captain: s.captains[0].id)
        s.advance(by: 600, config: cfg, now: date(in: .spring).addingTimeInterval(4200))
        XCTAssertTrue(s.completedAreaIDs.contains("bay"))
        XCTAssertEqual(s.eventLog.filter { $0.text.contains("集齐「宁静海湾」") }.count, 1)
        for (id, e) in s.codex {
            let f = GameState.fish(id, config: cfg)!
            XCTAssertTrue((f.baseKg * 0.6 ... f.baseKg * 1.8).contains(e.bestKg))
        }
    }

    func testDeterministic() {
        let cfg = EconomyConfig()
        let t = date(in: .autumn)
        var a = GameState(config: cfg, now: t), b = GameState(config: cfg, now: t)
        a.isFullVersion = true; b.isFullVersion = true
        a.isFullVersion = true
        a.applyElapsed(now: t.addingTimeInterval(7200), config: cfg)
        b.applyElapsed(now: t.addingTimeInterval(7200), config: cfg)
        XCTAssertEqual(a.coins, b.coins); XCTAssertEqual(a.gems, b.gems); XCTAssertEqual(a.codex, b.codex)
    }
}

final class AquariumTests: XCTestCase {
    func testKeepCatchRefundsAndFillsTank() throws {
        let cfg = quietConfig()
        let t = date(in: .spring)
        var s = plainState(cfg, at: t)
        s.advance(by: 19, config: cfg, now: t.addingTimeInterval(19))
        let rec = s.recentCatches[0]
        let coins = s.coins
        try s.keepCatch(at: 0, config: cfg, now: t)
        XCTAssertEqual(s.coins, coins - rec.sellValue!)
        XCTAssertEqual(s.tank.count, 1)
        XCTAssertEqual(s.tank[0].fishID, rec.fishID)
        XCTAssertThrowsError(try s.keepCatch(at: 0, config: cfg, now: t)) { XCTAssertEqual($0 as? GameState.TankError, .alreadyKept) }
    }

    func testTankCapacityAndUpgrade() throws {
        let cfg = quietConfig()
        let t = date(in: .spring)
        var s = plainState(cfg, at: t)
        s.coins = 1_000_000
        s.advance(by: 19 * 6, config: cfg, now: t.addingTimeInterval(19 * 6))
        for i in 0..<4 { try s.keepCatch(at: i, config: cfg, now: t) }
        XCTAssertThrowsError(try s.keepCatch(at: 4, config: cfg, now: t)) { XCTAssertEqual($0 as? GameState.TankError, .full) }
        try s.upgradeTank(config: cfg)
        XCTAssertEqual(s.tankCapacity(config: cfg), 6)
        try s.keepCatch(at: 4, config: cfg, now: t)
        try s.releaseFish(s.tank[0].id)
        XCTAssertEqual(s.tank.count, 4)
    }

    func testTankIncomeRewardsVariety() {
        var cfg = quietConfig()
        cfg.tankIncomePerValuePerSecond = 0.01
        let t = date(in: .spring)
        var s = plainState(cfg, at: t)
        s.captains = []   // 只看鱼缸
        s.tank = [TankFish(id: UUID(), fishID: "seabream", kg: 1, caughtAt: t),
                  TankFish(id: UUID(), fishID: "seabream", kg: 2, caughtAt: t)]
        XCTAssertEqual(s.tankIncomePerSecond(config: cfg), 0.15, accuracy: 1e-9) // 同种不叠加
        s.tank.append(TankFish(id: UUID(), fishID: "crab", kg: 0.3, caughtAt: t))
        XCTAssertEqual(s.tankIncomePerSecond(config: cfg), 0.23, accuracy: 1e-9)
        let earned = s.advance(by: 100, config: cfg, now: t.addingTimeInterval(100))
        XCTAssertEqual(earned, 23)
    }
}
