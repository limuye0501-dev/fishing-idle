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
            Section("3D 模型") { Text("Kenney（kenney.nl）Pirate / Watercraft / Survival / Nature Kit — CC0") }
            Section("音效") {
                Text("Kenney Interface Sounds、Music Jingles — CC0")
                Text("背景音乐《港口小调》— 本作原创（程序合成）")
            }
            Section("图片与资料") {
                Text("鱼类照片：Wikimedia Commons，各作者与许可见图鉴页")
                Text("世界地图：Natural Earth — 公有领域")
                Text("资料参考：维基百科 / FishBase / IUCN 红色名录")
            }
            Section("小熊船长、场景布局、程序") { Text("本作原创") }
        }
        .navigationTitle("致谢")
    }
}

// MARK: - 新手引导

struct OnboardingView: View {
    @EnvironmentObject var game: GameViewModel
    @State private var page = 0

    private struct Page { let emoji: String; let title: String; let text: String }
    private let pages: [Page] = [
        Page(emoji: "🐻⚓️", title: "欢迎来到小港口", text: "你雇的小熊船长们会自己出海打鱼——而且一出海就不太想回来。"),
        Page(emoji: "🎣🐟", title: "挂机也能赚", text: "船长们会自动出海、捕鱼、返航卖鱼。离开游戏时他们也在干活，回来记得收钱。"),
        Page(emoji: "🗺️🧭", title: "探索真实海域", text: "解锁新海域、升级船和渔具，收集 32 种真实鱼类的图鉴。四季轮换，不同季节有不同的鱼。"),
        Page(emoji: "🐠🫧", title: "你的私人鱼缸", text: "把喜欢的鱼留进鱼缸慢慢欣赏，点一下就能看小百科。")
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.65, green: 0.92, blue: 0.87), Color(red: 0.36, green: 0.78, blue: 0.82)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack(spacing: 18) {
                            Text(pages[i].emoji).font(.system(size: 88)).accessibilityHidden(true)
                            Text(LocalizedStringKey(pages[i].title)).font(.system(.title, design: .rounded).bold())
                            Text(LocalizedStringKey(pages[i].text))
                                .font(.system(.body, design: .rounded))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .foregroundStyle(Color(red: 0.12, green: 0.25, blue: 0.35))
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
                    Text(page < pages.count - 1 ? "下一步" : "开船啦！")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent).tint(.orange)
                .padding(.horizontal, 40).padding(.bottom, 30)
            }
        }
    }
}

// MARK: - 离线收益

struct OfflineSummaryView: View {
    let report: OfflineReport
    let onCollect: () -> Void
    @State private var appear = false

    var body: some View {
        VStack(spacing: 16) {
            Text("⛵️").font(.system(size: 60)).scaleEffect(appear ? 1 : 0.4)
            Text("船长们还在海上！").font(.system(.title2, design: .rounded).bold())
            Text("你离开了 \(formatDuration(report.seconds))").font(.subheadline).foregroundStyle(.secondary)
            VStack(spacing: 10) {
                row("🪙", "金币", "+\(report.coins)")
                if report.gems > 0 { row("💎", "宝石", "+\(report.gems)") }
                row("📜", "海上趣事", "\(report.events)")
            }
            .padding()
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
            Button(action: onCollect) {
                Text("收下").font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(.orange)
        }
        .padding(24)
        .background(Color(red: 1.0, green: 0.97, blue: 0.9), in: RoundedRectangle(cornerRadius: 24))
        .padding(32)
        .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { appear = true } }
    }

    private func row(_ icon: String, _ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(icon)
            Text(title)
            Spacer()
            Text(value).font(.system(.title3, design: .rounded).bold()).monospacedDigit()
        }
    }
}
