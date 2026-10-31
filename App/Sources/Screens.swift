import SwiftUI
import FishingCore

// MARK: - 设置

struct SettingsView: View {
    @EnvironmentObject var game: GameViewModel
    @ObservedObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var sfx = AudioManager.shared.sfxOn
    @State private var music = AudioManager.shared.musicOn
    @State private var haptics = AudioManager.shared.hapticsOn

    var body: some View {
        NavigationStack {
            Form {
                Section(tr("我的船", "My ship")) {
                    HStack {
                        Text(tr("船名", "Ship name"))
                        Spacer()
                        Text(game.state.shipName).foregroundStyle(.secondary)
                    }
                    Button(tr("✏️ 给船改名", "✏️ Rename the ship")) { dismiss(); Task { try? await Task.sleep(for: .milliseconds(400)); game.showNaming = true } }
                }
                Section("声音与触感") {
                    Toggle("🔊 音效", isOn: $sfx).onChange(of: sfx) { _, v in AudioManager.shared.sfxOn = v }
                    Toggle("🎵 背景音乐", isOn: $music).onChange(of: music) { _, v in AudioManager.shared.musicOn = v }
                    Toggle("📳 触感反馈", isOn: $haptics).onChange(of: haptics) { _, v in AudioManager.shared.hapticsOn = v }
                }
                Section("完整版") {
                    if game.isFullVersion {
                        Label("已解锁完整版，谢谢支持！", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    } else {
                        Button {
                            game.purchaseFullVersion()
                        } label: {
                            HStack {
                                Text("🔓 解锁完整版")
                                Spacer()
                                Text(store.priceText).foregroundStyle(.secondary)
                            }
                        }
                        .disabled(store.busy)
                        Text("一次购买，永久解锁全部海域、全部渔具与鱼缸扩容。宝石不出售。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("恢复购买") { game.restorePurchases() }.disabled(store.busy)
                }
                Section("关于") {
                    NavigationLink("隐私政策") { PrivacyPolicyView() }
                    NavigationLink("致谢与素材来源") { CreditsView() }
                    Button("重新查看新手引导") { dismiss(); game.showOnboarding = true }
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("隐私政策").font(.title2.bold())
                Text("《船长别回来》不收集、不上传任何个人信息。")
                Text("• 游戏进度只保存在你的设备上（应用沙盒内的存档文件与系统偏好设置）。")
                Text("• 不含广告、不含第三方统计或追踪 SDK，不请求定位、通讯录、相机等权限。")
                Text("• 内购由 Apple App Store 处理，我们拿不到你的支付信息。")
                Text("• 删除应用即可清除全部数据。")
                Text("如有疑问请联系：support@example.com（上架前替换）").foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("隐私政策")
    }
}

struct CreditsView: View {
    var body: some View {
        List {
            Section(tr("3D 场景", "3D scene")) { Text(tr("渔船、小船长、海面与天空：本作原创（SceneKit 程序建模）", "Trawler, little captain, sea and sky: original (procedural SceneKit models)")) }
            Section("音效") {
                Text("Kenney Interface Sounds、Music Jingles — CC0")
                Text("背景音乐《港口小调》— 本作原创（程序合成）")
            }
            Section("图片与资料") {
                Text("鱼类照片：Wikimedia Commons，各作者与许可见图鉴页")
                Text("世界地图：Natural Earth — 公有领域")
                Text("资料参考：维基百科 / FishBase / IUCN 红色名录")
            }
            Section(tr("美术与程序", "Art & code")) { Text(tr("应用图标与引导插画、程序：本作原创", "App icon, onboarding art and code: original")) }
        }
        .navigationTitle("致谢")
    }
}

// MARK: - 新手引导

struct OnboardingView: View {
    @EnvironmentObject var game: GameViewModel
    @State private var page = 0

    private struct Page { let image: String?; let emoji: String; let title: String; let text: String }
    private var pages: [Page] { [
        Page(image: "OnboardingHero", emoji: "", title: tr("欢迎上船，小船长！", "Welcome aboard, little captain!"),
             text: tr("你有一艘自己的大渔船。它一直漂在海上，日出日落、风来雨去，都在慢慢地捕鱼。", "You have your very own trawler. It stays out at sea through sunrise and sunset, wind and rain, quietly fishing.")),
        Page(image: nil, emoji: "🎣🌊", title: tr("挂机，或者亲手撒网", "Idle — or cast by hand"),
             text: tr("不在的时候船员会自己捕鱼。想玩的时候点「撒网」：看声呐找鱼群、掐准时机、稳住拉力，更容易钓到稀有的大鱼。", "The crew fishes while you're away. Tap Cast to play: find a school on sonar, time your throw and keep the line steady for rarer, bigger fish.")),
        Page(image: nil, emoji: "⛽️🧊", title: tr("燃油、鱼舱和新鲜度", "Fuel, hold and freshness"),
             text: tr("燃油会慢慢烧掉，鱼舱会装满，鱼也会不新鲜。可以叫收购船来海上收鱼，也可以回港全价卖、顺便改装。", "Fuel burns, the hold fills and fish lose freshness. Call the carrier ship at sea, or sail home for full prices and refits.")),
        Page(image: nil, emoji: "🗺️🐧", title: tr("从近海到南大洋", "From home waters to the Southern Ocean"),
             text: tr("一片片解锁大西洋、太平洋、印度洋、北冰洋和南大洋，收集 39 种真实海洋生物。天气、昼夜和季节都会改变鱼群。", "Unlock the Atlantic, Pacific, Indian, Arctic and Southern Oceans and collect 39 real sea creatures. Weather, day and night and the seasons all change what bites.")),
    ] }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 1.0, green: 0.86, blue: 0.80), Color(red: 0.99, green: 0.93, blue: 0.84), Color(red: 0.62, green: 0.88, blue: 0.86)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack(spacing: 18) {
                            if let name = pages[i].image, let img = UIImage(named: name) {
                                Image(uiImage: img).resizable().scaledToFit()
                                    .frame(maxHeight: 380)
                                    .clipShape(RoundedRectangle(cornerRadius: 28))
                                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.gold, lineWidth: 3))
                                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                                    .padding(.horizontal, 28)
                                    .accessibilityLabel(tr("戴白色船长帽的小船长站在渔船上", "A little captain in a white cap standing on the trawler"))
                            } else {
                                Text(pages[i].emoji).font(.system(size: 88)).accessibilityHidden(true)
                            }
                            Text(pages[i].title).font(.system(.title, design: .serif).bold()).multilineTextAlignment(.center)
                            Text(pages[i].text)
                                .font(.system(.body, design: .rounded))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .foregroundStyle(Theme.navy)
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                Button {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                        AudioManager.shared.play(.tap); AudioManager.shared.haptic()
                    } else {
                        game.finishOnboarding()
                    }
                } label: {
                    Text(page < pages.count - 1 ? tr("下一步", "Next") : tr("给船起个名字 →", "Name your ship →"))
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent).tint(Theme.coral)
                .padding(.horizontal, 40).padding(.bottom, 30)
            }
        }
    }
}

