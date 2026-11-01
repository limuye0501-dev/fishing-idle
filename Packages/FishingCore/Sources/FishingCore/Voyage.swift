import Foundation

// MARK: - v2：一艘大渔船，常驻海上（设计见 docs/design-v2.md）

/// 大洋
public struct Ocean: Identifiable, Sendable {
    public let id: String
    public let zhName: String
    public let enName: String
    public var name: String { CoreLang.english ? enName : zhName }
    /// 渔场中心（真实经纬度，经度 -180...180）
    public let lat: Double
    public let lon: Double
    /// 距母港航程（海里）
    public let distance: Double
    public let unlockCost: Int
    /// 解锁需要的图鉴物种数
    public let speciesRequired: Int
    /// 需要的船体加固等级（极地浮冰）
    public let hullRequired: Int
    public let polar: Bool
    public let fish: [FishType]
    public let zhBlurb: String
    public let enBlurb: String
    public var blurb: String { CoreLang.english ? enBlurb : zhBlurb }
}

public enum Weather: String, Codable, CaseIterable, Sendable {
    case sunny, breeze, rain, fog, storm, ice
    public var name: String {
        switch self {
        case .sunny: return tr("晴", "Sunny")
        case .breeze: return tr("微风", "Breezy")
        case .rain: return tr("小雨", "Rain")
        case .fog: return tr("海雾", "Fog")
        case .storm: return tr("风暴", "Storm")
        case .ice: return tr("浮冰", "Drift ice")
        }
    }
    public var emoji: String {
        switch self { case .sunny: "☀️"; case .breeze: "🌤️"; case .rain: "🌧️"; case .fog: "🌫️"; case .storm: "⛈️"; case .ice: "🧊" }
    }
    /// 捕获速度倍率
    public var catchRate: Double {
        switch self { case .sunny: 1.0; case .breeze: 1.15; case .rain: 0.95; case .fog: 0.9; case .storm: 0.4; case .ice: 0.7 }
    }
    /// 稀有度加成
    public var rareBoost: Double {
        switch self { case .sunny: 1.0; case .breeze: 1.0; case .rain: 1.3; case .fog: 1.5; case .storm: 1.3; case .ice: 1.3 }
    }
    public var fuelRate: Double { self == .storm ? 2.0 : 1.0 }
}

public enum DayPart: Sendable {
    case dawn, day, dusk, night
    public static func at(hour: Int) -> DayPart {
        switch hour {
        case 5..<7: return .dawn
        case 7..<17: return .day
        case 17..<19: return .dusk
        default: return .night
        }
    }
    public var name: String {
        switch self { case .dawn: tr("清晨", "Dawn"); case .day: tr("白天", "Day"); case .dusk: tr("黄昏", "Dusk"); case .night: tr("夜晚", "Night") }
    }
    /// 晨昏是“黄金时段”，夜里稀有鱼更多
    public var catchRate: Double { switch self { case .dawn, .dusk: 1.2; case .day: 1.0; case .night: 0.9 } }
    public var rareBoost: Double { self == .night ? 1.4 : 1.0 }
}

public enum ShipPart: String, Codable, CaseIterable, Sendable {
    case engine, hold, sonar, nets, icebox, hull
    public var name: String {
        switch self {
        case .engine: return tr("引擎", "Engine")
        case .hold: return tr("鱼舱", "Hold")
        case .sonar: return tr("声呐", "Sonar")
        case .nets: return tr("渔网绞机", "Net winch")
        case .icebox: return tr("冰柜", "Icebox")
        case .hull: return tr("船体加固", "Ice-strengthened hull")
        }
    }
    public var emoji: String {
        switch self { case .engine: "⚙️"; case .hold: "📦"; case .sonar: "📡"; case .nets: "🕸️"; case .icebox: "🧊"; case .hull: "🛡️" }
    }
    public var desc: String {
        switch self {
        case .engine: return tr("航速 +15%/级，油箱 +40", "+15% speed per level, +40 fuel capacity")
        case .hold: return tr("鱼舱 +20 格/级", "+20 hold slots per level")
        case .sonar: return tr("稀有鱼 +10%/级，主动捕鱼时鱼群更好找", "+10% rare fish per level; easier to find schools when fishing actively")
        case .nets: return tr("挂机捕鱼速度 +15%/级", "+15% idle catch speed per level")
        case .icebox: return tr("保鲜时间 +50%/级", "+50% freshness time per level")
        case .hull: return tr("2 级可进北冰洋，3 级可进南大洋，浮冰减速更少", "Lv2 for the Arctic, Lv3 for the Southern Ocean; less slowdown in ice")
        }
    }
}

public enum CrewSkill: String, Codable, CaseIterable, Sendable {
    case seamanship, angling, keenEye, cook
    public var name: String {
        switch self {
        case .seamanship: return tr("航海术", "Seamanship")
        case .angling: return tr("渔技", "Angling")
        case .keenEye: return tr("眼力", "Keen Eye")
        case .cook: return tr("保鲜术", "Preserving")
        }
    }
    public var desc: String {
        switch self {
        case .seamanship: return tr("油耗 -8%/级，航速 +5%/级", "−8% fuel use, +5% speed per level")
        case .angling: return tr("挂机捕鱼 +8%/级", "+8% idle catch speed per level")
        case .keenEye: return tr("稀有鱼 +12%/级", "+12% rare fish per level")
        case .cook: return tr("保鲜时间 +15%/级", "+15% freshness time per level")
        }
    }
}

public enum ShipPhase: String, Codable, Sendable { case fishing, sailing, docked }

