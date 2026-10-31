import Foundation

/// 季节：游戏内一季 = 现实 1 天（可在 EconomyConfig.seasonSeconds 调整），春→夏→秋→冬循环
public enum Season: Int, Codable, CaseIterable, Sendable {
    case spring, summer, autumn, winter
    public var name: String { CoreLang.english ? ["Spring", "Summer", "Autumn", "Winter"][rawValue] : ["春", "夏", "秋", "冬"][rawValue] }
    public var emoji: String { ["🌸", "☀️", "🍁", "❄️"][rawValue] }

    /// 以 UTC 纪元起的整“季长”计数，保证离线与在线一致
    public static func at(_ date: Date, seasonSeconds: Double) -> Season {
        let n = Int(floor(date.timeIntervalSince1970 / seasonSeconds))
        return Season(rawValue: ((n % 4) + 4) % 4)!
    }
    /// 距离下一季还有多少秒
    public static func secondsUntilNext(_ date: Date, seasonSeconds: Double) -> Double {
        let t = date.timeIntervalSince1970
        return seasonSeconds - t.truncatingRemainder(dividingBy: seasonSeconds)
    }
}

/// 渔具
public enum GearType: String, Codable, CaseIterable, Sendable {
    case rod, trap, longline, trawl, deepNet
    public var name: String {
        switch self {
        case .rod: return tr("鱼竿", "Rod")
        case .trap: return tr("笼捕", "Trap")
        case .longline: return tr("延绳钓", "Longline")
        case .trawl: return tr("拖网", "Trawl")
        case .deepNet: return tr("深海网", "Deep-sea Net")
        }
    }
    public var emoji: String {
        switch self {
        case .rod: return "🎣"
        case .trap: return "🪤"
        case .longline: return "🪝"
        case .trawl: return "🕸️"
        case .deepNet: return "🌊"
        }
    }
    public var detail: String {
        switch self {
        case .rod: return tr("万能入门渔具，什么都能钓一点", "A starter all-rounder that catches a little of everything")
        case .trap: return tr("专抓蟹、虾、贝类等底栖生物", "Made for crabs, prawns, shellfish and other bottom dwellers")
        case .longline: return tr("一根主线挂上百个钩，钓大型洄游鱼", "Hundreds of hooks on one main line, for big migratory fish")
        case .trawl: return tr("大网拖过，成群小鱼一网打尽（渔获多）", "Sweeps up whole schools of small fish (bigger hauls)")
        case .deepNet: return tr("稀有渔具，可抵达深海与传说海域", "Rare gear that reaches the deep and legendary seas")
        }
    }
}

/// 稀有度（由出现权重推导）
public enum Rarity: Int, Codable, Comparable, Sendable {
    case common, rare, epic, legendary
    public var name: String { CoreLang.english ? ["Common", "Rare", "Epic", "Legendary"][rawValue] : ["普通", "稀有", "史诗", "传说"][rawValue] }
    public static func < (a: Rarity, b: Rarity) -> Bool { a.rawValue < b.rawValue }
}

/// 鱼的种类（全部为真实物种）
public struct FishType: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    /// 中文名（存储）；`name` 为当前语言的显示名
    public let zhName: String
    public var name: String { CoreLang.english ? (CoreEN.fish[id] ?? CoreEN.extraFish[id] ?? zhName) : zhName }
    public let emoji: String
    public let value: Int
    /// 相对出现权重
    public let weight: Double
    /// 标准体重（公斤），实际体重在 0.6~1.8 倍之间浮动
    public let baseKg: Double
    /// 能捕获它的渔具
    public let gears: [GearType]
    /// 出没季节；空数组表示四季皆有
    public let seasons: [Season]

    public init(id: String, name: String, emoji: String, value: Int, weight: Double, baseKg: Double = 1,
                gears: [GearType] = GearType.allCases, seasons: [Season] = []) {
        self.id = id; self.zhName = name; self.emoji = emoji; self.value = value; self.weight = weight
        self.baseKg = baseKg; self.gears = gears; self.seasons = seasons
    }

    enum CodingKeys: String, CodingKey { case id, zhName = "name", emoji, value, weight, baseKg, gears, seasons }

    public var rarity: Rarity {
        weight >= 3 ? .common : weight >= 1.5 ? .rare : weight >= 0.8 ? .epic : .legendary
    }
    public func available(in season: Season) -> Bool { seasons.isEmpty || seasons.contains(season) }
    public func catchable(with gear: GearType, in season: Season) -> Bool { gears.contains(gear) && available(in: season) }
}

