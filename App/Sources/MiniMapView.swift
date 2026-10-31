import SwiftUI
import FishingCore

/// 真实世界航线：母港舟山 → 各大洋渔场（经度用 -120…240 连续表示，地图以亚洲—太平洋为中心）
enum SeaRoutes {
    static let home = (lat: 30.0, lon: 122.2)
    static let lon0 = -120.0, lon1 = 240.0, lat0 = 85.0, lat1 = -75.0
    static let aspect = 1440.0 / 640.0
    static let routes: [String: [(lat: Double, lon: Double)]] = [
        "coastal": [(29.5, 124.0)],
        "atlantic": [(22, 115), (5, 105), (2, 95), (-5, 80), (-30, 45), (-36, 20), (-20, 5), (10, -20), (35, -30), (52, -30)],
        "pacific": [(28, 140), (24, 160), (20, 190)],
        "indian": [(22, 115), (5, 105), (2, 95), (-12, 75)],
        "arctic": [(40, 140), (55, 165), (66, 190), (73, 175), (77, 140), (78, 90), (76, 30)],
        "southern": [(22, 115), (5, 105), (-10, 100), (-35, 80), (-55, 40), (-62, 20)],
    ]
    static func center(_ id: String) -> (lat: Double, lon: Double) { routes[id]?.last ?? home }
    static func path(_ id: String) -> [(lat: Double, lon: Double)] { [home] + (routes[id] ?? []) }

    static func point(_ p: (lat: Double, lon: Double), in size: CGSize) -> CGPoint {
        CGPoint(x: (p.lon - lon0) / (lon1 - lon0) * size.width, y: (lat0 - p.lat) / (lat0 - lat1) * size.height)
    }

    static func along(_ pts: [(lat: Double, lon: Double)], t: Double) -> (lat: Double, lon: Double) {
        guard pts.count > 1 else { return pts.first ?? home }
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

    /// 当前航段（起点→终点经过母港）
    static func voyagePath(_ s: VoyageState) -> [(lat: Double, lon: Double)]? {
        guard s.phase == .sailing, let to = s.sailTo else { return nil }
        let from = s.sailFrom ?? "port"
        let a = from == "port" ? [home] : Array(path(from).reversed())
        let b = to == "port" ? [home] : path(to)
        return a + b.dropFirst()
    }

    /// 船的位置；作业时在渔场里慢慢转圈
    static func shipPosition(_ s: VoyageState, now: Date = Date()) -> (lat: Double, lon: Double) {
        switch s.phase {
        case .docked: return home
        case .sailing: return along(voyagePath(s) ?? [home], t: s.sailProgress)
        case .fishing:
            let c = center(s.oceanID)
            let a = now.timeIntervalSince1970 / 600
            let r = s.oceanID == "coastal" ? 0.6 : 3.0
            return (c.lat + r * 0.6 * sin(a), c.lon + r * cos(a))
        }
    }
}

struct MiniMapView: View {
    let state: VoyageState
    var expanded: Bool = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2)) { ctx in
            GeometryReader { geo in
                let size = geo.size
                // 小地图：以船为中心放大；展开：全图
                let zoom: CGFloat = expanded ? 1 : 2.2
                let shipLL = SeaRoutes.shipPosition(state, now: ctx.date)
                let full = CGSize(width: size.width * zoom, height: size.height * zoom)
                let sp = SeaRoutes.point(shipLL, in: full)
                let ox = expanded ? 0 : min(0, max(size.width - full.width, size.width / 2 - sp.x))
                let oy = expanded ? 0 : min(0, max(size.height - full.height, size.height / 2 - sp.y))
                ZStack(alignment: .topLeading) {
                    Image(uiImage: UIImage(named: "WorldMap") ?? UIImage()).resizable()
                        .frame(width: full.width, height: full.height)
                    // 航线
                    if let p = SeaRoutes.voyagePath(state) {
                        Path { path in path.addLines(p.map { SeaRoutes.point($0, in: full) }) }
                            .stroke(Theme.coral, style: StrokeStyle(lineWidth: expanded ? 2.5 : 2, lineCap: .round, dash: [5, 4]))
                    }
                    // 各大洋渔场：展开时只标名称（避免重叠：标签放在点的固定一侧，小地图只标当前大洋）
                    ForEach(VoyageConfig.oceans) { o in
                        let c = SeaRoutes.point(SeaRoutes.center(o.id), in: full)
                        let unlocked = state.unlockedOceans.contains(o.id)
                        let current = state.oceanID == o.id
                        Circle().fill(unlocked ? Theme.teal : Color.gray.opacity(0.6))
                            .frame(width: expanded ? 9 : 6, height: expanded ? 9 : 6)
                            .overlay(Circle().stroke(.white, lineWidth: 1))
                            .position(c)
                        if expanded && o.id != "coastal" {
                            Text((unlocked ? "" : "🔒") + o.name)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background((current ? Theme.gold : Color.white).opacity(0.9), in: Capsule())
                                .foregroundStyle(Theme.ink)
                                .fixedSize()
                                .position(x: c.x, y: c.y > full.height - 24 ? c.y - 14 : c.y + 14)
                        }
                    }
                    Image(systemName: "house.fill").font(.system(size: expanded ? 11 : 9)).foregroundStyle(Theme.navy)
                        .position(SeaRoutes.point(SeaRoutes.home, in: full))
                    // 船
                    ZStack {
                        Circle().fill(Theme.coral.opacity(0.25)).frame(width: 26, height: 26)
                        Image(systemName: "ferry.fill").font(.system(size: expanded ? 13 : 11, weight: .bold)).foregroundStyle(Theme.coral)
                    }
                    .position(sp)
                    if expanded {
                        Text(state.shipName).font(.system(size: 11, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.navy, in: Capsule()).foregroundStyle(Theme.cream)
                            .fixedSize()
                            .position(x: sp.x, y: sp.y - 20)
                    }
                }
                .offset(x: ox, y: oy)
            }
            .aspectRatio(expanded ? SeaRoutes.aspect : 1.5, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: expanded ? 14 : 12))
            .overlay(RoundedRectangle(cornerRadius: expanded ? 14 : 12).stroke(Theme.gold, lineWidth: 2))
            .overlay(alignment: .bottomLeading) {
                if !expanded {
                    Text(state.phase == .docked ? tr("母港", "Port") : (state.phase == .sailing ? "\(Int(state.sailProgress * 100))%" : state.ocean.name))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.cream.opacity(0.9), in: Capsule()).foregroundStyle(Theme.ink)
                        .padding(5)
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
    }
}