// MARK: - 给船起名

struct ShipNamingView: View {
    @EnvironmentObject var game: GameViewModel
    @State private var name = ""
    private let ideas = CoreLang.english ? ["Cloud Haven", "Little Tern", "Sea Biscuit", "Morning Star"] : ["云栖号", "小燕鸥号", "海饼干号", "晨星号"]
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "anchor").font(.system(size: 34, weight: .bold)).foregroundStyle(Theme.gold)
            Text(tr("给你的渔船起个名字", "Name your trawler")).font(.system(.title2, design: .serif).bold()).foregroundStyle(Theme.navy)
            Text(tr("名字会漆在船身上，也会挂在铭牌上。以后可以在设置里改。", "It's painted on the hull and shown on the nameplate. You can change it later in Settings."))
                .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.secondary)
            TextField(game.state.shipName, text: $name)
                .font(.system(.title3, design: .serif))
                .multilineTextAlignment(.center)
                .padding(12).background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.gold, lineWidth: 2))
                .submitLabel(.done)
                .onSubmit { game.rename(name.isEmpty ? game.state.shipName : name) }
            HStack {
                ForEach(ideas, id: \.self) { n in
                    Button(n) { name = n }.font(.caption.bold()).buttonStyle(.bordered).tint(Theme.teal)
                }
            }
            Button {
                game.rename(name.isEmpty ? game.state.shipName : name)
            } label: {
                Text(tr("就叫这个！", "That's the one!")).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent).tint(Theme.coral)
        }
        .padding(24)
        .onAppear { name = game.state.shipName }
    }
}

// MARK: - 离线收益

struct OfflineSummaryView: View {
    @EnvironmentObject var game: GameViewModel
    let report: OfflineReport
    let onCollect: () -> Void
    @State private var appear = false

    var body: some View {
        VStack(spacing: 14) {
            Text("⛴️").font(.system(size: 60)).scaleEffect(appear ? 1 : 0.4)
            Text(tr("\(game.state.shipName) 一直在海上", "\(game.state.shipName) kept fishing")).font(.system(.title2, design: .serif).bold())
            Text(tr("你离开了 \(formatDuration(report.seconds))", "You were away for \(formatDuration(report.seconds))")).font(.subheadline).foregroundStyle(.secondary)
            VStack(spacing: 10) {
                row("🐟", tr("捕到", "Caught"), "\(report.fish)")
                if report.released > 0 { row("🫧", tr("舱满放生", "Released (hold full)"), "\(report.released)") }
                if report.newSpecies > 0 { row("📖", tr("新图鉴", "New species"), "+\(report.newSpecies)") }
                row("📦", tr("鱼舱", "Hold"), "\(game.state.hold.count)/\(game.state.holdCapacity) · \(game.state.holdValue(now: Date()).formatted())🪙")
            }
            .padding()
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
            Button(action: onCollect) {
                Text(tr("好的", "Nice")).font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(Theme.coral)
        }
        .foregroundStyle(Theme.ink)
        .padding(24)
        .background(Theme.cream, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.gold, lineWidth: 2))
        .padding(32)
        .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { appear = true } }
    }

    private func row(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack {
            Text(icon)
            Text(title)
            Spacer()
            Text(value).font(.system(.headline, design: .rounded).bold()).monospacedDigit()
        }
    }
}
