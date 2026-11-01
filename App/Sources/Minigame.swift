import SwiftUI
import Combine
import FishingCore

/// 主动捕鱼小游戏：声呐找鱼群 → 掐准抛网时机 → 稳住拉力收线
@MainActor
final class MinigameModel: ObservableObject {
    enum Stage { case sonar, cast, reel, result }
    struct Blip: Identifiable { let id = UUID(); var angle: Double; var radius: Double; let size: Double; let speed: Double }

    @Published var stage: Stage = .sonar { didSet { if stage != oldValue || stage == .sonar { MinigameBus.post(stageName) } } }
    var stageName: String { switch stage { case .sonar: "sonar"; case .cast: "cast"; case .reel: "reel"; case .result: "result" } }
    /// CI 截图：-mghold sonar|reel 让自动演示停在该阶段
    let hold = UserDefaults.standard.string(forKey: "mghold")
    @Published var blips: [Blip] = []
    @Published var sweep = 0.0
    @Published var castPos = 0.0
    @Published var tension = 0.3
    private var hapticClock = 0.0
    /// 鱼的体力：收线进度越高越累
    var fishStamina: Double { max(0, 1 - reelProgress) }
    @Published var reelProgress = 0.0
    @Published var reeling = false
    @Published var timeLeft = 0.0
    @Published var result: HoldFish?
    @Published var escaped = false
    @Published var lineSnapped = false
    var sonarScore = 0.3
    var castScore = 0.0
    var reelScore = 0.0
    let castTarget = 0.72
    private var castDir = 1.0
    private var t = 0.0
    private var timer: AnyCancellable?
    var autoplay = false
    var assist = AppSettings.shared.assistMode
    var band: ClosedRange<Double> { ReelConfig.safeBand(assist: assist) }
    var onFinish: ((Double) -> HoldFish?)?

    func start(sonarLevel: Int) {
        stage = .sonar; result = nil; escaped = false; lineSnapped = false
        t = 0; timeLeft = 8
        let n = 3 + sonarLevel
        blips = (0..<n).map { _ in
            Blip(angle: .random(in: 0..<(2 * .pi)), radius: .random(in: 0.25...0.85), size: .random(in: 0.3...1), speed: .random(in: -0.4...0.4))
        }
        timer?.cancel()
        timer = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            MainActor.assumeIsolated { self?.step(1.0 / 60) }
        }
    }
    func stop() { timer?.cancel(); timer = nil }
    func end() { stop(); MinigameBus.post("end") }

    private func step(_ dt: Double) {
        t += dt
        switch stage {
        case .sonar:
            sweep = (sweep + dt * 1.6).truncatingRemainder(dividingBy: 2 * .pi)
            for i in blips.indices { blips[i].angle += blips[i].speed * dt }
            timeLeft -= dt
            if hold == "sonar" { timeLeft = 8 }
            else if autoplay && t > 2.2 { pick(blips.max { $0.size < $1.size }!) }
            else if timeLeft <= 0 { pick(blips.min { $0.size < $1.size }!) }
        case .cast:
            castPos += castDir * dt * 0.9
            if castPos >= 1 { castPos = 1; castDir = -1 }
            if castPos <= 0 { castPos = 0; castDir = 1 }
            if autoplay && t > 1.2 && abs(castPos - castTarget) < 0.03 { throwNet() }
        case .reel:
            timeLeft -= dt
            if autoplay { reeling = tension < 0.55 }
            // 鱼的挣扎：拉力随时间起伏
            let pull = 0.18 * sin(t * 2.3) + 0.12 * sin(t * 5.1)
            tension += ((reeling ? ReelConfig.reelForce(assist: assist) : -0.45) + pull * (assist ? 0.7 : 1)) * dt
            tension = max(0, min(1, tension))
            if band.contains(tension) { reelProgress += dt * (reeling ? 0.24 : 0.08) }
            if hold == "reel" { reelProgress = min(reelProgress, 0.62); timeLeft = 9; tension = min(tension, 0.6) }
            MinigameBus.post("reel", progress: reelProgress)
            // v9：张力触感反馈——危险区连续重震，绿区轻点
            hapticClock += dt
            if tension > 0.85, hapticClock > 0.22 { hapticClock = 0; AudioManager.shared.haptic(.heavy) }
            else if band.contains(tension), reeling, hapticClock > 0.6 { hapticClock = 0; AudioManager.shared.haptic(.light) }
            if tension >= 1 { finish(snapped: true); return }
            if reelProgress >= 1 || timeLeft <= 0 { finish(snapped: false) }
        case .result: break
        }
    }

    func pick(_ b: Blip) {
        guard stage == .sonar else { return }
        sonarScore = b.size
        AudioManager.shared.play(.tap); AudioManager.shared.haptic(.light)
        stage = .cast; castPos = 0; castDir = 1; t = 0
    }
    func throwNet() {
        guard stage == .cast else { return }
        castScore = max(0, 1 - abs(castPos - castTarget) * 5)
        AudioManager.shared.play(.open); AudioManager.shared.haptic(.medium)
        stage = .reel; tension = 0.3; reelProgress = 0; timeLeft = 9; t = 0
    }
    private func finish(snapped: Bool) {
        // v8：断线不再丢鱼，只是品质（体型）变低
        reelScore = snapped ? 0 : min(1, reelProgress)
        let q = 0.2 * sonarScore + 0.3 * castScore + 0.5 * reelScore
        result = onFinish?(q)
        escaped = result == nil
        lineSnapped = snapped
        stage = .result
        reeling = false
        if autoplay { stop() }
    }
    var quality: Double { 0.2 * sonarScore + 0.3 * castScore + 0.5 * reelScore }
}

