import Foundation

public enum GameError: Error, Equatable {
    case notEnoughCoins, maxCaptains, unknownArea, areaLocked, alreadyUnlocked, unknownCaptain
}

/// 纯逻辑游戏状态（无 UI 依赖，可在 Linux 上测试）
public struct GameState: Codable, Sendable {
    public var coins: Int
    public var captains: [Captain]
    public var unlockedAreaIDs: [String]
    public var lastUpdate: Date
    public var totalFishCaught: Int
    /// 确定性随机数种子（保证可测试、可存档）
    public var rngState: UInt64
    public var recentCatches: [CatchRecord]

    public init(config: EconomyConfig = EconomyConfig(), now: Date = Date()) {
        coins = config.startingCoins
        let first = config.areas[0].id
        captains = [Captain(name: config.captainNames[0], areaID: first)]
        unlockedAreaIDs = [first]
        lastUpdate = now
        totalFishCaught = 0
        rngState = 0x9E3779B97F4A7C15
        recentCatches = []
    }

    // MARK: - 时间推进

    /// 某船长当前阶段总时长
    public static func phaseDuration(_ c: Captain, _ phase: TripPhase, _ config: EconomyConfig) -> Double {
        guard let area = config.area(c.areaID) else { return 1 }
        switch phase {
        case .sailingOut, .returning: return area.distance / c.boat.speed(config)
        case .fishing: return area.secondsPerFish * Double(c.boat.capacity(config))
        case .unloading: return config.unloadSeconds
        }
    }

    public static func tripDuration(_ c: Captain, _ config: EconomyConfig) -> Double {
        [TripPhase.sailingOut, .fishing, .returning, .unloading]
            .reduce(0) { $0 + phaseDuration(c, $1, config) }
    }

    /// 推进 dt 秒，返回期间赚的金币
    @discardableResult
    public mutating func advance(by dt: Double, config: EconomyConfig) -> Int {
        guard dt > 0 else { return 0 }
        var earned = 0
        for i in captains.indices {
            var remaining = dt
            // 长时间（离线）先按整趟批量结算，避免大量循环
            let trip = Self.tripDuration(captains[i], config)
            if remaining > trip * 3, trip > 0 {
                // 先走完当前这趟
                remaining = stepCaptain(i, remaining: remaining, config: config, earned: &earned, singleTrip: true)
                let fullTrips = Int(remaining / trip)
                if fullTrips > 0 {
                    earned += bulkTrips(i, count: fullTrips, config: config)
                    remaining -= Double(fullTrips) * trip
                }
            }
            _ = stepCaptain(i, remaining: remaining, config: config, earned: &earned, singleTrip: false)
        }
        coins += earned
        return earned
    }

    /// 逐阶段推进；singleTrip 时在完成一次卸货后停下，返回剩余时间
    private mutating func stepCaptain(_ i: Int, remaining: Double, config: EconomyConfig,
                                      earned: inout Int, singleTrip: Bool) -> Double {
        var remaining = remaining
        while remaining > 0 {
            let dur = Self.phaseDuration(captains[i], captains[i].phase, config)
            let left = dur - captains[i].phaseElapsed
            if remaining < left {
                captains[i].phaseElapsed += remaining
                return 0
            }
            remaining -= left
            captains[i].phaseElapsed = 0
            switch captains[i].phase {
            case .sailingOut: captains[i].phase = .fishing
            case .fishing: captains[i].phase = .returning
            case .returning: captains[i].phase = .unloading
            case .unloading:
                earned += sellCatch(i, config: config)
                captains[i].phase = .sailingOut
                if singleTrip { return remaining }
            }
        }
        return remaining
    }

    /// 卸货：按鱼舱容量逐条抽鱼并出售
    private mutating func sellCatch(_ i: Int, config: EconomyConfig) -> Int {
        guard let area = config.area(captains[i].areaID) else { return 0 }
        let cap = captains[i].boat.capacity(config)
        var total = 0
        var best: FishType?
        for _ in 0..<cap {
            if let f = area.pickFish(roll: nextRandom()) {
                total += f.value
                if best == nil || f.value > best!.value { best = f }
            }
        }
        captains[i].tripsCompleted += 1
        totalFishCaught += cap
        if let best {
            recentCatches.insert(CatchRecord(captainName: captains[i].name, fishName: best.name,
                                             fishEmoji: best.emoji, count: cap, coins: total), at: 0)
            if recentCatches.count > 10 { recentCatches.removeLast(recentCatches.count - 10) }
        }
        return total
    }

