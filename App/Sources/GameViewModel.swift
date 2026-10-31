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
    /// 面板当前分页：0 船长 1 海域 2 图鉴 3 日志
    @Published var panelTab = 0
    /// 最近一条海上事件提示（自动消失）
    @Published var eventBanner: String?
    private var seenEventCounter = 0

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
        #endif
        seenEventCounter = state.eventCounter
    }

    #if DEBUG
    static func demoState(config: EconomyConfig) -> GameState {
        let start = Date().addingTimeInterval(-3 * 3600)
        var s = GameState(config: config, now: start)
        s.coins = 100_000
        try? s.unlockArea("reef", config: config)
        try? s.hireCaptain(config: config)
        try? s.hireCaptain(config: config)
        s.applyElapsed(now: Date(), config: config)
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
        catch { toast = "操作失败" }
    }

    func upgradeSpeed(_ id: UUID) { perform { try $0.upgradeSpeed(captain: id, config: config) } }
    func upgradeCapacity(_ id: UUID) { perform { try $0.upgradeCapacity(captain: id, config: config) } }
    func hire() { perform { try $0.hireCaptain(config: config) } }
    func unlock(_ areaID: String) { perform { try $0.unlockArea(areaID, config: config) } }
    func assign(_ id: UUID, to areaID: String) { perform { try $0.assign(captain: id, to: areaID, config: config) } }

    func resetGame() {
        state = GameState(config: config)
        save()
    }
}
