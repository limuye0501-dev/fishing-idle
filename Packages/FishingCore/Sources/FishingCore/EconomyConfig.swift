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
            FishType(id: "sardine", name: "沙丁鱼", emoji: "🐟", value: 2, weight: 6),
            FishType(id: "mackerel", name: "鲭鱼", emoji: "🐟", value: 4, weight: 3),
            FishType(id: "crab", name: "小螃蟹", emoji: "🦀", value: 8, weight: 1),
        ]),
        SeaArea(id: "reef", name: "珊瑚礁", distance: 14, secondsPerFish: 1.4, unlockCost: 500, fish: [
            FishType(id: "clown", name: "小丑鱼", emoji: "🐠", value: 10, weight: 5),
            FishType(id: "squid", name: "鱿鱼", emoji: "🦑", value: 18, weight: 3),
            FishType(id: "lobster", name: "龙虾", emoji: "🦞", value: 40, weight: 1),
        ]),
        SeaArea(id: "deep", name: "深蓝远洋", distance: 28, secondsPerFish: 2.0, unlockCost: 4000, fish: [
            FishType(id: "tuna", name: "金枪鱼", emoji: "🐟", value: 45, weight: 5),
            FishType(id: "puffer", name: "河豚", emoji: "🐡", value: 70, weight: 3),
            FishType(id: "shark", name: "鲨鱼", emoji: "🦈", value: 200, weight: 1),
        ]),
        SeaArea(id: "legend", name: "传说之海", distance: 50, secondsPerFish: 3.0, unlockCost: 30000, fish: [
            FishType(id: "octopus", name: "大章鱼", emoji: "🐙", value: 220, weight: 5),
            FishType(id: "whale", name: "鲸鱼", emoji: "🐋", value: 600, weight: 2),
            FishType(id: "dragon", name: "龙王鱼", emoji: "🐉", value: 2000, weight: 0.5),
        ]),
    ]
}
