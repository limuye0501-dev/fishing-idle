import Foundation

// MARK: - v9：离线稀有事件、闪光变种、纪录、船猫、装饰与涂装

public struct RareEvent: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case bottle, whales, aurora, legendaryTrace, stormSurvived, shiny, record }
    public let kind: Kind
    public let text: String
    public let date: Date
    public var emoji: String {
        switch kind { case .bottle: "🍾"; case .whales: "🐋"; case .aurora: "🌌"; case .legendaryTrace: "✨"; case .stormSurvived: "⛈️"; case .shiny: "🌈"; case .record: "🏆" }
    }
}

/// 一条纪录鱼（用于分享卡）
public struct RecordCatch: Codable, Hashable, Sendable {
    public let fishID: String
    public let kg: Double
    public let date: Date
    public let weather: Weather
    public let oceanID: String
    public let shiny: Bool
}

public struct VoyageExtras: Codable, Hashable, Sendable {
    public var notes: [Int] = []                 // 收集到的漂流瓶纸条
    public var lastWeatherHour = -1
    public var lastWasStorm = false
    public var catLastPet: Date? = nil
    public var catHearts = 0
    public var catBonusUntil: Date? = nil
    public var shinies: [String: Int] = [:]
    public var records: [String: RecordCatch] = [:]
    public var decor: [String] = []              // 鱼缸装饰
    public var paints: [String] = ["classic"]    // 船体涂装
    public var paint = "classic"
    public var whalesUntil: Date? = nil
    public init() {}
}

public struct BottleNote: Sendable {
    public let id: Int
    public let zh: String, en: String
    public var text: String { tr(zh, en) }
}

public struct Decoration: Sendable, Identifiable {
    public let id: String, emoji: String, zh: String, en: String, cost: Int
    public var name: String { tr(zh, en) }
}
public struct HullPaint: Sendable, Identifiable {
    public let id: String, zh: String, en: String, cost: Int
    /// RGB 0…1（3D 侧可按此给船身着色）
    public let hull: (Double, Double, Double), stripe: (Double, Double, Double)
    public var name: String { tr(zh, en) }
}

extension VoyageConfig {
    public static let shinyChance = 0.004
    public static let shinyValueFactor = 5.0
    public static let bottleChance = 0.05        // 每小时
    public static let whaleChance = 0.05
    public static let auroraChance = 0.25        // 极地夜晚每小时
    public static let stormSurvivedCoins = 150
    public static let catBonusSeconds: Double = 3600
    public static let catBonusFactor = 1.10      // 撸猫后 1 小时挂机 +10%
    public static let decorBonusEach = 0.02      // 每件鱼缸装饰卖鱼 +2%

    public static let bottleNotes: [BottleNote] = [
        .init(id: 0, zh: "“给捡到这个瓶子的人：今天的海很温柔。”", en: "\"To whoever finds this: the sea was gentle today.\""),
        .init(id: 1, zh: "一张褪色的海图，角落画着一条会笑的鲸。", en: "A faded chart with a smiling whale doodled in the corner."),
        .init(id: 2, zh: "“我的猫又偷吃了我的沙丁鱼。”——某位船长", en: "\"My cat stole my sardines again.\" — a captain"),
        .init(id: 3, zh: "一首写给灯塔的小诗。", en: "A short poem written to a lighthouse."),
        .init(id: 4, zh: "“北边的冰化了，企鹅们在开会。”", en: "\"The ice up north melted; the penguins are holding a meeting.\""),
        .init(id: 5, zh: "孩子画的船，船上有一只橘猫。", en: "A child's drawing of a boat with an orange cat on it."),
        .init(id: 6, zh: "“如果你也在等晚霞，我们就算见过面了。”", en: "\"If you're also waiting for the sunset, then we've met.\""),
        .init(id: 7, zh: "一张写满潮汐时间的小纸片。", en: "A scrap of paper covered in tide times."),
        .init(id: 8, zh: "“深海里有一条发光的鱼，它认识我。”", en: "\"There's a glowing fish in the deep. It knows me.\""),
        .init(id: 9, zh: "一枚旧邮票，盖着已经不存在的港口邮戳。", en: "An old stamp, postmarked from a port that no longer exists."),
        .init(id: 10, zh: "“别着急回港，海会等你。”", en: "\"No need to hurry home. The sea will wait for you.\""),
        .init(id: 11, zh: "瓶底压着一张全家福，背面写着：平安。", en: "A family photo at the bottom; on the back: \"safe and sound\"."),
    ]

