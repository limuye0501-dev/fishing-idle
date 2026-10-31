import SwiftUI
import FishingCore

struct ContentView: View {
    @EnvironmentObject var game: GameViewModel
    @State private var showPanel = true

    var body: some View {
        ZStack(alignment: .top) {
            SeaSceneView(state: game.state, config: game.config)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                HUDView(coins: game.state.coins, fish: game.state.totalFishCaught)
                if let c = game.state.recentCatches.first {
                    Text("\(c.captainName) 带回 \(c.count) 条鱼 \(c.fishEmoji)\(c.fishName)  +\(c.coins)")
                        .font(.footnote.bold())
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                Spacer()
                if showPanel {
                    ControlPanel()
                        .transition(.move(edge: .bottom))
                }
                Button(showPanel ? "收起 ▼" : "港口管理 ▲") {
                    withAnimation(.spring) { showPanel.toggle() }
                }
                .buttonStyle(.borderedProminent).tint(.orange)
            }
            .padding()
        }
        .alert("欢迎回来！", isPresented: Binding(
            get: { game.offlineReport != nil },
            set: { if !$0 { game.offlineReport = nil } })) {
            Button("收下") { game.offlineReport = nil }
        } message: {
            if let r = game.offlineReport {
                Text("离开的 \(formatDuration(r.seconds)) 里，船长们赚了 \(r.coins) 金币 🪙")
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
    let fish: Int
    var body: some View {
        HStack {
            Label("\(coins)", systemImage: "dollarsign.circle.fill").foregroundStyle(.yellow)
            Spacer()
            Label("累计 \(fish) 条", systemImage: "fish.fill").foregroundStyle(.white)
        }
        .font(.title3.bold())
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ControlPanel: View {
    @EnvironmentObject var game: GameViewModel
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $tab) {
                Text("船长").tag(0)
                Text("海域").tag(1)
            }.pickerStyle(.segmented)
            ScrollView {
                if tab == 0 { captainList } else { areaList }
            }
            .frame(maxHeight: 280)
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
                Spacer()
                Menu(area?.name ?? "-") {
                    ForEach(cfg.areas.filter { game.state.unlockedAreaIDs.contains($0.id) }) { a in
                        Button(a.name) { game.assign(captain.id, to: a.id) }
                    }
                }
                .font(.subheadline)
            }
            HStack {
                Text(phaseText(captain.phase)).font(.caption)
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

    private func phaseText(_ p: TripPhase) -> String {
        switch p {
        case .sailingOut: return "出海中"
        case .fishing: return "捕鱼中"
        case .returning: return "返航中"
        case .unloading: return "卸货中"
        }
    }
}