/// 舱里的一条鱼
public struct HoldFish: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let fishID: String
    public let kg: Double
    public let caughtAt: Date
    public let active: Bool
    /// v9：闪光色变（稀有变种），价值 ×5
    public var shiny: Bool?
    public var isShiny: Bool { shiny ?? false }
    public init(id: UUID = UUID(), fishID: String, kg: Double, caughtAt: Date, active: Bool = false, shiny: Bool = false) {
        self.id = id; self.fishID = fishID; self.kg = kg; self.caughtAt = caughtAt; self.active = active; self.shiny = shiny ? true : nil
    }
}

public struct Quest: Sendable, Identifiable {
    public enum Kind: Sendable { case catches, species, earned, active, ocean, trophies, portVisits, tank }
    public let id: Int
    public let kind: Kind
    public let target: Int
    public let oceanID: String?
    public let coins: Int
    public let gems: Int
    public var title: String {
        switch kind {
        case .catches: return tr("累计捕获 \(target) 条鱼", "Catch \(target) fish")
        case .species: return tr("图鉴收集 \(target) 种", "Discover \(target) species")
        case .earned: return tr("卖鱼累计赚 \(target) 金币", "Earn \(target) coins selling fish")
        case .active: return tr("主动捕鱼成功 \(target) 次", "Land \(target) fish by hand")
        case .ocean: return tr("驶入\(VoyageConfig.ocean(oceanID ?? "")?.zhName ?? "")", "Sail into the \(VoyageConfig.ocean(oceanID ?? "")?.enName ?? "")")
        case .trophies: return tr("钓到 \(target) 条纪录级大鱼", "Land \(target) trophy-size fish")
        case .portVisits: return tr("回港 \(target) 次", "Visit port \(target) times")
        case .tank: return tr("鱼缸里养 \(target) 条鱼", "Keep \(target) fish in the aquarium")
        }
    }
}

public enum VoyageError: Error, Equatable {
    case notEnoughCoins, notEnoughGems, needsFullVersion, needsPort, notAtSea, locked, needsSpecies(Int), needsHull(Int)
    case maxLevel, holdEmpty, carrierCooldown, alreadyThere, noSkillPoints, tankFull, unknown
}

/// 全部 v2 数值
public enum VoyageConfig {
    public static let freeOceanCount = 2
    public static let freeGear: [GearType] = [.rod, .trap, .trawl]
    public static let freeMaxPartLevel = 3
    public static let maxPartLevel = 6
    public static let maxSkill = 5
    public static let startingCoins = 120
    public static let maxOfflineSeconds: Double = 12 * 3600
    public static let baseCatchSeconds = 90.0
    public static let baseSpeed = 0.6            // 海里/秒（游戏时间）
    public static let fuelPerHour = 8.0          // 作业时每小时油耗
    public static let fuelPerNM = 0.05           // 航行每海里油耗
    public static let driftCatchFactor = 0.5     // 没油时漂流作业效率（v8：30%→50%，不卡死）
    public static let shelfLifeHours = 6.0       // 冰柜 1 级时的保鲜期
    public static let minFreshness = 0.3
    /// 主动捕鱼体型系数：品质 0 → 0.6（失败也有鱼），品质 1 → 1.5
    public static func activeKgFactor(quality q: Double) -> Double { 0.6 + 0.9 * max(0, min(1, q)) }
    public static let carrierPrice = 0.75        // 收购船价格
    public static let carrierCooldown: Double = 2 * 3600
    public static let carrierFuelPrice = 3       // 收购船上的油价（每单位）
    public static let portFuelPrice = 1
    public static let carrierGemCost = 3
    public static let rareSightingChance = 0.08  // 每小时
    public static let rareSightingSeconds: Double = 20 * 60
    public static let trophyFactor = 1.5
    public static let tankBase = 4
    public static let tankPerLevel = 2
    public static let homeLat = 30.0, homeLon = 122.2   // 舟山
    public static func tankUpgradeCost(level: Int) -> Int { Int((500.0 * pow(2.0, Double(level))).rounded()) }
    public static func partCost(_ p: ShipPart, level: Int) -> Int {
        let base: Double
        switch p { case .engine: base = 120; case .hold: base = 150; case .sonar: base = 150; case .nets: base = 130; case .icebox: base = 90; case .hull: base = 400 }
        return Int((base * pow(2.1, Double(level - 1))).rounded())
    }
    public static func gearPrice(_ g: GearType) -> (coins: Int, gems: Int) {
        switch g { case .rod: (0, 0); case .trap: (100, 0); case .trawl: (300, 0); case .longline: (1_500, 0); case .deepNet: (0, 25) }
    }
    public static func gearCatch(_ g: GearType) -> Double {
        switch g { case .rod: 1.0; case .trap: 1.1; case .longline: 1.3; case .trawl: 1.5; case .deepNet: 1.4 }
    }
    public static func xpToNext(level: Int) -> Int { Int((60.0 * pow(Double(level), 1.6)).rounded()) }

