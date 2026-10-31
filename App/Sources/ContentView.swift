import SwiftUI
import FishingCore

struct ContentView: View {
    @EnvironmentObject var game: GameViewModel
    @State private var showPanel = true

    var body: some View {
        // 场景与面板上下分区：面板展开时 3D 画面自动缩到面板上方，港口不被遮挡
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                SeaSceneView(state: game.state, config: game.config)
                    .ignoresSafeArea(edges: .top)
                VStack(spacing: 8) {
                    HUDView(coins: game.state.coins, gems: game.state.gems, fish: game.state.totalFishCaught)
                    if let banner = game.eventBanner {
                        Text(banner)
                            .font(.footnote.bold()).multilineTextAlignment(.center)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.orange.opacity(0.9), in: Capsule())
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                            .task(id: banner) {
                                try? await Task.sleep(for: .seconds(3))
                                withAnimation { game.eventBanner = nil }
                            }
                    } else if let c = game.state.recentCatches.first {
                        Text("\(c.captainName) 带回 \(c.count) 条鱼 \(c.fishEmoji)\(c.fishName)  +\(c.coins)")
                            .font(.footnote.bold())
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    Spacer()
                    Button(showPanel ? "收起 ▼" : "港口管理 ▲") {
                        withAnimation(.spring) { showPanel.toggle() }
                    }
                    .buttonStyle(.borderedProminent).tint(.orange)
                }
                .padding()
            }
            if showPanel {
                ControlPanel()
                    .padding(.horizontal).padding(.bottom, 4)
                    .transition(.move(edge: .bottom))
            }
        }
        .background(Color(red: 0.55, green: 0.82, blue: 0.95))
        .alert("船长们还在海上！", isPresented: Binding(
            get: { game.offlineReport != nil },
            set: { if !$0 { game.offlineReport = nil } })) {
            Button("收下") { game.offlineReport = nil }
        } message: {
            if let r = game.offlineReport {
                Text("你离开的 \(formatDuration(r.seconds)) 里，船长们根本没打算回来：\n赚了 \(r.coins) 金币 🪙" +
                     (r.gems > 0 ? "、\(r.gems) 宝石 💎" : "") + "，经历 \(r.events) 件海上趣事（见日志）")
            }
        }
        .overlay(alignment: .center) {
            if let t = game.toast {
                Text(t).font(.headline).padding().background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                    .task { try? await Task.sleep(for: .seconds(1.2)); game.toast = nil }
            }
        }
    }
}

func formatDuration(_ s: Double) -> String {
    let m = Int(s) / 60
    return m >= 60 ? "\(m / 60)小时\(m % 60)分" : "\(m)分钟"
}