/// 海域
public struct SeaArea: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let zhName: String
    public var name: String { CoreLang.english ? (CoreEN.area[id] ?? zhName) : zhName }
    /// 距离（海里），决定航行时间
    public let distance: Double
    /// 每条鱼的捕获耗时（秒）
    public let secondsPerFish: Double
    public let unlockCost: Int
    public let fish: [FishType]
    /// 海域地图坐标（0~1，港口在 (0.5, 0.92)）
    public let mapX: Double
    public let mapY: Double
    public let zhBlurb: String
    public var blurb: String { CoreLang.english ? (CoreEN.blurb[id] ?? zhBlurb) : zhBlurb }

    public init(id: String, name: String, distance: Double, secondsPerFish: Double, unlockCost: Int,
                fish: [FishType], mapX: Double = 0.5, mapY: Double = 0.5, blurb: String = "") {
        self.id = id; self.zhName = name; self.distance = distance
        self.secondsPerFish = secondsPerFish; self.unlockCost = unlockCost; self.fish = fish
        self.mapX = mapX; self.mapY = mapY; self.zhBlurb = blurb
    }

    enum CodingKeys: String, CodingKey { case id, zhName = "name", distance, secondsPerFish, unlockCost, fish, mapX, mapY, zhBlurb = "blurb" }

    /// 加权平均单条鱼价值（不考虑渔具/季节）
    public var averageFishValue: Double {
        let total = fish.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return 0 }
        return fish.reduce(0) { $0 + Double($1.value) * $1.weight } / total
    }

    /// 当前渔具与季节下可捕获的鱼
    public func candidates(gear: GearType, season: Season) -> [FishType] {
        fish.filter { $0.catchable(with: gear, in: season) }
    }

    /// 用 0..<1 的随机数在候选鱼中按权重选鱼；rareBoost 放大候选中最贵鱼的权重
    public static func pick(from fish: [FishType], roll: Double, rareBoost: Double = 1) -> FishType? {
        guard !fish.isEmpty else { return nil }
        let maxValue = fish.map(\.value).max() ?? 0
        func w(_ f: FishType) -> Double { f.value == maxValue ? f.weight * rareBoost : f.weight }
        let total = fish.reduce(0) { $0 + w($1) }
        var acc = 0.0
        let target = min(max(roll, 0), 0.999_999) * total
        for f in fish {
            acc += w(f)
            if target < acc { return f }
        }
        return fish.last
    }

    /// 兼容旧接口：不过滤渔具季节
    public func pickFish(roll: Double, rareBoost: Double = 1) -> FishType? {
        Self.pick(from: fish, roll: roll, rareBoost: rareBoost)
    }
}

/// 船只
public struct Boat: Codable, Hashable, Sendable {
    public var speedLevel: Int
    public var capacityLevel: Int
    /// 已拥有的渔具及等级（rawValue → 等级）
    public var gearLevels: [String: Int]
    public var equipped: GearType

    public init(speedLevel: Int = 1, capacityLevel: Int = 1) {
        self.speedLevel = speedLevel; self.capacityLevel = capacityLevel
        self.gearLevels = [GearType.rod.rawValue: 1]
        self.equipped = .rod
    }

    enum CodingKeys: String, CodingKey { case speedLevel, capacityLevel, gearLevels, equipped }

    /// 兼容旧存档：旧船默认带一根 1 级鱼竿
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        speedLevel = try c.decode(Int.self, forKey: .speedLevel)
        capacityLevel = try c.decode(Int.self, forKey: .capacityLevel)
        gearLevels = try c.decodeIfPresent([String: Int].self, forKey: .gearLevels) ?? [GearType.rod.rawValue: 1]
        equipped = try c.decodeIfPresent(GearType.self, forKey: .equipped) ?? .rod
    }

    public func gearLevel(_ g: GearType) -> Int { gearLevels[g.rawValue] ?? 0 }
    public func owns(_ g: GearType) -> Bool { gearLevel(g) > 0 }

    /// 航速（海里/秒）
    public func speed(_ c: EconomyConfig) -> Double {
        c.baseSpeed * pow(c.speedGrowth, Double(speedLevel - 1))
    }
    /// 鱼舱容量（条）
    public func capacity(_ c: EconomyConfig) -> Int {
        c.baseCapacity + c.capacityPerLevel * (capacityLevel - 1)
    }
}

public enum TripPhase: String, Codable, Sendable {
    case sailingOut, fishing, returning, unloading
}

/// 船长特性
public enum Trait: String, Codable, CaseIterable, Sendable {
    case veteran      // 远洋老手：远海（第 3 个海域起）收益 +30%
    case quickHands   // 快手：捕鱼时间 -25%
    case lucky        // 幸运：稀有鱼概率 ×2，宝箱概率 ×2
    case homebody     // 不想回家：连续出海越久越赚，每趟 +2%（上限 +40%），换海域清零
    case stormRider   // 弄潮儿：遇风暴不减速，反而多钓 3 条

