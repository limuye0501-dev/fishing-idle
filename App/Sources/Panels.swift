import SwiftUI
import FishingCore

func seasonText(_ f: FishType) -> String {
    f.seasons.isEmpty ? tr("四季", "All year") : f.seasons.map { $0.emoji + $0.name }.joined(separator: "")
}
func gearText(_ f: FishType) -> String { f.gears.map { $0.emoji }.joined() }
func rarityColor(_ r: Rarity) -> Color {
    switch r { case .common: .gray; case .rare: .blue; case .epic: .purple; case .legendary: .orange }
}

/// 面板外壳
struct PanelSheet: View {
    @EnvironmentObject var game: GameViewModel
    let panel: Panel
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.system(.title3, design: .serif).bold()).foregroundStyle(Theme.navy)
                Spacer()
                Button { game.panel = nil } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                        .frame(width: 30, height: 30).background(Theme.creamDeep, in: Circle())
                }
                .accessibilityLabel(tr("关闭", "Close"))
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 8)
            ScrollView {
                Group {
                    switch panel {
                    case .chart: ChartPanel()
                    case .gear: GearPanel()
                    case .dock: DockPanel()
                    case .codex: CodexView()
                    case .tank: AquariumView()
                    case .log: LogPanel()
                    case .hold: HoldPanel()
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .foregroundStyle(Theme.ink)
    }
    private var title: String {
        switch panel {
        case .chart: tr("🗺️ 海图", "🗺️ Chart")
        case .gear: tr("🎣 渔具", "🎣 Gear")
        case .dock: tr("🔧 船坞与船员", "🔧 Dock & Crew")
        case .codex: tr("📖 图鉴", "📖 Codex")
        case .tank: tr("🐠 鱼缸", "🐠 Aquarium")
        case .log: tr("📜 航海日志", "📜 Logbook")
        case .hold: tr("📦 鱼舱", "📦 Hold")
        }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.45), lineWidth: 1))
    }
}

struct PillButton: View {
    let title: String
    var tint: Color = Theme.coral
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(.caption, design: .rounded).bold()).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(enabled ? tint : Color.gray.opacity(0.5), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// v9：点一下升 1 级；长按 0.4 秒后连续升级，直到钱不够或满级
struct RepeatPillButton: View {
    let title: String
    var tint: Color = Theme.coral
    var enabled = true
    let tap: () -> Void
    let repeatStep: () -> Bool
    @State private var timer: Timer?
    @State private var repeating = false
    var body: some View {
        Text(title).font(.system(.caption, design: .rounded).bold()).foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(enabled ? (repeating ? Theme.teal : tint) : Color.gray.opacity(0.5), in: Capsule())
            .scaleEffect(repeating ? 1.08 : 1)
            .onTapGesture { if enabled { tap() } }
            .onLongPressGesture(minimumDuration: 0.4, perform: {}, onPressingChanged: { pressing in
                if pressing && enabled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        guard timer == nil else { return }
                        repeating = true
                        timer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { t in
                            MainActor.assumeIsolated { if !repeatStep() { t.invalidate(); timer = nil; repeating = false } }
                        }
                    }
                } else { timer?.invalidate(); timer = nil; repeating = false }
            })
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(tr("长按连续升级", "Long-press to upgrade repeatedly"))
            .accessibilityAction { if enabled { tap() } }
    }
}

