import SwiftUI
import FishingCore

extension RecordCatch: Identifiable { public var id: String { fishID + "\(date.timeIntervalSince1970)" } }

/// v9 收藏：纪录鱼（可分享卡片）、漂流瓶纸条、鱼缸装饰、船体涂装
struct CollectionView: View {
    @EnvironmentObject var game: GameViewModel
    @Environment(\.dismiss) private var dismiss
    enum Tab: String, CaseIterable { case records, notes, decor, paint }
    @State private var tab: Tab = ProcessInfo.processInfo.arguments.contains("-notes") ? .notes : .records

    private func title(_ t: Tab) -> String {
        switch t { case .records: tr("纪录", "Records"); case .notes: tr("漂流瓶", "Bottles"); case .decor: tr("鱼缸装饰", "Decor"); case .paint: tr("涂装", "Paint") }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("", selection: $tab) { ForEach(Tab.allCases, id: \.self) { Text(title($0)).tag($0) } }
                    .pickerStyle(.segmented).padding(.horizontal)
                ScrollView {
                    switch tab {
                    case .records: records
                    case .notes: notes
                    case .decor: decor
                    case .paint: paints
                    }
                }
            }
            .navigationTitle(tr("收藏", "Collection")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(tr("完成", "Done")) { dismiss() } } }
            .background(Theme.cream)
        }
    }

    private var records: some View {
        let list = game.state.ext.records.values.sorted { $0.date > $1.date }
        return VStack(spacing: 10) {
            Text(tr("🐱 船猫爱心 \(game.state.ext.catHearts) · 🌈 闪光 \(game.state.ext.shinies.values.reduce(0, +))",
                    "🐱 Cat hearts \(game.state.ext.catHearts) · 🌈 Shinies \(game.state.ext.shinies.values.reduce(0, +))"))
                .font(.subheadline.bold())
            if list.isEmpty { Text(tr("还没有纪录，多钓几条吧～", "No records yet — keep fishing~")).foregroundStyle(.secondary).padding() }
            ForEach(list) { r in
                if let f = game.fish(r.fishID) {
                    HStack {
                        Text(f.emoji).font(.title)
                        VStack(alignment: .leading) {
                            Text((r.shiny ? "🌈 " : "") + f.name).font(.headline)
                            Text("\(formatKg(r.kg)) · \(r.weather.emoji) · \(VoyageConfig.ocean(r.oceanID)?.name ?? "")").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { game.shareRecord = r } label: { Label(tr("分享卡", "Card"), systemImage: "square.and.arrow.up") }
                            .buttonStyle(.bordered).tint(Theme.coral)
                    }
                    .padding(12).background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(.horizontal)
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("已收集 \(game.state.ext.notes.count)/\(VoyageConfig.bottleNotes.count) 张纸条", "\(game.state.ext.notes.count)/\(VoyageConfig.bottleNotes.count) notes collected"))
                .font(.subheadline.bold())
            ForEach(VoyageConfig.bottleNotes, id: \.id) { n in
                let have = game.state.ext.notes.contains(n.id)
                HStack(alignment: .top) {
                    Text(have ? "🍾" : "❔")
                    Text(have ? n.text : tr("还没捞到…离开时船会在海上捡漂流瓶", "Not found yet… the ship picks up bottles while you're away"))
                        .font(.system(.body, design: .serif)).foregroundStyle(have ? Theme.ink : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12).background(Color.white.opacity(have ? 0.8 : 0.4), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
    }

    private var decor: some View {
        VStack(spacing: 10) {
            Text(tr("每件装饰让卖鱼收入 +2%", "Each decoration adds +2% to fish sales")).font(.caption).foregroundStyle(.secondary)
            ForEach(VoyageConfig.decorations) { d in
                let owned = game.state.ext.decor.contains(d.id)
                HStack {
                    Text(d.emoji).font(.title2)
                    Text(d.name).font(.headline)
                    Spacer()
                    if owned { Label(tr("已摆放", "Placed"), systemImage: "checkmark").foregroundStyle(.green) }
                    else { PillButton(title: "\(d.cost.formatted())🪙", enabled: game.state.coins >= d.cost) { game.buyDecoration(d.id) } }
                }
                .padding(12).background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal)
    }

    private var paints: some View {
        VStack(spacing: 10) {
            ForEach(VoyageConfig.paints) { p in
                let owned = game.state.ext.paints.contains(p.id), on = game.state.ext.paint == p.id
                HStack {
                    HStack(spacing: 0) {
                        Color(red: p.hull.0, green: p.hull.1, blue: p.hull.2)
                        Color(red: p.stripe.0, green: p.stripe.1, blue: p.stripe.2).frame(width: 10)
                    }
                    .frame(width: 44, height: 28).clipShape(RoundedRectangle(cornerRadius: 6))
                    Text(p.name).font(.headline)
                    Spacer()
                    if on { Label(tr("使用中", "In use"), systemImage: "checkmark").foregroundStyle(.green) }
                    else if owned { PillButton(title: tr("使用", "Apply"), tint: Theme.navy) { game.paint(p.id) } }
                    else { PillButton(title: "\(p.cost.formatted())🪙", enabled: game.state.coins >= p.cost) { game.paint(p.id) } }
                }
                .padding(12).background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
            }
            Text(tr("涂装数据已保存，船体 3D 着色由场景模块读取 ext.paint（待接入）。", "Paint is saved; the 3D hull tint reads ext.paint (hook pending)."))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}

/// 纪录鱼分享卡
struct RecordCard: View {
    let record: RecordCatch
    let shipName: String
    var body: some View {
        let f = VoyageConfig.fish(record.fishID)
        let df: DateFormatter = { let d = DateFormatter(); d.dateStyle = .medium; d.timeStyle = .short; return d }()
        VStack(spacing: 10) {
            HStack {
                Text(tr("船长别回来", "Captain, Don't Come Back")).font(.system(.caption, design: .serif).bold())
                Spacer()
                Text(record.shiny ? tr("🌈 闪光变种", "🌈 SHINY") : tr("🏆 纪录", "🏆 RECORD")).font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Theme.gold.opacity(0.3), in: Capsule())
            }
            Text(f?.emoji ?? "🐟").font(.system(size: 96))
                .shadow(color: record.shiny ? .pink.opacity(0.7) : .clear, radius: 16)
            Text(f?.name ?? record.fishID).font(.system(.title, design: .serif).bold())
            if let f { Text(f.rarity.name).font(.subheadline.bold()).foregroundStyle(rarityColor(f.rarity)) }
            Text(formatKg(record.kg)).font(.system(size: 44, weight: .heavy, design: .rounded))
            VStack(spacing: 4) {
                Text("\(record.weather.emoji) \(record.weather.name) · \(VoyageConfig.ocean(record.oceanID)?.name ?? "")")
                Text(df.string(from: record.date))
                Text(tr("⛴️ \(shipName)", "⛴️ \(shipName)")).bold()
            }
            .font(.subheadline)
        }
        .foregroundStyle(Theme.ink)
        .padding(24)
        .frame(width: 340)
        .background(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.80), Theme.cream, Color(red: 0.70, green: 0.90, blue: 0.88)], startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.gold, lineWidth: 3))
    }
}

struct RecordShareSheet: View {
    @EnvironmentObject var game: GameViewModel
    let record: RecordCatch
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 18) {
            RecordCard(record: record, shipName: game.state.shipName).shadow(radius: 10, y: 6)
            if let img = image {
                HStack(spacing: 12) {
                    Button {
                        PhotoSaver.save(img) { ok in game.toast = ok ? tr("已保存到相册", "Saved to Photos") : tr("没有相册权限", "No Photos access") }
                    } label: { Label(tr("存到相册", "Save to Photos"), systemImage: "photo.on.rectangle") }
                        .buttonStyle(.borderedProminent).tint(Theme.teal)
                    ShareLink(item: Image(uiImage: img), preview: SharePreview(tr("我的纪录鱼", "My record fish"), image: Image(uiImage: img))) {
                        Label(tr("分享", "Share"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.coral)
                }
            }
        }
        .padding()
        .onAppear {
            let r = ImageRenderer(content: RecordCard(record: record, shipName: game.state.shipName))
            r.scale = 3
            image = r.uiImage
        }
    }
}
