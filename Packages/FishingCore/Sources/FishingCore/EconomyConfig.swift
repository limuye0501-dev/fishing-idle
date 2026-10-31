import Foundation

/// 全部数值配置集中在这里，便于调平衡
public struct EconomyConfig: Codable, Sendable {
    public var startingCoins = 50
    public var baseSpeed = 1.0          // 海里/秒
    public var speedGrowth = 1.25
    public var baseCapacity = 5
    public var capacityPerLevel = 3
    public var unloadSeconds = 2.0
    public var speedUpgradeBase = 40.0
    public var capacityUpgradeBase = 30.0
    public var upgradeCostGrowth = 1.6
    public var captainHireBase = 150.0
    public var captainHireGrowth = 2.2
    public var maxCaptains = 6
    public var maxOfflineSeconds: Double = 8 * 3600
    public var areas: [SeaArea]
    // 船长成长
    public var levelValueBonus = 0.05     // 每级收益 +5%
    public var levelSpeedBonus = 0.03     // 每级航速 +3%
    public var xpPerTripBase = 10
    public var xpPerAreaIndex = 5
    // 海上事件概率（每趟出海一次判定）
    public var fishSchoolChance = 0.15
    public var stormChance = 0.10
    public var treasureChance = 0.06
    public var fishSchoolMultiplier = 1.5
    public var stormTimeMultiplier = 1.5
    public var stormBonusFish = 2
    // 图鉴集齐奖励：金币 + 该海域永久收益加成
    public var codexAreaBonus = 0.10
    public func codexReward(for area: SeaArea) -> Int { max(200, area.unlockCost / 2) }

    public var captainNames = ["老王", "阿海", "小渔", "大胡子", "珍珠", "阿浪"]

    public init(areas: [SeaArea] = EconomyConfig.defaultAreas) { self.areas = areas }

    public func area(_ id: String) -> SeaArea? { areas.first { $0.id == id } }

    public func speedUpgradeCost(level: Int) -> Int {
        Int((speedUpgradeBase * pow(upgradeCostGrowth, Double(level - 1))).rounded())
    }
    public func capacityUpgradeCost(level: Int) -> Int {
        Int((capacityUpgradeBase * pow(upgradeCostGrowth, Double(level - 1))).rounded())
    }
    /// existing = 当前船长数量
    public func hireCost(existing: Int) -> Int {
        Int((captainHireBase * pow(captainHireGrowth, Double(existing - 1))).rounded())
    }

    public static let defaultAreas: [SeaArea] = [
        SeaArea(id: "bay", name: "宁静海湾", distance: 6, secondsPerFish: 1.0, unlockCost: 0, fish: [
            FishType(id: "sardine", name: "沙丁鱼", emoji: "🐟", value: 2, weight: 6, baseKg: 0.1),
            FishType(id: "mackerel", name: "鲭鱼", emoji: "🐟", value: 4, weight: 3, baseKg: 0.5),
            FishType(id: "crab", name: "小螃蟹", emoji: "🦀", value: 8, weight: 1, baseKg: 0.3),
        ]),
        SeaArea(id: "reef", name: "珊瑚礁", distance: 14, secondsPerFish: 1.4, unlockCost: 500, fish: [
            FishType(id: "clown", name: "小丑鱼", emoji: "🐠", value: 10, weight: 5, baseKg: 0.2),
            FishType(id: "squid", name: "鱿鱼", emoji: "🦑", value: 18, weight: 3, baseKg: 1.2),
            FishType(id: "lobster", name: "龙虾", emoji: "🦞", value: 40, weight: 1, baseKg: 2.5),
        ]),
        SeaArea(id: "deep", name: "深蓝远洋", distance: 28, secondsPerFish: 2.0, unlockCost: 4000, fish: [
            FishType(id: "tuna", name: "金枪鱼", emoji: "🐟", value: 45, weight: 5, baseKg: 40),
            FishType(id: "puffer", name: "河豚", emoji: "🐡", value: 70, weight: 3, baseKg: 1.5),
            FishType(id: "shark", name: "鲨鱼", emoji: "🦈", value: 200, weight: 1, baseKg: 120),
        ]),
        SeaArea(id: "legend", name: "传说之海", distance: 50, secondsPerFish: 3.0, unlockCost: 30000, fish: [
            FishType(id: "octopus", name: "大章鱼", emoji: "🐙", value: 220, weight: 5, baseKg: 15),
            FishType(id: "whale", name: "鲸鱼", emoji: "🐋", value: 600, weight: 2, baseKg: 8000),
            FishType(id: "dragon", name: "龙王鱼", emoji: "🐉", value: 2000, weight: 0.5, baseKg: 300),
        ]),
    ]
}