    public var name: String {
        switch self {
        case .veteran: return tr("远洋老手", "Old Salt")
        case .quickHands: return tr("快手", "Quick Hands")
        case .lucky: return tr("幸运", "Lucky")
        case .homebody: return tr("不想回家", "Won't Come Home")
        case .stormRider: return tr("弄潮儿", "Storm Rider")
        }
    }
    public var detail: String {
        switch self {
        case .veteran: return tr("在深蓝远洋及更远海域收益 +30%", "+30% income in the Deep Blue and beyond")
        case .quickHands: return tr("捕鱼时间 -25%", "−25% fishing time")
        case .lucky: return tr("稀有鱼与宝箱概率翻倍", "Double chance of rare fish and treasure chests")
        case .homebody: return tr("连续出海越久越赚，每趟 +2%（最多 +40%）", "Earns more the longer the streak at sea: +2% per trip (up to +40%)")
        case .stormRider: return tr("风暴不耽误行程，还能多钓 3 条", "Storms cause no delay and bring 3 extra fish")
        }
    }
}

/// 海上随机事件
public enum SeaEvent: String, Codable, Sendable {
    case fishSchool   // 鱼群：本趟渔获 ×1.5
    case storm        // 风暴：捕鱼时间 +50%，但被困海上多钓 2 条
    case treasure     // 宝箱：金币 + 宝石

    public var name: String {
        switch self {
        case .fishSchool: return tr("遇到鱼群", "met a school of fish")
        case .storm: return tr("遭遇风暴", "ran into a storm")
        case .treasure: return tr("捞到宝箱", "hauled up a treasure chest")
        }
    }
    public var emoji: String {
        switch self {
        case .fishSchool: return "🐟🐟"
        case .storm: return "⛈️"
        case .treasure: return "🎁"
        }
    }
}

/// 船长
public struct Captain: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var boat: Boat
    public var areaID: String
    public var phase: TripPhase
    /// 当前阶段已经经过的秒数
    public var phaseElapsed: Double
    public var tripsCompleted: Int
    public var level: Int
    public var xp: Int
    public var trait: Trait
    /// 本趟出海遇到的事件（出港后、开始捕鱼时抽取）
    public var tripEvent: SeaEvent?
    /// 连续出海趟数（“不想回家”特性用；目前每趟卸货后不清零，切换海域时清零）
    public var streak: Int

    public init(id: UUID = UUID(), name: String, boat: Boat = Boat(), areaID: String, trait: Trait = .veteran) {
        self.id = id; self.name = name; self.boat = boat; self.areaID = areaID
        self.phase = .sailingOut; self.phaseElapsed = 0; self.tripsCompleted = 0
        self.level = 1; self.xp = 0; self.trait = trait; self.tripEvent = nil; self.streak = 0
    }

    enum CodingKeys: String, CodingKey {
        case id, name, boat, areaID, phase, phaseElapsed, tripsCompleted, level, xp, trait, tripEvent, streak
    }

    /// 兼容旧存档：新字段缺失时取默认值
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        boat = try c.decode(Boat.self, forKey: .boat)
        areaID = try c.decode(String.self, forKey: .areaID)
        phase = try c.decode(TripPhase.self, forKey: .phase)
        phaseElapsed = try c.decode(Double.self, forKey: .phaseElapsed)
        tripsCompleted = try c.decodeIfPresent(Int.self, forKey: .tripsCompleted) ?? 0
        level = try c.decodeIfPresent(Int.self, forKey: .level) ?? 1
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        trait = try c.decodeIfPresent(Trait.self, forKey: .trait) ?? .veteran
        tripEvent = try c.decodeIfPresent(SeaEvent.self, forKey: .tripEvent)
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
    }

    /// 升到下一级所需经验（放缓曲线）
    public func xpToNext(_ c: EconomyConfig) -> Int {
        Int((c.xpBase * pow(Double(level), c.xpExponent)).rounded())
    }
}

/// 图鉴条目
public struct CodexEntry: Codable, Hashable, Sendable {
    public var count: Int
    public var bestKg: Double
    public var firstCaught: Date
    public init(count: Int, bestKg: Double, firstCaught: Date) { self.count = count; self.bestKg = bestKg; self.firstCaught = firstCaught }
}

/// 事件日志
public struct EventRecord: Codable, Hashable, Sendable {
    public let date: Date
    public let text: String
    public init(date: Date, text: String) { self.date = date; self.text = text }
}

/// 一次出海的收获记录
public struct CatchRecord: Codable, Hashable, Sendable {
    public let captainName: String
    public let fishName: String
    public let fishEmoji: String
    public let count: Int
    public let coins: Int
    // 以下为新版字段（旧存档为 nil）：本趟最好的一条鱼，可选择留下放进鱼缸
    public var fishID: String? = nil
    public var kg: Double? = nil
    public var sellValue: Int? = nil
    public var kept: Bool? = nil
}

/// 鱼缸里的一条鱼
public struct TankFish: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let fishID: String
    public let kg: Double
    public let caughtAt: Date

    public init(id: UUID = UUID(), fishID: String, kg: Double, caughtAt: Date) {
        self.id = id; self.fishID = fishID; self.kg = kg; self.caughtAt = caughtAt
    }
}