// MARK: - 海图：选择大洋、解锁、航行
struct ChartPanel: View {
    @EnvironmentObject var game: GameViewModel
    var body: some View {
        let s = game.state
        VStack(spacing: 10) {
            MiniMapView(state: s, expanded: true)
            if s.phase != .docked {
                Card {
                    HStack {
                        Text(tr("⚓️ 返回母港", "⚓️ Return to home port")).font(.headline)
                        Spacer()
                        PillButton(title: tr("返航 \(formatDuration(s.travelSeconds(to: "port")))", "Go · \(formatDuration(s.travelSeconds(to: "port")))"),
                                   tint: Theme.navy, enabled: s.phase == .fishing) { game.sail(to: "port") }
                    }
                    Text(tr("回港可以全价卖鱼、便宜加油、改装船只、把鱼放进鱼缸。不回港也没关系，收购船会来海上收鱼。", "In port you get full prices, cheap fuel, refits and the aquarium. Staying out is fine too — a carrier ship buys fish at sea."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(Array(VoyageConfig.oceans.enumerated()), id: \.element.id) { i, o in
                OceanCard(ocean: o, index: i)
            }
        }
    }
}

struct OceanCard: View {
    @EnvironmentObject var game: GameViewModel
    let ocean: Ocean
    let index: Int
    var body: some View {
        let s = game.state
        let unlocked = s.unlockedOceans.contains(ocean.id)
        let here = s.oceanID == ocean.id && s.phase == .fishing
        Card {
            HStack {
                Text(ocean.name).font(.system(.headline, design: .serif))
                if ocean.polar { Text("🧊").font(.caption) }
                Spacer()
                if here {
                    Text(tr("📍 作业中", "📍 Fishing here")).font(.caption.bold()).foregroundStyle(Theme.teal)
                } else if unlocked {
                    let blocked = s.canEnter(ocean)
                    PillButton(title: blocked != nil ? GameViewModel.message(blocked!) : tr("前往 \(formatDuration(s.travelSeconds(to: ocean.id)))", "Sail · \(formatDuration(s.travelSeconds(to: ocean.id)))"),
                               tint: Theme.teal, enabled: blocked == nil && s.phase != .sailing) { game.sail(to: ocean.id) }
                } else if index >= VoyageConfig.freeOceanCount && !s.isFullVersion {
                    FullVersionBadge()
                } else {
                    PillButton(title: tr("解锁 \(ocean.unlockCost.formatted())", "Unlock \(ocean.unlockCost.formatted())"),
                               enabled: s.coins >= ocean.unlockCost && s.codex.count >= ocean.speciesRequired) { game.unlock(ocean.id) }
                }
            }
            Text(ocean.blurb).font(.caption).foregroundStyle(.secondary)
            if !unlocked {
                Text(tr("条件：图鉴 \(s.codex.count)/\(ocean.speciesRequired) 种\(ocean.hullRequired > 1 ? " · 船体加固 \(ocean.hullRequired) 级" : "")",
                        "Needs: \(s.codex.count)/\(ocean.speciesRequired) species\(ocean.hullRequired > 1 ? " · Lv\(ocean.hullRequired) hull" : "")"))
                    .font(.caption2.bold()).foregroundStyle(Theme.coral)
            }
            Text(ocean.fish.map { s.codex[$0.id] != nil ? $0.emoji : "❔" }.joined(separator: " ")).font(.callout)
        }
    }
}

// MARK: - 渔具
struct GearPanel: View {
    @EnvironmentObject var game: GameViewModel
    var body: some View {
        let s = game.state
        VStack(spacing: 10) {
            Text(tr("船上所有渔具都会一起作业，能捕的鱼种更多；“主力渔具”决定挂机速度。买新渔具要回港。", "Every piece of gear on board works at once, widening which species you can catch; the main gear sets idle speed. Buy new gear in port."))
                .font(.caption).foregroundStyle(.secondary)
            ForEach(GearType.allCases, id: \.self) { g in
                let lv = s.gearLevels[g.rawValue]
                let cost = s.gearUpgradeCost(g)
                Card {
                    HStack {
                        Text("\(g.emoji) \(g.name)").font(.headline)
                        if let lv { Text("Lv\(lv)").font(.caption.bold()).foregroundStyle(Theme.teal) }
                        Spacer()
                        if lv != nil {
                            if s.equipped == g { Text(tr("主力", "Main")).font(.caption.bold()).foregroundStyle(Theme.coral) }
                            else { PillButton(title: tr("设为主力", "Make main"), tint: Theme.navy) { game.equip(g) } }
                        }
                        if !VoyageConfig.freeGear.contains(g) && !s.isFullVersion && lv == nil { FullVersionBadge() }
                        else if (lv ?? 0) < 5 {
                            PillButton(title: (lv == nil ? tr("购买 ", "Buy ") : tr("升级 ", "Upgrade ")) + (cost.gems > 0 ? "\(cost.gems)💎" : "\(cost.coins.formatted())🪙"),
                                       enabled: s.phase == .docked && s.coins >= cost.coins && s.gems >= cost.gems) { game.buyGear(g) }
                        }
                    }
                    let fish = s.ocean.fish.filter { $0.gears.contains(g) }
                    Text(tr("在\(s.ocean.zhName)可捕：", "Catches here: ") + (fish.isEmpty ? "—" : fish.map { $0.emoji + $0.name }.joined(separator: " ")))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            if s.phase != .docked {
                Text(tr("⚓️ 在海上只能更换主力渔具，买和升级要回港。", "⚓️ At sea you can only switch main gear; buying and upgrading happen in port."))
                    .font(.caption2.bold()).foregroundStyle(Theme.coral)
            }
        }
    }
}

// MARK: - 船坞（改装 + 船员技能 + 补给）
struct DockPanel: View {
    @EnvironmentObject var game: GameViewModel
    var body: some View {
        let s = game.state
        VStack(spacing: 10) {
            Card {
                HStack {
                    Text(tr("⛽️ 燃油 \(Int(s.fuel))/\(Int(s.fuelCapacity))", "⛽️ Fuel \(Int(s.fuel))/\(Int(s.fuelCapacity))")).font(.headline)
                    Spacer()
                    let c = s.refuelCost()
                    PillButton(title: tr("加满 \(c)🪙", "Fill up \(c)🪙"), tint: Theme.teal,
                               enabled: c > 0 && s.coins >= c && (s.phase == .docked || s.carrierAvailable(now: Date()) || s.fuel <= 0)) { game.refuel() }
                }
                Text(s.phase == .docked ? tr("港口油价 1 金币/升", "Port price: 1 coin per unit")
                                        : tr("海上向收购船买油，3 金币/升（和收鱼共用冷却）", "At sea the carrier sells fuel at 3 coins/unit (shares its cooldown)"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Text(tr("船只改装", "Ship refits")).font(.system(.headline, design: .serif)).frame(maxWidth: .infinity, alignment: .leading)
            if s.phase != .docked {
                Text(tr("⚓️ 改装需要在母港进行", "⚓️ Refits happen in home port")).font(.caption.bold()).foregroundStyle(Theme.coral)
            }
            ForEach(ShipPart.allCases, id: \.self) { p in
                let lv = s.part(p)
                Card {
                    HStack {
                        Text("\(p.emoji) \(p.name)").font(.headline)
                        Text("Lv\(lv)").font(.caption.bold()).foregroundStyle(Theme.teal)
                        Spacer()
                        if lv >= VoyageConfig.maxPartLevel { Text(tr("已满级", "Max level")).font(.caption) }
                        else if lv >= s.maxPartLevel { FullVersionBadge() }
                        else {
                            let c = VoyageConfig.partCost(p, level: lv)
                            RepeatPillButton(title: "\(c.formatted())🪙", enabled: s.phase == .docked && s.coins >= c,
                                             tap: { game.upgrade(p) }, repeatStep: { game.upgradeRepeat(p) })
                        }
                    }
                    Text(p.desc).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(tr("船员技能（剩余 \(s.skillPoints) 点）", "Crew skills (\(s.skillPoints) points left)")).font(.system(.headline, design: .serif))
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(CrewSkill.allCases, id: \.self) { k in
                Card {
                    HStack {
                        Text(k.name).font(.headline)
                        Text(String(repeating: "●", count: s.skill(k)) + String(repeating: "○", count: VoyageConfig.maxSkill - s.skill(k)))
                            .font(.caption).foregroundStyle(Theme.gold)
                        Spacer()
                        PillButton(title: "+1", tint: Theme.navy, enabled: s.skillPoints > 0 && s.skill(k) < VoyageConfig.maxSkill) { game.learn(k) }
                    }
                    Text(k.desc).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - 鱼舱：卖鱼
struct HoldPanel: View {
    @EnvironmentObject var game: GameViewModel
    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { ctx in
            let s = game.state
            let now = ctx.date
            VStack(spacing: 10) {
                Card {
                    HStack {
                        Text(tr("舱内 \(s.hold.count)/\(s.holdCapacity) 条 · 估值 \(s.holdValue(now: now).formatted())🪙", "\(s.hold.count)/\(s.holdCapacity) fish · worth \(s.holdValue(now: now).formatted())🪙"))
                            .font(.headline)
                    }
                    if s.phase == .docked {
                        PillButton(title: tr("鱼市全价卖出", "Sell at the market (full price)"), tint: Theme.teal, enabled: !s.hold.isEmpty) { game.sell() }
                    } else if s.carrierAvailable(now: now) {
                        PillButton(title: tr("呼叫收购船（75% 价格）", "Call the carrier (75% price)"), tint: Theme.teal, enabled: !s.hold.isEmpty) { game.sell() }
                    } else {
                        let left = VoyageConfig.carrierCooldown - now.timeIntervalSince(s.lastCarrier)
                        HStack {
                            Text(tr("收购船 \(formatDuration(left)) 后到", "Carrier back in \(formatDuration(left))")).font(.caption)
                            Spacer()
                            PillButton(title: tr("加急 \(VoyageConfig.carrierGemCost)💎", "Rush \(VoyageConfig.carrierGemCost)💎"), tint: .purple,
                                       enabled: !s.hold.isEmpty && s.gems >= VoyageConfig.carrierGemCost) { game.sell(useGems: true) }
                        }
                    }
                    Text(tr("鱼会慢慢不新鲜（最低 30% 价），冰柜越好保鲜越久。舱满后船员会把小鱼放生，只留更值钱的。",
                            "Fish lose freshness over time (down to 30% value); a better icebox keeps them longer. When the hold is full the crew releases smaller fish and keeps the valuable ones."))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(s.hold.sorted { s.value($0, now: now) > s.value($1, now: now) }) { f in
                    let t = VoyageConfig.fish(f.fishID)
                    HStack {
                        Text("\(t?.emoji ?? "🐟") \(t?.name ?? f.fishID)").font(.callout.bold())
                        if f.kg >= (t?.baseKg ?? 1) * VoyageConfig.trophyFactor { Text("🏆").font(.caption) }
                        if f.active { Text("🎯").font(.caption) }
                        Text(formatKg(f.kg)).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("❄︎\(Int(s.freshness(f, now: now) * 100))%").font(.caption2).foregroundStyle(.blue)
                        Text("\(s.value(f, now: now))🪙").font(.caption.bold()).monospacedDigit()
                        if s.phase == .docked {
                            Button { game.keep(f.id) } label: { Image(systemName: "drop.fill").foregroundStyle(Theme.teal) }
                                .accessibilityLabel(tr("放进鱼缸", "Move to aquarium"))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

// MARK: - 日志：任务 + 事件
struct LogPanel: View {
    @EnvironmentObject var game: GameViewModel
    var body: some View {
        let s = game.state
        VStack(alignment: .leading, spacing: 10) {
            if let q = s.currentQuest {
                Card {
                    Text(tr("当前目标", "Current goal")).font(.caption.bold()).foregroundStyle(Theme.coral)
                    Text(q.title).font(.headline)
                    ProgressView(value: Double(min(q.target, s.questProgress(q))), total: Double(q.target)).tint(Theme.teal)
                    Text(tr("\(min(q.target, s.questProgress(q)))/\(q.target) · 奖励 \(q.coins.formatted())🪙 \(q.gems)💎", "\(min(q.target, s.questProgress(q)))/\(q.target) · reward \(q.coins.formatted())🪙 \(q.gems)💎"))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Card {
                Text(tr("航海统计", "Voyage stats")).font(.headline)
                Text(tr("累计 \(s.totalFishCaught) 条 · 亲手钓 \(s.activeCatches) 条 · 纪录大鱼 \(s.trophies) 条 · 回港 \(s.portVisits) 次",
                        "\(s.totalFishCaught) fish · \(s.activeCatches) by hand · \(s.trophies) trophies · \(s.portVisits) port visits")).font(.caption)
            }
            if s.eventLog.isEmpty {
                Text(tr("海上风平浪静，暂时没有新鲜事", "Calm seas — nothing new yet")).foregroundStyle(.secondary)
            }
            ForEach(Array(s.eventLog.enumerated()), id: \.offset) { _, e in
                HStack(alignment: .top) {
                    Text(e.date, style: .time).font(.caption2).foregroundStyle(.secondary).frame(width: 48, alignment: .leading)
                    Text(e.text).font(.caption)
                }
            }
        }
    }
}

// MARK: - 图鉴（按大洋）
struct CodexView: View {
    @EnvironmentObject var game: GameViewModel
    var body: some View {
        VStack(spacing: 10) {
            Text(tr("已收集 \(game.state.codex.count)/\(VoyageConfig.allFish.count) 种", "\(game.state.codex.count)/\(VoyageConfig.allFish.count) species discovered"))
                .font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(VoyageConfig.oceans) { o in
                Card {
                    HStack {
                        Text(o.name).font(.system(.headline, design: .serif))
                        Spacer()
                        Text("\(o.fish.filter { game.state.codex[$0.id] != nil }.count)/\(o.fish.count)").font(.caption).foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                        ForEach(o.fish) { f in
                            FishCard(fish: f, entry: game.state.codex[f.id], season: game.season)
                                .onTapGesture { game.encyclopediaFish = f.id }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(game.state.codex[f.id] != nil ? f.name : tr("未知鱼种", "Unknown species"))
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction { game.encyclopediaFish = f.id }
                        }
                    }
                }
            }
        }
    }
}

struct FishCard: View {
    let fish: FishType
    let entry: CodexEntry?
    let season: Season
    var body: some View {
        VStack(spacing: 2) {
            if entry != nil, let img = Encyclopedia.photo("fish_\(fish.id)") {
                Image(uiImage: img).resizable().scaledToFill().frame(width: 40, height: 28).clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Text(entry == nil ? "❔" : fish.emoji).font(.title3).frame(height: 28)
            }
            Text(entry == nil ? "???" : fish.name).font(.caption2.bold()).lineLimit(1).minimumScaleFactor(0.6)
            Text(fish.rarity.name).font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 4).background(rarityColor(fish.rarity).opacity(0.25), in: Capsule())
            if let e = entry {
                Text("×\(e.count) · \(formatKg(e.bestKg))").font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
            } else {
                Text(gearText(fish) + " " + seasonText(fish)).font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(entry == nil ? Color.gray.opacity(0.12) : Theme.cream, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(entry == nil ? Color.clear : rarityColor(fish.rarity).opacity(0.5), lineWidth: 1))
    }
}

// MARK: - 鱼缸
struct AquariumView: View {
    @EnvironmentObject var game: GameViewModel
    var body: some View {
        let s = game.state
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tr("🐠 生态鱼缸 \(s.tank.count)/\(s.tankCapacity)", "🐠 Aquarium \(s.tank.count)/\(s.tankCapacity)")).font(.headline)
                Spacer()
                let cost = VoyageConfig.tankUpgradeCost(level: s.tankLevel)
                if !game.isFullVersion { FullVersionBadge() } else {
                    PillButton(title: tr("扩容 +2（\(cost.formatted())）", "Expand +2 (\(cost.formatted()))"), tint: Theme.teal, enabled: s.coins >= cost) { game.upgradeTank() }
                }
            }
            ZStack {
                Aquarium3D(ids: s.tank.map(\.fishID)) { game.encyclopediaFish = $0 }
                if s.tank.isEmpty {
                    Text(tr("鱼缸空空的～回港时从鱼舱挑几条吧", "The aquarium is empty — pick a few from the hold in port")).font(.caption).foregroundStyle(.white)
                }
            }
            .background(LinearGradient(colors: [Color(red: 0.70, green: 0.94, blue: 0.93), Color(red: 0.20, green: 0.58, blue: 0.70)], startPoint: .top, endPoint: .bottom))
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Text(tr("回港后可以在鱼舱里点 💧 把喜欢的鱼放进鱼缸。点鱼看小百科。", "In port, tap 💧 on a fish in the hold to move it here. Tap a fish to read about it."))
                .font(.caption2).foregroundStyle(.secondary)
            ForEach(s.tank) { t in
                let f = game.fish(t.fishID)
                HStack {
                    Text("\(f?.emoji ?? "🐟") \(f?.name ?? t.fishID) · \(formatKg(t.kg))").font(.caption)
                    Spacer()
                    Button(tr("放生", "Release")) { game.release(t.id) }.font(.caption2)
                }
            }
        }
    }
}

/// 简单 2D 游动：每条鱼按自己的相位做正弦往返
struct TankScene: View {
    let tank: [TankFish]
    let onTap: (String) -> Void

    private func swimmer(_ f: TankFish, index i: Int, t: Double, w: CGFloat, h: CGFloat) -> some View {
        let seed: Double = Double(abs(f.id.hashValue % 1000)) / 1000.0
        let omega: Double = (0.15 + 0.1 * seed) * 2.0 * Double.pi / 3.0
        let angle: Double = t * omega + seed * 6.28
        let x: Double = 0.5 + 0.42 * sin(angle)
        let goingRight: Bool = cos(angle) > 0
        let row: Double = Double(i % 5) / 4.0
        let y: Double = 0.2 + 0.6 * row + 0.04 * sin(t * 1.7 + seed * 10.0)
        let emoji: String = VoyageConfig.fish(f.fishID)?.emoji ?? "🐟"
        return Text(emoji)
            .font(.system(size: 28))
            .scaleEffect(x: goingRight ? -1 : 1, y: 1)
            .position(x: CGFloat(x) * w, y: CGFloat(y) * (h - 20))
            .onTapGesture { onTap(f.fishID) }
            .accessibilityLabel(VoyageConfig.fish(f.fishID)?.name ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onTap(f.fishID) }
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    LinearGradient(colors: [Color(red: 0.62, green: 0.92, blue: 0.93), Color(red: 0.16, green: 0.58, blue: 0.66)],
                                   startPoint: .top, endPoint: .bottom)
                    Rectangle().fill(Color(red: 0.95, green: 0.88, blue: 0.70)).frame(height: 16)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    ForEach(0..<5, id: \.self) { k in
                        Text("🌿").font(.title2)
                            .rotationEffect(.degrees(sin(t * 1.3 + Double(k)) * 8), anchor: .bottom)
                            .position(x: w * CGFloat(0.1 + 0.2 * Double(k)), y: h - 22)
                    }
                    ForEach(0..<6, id: \.self) { k in
                        let phase = (t * 0.25 + Double(k) * 0.37).truncatingRemainder(dividingBy: 1)
                        Circle().stroke(Color.white.opacity(0.6), lineWidth: 1).frame(width: 5, height: 5)
                            .position(x: w * CGFloat(0.15 + 0.14 * Double(k)), y: h * CGFloat(1 - phase))
                    }
                    if tank.isEmpty {
                        Text(tr("鱼缸空空的～回港时从鱼舱挑几条吧", "The aquarium is empty — pick a few from the hold in port")).font(.caption).foregroundStyle(.white)
                    }
                    ForEach(Array(tank.enumerated()), id: \.element.id) { i, f in
                        swimmer(f, index: i, t: t, w: w, h: h)
                    }
                }
            }
        }
    }
}

/// 完整版标记：点按进入购买流程
struct FullVersionBadge: View {
    @EnvironmentObject var game: GameViewModel
    var body: some View {
        PillButton(title: tr("🔓 完整版", "🔓 Full Version"), tint: .orange) { game.purchaseFullVersion() }
    }
}

func formatKg(_ kg: Double) -> String {
    kg >= 1000 ? String(format: tr("%.1f吨", "%.1f t"), kg / 1000) : (kg >= 10 ? String(format: "%.0fkg", kg) : (kg >= 0.1 ? String(format: "%.2fkg", kg) : String(format: "%.0fg", kg * 1000)))
}