struct FishingMinigameView: View {
    @EnvironmentObject var game: GameViewModel
    @StateObject private var m = MinigameModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [.clear, .clear, Color(red: 0.05, green: 0.16, blue: 0.26).opacity(0.85)], startPoint: .top, endPoint: .bottom)   // v7.2：露出 3D 场景
                .ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    Text(title).font(.system(.title2, design: .serif).bold()).foregroundStyle(Theme.cream)
                    Spacer()
                    Button { m.stop(); game.showMinigame = false } label: {
                        Image(systemName: "xmark").font(.headline).foregroundStyle(Theme.cream)
                            .frame(width: 36, height: 36).background(.white.opacity(0.15), in: Circle())
                    }
                    .accessibilityLabel(tr("收工", "Done"))
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(red: 0.05, green: 0.16, blue: 0.26).opacity(0.72), in: Capsule())
                Text(hint).font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.cream.opacity(0.85))
                    .multilineTextAlignment(.center).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(red: 0.05, green: 0.16, blue: 0.26).opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                switch m.stage {
                case .sonar: sonar
                case .cast: cast
                case .reel: reel
                case .result: resultCard
                }
                Spacer(minLength: 0)
                StagePips(stage: m.stage)
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
            .padding(.top, 128)   // v7.5：标题放在主界面金币/状态条下方，不再重叠
        }
        .onAppear {
            m.autoplay = game.autoplayMinigame
            m.onFinish = { q in game.finishMinigame(quality: q) }
            m.start(sonarLevel: game.state.part(.sonar))
        }
        .onDisappear { m.end() }
    }

    private var title: String {
        switch m.stage {
        case .sonar: tr("① 声呐找鱼群", "① Find a school")
        case .cast: tr("② 抛网", "② Cast")
        case .reel: tr("③ 收网", "③ Reel in")
        case .result: m.escaped ? tr("鱼跑了…", "It got away…") : tr("上钩啦！", "Got one!")
        }
    }
    private var hint: String {
        switch m.stage {
        case .sonar: tr("越大的光点越可能是稀有的大鱼。点一个！", "Bigger blips are likelier to be rare, big fish. Tap one!")
        case .cast: tr("指针走到金色区域时点击抛网", "Tap when the needle is in the gold zone")
        case .reel: tr("按住收线，松开放线。拉力保持在绿色区间，别把网绳拉断！", "Hold to reel, release to give slack. Keep tension in the green — don't snap the line!")
        case .result: m.escaped ? tr("下次稳一点～", "Steady hands next time~") : m.lineSnapped ? tr("拉力太大，鱼还是捞上来了，只是个头小了点", "Too much tension — you still landed it, just a smaller one") : tr("亲手钓的鱼更稀有、更大", "Fish caught by hand are rarer and bigger")
        }
    }

    private var sonar: some View {
        GeometryReader { g in
            let r = min(g.size.width, g.size.height) / 2
            let c = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            ZStack {
                Circle().fill(Color(red: 0.05, green: 0.35, blue: 0.30).opacity(0.12))   // v7.2：3D 声呐为主，2D 仅作点击层
                ForEach(1..<4) { k in Circle().stroke(Color.green.opacity(0.35), lineWidth: 1).frame(width: r * 2 * CGFloat(k) / 3, height: r * 2 * CGFloat(k) / 3) }
                Path { p in p.move(to: c); p.addLine(to: CGPoint(x: c.x + r * cos(m.sweep), y: c.y + r * sin(m.sweep))) }
                    .stroke(Color.green, lineWidth: 2)
                ForEach(m.blips) { b in
                    let p = CGPoint(x: c.x + r * b.radius * cos(b.angle), y: c.y + r * b.radius * sin(b.angle))
                    Circle().fill(Color(red: 0.6, green: 1, blue: 0.6))
                        .frame(width: 10 + 26 * b.size, height: 10 + 26 * b.size)
                        .shadow(color: .green, radius: 8)
                        .position(p)
                        .onTapGesture { m.pick(b) }
                        .accessibilityLabel(tr("鱼群", "School of fish"))
                        .accessibilityAddTraits(.isButton)
                }
            }
            .frame(width: r * 2, height: r * 2)
            .position(c)
        }
        .frame(height: 320)
    }

    private var cast: some View {
        VStack(spacing: 24) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(Theme.gold).frame(width: g.size.width * 0.12).offset(x: g.size.width * (m.castTarget - 0.06))
                    Capsule().fill(Theme.cream).frame(width: 6, height: 44).offset(x: g.size.width * m.castPos - 3)
                }
            }
            .frame(height: 36)
            Button { m.throwNet() } label: {
                Text(tr("抛网！", "Cast!")).font(.system(.title2, design: .rounded).bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(Theme.coral, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var reel: some View {
        VStack(spacing: 20) {
            GeometryReader { g in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.12))
                    Rectangle().fill(Color.green.opacity(0.35)).frame(height: g.size.height * (m.band.upperBound - m.band.lowerBound)).offset(y: -g.size.height * m.band.lowerBound)
                    RoundedRectangle(cornerRadius: 4).fill(m.tension > 0.85 ? Color.red : Theme.cream)
                        .frame(height: 8).offset(y: -g.size.height * m.tension + 4)
                }
            }
            .frame(width: 30, height: 200)
            .overlay(alignment: .top) { Text(tr("拉力", "Tension")).font(.caption2.bold()).foregroundStyle(Theme.cream).fixedSize().offset(y: -16) }
            .opacity(0.85)
            .frame(maxWidth: .infinity, alignment: .trailing)   // v7.6：拉力条贴右侧，不再挡住 3D 网兜
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("鱼的体力", "Fish stamina")).font(.caption2.bold()).foregroundStyle(Theme.cream)
                ProgressView(value: m.fishStamina).tint(m.fishStamina < 0.3 ? .green : Theme.coral)
            }
            Text(tr("剩余 \(max(0, Int(m.timeLeft.rounded()))) 秒", "\(max(0, Int(m.timeLeft.rounded())))s left")).font(.caption).foregroundStyle(Theme.cream)
            Text(tr("按住收线", "Hold to reel"))
                .font(.system(.title3, design: .rounded).bold()).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 22)
                .background(m.reeling ? Theme.teal : Theme.coral, in: RoundedRectangle(cornerRadius: 18))
                .gesture(DragGesture(minimumDistance: 0).onChanged { _ in m.reeling = true }.onEnded { _ in m.reeling = false })
                .accessibilityAddTraits(.isButton)
        }
    }

    private var resultCard: some View {
        VStack(spacing: 14) {
            if let f = m.result, let t = VoyageConfig.fish(f.fishID) {
                if let img = Encyclopedia.photo("fish_\(t.id)") {
                    Image(uiImage: img).resizable().scaledToFill().frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Text(t.emoji).font(.system(size: 90))
                }
                Text("\(t.emoji) \(t.name)").font(.system(.title, design: .serif).bold())
                HStack(spacing: 10) {
                    Text(t.rarity.name).font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 3).background(rarityColor(t.rarity).opacity(0.3), in: Capsule())
                    Text(formatKg(f.kg)).font(.headline)
                    if f.kg >= t.baseKg * VoyageConfig.trophyFactor { Text(tr("🏆 纪录级", "🏆 Trophy")).font(.caption.bold()) }
                }
                Text(tr("评分 \(Int(m.quality * 100)) · 放进鱼舱了", "Score \(Int(m.quality * 100)) · stowed in the hold")).font(.caption)
            } else {
                Text("🫧").font(.system(size: 90))
                Text(tr("网绳太紧，鱼挣脱了", "The line was too tight and it slipped away")).font(.headline)
            }
            HStack {
                Button(tr("收工", "Done")) { game.showMinigame = false }
                    .buttonStyle(.bordered).tint(Theme.cream)
                Button(tr("再撒一网", "Cast again")) { m.start(sonarLevel: game.state.part(.sonar)) }
                    .buttonStyle(.borderedProminent).tint(Theme.coral)
            }
        }
        .foregroundStyle(Theme.cream)
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 24))
    }
}

struct StagePips: View {
    let stage: MinigameModel.Stage
    var body: some View {
        let idx: Int = { switch stage { case .sonar: 0; case .cast: 1; case .reel: 2; case .result: 3 } }()
        HStack(spacing: 8) {
            ForEach(0..<3) { i in Capsule().fill(i <= idx ? Theme.gold : Color.white.opacity(0.2)).frame(width: 40, height: 6) }
        }
    }
}
