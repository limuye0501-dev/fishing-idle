import SwiftUI
import FishingCore

/// 治愈系配色（参照美术参考图：奶油色面板、海军蓝铭牌、金色描边）
enum Theme {
    static let cream = Color(red: 0.99, green: 0.96, blue: 0.89)
    static let creamDeep = Color(red: 0.96, green: 0.90, blue: 0.78)
    static let gold = Color(red: 0.86, green: 0.66, blue: 0.30)
    static let navy = Color(red: 0.13, green: 0.22, blue: 0.38)
    static let ink = Color(red: 0.25, green: 0.20, blue: 0.15)
    static let teal = Color(red: 0.20, green: 0.62, blue: 0.64)
    static let coral = Color(red: 0.95, green: 0.55, blue: 0.45)
}

struct ContentView: View {
    @EnvironmentObject var game: GameViewModel

    var body: some View {
        ZStack {
            SeaSceneView(state: game.state, photoMode: game.photoMode, catHearts: game.catHearts) { game.petCat() }
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel(tr("\(game.state.shipName) 在\(game.state.ocean.zhName)", "\(game.state.shipName) in the \(game.state.ocean.enName)"))
            if game.photoMode {
                PhotoModeOverlay().transition(.opacity)
            } else {
                HUDLayer()
            }
        }
        .sheet(isPresented: $game.showRecords) {
            CollectionView().environmentObject(game)
                .presentationDetents([.large]).presentationBackground(Theme.cream)
        }
        .sheet(item: $game.shareRecord) { r in
            RecordShareSheet(record: r).environmentObject(game)
                .presentationDetents([.large]).presentationBackground(Theme.cream)
        }
        .sheet(item: $game.panel) { p in
            PanelSheet(panel: p).environmentObject(game)
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.cream)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $game.showMap) {
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("\(game.state.shipName) 在哪儿？", "Where is \(game.state.shipName)?")).font(.system(.title3, design: .rounded).bold())
                MiniMapView(state: game.state, expanded: true)
                Text(tr("母港在舟山。点海图可以选择要去的大洋。底图：Natural Earth（公有领域）。", "Home port is Zhoushan. Open the Chart to pick an ocean. Basemap: Natural Earth (public domain)."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
            .presentationDetents([.medium])
            .presentationBackground(Theme.cream)
        }
        .sheet(item: Binding(get: { game.encyclopediaFish.map(FishRef.init) },
                             set: { game.encyclopediaFish = $0?.id })) { ref in
            EncyclopediaView(fishID: ref.id).environmentObject(game)
        }
        .overlay {
            if let r = game.offlineReport {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    OfflineSummaryView(report: r) { withAnimation(.spring) { game.collectOffline() } }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .fullScreenCover(isPresented: $game.showOnboarding) { OnboardingView().environmentObject(game) }
        .fullScreenCover(isPresented: $game.showMinigame) { FishingMinigameView().environmentObject(game).presentationBackground(.clear) }
        .sheet(isPresented: $game.showSettings) { SettingsView(store: game.storeManager).environmentObject(game) }
        .sheet(isPresented: $game.showNaming) {
            ShipNamingView().environmentObject(game)
                .presentationDetents([.medium]).presentationBackground(Theme.cream).interactiveDismissDisabled()
        }
        .overlay(alignment: .center) {
            if let t = game.toast {
                Text(t).font(.headline).padding().background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                    .task(id: t) { try? await Task.sleep(for: .seconds(1.4)); game.toast = nil }
            }
        }
    }
}

struct HUDLayer: View {
    @EnvironmentObject var game: GameViewModel
    @State private var railOpen = false

    var body: some View {
        let s = game.state
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    CoinPill(coins: s.coins) { game.panel = .hold }
                    HStack(spacing: 6) {
                        SmallPill(text: "💎 \(s.gems)")
                        if !s.isFullVersion { SmallPill(text: tr("免费版", "Free")) }
                    }
                }
                Spacer()
                ShipBanner(name: s.shipName, level: s.level) { game.showSettings = true }
            }
            StatusStrip()
            if let banner = game.eventBanner {
                Text(banner)
                    .font(.system(.footnote, design: .rounded).bold()).multilineTextAlignment(.center)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Theme.cream.opacity(0.95), in: Capsule())
                    .overlay(Capsule().stroke(Theme.gold, lineWidth: 1.5))
                    .foregroundStyle(Theme.ink)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: banner) {
                        try? await Task.sleep(for: .seconds(3.5))
                        withAnimation { game.eventBanner = nil }
                    }
            }
            Spacer()
            HStack(alignment: .bottom) {
                MiniMapView(state: s)
                    .frame(width: 92)
                    .opacity(0.92)
                    .onTapGesture { game.showMap = true }
                    .accessibilityElement()
                    .accessibilityLabel(tr("世界地图：船的位置", "World map: where the ship is"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { game.showMap = true }
                Spacer()
                // v5：可折叠侧栏，默认只露出一个菜单按钮，画面更干净
                VStack(spacing: 8) {
                    if railOpen {
                        Group {
                            RoundButton(icon: "map.fill", title: tr("海图", "Chart")) { game.panel = .chart }
                            RoundButton(icon: "circle.grid.cross.fill", title: tr("渔具", "Gear")) { game.panel = .gear }
                            RoundButton(icon: "wrench.and.screwdriver.fill", title: tr("船坞", "Dock"), badge: s.skillPoints > 0) { game.panel = .dock }
                            RoundButton(icon: "book.fill", title: tr("图鉴", "Codex")) { game.panel = .codex }
                            RoundButton(icon: "fish.fill", title: tr("鱼缸", "Tank")) { game.panel = .tank }
                            RoundButton(icon: "scroll.fill", title: tr("日志", "Log")) { game.panel = .log }
                            RoundButton(icon: "star.fill", title: tr("收藏", "Collection")) { game.showRecords = true }
                            RoundButton(icon: "camera.fill", title: tr("拍照", "Photo")) { withAnimation { railOpen = false; game.photoMode = true } }
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    RoundButton(icon: railOpen ? "xmark" : "line.3.horizontal", title: railOpen ? tr("收起", "Close") : tr("菜单", "Menu"),
                                badge: !railOpen && s.skillPoints > 0) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { railOpen.toggle() }
                    }
                }
            }
            BottomBar()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }
}

struct CoinPill: View {
    let coins: Int
    let action: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.4), Theme.gold], startPoint: .top, endPoint: .bottom))
                Circle().stroke(Color(red: 0.7, green: 0.5, blue: 0.2), lineWidth: 2)
                RoundedRectangle(cornerRadius: 2).stroke(Color(red: 0.6, green: 0.42, blue: 0.15), lineWidth: 2).frame(width: 10, height: 10)
            }
            .frame(width: 32, height: 32)
            Text(coins.formatted()).font(.system(.headline, design: .rounded).bold()).monospacedDigit().foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Button(action: action) {
                Image(systemName: "plus").font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.ink)
                    .frame(width: 26, height: 26).background(Theme.creamDeep, in: Circle())
                    .overlay(Circle().stroke(Theme.gold, lineWidth: 1.5))
            }
            .accessibilityLabel(tr("卖鱼", "Sell fish"))
        }
        .padding(.leading, 4).padding(.trailing, 6).padding(.vertical, 4)
        .background(Theme.cream, in: Capsule())
        .overlay(Capsule().stroke(Theme.gold, lineWidth: 2))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tr("金币 \(coins)", "\(coins) coins"))
    }
}