struct HUDView: View {
    let coins: Int
    let gems: Int
    let fish: Int
    var body: some View {
        HStack(spacing: 14) {
            Label("\(coins)", systemImage: "dollarsign.circle.fill").foregroundStyle(.yellow)
            Label("\(gems)", systemImage: "diamond.fill").foregroundStyle(.purple)
            Spacer()
            Label("\(fish) 条", systemImage: "fish.fill").foregroundStyle(.white)
        }
        .font(.headline)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ControlPanel: View {
    @EnvironmentObject var game: GameViewModel

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $game.panelTab) {
                Text("船长").tag(0)
                Text("海域").tag(1)
                Text("图鉴").tag(2)
                Text("日志").tag(3)
            }.pickerStyle(.segmented)
            ScrollView {
                switch game.panelTab {
                case 0: captainList
                case 1: areaList
                case 2: CodexView()
                default: logList
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var captainList: some View {
        VStack(spacing: 8) {
            ForEach(game.state.captains) { c in CaptainRow(captain: c) }
            if let cost = game.state.nextHireCost(config: game.config) {
                Button { game.hire() } label: {
                    Label("雇佣新船长（\(cost) 金币）", systemImage: "person.badge.plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(game.state.coins < cost)
            } else {
                Text("船长已满员").foregroundStyle(.secondary)
            }
        }
    }

    private var areaList: some View {
        VStack(spacing: 8) {
            ForEach(game.config.areas) { a in
                let unlocked = game.state.unlockedAreaIDs.contains(a.id)
                HStack {
                    VStack(alignment: .leading) {
                        Text(a.name).font(.headline)
                        Text(a.fish.map { "\($0.emoji)\($0.name) \($0.value)" }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if unlocked {
                        Text("已解锁").font(.caption).foregroundStyle(.green)
                    } else {
                        Button("解锁 \(a.unlockCost)") { game.unlock(a.id) }
                            .buttonStyle(.bordered)
                            .disabled(game.state.coins < a.unlockCost)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var logList: some View {
        VStack(alignment: .leading, spacing: 6) {
            if game.state.eventLog.isEmpty {
                Text("海上风平浪静，暂时没有新鲜事").foregroundStyle(.secondary)
            }
            ForEach(Array(game.state.eventLog.enumerated()), id: \.offset) { _, e in
                HStack(alignment: .top) {
                    Text(e.date, style: .time).font(.caption2).foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
                    Text(e.text).font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CodexView: View {
    @EnvironmentObject var game: GameViewModel

    var body: some View {
        VStack(spacing: 8) {
            ForEach(game.config.areas) { area in
                let p = game.state.codexProgress(area)
                let done = game.state.completedAreaIDs.contains(area.id)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(area.name).font(.headline)
                        Spacer()
                        Text(done ? "🏆 已集齐 · 收益+\(Int(game.config.codexAreaBonus * 100))%"
                                  : "\(p.caught)/\(p.total) · 集齐奖 \(game.config.codexReward(for: area)) 金币")
                            .font(.caption).foregroundStyle(done ? .orange : .secondary)
                    }
                    HStack(spacing: 6) {
                        ForEach(area.fish) { f in
                            FishCard(fish: f, entry: game.state.codex[f.id])
                        }
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

struct FishCard: View {
    let fish: FishType
    let entry: CodexEntry?

    var body: some View {
        VStack(spacing: 2) {
            Text(entry == nil ? "❔" : fish.emoji).font(.title2)
            Text(entry == nil ? "???" : fish.name).font(.caption.bold())
            if let e = entry {
                Text("×\(e.count) · 最重 \(formatKg(e.bestKg))").font(.caption2).foregroundStyle(.secondary)
                Text(e.firstCaught, format: .dateTime.month().day()).font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("未发现").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Color.white.opacity(entry == nil ? 0.3 : 0.8), in: RoundedRectangle(cornerRadius: 8))
    }
}

func formatKg(_ kg: Double) -> String {
    kg >= 1000 ? String(format: "%.1f吨", kg / 1000) : (kg >= 10 ? String(format: "%.0fkg", kg) : String(format: "%.2fkg", kg))
}

struct CaptainRow: View {
    @EnvironmentObject var game: GameViewModel
    let captain: Captain

    var body: some View {
        let cfg = game.config
        let boat = captain.boat
        let area = cfg.area(captain.areaID)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("⛵️ \(captain.name)").font(.headline)
                Text("Lv\(captain.level)").font(.caption.bold())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.25), in: Capsule())
                Spacer()
                Menu(area?.name ?? "-") {
                    ForEach(cfg.areas.filter { game.state.unlockedAreaIDs.contains($0.id) }) { a in
                        Button(a.name) { game.assign(captain.id, to: a.id) }
                    }
                }
                .font(.subheadline)
            }
            Text("【\(captain.trait.name)】\(captain.trait.detail)")
                .font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text("经验").font(.caption2)
                ProgressView(value: Double(captain.xp), total: Double(captain.xpToNext)).tint(.purple)
                Text("收益×\(String(format: "%.2f", game.state.valueMultiplier(captain, config: cfg)))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            HStack {
                Text(phaseText(captain)).font(.caption)
                ProgressView(value: game.state.phaseProgress(captain, config: cfg))
            }
            HStack {
                let sc = cfg.speedUpgradeCost(level: boat.speedLevel)
                Button("航速 Lv\(boat.speedLevel) ↑\(sc)") { game.upgradeSpeed(captain.id) }
                    .disabled(game.state.coins < sc)
                let cc = cfg.capacityUpgradeCost(level: boat.capacityLevel)
                Button("鱼舱 \(boat.capacity(cfg)) ↑\(cc)") { game.upgradeCapacity(captain.id) }
                    .disabled(game.state.coins < cc)
            }
            .buttonStyle(.bordered).font(.caption)
        }
        .padding(8)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private func phaseText(_ c: Captain) -> String {
        let ev = c.tripEvent.map { " \($0.emoji)" } ?? ""
        switch c.phase {
        case .sailingOut: return "出海中"
        case .fishing: return "捕鱼中" + ev
        case .returning: return "返航中" + ev
        case .unloading: return "卸货中"
        }
    }
}
