import XCTest
@testable import FishingCore

final class PaywallTests: XCTestCase {
    func testFreeVersionLimits() throws {
        let cfg = quietConfig()
        var s = GameState(config: cfg, now: date(in: .winter))
        XCTAssertFalse(s.isFullVersion)
        s.coins = 1_000_000; s.gems = 100
        let id = s.captains[0].id
        try s.unlockArea("mangrove", config: cfg)                       // 第二片海域免费
        XCTAssertThrowsError(try s.unlockArea("reef", config: cfg)) { XCTAssertEqual($0 as? GameError, .requiresFullVersion) }
        try s.buyGear(.trap, captain: id, config: cfg)                  // 笼捕免费
        XCTAssertThrowsError(try s.buyGear(.longline, captain: id, config: cfg)) { XCTAssertEqual($0 as? GameError, .requiresFullVersion) }
        XCTAssertThrowsError(try s.buyGear(.deepNet, captain: id, config: cfg))
        XCTAssertThrowsError(try s.upgradeTank(config: cfg)) { XCTAssertEqual($0 as? GameError, .requiresFullVersion) }
        try s.upgradeGear(.rod, captain: id, config: cfg)               // 鱼竿升级免费
        try s.rushTrip(captain: id, config: cfg, now: date(in: .winter)) // 宝石加速免费
        // 免费版同样四季轮换
        XCTAssertEqual(s.season(at: date(in: .winter), config: cfg), .winter)
    }

    /// 免费海域的每种鱼，一年内都能用免费渔具抓到 → 免费图鉴可集齐
    func testFreeSeasCodexCompletableInFreeTier() {
        let cfg = EconomyConfig()
        for area in cfg.areas.prefix(cfg.freeAreaCount) {
            for f in area.fish {
                let ok = Season.allCases.contains { se in cfg.freeGear.contains { f.catchable(with: $0, in: se) } }
                XCTAssertTrue(ok, "\(f.name) 免费版抓不到")
            }
        }
    }

    /// 实际模拟：免费版玩家跨一年（四季）用鱼竿/笼捕把两片免费海域图鉴集齐
    func testFreeTierSimulationCompletesCodex() throws {
        let cfg = quietConfig()
        let t0 = date(in: .spring)
        var s = GameState(config: cfg, now: t0)
        s.coins = 1_000_000
        let id = s.captains[0].id
        try s.unlockArea("mangrove", config: cfg)
        try s.buyGear(.trap, captain: id, config: cfg)
        for day in 0..<4 {
            for area in ["bay", "mangrove"] {
                for gear in [GearType.rod, .trap] {
                    try s.assign(captain: id, to: area, config: cfg)
                    try s.equipGear(gear, captain: id)
                    let end = s.lastUpdate.addingTimeInterval(1800)
                    s.applyElapsed(now: end, config: cfg)
                }
            }
            s.lastUpdate = t0.addingTimeInterval(Double(day + 1) * 86_400)
        }
        XCTAssertTrue(s.completedAreaIDs.contains("bay"))
        XCTAssertTrue(s.completedAreaIDs.contains("mangrove"))
    }

    func testGrantFullVersionUnlocksEverything() throws {
        let cfg = quietConfig()
        var s = GameState(config: cfg, now: date(in: .winter))
        s.coins = 1_000_000; s.gems = 100
        s.grantFullVersion()
        try s.unlockArea("reef", config: cfg)
        try s.buyGear(.deepNet, captain: s.captains[0].id, config: cfg)
        try s.upgradeTank(config: cfg)
        XCTAssertEqual(s.season(at: date(in: .winter), config: cfg), .winter)
    }

    func testOldSavesGrandfathered() throws {
        func decode(_ areas: String) throws -> GameState {
            let json = """
            {"coins":1,"captains":[],"unlockedAreaIDs":[\(areas)],"lastUpdate":1000000,"totalFishCaught":0,"rngState":1,"recentCatches":[]}
            """
            let d = JSONDecoder(); d.dateDecodingStrategy = .secondsSince1970
            return try d.decode(GameState.self, from: Data(json.utf8))
        }
        XCTAssertTrue(try decode("\"bay\",\"reef\"").isFullVersion)
        XCTAssertFalse(try decode("\"bay\"").isFullVersion)
        // 新存档写入后保持
        var s = try decode("\"bay\""); s.grantFullVersion()
        let e = JSONEncoder(); e.dateEncodingStrategy = .secondsSince1970
        let d = JSONDecoder(); d.dateDecodingStrategy = .secondsSince1970
        XCTAssertTrue(try d.decode(GameState.self, from: e.encode(s)).isFullVersion)
    }
}