    static func f(_ id: String) -> FishType {
        if let x = GameState.fish(id, config: EconomyConfig()) { return x }
        return extraFish.first { $0.id == id }!
    }
    /// v2 新增物种
    public static let extraFish: [FishType] = [
        FishType(id: "snowcrab", name: "灰眼雪蟹", emoji: "🦀", value: 20, weight: 3, baseKg: 0.6, gears: [.trap], seasons: [.winter, .spring]),
        FishType(id: "polarcod", name: "极地鳕", emoji: "🐟", value: 12, weight: 5, baseKg: 0.2, gears: [.rod, .trawl]),
        FishType(id: "halibut", name: "马舌鲽", emoji: "🐟", value: 70, weight: 3, baseKg: 8, gears: [.longline, .trawl]),
        FishType(id: "greenlandshark", name: "小头睡鲨", emoji: "🦈", value: 900, weight: 0.5, baseKg: 400, gears: [.longline, .deepNet]),
        FishType(id: "krill", name: "南极大磷虾", emoji: "🦐", value: 15, weight: 6, baseKg: 0.002, gears: [.trawl]),
        FishType(id: "icefish", name: "裘氏鳄头冰鱼", emoji: "🐟", value: 60, weight: 3, baseKg: 0.4, gears: [.trawl, .rod]),
        FishType(id: "toothfish", name: "莫氏犬牙南极鱼", emoji: "🐟", value: 450, weight: 1.5, baseKg: 30, gears: [.longline, .deepNet]),
    ]
    public static let oceans: [Ocean] = [
        Ocean(id: "coastal", zhName: "东海近海", enName: "East China Sea", lat: 29.5, lon: 124.0, distance: 30, unlockCost: 0,
              speciesRequired: 0, hullRequired: 1, polar: false,
              fish: ["mackerel", "crab", "seabream", "mudskipper", "puffer", "monkfish", "abalone", "yellowtail"].map(f),
              zhBlurb: "家门口的渔场，风平浪静，最适合新船试网", enBlurb: "The fishing grounds on your doorstep — calm water for a new ship's first casts"),
        Ocean(id: "atlantic", zhName: "大西洋", enName: "Atlantic Ocean", lat: 52.0, lon: -30.0, distance: 900, unlockCost: 1_500,
              speciesRequired: 4, hullRequired: 1, polar: false,
              fish: ["sardine", "cod", "salmon", "snowcrab", "swordfish", "sunfish", "bluefin"].map(f),
              zhBlurb: "鳕鱼、鲑鱼与蓝鳍金枪鱼的老渔场", enBlurb: "Classic grounds for cod, salmon and bluefin tuna"),
        Ocean(id: "pacific", zhName: "太平洋", enName: "Pacific Ocean", lat: 20.0, lon: -170.0, distance: 1_200, unlockCost: 8_000,
              speciesRequired: 10, hullRequired: 1, polar: false,
              fish: ["clown", "urchin", "tuna", "mahimahi", "coraltrout", "octopus", "oarfish", "megamouth"].map(f),
              zhBlurb: "世界最大的大洋，从珊瑚礁到深海怪鱼应有尽有", enBlurb: "The largest ocean — from coral reefs to deep-sea giants"),
        Ocean(id: "indian", zhName: "印度洋", enName: "Indian Ocean", lat: -12.0, lon: 75.0, distance: 1_500, unlockCost: 25_000,
              speciesRequired: 16, hullRequired: 1, polar: false,
              fish: ["tigerprawn", "mudcrab", "squid", "barramundi", "lobster", "seadragon", "coelacanth"].map(f),
              zhBlurb: "温暖的季风海洋，活化石腔棘鱼的故乡", enBlurb: "A warm monsoon ocean, home of the living-fossil coelacanth"),
        Ocean(id: "arctic", zhName: "北冰洋", enName: "Arctic Ocean", lat: 76.0, lon: 30.0, distance: 2_000, unlockCost: 60_000,
              speciesRequired: 22, hullRequired: 2, polar: true,
              fish: ["polarcod", "charr", "kingcrab", "halibut", "greenlandshark"].map(f),
              zhBlurb: "浮冰之间的寒冷海域，寿命几百岁的睡鲨在深处游荡", enBlurb: "Cold water between ice floes, where centuries-old sharks roam the deep"),
        Ocean(id: "southern", zhName: "南大洋", enName: "Southern Ocean", lat: -62.0, lon: 20.0, distance: 2_600, unlockCost: 150_000,
              speciesRequired: 28, hullRequired: 3, polar: true,
              fish: ["krill", "icefish", "toothfish", "giantsquid"].map(f),
              zhBlurb: "环绕南极的狂风巨浪，磷虾与白血冰鱼的世界", enBlurb: "Wild seas around Antarctica — the world of krill and white-blooded icefish"),
    ]
    public static func ocean(_ id: String) -> Ocean? { oceans.first { $0.id == id } }
    public static var allFish: [FishType] { oceans.flatMap(\.fish) }
    public static func fish(_ id: String) -> FishType? { allFish.first { $0.id == id } }
    public static func oceanOf(fish id: String) -> Ocean? { oceans.first { $0.fish.contains { $0.id == id } } }

    public static let quests: [Quest] = [
        Quest(id: 0, kind: .catches, target: 10, oceanID: nil, coins: 100, gems: 1),
        Quest(id: 1, kind: .active, target: 3, oceanID: nil, coins: 150, gems: 1),
        Quest(id: 2, kind: .species, target: 5, oceanID: nil, coins: 200, gems: 1),
        Quest(id: 3, kind: .portVisits, target: 1, oceanID: nil, coins: 100, gems: 0),
        Quest(id: 4, kind: .earned, target: 1_000, oceanID: nil, coins: 300, gems: 2),
        Quest(id: 5, kind: .ocean, target: 1, oceanID: "atlantic", coins: 500, gems: 2),
        Quest(id: 6, kind: .trophies, target: 3, oceanID: nil, coins: 600, gems: 2),
        Quest(id: 7, kind: .tank, target: 3, oceanID: nil, coins: 800, gems: 2),
        Quest(id: 8, kind: .species, target: 12, oceanID: nil, coins: 1_500, gems: 3),
        Quest(id: 9, kind: .ocean, target: 1, oceanID: "pacific", coins: 3_000, gems: 3),
        Quest(id: 10, kind: .catches, target: 500, oceanID: nil, coins: 5_000, gems: 3),
        Quest(id: 11, kind: .ocean, target: 1, oceanID: "indian", coins: 10_000, gems: 4),
        Quest(id: 12, kind: .species, target: 24, oceanID: nil, coins: 20_000, gems: 5),
        Quest(id: 13, kind: .ocean, target: 1, oceanID: "arctic", coins: 30_000, gems: 5),
        Quest(id: 14, kind: .ocean, target: 1, oceanID: "southern", coins: 60_000, gems: 8),
        Quest(id: 15, kind: .species, target: 39, oceanID: nil, coins: 100_000, gems: 10),
    ]
}

