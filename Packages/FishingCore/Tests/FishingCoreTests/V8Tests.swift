import XCTest
@testable import FishingCore

final class V8Tests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testEmptyFuelKeepsHalfEfficiency() {
        var s = VoyageState(now: t0); s.weatherOverride = .sunny
        let full = s.catchInterval(at: t0)
        s.fuel = 0
        XCTAssertEqual(VoyageConfig.driftCatchFactor, 0.5)
        XCTAssertEqual(s.catchInterval(at: t0), full / 0.5, accuracy: 1e-9)
        // 没油也照样在钓
        let r = s.advance(to: t0.addingTimeInterval(3600))
        XCTAssertGreaterThan(r.catches.count, 0)
    }

    func testFailedMinigameStillLandsFish() {
        var s = VoyageState(now: t0); s.weatherOverride = .sunny
        let f = s.activeCatch(quality: 0, now: t0)
        XCTAssertNotNil(f)
        var s2 = VoyageState(now: t0); s2.weatherOverride = .sunny
        XCTAssertNotNil(s2.activeCatch(quality: 1, now: t0))
        XCTAssertLessThan(VoyageConfig.activeKgFactor(quality: 0), VoyageConfig.activeKgFactor(quality: 1))
        XCTAssertEqual(VoyageConfig.activeKgFactor(quality: 0), 0.6, accuracy: 1e-9)
    }

    func testAssistBandIsWider() {
        let a = ReelConfig.safeBand(assist: true), n = ReelConfig.safeBand(assist: false)
        XCTAssertLessThan(a.lowerBound, n.lowerBound)
        XCTAssertGreaterThan(a.upperBound, n.upperBound)
    }

    func testReportCollectsEventsForPostcard() {
        var s = VoyageState(now: t0); s.weatherOverride = .sunny
        let before = s.eventCounter
        let r = s.advance(to: t0.addingTimeInterval(12 * 3600))
        XCTAssertEqual(r.events.count, min(60, s.eventCounter - before))
        XCTAssertEqual(r.events.first, s.eventCounter > before ? s.eventLog.first?.text : nil)
        XCTAssertNotNil(r.bestCatch)
        XCTAssertGreaterThanOrEqual(r.trophies, 0)
    }

    func testExportImportRoundTrip() throws {
        var s = VoyageState(now: t0, shipName: "Test")
        s.advance(to: t0.addingTimeInterval(3600))
        let d = try SaveTransfer.export(s, now: t0)
        let back = try SaveTransfer.importSave(d)
        XCTAssertEqual(back.shipName, "Test")
        XCTAssertEqual(back.totalFishCaught, s.totalFishCaught)
        XCTAssertEqual(back.hold.count, s.hold.count)
        // 裸存档也可以导入
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        XCTAssertEqual(try SaveTransfer.importSave(try enc.encode(s)).shipName, "Test")
        XCTAssertThrowsError(try SaveTransfer.importSave(Data("{\"a\":1}".utf8))) { XCTAssertEqual($0 as? SaveTransfer.TransferError, .notASave) }
        XCTAssertThrowsError(try SaveTransfer.importSave(Data("garbage".utf8))) { XCTAssertEqual($0 as? SaveTransfer.TransferError, .corrupted) }
    }

    func testResolvePrefersProgressAndKeepsPurchase() {
        var a = VoyageState(now: t0); a.isFullVersion = true
        var b = VoyageState(now: t0); b.totalFishCaught = 500
        let w = SaveTransfer.resolve(local: a, remote: b)
        XCTAssertEqual(w.totalFishCaught, 500)
        XCTAssertTrue(w.isFullVersion)
        var c = VoyageState(now: t0); c.lastUpdate = t0.addingTimeInterval(60)
        XCTAssertEqual(SaveTransfer.resolve(local: VoyageState(now: t0), remote: c).lastUpdate, c.lastUpdate)
    }
}