    public static let decorations: [Decoration] = [
        .init(id: "sand", emoji: "🏖️", zh: "细白沙", en: "White sand", cost: 2_000),
        .init(id: "kelp", emoji: "🌿", zh: "海带丛", en: "Kelp clump", cost: 5_000),
        .init(id: "shell", emoji: "🐚", zh: "大海螺", en: "Conch shell", cost: 12_000),
        .init(id: "coral", emoji: "🪸", zh: "珊瑚礁", en: "Coral reef", cost: 30_000),
        .init(id: "chest", emoji: "🧰", zh: "宝箱", en: "Treasure chest", cost: 75_000),
        .init(id: "castle", emoji: "🏰", zh: "小城堡", en: "Tiny castle", cost: 180_000),
        .init(id: "wreck", emoji: "⚓️", zh: "沉船残骸", en: "Shipwreck", cost: 420_000),
        .init(id: "lantern", emoji: "🏮", zh: "水下灯笼", en: "Underwater lantern", cost: 1_000_000),
        .init(id: "diver", emoji: "🤿", zh: "潜水员摆件", en: "Diver figurine", cost: 2_400_000),
        .init(id: "moon", emoji: "🌕", zh: "月光石", en: "Moonstone", cost: 5_500_000),
    ]

    public static let paints: [HullPaint] = [
        .init(id: "classic", zh: "经典白蓝", en: "Classic", cost: 0, hull: (0.95, 0.93, 0.88), stripe: (0.18, 0.55, 0.60)),
        .init(id: "coral", zh: "珊瑚粉", en: "Coral pink", cost: 8_000, hull: (0.98, 0.72, 0.66), stripe: (0.95, 0.95, 0.92)),
        .init(id: "mint", zh: "薄荷绿", en: "Mint", cost: 25_000, hull: (0.70, 0.92, 0.82), stripe: (0.20, 0.40, 0.45)),
        .init(id: "sunset", zh: "晚霞金", en: "Sunset gold", cost: 90_000, hull: (0.99, 0.80, 0.45), stripe: (0.85, 0.35, 0.30)),
        .init(id: "navy", zh: "深海蓝", en: "Deep navy", cost: 300_000, hull: (0.15, 0.22, 0.40), stripe: (0.95, 0.80, 0.40)),
        .init(id: "aurora", zh: "极光", en: "Aurora", cost: 1_200_000, hull: (0.45, 0.85, 0.75), stripe: (0.60, 0.40, 0.90)),
        .init(id: "pearl", zh: "珍珠", en: "Pearl", cost: 4_000_000, hull: (0.98, 0.96, 0.94), stripe: (0.80, 0.70, 0.85)),
        .init(id: "legend", zh: "传说之船", en: "Legendary", cost: 12_000_000, hull: (0.10, 0.10, 0.12), stripe: (0.95, 0.75, 0.25)),
    ]

    /// 全部金币去处总和（用于节奏测算，见 docs/progression-curve.md）
    public static var totalLongTermSink: Int {
        decorations.map(\.cost).reduce(0, +) + paints.map(\.cost).reduce(0, +)
    }
}

public enum CatPetResult: Equatable, Sendable { case petted(hearts: Int), sleepy }

extension VoyageState {
    // MARK: 稀有事件（每小时一次判定；离线时也会触发）
    mutating func rollRareEvents(_ now: Date, report: inout VoyageReport) {
        let w = weather(at: now)
        var e = ext
        defer { v9 = e }
        func add(_ k: RareEvent.Kind, _ text: String) {
            log(text, now)
            report.rareEvents.append(RareEvent(kind: k, text: text, date: now))
        }
        // 风暴过后
        if e.lastWasStorm && w != .storm {
            coins += VoyageConfig.stormSurvivedCoins
            add(.stormSurvived, tr("⛈️ 熬过了一场风暴，船员们在甲板上欢呼（+\(VoyageConfig.stormSurvivedCoins) 金币）",
                                  "⛈️ Weathered a storm — the crew cheered on deck (+\(VoyageConfig.stormSurvivedCoins) coins)"))
        }
        e.lastWasStorm = w == .storm
        // 漂流瓶
        if rand() < VoyageConfig.bottleChance {
            let missing = VoyageConfig.bottleNotes.map(\.id).filter { !e.notes.contains($0) }
            if let id = missing.first {
                e.notes.append(id)
                add(.bottle, tr("🍾 捞到一个漂流瓶：\(VoyageConfig.bottleNotes[id].zh)", "🍾 Fished up a bottle: \(VoyageConfig.bottleNotes[id].en)"))
            } else {
                coins += 50
                add(.bottle, tr("🍾 又捞到一个空漂流瓶（+50 金币）", "🍾 Another empty bottle (+50 coins)"))
            }
        }
        // 鲸群（非极地）：接下来 1 小时稀有鱼更多
        if !ocean.polar && rand() < VoyageConfig.whaleChance {
            e.whalesUntil = now.addingTimeInterval(3600)
            add(.whales, tr("🐋 一群鲸在船边喷水，鱼群跟着来了", "🐋 A pod of whales spouted beside the ship — fish followed them"))
        }
        // 极光（极地夜晚）
        if ocean.polar && dayPart(now) == .night && rand() < VoyageConfig.auroraChance {
            gems += 1
            add(.aurora, tr("🌌 夜空亮起了极光，船长看呆了（+1💎）", "🌌 The aurora lit up the night sky (+1💎)"))
        }
    }