/// 本次推进期间发生的事（给 UI 做提示/音效）
public struct VoyageReport: Sendable {
    public var catches: [HoldFish] = []
    public var released = 0
    public var newSpecies: [String] = []
    public var arrived: String? = nil
    public var seconds: Double = 0
    /// 期间发生的稀有/重要事件（日志文本，新→旧），用于“航海日志明信片”
    public var events: [String] = []
    public var trophies = 0
    /// v9：离线稀有事件
    public var rareEvents: [RareEvent] = []
    public var shinies = 0
    public var records: [String] = []
    public init() {}
    /// 本次最值钱的一条
    public var bestCatch: HoldFish? { catches.max { (VoyageConfig.fish($0.fishID)?.value ?? 0) < (VoyageConfig.fish($1.fishID)?.value ?? 0) } }

}

/// v2 游戏状态
public struct VoyageState: Codable, Sendable {
    public var version = 2
    public var coins: Int
    public var gems: Int
    public var shipName: String
    public var oceanID: String
    public var unlockedOceans: [String]
    public var phase: ShipPhase
    public var sailTo: String?          // 目的地：大洋 id 或 "port"
    public var sailFrom: String?
    public var sailElapsed: Double
    public var sailTotal: Double
    public var fuel: Double
    public var hold: [HoldFish]
    public var parts: [String: Int]
    public var gearLevels: [String: Int]
    public var equipped: GearType
    public var level: Int
    public var xp: Int
    public var skills: [String: Int]
    public var codex: [String: CodexEntry]
    public var tank: [TankFish]
    public var tankLevel: Int
    public var isFullVersion: Bool
    public var totalFishCaught: Int
    public var activeCatches: Int
    public var trophies: Int
    public var portVisits: Int
    public var coinsEarned: Int
    public var questIndex: Int
    public var visitedOceans: [String]
    public var eventLog: [EventRecord]
    public var eventCounter: Int
    public var rngState: UInt64
    public var lastUpdate: Date
    public var catchTimer: Double
    public var lastCarrier: Date
    public var sightingFishID: String?
    public var sightingUntil: Date?
    public var lastSightingHour: Int
    /// 本地时区偏移（秒），用于昼夜；App 每次启动写入
    public var utcOffset: Int
    /// 调试/演示：固定天气
    public var weatherOverride: Weather?
    /// v9 扩展存档（可选字段，旧存档自动兼容）
    public var v9: VoyageExtras?
    public var ext: VoyageExtras { get { v9 ?? VoyageExtras() } set { v9 = newValue } }

    public init(now: Date = Date(), shipName: String = "云栖号") {
        coins = VoyageConfig.startingCoins; gems = 0
        self.shipName = shipName
        oceanID = "coastal"; unlockedOceans = ["coastal"]; phase = .fishing
        sailTo = nil; sailFrom = nil; sailElapsed = 0; sailTotal = 0
        fuel = 100; hold = []
        parts = Dictionary(uniqueKeysWithValues: ShipPart.allCases.map { ($0.rawValue, 1) })
        gearLevels = [GearType.rod.rawValue: 1, GearType.trawl.rawValue: 1]; equipped = .trawl
        level = 1; xp = 0; skills = [:]
        codex = [:]; tank = []; tankLevel = 0; isFullVersion = false
        totalFishCaught = 0; activeCatches = 0; trophies = 0; portVisits = 0; coinsEarned = 0; questIndex = 0
        visitedOceans = ["coastal"]; eventLog = []; eventCounter = 0
        rngState = 0x9E3779B97F4A7C15; lastUpdate = now; catchTimer = 0
        lastCarrier = .distantPast; sightingFishID = nil; sightingUntil = nil; lastSightingHour = -1
        utcOffset = 8 * 3600; weatherOverride = nil
    }

    // MARK: 派生数值
    public func part(_ p: ShipPart) -> Int { parts[p.rawValue] ?? 1 }
    public func skill(_ s: CrewSkill) -> Int { skills[s.rawValue] ?? 0 }
    public var ocean: Ocean { VoyageConfig.ocean(oceanID) ?? VoyageConfig.oceans[0] }
    public var holdCapacity: Int { 40 + 20 * (part(.hold) - 1) }   // 用户要求：鱼舱加大（Lv3=80，Lv6=140）
    public var fuelCapacity: Double { 100 + 40 * Double(part(.engine) - 1) }
    public var speed: Double { VoyageConfig.baseSpeed * (1 + 0.15 * Double(part(.engine) - 1)) * (1 + 0.05 * Double(skill(.seamanship))) }
    public var shelfLife: Double { VoyageConfig.shelfLifeHours * 3600 * (1 + 0.5 * Double(part(.icebox) - 1)) * (1 + 0.15 * Double(skill(.cook))) }
    public var skillPoints: Int { (level - 1) - skills.values.reduce(0, +) }
    public var tankCapacity: Int { VoyageConfig.tankBase + VoyageConfig.tankPerLevel * tankLevel }
    public var atSea: Bool { phase == .fishing }
    public var maxPartLevel: Int { isFullVersion ? VoyageConfig.maxPartLevel : VoyageConfig.freeMaxPartLevel }
    public var currentQuest: Quest? { questIndex < VoyageConfig.quests.count ? VoyageConfig.quests[questIndex] : nil }