struct SmallPill: View {
    let text: String
    var body: some View {
        Text(text).font(.system(.caption, design: .rounded).bold()).foregroundStyle(Theme.ink)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Theme.cream.opacity(0.92), in: Capsule())
            .overlay(Capsule().stroke(Theme.gold.opacity(0.8), lineWidth: 1))
    }
}

/// 海军蓝铭牌：金色锚、贝壳、流苏
struct ShipBanner: View {
    let name: String
    let level: Int
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "anchor").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.gold)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name).font(.system(.title3, design: .serif).bold()).foregroundStyle(Theme.cream)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text(tr("Lv.\(level) · 拖网渔船", "Lv.\(level) · Trawler")).font(.system(.caption2, design: .rounded).bold())
                            .foregroundStyle(Theme.gold)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10).fill(LinearGradient(colors: [Theme.navy, Color(red: 0.09, green: 0.15, blue: 0.28)], startPoint: .top, endPoint: .bottom))
                )
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.gold, lineWidth: 2.5))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.gold.opacity(0.5), lineWidth: 1).padding(4))
                .overlay(alignment: .bottomLeading) { Text("🐚").font(.system(size: 14)).offset(x: -6, y: 6) }
                .overlay(alignment: .bottomTrailing) { Text("🐚").font(.system(size: 12)).offset(x: 5, y: 6) }
                // 流苏
                VStack(spacing: 0) {
                    Rectangle().fill(Theme.gold).frame(width: 2, height: 8)
                    Circle().fill(Theme.gold).frame(width: 8, height: 8)
                    Capsule().fill(Color(red: 0.75, green: 0.25, blue: 0.25)).frame(width: 6, height: 14)
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr("船名 \(name)，船长 \(level) 级。点按改名", "Ship \(name), captain level \(level). Tap to rename"))
    }
}

