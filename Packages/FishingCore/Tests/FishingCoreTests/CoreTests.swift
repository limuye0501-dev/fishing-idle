import XCTest
@testable import FishingCore

final class CoreTests: XCTestCase {
    let cfg = quietConfig()

    func testInitialState() {
        let s = GameState(config: cfg, now: date(in: .spring))
        XCTAssertEqual(s.coins, 50)
        XCTAssertEqual(s.captains.count, 1)
        XCTAssertEqual(s.captains[0].boat.equipped, .rod)
        XCTAssertEqual(s.unlockedAreaIDs, ["bay"])
        XCTAssertEqual(s.tankCapacity(config: cfg), 4)
    }

    func testRosterIsRichAndConsistent() {
        let all = cfg.areas.flatMap(\.fish)
        XCTAssertGreaterThanOrEqual(all.count, 32)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "鱼种 id 唯一")
        XCTAssertGreaterThanOrEqual(cfg.areas.count, 8)
        for a in cfg.areas {
            XCTAssertTrue((0...1).contains(a.mapX) && (0...1).contains(a.mapY))
            for f in a.fish { XCTAssertFalse(f.gears.isEmpty, f.id) }
        }
        // 每种稀有度都存在
        XCTAssertEqual(Set(all.map(\.rarity)).count, 4)
        // 海域按距离递增
        XCTAssertEqual(cfg.areas.map(\.distance), cfg.areas.map(\.distance).sorted())
    }

    func testTripDurationAndPhases() {
        var s = plainState(cfg, at: date(in: .spring))
        XCTAssertEqual(GameState.tripDuration(s.captains[0], cfg), 19, accuracy: 1e-9)
        s.advance(by: 7, config: cfg)
        XCTAssertEqual(s.captains[0].phase, .fishing)
        XCTAssertEqual(s.captains[0].phaseElapsed, 1, accuracy: 1e-9)
    }

    func testOneTripEarnsCoins() {
        let t = date(in: .spring)
        var s = plainState(cfg, at: t)
        let earned = s.advance(by: 19, config: cfg, now: t.addingTimeInterval(19))
        XCTAssertGreaterThanOrEqual(earned, 5 * 2)
        XCTAssertEqual(s.coins, 50 + earned)
        XCTAssertEqual(s.captains[0].tripsCompleted, 1)
        XCTAssertNotNil(s.recentCatches.first?.fishID)
    }

    func testOfflineCappedAndStepwiseConsistent() {
        let end = date(in: .winter).addingTimeInterval(10 * 3600)   // 冬季中段
        var a = plainState(cfg, at: end.addingTimeInterval(-100 * 3600))
        let r = a.applyElapsed(now: end, config: cfg)
        let t = date(in: .winter)
        XCTAssertEqual(r.seconds, 8 * 3600)
        // 冬季 + 鱼竿：宁静海湾只钓得到沙丁鱼（价 2）
        XCTAssertEqual(Set(a.codex.keys), ["sardine"])
        let trips = Int(8.0 * 3600 / 19)
        XCTAssertEqual(a.captains[0].tripsCompleted, trips)
        XCTAssertEqual(r.coins, trips * 5 * 2)

        var b = plainState(cfg, at: t)
        var c = plainState(cfg, at: t)
        b.advance(by: 1000, config: cfg, now: t.addingTimeInterval(1000))
        for k in 1...1000 { c.advance(by: 1, config: cfg, now: t.addingTimeInterval(Double(k))) }
        XCTAssertEqual(b.coins, c.coins)
        XCTAssertEqual(b.captains[0].phaseElapsed, c.captains[0].phaseElapsed, accuracy: 1e-6)
    }

    func testUpgradesHireUnlockAssign() throws {
        var s = plainState(cfg, at: date(in: .spring))
        let id = s.captains[0].id
        try s.upgradeCapacity(captain: id, config: cfg)
        XCTAssertEqual(s.coins, 20)
        XCTAssertThrowsError(try s.upgradeSpeed(captain: id, config: cfg))
        s.coins = 1_000_000
        try s.hireCaptain(config: cfg)
        XCTAssertThrowsError(try s.assign(captain: s.captains[1].id, to: "reef", config: cfg))
        try s.unlockArea("reef", config: cfg)
        try s.assign(captain: s.captains[1].id, to: "reef", config: cfg)
        XCTAssertThrowsError(try s.unlockArea("reef", config: cfg))
        for _ in 0..<4 { try s.hireCaptain(config: cfg) }
        XCTAssertNil(s.nextHireCost(config: cfg))
    }

    func testPersistenceRoundTrip() throws {
        var s = plainState(cfg, at: date(in: .summer))
        s.advance(by: 60, config: cfg)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fi_\(UUID()).json")
        let store = SaveStore(url: url)
        try store.save(s)
        let l = try XCTUnwrap(store.load())
        XCTAssertEqual(l.coins, s.coins)
        XCTAssertEqual(l.captains, s.captains)
        XCTAssertEqual(l.codex, s.codex)
        try? FileManager.default.removeItem(at: url)
    }

    func testDecodesV1AndV2Saves() throws {
        let id = UUID()
        let v1 = """
        {"coins":123,"captains":[{"id":"\(id.uuidString)","name":"老王","boat":{"speedLevel":2,"capacityLevel":1},
        "areaID":"bay","phase":"fishing","phaseElapsed":1.5,"tripsCompleted":4}],
        "unlockedAreaIDs":["bay"],"lastUpdate":1000000,"totalFishCaught":20,"rngState":42,
        "recentCatches":[{"captainName":"老王","fishName":"沙丁鱼","fishEmoji":"🐟","count":5,"coins":10}]}
        """
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        let s = try dec.decode(GameState.self, from: Data(v1.utf8))
        XCTAssertEqual(s.coins, 123)
        XCTAssertEqual(s.captains[0].boat.equipped, .rod)
        XCTAssertEqual(s.captains[0].boat.gearLevel(.rod), 1)
        XCTAssertEqual(s.captains[0].level, 1)
        XCTAssertTrue(s.tank.isEmpty)
        XCTAssertNil(s.recentCatches[0].fishID)
        // v2（上一版）：带等级/图鉴但没有渔具、鱼缸
        let v2 = """
        {"coins":5,"gems":3,"captains":[{"id":"\(id.uuidString)","name":"老王","boat":{"speedLevel":1,"capacityLevel":3},
        "areaID":"reef","phase":"returning","phaseElapsed":0,"tripsCompleted":9,"level":4,"xp":7,"trait":"lucky","streak":2}],
        "unlockedAreaIDs":["bay","reef"],"lastUpdate":1000000,"totalFishCaught":40,"rngState":1,"recentCatches":[],
        "codex":{"clown":{"count":3,"bestKg":0.06,"firstCaught":1000}},"completedAreaIDs":[],"eventLog":[],"eventCounter":5}
        """
        let s2 = try dec.decode(GameState.self, from: Data(v2.utf8))
        XCTAssertEqual(s2.captains[0].trait, .lucky)
        XCTAssertEqual(s2.codex["clown"]?.count, 3)
        XCTAssertEqual(s2.tankLevel, 0)
    }
}