    public func weather(at date: Date) -> Weather {
        if let w = weatherOverride { return w }
        let hour = Int(floor(date.timeIntervalSince1970 / 3600))
        var h = UInt64(bitPattern: Int64(hour)) &* 0x9E3779B97F4A7C15 ^ UInt64(oceanID.unicodeScalars.reduce(0) { $0 &* 31 &+ UInt64($1.value) })
        h ^= h >> 29; h = h &* 0xBF58476D1CE4E5B9; h ^= h >> 32
        let r = Double(h % 1000) / 1000
        let season = Season.at(date, seasonSeconds: 86_400)
        let stormP = season == .winter ? 0.12 : 0.06
        if ocean.polar && r < 0.30 { return .ice }
        if r < 0.30 + stormP { return ocean.polar ? .storm : (r < stormP ? .storm : .sunny) }
        if r < 0.50 { return .breeze }
        if r < 0.62 { return .rain }
        if r < 0.72 { return .fog }
        return .sunny
    }
    public func localHour(_ date: Date) -> Int {
        let t = Int(date.timeIntervalSince1970) + utcOffset
        return ((t / 3600) % 24 + 24) % 24
    }
    public func dayPart(_ date: Date) -> DayPart { DayPart.at(hour: localHour(date)) }

    public func freshness(_ f: HoldFish, now: Date) -> Double {
        let age = max(0, now.timeIntervalSince(f.caughtAt))
        return max(VoyageConfig.minFreshness, 1 - age / shelfLife)
    }
    public func value(_ f: HoldFish, now: Date) -> Int {
        guard let t = VoyageConfig.fish(f.fishID) else { return 0 }
        let size = max(0.6, min(2.0, f.kg / max(t.baseKg, 0.0001)))
        let season = Season.at(now, seasonSeconds: 86_400)
        let autumn = season == .autumn ? 1.1 : 1.0
        return max(1, Int((Double(t.value) * size * freshness(f, now: now) * autumn * (f.isShiny ? VoyageConfig.shinyValueFactor : 1)).rounded()))
    }
    public func holdValue(now: Date) -> Int { hold.reduce(0) { $0 + value($1, now: now) } }
    public var averageFreshnessText: String { "" }

    /// 船上已有渔具能捕到的鱼（季节只影响概率）
    public func pool(at date: Date) -> [FishType] {
        return ocean.fish.filter { f in f.gears.contains { gearLevels[$0.rawValue] != nil } }
    }
    /// 每条鱼的平均间隔（秒）；0 表示停工
    public func catchInterval(at date: Date) -> Double {
        guard phase == .fishing, !pool(at: date).isEmpty else { return 0 }
        let w = weather(at: date)
        var rate = VoyageConfig.gearCatch(equipped) * (1 + 0.15 * Double(part(.nets) - 1)) * (1 + 0.08 * Double(skill(.angling)))
        rate *= (1 + 0.15 * Double((gearLevels[equipped.rawValue] ?? 1) - 1))
        rate *= w.catchRate * dayPart(date).catchRate
        if fuel <= 0 { rate *= VoyageConfig.driftCatchFactor }
        rate *= catSpeedFactor(at: date)
        return VoyageConfig.baseCatchSeconds / rate
    }
    public func rareMultiplier(at date: Date, active: Double = 0) -> Double {
        weather(at: date).rareBoost * dayPart(date).rareBoost * (1 + 0.10 * Double(part(.sonar) - 1))
            * (1 + 0.12 * Double(skill(.keenEye))) * (1 + 2.0 * active) * moodRareFactor(at: date)
    }

    // MARK: 随机
    mutating func rand() -> Double {
        rngState = rngState &* 6364136223846793005 &+ 1442695040888963407
        return Double((rngState >> 11) & ((1 << 53) - 1)) / Double(1 << 53)
    }

    mutating func log(_ text: String, _ date: Date) {
        eventLog.insert(EventRecord(date: date, text: text), at: 0)
        if eventLog.count > 60 { eventLog.removeLast(eventLog.count - 60) }
        eventCounter += 1
    }

    /// 按权重抽鱼。rare>1 时提高稀有鱼权重
    private mutating func pickFish(_ pool: [FishType], rare: Double, now: Date) -> FishType? {
        guard !pool.isEmpty else { return nil }
        let season = Season.at(now, seasonSeconds: 86_400)
        let sighting = (sightingUntil.map { $0 > now } ?? false) ? sightingFishID : nil
        let weights: [Double] = pool.map { f in
            var w = f.weight
            if w < 3 { w *= pow(rare, Double(3 - min(3, Int(w)))) * (w < 1 ? rare : 1) }
            if !f.seasons.isEmpty { w *= f.seasons.contains(season) ? 1.5 : 0.25 }   // 当季洄游，过季少见
            if f.id == sighting { w *= 6 }
            if f.id == targetFishID { w *= VoyageConfig.targetWeightFactor }
            return w
        }
        let total = weights.reduce(0, +)
        var r = rand() * total
        for (i, w) in weights.enumerated() { r -= w; if r <= 0 { return pool[i] } }
        return pool.last
    }

    /// 放进鱼舱；满了就放生最不值钱的一条（挂机始终可行，但满舱收益封顶）
    @discardableResult
    private mutating func stow(_ t: FishType, kgFactor: Double, active: Bool, now: Date, report: inout VoyageReport) -> HoldFish {
        let kg = t.baseKg * (0.6 + rand() * 1.2) * kgFactor
        let shiny = rand() < VoyageConfig.shinyChance * (active ? 3 : 1) * weather(at: now).rareBoost
        let f = HoldFish(fishID: t.id, kg: kg, caughtAt: now, active: active, shiny: shiny)
        totalFishCaught += 1
        noteCatch(f, type: t, now: now, report: &report)
        if kg >= t.baseKg * VoyageConfig.trophyFactor { trophies += 1 }
        var e = codex[t.id] ?? CodexEntry(count: 0, bestKg: 0, firstCaught: now)
        let isNew = e.count == 0
        e.count += 1; e.bestKg = max(e.bestKg, kg); codex[t.id] = e
        if isNew {
            report.newSpecies.append(t.id)
            log(tr("📖 新图鉴：\(t.emoji)\(t.name)", "📖 New in the Codex: \(t.emoji) \(t.name)"), now)
        }
        gainXP(active ? 6 : 2, now)
        if hold.count >= holdCapacity {
            let idx = hold.indices.min { value(hold[$0], now: now) < value(hold[$1], now: now) }!
            if value(hold[idx], now: now) < value(f, now: now) { hold.remove(at: idx); hold.append(f) }
            report.released += 1
        } else {
            hold.append(f)
        }
        report.catches.append(f)
        checkQuests(now)
        return f
    }

