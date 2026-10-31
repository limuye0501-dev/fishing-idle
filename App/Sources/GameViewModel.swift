import Foundation
import Combine
import FishingCore

/// UI 与纯逻辑层之间的桥：驱动时钟、存档、离线收益
@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var state: GameState
    @Published var offlineReport: (seconds: Double, coins: Int)?
    @Published var toast: String?

    let config = EconomyConfig()
    private let store = SaveStore.defaultStore()
    private var timer: AnyCancellable?
    private var ticksSinceSave = 0

    init() {
        state = SaveStore.defaultStore().load() ?? GameState(config: EconomyConfig())
    }

    func resume() {
        let r = state.applyElapsed(now: Date(), config: config)
        if r.seconds > 60, r.coins > 0 { offlineReport = r }
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
