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
    @ObservedObject private var settings = AppSettings.shared
    @State private var exportURL: URL?
    @State private var importing = false

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
                Section {
                    Picker("🔋 帧率", selection: $settings.fps) {
                        Text("30 fps（省电）").tag(30)
                        Text("60 fps").tag(60)
                        Text("120 fps").tag(120)
                    }
                    Toggle("🎥 减少镜头晃动", isOn: $settings.reduceCameraMotion)
                } header: { Text("画面与性能") } footer: { Text("默认 30 帧省电、不发烫。容易晕的话打开“减少镜头晃动”。") }
                Section {
                    Toggle("🎣 收线辅助模式", isOn: $settings.assistMode)
                } header: { Text("小游戏") } footer: { Text("绿色拉力区间更宽、鱼挣扎更轻。断线也不会丢鱼，只是个头小一点。") }
                Section {
                    Toggle("☁️ iCloud 同步存档", isOn: $settings.iCloudSync)
                        .onChange(of: settings.iCloudSync) { _, on in if on { CloudSave.shared.push(game.state, force: true); game.pullCloud() } }
                    if let url = exportURL {
                        ShareLink(item: url) { Label("分享导出的存档文件", systemImage: "square.and.arrow.up") }
                    } else {
                        Button { exportURL = game.exportSaveFile() } label: { Label("导出存档", systemImage: "square.and.arrow.up") }
                    }
                    Button { importing = true } label: { Label("导入存档", systemImage: "square.and.arrow.down") }
                } header: { Text("存档") } footer: { Text("换手机或重装前可以导出存档文件（保存到“文件”或发给自己），之后在这里导入。导入会覆盖当前进度。") }
                Section("声音与触感") {
                    Toggle("🔊 音效", isOn: $sfx).onChange(of: sfx) { _, v in AudioManager.shared.sfxOn = v }
                    Toggle("🎵 背景音乐", isOn: $music).onChange(of: music) { _, v in AudioManager.shared.musicOn = v }
                    Toggle("📳 触感反馈", isOn: $haptics).onChange(of: haptics) { _, v in AudioManager.shared.hapticsOn = v }
                    LabeledContent("🌊 环境声") { Slider(value: $settings.ambienceVolume, in: 0...1).frame(maxWidth: 170) }
                    LabeledContent("🔔 音效音量") { Slider(value: $settings.sfxVolume, in: 0...1).frame(maxWidth: 170) }
                    LabeledContent("🎵 音乐音量") { Slider(value: $settings.musicVolume, in: 0...1).frame(maxWidth: 170)
                        .onChange(of: settings.musicVolume) { _, _ in AudioManager.shared.applyMusicVolume() } }
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
                        Text("前两片海免费。一次购买，永久解锁全部海域、全部渔具与鱼缸扩容。无广告、无体力，宝石不出售。")
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
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { r in
                if case .success(let url) = r { game.importSave(from: url) }
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
                Text("• 游戏进度保存在你的设备上；若开启 iCloud 同步，会存入你自己的 iCloud 账户（我们无法访问）。")
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
        Page(image: nil, emoji: "🐱📸", title: tr("船猫、明信片和拍照", "The ship's cat, postcards and photos"),
             text: tr("每天点一下甲板上的船猫，它会让船员干劲更足。离开再回来会收到航海明信片；菜单里的「拍照」可以隐藏界面给船拍美照，「收藏」里有纪录鱼卡片和漂流瓶。", "Pet the ship's cat on deck once a day for a crew boost. Come back to a voyage postcard; use Photo in the menu to hide the UI and snap your ship, and Collection for record cards and bottle notes.")),
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
                PromiseBanner()
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

    /// v8：“航海日志明信片”——回到游戏时的惊喜时刻
    private var dateLine: String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: Date())
    }
    private var weatherLine: String {
        let now = Date(), w = game.state.weather(at: now)
        return "\(w.emoji) \(w.name) · \(game.state.ocean.name)"
    }

    var body: some View {
        VStack(spacing: 12) {
            // 明信片正面：船长插画 + 邮戳
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = UIImage(named: "OnboardingHero") { Image(uiImage: img).resizable().scaledToFill() }
                    else { Text("⛴️").font(.system(size: 80)) }
                }
                .frame(height: 170).frame(maxWidth: .infinity).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .bottomLeading) {
                    Text(weatherLine).font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule()).padding(8)
                }
                .accessibilityLabel(tr("船长在海上的明信片插画", "Postcard illustration of the captain at sea"))
                VStack(spacing: 0) {
                    Text(tr("航海日志", "SHIP'S LOG")).font(.system(size: 9, weight: .heavy, design: .serif))
                    Text("⚓️").font(.system(size: 18))
                }
                .foregroundStyle(Theme.coral)
                .padding(6).background(Circle().stroke(Theme.coral, style: StrokeStyle(lineWidth: 2, dash: [3, 2])))
                .rotationEffect(.degrees(-12)).padding(6)
            }
            .padding(8).background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            .rotationEffect(.degrees(appear ? -1.5 : -8)).scaleEffect(appear ? 1 : 0.6)

            Text(tr("来自 \(game.state.shipName) 的明信片", "A postcard from \(game.state.shipName)"))
                .font(.system(.title3, design: .serif).bold())
            Text(tr("你离开了 \(formatDuration(report.seconds)) · \(dateLine)", "Away for \(formatDuration(report.seconds)) · \(dateLine)"))
                .font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 8) {
                row("🐟", tr("捕到", "Caught"), "\(report.fish)")
                if let id = report.bestFishID, let f = game.fish(id) { row(f.emoji, tr("最好的一条", "Best catch"), f.name) }
                if report.trophies > 0 { row("🏆", tr("纪录级大鱼", "Trophy fish"), "\(report.trophies)") }
                if report.newSpecies > 0 { row("📖", tr("新图鉴", "New species"), "+\(report.newSpecies)") }
                if report.released > 0 { row("🫧", tr("舱满放生", "Released (hold full)"), "\(report.released)") }
                row("📦", tr("鱼舱", "Hold"), "\(game.state.hold.count)/\(game.state.holdCapacity) · \(game.state.holdValue(now: Date()).formatted())🪙")
            }
            .padding(12)
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
            let lines = report.rareEvents.isEmpty ? report.events : report.rareEvents.map(\.text)
            if !lines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("海上见闻", "Sightings at sea")).font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(Array(lines.prefix(3).enumerated()), id: \.offset) { _, e in
                        Text(e).font(.system(.footnote, design: .serif)).lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if report.fuelEmpty {
                Text(tr("⛽️ 燃油用完了，船员在半速漂流作业。叫补给船就能加油。", "⛽️ Out of fuel — the crew kept fishing at half speed. Call the carrier to refuel."))
                    .font(.caption).foregroundStyle(Theme.coral).multilineTextAlignment(.center)
            }
            Button(action: onCollect) {
                Text(tr("收好明信片", "Keep the postcard")).font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(Theme.coral)
        }
        .foregroundStyle(Theme.ink)
        .padding(20)
        .background(Theme.cream, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.gold, lineWidth: 2))
        .padding(24)
        .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true } }
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

/// v8：首屏就把“买断边界”说清楚
struct PromiseBanner: View {
    var body: some View {
        VStack(spacing: 6) {
            Text(tr("前两片海免费 · 一次性解锁全部", "First two seas free · one-time unlock for the rest"))
                .font(.system(.subheadline, design: .rounded).bold())
            HStack(spacing: 14) {
                Label(tr("无广告", "No ads"), systemImage: "nosign")
                Label(tr("无体力", "No stamina"), systemImage: "bolt.slash.fill")
                Label(tr("无抽卡", "No gacha"), systemImage: "dice")
            }
            .font(.system(.caption, design: .rounded).bold())
        }
        .foregroundStyle(Theme.navy)
        .padding(.vertical, 10).padding(.horizontal, 16)
        .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.gold, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }
}