    private mutating func gainXP(_ n: Int, _ now: Date) {
        xp += n
        while xp >= VoyageConfig.xpToNext(level: level) {
            xp -= VoyageConfig.xpToNext(level: level); level += 1
            log(tr("⭐️ 船长升到 Lv\(level)，获得 1 技能点", "⭐️ Captain reached Lv\(level) — 1 skill point"), now)
        }
    }

    // MARK: 时间推进（在线与离线同一套逻辑）
    @discardableResult
    public mutating func advance(to now: Date) -> VoyageReport {
        var report = VoyageReport()
        var dt = now.timeIntervalSince(lastUpdate)
        guard dt > 0 else { return report }
        dt = min(dt, VoyageConfig.maxOfflineSeconds)
        report.seconds = dt
        let eventsBefore = eventCounter, trophiesBefore = trophies
        var t = now.addingTimeInterval(-dt)
        while dt > 0 {
            let step = min(dt, 30)
            t = t.addingTimeInterval(step); dt -= step
            tick(step, at: t, report: &report)
        }
        accrueShells(seconds: report.seconds)
        lastUpdate = now
        report.events = Array(eventLog.prefix(min(eventLog.count, eventCounter - eventsBefore))).map(\.text)
        report.trophies = trophies - trophiesBefore
        return report
    }

    private mutating func tick(_ step: Double, at now: Date, report: inout VoyageReport) {
        switch phase {
        case .sailing:
            let w = weather(at: now)
            var sp = speed
            if w == .ice { sp *= part(.hull) >= 3 ? 0.85 : 0.5 }
            if w == .storm { sp *= 0.7 }
            let nm = sp * step
            if fuel > 0 {
                fuel = max(0, fuel - nm * VoyageConfig.fuelPerNM * (1 - 0.08 * Double(skill(.seamanship))))
                sailElapsed += nm / speed
            } else {
                sailElapsed += nm / speed * 0.35   // 没油：挂帆慢慢漂
            }
            if sailElapsed >= sailTotal { arrive(now, report: &report) }
        case .docked:
            break
        case .fishing:
            rollSighting(now, report: &report)
            if fuel > 0 {
                fuel = max(0, fuel - VoyageConfig.fuelPerHour * weather(at: now).fuelRate * (1 - 0.08 * Double(skill(.seamanship))) * step / 3600)
            }
            let interval = catchInterval(at: now)
            guard interval > 0 else { return }
            catchTimer += step
            while catchTimer >= interval {
                catchTimer -= interval
                if let t = pickFish(pool(at: now), rare: rareMultiplier(at: now), now: now) {
                    stow(t, kgFactor: 1, active: false, now: now, report: &report)
                }
            }
        }
    }

    private mutating func rollSighting(_ now: Date, report: inout VoyageReport) {
        let hour = Int(floor(now.timeIntervalSince1970 / 3600))
        guard hour != lastSightingHour else { return }
        lastSightingHour = hour
        rollRareEvents(now, report: &report)
        if rand() < VoyageConfig.rareSightingChance {
            let rare = ocean.fish.sorted { $0.weight < $1.weight }.first!
            sightingFishID = rare.id
            sightingUntil = now.addingTimeInterval(VoyageConfig.rareSightingSeconds)
            log(tr("✨ 声呐发现\(rare.emoji)\(rare.name)的踪迹！20 分钟内更容易遇到", "✨ Sonar picked up signs of \(rare.emoji) \(rare.name)! More likely for 20 min"), now)
            report.rareEvents.append(RareEvent(kind: .legendaryTrace, text: eventLog.first?.text ?? "", date: now))
        }
    }

    private mutating func arrive(_ now: Date, report: inout VoyageReport) {
        let dest = sailTo ?? oceanID
        sailTo = nil; sailFrom = nil; sailElapsed = 0; sailTotal = 0; catchTimer = 0
        if dest == "port" {
            phase = .docked; portVisits += 1
            log(tr("⚓️ \(shipName) 回到母港", "⚓️ \(shipName) is back in home port"), now)
        } else {
            phase = .fishing; oceanID = dest
            if !visitedOceans.contains(dest) { visitedOceans.append(dest) }
            log(tr("🧭 \(shipName) 抵达\(ocean.zhName)，开始作业", "🧭 \(shipName) reached the \(ocean.enName) and started fishing"), now)
        }
        report.arrived = dest
        checkQuests(now)
    }

    // MARK: 航行
    /// 两地航程（海里）。母港视为 0
    public static func distance(_ a: String, _ b: String) -> Double {
        let da = a == "port" ? 0 : (VoyageConfig.ocean(a)?.distance ?? 0)
        let db = b == "port" ? 0 : (VoyageConfig.ocean(b)?.distance ?? 0)
        if a == "port" || b == "port" { return max(da, db) }
        return max(abs(da - db), 300)
    }
    public func travelSeconds(to dest: String) -> Double {
        let from = phase == .docked ? "port" : oceanID
        return VoyageState.distance(from, dest) / speed
    }
    public func canEnter(_ o: Ocean) -> VoyageError? {
        if !unlockedOceans.contains(o.id) { return .locked }
        if part(.hull) < o.hullRequired { return .needsHull(o.hullRequired) }
        return nil
    }
    public mutating func sail(to dest: String, now: Date) throws {
        advance(to: now)
        if dest != "port", let o = VoyageConfig.ocean(dest), let e = canEnter(o) { throw e }
        if phase == .sailing { throw VoyageError.unknown }
        if dest == oceanID && phase == .fishing { throw VoyageError.alreadyThere }
        if dest == "port" && phase == .docked { throw VoyageError.alreadyThere }
        sailFrom = phase == .docked ? "port" : oceanID
        sailTotal = travelSeconds(to: dest); sailElapsed = 0
        sailTo = dest; phase = .sailing
        let name = dest == "port" ? tr("母港", "home port") : (VoyageConfig.ocean(dest)?.name ?? dest)
        log(tr("⛵️ 起航前往\(name)", "⛵️ Setting sail for \(name)"), now)
    }
    /// 航行进度 0...1
    public var sailProgress: Double { sailTotal > 0 ? min(1, sailElapsed / sailTotal) : 0 }

