import Foundation

/// 鱼的种类
public struct FishType: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let emoji: String
    public let value: Int
    /// 相对出现权重
    public let weight: Double
    /// 标准体重（公斤），实际体重在 0.6~1.8 倍之间浮动
    public let baseKg: Double

    public init(id: String, name: String, emoji: String, value: Int, weight: Double, baseKg: Double = 1) {
        self.id = id; self.name = name; self.emoji = emoji; self.value = value; self.weight = weight
        self.baseKg = baseKg
    }
}

/// 海域
public struct SeaArea: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    /// 距离（海里），决定航行时间
    public let distance: Double
    /// 每条鱼的捕获耗时（秒）
    public let secondsPerFish: Double
    public let unlockCost: Int
    public let fish: [FishType]

    public init(id: String, name: String, distance: Double, secondsPerFish: Double, unlockCost: Int, fish: [FishType]) {
        self.id = id; self.name = name; self.distance = distance
        self.secondsPerFish = secondsPerFish; self.unlockCost = unlockCost; self.fish = fish
    }

    /// 加权平均单条鱼价值
    public var averageFishValue: Double {
        let total = fish.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return 0 }
        return fish.reduce(0) { $0 + Double($1.value) * $1.weight } / total
    }

    /// 用 0..<1 的随机数按权重选鱼；rareBoost 会放大该海域最贵鱼的权重
    public func pickFish(roll: Double, rareBoost: Double = 1) -> FishType? {
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
}

/// 船只
public struct Boat: Codable, Hashable, Sendable {
    public var speedLevel: Int
    public var capacityLevel: Int

    public init(speedLevel: Int = 1, capacityLevel: Int = 1) {
        self.speedLevel = speedLevel; self.capacityLevel = capacityLevel
    }

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
        case .veteran: return "远洋老手"
        case .quickHands: return "快手"
        case .lucky: return "幸运"
        case .homebody: return "不想回家"
        case .stormRider: return "弄潮儿"
        }
    }
    public var detail: String {
        switch self {
        case .veteran: return "在深蓝远洋及更远海域收益 +30%"
        case .quickHands: return "捕鱼时间 -25%"
        case .lucky: return "稀有鱼与宝箱概率翻倍"
        case .homebody: return "连续出海越久越赚，每趟 +2%（最多 +40%）"
        case .stormRider: return "风暴不耽误行程，还能多钓 3 条"
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
        case .fishSchool: return "遇到鱼群"
        case .storm: return "遭遇风暴"
        case .treasure: return "捞到宝箱"
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

    /// 升到下一级所需经验
    public var xpToNext: Int { 40 + 30 * (level - 1) }
}

/// 图鉴条目
public struct CodexEntry: Codable, Hashable, Sendable {
    public var count: Int
    public var bestKg: Double
    public var firstCaught: Date
}

/// 事件日志
public struct EventRecord: Codable, Hashable, Sendable {
    public let date: Date
    public let text: String
}

/// 一次出海的收获记录
public struct CatchRecord: Codable, Hashable, Sendable {
    public let captainName: String
    public let fishName: String
    public let fishEmoji: String
    public let count: Int
    public let coins: Int
}
