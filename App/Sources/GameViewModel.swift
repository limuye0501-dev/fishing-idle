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
    }

    #if DEBUG
    static func demoState(config: EconomyConfig) -> GameState {
        let start = Date().addingTimeInterval(-3 * 3600)
        var s = GameState(config: config, now: start)
        s.coins = 100_000
        s.gems = 40
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
        // 留几条鱼进鱼缸
        var kept = Set<String>()
        for i in s.recentCatches.indices {
            if let f = s.recentCatches[i].fishID, !kept.contains(f) {
                if (try? s.keepCatch(at: i, config: config, now: Date())) != nil { kept.insert(f) }
            }
        }
        return s
    }
    #endif

    func resume() {
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
        ticksSinceSave += 1
        if ticksSinceSave >= 50 { ticksSinceSave = 0; save() }   // 每 5 秒存档
    }

    private func save() { try? store.save(state) }

    private func perform(_ action: (inout GameState) throws -> Void) {
        do { try action(&state); save() }
        catch GameError.notEnoughCoins { toast = "金币不足" }
        catch GameError.maxCaptains { toast = "船长已满员" }
        catch GameError.areaLocked { toast = "海域未解锁" }
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

    var season: Season { Season.at(Date(), seasonSeconds: config.seasonSeconds) }
    func fish(_ id: String) -> FishType? { GameState.fish(id, config: config) }
    func area(of fishID: String) -> SeaArea? { config.areas.first { $0.fish.contains { $0.id == fishID } } }

    func resetGame() {
        state = GameState(config: config)
        save()
    }
}
