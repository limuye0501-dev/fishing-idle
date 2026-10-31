import SceneKit
import UIKit
import FishingCore

/// 程序化生成的 Q 版海港场景
final class OceanScene {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private var boats: [UUID: SCNNode] = [:]
    private let dockPosition = SCNVector3(0, 0, 4)

    init() {
        buildCamera()
        buildLights()
        buildWater()
        buildIsland()
        buildDock()
        buildRocksAndBuoys()
    }

    // MARK: - 构建

    private func buildCamera() {
        let cam = SCNCamera()
        cam.fieldOfView = 55
        cam.zFar = 250
        cameraNode.camera = cam
        // 固定俯视斜角：从港口后上方看向海面，港口在画面下部、渔场在上部
        cameraNode.position = SCNVector3(0, 30, 34)
        let look = SCNNode()
        look.position = SCNVector3(0, 0, -3)
        scene.rootNode.addChildNode(look)
        let c = SCNLookAtConstraint(target: look)
        c.isGimbalLockEnabled = true
        cameraNode.constraints = [c]
        scene.rootNode.addChildNode(cameraNode)
    }

    private func buildLights() {
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light!.type = .directional
        sun.light!.intensity = 900
        sun.light!.castsShadow = true
        sun.light!.shadowMode = .deferred
        sun.light!.shadowColor = UIColor.black.withAlphaComponent(0.25)
        sun.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)
        scene.rootNode.addChildNode(sun)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 450
        ambient.light!.color = UIColor(red: 0.85, green: 0.92, blue: 1, alpha: 1)
        scene.rootNode.addChildNode(ambient)
    }

    private func buildWater() {
        let plane = SCNPlane(width: 120, height: 120)
        plane.widthSegmentCount = 120
        plane.heightSegmentCount = 120
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.25, green: 0.70, blue: 0.85, alpha: 1)
        m.lightingModel = .lambert   // 无高光，避免发白
        // 几何着色器：平缓波浪（plane 本地坐标中 z 为法向）
        m.shaderModifiers = [
            .geometry: """
            float t = scn_frame.time * 0.8;
            float w = sin(_geometry.position.x * 0.35 + t) * 0.18
                    + cos(_geometry.position.y * 0.28 + t * 1.3) * 0.14;
            _geometry.position.z += w;
            """,
            // 海水渐变：近岸浅青绿 → 远海深蓝（纹理坐标 v：0 远、1 近）
            .surface: """
            // 注意：着色器在线性色彩空间，颜色值已由 sRGB 换算
            float2 uv = _surface.diffuseTexcoord;
            float v = smoothstep(0.30, 0.85, uv.y);
            float3 deep = float3(0.006, 0.16, 0.42);      // sRGB ≈ (0.08, 0.44, 0.68)
            float3 shallow = float3(0.02, 0.50, 0.55);    // sRGB ≈ (0.15, 0.74, 0.77) 绿松石
            float3 col = mix(deep, shallow, v);
            float t = scn_frame.time;
            float ripple = sin(uv.x * 420.0 + sin(uv.y * 260.0 + t * 0.7) * 2.5 + t * 0.9)
                         * sin(uv.y * 380.0 - t * 0.6);
            col *= 1.0 + 0.10 * smoothstep(0.55, 1.0, ripple);
            _surface.diffuse.rgb = col;
            """
        ]
        plane.materials = [m]
        let node = SCNNode(geometry: plane)
        node.eulerAngles.x = -Float.pi / 2
        node.position = SCNVector3(0, -0.2, -20)
        scene.rootNode.addChildNode(node)
    }

    private func mat(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .lambert // 柔和卡通感
        return m
    }

    private func buildIsland() {
        // 港口小岛：放在镜头前方，靠海一侧朝向远处
        let sand = SCNCylinder(radius: 7, height: 0.8)
        sand.radialSegmentCount = 48
        sand.materials = [mat(UIColor(red: 0.98, green: 0.88, blue: 0.64, alpha: 1))]
        let island = SCNNode(geometry: sand)
        island.position = SCNVector3(0, 0, 11)
        scene.rootNode.addChildNode(island)

        let grass = SCNCylinder(radius: 6, height: 0.3)
        grass.radialSegmentCount = 48
        grass.materials = [mat(UIColor(red: 0.55, green: 0.82, blue: 0.42, alpha: 1))]
        let g = SCNNode(geometry: grass)
        g.position = SCNVector3(0, 0.5, 0.5)
        island.addChildNode(g)

        // 圆滚滚的树（放在两侧和后方，不挡港口）
        for (x, z) in [(-5.0, -1.5), (4.8, -1.8), (2.5, 3.5), (4.6, 1.8), (-1.0, 4.5)] {
            let trunk = SCNNode(geometry: SCNCylinder(radius: 0.25, height: 1.2))
            trunk.geometry?.materials = [mat(UIColor.brown)]
            trunk.position = SCNVector3(Float(x), 1.2, Float(z))
            let crown = SCNNode(geometry: SCNSphere(radius: 1.0))
            crown.geometry?.materials = [mat(UIColor(red: 0.35, green: 0.70, blue: 0.35, alpha: 1))]
            crown.position = SCNVector3(0, 1.1, 0)
            trunk.addChildNode(crown)
            island.addChildNode(trunk)
        }

        // 鱼市场小屋：正面朝镜头（+z），前方立招牌
        let house = SCNNode(geometry: SCNBox(width: 3.2, height: 2.2, length: 2.4, chamferRadius: 0.15))
        house.geometry?.materials = [mat(UIColor(red: 1, green: 0.95, blue: 0.85, alpha: 1))]
        house.position = SCNVector3(-2.2, 1.7, -0.3)
        let roof = SCNNode(geometry: SCNPyramid(width: 3.6, height: 1.2, length: 2.6))
        roof.geometry?.materials = [mat(UIColor(red: 0.85, green: 0.62, blue: 0.30, alpha: 1))]
        roof.position = SCNVector3(0, 1.1, 0)
        house.addChildNode(roof)
        let door = SCNNode(geometry: SCNBox(width: 0.8, height: 1.2, length: 0.05, chamferRadius: 0.05))
        door.geometry?.materials = [mat(UIColor(red: 0.55, green: 0.38, blue: 0.24, alpha: 1))]
        door.position = SCNVector3(0.7, -0.5, 1.22)
        house.addChildNode(door)
        let window = SCNNode(geometry: SCNBox(width: 0.8, height: 0.6, length: 0.05, chamferRadius: 0.05))
        window.geometry?.materials = [mat(UIColor(red: 0.55, green: 0.80, blue: 0.95, alpha: 1))]
        window.position = SCNVector3(-0.7, 0.0, 1.22)
        house.addChildNode(window)
        // 条纹遮阳棚
        for i in 0..<6 {
            let strip = SCNNode(geometry: SCNBox(width: 0.54, height: 0.08, length: 0.8, chamferRadius: 0.02))
            strip.geometry?.materials = [mat(i % 2 == 0 ? UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1) : .white)]
            strip.position = SCNVector3(-1.35 + Float(i) * 0.54, 0.75, 1.55)
            strip.eulerAngles.x = 0.35
            house.addChildNode(strip)
        }
        island.addChildNode(house)

        // 招牌：木板立在屋前，向后仰朝向镜头
        let sign = SCNNode()
        let board = SCNNode(geometry: SCNBox(width: 2.6, height: 1.0, length: 0.12, chamferRadius: 0.08))
        board.geometry?.materials = [mat(UIColor(red: 0.50, green: 0.32, blue: 0.18, alpha: 1))]
        sign.addChildNode(board)
        let text = SCNText(string: "鱼市场", extrusionDepth: 0.02)
        text.font = UIFont.systemFont(ofSize: 1, weight: .heavy)
        text.flatness = 0.02
        text.materials = [mat(UIColor(red: 1, green: 0.96, blue: 0.85, alpha: 1))]
        let tn = SCNNode(geometry: text)
        let (minB, maxB) = tn.boundingBox
        tn.pivot = SCNMatrix4MakeTranslation((minB.x + maxB.x) / 2, (minB.y + maxB.y) / 2, 0)
        tn.scale = SCNVector3(0.7, 0.7, 0.7)
        tn.position = SCNVector3(0, 0, 0.07)
        sign.addChildNode(tn)
        for x: Float in [-1.0, 1.0] {
            let leg = SCNNode(geometry: SCNCylinder(radius: 0.07, height: 1.0))
            leg.geometry?.materials = [mat(UIColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1))]
            leg.position = SCNVector3(x, -0.8, -0.05)
            sign.addChildNode(leg)
        }
        sign.position = SCNVector3(-2.2, 1.9, 2.2)
        sign.eulerAngles.x = -0.55
        island.addChildNode(sign)
    }

    private func buildDock() {
        let wood = mat(UIColor(red: 0.72, green: 0.52, blue: 0.33, alpha: 1))
        let darkWood = mat(UIColor(red: 0.55, green: 0.38, blue: 0.24, alpha: 1))
        // 码头平台：从小岛靠海边缘伸向海面，位于镜头正前方
        let deck = SCNNode(geometry: SCNBox(width: 15, height: 0.35, length: 3.2, chamferRadius: 0.1))
        deck.geometry?.materials = [wood]
        deck.position = SCNVector3(0, 0.45, dockPosition.z + 1.6)
        scene.rootNode.addChildNode(deck)
        // 木板缝
        for x in stride(from: -7.0, through: 7.0, by: 1.0) {
            let line = SCNNode(geometry: SCNBox(width: 0.05, height: 0.36, length: 3.2, chamferRadius: 0))
            line.geometry?.materials = [darkWood]
            line.position = SCNVector3(Float(x), 0.46, dockPosition.z + 1.6)
            scene.rootNode.addChildNode(line)
        }
        // 前沿木桩 + 绳子
        for x in stride(from: -7.2, through: 7.2, by: 2.4) {
            let post = SCNNode(geometry: SCNCylinder(radius: 0.2, height: 1.6))
            post.geometry?.materials = [darkWood]
            post.position = SCNVector3(Float(x), 0.5, dockPosition.z + 0.1)
            scene.rootNode.addChildNode(post)
        }
        let rope = SCNNode(geometry: SCNCylinder(radius: 0.05, height: 14.4))
        rope.geometry?.materials = [mat(UIColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1))]
        rope.eulerAngles.z = Float.pi / 2
        rope.position = SCNVector3(0, 1.1, dockPosition.z + 0.1)
        scene.rootNode.addChildNode(rope)
        // 木箱、木桶、路灯
        for (x, dz) in [(5.6, 2.3), (6.5, 2.3), (6.05, 2.3)] {
            let crate = SCNNode(geometry: SCNBox(width: 0.8, height: 0.8, length: 0.8, chamferRadius: 0.06))
            crate.geometry?.materials = [wood]
            crate.position = SCNVector3(Float(x), x == 6.05 ? 1.8 : 1.0, dockPosition.z + Float(dz))
            scene.rootNode.addChildNode(crate)
        }
        let barrel = SCNNode(geometry: SCNCylinder(radius: 0.45, height: 1.0))
        barrel.geometry?.materials = [darkWood]
        barrel.position = SCNVector3(-6.2, 1.1, dockPosition.z + 2.3)
        scene.rootNode.addChildNode(barrel)
        let lamp = SCNNode(geometry: SCNCylinder(radius: 0.08, height: 2.2))
        lamp.geometry?.materials = [mat(.darkGray)]
        lamp.position = SCNVector3(7.2, 1.7, dockPosition.z + 1.0)
        let bulb = SCNNode(geometry: SCNSphere(radius: 0.25))
        let glow = SCNMaterial(); glow.diffuse.contents = UIColor.systemYellow; glow.emission.contents = UIColor.systemYellow
        bulb.geometry?.materials = [glow]
        bulb.position = SCNVector3(0, 1.2, 0)
        lamp.addChildNode(bulb)
        scene.rootNode.addChildNode(lamp)
    }

    private func buildRocksAndBuoys() {
        let rockMat = mat(UIColor(red: 0.55, green: 0.52, blue: 0.50, alpha: 1))
        let spots: [(Float, Float, Float, Bool)] = [(-9, -3, 1.6, true), (10, -9, 2.0, false),
                                                    (-11, -16, 1.4, false), (9, -22, 1.8, true)]
        for (x, z, r, green) in spots {
            let sph = SCNSphere(radius: CGFloat(r))
            sph.segmentCount = 7   // 低多边形，石头更有棱角
            sph.materials = [rockMat]
            let rock = SCNNode(geometry: sph)
            rock.scale = SCNVector3(1.2, 0.6, 1.0)
            rock.position = SCNVector3(x, 0, z)
            scene.rootNode.addChildNode(rock)
            if green {
                let bush = SCNNode(geometry: SCNSphere(radius: CGFloat(r) * 0.5))
                bush.geometry?.materials = [mat(UIColor(red: 0.45, green: 0.75, blue: 0.35, alpha: 1))]
                bush.position = SCNVector3(x, r * 0.55, z)
                scene.rootNode.addChildNode(bush)
            }
        }
        for (i, p) in [(-4.5, -1.5), (4.5, -7.0), (-3.0, -13.0), (5.5, -19.0)].enumerated() {
            let buoy = SCNNode()
            let base = SCNNode(geometry: SCNCylinder(radius: 0.3, height: 0.6))
            base.geometry?.materials = [mat(i % 2 == 0 ? .systemRed : .white)]
            let top = SCNNode(geometry: SCNSphere(radius: 0.22))
            top.geometry?.materials = [mat(i % 2 == 0 ? .white : .systemRed)]
            top.position.y = 0.45
            buoy.addChildNode(base); buoy.addChildNode(top)
            buoy.position = SCNVector3(Float(p.0), 0.1, Float(p.1))
            let bob = SCNAction.sequence([.moveBy(x: 0, y: 0.2, z: 0, duration: 1.3 + Double(i) * 0.2),
                                          .moveBy(x: 0, y: -0.2, z: 0, duration: 1.3 + Double(i) * 0.2)])
            bob.timingMode = .easeInEaseOut
            buoy.runAction(.repeatForever(bob))
            scene.rootNode.addChildNode(buoy)
        }
    }

    /// 玩具风格小船：圆角船身 + 船舱 + 桅杆 + 帆 + 圆滚滚的船长
    private func makeBoat(colorIndex: Int) -> SCNNode {
        let palette: [UIColor] = [.systemRed, .systemOrange, .systemPink, .systemPurple, .systemYellow, .systemGreen]
        let root = SCNNode()
        let body = SCNNode()
        root.addChildNode(body)
        let hull = SCNNode(geometry: SCNBox(width: 1.4, height: 0.6, length: 2.6, chamferRadius: 0.3))
        hull.geometry?.materials = [mat(UIColor(red: 0.70, green: 0.48, blue: 0.30, alpha: 1))]
        hull.position.y = 0.3
        body.addChildNode(hull)
        let stripe = SCNNode(geometry: SCNBox(width: 1.45, height: 0.15, length: 2.5, chamferRadius: 0.07))
        stripe.geometry?.materials = [mat(palette[colorIndex % palette.count])]
        stripe.position.y = 0.5
        body.addChildNode(stripe)
        let cabin = SCNNode(geometry: SCNBox(width: 0.9, height: 0.7, length: 0.8, chamferRadius: 0.12))
        cabin.geometry?.materials = [mat(.white)]
        cabin.position = SCNVector3(0, 0.95, 0.75)
        let cabinRoof = SCNNode(geometry: SCNBox(width: 1.05, height: 0.12, length: 0.95, chamferRadius: 0.05))
        cabinRoof.geometry?.materials = [mat(palette[colorIndex % palette.count])]
        cabinRoof.position.y = 0.4
        cabin.addChildNode(cabinRoof)
        body.addChildNode(cabin)
        let mast = SCNNode(geometry: SCNCylinder(radius: 0.06, height: 1.6))
        mast.geometry?.materials = [mat(.brown)]
        mast.position = SCNVector3(0, 1.4, -0.7)
        body.addChildNode(mast)
        let flag = SCNNode(geometry: SCNBox(width: 0.02, height: 0.3, length: 0.45, chamferRadius: 0))
        flag.geometry?.materials = [mat(palette[colorIndex % palette.count])]
        flag.position = SCNVector3(0, 2.05, -0.5)
        body.addChildNode(flag)
        // 船长：身体 + 大圆头 + 白帽
        let captain = SCNNode()
        let torso = SCNNode(geometry: SCNCapsule(capRadius: 0.22, height: 0.6))
        torso.geometry?.materials = [mat(UIColor(red: 0.15, green: 0.25, blue: 0.55, alpha: 1))]
        captain.addChildNode(torso)
        let head = SCNNode(geometry: SCNSphere(radius: 0.3))
        head.geometry?.materials = [mat(UIColor(red: 0.95, green: 0.78, blue: 0.55, alpha: 1))]
        head.position.y = 0.48
        captain.addChildNode(head)
        let cap = SCNNode(geometry: SCNCylinder(radius: 0.26, height: 0.14))
        cap.geometry?.materials = [mat(.white)]
        cap.position.y = 0.76
        captain.addChildNode(cap)
        let brim = SCNNode(geometry: SCNCylinder(radius: 0.12, height: 0.04))
        brim.geometry?.materials = [mat(UIColor(red: 0.15, green: 0.2, blue: 0.4, alpha: 1))]
        brim.position = SCNVector3(0, 0.7, -0.24)
        captain.addChildNode(brim)
        captain.position = SCNVector3(0, 0.9, -0.1)
        captain.scale = SCNVector3(1.5, 1.5, 1.5)
        body.addChildNode(captain)
        body.scale = SCNVector3(1.8, 1.8, 1.8)
        // 上下浮动 + 轻微摇摆
        let bob = SCNAction.sequence([
            .moveBy(x: 0, y: 0.15, z: 0, duration: 1.1),
            .moveBy(x: 0, y: -0.15, z: 0, duration: 1.1)
        ])
        bob.timingMode = .easeInEaseOut
        body.runAction(.repeatForever(bob))
        let rock = SCNAction.sequence([.rotateBy(x: 0, y: 0, z: 0.06, duration: 1.4),
                                       .rotateBy(x: 0, y: 0, z: -0.06, duration: 1.4)])
        rock.timingMode = .easeInEaseOut
        body.runAction(.repeatForever(rock))
        return root
    }

    // MARK: - 同步

    /// 每个海域在画面中的渔场位置（越远越靠上）
    private func fishingSpot(for areaIndex: Int, lane: Int) -> SCNVector3 {
        let z = -4.0 - Double(areaIndex) * 7
        let x = Double(Self.laneX(lane))
        return SCNVector3(Float(x), 0, Float(z))
    }

    private func berth(lane: Int) -> SCNVector3 {
        SCNVector3(Self.laneX(lane), 0, dockPosition.z - 2.2)
    }

    func sync(state: GameState, config: EconomyConfig) {
        let ids = Set(state.captains.map(\.id))
        for (id, node) in boats where !ids.contains(id) {
            node.removeFromParentNode(); boats[id] = nil
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
        }
    }

    /// 泊位横向位置：从中间向两侧排开
    private static func laneX(_ lane: Int) -> Float {
        let order: [Float] = [0, -2.7, 2.7, -5.4, 5.4, -8.1]
        return order[lane % order.count]
    }

    private func smooth(_ t: Float) -> Float { t * t * (3 - 2 * t) }
    private func lerp(_ a: SCNVector3, _ b: SCNVector3, _ t: Float) -> SCNVector3 {
        SCNVector3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
    }
}
