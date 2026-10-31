import Foundation
import Combine
import FishingCore

struct OfflineReport {
    let seconds: Double
    let coins: Int
    let gems: Int
    let events: Int
}

/// UI 与纯逻辑层之间的桥：驱动时钟、存档、离线收益
@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var state: GameState
    @Published var offlineReport: OfflineReport?
    @Published var toast: String?
    /// 面板当前分页：0 船长 1 渔具 2 海图 3 图鉴 4 鱼缸 5 日志
    @Published var panelTab = 0
    /// 最近一条海上事件提示（自动消失）
    @Published var eventBanner: String?
    private var seenEventCounter = 0
    /// 正在查看的小百科条目（鱼种 id）
    @Published var encyclopediaFish: String?
    /// 渔具页当前选中的船长
    @Published var gearCaptainID: UUID?

    /// 首次启动新手引导
    @Published var showOnboarding = false
    @Published var showSettings = false
    private var lastCatchCount = 0
    lazy var storeManager: StoreManager = StoreManager { [weak self] in
        guard let self, !self.state.isFullVersion else { return }
        self.state.grantFullVersion(); self.save()
        self.toast = "已解锁完整版，谢谢支持！"
    }

    let config = EconomyConfig()
    private let store = SaveStore.defaultStore()
    private var timer: AnyCancellable?
    private var ticksSinceSave = 0

    init() {
        state = SaveStore.defaultStore().load() ?? GameState(config: EconomyConfig())
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let t = Int(args[i + 1]) { panelTab = t }
        #if DEBUG
        // CI 截图用：-demo 生成一个玩了一会儿的存档
        if args.contains("-demo") { state = Self.demoState(config: config) }
        if let i = args.firstIndex(of: "-ency"), i + 1 < args.count { encyclopediaFish = args[i + 1] }
        #endif
        seenEventCounter = state.eventCounter
        lastCatchCount = state.totalFishCaught
        let onboarded = UserDefaults.standard.bool(forKey: "onboarded")
        showOnboarding = (!onboarded && !args.contains("-demo") && !args.contains("-skipOnboarding")) || args.contains("-onboarding")
        if args.contains("-settings") { showSettings = true }
        if args.contains("-offline") {
            offlineReport = OfflineReport(seconds: 3 * 3600 + 25 * 60, coins: 3200, gems: 3, events: 7)
        }
    }

    func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboarded")
        showOnboarding = false
        AudioManager.shared.play(.open)
    }

    #if DEBUG
    static func demoState(config: EconomyConfig) -> GameState {
        let start = Date().addingTimeInterval(-3 * 3600)
        var s = GameState(config: config, now: start)
        s.coins = 100_000
        s.gems = 40
        s.grantFullVersion()
        for a in ["mangrove", "reef", "kelp"] { try? s.unlockArea(a, config: config) }
        try? s.hireCaptain(config: config)
        try? s.hireCaptain(config: config)
        let ids = s.captains.map(\.id)
        try? s.buyGear(.trap, captain: ids[0], config: config)
        try? s.buyGear(.longline, captain: ids[1], config: config)
        try? s.equipGear(.longline, captain: ids[1])
        try? s.assign(captain: ids[1], to: "reef", config: config)
        try? s.buyGear(.trawl, captain: ids[2], config: config)
        try? s.equipGear(.trawl, captain: ids[2])
        try? s.assign(captain: ids[2], to: "mangrove", config: config)
        try? s.upgradeGear(.rod, captain: ids[0], config: config)
        s.applyElapsed(now: Date().addingTimeInterval(-1.5 * 3600), config: config)
        try? s.equipGear(.trap, captain: ids[0])
        s.applyElapsed(now: Date(), config: config)
        // 鱼缸：先升级两次，再放进几种不同的鱼（截图演示用）
        try? s.upgradeTank(config: config); try? s.upgradeTank(config: config)
        for (id, kg) in [("clown", 0.06), ("seadragon", 0.12), ("crab", 0.35), ("seabream", 1.8),
                         ("lobster", 2.1), ("squid", 0.9), ("mudskipper", 0.02), ("urchin", 0.1)] {
            s.tank.append(TankFish(id: UUID(), fishID: id, kg: kg, caughtAt: Date()))
        }
        return s
    }
    #endif

    func resume() {
        AudioManager.shared.startMusic()
        _ = storeManager
        let gemsBefore = state.gems, eventsBefore = state.eventCounter
        let r = state.applyElapsed(now: Date(), config: config)
        if r.seconds > 60, r.coins > 0 {
            offlineReport = OfflineReport(seconds: r.seconds, coins: r.coins,
                                          gems: state.gems - gemsBefore, events: state.eventCounter - eventsBefore)
        }
        seenEventCounter = state.eventCounter
        guard timer == nil else { return }
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                MainActor.assumeIsolated { self?.tick(now) }
            }
    }

    func pauseAndSave() {
        AudioManager.shared.stopMusic()
        timer?.cancel(); timer = nil
        state.applyElapsed(now: Date(), config: config)
        save()
    }

    private func tick(_ now: Date) {
        state.applyElapsed(now: now, config: config)
        if state.eventCounter != seenEventCounter {
            seenEventCounter = state.eventCounter
            eventBanner = state.eventLog.first?.text
        }
        if state.totalFishCaught != lastCatchCount {
            if state.totalFishCaught > lastCatchCount {
                AudioManager.shared.play(.coin, volume: 0.5)
                AudioManager.shared.haptic(.soft)
            }
            lastCatchCount = state.totalFishCaught
        }
        ticksSinceSave += 1
        if ticksSinceSave >= 50 { ticksSinceSave = 0; save() }   // 每 5 秒存档
    }

    private func save() { try? store.save(state) }

    private func perform(_ action: (inout GameState) throws -> Void) {
        do {
            try action(&state); save()
            AudioManager.shared.play(.upgrade, volume: 0.5)
            AudioManager.shared.haptic(.medium)
        } catch {
            AudioManager.shared.play(.error, volume: 0.5)
            AudioManager.shared.notify(.warning)
            report(error)
        }
    }

    private func report(_ error: Error) {
        do { throw error }
        catch GameError.notEnoughCoins { toast = "金币不足" }
        catch GameError.maxCaptains { toast = "船长已满员" }
        catch GameError.areaLocked { toast = "海域未解锁" }
        catch GameError.requiresFullVersion { toast = "解锁完整版后可用" }
        catch GameState.GearError.notEnoughGems { toast = "宝石不足" }
        catch GameState.GearError.maxLevel { toast = "已满级" }
        catch GameState.GearError.notOwned { toast = "还没有这件渔具" }
        catch GameState.TankError.full { toast = "鱼缸满了，先升级或放生" }
        catch GameState.TankError.alreadyKept { toast = "这条已经在鱼缸里了" }
        catch { toast = "操作失败" }
    }

    func upgradeSpeed(_ id: UUID) { perform { try $0.upgradeSpeed(captain: id, config: config) } }
    func upgradeCapacity(_ id: UUID) { perform { try $0.upgradeCapacity(captain: id, config: config) } }
    func hire() { perform { try $0.hireCaptain(config: config) } }
    func unlock(_ areaID: String) { perform { try $0.unlockArea(areaID, config: config) } }
    func assign(_ id: UUID, to areaID: String) { perform { try $0.assign(captain: id, to: areaID, config: config) } }

    func buyGear(_ g: GearType, _ id: UUID) { perform { try $0.buyGear(g, captain: id, config: config) } }
    func upgradeGear(_ g: GearType, _ id: UUID) { perform { try $0.upgradeGear(g, captain: id, config: config) } }
    func equipGear(_ g: GearType, _ id: UUID) { perform { try $0.equipGear(g, captain: id) } }
    func rush(_ id: UUID) { perform { try $0.rushTrip(captain: id, config: config, now: Date()) } }
    func keep(_ index: Int) { perform { try $0.keepCatch(at: index, config: config, now: Date()) } }
    func release(_ id: UUID) { perform { try $0.releaseFish(id) } }
    func upgradeTank() { perform { try $0.upgradeTank(config: config) } }

    /// 唯一的付费开关（下一轮由 StoreKit 2 的交易结果驱动）
    var isFullVersion: Bool { state.isFullVersion }

    /// 「解锁完整版」：StoreKit 2 购买；成功后由 StoreManager 回调授予 isFullVersion
    func purchaseFullVersion() {
        Task {
            let ok = await storeManager.purchase()
            if ok { AudioManager.shared.play(.catchFish); AudioManager.shared.notify(.success) }
            else if !state.isFullVersion { toast = "购买未完成" }
        }
    }

    func restorePurchases() {
        Task {
            let ok = await storeManager.restore()
            toast = ok ? "已恢复购买" : "没有找到可恢复的购买"
        }
    }

    func collectOffline() {
        offlineReport = nil
        AudioManager.shared.play(.catchFish)
        AudioManager.shared.notify(.success)
    }

    var season: Season { state.season(at: Date(), config: config) }
    func fish(_ id: String) -> FishType? { GameState.fish(id, config: config) }
    func area(of fishID: String) -> SeaArea? { config.areas.first { $0.fish.contains { $0.id == fishID } } }

    func resetGame() {
        state = GameState(config: config)
        save()
    }
}