    public mutating func unlock(_ id: String, now: Date) throws {
        guard let i = VoyageConfig.oceans.firstIndex(where: { $0.id == id }) else { throw VoyageError.unknown }
        let o = VoyageConfig.oceans[i]
        if unlockedOceans.contains(id) { throw VoyageError.alreadyThere }
        if i >= VoyageConfig.freeOceanCount && !isFullVersion { throw VoyageError.needsFullVersion }
        if codex.count < o.speciesRequired { throw VoyageError.needsSpecies(o.speciesRequired) }
        if coins < o.unlockCost { throw VoyageError.notEnoughCoins }
        coins -= o.unlockCost; unlockedOceans.append(id)
        log(tr("🗺️ 解锁海图：\(o.zhName)", "🗺️ New chart unlocked: \(o.enName)"), now)
    }

    // MARK: 卖鱼与补给
    public var carrierReady: Bool { true }
    public func carrierAvailable(now: Date) -> Bool { now.timeIntervalSince(lastCarrier) >= VoyageConfig.carrierCooldown }
    /// 在港：全价卖出；在海上：收购船 75%（有冷却，可用宝石立即呼叫）
    @discardableResult
    public mutating func sellAll(now: Date, useGems: Bool = false) throws -> Int {
        advance(to: now)
        guard !hold.isEmpty else { throw VoyageError.holdEmpty }
        var price = 1.0
        if phase != .docked {
            if !carrierAvailable(now: now) {
                guard useGems else { throw VoyageError.carrierCooldown }
                guard gems >= VoyageConfig.carrierGemCost else { throw VoyageError.notEnoughGems }
                gems -= VoyageConfig.carrierGemCost
            }
            price = VoyageConfig.carrierPrice
            lastCarrier = now
        }
        let total = Int((Double(holdValue(now: now)) * price).rounded())
        coins += total; coinsEarned += total
        let n = hold.count
        hold.removeAll()
        log(phase == .docked ? tr("💰 鱼市卖出 \(n) 条鱼，+\(total) 金币", "💰 Sold \(n) fish at the market, +\(total) coins")
                             : tr("🚢 收购船收走 \(n) 条鱼，+\(total) 金币", "🚢 The carrier ship bought \(n) fish, +\(total) coins"), now)
        checkQuests(now)
        return total
    }
    public func refuelCost() -> Int {
        let need = Int(ceil(fuelCapacity - fuel))
        return need * (phase == .docked ? VoyageConfig.portFuelPrice : VoyageConfig.carrierFuelPrice)
    }
    public mutating func refuel(now: Date) throws {
        advance(to: now)
        let cost = refuelCost()
        guard cost > 0 else { throw VoyageError.alreadyThere }
        if phase != .docked && !carrierAvailable(now: now) && fuel > 0 { throw VoyageError.carrierCooldown }
        guard coins >= cost else { throw VoyageError.notEnoughCoins }
        coins -= cost; fuel = fuelCapacity
        log(tr("⛽️ 加满燃油（-\(cost)）", "⛽️ Refuelled (−\(cost))"), now)
    }

    // MARK: 船坞（只能在港）
    public mutating func upgrade(_ p: ShipPart, now: Date) throws {
        guard phase == .docked else { throw VoyageError.needsPort }
        let lv = part(p)
        guard lv < VoyageConfig.maxPartLevel else { throw VoyageError.maxLevel }
        guard lv < maxPartLevel else { throw VoyageError.needsFullVersion }
        let cost = VoyageConfig.partCost(p, level: lv)
        guard coins >= cost else { throw VoyageError.notEnoughCoins }
        coins -= cost; parts[p.rawValue] = lv + 1
        if p == .engine { fuel = min(fuelCapacity, fuel + 40) }
        log(tr("🔧 \(p.name) 升到 \(lv + 1) 级", "🔧 \(p.name) upgraded to Lv\(lv + 1)"), now)
    }
    public mutating func buyGear(_ g: GearType, now: Date) throws {
        guard phase == .docked else { throw VoyageError.needsPort }
        if !VoyageConfig.freeGear.contains(g) && !isFullVersion { throw VoyageError.needsFullVersion }
        let lv = gearLevels[g.rawValue] ?? 0
        guard lv < 5 else { throw VoyageError.maxLevel }
        let p = VoyageConfig.gearPrice(g)
        let coinCost = lv == 0 ? p.coins : Int(Double(max(p.coins, 200)) * pow(1.9, Double(lv)))
        let gemCost = lv == 0 ? p.gems : 0
        guard coins >= coinCost else { throw VoyageError.notEnoughCoins }
        guard gems >= gemCost else { throw VoyageError.notEnoughGems }
        coins -= coinCost; gems -= gemCost; gearLevels[g.rawValue] = lv + 1
        // v9：绝不自动换装（玩家选择的渔具/海域/目标鱼一直保持）
        log(tr("\(g.emoji) \(g.name) \(lv == 0 ? "上船" : "升到 \(lv + 1) 级")", "\(g.emoji) \(g.name) \(lv == 0 ? "on board" : "upgraded to Lv\(lv + 1)")"), now)
    }
    public func gearUpgradeCost(_ g: GearType) -> (coins: Int, gems: Int) {
        let lv = gearLevels[g.rawValue] ?? 0
        let p = VoyageConfig.gearPrice(g)
        return lv == 0 ? p : (Int(Double(max(p.coins, 200)) * pow(1.9, Double(lv))), 0)
    }
    /// 换渔具可以在海上进行
    public mutating func equip(_ g: GearType, now: Date) throws {
        guard gearLevels[g.rawValue] != nil else { throw VoyageError.locked }
        advance(to: now); equipped = g
    }
    public mutating func learn(_ s: CrewSkill) throws {
        guard skillPoints > 0 else { throw VoyageError.noSkillPoints }
        guard skill(s) < VoyageConfig.maxSkill else { throw VoyageError.maxLevel }
        skills[s.rawValue] = skill(s) + 1
    }
    public mutating func rename(_ name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { shipName = String(n.prefix(12)) }
    }

