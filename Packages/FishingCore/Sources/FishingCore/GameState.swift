import Foundation

public enum GameError: Error, Equatable {
    case notEnoughCoins, maxCaptains, unknownArea, areaLocked, alreadyUnlocked, unknownCaptain
}

/// 纯逻辑游戏状态（无 UI 依赖，可在 Linux 上测试）
public struct GameState: Codable, Sendable {
    public var coins: Int
    public var gems: Int
    public var captains: [Captain]
    public var unlockedAreaIDs: [String]
    public var lastUpdate: Date
    public var totalFishCaught: Int
    /// 确定性随机数种子（保证可测试、可存档）
    public var rngState: UInt64
    public var recentCatches: [CatchRecord]
    /// 鱼图鉴：鱼种 id → 条目
    public var codex: [String: CodexEntry]
    /// 已领取图鉴集齐奖励的海域
    public var completedAreaIDs: [String]
    /// 海上事件 / 升级 / 图鉴日志（新的在前）
    public var eventLog: [EventRecord]
    /// 单调递增的日志序号（UI 用来判断是否有新事件弹提示）
    public var eventCounter: Int
    /// 生态鱼缸
    public var tank: [TankFish]
    public var tankLevel: Int
    /// 鱼缸门票收入的小数累积
    public var tankIncomeCarry: Double

    public init(config: EconomyConfig = EconomyConfig(), now: Date = Date()) {
        coins = config.startingCoins
        gems = 0
        let first = config.areas[0].id
        captains = [Captain(name: config.captainNames[0], areaID: first, trait: .homebody)]
        unlockedAreaIDs = [first]
        lastUpdate = now
        totalFishCaught = 0
        rngState = 0x9E3779B97F4A7C15
        recentCatches = []
        codex = [:]
        completedAreaIDs = []
        eventLog = []
        eventCounter = 0
        tank = []
        tankLevel = 0
        tankIncomeCarry = 0
    }

    enum CodingKeys: String, CodingKey {
        case coins, gems, captains, unlockedAreaIDs, lastUpdate, totalFishCaught, rngState, recentCatches
        case codex, completedAreaIDs, eventLog, eventCounter, tank, tankLevel, tankIncomeCarry
    }

