import SwiftUI
import FishingCore

struct ContentView: View {
    @EnvironmentObject var game: GameViewModel

    var body: some View {
        // 场景与面板上下分区：面板展开时 3D 画面自动缩到面板上方，港口不被遮挡
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                SeaSceneView(state: game.state, config: game.config)
                    .ignoresSafeArea(edges: .top)
                    .accessibilityElement()
                    .accessibilityLabel(tr("港口与海面：船长们正在出海捕鱼", "Harbor and sea: your captains are out fishing"))
                VStack(spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        HUDView(coins: game.state.coins, gems: game.state.gems, fish: game.state.totalFishCaught,
                                season: game.season, secondsLeft: Season.secondsUntilNext(Date(), seasonSeconds: game.config.seasonSeconds),
                                full: game.isFullVersion)
                        Button {
                            AudioManager.shared.play(.open); AudioManager.shared.haptic()
                            game.showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(red: 0.35, green: 0.25, blue: 0.15))
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("设置")
                    }
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
                        Text(tr("\(c.captainName) 带回 \(c.count) 条鱼 \(c.fishEmoji)\(c.fishName)  +\(c.coins)", "\(displayCaptainName(c.captainName)) brought back \(c.count) fish \(c.fishEmoji) \(game.fishName(c))  +\(c.coins)"))
                            .font(.footnote.bold())
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    Spacer()
                    if game.state.captains.contains(where: { $0.phase != .unloading }) {
                        HStack {
                            MiniMapView(state: game.state, config: game.config)
                                .frame(width: 150)
                                .onTapGesture { game.showMap = true }
                                .accessibilityElement()
                                .accessibilityLabel(tr("世界地图：船长们的位置", "World map: where the captains are"))
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction { game.showMap = true }
                            Spacer()
                        }
                    }
                    Button(game.showPanel ? "收起 ▼" : "港口管理 ▲") {
                        withAnimation(.spring) { game.showPanel.toggle() }
                        AudioManager.shared.play(.tap); AudioManager.shared.haptic()
                    }
                    .buttonStyle(.borderedProminent).tint(.orange)
                }
                .padding()
            }
            if game.showPanel {
                ControlPanel()
                    .padding(.horizontal).padding(.bottom, 4)
                    .transition(.move(edge: .bottom))
            }
        }
        .background(Color(red: 0.55, green: 0.82, blue: 0.95))
        .sheet(isPresented: $game.showMap) {
            VStack(alignment: .leading, spacing: 12) {
                Text("船长们在哪儿？").font(.title3.bold())
                MiniMapView(state: game.state, config: game.config, expanded: true)
                Text("每片海域对应一处真实海区，母港在舟山。底图：Natural Earth（公有领域）。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
            .presentationDetents([.medium])
        }
        .sheet(item: Binding(get: { game.encyclopediaFish.map(FishRef.init) },
                             set: { game.encyclopediaFish = $0?.id })) { ref in
            EncyclopediaView(fishID: ref.id).environmentObject(game)
        }
        .overlay {
            if let r = game.offlineReport {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    OfflineSummaryView(report: r) { withAnimation(.spring) { game.collectOffline() } }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .fullScreenCover(isPresented: $game.showOnboarding) { OnboardingView().environmentObject(game) }
        .sheet(isPresented: $game.showSettings) { SettingsView(store: game.storeManager).environmentObject(game) }
        .overlay(alignment: .center) {
            if let t = game.toast {
                Text(LocalizedStringKey(t)).font(.headline).padding().background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                    .task { try? await Task.sleep(for: .seconds(1.2)); game.toast = nil }
            }
        }
    }
}

func formatDuration(_ s: Double) -> String {
    let m = Int(s) / 60
    return m >= 60 ? tr("\(m / 60)小时\(m % 60)分", "\(m / 60)h \(m % 60)m") : tr("\(m)分钟", "\(m) min")
}

struct FishRef: Identifiable { let id: String }

struct HUDView: View {
    let coins: Int
    let gems: Int
    let fish: Int
    let season: Season
    let secondsLeft: Double
    var full: Bool = true
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 14) {
                Label("\(coins)", systemImage: "dollarsign.circle.fill").foregroundStyle(.yellow)
                Label("\(gems)", systemImage: "diamond.fill").foregroundStyle(.purple)
                Spacer()
                Label(tr("\(fish) 条", "\(fish) fish"), systemImage: "fish.fill").foregroundStyle(.white)
            }
            .font(.headline)
            HStack {
                Text(tr("\(season.emoji) \(season.name)季", "\(season.emoji) \(season.name)")).font(.subheadline.bold()).foregroundStyle(.white)
                if !full {
                    Text("免费版").font(.caption2.bold()).foregroundStyle(.orange)
                }
                Text(tr("距\(Season(rawValue: (season.rawValue + 1) % 4)!.name)季 \(formatDuration(secondsLeft))", "\(Season(rawValue: (season.rawValue + 1) % 4)!.name) in \(formatDuration(secondsLeft))"))
                    .font(.caption).foregroundStyle(.white.opacity(0.85))
                Spacer()
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("金币 \(coins)，宝石 \(gems)，累计 \(fish) 条鱼，\(season.name)季，\(formatDuration(secondsLeft))后换季",
                               "\(coins) coins, \(gems) gems, \(fish) fish caught, \(season.name), next season in \(formatDuration(secondsLeft))"))
    }
}

