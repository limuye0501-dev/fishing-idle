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
    // 免费版范围：前两片海域、只有鱼竿、固定春季、鱼缸不能扩容；宝石永不出售
    public var freeAreaCount = 2
    public var freeGear: [GearType] = [.rod]
    public var freeSeason: Season = .spring
    public var maxOfflineSeconds: Double = 8 * 3600
    public var areas: [SeaArea]
    // 船长成长
    public var levelValueBonus = 0.02     // 每级收益 +2%
    public var levelSpeedBonus = 0.01     // 每级航速 +1%
    public var xpPerTripBase = 10
    public var xpPerAreaIndex = 5
    // 海上事件概率（每趟出海一次判定）
    public var fishSchoolChance = 0.15
    public var stormChance = 0.10
    public var treasureChance = 0.03
    public var fishSchoolMultiplier = 1.5
    public var stormTimeMultiplier = 1.5
    public var stormBonusFish = 2
    // 图鉴集齐奖励：金币 + 该海域永久收益加成
    public var codexAreaBonus = 0.10
    public func codexReward(for area: SeaArea) -> Int { max(200, area.unlockCost / 2) }

    // 升级经验曲线：xpToNext = xpBase × level^xpExponent（放缓升级）
    public var xpBase = 60.0
    public var xpExponent = 1.6
    // 宝箱：宝石 1 个（幸运 1~2），金币按渔获估值
    public var treasureGemsMax = 1
    // 季节：一季 = 现实 1 天（UTC 0 点切换）
    public var seasonSeconds: Double = 86_400
    public var summerSchoolMultiplier = 1.5   // 夏季鱼群更多
    public var winterStormMultiplier = 2.0    // 冬季风暴翻倍
    public var springTreasureMultiplier = 1.5 // 春季宝箱更多
    public var autumnValueBonus = 0.10        // 秋季鱼价 +10%
    // 渔具
    public func gearCatchMultiplier(_ g: GearType) -> Double {
        switch g { case .rod: 1.0; case .trap: 1.1; case .longline: 1.25; case .trawl: 1.5; case .deepNet: 1.4 }
    }
    public var gearLevelBonus = 0.15          // 每级渔获 +15%
    public var maxGearLevel = 5
    /// 购买价格：金币或宝石（深海网是宝石专属稀有渔具）
    public func gearPrice(_ g: GearType) -> (coins: Int, gems: Int) {
        switch g { case .rod: (0, 0); case .trap: (150, 0); case .longline: (600, 0); case .trawl: (2_000, 0); case .deepNet: (0, 25) }
    }
    public func gearUpgradeCost(_ g: GearType, level: Int) -> Int {
        Int((80.0 * pow(1.9, Double(level - 1)) * (g == .deepNet ? 4 : 1)).rounded())
    }
    // 宝石用途：加速本趟出海
    public var rushGemCost = 2
    // 生态鱼缸
    public var tankBaseCapacity = 4
    public var tankCapacityPerLevel = 2
    public func tankUpgradeCost(level: Int) -> Int { Int((500.0 * pow(2.0, Double(level))).rounded()) }
    /// 游客门票收入：每种不同鱼每秒 = 鱼价 × 该系数（物种越多越赚）
    public var tankIncomePerValuePerSecond = 0.002

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
            FishType(id: "sardine", name: "欧洲沙丁鱼", emoji: "🐟", value: 2, weight: 6, baseKg: 0.1, gears: [.rod, .trawl]),
            FishType(id: "mackerel", name: "白腹鲭", emoji: "🐟", value: 4, weight: 3, baseKg: 0.5, gears: [.rod, .longline, .trawl], seasons: [.spring, .autumn]),
            FishType(id: "crab", name: "三疣梭子蟹", emoji: "🦀", value: 8, weight: 2, baseKg: 0.3, gears: [.trap]),
            FishType(id: "seabream", name: "真鲷", emoji: "🐠", value: 15, weight: 1, baseKg: 1.5, gears: [.rod, .longline], seasons: [.spring]),
        ], mapX: 0.50, mapY: 0.78, blurb: "港口外的浅湾，新手船长的第一站"),
        SeaArea(id: "mangrove", name: "红树林湿地", distance: 9, secondsPerFish: 1.1, unlockCost: 300, fish: [
            FishType(id: "mudskipper", name: "弹涂鱼", emoji: "🐟", value: 5, weight: 5, baseKg: 0.02, gears: [.rod, .trap]),
            FishType(id: "tigerprawn", name: "斑节对虾", emoji: "🦐", value: 6, weight: 4, baseKg: 0.1, gears: [.trap, .trawl], seasons: [.summer, .autumn]),
            FishType(id: "mudcrab", name: "锯缘青蟹", emoji: "🦀", value: 18, weight: 2, baseKg: 1.0, gears: [.trap], seasons: [.summer, .autumn]),
            FishType(id: "barramundi", name: "尖吻鲈", emoji: "🐟", value: 25, weight: 1, baseKg: 5, gears: [.rod, .longline], seasons: [.winter, .spring]),
        ], mapX: 0.18, mapY: 0.68, blurb: "咸淡水交汇的泥滩，蟹虾成群"),
        SeaArea(id: "reef", name: "珊瑚礁", distance: 14, secondsPerFish: 1.4, unlockCost: 1_200, fish: [
            FishType(id: "clown", name: "眼斑双锯鱼", emoji: "🐠", value: 10, weight: 5, baseKg: 0.05, gears: [.rod, .trap]),
            FishType(id: "squid", name: "莱氏拟乌贼", emoji: "🦑", value: 18, weight: 3, baseKg: 1.0, gears: [.rod, .trawl], seasons: [.summer, .autumn]),
            FishType(id: "lobster", name: "锦绣龙虾", emoji: "🦞", value: 40, weight: 1.5, baseKg: 2.0, gears: [.trap], seasons: [.autumn, .winter]),
            FishType(id: "coraltrout", name: "豹纹鳃棘鲈", emoji: "🐟", value: 60, weight: 1, baseKg: 3.0, gears: [.longline], seasons: [.summer]),
        ], mapX: 0.80, mapY: 0.62, blurb: "五彩斑斓的热带珊瑚，热闹又脆弱"),
        SeaArea(id: "kelp", name: "海藻森林", distance: 18, secondsPerFish: 1.5, unlockCost: 3_000, fish: [
            FishType(id: "urchin", name: "紫球海胆", emoji: "🟣", value: 12, weight: 5, baseKg: 0.1, gears: [.trap]),
            FishType(id: "abalone", name: "皱纹盘鲍", emoji: "🐚", value: 35, weight: 2, baseKg: 0.3, gears: [.trap], seasons: [.summer]),
            FishType(id: "yellowtail", name: "五条鰤", emoji: "🐟", value: 30, weight: 3, baseKg: 8, gears: [.rod, .longline], seasons: [.winter]),
            FishType(id: "seadragon", name: "叶海龙", emoji: "🐉", value: 120, weight: 0.5, baseKg: 0.1, gears: [.rod], seasons: [.spring]),
        ], mapX: 0.32, mapY: 0.50, blurb: "高耸的巨藻随浪摇曳，藏着海里的“龙”"),
        SeaArea(id: "deep", name: "深蓝远洋", distance: 28, secondsPerFish: 2.0, unlockCost: 8_000, fish: [
            FishType(id: "tuna", name: "黄鳍金枪鱼", emoji: "🐟", value: 45, weight: 5, baseKg: 60, gears: [.longline, .deepNet]),
            FishType(id: "mahimahi", name: "鲯鳅", emoji: "🐬", value: 50, weight: 3, baseKg: 10, gears: [.rod, .longline], seasons: [.summer, .autumn]),
            FishType(id: "puffer", name: "红鳍东方鲀", emoji: "🐡", value: 70, weight: 2, baseKg: 2, gears: [.rod, .longline], seasons: [.winter]),
            FishType(id: "swordfish", name: "剑鱼", emoji: "🗡️", value: 160, weight: 0.8, baseKg: 90, gears: [.longline, .deepNet], seasons: [.summer]),
        ], mapX: 0.72, mapY: 0.40, blurb: "看不到岸的蓝水区，大型洄游鱼的地盘"),
        SeaArea(id: "ice", name: "北冰浮岛", distance: 36, secondsPerFish: 2.4, unlockCost: 20_000, fish: [
            FishType(id: "cod", name: "大西洋鳕", emoji: "🐟", value: 50, weight: 5, baseKg: 8, gears: [.trawl, .longline]),
            FishType(id: "salmon", name: "大西洋鲑", emoji: "🍣", value: 80, weight: 3, baseKg: 5, gears: [.rod, .trawl], seasons: [.autumn]),
            FishType(id: "charr", name: "北极红点鲑", emoji: "🐟", value: 90, weight: 2, baseKg: 3, gears: [.rod], seasons: [.winter, .spring]),
            FishType(id: "kingcrab", name: "堪察加拟石蟹", emoji: "🦀", value: 150, weight: 1.5, baseKg: 5, gears: [.trap], seasons: [.winter]),
        ], mapX: 0.15, mapY: 0.28, blurb: "冰山漂浮的寒冷海域，冬天收获最好"),
        SeaArea(id: "trench", name: "深渊海沟", distance: 45, secondsPerFish: 2.8, unlockCost: 50_000, fish: [
            FishType(id: "monkfish", name: "黄鮟鱇", emoji: "🐟", value: 120, weight: 4, baseKg: 10, gears: [.deepNet, .longline]),
            FishType(id: "octopus", name: "北太平洋巨型章鱼", emoji: "🐙", value: 220, weight: 3, baseKg: 15, gears: [.trap, .deepNet]),
            FishType(id: "giantsquid", name: "大王乌贼", emoji: "🦑", value: 400, weight: 1, baseKg: 150, gears: [.deepNet], seasons: [.autumn, .winter]),
            FishType(id: "oarfish", name: "皇带鱼", emoji: "🎏", value: 600, weight: 0.6, baseKg: 50, gears: [.deepNet], seasons: [.spring, .summer]),
        ], mapX: 0.62, mapY: 0.20, blurb: "阳光照不到的深渊，怪鱼出没"),
        SeaArea(id: "legend", name: "传说之海", distance: 60, secondsPerFish: 3.0, unlockCost: 120_000, fish: [
            FishType(id: "bluefin", name: "大西洋蓝鳍金枪鱼", emoji: "🐟", value: 500, weight: 3, baseKg: 250, gears: [.longline, .deepNet]),
            FishType(id: "sunfish", name: "翻车鲀", emoji: "🐟", value: 700, weight: 2, baseKg: 1000, gears: [.deepNet], seasons: [.summer, .autumn]),
            FishType(id: "megamouth", name: "巨口鲨", emoji: "🦈", value: 1500, weight: 0.6, baseKg: 750, gears: [.deepNet], seasons: [.winter]),
            FishType(id: "coelacanth", name: "西印度洋矛尾鱼", emoji: "🦕", value: 2500, weight: 0.3, baseKg: 80, gears: [.deepNet], seasons: [.spring]),
        ], mapX: 0.40, mapY: 0.07, blurb: "海图尽头，活化石与巨兽的传说"),
    ]
}