    /// 离线批量结算：按期望值计算
    private mutating func bulkTrips(_ i: Int, count: Int, config: EconomyConfig) -> Int {
        guard let area = config.area(captains[i].areaID) else { return 0 }
        let cap = captains[i].boat.capacity(config)
        captains[i].tripsCompleted += count
        totalFishCaught += cap * count
        return Int((area.averageFishValue * Double(cap * count)).rounded())
    }

    /// SplitMix64 → [0,1)
    private mutating func nextRandom() -> Double {
        rngState &+= 0x9E3779B97F4A7C15
        var z = rngState
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }

    // MARK: - 离线收益

    /// 应用从 lastUpdate 到 now 的进度（上限 maxOfflineSeconds），返回 (秒数, 金币)
    @discardableResult
    public mutating func applyElapsed(now: Date, config: EconomyConfig) -> (seconds: Double, coins: Int) {
        let raw = now.timeIntervalSince(lastUpdate)
        lastUpdate = now
        guard raw > 0 else { return (0, 0) }
        let secs = min(raw, config.maxOfflineSeconds)
        return (secs, advance(by: secs, config: config))
    }

    // MARK: - 操作

    private mutating func spend(_ cost: Int) throws {
        guard coins >= cost else { throw GameError.notEnoughCoins }
        coins -= cost
    }

    private func index(of id: UUID) throws -> Int {
        guard let i = captains.firstIndex(where: { $0.id == id }) else { throw GameError.unknownCaptain }
        return i
    }

    public mutating func upgradeSpeed(captain id: UUID, config: EconomyConfig) throws {
        let i = try index(of: id)
        try spend(config.speedUpgradeCost(level: captains[i].boat.speedLevel))
        rescalePhase(i, config: config) { $0.boat.speedLevel += 1 }
    }

    public mutating func upgradeCapacity(captain id: UUID, config: EconomyConfig) throws {
        let i = try index(of: id)
        try spend(config.capacityUpgradeCost(level: captains[i].boat.capacityLevel))
        rescalePhase(i, config: config) { $0.boat.capacityLevel += 1 }
    }

    public func nextHireCost(config: EconomyConfig) -> Int? {
        captains.count >= config.maxCaptains ? nil : config.hireCost(existing: captains.count)
    }

    public mutating func hireCaptain(config: EconomyConfig) throws {
        guard let cost = nextHireCost(config: config) else { throw GameError.maxCaptains }
        try spend(cost)
        let name = config.captainNames[captains.count % config.captainNames.count]
        captains.append(Captain(name: name, areaID: unlockedAreaIDs.last ?? config.areas[0].id))
    }

    public mutating func unlockArea(_ areaID: String, config: EconomyConfig) throws {
        guard let area = config.area(areaID) else { throw GameError.unknownArea }
        guard !unlockedAreaIDs.contains(areaID) else { throw GameError.alreadyUnlocked }
        try spend(area.unlockCost)
        unlockedAreaIDs.append(areaID)
    }

    /// 切换海域：从下一趟出海开始生效（若正在出港则立即切换并保持进度比例）
    public mutating func assign(captain id: UUID, to areaID: String, config: EconomyConfig) throws {
        let i = try index(of: id)
        guard config.area(areaID) != nil else { throw GameError.unknownArea }
        guard unlockedAreaIDs.contains(areaID) else { throw GameError.areaLocked }
        rescalePhase(i, config: config) { $0.areaID = areaID }
    }

    /// 修改船长属性时，保持当前阶段完成比例不变，避免动画跳变
    private mutating func rescalePhase(_ i: Int, config: EconomyConfig, _ change: (inout Captain) -> Void) {
        let old = Self.phaseDuration(captains[i], captains[i].phase, config)
        let p = old > 0 ? captains[i].phaseElapsed / old : 0
        change(&captains[i])
        captains[i].phaseElapsed = p * Self.phaseDuration(captains[i], captains[i].phase, config)
    }

    /// 0...1 当前阶段进度（供动画使用）
    public func phaseProgress(_ c: Captain, config: EconomyConfig) -> Double {
        let d = Self.phaseDuration(c, c.phase, config)
        return d > 0 ? min(1, c.phaseElapsed / d) : 0
    }
}