    /// 捕获时：闪光变种与纪录
    mutating func noteCatch(_ f: HoldFish, type t: FishType, now: Date, report: inout VoyageReport) {
        var e = ext
        if f.isShiny {
            e.shinies[t.id, default: 0] += 1
            report.shinies += 1
            let text = tr("🌈 闪光变种！\(t.emoji)\(t.name)", "🌈 Shiny variant! \(t.emoji) \(t.name)")
            log(text, now); report.rareEvents.append(RareEvent(kind: .shiny, text: text, date: now))
        }
        let prev = e.records[t.id]?.kg ?? codex[t.id]?.bestKg ?? 0
        if (codex[t.id]?.count ?? 0) > 0, f.kg > prev, f.kg >= t.baseKg * VoyageConfig.trophyFactor {
            report.records.append(t.id)
            let text = tr("🏆 新纪录：\(t.emoji)\(t.name) \(String(format: "%.1f", f.kg)) kg", "🏆 New record: \(t.emoji) \(t.name) \(String(format: "%.1f", f.kg)) kg")
            log(text, now); report.rareEvents.append(RareEvent(kind: .record, text: text, date: now))
        }
        if f.kg > (e.records[t.id]?.kg ?? 0) {
            e.records[t.id] = RecordCatch(fishID: t.id, kg: f.kg, date: now, weather: weather(at: now), oceanID: oceanID, shiny: f.isShiny)
        }
        v9 = e
    }

    /// 鲸群/船猫带来的额外稀有度与速度
    public func moodRareFactor(at now: Date) -> Double { (ext.whalesUntil.map { $0 > now } ?? false) ? 1.5 : 1 }
    public func catSpeedFactor(at now: Date) -> Double { (ext.catBonusUntil.map { $0 > now } ?? false) ? VoyageConfig.catBonusFactor : 1 }
    public var decorSellBonus: Double { 1 + VoyageConfig.decorBonusEach * Double(ext.decor.count) }

    // MARK: 船猫
    public func canPetCat(now: Date) -> Bool {
        guard let last = ext.catLastPet else { return true }
        return localDay(last) != localDay(now)
    }
    func localDay(_ d: Date) -> Int { Int(floor((d.timeIntervalSince1970 + Double(utcOffset)) / 86_400)) }
    /// 每天第一次撸猫：+1 爱心、1 小时挂机 +10%；之后只是呼噜
    @discardableResult
    public mutating func petCat(now: Date) -> CatPetResult {
        advance(to: now)
        guard canPetCat(now: now) else { return .sleepy }
        var e = ext
        e.catLastPet = now; e.catHearts += 1; e.catBonusUntil = now.addingTimeInterval(VoyageConfig.catBonusSeconds)
        v9 = e
        log(tr("🐱 船猫蹭了蹭你（今天挂机 1 小时 +10%）", "🐱 The ship's cat purred (+10% idle catch for 1 h)"), now)
        return .petted(hearts: e.catHearts)
    }

    // MARK: 金币去处
    public mutating func buyDecoration(_ id: String) throws {
        guard let d = VoyageConfig.decorations.first(where: { $0.id == id }) else { throw VoyageError.unknown }
        guard !ext.decor.contains(id) else { throw VoyageError.maxLevel }
        guard coins >= d.cost else { throw VoyageError.notEnoughCoins }
        coins -= d.cost; ext.decor.append(id)
    }
    public mutating func buyOrApplyPaint(_ id: String) throws {
        guard let p = VoyageConfig.paints.first(where: { $0.id == id }) else { throw VoyageError.unknown }
        if !ext.paints.contains(id) {
            guard coins >= p.cost else { throw VoyageError.notEnoughCoins }
            coins -= p.cost; ext.paints.append(id)
        }
        ext.paint = id
    }
    public var notesCollected: [BottleNote] { ext.notes.compactMap { i in VoyageConfig.bottleNotes.first { $0.id == i } } }
}