    // MARK: 鱼缸（在港才能从鱼舱转移）
    public mutating func keepInTank(_ id: UUID, now: Date) throws {
        guard phase == .docked || hasMethod(.liveWell) else { throw VoyageError.needsPort }
        guard tank.count < tankCapacity else { throw VoyageError.tankFull }
        guard let i = hold.firstIndex(where: { $0.id == id }) else { throw VoyageError.unknown }
        let f = hold.remove(at: i)
        tank.append(TankFish(fishID: f.fishID, kg: f.kg, caughtAt: f.caughtAt))
        let name = VoyageConfig.fish(f.fishID)?.name ?? ""
        log(tr("🐠 \(name) 住进了鱼缸", "🐠 \(name) moved into the aquarium"), now)
        checkQuests(now)
    }
    public mutating func release(tankIndex i: Int) { if tank.indices.contains(i) { tank.remove(at: i) } }
    public mutating func upgradeTank() throws {
        guard isFullVersion else { throw VoyageError.needsFullVersion }
        let c = VoyageConfig.tankUpgradeCost(level: tankLevel)
        guard coins >= c else { throw VoyageError.notEnoughCoins }
        coins -= c; tankLevel += 1
    }

    // MARK: 主动捕鱼
    /// quality：小游戏表现 0...1。返回钓到的鱼（nil = 跑了）
    @discardableResult
    public mutating func activeCatch(quality: Double, now: Date) -> HoldFish? {
        advance(to: now)
        guard phase == .fishing else { return nil }
        // v8：小游戏失败不丢鱼，只降低品质/体型（kgFactor 0.6…1.5）
        let q = max(0, min(1, quality))
        var report = VoyageReport()
        guard let t = pickFish(pool(at: now).isEmpty ? ocean.fish : pool(at: now), rare: rareMultiplier(at: now, active: q), now: now) else { return nil }
        activeCatches += 1
        fuel = max(0, fuel - 0.3)
        if hasMethod(.doubleHaul), q >= 0.6, let t2 = pickFish(pool(at: now).isEmpty ? ocean.fish : pool(at: now), rare: rareMultiplier(at: now, active: q), now: now) {
            stow(t2, kgFactor: 1, active: true, now: now, report: &report)   // 双网：好表现时多捞一条
        }
        return stow(t, kgFactor: VoyageConfig.activeKgFactor(quality: q), active: true, now: now, report: &report)
    }

    // MARK: 任务
    public func questProgress(_ q: Quest) -> Int {
        switch q.kind {
        case .catches: return totalFishCaught
        case .species: return codex.count
        case .earned: return coinsEarned
        case .active: return activeCatches
        case .ocean: return visitedOceans.contains(q.oceanID ?? "") ? 1 : 0
        case .trophies: return trophies
        case .portVisits: return portVisits
        case .tank: return tank.count
        }
    }
    private mutating func checkQuests(_ now: Date) {
        while let q = currentQuest, questProgress(q) >= q.target {
            coins += q.coins; gems += q.gems; questIndex += 1
            log(tr("📜 完成航海日志：\(q.title)  +\(q.coins) 金币 +\(q.gems)💎", "📜 Logbook goal done: \(q.title)  +\(q.coins) coins +\(q.gems)💎"), now)
        }
    }

    // MARK: 迁移旧存档（v1 多船队 → v2 单船）
    public static func migrate(_ old: GameState, now: Date) -> VoyageState {
        var s = VoyageState(now: now)
        s.coins = old.coins + 200; s.gems = old.gems
        s.codex = old.codex; s.tank = old.tank; s.tankLevel = old.tankLevel
        s.isFullVersion = old.isFullVersion; s.totalFishCaught = old.totalFishCaught
        var gl: [String: Int] = [GearType.trawl.rawValue: 1]
        for c in old.captains { for (k, v) in c.boat.gearLevels { gl[k] = max(gl[k] ?? 0, v) } }
        s.gearLevels = gl
        s.level = max(1, old.captains.map(\.level).max() ?? 1)
        let n = old.unlockedAreaIDs.count
        let oceans = min(VoyageConfig.oceans.count, max(1, Int((Double(n) * 6.0 / 8.0).rounded())))
        let allowed = s.isFullVersion ? oceans : min(oceans, VoyageConfig.freeOceanCount)
        s.unlockedOceans = VoyageConfig.oceans.prefix(allowed).map(\.id)
        s.parts[ShipPart.hull.rawValue] = allowed >= 6 ? 3 : (allowed >= 5 ? 2 : 1)
        s.rngState = old.rngState
        s.log(tr("🚢 船队合并成了一艘大渔船！旧船长们的经验与收藏都在", "🚢 Your fleet merged into one big trawler — all your progress and collection came along"), now)
        return s
    }
}