    /// 兼容旧存档：新字段缺失时取默认值
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coins = try c.decode(Int.self, forKey: .coins)
        gems = try c.decodeIfPresent(Int.self, forKey: .gems) ?? 0
        captains = try c.decode([Captain].self, forKey: .captains)
        unlockedAreaIDs = try c.decode([String].self, forKey: .unlockedAreaIDs)
        lastUpdate = try c.decode(Date.self, forKey: .lastUpdate)
        totalFishCaught = try c.decodeIfPresent(Int.self, forKey: .totalFishCaught) ?? 0
        rngState = try c.decodeIfPresent(UInt64.self, forKey: .rngState) ?? 0x9E3779B97F4A7C15
        recentCatches = try c.decodeIfPresent([CatchRecord].self, forKey: .recentCatches) ?? []
        codex = try c.decodeIfPresent([String: CodexEntry].self, forKey: .codex) ?? [:]
        completedAreaIDs = try c.decodeIfPresent([String].self, forKey: .completedAreaIDs) ?? []
        eventLog = try c.decodeIfPresent([EventRecord].self, forKey: .eventLog) ?? []
        eventCounter = try c.decodeIfPresent(Int.self, forKey: .eventCounter) ?? 0
        tank = try c.decodeIfPresent([TankFish].self, forKey: .tank) ?? []
        tankLevel = try c.decodeIfPresent(Int.self, forKey: .tankLevel) ?? 0
        tankIncomeCarry = try c.decodeIfPresent(Double.self, forKey: .tankIncomeCarry) ?? 0
    }

    // MARK: - 数值计算

    public static func speed(_ c: Captain, _ config: EconomyConfig) -> Double {
        c.boat.speed(config) * (1 + config.levelSpeedBonus * Double(c.level - 1))
    }

    /// 本趟实际捕获条数（含鱼群、风暴加成）
    public static func catchCount(_ c: Captain, _ config: EconomyConfig) -> Int {
        let g = c.boat.equipped
        var n = Double(c.boat.capacity(config)) * config.gearCatchMultiplier(g)
            * (1 + config.gearLevelBonus * Double(max(1, c.boat.gearLevel(g)) - 1))
        switch c.tripEvent {
        case .fishSchool: n *= config.fishSchoolMultiplier
        case .storm: n += Double(config.stormBonusFish + (c.trait == .stormRider ? 3 : 0))
        default: break
        }
        return Int(n.rounded())
    }

    /// 某船长当前阶段总时长
    public static func phaseDuration(_ c: Captain, _ phase: TripPhase, _ config: EconomyConfig) -> Double {
        guard let area = config.area(c.areaID) else { return 1 }
        switch phase {
        case .sailingOut, .returning: return area.distance / speed(c, config)
        case .fishing:
            var t = area.secondsPerFish * Double(c.boat.capacity(config))
            if c.trait == .quickHands { t *= 0.75 }
            if c.tripEvent == .storm && c.trait != .stormRider { t *= config.stormTimeMultiplier }
            return t
        case .unloading: return config.unloadSeconds
        }
    }

    public static func tripDuration(_ c: Captain, _ config: EconomyConfig) -> Double {
        [TripPhase.sailingOut, .fishing, .returning, .unloading]
            .reduce(0) { $0 + phaseDuration(c, $1, config) }
    }

    /// 综合收益倍率：等级、特性、图鉴集齐加成
    public func valueMultiplier(_ c: Captain, config: EconomyConfig, season: Season? = nil) -> Double {
        var m = 1 + config.levelValueBonus * Double(c.level - 1)
        if season == .autumn { m *= 1 + config.autumnValueBonus }
        let areaIndex = config.areas.firstIndex { $0.id == c.areaID } ?? 0
        if c.trait == .veteran && areaIndex >= 2 { m *= 1.3 }
        if c.trait == .homebody { m *= 1 + min(0.4, 0.02 * Double(c.streak)) }
        if completedAreaIDs.contains(c.areaID) { m *= 1 + config.codexAreaBonus }
        return m
    }

    // MARK: - 时间推进

    /// 推进 dt 秒，返回期间赚的金币。离线时同样逐趟模拟（确定性随机），保证事件、季节和图鉴一致。
    /// now 为这段时间的结束时刻（默认 lastUpdate），用于判断每个事件发生时的季节。
    @discardableResult
    public mutating func advance(by dt: Double, config: EconomyConfig, now: Date? = nil) -> Int {
        guard dt > 0 else { return 0 }
        let start = (now ?? lastUpdate).addingTimeInterval(-dt)
        var earned = 0
        for i in captains.indices {
            var remaining = dt
            while remaining > 0 {
                let dur = Self.phaseDuration(captains[i], captains[i].phase, config)
                let left = dur - captains[i].phaseElapsed
                if remaining < left {
                    captains[i].phaseElapsed += remaining
                    break
                }
                remaining -= left
                earned += completePhase(i, config: config, date: start.addingTimeInterval(dt - remaining))
            }
        }
        earned += tankIncome(seconds: dt, config: config)
        coins += earned
        return earned
    }

    /// 结束当前阶段并进入下一阶段，返回卸货收入
    private mutating func completePhase(_ i: Int, config: EconomyConfig, date: Date) -> Int {
        captains[i].phaseElapsed = 0
        switch captains[i].phase {
        case .sailingOut:
            rollEvent(i, config: config, date: date)
            captains[i].phase = .fishing
        case .fishing: captains[i].phase = .returning
        case .returning: captains[i].phase = .unloading
        case .unloading:
            captains[i].phase = .sailingOut
            return finishTrip(i, config: config, date: date)
        }
        return 0
    }

    public func season(at date: Date, config: EconomyConfig) -> Season {
        Season.at(date, seasonSeconds: config.seasonSeconds)
    }

    /// 到达渔场时抽取海上事件
    private mutating func rollEvent(_ i: Int, config: EconomyConfig, date: Date) {
        let r = nextRandom()
        let se = season(at: date, config: config)
        let luck = captains[i].trait == .lucky ? 2.0 : 1.0
        let t = config.treasureChance * luck * (se == .spring ? config.springTreasureMultiplier : 1)
        let school = config.fishSchoolChance * (se == .summer ? config.summerSchoolMultiplier : 1)
        let storm = config.stormChance * (se == .winter ? config.winterStormMultiplier : 1)
        let ev: SeaEvent?
        if r < t { ev = .treasure }
        else if r < t + school { ev = .fishSchool }
        else if r < t + school + storm { ev = .storm }
        else { ev = nil }
        captains[i].tripEvent = ev
        if let ev {
            let extra: String
            switch ev {
            case .fishSchool: extra = "渔获 ×\(config.fishSchoolMultiplier)"
            case .storm: extra = captains[i].trait == .stormRider ? "弄潮儿毫不在意，多钓几条" : "被困海上，回港推迟"
            case .treasure: extra = "回港后开箱"
            }
            log("\(ev.emoji) \(captains[i].name) \(ev.name)：\(extra)", date)
        }
    }

    /// 卸货：逐条抽鱼、记图鉴、出售、结算经验和宝箱
    private mutating func finishTrip(_ i: Int, config: EconomyConfig, date: Date) -> Int {
        guard let area = config.area(captains[i].areaID) else { return 0 }
        let c = captains[i]
        let se = season(at: date, config: config)
        let pool = area.candidates(gear: c.boat.equipped, season: se)
        let count = pool.isEmpty ? 0 : Self.catchCount(c, config)
        let boost = c.trait == .lucky ? 2.0 : 1.0
        var raw = 0
        var best: FishType?
        var bestKg = 0.0
        for _ in 0..<count {
            guard let f = SeaArea.pick(from: pool, roll: nextRandom(), rareBoost: boost) else { continue }
            raw += f.value
            let kg = f.baseKg * (0.6 + 1.2 * nextRandom())
            if best == nil || f.value > best!.value { best = f; bestKg = kg }
            recordCodex(f, kg: kg, date: date)
        }
        let mult = valueMultiplier(c, config: config, season: se)
        var total = Int((Double(raw) * mult).rounded())
        if pool.isEmpty && c.tripEvent != .treasure {
            log("🫙 \(c.name) 在\(area.name)用\(c.boat.equipped.name)\(se.name)季钓不到鱼，空手而归", date)
        }

        if c.tripEvent == .treasure {
            let chestCoins = Int((area.averageFishValue * Double(c.boat.capacity(config)) * 2).rounded()) + 10
            let chestGems = 1 + (c.trait == .lucky ? Int(nextRandom() * 2) : 0) + max(0, config.treasureGemsMax - 1)
            total += chestCoins
            gems += chestGems
            log("🎁 \(c.name) 打开宝箱：+\(chestCoins) 金币，+\(chestGems) 💎", date)
        }

        captains[i].tripsCompleted += 1
        captains[i].streak += 1
        captains[i].tripEvent = nil
        totalFishCaught += count
        gainXP(i, config.xpPerTripBase + config.xpPerAreaIndex * (config.areas.firstIndex { $0.id == area.id } ?? 0), date: date, config: config)
        if let best {
            var rec = CatchRecord(captainName: c.name, fishName: best.name,
                                  fishEmoji: best.emoji, count: count, coins: total)
            rec.fishID = best.id
            rec.kg = bestKg
            rec.sellValue = Int((Double(best.value) * mult).rounded())
            rec.kept = false
            recentCatches.insert(rec, at: 0)
            if recentCatches.count > 10 { recentCatches.removeLast(recentCatches.count - 10) }
        }
        total += checkCodexCompletion(area, config: config, date: date)
        return total
    }

    private mutating func recordCodex(_ f: FishType, kg: Double, date: Date) {
        if var e = codex[f.id] {
            e.count += 1
            e.bestKg = max(e.bestKg, kg)
            codex[f.id] = e
        } else {
            codex[f.id] = CodexEntry(count: 1, bestKg: kg, firstCaught: date)
            log("📖 新图鉴：\(f.emoji)\(f.name)", date)
        }
    }

    /// 集齐某海域全部鱼种时发放一次奖励
    private mutating func checkCodexCompletion(_ area: SeaArea, config: EconomyConfig, date: Date) -> Int {
        guard !completedAreaIDs.contains(area.id),
              area.fish.allSatisfy({ codex[$0.id] != nil }) else { return 0 }
        completedAreaIDs.append(area.id)
        let reward = config.codexReward(for: area)
        log("🏆 集齐「\(area.name)」图鉴！+\(reward) 金币，该海域收益永久 +\(Int(config.codexAreaBonus * 100))%", date)
        return reward
    }

    private mutating func gainXP(_ i: Int, _ amount: Int, date: Date, config: EconomyConfig) {
        captains[i].xp += amount
        while captains[i].xp >= captains[i].xpToNext(config) {
            captains[i].xp -= captains[i].xpToNext(config)
            captains[i].level += 1
            log("⭐️ \(captains[i].name) 升到 Lv\(captains[i].level)", date)
        }
    }

    private mutating func log(_ text: String, _ date: Date) {
        eventCounter += 1
        eventLog.insert(EventRecord(date: date, text: text), at: 0)
        if eventLog.count > 30 { eventLog.removeLast(eventLog.count - 30) }
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
        return (secs, advance(by: secs, config: config, now: now))
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
        let traits = Trait.allCases
        let trait = traits[min(traits.count - 1, Int(nextRandom() * Double(traits.count)))]
        captains.append(Captain(name: name, areaID: unlockedAreaIDs.last ?? config.areas[0].id, trait: trait))
        log("🧑‍✈️ 新船长 \(name) 入伙（\(trait.name)）", lastUpdate)
    }

    public mutating func unlockArea(_ areaID: String, config: EconomyConfig) throws {
        guard let area = config.area(areaID) else { throw GameError.unknownArea }
        guard !unlockedAreaIDs.contains(areaID) else { throw GameError.alreadyUnlocked }
        try spend(area.unlockCost)
        unlockedAreaIDs.append(areaID)
    }

    /// 切换海域：保持当前阶段完成比例；“不想回家”的连续出海计数清零
    public mutating func assign(captain id: UUID, to areaID: String, config: EconomyConfig) throws {
        let i = try index(of: id)
        guard config.area(areaID) != nil else { throw GameError.unknownArea }
        guard unlockedAreaIDs.contains(areaID) else { throw GameError.areaLocked }
        guard captains[i].areaID != areaID else { return }
        rescalePhase(i, config: config) { $0.areaID = areaID; $0.streak = 0 }
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

    // MARK: - 渔具

    public enum GearError: Error, Equatable { case alreadyOwned, notOwned, maxLevel, notEnoughGems }

    public mutating func buyGear(_ g: GearType, captain id: UUID, config: EconomyConfig) throws {
        let i = try index(of: id)
        guard !captains[i].boat.owns(g) else { throw GearError.alreadyOwned }
        let price = config.gearPrice(g)
        guard coins >= price.coins else { throw GameError.notEnoughCoins }
        guard gems >= price.gems else { throw GearError.notEnoughGems }
        coins -= price.coins
        gems -= price.gems
        captains[i].boat.gearLevels[g.rawValue] = 1
        log("\(g.emoji) \(captains[i].name) 的船添置了\(g.name)", lastUpdate)
    }

    public mutating func upgradeGear(_ g: GearType, captain id: UUID, config: EconomyConfig) throws {
        let i = try index(of: id)
        let lv = captains[i].boat.gearLevel(g)
        guard lv > 0 else { throw GearError.notOwned }
        guard lv < config.maxGearLevel else { throw GearError.maxLevel }
        try spend(config.gearUpgradeCost(g, level: lv))
        captains[i].boat.gearLevels[g.rawValue] = lv + 1
    }

    /// 更换渔具：从下一趟卸货结算开始生效
    public mutating func equipGear(_ g: GearType, captain id: UUID) throws {
        let i = try index(of: id)
        guard captains[i].boat.owns(g) else { throw GearError.notOwned }
        captains[i].boat.equipped = g
    }

    // MARK: - 宝石：加速

    /// 花宝石让船长立刻完成本趟（直接卸货结算），返回本趟收入
    @discardableResult
    public mutating func rushTrip(captain id: UUID, config: EconomyConfig, now: Date) throws -> Int {
        let i = try index(of: id)
        guard gems >= config.rushGemCost else { throw GearError.notEnoughGems }
        gems -= config.rushGemCost
        let trips = captains[i].tripsCompleted
        var earned = 0
        while captains[i].tripsCompleted == trips {
            earned += completePhase(i, config: config, date: now)
        }
        coins += earned
        return earned
    }

    // MARK: - 生态鱼缸

    public enum TankError: Error, Equatable { case full, nothingToKeep, alreadyKept, notFound }

    public func tankCapacity(config: EconomyConfig) -> Int {
        config.tankBaseCapacity + config.tankCapacityPerLevel * tankLevel
    }

    /// 鱼缸中不同物种
    public var tankSpecies: Set<String> { Set(tank.map(\.fishID)) }

    /// 游客门票：每秒收入（物种越多越赚，同种重复不加成）
    public func tankIncomePerSecond(config: EconomyConfig) -> Double {
        let values = Dictionary(uniqueKeysWithValues: config.areas.flatMap(\.fish).map { ($0.id, $0.value) })
        return tankSpecies.reduce(0) { $0 + Double(values[$1] ?? 0) } * config.tankIncomePerValuePerSecond
    }

    private mutating func tankIncome(seconds: Double, config: EconomyConfig) -> Int {
        guard !tank.isEmpty else { return 0 }
        tankIncomeCarry += tankIncomePerSecond(config: config) * seconds
        let whole = Int(tankIncomeCarry)
        tankIncomeCarry -= Double(whole)
        return whole
    }

    /// 留下某次渔获里最好的那条鱼：退还已卖出的钱（从金币扣除）并放进鱼缸
    public mutating func keepCatch(at index: Int, config: EconomyConfig, now: Date) throws {
        guard recentCatches.indices.contains(index), let fid = recentCatches[index].fishID,
              let kg = recentCatches[index].kg else { throw TankError.nothingToKeep }
        guard recentCatches[index].kept != true else { throw TankError.alreadyKept }
        guard tank.count < tankCapacity(config: config) else { throw TankError.full }
        let refund = recentCatches[index].sellValue ?? 0
        try spend(refund)
        recentCatches[index].kept = true
        tank.append(TankFish(id: UUID(), fishID: fid, kg: kg, caughtAt: now))
        log("🐠 \(recentCatches[index].fishEmoji)\(recentCatches[index].fishName) 被放进了生态鱼缸", now)
    }

    public mutating func releaseFish(_ id: UUID) throws {
        guard let i = tank.firstIndex(where: { $0.id == id }) else { throw TankError.notFound }
        tank.remove(at: i)
    }

    public mutating func upgradeTank(config: EconomyConfig) throws {
        try spend(config.tankUpgradeCost(level: tankLevel))
        tankLevel += 1
    }

    /// 查找鱼种
    public static func fish(_ id: String, config: EconomyConfig) -> FishType? {
        config.areas.lazy.flatMap(\.fish).first { $0.id == id }
    }

    /// 某海域图鉴进度
    public func codexProgress(_ area: SeaArea) -> (caught: Int, total: Int) {
        (area.fish.filter { codex[$0.id] != nil }.count, area.fish.count)
    }
}
