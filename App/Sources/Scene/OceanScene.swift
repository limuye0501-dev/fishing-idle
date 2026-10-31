import SceneKit
import UIKit
import FishingCore

/// Q 版低多边形海港场景：Kenney CC0 模型 + 程序化小熊船长（布局见 PortLayout.json）
final class OceanScene {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private var boats: [UUID: SCNNode] = [:]
    private var bubbleKeys: [UUID: String] = [:]
    private let dockPosition = SCNVector3(0, 0, 4.7)
    private let layout: PortLayout?
    private static let accents: [UIColor] = [
        UIColor(red: 0.20, green: 0.38, blue: 0.75, alpha: 1), UIColor(red: 0.85, green: 0.30, blue: 0.25, alpha: 1),
        UIColor(red: 0.20, green: 0.62, blue: 0.45, alpha: 1), UIColor(red: 0.95, green: 0.62, blue: 0.20, alpha: 1),
        UIColor(red: 0.55, green: 0.35, blue: 0.70, alpha: 1), UIColor(red: 0.25, green: 0.65, blue: 0.80, alpha: 1)
    ]

    init() {
        layout = PortLayout.load()
        buildCamera()
        buildLights()
        buildWater()
        buildPort()
    }

    // MARK: - 构建

    private func buildCamera() {
        let cam = SCNCamera()
        let c = layout?.camera ?? PortCamera(pos: [14, 30, 28], look: [-2, 0, -1], fov: 42)
        cam.fieldOfView = CGFloat(c.fov)
        cam.zFar = 250
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(c.pos[0], c.pos[1], c.pos[2])
        let look = SCNNode()
        look.position = SCNVector3(c.look[0], c.look[1], c.look[2])
        scene.rootNode.addChildNode(look)
        let lc = SCNLookAtConstraint(target: look)
        lc.isGimbalLockEnabled = true
        cameraNode.constraints = [lc]
        scene.rootNode.addChildNode(cameraNode)
    }

    private func buildLights() {
        // 暖色主光 + 柔和阴影
        let sun = SCNNode()
        let light = SCNLight()
        light.type = .directional
        light.intensity = 780
        light.color = UIColor(red: 1.0, green: 0.94, blue: 0.82, alpha: 1)
        light.castsShadow = true
        light.shadowMode = .forward
        light.shadowColor = UIColor(red: 0.05, green: 0.15, blue: 0.25, alpha: 0.35)
        light.shadowRadius = 6
        light.shadowSampleCount = 16
        light.shadowMapSize = CGSize(width: 2048, height: 2048)
        light.automaticallyAdjustsShadowProjection = true
        light.maximumShadowDistance = 80
        sun.light = light
        let d = layout?.sunDir ?? [-0.45, -0.85, -0.35]
        sun.position = SCNVector3(0, 0, 0)
        sun.look(at: SCNVector3(d[0], d[1], d[2]))
        scene.rootNode.addChildNode(sun)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 300
        ambient.light!.color = UIColor(red: 0.90, green: 0.93, blue: 1.0, alpha: 1)
        scene.rootNode.addChildNode(ambient)
    }

