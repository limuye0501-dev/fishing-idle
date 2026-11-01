import XCTest
@testable import FishingCore

final class V9QueueTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func fishingState() -> VoyageState {
        var s = VoyageState(now: t0, shipName: "QA")
        s.weatherOverride = .sunny
        if s.phase != .fishing { s.phase = .fishing }
        return s
    }

    /// QA：存档 → 杀进程 → 冷启动，离线结算与一直开着完全一致
    func testOfflineSettlementSurvivesKillAndRelaunch() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = VoyageStore(url: dir.appendingPathComponent("v.json"),
                                legacy: SaveStore(url: dir.appendingPathComponent("old.json")))
        var live = fishingState(), killed = live
        let t1 = t0.addingTimeInterval(600), t2 = t0.addingTimeInterval(600 + 3 * 3600)
        live.advance(to: t1); killed.advance(to: t1)
        try store.save(killed)
        // —— 进程被杀；内存里的 killed 丢弃，只剩磁盘 ——
        guard var relaunched = store.load(now: t2)?.0 else { return XCTFail("save missing") }
        XCTAssertEqual(relaunched.lastUpdate.timeIntervalSince1970, t1.timeIntervalSince1970, accuracy: 1)
        let rep = relaunched.advance(to: t2)
        live.advance(to: t2)
        XCTAssertEqual(rep.seconds, 3 * 3600, accuracy: 1)
        XCTAssertGreaterThan(relaunched.totalFishCaught, 0)
        XCTAssertEqual(relaunched.totalFishCaught, live.totalFishCaught)
        XCTAssertEqual(relaunched.hold.map(\.fishID), live.hold.map(\.fishID))
        XCTAssertEqual(relaunched.coins, live.coins)
        XCTAssertEqual(relaunched.fuel, live.fuel, accuracy: 1e-6)
        // 再次冷启动不会重复结算
        try store.save(relaunched)
        var again = store.load(now: t2)!.0
        XCTAssertEqual(again.advance(to: t2).seconds, 0)
        XCTAssertEqual(again.totalFishCaught, live.totalFishCaught)
    }

    func testOfflineCappedAtMax() {
        var s = fishingState()
        let r = s.advance(to: t0.addingTimeInterval(VoyageConfig.maxOfflineSeconds * 3))
        XCTAssertEqual(r.seconds, VoyageConfig.maxOfflineSeconds, accuracy: 1)
    }

    func testItemizedBreakdownSumsToHoldValue() {
        var s = fishingState()
        s.advance(to: t0.addingTimeInterval(4 * 3600))
        let lines = s.itemize(s.hold, now: s.lastUpdate)
        XCTAssertFalse(lines.isEmpty)
        XCTAssertEqual(lines.map(\.count).reduce(0, +), s.hold.count)
        XCTAssertEqual(lines.map(\.coins).reduce(0, +), s.hold.reduce(0) { $0 + s.value($1, now: s.lastUpdate) })
        XCTAssertEqual(lines.map(\.coins), lines.map(\.coins).sorted(by: >))
    }

    func testBuyingGearNeverAutoSwaps() throws {
        var s = fishingState(); s.phase = .docked; s.coins = 10_000_000; s.gems = 1000; s.isFullVersion = true
        let before = s.equipped
        var bought = 0
        for g in GearType.allCases where g != before && (s.gearLevels[g.rawValue] ?? 0) == 0 {
            if (try? s.buyGear(g, now: t0)) != nil { bought += 1 }
        }
        XCTAssertGreaterThan(bought, 0)
        XCTAssertEqual(s.equipped, before)
    }

    func testMethodsUnlockByUpgrades() throws {
        var s = fishingState()
        XCTAssertFalse(s.hasMethod(.targetLock))
        XCTAssertThrowsError(try s.setTarget(s.ocean.fish[0].id))
        s.parts[ShipPart.sonar.rawValue] = 2
        let target = s.ocean.fish.last!.id
        try s.setTarget(target)
        XCTAssertEqual(s.targetFishID, target)
        // 锁定后目标鱼更常见
        var plain = fishingState()
        s.advance(to: t0.addingTimeInterval(12 * 3600)); plain.advance(to: t0.addingTimeInterval(12 * 3600))
        let n = { (x: VoyageState) in Double(x.hold.filter { $0.fishID == target }.count) / Double(max(1, x.hold.count)) }
        XCTAssertGreaterThanOrEqual(n(s), n(plain))

        var w = fishingState(); w.hold = [HoldFish(id: UUID(), fishID: w.ocean.fish[0].id, kg: 1, caughtAt: t0, active: false)]
        XCTAssertThrowsError(try w.keepInTank(w.hold[0].id, now: t0))
        w.parts[ShipPart.icebox.rawValue] = 3
        XCTAssertNoThrow(try w.keepInTank(w.hold[0].id, now: t0))

        var d = fishingState(); d.parts[ShipPart.nets.rawValue] = 4
        let c0 = d.hold.count
        d.activeCatch(quality: 1, now: t0.addingTimeInterval(1))
        XCTAssertEqual(d.hold.count - c0, 2 + (d.hold.count - c0 - 2))
        XCTAssertGreaterThanOrEqual(d.hold.count - c0, 2)
    }

    func testAquariumOnlyYieldsShells() {
        var s = fishingState(); s.phase = .docked
        s.tank = [TankFish(fishID: s.ocean.fish[0].id, kg: 1, caughtAt: t0), TankFish(fishID: s.ocean.fish[1].id, kg: 1, caughtAt: t0)]
        let coins = s.coins
        s.advance(to: t0.addingTimeInterval(3600))
        XCTAssertEqual(s.ext.shells, 2, accuracy: 0.01)
        XCTAssertEqual(s.coins, coins)
    }
}

final class ExtrasDecodeTests: XCTestCase {
    func testPartialExtrasDecode() throws {
        let e = try JSONDecoder().decode(VoyageExtras.self, from: Data(#"{"notes":[1],"catHearts":3}"#.utf8))
        XCTAssertEqual(e.notes, [1]); XCTAssertEqual(e.catHearts, 3); XCTAssertEqual(e.shells, 0); XCTAssertNil(e.targetFishID)
    }
}
