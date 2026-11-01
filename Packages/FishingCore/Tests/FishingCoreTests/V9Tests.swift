import XCTest
@testable import FishingCore

final class V9Tests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testOldSaveWithoutExtrasDecodes() throws {
        let s = VoyageState(now: t0)
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        var obj = try JSONSerialization.jsonObject(with: try enc.encode(s)) as! [String: Any]
        obj.removeValue(forKey: "v9")
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        let back = try dec.decode(VoyageState.self, from: try JSONSerialization.data(withJSONObject: obj))
        XCTAssertEqual(back.ext.paint, "classic")
    }

    func testOfflineRareEventsHappenAndFeedReport() {
        var s = VoyageState(now: t0); s.weatherOverride = .sunny
        var kinds = Set<RareEvent.Kind>()
        var now = t0
        for _ in 0..<20 { now = now.addingTimeInterval(12 * 3600); kinds.formUnion(s.advance(to: now).rareEvents.map(\.kind)) }
        XCTAssertTrue(kinds.contains(.bottle))
        XCTAssertTrue(kinds.contains(.whales))
        XCTAssertFalse(s.ext.notes.isEmpty)
        XCTAssertEqual(Set(s.ext.notes).count, s.ext.notes.count)
    }

    func testAuroraOnlyInPolarSeas() {
        var s = VoyageState(now: t0); s.weatherOverride = .sunny
        var now = t0, aurora = 0
        for _ in 0..<10 { now = now.addingTimeInterval(12 * 3600); aurora += s.advance(to: now).rareEvents.filter { $0.kind == .aurora }.count }
        XCTAssertEqual(aurora, 0)
        var p = VoyageState(now: t0); p.oceanID = "arctic"; p.weatherOverride = .ice; p.gearLevels["longline"] = 1
        now = t0
        for _ in 0..<10 { now = now.addingTimeInterval(12 * 3600); aurora += p.advance(to: now).rareEvents.filter { $0.kind == .aurora }.count }
        XCTAssertGreaterThan(aurora, 0)
    }

    func testStormSurvivedEvent() {
        var s = VoyageState(now: t0); s.weatherOverride = .storm
        s.advance(to: t0.addingTimeInterval(2 * 3600))
        s.weatherOverride = .sunny
        let r = s.advance(to: t0.addingTimeInterval(4 * 3600))
        XCTAssertTrue(r.rareEvents.contains { $0.kind == .stormSurvived })
    }

    func testShinyWorthMoreAndRecordsTracked() {
        let s = VoyageState(now: t0)
        let a = HoldFish(fishID: "sardine", kg: 0.1, caughtAt: t0), b = HoldFish(fishID: "sardine", kg: 0.1, caughtAt: t0, shiny: true)
        XCTAssertGreaterThan(s.value(b, now: t0), s.value(a, now: t0) * 3)
        var x = VoyageState(now: t0); x.weatherOverride = .sunny
        x.advance(to: t0.addingTimeInterval(12 * 3600))
        XCTAssertFalse(x.ext.records.isEmpty)
        for (id, r) in x.ext.records { XCTAssertEqual(r.kg, x.codex[id]!.bestKg, accuracy: 1e-9) }
    }

    func testFogAndRainAreMoodNotPunishment() {
        XCTAssertGreaterThan(Weather.fog.rareBoost, 1.2)
        XCTAssertGreaterThan(Weather.rain.rareBoost, 1.2)
        XCTAssertGreaterThanOrEqual(Weather.rain.catchRate, 0.95)
        XCTAssertGreaterThanOrEqual(Weather.fog.catchRate, 0.9)
    }

    func testCatOncePerDay() {
        var s = VoyageState(now: t0); s.weatherOverride = .sunny
        let base = s.catchInterval(at: t0)
        XCTAssertEqual(s.petCat(now: t0), .petted(hearts: 1))
        XCTAssertEqual(s.petCat(now: t0.addingTimeInterval(60)), .sleepy)
        XCTAssertLessThan(s.catchInterval(at: t0.addingTimeInterval(60)), base)
        var fresh = VoyageState(now: t0); fresh.weatherOverride = .sunny
        XCTAssertEqual(s.catchInterval(at: t0.addingTimeInterval(3700)), fresh.catchInterval(at: t0.addingTimeInterval(3700)), accuracy: 1e-9)
        XCTAssertEqual(s.petCat(now: t0.addingTimeInterval(86_400)), .petted(hearts: 2))
    }

    func testDecorAndPaintSinks() throws {
        var s = VoyageState(now: t0); s.coins = 10_000
        try s.buyDecoration("sand")
        XCTAssertEqual(s.coins, 8_000)
        XCTAssertThrowsError(try s.buyDecoration("sand"))
        XCTAssertEqual(s.decorSellBonus, 1.02, accuracy: 1e-9)
        try s.buyOrApplyPaint("coral"); XCTAssertEqual(s.ext.paint, "coral"); XCTAssertEqual(s.coins, 0)
        try s.buyOrApplyPaint("classic"); XCTAssertEqual(s.ext.paint, "classic")
        XCTAssertThrowsError(try s.buyOrApplyPaint("mint"))
    }

    /// 节奏：满配船挂机 50 小时的收入，不足以买完全部长期去处（装饰 + 涂装）
    func testIdlePacingDoesNotCapOutIn50h() {
        var s = VoyageState(now: t0, shipName: "T")
        s.isFullVersion = true; s.weatherOverride = .sunny
        s.unlockedOceans = VoyageConfig.oceans.map(\.id); s.oceanID = "indian"
        for p in ShipPart.allCases { s.parts[p.rawValue] = VoyageConfig.maxPartLevel }
        s.gearLevels = ["rod": 5, "trap": 5, "trawl": 5, "longline": 5, "deepNet": 5]
        s.skills = ["angling": 5, "keenEye": 5, "seamanship": 5, "cook": 5]
        var now = t0, earned = 0
        for _ in 0..<(50 * 2) {      // 每 30 分钟叫收购船（理想化的勤快玩家）
            now = now.addingTimeInterval(1800); s.fuel = s.fuelCapacity
            s.lastCarrier = .distantPast
            earned += (try? s.sellAll(now: now)) ?? 0
        }
        print("PACING maxed ship 50h earned=\(earned) per_h=\(earned / 50) longTermSink=\(VoyageConfig.totalLongTermSink)")
        XCTAssertLessThan(earned, VoyageConfig.totalLongTermSink)
    }
}
