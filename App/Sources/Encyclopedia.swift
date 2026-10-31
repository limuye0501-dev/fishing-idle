import SwiftUI
import UIKit
import FishingCore

/// 小百科条目（随 App 打包的 Encyclopedia.json）
struct EncyclopediaEntry: Codable, Identifiable {
    let id: String
    let name: String
    let englishName: String
    let scientificName: String
    var aliases: String
    var size: String
    var distribution: String
    var diet: String
    var behavior: String
    var season: String
    var facts: [String]
    let iucn: String
    let photo: String
    let photoAuthor: String
    let photoLicense: String
    let photoSource: String
    let reference: String

    var iucnText: String {
        switch iucn {
        case "LC": return tr("无危 (LC)", "Least Concern (LC)")
        case "NT": return tr("近危 (NT)", "Near Threatened (NT)")
        case "VU": return tr("易危 (VU)", "Vulnerable (VU)")
        case "EN": return tr("濒危 (EN)", "Endangered (EN)")
        case "CR": return tr("极危 (CR)", "Critically Endangered (CR)")
        case "DD": return tr("数据缺乏 (DD)", "Data Deficient (DD)")
        default: return tr("IUCN 未评估 (NE)", "Not Evaluated (NE)")
        }
    }
}

/// 英文版百科文本（Encyclopedia.en.json，按鱼 id）
struct EnglishText: Codable {
    let aliases: String, size: String, distribution: String, diet: String, behavior: String, season: String
    let facts: [String]
}

enum Encyclopedia {
    static let entries: [String: EncyclopediaEntry] = {
        guard let url = Bundle.main.url(forResource: "Encyclopedia", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([EncyclopediaEntry].self, from: data) else { return [:] }
        var en: [String: EnglishText] = [:]
        if CoreLang.english, let u = Bundle.main.url(forResource: "Encyclopedia.en", withExtension: "json"),
           let d = try? Data(contentsOf: u), let m = try? JSONDecoder().decode([String: EnglishText].self, from: d) { en = m }
        return Dictionary(uniqueKeysWithValues: list.map { e -> (String, EncyclopediaEntry) in
            var e = e
            if let t = en[e.id] {
                e.aliases = t.aliases; e.size = t.size; e.distribution = t.distribution; e.diet = t.diet
                e.behavior = t.behavior; e.season = t.season; e.facts = t.facts
            }
            return (e.id, e)
        })
    }()

    static func photo(_ name: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

struct EncyclopediaView: View {
    @EnvironmentObject var game: GameViewModel
    @Environment(\.dismiss) private var dismiss
    let fishID: String

    var body: some View {
        let fish = game.fish(fishID)
        let entry = Encyclopedia.entries[fishID]
        let record = game.state.codex[fishID]
        let unlocked = record != nil
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if unlocked {
                        FishTurntable(id: fishID)
                            .frame(height: 200).frame(maxWidth: .infinity)
                            .background(LinearGradient(colors: [Color(red: 0.99, green: 0.93, blue: 0.88), Color(red: 0.80, green: 0.93, blue: 0.94)], startPoint: .top, endPoint: .bottom))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if let e = entry, let img = Encyclopedia.photo(e.photo) {
                        Image(uiImage: img).resizable().scaledToFit()
                            .frame(maxWidth: .infinity)
                            .blur(radius: unlocked ? 0 : 18)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay { if !unlocked { Text("❔").font(.system(size: 60)) } }
                        Text(verbatim: "📷 \(e.photoAuthor) · \(e.photoLicense) · Wikimedia Commons")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if let f = fish {
                        HStack {
                            Text("\(unlocked ? f.emoji : "❔") \(unlocked ? f.name : "未知鱼种")").font(.title2.bold())
                            Text(f.rarity.name).font(.caption.bold()).padding(.horizontal, 6)
                                .background(rarityColor(f.rarity).opacity(0.25), in: Capsule())
                        }
                        let area = game.area(of: f.id)
                        info("游戏中", tr("\(area?.name ?? "") · 渔具 \(f.gears.map { $0.emoji + $0.name }.joined(separator: "/")) · \(seasonText(f)) · 售价 \(f.value)",
                                         "\(area?.name ?? "") · gear \(f.gears.map { $0.emoji + $0.name }.joined(separator: "/")) · \(seasonText(f)) · sells for \(f.value)"))
                        if let r = record {
                            info("我的记录", tr("共捕获 \(r.count) 条 · 最重 \(formatKg(r.bestKg)) · 首次 \(r.firstCaught.formatted(date: .abbreviated, time: .omitted))",
                                           "\(r.count) caught · heaviest \(formatKg(r.bestKg)) · first on \(r.firstCaught.formatted(date: .abbreviated, time: .omitted))"))
                        }
                    }
                    if let e = entry {
                        if unlocked {
                            Text(e.scientificName).italic().font(.subheadline)
                            if CoreLang.english { info("中文名", e.name) } else { info("英文名", e.englishName) }
                            info("别名", e.aliases)
                            info("体型", e.size)
                            info("分布与栖息地", e.distribution)
                            info("食性", e.diet)
                            info("习性", e.behavior)
                            info("现实渔季", e.season)
                            info("保护等级", e.iucnText)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("冷知识").font(.caption.bold()).foregroundStyle(.orange)
                                ForEach(e.facts, id: \.self) { Text("• " + $0).font(.callout) }
                            }
                            Text("资料参考：维基百科 / FishBase / IUCN 红色名录").font(.caption2).foregroundStyle(.secondary)
                            if let u = URL(string: e.photoSource) { Link("图片来源与许可", destination: u).font(.caption2) }
                        } else {
                            Text("首次捕获后解锁完整百科。").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("小百科")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { dismiss() } } }
        }
    }

    private func info(_ title: LocalizedStringKey, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.bold()).foregroundStyle(.teal)
            Text(text).font(.callout)
        }
    }
}