struct StatusStrip: View {
    @EnvironmentObject var game: GameViewModel
    var body: some View {
        let s = game.state
        let now = Date()
        HStack(spacing: 8) {
            Meter(icon: "fuelpump.fill", value: s.fuel / s.fuelCapacity, text: "\(Int(s.fuel))", color: s.fuel < 20 ? .red : Theme.teal)
            Meter(icon: "shippingbox.fill", value: Double(s.hold.count) / Double(s.holdCapacity), text: "\(s.hold.count)/\(s.holdCapacity)",
                  color: s.hold.count >= s.holdCapacity ? Theme.coral : Theme.gold)
            let fresh = s.hold.isEmpty ? 1 : s.hold.map { s.freshness($0, now: now) }.reduce(0, +) / Double(s.hold.count)
            Meter(icon: "snowflake", value: fresh, text: "\(Int(fresh * 100))%", color: fresh < 0.6 ? Theme.coral : .blue)
        }
        .onTapGesture { game.panel = .hold }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("燃油 \(Int(s.fuel))，鱼舱 \(s.hold.count)/\(s.holdCapacity)", "Fuel \(Int(s.fuel)), hold \(s.hold.count) of \(s.holdCapacity)"))
        .accessibilityAddTraits(.isButton)
    }
}

struct Meter: View {
    let icon: String
    let value: Double
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(color)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.creamDeep)
                    Capsule().fill(color).frame(width: g.size.width * max(0.04, min(1, value)))
                }
            }
            .frame(height: 6)
            Text(text).font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Theme.cream.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(Theme.gold.opacity(0.7), lineWidth: 1))
    }
}