    private func buildWater() {
        let plane = SCNPlane(width: 140, height: 140)
        plane.widthSegmentCount = 140
        plane.heightSegmentCount = 140
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.25, green: 0.75, blue: 0.82, alpha: 1)
        m.lightingModel = .constant   // 直接输出鲜艳的绿松石色，不被光照压暗
        m.shaderModifiers = [
            .geometry: """
            float t = scn_frame.time * 0.6;
            float w = sin(_geometry.position.x * 0.35 + t) * 0.05
                    + cos(_geometry.position.y * 0.28 + t * 1.3) * 0.04;
            _geometry.position.z += w;
            """,
            // 绿松石海水：近岸浅、远海深；叠加两层流动的白色浪花纹
            .surface: """
            // 动森风格：按到岸/礁石/码头的距离做浅→深柔和渐变 + 贴边白色泡沫线
            float2 uv = _surface.diffuseTexcoord;
            float x = -70.0 + 140.0 * uv.x;
            float z = -90.0 + 140.0 * uv.y;
            float t = scn_frame.time;
            float2 q;
            q = max(max(float2(-10.5, 4.8) - float2(x, z), float2(x, z) - float2(11.3, 13.0)), float2(0.0));
            float d = length(q);
            q = max(max(float2(7.7, -0.3) - float2(x, z), float2(x, z) - float2(10.3, 4.8)), float2(0.0));
            d = min(d, length(q));
            d = min(d, max(length(float2(x + 9.0, z + 12.0)) - 2.6, 0.0));
            d = min(d, max(length(float2(x + 10.0, z + 3.0)) - 2.2, 0.0));
            d = min(d, max(length(float2(x - 7.0, z + 8.0)) - 2.8, 0.0));
            d = min(d, max(length(float2(x - 8.5, z + 19.0)) - 2.0, 0.0));
            d = min(d, max(length(float2((x + 9.5) / 3.9, (z - 10.5) / 3.3)) - 1.0, 0.0) * 3.3);
            d = min(d, max(length(float2((x + 3.0) / 7.1, (z - 14.2) / 2.3)) - 1.0, 0.0) * 2.3);
            d = min(d, max(length(float2((x - 5.5) / 5.6, (z - 14.4) / 2.1)) - 1.0, 0.0) * 2.1);
            d = min(d, max(length(float2((x - 12.6) / 2.8, (z - 1.5) / 3.7)) - 1.0, 0.0) * 2.8);
            d += 0.35 * sin(x * 1.3 + z * 0.9 + t * 0.4) * sin(z * 1.1 - x * 0.4);
            // sRGB → 线性：A6EBDD / 8FE3D6 / 5CC8D0 / 4AA6D8
            float3 c0 = float3(0.381, 0.831, 0.723);
            float3 c1 = float3(0.274, 0.768, 0.672);
            float3 c2 = float3(0.107, 0.578, 0.630);
            float3 c3 = float3(0.069, 0.381, 0.686);
            float3 col = mix(c0, c1, smoothstep(0.3, 2.0, d));
            col = mix(col, c2, smoothstep(2.0, 7.0, d));
            col = mix(col, c3, smoothstep(7.0, 16.0, d));
            float hl = sin(x * 0.9 + sin(z * 0.7 + t * 0.3) * 1.5 + t * 0.5) * sin(z * 1.2 - sin(x * 0.5) - t * 0.4);
            col = mix(col, float3(1.0), 0.10 * smoothstep(0.92, 0.99, hl));
            float foam = smoothstep(0.0, 0.12, d) * (1.0 - smoothstep(0.45, 0.75, d));
            col = mix(col, float3(1.0), 0.92 * foam);
            _surface.diffuse.rgb = col;
            _surface.emission.rgb = float3(0.0);
            """
        ]
        plane.materials = [m]
        let node = SCNNode(geometry: plane)
        node.eulerAngles.x = -Float.pi / 2
        node.position = SCNVector3(0, -0.05, -20)
        scene.rootNode.addChildNode(node)
    }

    private func mat(_ color: UIColor, glow: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .lambert
        if glow { m.emission.contents = color }
        return m
    }

    private func color(_ c: [Float]?) -> UIColor {
        guard let c, c.count >= 3 else { return .white }
        return UIColor(red: CGFloat(c[0]), green: CGFloat(c[1]), blue: CGFloat(c[2]), alpha: 1)
    }

    /// 由布局节点构建 SceneKit 节点
    private func makeNode(_ n: PortNode) -> SCNNode {
        let node: SCNNode
        if let m = n.m {
            let g = ModelLibrary.shared.geometry(m, tint: n.tint)
            if let t = n.tex, let base = g?.copy() as? SCNGeometry {
                base.materials = [Self.texturedMaterial(t)]
                node = SCNNode(geometry: base)
            } else {
                node = SCNNode(geometry: g)
            }
        } else if let pf = n.prefab {
            node = SCNNode()
            for child in layout?.prefabs[pf] ?? [] { node.addChildNode(makeNode(child)) }
        } else {
            let sz = n.size ?? [1, 1, 1]
            let geo: SCNGeometry
            switch n.k ?? "box" {
            case "cyl":
                geo = SCNCylinder(radius: CGFloat(sz[0]), height: CGFloat(sz.count > 1 ? sz[1] : 1))
            case "sphere":
                let s = SCNSphere(radius: CGFloat(sz[0])); s.segmentCount = 36; geo = s
            default:
                let w = CGFloat(sz[0]), h = CGFloat(sz.count > 1 ? sz[1] : sz[0]), l = CGFloat(sz.count > 2 ? sz[2] : sz[0])
                geo = SCNBox(width: w, height: h, length: l, chamferRadius: min(w, h, l) * 0.12)
            }
            geo.materials = [mat(color(n.c), glow: (n.glow ?? 0) > 0)]
            node = SCNNode(geometry: geo)
        }
        node.name = n.name
        let p = n.p ?? [0, 0, 0]
        node.position = SCNVector3(p[0], p[1], p[2])
        let deg = Float.pi / 180
        node.eulerAngles = SCNVector3((n.rx ?? 0) * deg, (n.ry ?? 0) * deg, 0)
        if let s = n.s, s.count == 3 { node.scale = SCNVector3(s[0], s[1], s[2]) }
        if (n.bob ?? 0) > 0 {
            let up = SCNAction.moveBy(x: 0, y: 0.18, z: 0, duration: 1.4)
            up.timingMode = .easeInEaseOut
            let down = up.reversed()
            node.runAction(.repeatForever(.sequence([up, down])))
        }
        return node
    }

    /// 程序化纹理：木纹 / 石块明暗（在模型本地坐标里计算，不需要贴图）
    private static func texturedMaterial(_ kind: String) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor.white
        m.lightingModel = .lambert
        let wood = """
        float3 mp = (scn_node.inverseModelViewTransform * float4(_surface.position, 1.0)).xyz;
        float plank = floor(mp.x * 2.2);
        float h = fract(sin(plank * 12.9898) * 43758.5453);
        float grain = sin(mp.z * 9.0 + sin(mp.x * 31.0 + h * 6.0) * 1.6 + h * 20.0);
        float seam = smoothstep(0.0, 0.06, fract(mp.x * 2.2)) * smoothstep(1.0, 0.94, fract(mp.x * 2.2));
        float k = (0.86 + 0.18 * h) * (0.93 + 0.07 * grain) * mix(0.55, 1.0, seam);
        _surface.diffuse.rgb *= k;
        """
        let stone = """
        float3 mp = (scn_node.inverseModelViewTransform * float4(_surface.position, 1.0)).xyz;
        float2 c = floor(mp.xz * 3.0);
        float h = fract(sin(dot(c, float2(12.9898, 78.233))) * 43758.5453);
        float2 f = fract(mp.xz * 3.0);
        float edge = smoothstep(0.0, 0.10, min(min(f.x, f.y), min(1.0 - f.x, 1.0 - f.y)));
        float3 tint = mix(float3(0.92, 0.88, 0.82), float3(1.08, 1.04, 0.98), h);
        _surface.diffuse.rgb *= tint * mix(0.7, 1.0, edge);
        """
        m.shaderModifiers = [.surface: kind == "stone" ? stone : wood]
        return m
    }

    private func addFoam(at p: [Float], radius: Float) {
        let plane = SCNPlane(width: CGFloat(radius * 2), height: CGFloat(radius * 2))
        let m = SCNMaterial()
        m.diffuse.contents = BubbleArt.foamRing
        m.lightingModel = .constant
        m.writesToDepthBuffer = false
        m.blendMode = .alpha
        plane.materials = [m]
        let node = SCNNode(geometry: plane)
        node.eulerAngles.x = -Float.pi / 2
        node.position = SCNVector3(p[0], 0.08, p[2])
        node.castsShadow = false
        let grow = SCNAction.scale(to: 1.12, duration: 1.6)
        grow.timingMode = .easeInEaseOut
        let shrink = SCNAction.scale(to: 0.95, duration: 1.6)
        shrink.timingMode = .easeInEaseOut
        node.runAction(.repeatForever(.sequence([grow, shrink])))
        scene.rootNode.addChildNode(node)
    }

    private func buildPort() {
        guard let layout else { return }
        for n in layout.nodes {
            scene.rootNode.addChildNode(makeNode(n))
        }
        // 码头前沿一条长泡沫带
        // 招牌文字
        let text = SCNText(string: tr("鱼市场", "MARKET"), extrusionDepth: 0.03)
        text.font = UIFont.systemFont(ofSize: 1, weight: .heavy)
        text.flatness = 0.02
        text.materials = [mat(UIColor(red: 1, green: 0.95, blue: 0.82, alpha: 1))]
        let tn = SCNNode(geometry: text)
        let (minB, maxB) = tn.boundingBox
        tn.pivot = SCNMatrix4MakeTranslation((minB.x + maxB.x) / 2, (minB.y + maxB.y) / 2, 0)
        let ts: Float = CoreLang.english ? 0.55 : 0.78
        tn.scale = SCNVector3(ts, ts, ts)
        tn.position = SCNVector3(-5.2, 4.86, 8.98)
        scene.rootNode.addChildNode(tn)
        // 黑板上的“今日渔获”
        let chalk = SCNText(string: tr("今日渔获", "TODAY"), extrusionDepth: 0.01)
        chalk.font = UIFont.systemFont(ofSize: 1, weight: .bold)
        chalk.flatness = 0.03
        chalk.materials = [mat(.white)]
        let cn = SCNNode(geometry: chalk)
        let (cmin, cmax) = cn.boundingBox
        cn.pivot = SCNMatrix4MakeTranslation((cmin.x + cmax.x) / 2, (cmin.y + cmax.y) / 2, 0)
        let cs: Float = CoreLang.english ? 0.17 : 0.22
        cn.scale = SCNVector3(cs, cs, cs)
        cn.position = SCNVector3(0.8, 1.75, 7.47)
        cn.eulerAngles.x = -12 * Float.pi / 180
        scene.rootNode.addChildNode(cn)
    }

    /// 木质小船 + 船舱 + 小熊船长；顶部挂气泡
    private func makeBoat(colorIndex: Int) -> SCNNode {
        let root = SCNNode()
        let body = SCNNode()
        root.addChildNode(body)
        for n in layout?.prefabs["boat"] ?? [] { body.addChildNode(makeNode(n)) }
        let accent = Self.accents[colorIndex % Self.accents.count]
        body.enumerateHierarchy { n, _ in
            if n.name == "accent" { n.geometry = n.geometry?.copy() as? SCNGeometry; n.geometry?.materials = [mat(accent)] }
        }
        body.scale = SCNVector3(1.4, 1.4, 1.4)
        addFoam(to: root)
        let bob = SCNAction.sequence([.moveBy(x: 0, y: 0.12, z: 0, duration: 1.1), .moveBy(x: 0, y: -0.12, z: 0, duration: 1.1)])
        bob.timingMode = .easeInEaseOut
        body.runAction(.repeatForever(bob))
        let rock = SCNAction.sequence([.rotateBy(x: 0, y: 0, z: 0.05, duration: 1.4), .rotateBy(x: 0, y: 0, z: -0.05, duration: 1.4)])
        rock.timingMode = .easeInEaseOut
        body.runAction(.repeatForever(rock))
        // 气泡（不随船转向：挂在独立节点上，用 billboard 约束）
        let bubble = SCNNode(geometry: SCNPlane(width: 2.4, height: 2.2))
        bubble.name = "bubble"
        bubble.position = SCNVector3(0, 4.6, 0)
        let bc = SCNBillboardConstraint()
        bubble.constraints = [bc]
        bubble.isHidden = true
        bubble.castsShadow = false
        bubble.renderingOrder = 100
        root.addChildNode(bubble)
        return root
    }

    private func addFoam(to boat: SCNNode) {
        let plane = SCNPlane(width: 4.2, height: 5.4)
        let m = SCNMaterial()
        m.diffuse.contents = BubbleArt.foamRing
        m.lightingModel = .constant
        m.writesToDepthBuffer = false
        plane.materials = [m]
        let wake = SCNNode(geometry: plane)
        wake.eulerAngles.x = -Float.pi / 2
        wake.position = SCNVector3(0, 0.1, 0)
        wake.castsShadow = false
        boat.addChildNode(wake)
    }

    private func setBubble(_ boat: SCNNode, id: UUID, key: String?, image: () -> UIImage, width: CGFloat, height: CGFloat) {
        guard let bubble = boat.childNode(withName: "bubble", recursively: false) else { return }
        guard let key else { bubble.isHidden = true; bubbleKeys[id] = nil; return }
        bubble.isHidden = false
        if bubbleKeys[id] == key { return }
        bubbleKeys[id] = key
        let plane = SCNPlane(width: width, height: height)
        let m = SCNMaterial()
        m.diffuse.contents = image()
        m.lightingModel = .constant
        m.readsFromDepthBuffer = false
        m.writesToDepthBuffer = false
        plane.materials = [m]
        bubble.geometry = plane
    }

    private func updateBubble(_ boat: SCNNode, captain c: Captain, state: GameState, config: EconomyConfig) {
        switch c.phase {
        case .returning, .unloading:
            setBubble(boat, id: c.id, key: "fish1", image: { BubbleArt.fishBubble(count: 1) }, width: 3.0, height: 2.7)
        case .sailingOut, .fishing:
            let el = c.phaseElapsed
            var rem = GameState.phaseDuration(c, c.phase, config) - el
            if c.phase == .sailingOut { rem += GameState.phaseDuration(c, .fishing, config) }
            rem += GameState.phaseDuration(c, .returning, config)
            let total = GameState.tripDuration(c, config)
            let secs = max(0, Int(rem.rounded(.up)))
            let text = String(format: "%02d:%02d", secs / 60, secs % 60)
            let prog = total > 0 ? 1 - rem / total : 0
            let key = text + "|" + String(Int(prog * 20))
            setBubble(boat, id: c.id, key: key, image: { BubbleArt.timerPill(text, progress: prog) }, width: 4.2, height: 1.55)
        }
    }

    // MARK: - 同步

    /// 每个海域在画面中的渔场位置（越远越靠上）
    private func fishingSpot(for areaIndex: Int, lane: Int) -> SCNVector3 {
        let z = -4.0 - Double(min(areaIndex, 7)) * 3.2
        let x = Double(Self.laneX(lane))
        return SCNVector3(Float(x), 0, Float(z))
    }

    private func berth(lane: Int) -> SCNVector3 {
        SCNVector3(Self.laneX(lane), 0, dockPosition.z - 2.3)
    }

    func sync(state: GameState, config: EconomyConfig) {
        let ids = Set(state.captains.map(\.id))
        for (id, node) in boats where !ids.contains(id) {
            node.removeFromParentNode(); boats[id] = nil; bubbleKeys[id] = nil
        }
        for (lane, c) in state.captains.enumerated() {
            let node: SCNNode
            if let n = boats[c.id] { node = n } else {
                node = makeBoat(colorIndex: lane)
                scene.rootNode.addChildNode(node)
                boats[c.id] = node
            }
            let areaIndex = config.areas.firstIndex { $0.id == c.areaID } ?? 0
            let home = berth(lane: lane)
            let spot = fishingSpot(for: areaIndex, lane: lane)
            let p = Float(state.phaseProgress(c, config: config))
            let pos: SCNVector3
            let dir: (x: Float, z: Float)   // 当前行进方向
            switch c.phase {
            case .sailingOut:
                pos = lerp(home, spot, smooth(p))
                dir = (spot.x - home.x, spot.z - home.z)
            case .fishing:
                // 渔场里绕小椭圆，朝向取切线方向
                let a = p * Float.pi * 2
                pos = SCNVector3(spot.x + sin(a) * 0.8, 0, spot.z + cos(a) * 0.4)
                dir = (cos(a) * 0.8, -sin(a) * 0.4)
            case .returning:
                pos = lerp(spot, home, smooth(p))
                dir = (home.x - spot.x, home.z - spot.z)
            case .unloading:
                pos = home
                dir = (home.x - spot.x, home.z - spot.z)
            }
            // 船头朝 -z：绕 y 轴旋转 θ 后船头为 (-sinθ, -cosθ)
            let target = atan2(-dir.x, -dir.z)
            // 选取与当前角度最近的等价角，避免插值时整圈打转
            var heading = target
            let cur = node.eulerAngles.y
            while heading - cur > Float.pi { heading -= 2 * Float.pi }
            while heading - cur < -Float.pi { heading += 2 * Float.pi }
            // 隐式动画平滑 0.1s 的 tick 间隔
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.12
            node.position = pos
            node.eulerAngles.y = heading
            SCNTransaction.commit()
            updateBubble(node, captain: c, state: state, config: config)
        }
        deOverlapBubbles(state: state)
    }

    /// 气泡互相靠近时向上错开（按离镜头远近排序，近处的保持原高度）
    private func deOverlapBubbles(state: GameState) {
        var placed: [(x: Float, z: Float, y: Float)] = []
        let nodes = state.captains.compactMap { boats[$0.id] }.sorted { $0.position.z > $1.position.z }
        for n in nodes {
            guard let b = n.childNode(withName: "bubble", recursively: false), !b.isHidden else { continue }
            var y: Float = 4.6
            var moved = true
            while moved {
                moved = false
                for p in placed where abs(p.x - n.position.x) < 4.6 && abs(p.z - n.position.z) < 4.0 && abs(p.y - y) < 1.7 {
                    y = p.y + 1.8; moved = true
                }
            }
            placed.append((n.position.x, n.position.z, y))
            if abs(b.position.y - y) > 0.01 {
                SCNTransaction.begin(); SCNTransaction.animationDuration = 0.25
                b.position = SCNVector3(0, y, 0)
                SCNTransaction.commit()
            }
        }
    }

    /// 泊位横向位置：从中间向两侧排开
    private static func laneX(_ lane: Int) -> Float {
        let order: [Float] = [0, -3, 3, -6, 6, -9]
        return order[lane % order.count]
    }

    private func smooth(_ t: Float) -> Float { t * t * (3 - 2 * t) }
    private func lerp(_ a: SCNVector3, _ b: SCNVector3, _ t: Float) -> SCNVector3 {
        SCNVector3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
    }
}
