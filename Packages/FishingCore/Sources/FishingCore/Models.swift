import Foundation

/// 鱼的种类
public struct FishType: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let emoji: String
    public let value: Int
    /// 相对出现权重
    public let weight: Double

    public init(id: String, name: String, emoji: String, value: Int, weight: Double) {
        self.id = id; self.name = name; self.emoji = emoji; self.value = value; self.weight = weight
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

    /// 用 0..<1 的随机数按权重选鱼
    public func pickFish(roll: Double) -> FishType? {
        let total = fish.reduce(0) { $0 + $1.weight }
        var acc = 0.0
        let target = min(max(roll, 0), 0.999_999) * total
        for f in fish {
            acc += f.weight
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

    public init(id: UUID = UUID(), name: String, boat: Boat = Boat(), areaID: String) {
        self.id = id; self.name = name; self.boat = boat; self.areaID = areaID
        self.phase = .sailingOut; self.phaseElapsed = 0; self.tripsCompleted = 0
    }
}

/// 一次出海的收获记录
public struct CatchRecord: Codable, Hashable, Sendable {
    public let captainName: String
    public let fishName: String
    public let fishEmoji: String
    public let count: Int
    public let coins: Int
}