struct ControlPanel: View {
    @EnvironmentObject var game: GameViewModel

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $game.panelTab) {
                Text("船长").tag(0)
                Text("渔具").tag(1)
                Text("海图").tag(2)
                Text("图鉴").tag(3)
                Text("鱼缸").tag(4)
                Text("日志").tag(5)
            }.pickerStyle(.segmented)
            .onChange(of: game.panelTab) { _, _ in AudioManager.shared.play(.tap, volume: 0.4); AudioManager.shared.haptic(.light) }
            ScrollView {
                switch game.panelTab {
                case 0: captainList
                case 1: GearPanel()
                case 2: SeaMapView()
                case 3: CodexView()
                case 4: AquariumView()
                default: logList
                }
            }
            .frame(maxHeight: 250)
            .animation(.easeInOut(duration: 0.2), value: game.panelTab)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var captainList: some View {
        VStack(spacing: 8) {
            ForEach(game.state.captains) { c in CaptainRow(captain: c) }
            if let cost = game.state.nextHireCost(config: game.config) {
                Button { game.hire() } label: {
                    Label(tr("雇佣新船长（\(cost) 金币）", "Hire a new captain (\(cost) coins)"), systemImage: "person.badge.plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(game.state.coins < cost)
            } else {
                Text("船长已满员").foregroundStyle(.secondary)
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

func seasonText(_ f: FishType) -> String {
    f.seasons.isEmpty ? tr("四季", "All year") : f.seasons.map { $0.emoji + $0.name }.joined(separator: "")
}

func gearText(_ f: FishType) -> String {
    f.gears.map { $0.emoji }.joined()
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
                        Text(done ? tr("🏆 已集齐 · 收益+\(Int(game.config.codexAreaBonus * 100))%", "🏆 Complete · income +\(Int(game.config.codexAreaBonus * 100))%")
                                  : tr("\(p.caught)/\(p.total) · 集齐奖 \(game.config.codexReward(for: area)) 金币", "\(p.caught)/\(p.total) · reward \(game.config.codexReward(for: area)) coins"))
                            .font(.caption).foregroundStyle(done ? .orange : .secondary)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                        ForEach(area.fish) { f in
                            FishCard(fish: f, entry: game.state.codex[f.id], season: game.season)
                                .onTapGesture { game.encyclopediaFish = f.id }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(game.state.codex[f.id] != nil ? f.name : tr("未知鱼种", "Unknown species"))
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction { game.encyclopediaFish = f.id }
                        }
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

func rarityColor(_ r: Rarity) -> Color {
    switch r {
    case .common: return .gray
    case .rare: return .blue
    case .epic: return .purple
    case .legendary: return .orange
    }
}

struct FishCard: View {
    let fish: FishType
    let entry: CodexEntry?
    let season: Season

    var body: some View {
        VStack(spacing: 2) {
            Text(entry == nil ? "❔" : fish.emoji).font(.title3)
            Text(entry == nil ? "???" : fish.name).font(.caption2.bold()).lineLimit(1).minimumScaleFactor(0.6)
            Text(fish.rarity.name).font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 4).background(rarityColor(fish.rarity).opacity(0.25), in: Capsule())
            Text(gearText(fish) + " " + seasonText(fish)).font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.5)
            if let e = entry {
                Text("×\(e.count) · \(formatKg(e.bestKg))").font(.system(size: 9)).foregroundStyle(.secondary)
            } else {
                Text(fish.available(in: season) ? "当季可捕" : "不在季").font(.system(size: 9))
                    .foregroundStyle(fish.available(in: season) ? Color.green : Color.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Color.white.opacity(entry == nil ? 0.3 : 0.8), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(rarityColor(fish.rarity).opacity(entry == nil ? 0.2 : 0.7), lineWidth: 1))
    }
}

func formatKg(_ kg: Double) -> String {
    kg >= 1000 ? String(format: tr("%.1f吨", "%.1f t"), kg / 1000) : (kg >= 10 ? String(format: "%.0fkg", kg) : String(format: "%.2fkg", kg))
}

struct CaptainRow: View {
    @EnvironmentObject var game: GameViewModel
    let captain: Captain

    var body: some View {
        let cfg = game.config
        let boat = captain.boat
        let area = cfg.area(captain.areaID)
        let pool = area?.candidates(gear: boat.equipped, season: game.season) ?? []
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("⛵️ \(displayCaptainName(captain.name))").font(.headline)
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
                ProgressView(value: Double(captain.xp), total: Double(captain.xpToNext(cfg))).tint(.purple)
                Text(tr("收益×", "Income ×") + String(format: "%.2f", game.state.valueMultiplier(captain, config: cfg, season: game.season)))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Text("\(boat.equipped.emoji) \(boat.equipped.name) Lv\(boat.gearLevel(boat.equipped))").font(.caption.bold())
                Text(pool.isEmpty ? "⚠️ 当季此渔具钓不到鱼" : tr("可捕：", "Catches: ") + pool.map(\.emoji).joined())
                    .font(.caption2).foregroundStyle(pool.isEmpty ? Color.red : Color.secondary).lineLimit(1)
                Spacer()
                Button("换渔具") { game.gearCaptainID = captain.id; game.panelTab = 1 }.font(.caption2)
            }
            HStack {
                Text(phaseText(captain)).font(.caption)
                ProgressView(value: game.state.phaseProgress(captain, config: cfg))
                Button("⚡️\(cfg.rushGemCost)💎") { game.rush(captain.id) }
                    .font(.caption2).buttonStyle(.bordered).tint(.purple)
                    .disabled(game.state.gems < cfg.rushGemCost)
            }
            HStack {
                let sc = cfg.speedUpgradeCost(level: boat.speedLevel)
                Button(tr("航速 Lv\(boat.speedLevel) ↑\(sc)", "Speed Lv\(boat.speedLevel) ↑\(sc)")) { game.upgradeSpeed(captain.id) }
                    .disabled(game.state.coins < sc)
                let cc = cfg.capacityUpgradeCost(level: boat.capacityLevel)
                Button(tr("鱼舱 \(boat.capacity(cfg)) ↑\(cc)", "Hold \(boat.capacity(cfg)) ↑\(cc)")) { game.upgradeCapacity(captain.id) }
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
        case .sailingOut: return tr("出海中", "Sailing out")
        case .fishing: return tr("捕鱼中", "Fishing") + ev
        case .returning: return tr("返航中", "Returning") + ev
        case .unloading: return tr("卸货中", "Unloading")
        }
    }
}
