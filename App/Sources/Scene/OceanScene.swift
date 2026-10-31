import SceneKit
import UIKit
import FishingCore

/// 程序化生成的 Q 版海港场景
final class OceanScene {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private var boats: [UUID: SCNNode] = [:]
    private let dockPosition = SCNVector3(0, 0, 6)

    init() {
        buildCamera()
        buildLights()
        buildWater()
        buildIsland()
        buildDock()
    }

    // MARK: - 构建

    private func buildCamera() {
        let cam = SCNCamera()
        cam.fieldOfView = 50
        cam.zFar = 200
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 22, 22)
        cameraNode.eulerAngles = SCNVector3(-Float.pi / 4.2, 0, 0) // 固定俯视角
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
        m.specular.contents = UIColor.white
        m.shininess = 0.6
        m.lightingModel = .blinn
        // 几何着色器：平缓波浪（plane 本地坐标中 z 为法向）
        m.shaderModifiers = [
            .geometry: """
            float t = scn_frame.time * 0.8;
            float w = sin(_geometry.position.x * 0.35 + t) * 0.18
                    + cos(_geometry.position.y * 0.28 + t * 1.3) * 0.14;
            _geometry.position.z += w;
            """,
            .fragment: """
            float glint = step(0.985, fract(sin(dot(floor(_surface.diffuseTexcoord * 160.0), float2(12.9898, 78.233))) * 43758.5453 + scn_frame.time * 0.15));
            _output.color.rgb = mix(_output.color.rgb, float3(1.0), glint * 0.35);
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
        let sand = SCNCylinder(radius: 9, height: 1)
        sand.materials = [mat(UIColor(red: 0.98, green: 0.88, blue: 0.64, alpha: 1))]
        let island = SCNNode(geometry: sand)
        island.position = SCNVector3(0, 0, 13)
        scene.rootNode.addChildNode(island)

        let grass = SCNCylinder(radius: 7, height: 0.4)
        grass.materials = [mat(UIColor(red: 0.55, green: 0.82, blue: 0.42, alpha: 1))]
        let g = SCNNode(geometry: grass)
        g.position = SCNVector3(0, 0.65, 0.8)
        island.addChildNode(g)

        // 圆滚滚的树
        for (x, z) in [(-4.0, 2.0), (4.5, 1.0), (-2.0, 4.0), (2.5, 4.5)] {
            let trunk = SCNNode(geometry: SCNCylinder(radius: 0.25, height: 1.2))
            trunk.geometry?.materials = [mat(UIColor.brown)]
            trunk.position = SCNVector3(Float(x), 1.4, Float(z))
            let crown = SCNNode(geometry: SCNSphere(radius: 1.0))
            crown.geometry?.materials = [mat(UIColor(red: 0.35, green: 0.70, blue: 0.35, alpha: 1))]
            crown.position = SCNVector3(0, 1.1, 0)
            trunk.addChildNode(crown)
            island.addChildNode(trunk)
        }

        // 小房子
        let house = SCNNode(geometry: SCNBox(width: 2, height: 1.6, length: 2, chamferRadius: 0.2))
        house.geometry?.materials = [mat(UIColor(red: 1, green: 0.95, blue: 0.85, alpha: 1))]
        house.position = SCNVector3(0, 1.6, 2)
        let roof = SCNNode(geometry: SCNPyramid(width: 2.6, height: 1.2, length: 2.6))
        roof.geometry?.materials = [mat(UIColor(red: 0.95, green: 0.45, blue: 0.4, alpha: 1))]
        roof.position = SCNVector3(0, 0.8, 0)
        house.addChildNode(roof)
        island.addChildNode(house)
    }

    private func buildDock() {
        let wood = mat(UIColor(red: 0.72, green: 0.52, blue: 0.33, alpha: 1))
        let deck = SCNNode(geometry: SCNBox(width: 10, height: 0.3, length: 2, chamferRadius: 0.1))
        deck.geometry?.materials = [wood]
        deck.position = SCNVector3(0, 0.4, dockPosition.z + 1.5)
        scene.rootNode.addChildNode(deck)
        for x in stride(from: -4.5, through: 4.5, by: 1.5) {
            let post = SCNNode(geometry: SCNCylinder(radius: 0.15, height: 1.2))
            post.geometry?.materials = [wood]
            post.position = SCNVector3(Float(x), 0.1, dockPosition.z + 0.6)
            scene.rootNode.addChildNode(post)
        }
    }

    /// 玩具风格小船：圆角船身 + 船舱 + 桅杆 + 帆
    private func makeBoat(colorIndex: Int) -> SCNNode {
        let palette: [UIColor] = [.systemRed, .systemOrange, .systemPink, .systemPurple, .systemYellow, .systemGreen]
        let root = SCNNode()
        let hull = SCNNode(geometry: SCNBox(width: 1.4, height: 0.6, length: 2.6, chamferRadius: 0.3))
        hull.geometry?.materials = [mat(palette[colorIndex % palette.count])]
        hull.position.y = 0.3
        root.addChildNode(hull)
        let cabin = SCNNode(geometry: SCNBox(width: 0.9, height: 0.6, length: 0.9, chamferRadius: 0.15))
        cabin.geometry?.materials = [mat(.white)]
        cabin.position = SCNVector3(0, 0.9, 0.5)
        root.addChildNode(cabin)
        let mast = SCNNode(geometry: SCNCylinder(radius: 0.06, height: 1.8))
        mast.geometry?.materials = [mat(.brown)]
        mast.position = SCNVector3(0, 1.5, -0.4)
        root.addChildNode(mast)
        let sail = SCNNode(geometry: SCNPyramid(width: 0.05, height: 1.3, length: 1.0))
        sail.geometry?.materials = [mat(UIColor(white: 0.97, alpha: 1))]
        sail.position = SCNVector3(0, 0.9, -0.9)
        root.addChildNode(sail)
        // 上下浮动
        let bob = SCNAction.sequence([
            .moveBy(x: 0, y: 0.15, z: 0, duration: 1.1),
            .moveBy(x: 0, y: -0.15, z: 0, duration: 1.1)
        ])
        bob.timingMode = .easeInEaseOut
        hull.runAction(.repeatForever(bob))
        return root
    }

    // MARK: - 同步

    /// 每个海域在画面中的渔场位置（越远越靠上）
    private func fishingSpot(for areaIndex: Int, lane: Int) -> SCNVector3 {
        let z = -6.0 - Double(areaIndex) * 9
        let x = Double(lane - 2) * 3.2
        return SCNVector3(Float(x), 0, Float(z))
    }

    private func berth(lane: Int) -> SCNVector3 {
        SCNVector3(Float(lane - 2) * 3.2, 0, dockPosition.z - 1)
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
            var heading: Float = 0 // 0 = 朝 -z（出海方向）
            switch c.phase {
            case .sailingOut:
                pos = lerp(home, spot, smooth(p))
            case .fishing:
                // 渔场里绕小圈
                let a = p * Float.pi * 2
                pos = SCNVector3(spot.x + sin(a) * 0.8, 0, spot.z + cos(a) * 0.4)
                heading = -a
            case .returning:
                pos = lerp(spot, home, smooth(p))
                heading = Float.pi
            case .unloading:
                pos = home
                heading = Float.pi
            }
            // 隐式动画平滑 0.1s 的 tick 间隔
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.12
            node.position = pos
            node.eulerAngles.y = heading
            SCNTransaction.commit()
        }
    }

    private func smooth(_ t: Float) -> Float { t * t * (3 - 2 * t) }
    private func lerp(_ a: SCNVector3, _ b: SCNVector3, _ t: Float) -> SCNVector3 {
        SCNVector3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
    }
}
