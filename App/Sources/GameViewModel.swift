import Foundation
import SwiftUI
import Combine
import FishingCore

struct OfflineReport {
    let seconds: Double
    let fish: Int
    let released: Int
    let newSpecies: Int
    let arrived: String?
    var events: [String] = []
    var bestFishID: String? = nil
    var trophies = 0
    var fuelEmpty = false
    var rareEvents: [RareEvent] = []
}

/// 面板
enum Panel: String, Identifiable, CaseIterable {
    case chart, gear, dock, codex, tank, log, hold
    var id: String { rawValue }
}

/// UI 与纯逻辑层之间的桥：驱动时钟、存档、离线收益（v2：一艘船）
@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var state: VoyageState
    @Published var offlineReport: OfflineReport?
    @Published var panel: Panel?
    @Published var showMap = false
    @Published var toast: String?
    @Published var eventBanner: String?
    @Published var encyclopediaFish: String?
    @Published var showOnboarding = false
    @Published var showSettings = false
    @Published var showNaming = false
    @Published var showMinigame = false { didSet { AmbientAudio.shared.setUnderwater(showMinigame) } }   // v9：收线时水下闷声
    /// 最近一条捕获（浮动提示）
    @Published var lastCatch: HoldFish?
    @Published var migratedFromV1 = false
    // v9
    @Published var photoMode = false
    @Published var shareRecord: RecordCatch?
    @Published var catHearts = 0          // 触发爱心动画
    @Published var showRecords = false
    @Published var showNotes = false
    /// 演示：小游戏自动玩
    var autoplayMinigame = false
    private var seenEventCounter = 0
    private var lastCatchCount = 0

    lazy var storeManager: StoreManager = StoreManager { [weak self] in
        guard let self, !self.state.isFullVersion else { return }
        self.state.isFullVersion = true; self.save()
        self.toast = tr("已解锁完整版，谢谢支持！", "Full Version unlocked — thank you!")
    }

    private let store = VoyageStore.defaultStore()
    private var timer: AnyCancellable?
    private var ticksSinceSave = 0

    init() {
        CoreLang.english = (Bundle.main.preferredLocalizations.first ?? "zh-Hans").hasPrefix("en")
        let args = ProcessInfo.processInfo.arguments
        if let (s, migrated) = VoyageStore.defaultStore().load() {
            state = s; migratedFromV1 = migrated
        } else {
            state = VoyageState(shipName: CoreLang.english ? "Cloud Haven" : "云栖号")
        }
        state.utcOffset = TimeZone.current.secondsFromGMT()
        #if DEBUG
        if args.contains("-demo") { state = Self.demoState() }
        if let i = args.firstIndex(of: "-ency"), i + 1 < args.count { encyclopediaFish = args[i + 1] }
        if let i = args.firstIndex(of: "-panel"), i + 1 < args.count { panel = Panel(rawValue: args[i + 1]) }
        if let i = args.firstIndex(of: "-weather"), i + 1 < args.count { state.weatherOverride = Weather(rawValue: args[i + 1]) }
        if let i = args.firstIndex(of: "-hour"), i + 1 < args.count, let h = Int(args[i + 1]) {
            // 把本地时间“拨”到指定小时，用于截图昼夜
            let now = Int(Date().timeIntervalSince1970)
            let cur = ((now / 3600) % 24 + 24) % 24
            state.utcOffset = ((h - cur) % 24) * 3600
        }
        if args.contains("-port") { state.phase = .docked }
        if args.contains("-sailing") { try? state.sail(to: "pacific", now: Date()); state.sailElapsed = state.sailTotal * 0.4 }
        if let i = args.firstIndex(of: "-ocean"), i + 1 < args.count { state.oceanID = args[i + 1] }
        if args.contains("-minigame") { showMinigame = true; autoplayMinigame = args.contains("-autoplay") }
        if args.contains("-naming") { showNaming = true }
        if args.contains("-photo") { photoMode = true }
        if args.contains("-records") { showRecords = true }
        if args.contains("-notes") { showNotes = true }
        if args.contains("-share") { shareRecord = RecordCatch(fishID: "mahimahi", kg: 21.4, date: Date(), weather: .sunny, oceanID: "pacific", shiny: true) }
        #endif
        seenEventCounter = state.eventCounter
        lastCatchCount = state.totalFishCaught
        let onboarded = UserDefaults.standard.bool(forKey: "onboarded")
        showOnboarding = (!onboarded && !args.contains("-demo") && !args.contains("-skipOnboarding")) || args.contains("-onboarding")
        if args.contains("-skipOnboarding") && !onboarded && !args.contains("-demo") { showNaming = false }
        if args.contains("-settings") { showSettings = true }
        if args.contains("-tour") { runTour() }
        if args.contains("-offline") {
            offlineReport = OfflineReport(seconds: 3 * 3600 + 25 * 60, fish: 142, released: 96, newSpecies: 2, arrived: nil,
                                          events: [tr("🍾 捞到一个漂流瓶，里面有张旧海图", "🍾 Fished up a message in a bottle with an old chart"),
                                                   tr("🐋 远处有一群座头鲸喷水", "🐋 A pod of humpbacks spouted in the distance"),
                                                   tr("✨ 声呐发现🦈的踪迹！", "✨ Sonar picked up signs of 🦈!")],
                                          bestFishID: "mahimahi", trophies: 1, fuelEmpty: true)
        }
    }

    /// 引导结束 → 给船起名
    func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboarded")
        showOnboarding = false
        AudioManager.shared.play(.open)
        if !UserDefaults.standard.bool(forKey: "named") {
            Task { try? await Task.sleep(for: .milliseconds(500)); showNaming = true }
        }
    }

    func rename(_ name: String) {
        state.rename(name); save()
        UserDefaults.standard.set(true, forKey: "named")
        showNaming = false
        AudioManager.shared.play(.upgrade); AudioManager.shared.notify(.success)
    }

    #if DEBUG
    static func demoState() -> VoyageState {
        let start = Date().addingTimeInterval(-3 * 3600)
        var s = VoyageState(now: start, shipName: CoreLang.english ? "Cloud Haven" : "云栖号")
        s.coins = 128_560; s.gems = 24; s.isFullVersion = true
        s.unlockedOceans = ["coastal", "atlantic", "pacific", "indian"]
        s.visitedOceans = ["coastal", "atlantic", "pacific"]
        s.parts = ["engine": 3, "hold": 4, "sonar": 3, "nets": 3, "icebox": 2, "hull": 1]
        s.gearLevels = ["rod": 2, "trap": 2, "trawl": 3, "longline": 1]
        s.level = 32; s.skills = ["angling": 5, "keenEye": 4, "seamanship": 3, "cook": 2]
        s.weatherOverride = .sunny
        s.utcOffset = TimeZone.current.secondsFromGMT()
        for f in VoyageConfig.oceans.prefix(3).flatMap(\.fish).prefix(20) {
            s.codex[f.id] = CodexEntry(count: 3 + f.id.count, bestKg: f.baseKg * 1.3, firstCaught: start)
        }
        s.questIndex = 8; s.totalFishCaught = 2_380
        s.tank = [("clown", 0.06), ("seabream", 1.8), ("crab", 0.35), ("octopus", 14), ("salmon", 5.2), ("mahimahi", 9)]
            .map { TankFish(fishID: $0.0, kg: $0.1, caughtAt: start) }
        s.tankLevel = 2
        s.oceanID = "coastal"
        s.lastUpdate = start.addingTimeInterval(2.5 * 3600)
        s.advance(to: Date())
        s.fuel = s.fuelCapacity * 0.72
        var e = s.ext
        e.notes = [0, 2, 5, 6]; e.decor = ["sand", "kelp", "coral"]; e.paints = ["classic", "coral"]; e.catHearts = 12
        e.shinies = ["clown": 1]
        e.records["mahimahi"] = RecordCatch(fishID: "mahimahi", kg: 21.4, date: start, weather: .sunny, oceanID: "pacific", shiny: true)
        e.records["seabream"] = RecordCatch(fishID: "seabream", kg: 3.1, date: start, weather: .fog, oceanID: "coastal", shiny: false)
        s.v9 = e
        return s
    }
    #endif

    func resume() {
        AudioManager.shared.startMusic()
        _ = storeManager
        pullCloud()
        let r = state.advance(to: Date())
        if r.seconds > 120, !r.catches.isEmpty {
            offlineReport = OfflineReport(seconds: r.seconds, fish: r.catches.count, released: r.released,
                                          newSpecies: r.newSpecies.count, arrived: r.arrived,
                                          events: r.events, bestFishID: r.bestCatch?.fishID, trophies: r.trophies,
                                          fuelEmpty: state.fuel <= 0, rareEvents: r.rareEvents)
        }
        seenEventCounter = state.eventCounter
        lastCatchCount = state.totalFishCaught
        guard timer == nil else { return }
        timer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in MainActor.assumeIsolated { self?.tick(now) } }
    }

    func pauseAndSave() {
        AudioManager.shared.stopMusic()
        timer?.cancel(); timer = nil
        state.advance(to: Date())
        save()
    }

    private func tick(_ now: Date) {
        let r = state.advance(to: now)
        AmbientAudio.shared.update(state: state, now: now)
        if !r.rareEvents.isEmpty { AudioManager.shared.play(.rare, volume: 0.6); AudioManager.shared.notify(.success) }
        if let c = r.catches.last {
            lastCatch = c
            AudioManager.shared.play(.coin, volume: 0.4)
            AudioManager.shared.haptic(.soft)
        }
        if state.eventCounter != seenEventCounter {
            seenEventCounter = state.eventCounter
            eventBanner = state.eventLog.first?.text
        }
        ticksSinceSave += 1
        if ticksSinceSave >= 20 { ticksSinceSave = 0; save() }
    }

    func save() {
        try? store.save(state)
        if AppSettings.shared.iCloudSync { CloudSave.shared.push(state) }
    }

    // MARK: v8 存档同步 / 导出导入
    /// 启动或回到前台时：与 iCloud 存档比较，取进度更多者
    func pullCloud() {
        guard AppSettings.shared.iCloudSync, let remote = CloudSave.shared.pull() else { return }
        let merged = SaveTransfer.resolve(local: state, remote: remote)
        if merged.lastUpdate != state.lastUpdate || merged.totalFishCaught != state.totalFishCaught {
            state = merged; state.utcOffset = TimeZone.current.secondsFromGMT()
            toast = tr("已从 iCloud 同步存档", "Save synced from iCloud")
        }
    }
    func exportSaveFile() -> URL? {
        guard let d = try? SaveTransfer.export(state) else { return nil }
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmm"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("captain-save-\(f.string(from: Date())).json")
        do { try d.write(to: url, options: .atomic); return url } catch { return nil }
    }
    func importSave(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            var s = try SaveTransfer.importSave(try Data(contentsOf: url))
            s.isFullVersion = s.isFullVersion || state.isFullVersion
            s.utcOffset = TimeZone.current.secondsFromGMT()
            state = s; save()
            toast = tr("存档已导入", "Save imported")
        } catch {
            toast = tr("这不是有效的存档文件", "That isn't a valid save file")
        }
    }

    private func perform(_ action: (inout VoyageState) throws -> Void) {
        do {
            try action(&state); save()
            AudioManager.shared.play(.upgrade, volume: 0.5)
            AudioManager.shared.haptic(.medium)
        } catch {
            AudioManager.shared.play(.error, volume: 0.5)
            AudioManager.shared.notify(.warning)
            toast = Self.message(error)
        }
    }

    static func message(_ e: Error) -> String {
        switch e as? VoyageError {
        case .notEnoughCoins: return tr("金币不足", "Not enough coins")
        case .notEnoughGems: return tr("宝石不足", "Not enough gems")
        case .needsFullVersion: return tr("解锁完整版后可用", "Available in the Full Version")
        case .needsPort: return tr("要先回港才能做这件事", "Head back to port first")
        case .locked: return tr("还没解锁", "Not unlocked yet")
        case .needsSpecies(let n): return tr("图鉴需要收集 \(n) 种", "Discover \(n) species first")
        case .needsHull(let n): return tr("船体加固需要 \(n) 级", "Needs Lv\(n) ice-strengthened hull")
        case .maxLevel: return tr("已满级", "Max level")
        case .holdEmpty: return tr("鱼舱是空的", "The hold is empty")
        case .carrierCooldown: return tr("收购船还在路上", "The carrier ship is on its way")
        case .alreadyThere: return tr("已经在这里了", "Already there")
        case .noSkillPoints: return tr("没有技能点", "No skill points")
        case .tankFull: return tr("鱼缸满了，先扩容或放生", "Aquarium is full — expand it or release a fish")
        default: return tr("操作失败", "Something went wrong")
        }
    }

    // MARK: 操作
    func sail(to dest: String) { perform { try $0.sail(to: dest, now: Date()) }; panel = nil }
    func unlock(_ id: String) { perform { try $0.unlock(id, now: Date()) } }
    func sell(useGems: Bool = false) {
        do {
            let n = try state.sellAll(now: Date(), useGems: useGems); save()
            AudioManager.shared.play(.catchFish); AudioManager.shared.notify(.success)
            toast = "+\(n) 🪙"
        } catch { AudioManager.shared.play(.error, volume: 0.5); toast = Self.message(error) }
    }
    func refuel() { perform { try $0.refuel(now: Date()) } }
    func upgrade(_ p: ShipPart) { perform { try $0.upgrade(p, now: Date()) } }
    func buyGear(_ g: GearType) { perform { try $0.buyGear(g, now: Date()) } }
    func equip(_ g: GearType) { perform { try $0.equip(g, now: Date()) } }
    func learn(_ s: CrewSkill) { perform { try $0.learn(s) } }
    func keep(_ id: UUID) { perform { try $0.keepInTank(id, now: Date()) } }
    func release(_ id: UUID) { if let i = state.tank.firstIndex(where: { $0.id == id }) { state.release(tankIndex: i); save() } }
    func upgradeTank() { perform { try $0.upgradeTank() } }
    /// 小游戏结果
    func finishMinigame(quality: Double) -> HoldFish? {
        let f = state.activeCatch(quality: quality, now: Date())
        save()
        if let f {
            AudioManager.shared.play(f.isShiny || (state.ext.records[f.fishID]?.kg == f.kg && f.kg >= (fish(f.fishID)?.baseKg ?? 1) * VoyageConfig.trophyFactor) ? .rare : .catchFish)
            AudioManager.shared.notify(.success)
        }
        else { AudioManager.shared.play(.error, volume: 0.4) }
        return f
    }

    var isFullVersion: Bool { state.isFullVersion }

    // MARK: v9 船猫 / 装饰 / 涂装
    func petCat() {
        switch state.petCat(now: Date()) {
        case .petted(let h):
            save(); catHearts = h
            AudioManager.shared.play(.purr); AudioManager.shared.notify(.success)
            toast = tr("🐱 呼噜呼噜～ 1 小时内挂机 +10%", "🐱 Purr~ +10% idle catch for 1 hour")
        case .sleepy:
            AudioManager.shared.play(.purr, volume: 0.35); AudioManager.shared.haptic(.soft)
            toast = tr("🐱 船猫眯着眼打了个哈欠（明天再来）", "🐱 The cat yawns lazily (come back tomorrow)")
        }
    }
    func buyDecoration(_ id: String) { perform { try $0.buyDecoration(id) } }
    func paint(_ id: String) { perform { try $0.buyOrApplyPaint(id) } }
    /// 长按连续升级：返回是否成功（失败则停止连发）
    @discardableResult
    func upgradeRepeat(_ p: ShipPart) -> Bool {
        do { try state.upgrade(p, now: Date()); AudioManager.shared.play(.upgrade, volume: 0.4); AudioManager.shared.haptic(.light); return true }
        catch { save(); return false }
    }
    func purchaseFullVersion() {
        Task {
            let ok = await storeManager.purchase()
            if ok { AudioManager.shared.play(.catchFish); AudioManager.shared.notify(.success) }
            else if !state.isFullVersion { toast = tr("购买未完成", "Purchase not completed") }
        }
    }
    func restorePurchases() {
        Task {
            let ok = await storeManager.restore()
            toast = ok ? tr("已恢复购买", "Purchases restored") : tr("没有找到可恢复的购买", "No purchases to restore")
        }
    }
    func collectOffline() {
        offlineReport = nil
        AudioManager.shared.play(.catchFish); AudioManager.shared.notify(.success)
    }

    var season: Season { Season.at(Date(), seasonSeconds: 86_400) }
    func fish(_ id: String) -> FishType? { VoyageConfig.fish(id) }
    func area(of fishID: String) -> Ocean? { VoyageConfig.oceanOf(fish: fishID) }

    func resetGame() {
        state = VoyageState(shipName: state.shipName)
        state.utcOffset = TimeZone.current.secondsFromGMT()
        save()
    }

    // MARK: - 演示视频用自动导览（-demo -tour）
    private func runTour() {
        let steps: [(Double, (GameViewModel) -> Void)] = [
            (0, { $0.panel = nil }),
            (9, { $0.autoplayMinigame = true; $0.showMinigame = true }),
            (24, { $0.showMinigame = false }),
            (27, { $0.state.weatherOverride = .fog }),
            (33, { $0.state.weatherOverride = .sunny; $0.panel = .hold }),
            (39, { $0.sell() }),
            (41, { $0.panel = .chart }),
            (49, { $0.panel = nil; $0.showMap = true }),
            (55, { $0.showMap = false; $0.sail(to: "port") }),
            (58, { $0.state.forceArrive() }),
            (60, { $0.panel = .dock }),
            (64, { $0.upgrade(.sonar) }),
            (67, { $0.panel = .codex }),
            (71, { $0.encyclopediaFish = "seabream" }),
            (77, { $0.encyclopediaFish = nil; $0.panel = .tank }),
            (83, { $0.panel = nil }),
        ]
        Task { @MainActor [weak self] in
            var t = 0.0
            for (at, action) in steps {
                try? await Task.sleep(for: .seconds(at - t)); t = at
                guard let self else { return }
                withAnimation(.spring) { action(self) }
            }
        }
    }
}

extension VoyageState {
    /// 演示：立刻抵达
    mutating func forceArrive() { if phase == .sailing { sailElapsed = sailTotal; lastUpdate = Date().addingTimeInterval(-1); advance(to: Date()) } }
}
