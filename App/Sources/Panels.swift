import SwiftUI
import FishingCore

// MARK: - 渔具

struct GearPanel: View {
    @EnvironmentObject var game: GameViewModel

    var body: some View {
        let caps = game.state.captains
        let selected = caps.first { $0.id == game.gearCaptainID } ?? caps.first
        VStack(alignment: .leading, spacing: 8) {
            if let c = selected {
                Picker("船长", selection: Binding(get: { c.id }, set: { game.gearCaptainID = $0 })) {
                    ForEach(caps) { Text("⛵️\($0.name)").tag($0.id) }
                }.pickerStyle(.segmented)
                ForEach(GearType.allCases, id: \.self) { g in
                    GearRow(captain: c, gear: g)
                }
            }
        }
    }
}

struct GearRow: View {
    @EnvironmentObject var game: GameViewModel
    let captain: Captain
    let gear: GearType

    var body: some View {
        let cfg = game.config
        let lv = captain.boat.gearLevel(gear)
        let equipped = captain.boat.equipped == gear
        let area = cfg.area(captain.areaID)
        let pool = area?.candidates(gear: gear, season: game.season) ?? []
        HStack(alignment: .top) {
            Text(gear.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(gear.name).font(.subheadline.bold())
                    if lv > 0 { Text("Lv\(lv)").font(.caption2.bold()) }
                    Text("渔获×\(String(format: "%.2f", cfg.gearCatchMultiplier(gear) * (1 + cfg.gearLevelBonus * Double(max(1, lv) - 1))))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Text(gear.detail).font(.caption2).foregroundStyle(.secondary)
                Text("\(area?.name ?? "")·\(game.season.name)季可捕：" + (pool.isEmpty ? "无" : pool.map { $0.emoji + $0.name }.joined(separator: " ")))
                    .font(.caption2).foregroundStyle(pool.isEmpty ? .red : .primary).lineLimit(2)
            }
            Spacer()
            VStack(spacing: 4) {
                if lv == 0 {
                    let p = cfg.gearPrice(gear)
                    Button(p.gems > 0 ? "购买 \(p.gems)💎" : "购买 \(p.coins)") { game.buyGear(gear, captain.id) }
                        .disabled(game.state.coins < p.coins || game.state.gems < p.gems)
                } else {
                    if equipped {
                        Text("使用中").font(.caption.bold()).foregroundStyle(.green)
                    } else {
                        Button("装备") { game.equipGear(gear, captain.id) }
                    }
                    if lv < cfg.maxGearLevel {
                        let cost = cfg.gearUpgradeCost(gear, level: lv)
                        Button("↑\(cost)") { game.upgradeGear(gear, captain.id) }
                            .disabled(game.state.coins < cost)
                    }
                }
            }
            .buttonStyle(.bordered).font(.caption)
        }
        .padding(8)
        .background(Color.white.opacity(equipped ? 0.8 : 0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 海图

struct SeaMapView: View {
    @EnvironmentObject var game: GameViewModel
    @State private var selected: String = "bay"

    var body: some View {
        let cfg = game.config
        VStack(spacing: 8) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let port = CGPoint(x: w * 0.5, y: h * 0.97)
                ZStack {
                    LinearGradient(colors: [Color(red: 0.05, green: 0.2, blue: 0.45), Color(red: 0.25, green: 0.7, blue: 0.85)],
                                   startPoint: .top, endPoint: .bottom)
                    ForEach(cfg.areas) { a in
                        Path { p in
                            p.move(to: port)
                            p.addLine(to: CGPoint(x: a.mapX * w, y: a.mapY * h))
                        }
                        .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    Text("⚓️港口").font(.caption2.bold()).foregroundStyle(.white).position(port)
                    ForEach(cfg.areas) { a in
                        let unlocked = game.state.unlockedAreaIDs.contains(a.id)
                        let boats = game.state.captains.filter { $0.areaID == a.id }.count
                        VStack(spacing: 0) {
                            Text(unlocked ? (boats > 0 ? "⛵️×\(boats)" : "🏝️") : "🔒").font(.caption)
                            Text(a.name).font(.system(size: 10, weight: .bold))
                            Text("\(Int(a.distance))海里").font(.system(size: 9))
                        }
                        .foregroundStyle(.white)
                        .padding(3)
                        .background((selected == a.id ? Color.orange : Color.black.opacity(0.35)), in: RoundedRectangle(cornerRadius: 6))
                        .position(x: a.mapX * w, y: a.mapY * h)
                        .onTapGesture { selected = a.id }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(height: 200)
            if let a = cfg.area(selected) { AreaDetail(area: a) }
        }
    }
}

struct AreaDetail: View {
    @EnvironmentObject var game: GameViewModel
    let area: SeaArea

    var body: some View {
        let cfg = game.config
        let unlocked = game.state.unlockedAreaIDs.contains(area.id)
        let oneWay = area.distance / cfg.baseSpeed
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(area.name).font(.headline)
                Spacer()
                if unlocked {
                    Text("已解锁").font(.caption).foregroundStyle(.green)
                } else {
                    Button("解锁 \(area.unlockCost)") { game.unlock(area.id) }
                        .buttonStyle(.borderedProminent).font(.caption)
                        .disabled(game.state.coins < area.unlockCost)
                }
            }
            Text(area.blurb).font(.caption).foregroundStyle(.secondary)
            Text("距离 \(Int(area.distance)) 海里 · 航程约 \(Int(oneWay.rounded())) 秒（初始船速，单程）")
                .font(.caption2)
            ForEach(area.fish) { f in
                HStack(spacing: 4) {
                    Text(f.emoji + f.name).font(.caption2.bold())
                    Text(f.rarity.name).font(.system(size: 9)).foregroundStyle(rarityColor(f.rarity))
                    Spacer()
                    Text(gearText(f) + " " + seasonText(f) + " · \(f.value)💰").font(.caption2)
                }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 生态鱼缸

struct AquariumView: View {
    @EnvironmentObject var game: GameViewModel

    var body: some View {
        let cfg = game.config
        let cap = game.state.tankCapacity(config: cfg)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🐠 生态鱼缸 \(game.state.tank.count)/\(cap)").font(.headline)
                Spacer()
                Text("游客门票 +\(String(format: "%.2f", game.state.tankIncomePerSecond(config: cfg)))/秒")
                    .font(.caption).foregroundStyle(.orange)
            }
            TankScene(tank: game.state.tank) { game.encyclopediaFish = $0 }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack {
                Text("物种越多游客越多（同种不叠加）。点鱼看小百科。").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                let cost = cfg.tankUpgradeCost(level: game.state.tankLevel)
                Button("扩容 +\(cfg.tankCapacityPerLevel)（\(cost)）") { game.upgradeTank() }
                    .buttonStyle(.bordered).font(.caption)
                    .disabled(game.state.coins < cost)
            }
            if !game.state.tank.isEmpty {
                Text("鱼缸里的鱼").font(.subheadline.bold())
                ForEach(game.state.tank) { t in
                    let f = game.fish(t.fishID)
                    HStack {
                        Text("\(f?.emoji ?? "🐟") \(f?.name ?? t.fishID) · \(formatKg(t.kg))").font(.caption)
                        Spacer()
                        Button("放生") { game.release(t.id) }.font(.caption2)
                    }
                }
            }
            Text("最近渔获（留下最好的一条，不卖）").font(.subheadline.bold())
            ForEach(Array(game.state.recentCatches.prefix(8).enumerated()), id: \.offset) { i, r in
                HStack {
                    Text("\(r.fishEmoji)\(r.fishName)").font(.caption)
                    if let kg = r.kg { Text(formatKg(kg)).font(.caption2).foregroundStyle(.secondary) }
                    Text("· \(r.captainName)").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    if r.kept == true {
                        Text("已入缸").font(.caption2).foregroundStyle(.green)
                    } else if r.fishID != nil {
                        Button("留下 −\(r.sellValue ?? 0)") { game.keep(i) }
                            .font(.caption2).buttonStyle(.bordered)
                            .disabled(game.state.tank.count >= cap || game.state.coins < (r.sellValue ?? 0))
                    }
                }
            }
        }
    }
}

/// 简单 2D 游动：每条鱼按自己的相位做正弦往返
struct TankScene: View {
    let tank: [TankFish]
    let onTap: (String) -> Void

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    LinearGradient(colors: [Color(red: 0.55, green: 0.88, blue: 0.95), Color(red: 0.05, green: 0.45, blue: 0.6)],
                                   startPoint: .top, endPoint: .bottom)
                    // 沙底与水草
                    Rectangle().fill(Color(red: 0.93, green: 0.85, blue: 0.62)).frame(height: 14)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    ForEach(0..<5, id: \.self) { k in
                        Text("🌿").font(.title2)
                            .rotationEffect(.degrees(sin(t * 1.3 + Double(k)) * 8), anchor: .bottom)
                            .position(x: w * (0.1 + 0.2 * Double(k)), y: h - 22)
                    }
                    ForEach(0..<6, id: \.self) { k in
                        let phase = (t * 0.25 + Double(k) * 0.37).truncatingRemainder(dividingBy: 1)
                        Circle().stroke(Color.white.opacity(0.6), lineWidth: 1).frame(width: 5, height: 5)
                            .position(x: w * (0.15 + 0.14 * Double(k)), y: h * (1 - phase))
                    }
                    if tank.isEmpty {
                        Text("鱼缸空空的～去“最近渔获”里留几条吧").font(.caption).foregroundStyle(.white)
                    }
                    ForEach(Array(tank.enumerated()), id: \.element.id) { i, f in
                        let seed = Double(abs(f.id.hashValue % 1000)) / 1000
                        let speed = 0.15 + 0.1 * seed
                        let x = 0.5 + 0.42 * sin(t * speed * 2 * .pi / 3 + seed * 6.28)
                        let goingRight = cos(t * speed * 2 * .pi / 3 + seed * 6.28) > 0
                        let y = 0.2 + 0.6 * (Double(i % 5) / 4) + 0.04 * sin(t * 1.7 + seed * 10)
                        Text(GameState.fish(f.fishID, config: EconomyConfig())?.emoji ?? "🐟")
                            .font(.system(size: 26))
                            .scaleEffect(x: goingRight ? -1 : 1, y: 1)
                            .position(x: x * w, y: y * (h - 20))
                            .onTapGesture { onTap(f.fishID) }
                    }
                }
            }
        }
    }
}
