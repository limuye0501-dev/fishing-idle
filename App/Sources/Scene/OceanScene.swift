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
        let c = layout?.camera ?? PortCamera(pos: [7, 27, 31], look: [0, 0, -3], fov: 42)
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
        light.intensity = 1050
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
        ambient.light!.intensity = 520
        ambient.light!.color = UIColor(red: 0.90, green: 0.93, blue: 1.0, alpha: 1)
        scene.rootNode.addChildNode(ambient)
    }

    private func buildWater() {
        let plane = SCNPlane(width: 140, height: 140)
        plane.widthSegmentCount = 140
        plane.heightSegmentCount = 140
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.25, green: 0.75, blue: 0.82, alpha: 1)
        m.lightingModel = .lambert
        m.shaderModifiers = [
            .geometry: """
            float t = scn_frame.time * 0.8;
            float w = sin(_geometry.position.x * 0.35 + t) * 0.12
                    + cos(_geometry.position.y * 0.28 + t * 1.3) * 0.10;
            _geometry.position.z += w;
            """,
            // 绿松石海水：近岸浅、远海深；叠加两层流动的白色浪花纹
            .surface: """
            float2 uv = _surface.diffuseTexcoord;
            float v = smoothstep(0.25, 0.75, uv.y);
            float3 deep = float3(0.02, 0.27, 0.50);
            float3 shallow = float3(0.07, 0.62, 0.62);
            float3 col = mix(deep, shallow, v);
            float t = scn_frame.time;
            float2 p = uv * 140.0;
            float a = sin(p.x * 1.10 + sin(p.y * 0.9 + t * 0.6) * 1.6 + t * 0.7);
            float b = sin(p.y * 1.35 + sin(p.x * 0.7 - t * 0.5) * 1.8 - t * 0.55);
            float cell = a * b;
            col = mix(col, col * 1.25 + 0.03, smoothstep(0.35, 0.75, cell));
            float foam = smoothstep(0.88, 0.97, cell);
            col = mix(col, float3(0.92, 0.97, 0.97), foam * 0.75);
            _surface.diffuse.rgb = col;
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
            node = SCNNode(geometry: ModelLibrary.shared.geometry(m, tint: n.tint))
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
                let s = SCNSphere(radius: CGFloat(sz[0])); s.segmentCount = 20; geo = s
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
            if let r = n.foam, let p = n.p { addFoam(at: p, radius: r) }
        }
        // 码头前沿一条长泡沫带
        for x in stride(from: -9.0, through: 6.0, by: 1.5) { addFoam(at: [Float(x), 0, 4.9], radius: 1.1) }
        for z in stride(from: -1.0, through: 4.0, by: 1.5) { addFoam(at: [7.6, 0, Float(z)], radius: 1.0); addFoam(at: [10.4, 0, Float(z)], radius: 1.0) }
        // 招牌文字
        let text = SCNText(string: "鱼市场", extrusionDepth: 0.03)
        text.font = UIFont.systemFont(ofSize: 1, weight: .heavy)
        text.flatness = 0.02
        text.materials = [mat(UIColor(red: 1, green: 0.95, blue: 0.82, alpha: 1))]
        let tn = SCNNode(geometry: text)
        let (minB, maxB) = tn.boundingBox
        tn.pivot = SCNMatrix4MakeTranslation((minB.x + maxB.x) / 2, (minB.y + maxB.y) / 2, 0)
        tn.scale = SCNVector3(0.6, 0.6, 0.6)
        tn.position = SCNVector3(-5.2, 3.88, 8.58)
        scene.rootNode.addChildNode(tn)
        // 黑板上的“今日渔获”
        let chalk = SCNText(string: "今日渔获", extrusionDepth: 0.01)
        chalk.font = UIFont.systemFont(ofSize: 1, weight: .bold)
        chalk.flatness = 0.03
        chalk.materials = [mat(.white)]
        let cn = SCNNode(geometry: chalk)
        let (cmin, cmax) = cn.boundingBox
        cn.pivot = SCNMatrix4MakeTranslation((cmin.x + cmax.x) / 2, (cmin.y + cmax.y) / 2, 0)
        cn.scale = SCNVector3(0.22, 0.22, 0.22)
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
            setBubble(boat, id: c.id, key: "fish1", image: { BubbleArt.fishBubble(count: 1) }, width: 2.3, height: 2.1)
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
            setBubble(boat, id: c.id, key: key, image: { BubbleArt.timerPill(text, progress: prog) }, width: 3.0, height: 1.1)
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
