import SwiftUI
import FishingCore

/// 真实世界航线小地图：每片海域对应现实中的一个海区，按出海进度沿航线插值
enum SeaRoutes {
    /// 母港：舟山（30.0°N, 122.2°E）
    static let home = (lat: 30.0, lon: 122.2)
    /// 航点（经度用 0…360 连续表示，避免跨日界线）
    static let routes: [String: [(lat: Double, lon: Double)]] = [
        "bay": [(29.4, 122.9)],                                             // 舟山群岛外海
        "mangrove": [(27.0, 121.5), (22.5, 117.5), (20.5, 112.0), (20.0, 110.6)], // 海南东寨港红树林
        "reef": [(28.0, 125.0), (26.2, 127.3)],                             // 冲绳庆良间珊瑚礁
        "kelp": [(32.0, 135.0), (38.0, 160.0), (40.0, 200.0), (36.6, 238.1)],    // 加州蒙特雷海藻林
        "deep": [(25.0, 135.0), (20.0, 165.0)],                             // 北太平洋中部
        "ice": [(35.0, 142.0), (45.0, 155.0), (55.0, 170.0), (64.0, 190.0)],     // 白令海
        "trench": [(25.0, 130.0), (11.35, 142.2)],                          // 马里亚纳海沟
        "legend": [(25.0, 135.0), (15.0, 200.0), (8.0, 270.0), (9.0, 280.5), (25.0, 289.0)] // 百慕大三角
    ]
    static let placeNames: [String: String] = [
        "bay": "舟山外海", "mangrove": "海南东寨港", "reef": "冲绳庆良间", "kelp": "加州蒙特雷",
        "deep": "北太平洋", "ice": "白令海", "trench": "马里亚纳海沟", "legend": "百慕大三角"
    ]
    static let placeNamesEN: [String: String] = [
        "bay": "Off Zhoushan", "mangrove": "Dongzhai Harbor, Hainan", "reef": "Kerama Islands, Okinawa", "kelp": "Monterey, California",
        "deep": "North Pacific", "ice": "Bering Sea", "trench": "Mariana Trench", "legend": "Bermuda Triangle"
    ]
    static func place(_ id: String) -> String { (CoreLang.english ? placeNamesEN[id] : placeNames[id]) ?? "" }
    // 地图图片范围（与 WorldMap.png 生成参数一致）
    static let lon0 = 95.0, lon1 = 300.0, lat0 = -8.0, lat1 = 72.0

    static func path(_ area: String) -> [(lat: Double, lon: Double)] { [home] + (routes[area] ?? []) }

    static func point(_ p: (lat: Double, lon: Double), in size: CGSize) -> CGPoint {
        CGPoint(x: (p.lon - lon0) / (lon1 - lon0) * size.width, y: (lat1 - p.lat) / (lat1 - lat0) * size.height)
    }

    /// t∈[0,1]：沿航线按长度插值
    static func position(_ area: String, t: Double) -> (lat: Double, lon: Double) {
        let pts = path(area)
        guard pts.count > 1 else { return home }
        var lens: [Double] = []
        for i in 1..<pts.count { lens.append(hypot(pts[i].lat - pts[i - 1].lat, pts[i].lon - pts[i - 1].lon)) }
        var remain = max(0, min(1, t)) * lens.reduce(0, +)
        for i in 0..<lens.count {
            if remain <= lens[i] || i == lens.count - 1 {
                let f = lens[i] > 0 ? min(1, remain / lens[i]) : 1
                return (pts[i].lat + (pts[i + 1].lat - pts[i].lat) * f, pts[i].lon + (pts[i + 1].lon - pts[i].lon) * f)
            }
            remain -= lens[i]
        }
        return pts.last!
    }

    /// 根据船长阶段求航线进度
    static func progress(_ c: Captain, state: GameState, config: EconomyConfig) -> Double? {
        let p = state.phaseProgress(c, config: config)
        switch c.phase {
        case .sailingOut: return p
        case .fishing: return 1
        case .returning: return 1 - p
        case .unloading: return nil
        }
    }
}

struct MiniMapView: View {
    let state: GameState
    let config: EconomyConfig
    var expanded: Bool = false

    private static let colors: [Color] = [.blue, .red, .green, .orange, .purple, .teal]

    var body: some View {
        let atSea = state.captains.enumerated().filter { $0.element.phase != .unloading }
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                Image(uiImage: UIImage(named: "WorldMap") ?? UIImage()).resizable()
                ForEach(atSea, id: \.element.id) { item in
                    let c = item.element
                    let color = Self.colors[item.offset % Self.colors.count]
                    let pts = SeaRoutes.path(c.areaID).map { SeaRoutes.point($0, in: size) }
                    Path { p in p.addLines(pts) }
                        .stroke(color.opacity(0.7), style: StrokeStyle(lineWidth: expanded ? 2.5 : 1.5, lineCap: .round, dash: [4, 3]))
                    if let t = SeaRoutes.progress(c, state: state, config: config) {
                        let pos = SeaRoutes.point(SeaRoutes.position(c.areaID, t: t), in: size)
                        Circle().fill(color).overlay(Circle().stroke(.white, lineWidth: 1.5))
                            .frame(width: expanded ? 12 : 8, height: expanded ? 12 : 8)
                            .position(pos)
                        if expanded {
                            Text("\(displayCaptainName(c.name)) · \(SeaRoutes.place(c.areaID))")
                                .font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.white.opacity(0.85), in: Capsule())
                                .position(x: pos.x, y: pos.y - 14)
                        }
                    }
                }
                Image(systemName: "house.fill").font(.system(size: expanded ? 12 : 8)).foregroundStyle(.brown)
                    .position(SeaRoutes.point(SeaRoutes.home, in: size))
            }
        }
        .aspectRatio(820.0 / 320.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: expanded ? 14 : 10))
        .overlay(RoundedRectangle(cornerRadius: expanded ? 14 : 10).stroke(.white, lineWidth: 2))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }
}