struct RoundButton: View {
    let icon: String
    let title: String
    var badge = false
    let action: () -> Void
    var body: some View {
        Button {
            AudioManager.shared.play(.open, volume: 0.5); AudioManager.shared.haptic()
            action()
        } label: {
            VStack(spacing: 1) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.navy)
                Text(title).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(width: 54, height: 54)
            .background(Theme.cream, in: Circle())
            .overlay(Circle().stroke(Theme.gold, lineWidth: 2))
            .overlay(alignment: .topTrailing) { if badge { Circle().fill(.red).frame(width: 11, height: 11).overlay(Circle().stroke(.white, lineWidth: 1.5)) } }
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct BottomBar: View {
    @EnvironmentObject var game: GameViewModel
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let s = game.state
            let now = ctx.date
            let w = s.weather(at: now)
            HStack(spacing: 10) {
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Text(placeText(s)).font(.system(.headline, design: .serif).bold())
                        Text("·")
                        Text("\(w.emoji)\(w.name)").font(.system(.subheadline, design: .rounded).bold())
                        Rectangle().fill(Theme.gold).frame(width: 1, height: 16)
                        Text(String(format: "%02d:%02d", s.localHour(now), (Int(now.timeIntervalSince1970) / 60) % 60))
                            .font(.system(.headline, design: .rounded).bold()).monospacedDigit()
                    }
                    .lineLimit(1).minimumScaleFactor(0.6)
                    Text(subText(s, now)).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(Theme.ink.opacity(0.75))
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8).padding(.horizontal, 10)
                .background(Theme.cream, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold, lineWidth: 2))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.gold.opacity(0.4), lineWidth: 1).padding(3))
                MainAction()
            }
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
    }

    private func placeText(_ s: VoyageState) -> String {
        switch s.phase {
        case .docked: return tr("舟山母港", "Home Port")
        case .sailing:
            let to = s.sailTo == "port" ? tr("母港", "Port") : (VoyageConfig.ocean(s.sailTo ?? "")?.name ?? "")
            return tr("前往\(to)", "To \(to)")
        case .fishing: return s.ocean.name
        }
    }
    private func subText(_ s: VoyageState, _ now: Date) -> String {
        switch s.phase {
        case .sailing:
            let left = max(0, s.sailTotal - s.sailElapsed)
            return tr("航行中 \(Int(s.sailProgress * 100))% · 还要 \(formatDuration(left))", "Sailing \(Int(s.sailProgress * 100))% · \(formatDuration(left)) left")
        case .docked: return tr("在港：鱼市全价 · 船坞改装 · 便宜燃油", "In port: full prices · refits · cheap fuel")
        case .fishing:
            let season = Season.at(now, seasonSeconds: 86_400)
            let part = s.dayPart(now)
            if s.fuel <= 0 { return tr("没油了，挂帆漂流作业（效率 30%）", "Out of fuel — drifting under sail (30%)") }
            if s.hold.count >= s.holdCapacity { return tr("鱼舱满了，只留更值钱的鱼", "Hold full — only keeping better fish") }
            return tr("\(season.emoji)\(season.name)季 · \(part.name) · 挂机捕鱼中", "\(season.emoji) \(season.name) · \(part.name) · fishing")
        }
    }
}

/// 右下角主按钮：海上=撒网（主动捕鱼），在港=出海
struct MainAction: View {
    @EnvironmentObject var game: GameViewModel
    var body: some View {
        let s = game.state
        Button {
            AudioManager.shared.play(.tap); AudioManager.shared.haptic(.medium)
            switch s.phase {
            case .fishing: game.showMinigame = true
            case .docked: game.panel = .chart
            case .sailing: game.showMap = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: s.phase == .fishing ? "scope" : (s.phase == .docked ? "sailboat.fill" : "location.north.line.fill"))
                    .font(.system(size: 18, weight: .bold))
                Text(s.phase == .fishing ? tr("撒网", "Cast") : (s.phase == .docked ? tr("出海", "Set sail") : tr("航行", "Route")))
                    .font(.system(.headline, design: .rounded).bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(LinearGradient(colors: [Color(red: 0.98, green: 0.62, blue: 0.40), Color(red: 0.90, green: 0.42, blue: 0.32)], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cream, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(s.phase == .fishing ? tr("主动捕鱼", "Fish by hand") : tr("出海", "Set sail"))
    }
}

func formatDuration(_ s: Double) -> String {
    let m = Int(s) / 60
    if m < 1 { return tr("\(Int(s))秒", "\(Int(s))s") }
    return m >= 60 ? tr("\(m / 60)小时\(m % 60)分", "\(m / 60)h \(m % 60)m") : tr("\(m)分钟", "\(m) min")
}

struct FishRef: Identifiable { let id: String }
