import SceneKit
import UIKit

/// 加载 Blender 制作的 USDZ 模型（烘焙 AO + 柔和色块贴图）；失败时返回 nil，由程序化模型兜底
enum ModelAssets {
    static func load(_ name: String) -> SCNNode? {
        let url = Bundle.main.url(forResource: name, withExtension: "usdz", subdirectory: "Models")
            ?? Bundle.main.url(forResource: name, withExtension: "usdz")
        guard let url, let s = try? SCNScene(url: url, options: [.checkConsistency: false]) else { return nil }
        let root = SCNNode(); root.name = name
        for c in s.rootNode.childNodes { root.addChildNode(c) }
        root.enumerateHierarchy { n, _ in
            n.castsShadow = true
            for m in n.geometry?.materials ?? [] {
                m.lightingModel = .physicallyBased
                m.metalness.contents = 0.0
                if m.roughness.contents == nil { m.roughness.contents = 0.65 }
                m.isDoubleSided = true
            }
        }
        return root
    }

    struct Ship { let node: SCNNode; let windows: SCNMaterial?; let radar: SCNNode?; let net: SCNNode?; let flag: SCNNode?; let lantern: SCNNode? }

    static func ship() -> Ship? {
        guard let n = load("Ship") else { return nil }
        let windows = n.childNode(withName: "Windows", recursively: true)
        let wm = firstMaterial(windows)
        wm?.roughness.contents = 0.08
        let lantern = n.childNode(withName: "Lantern", recursively: true)
        if let lm = firstMaterial(lantern) { lm.emission.contents = UIColor(red: 1, green: 0.62, blue: 0.42, alpha: 1) }
        // 柔和暖色底光：轻微自发光避免阴影过黑（治愈色调）
        n.enumerateHierarchy { c, _ in
            for m in c.geometry?.materials ?? [] where m !== wm && c.name != "Lantern" && !(c.parent?.name == "Lantern") {
                m.emission.contents = UIColor(red: 0.04, green: 0.03, blue: 0.025, alpha: 1)   // v7.4：减弱，恢复对比
            }
        }
        return Ship(node: n, windows: wm,
                    radar: n.childNode(withName: "Radar", recursively: true),
                    net: n.childNode(withName: "Net", recursively: true),
                    flag: n.childNode(withName: "Flag", recursively: true),
                    lantern: lantern)
    }

    /// 小船长：Head、ArmR（挥手）为 Blender 中的空物体，局部坐标仍是 Z 向上
    static func captain() -> SCNNode? {
        guard let n = load("Captain") else { return nil }
        if let arm = n.childNode(withName: "ArmR", recursively: true) {
            let base = arm.eulerAngles
            func to(_ dx: Float, _ t: TimeInterval) -> SCNAction {
                let a = SCNAction.rotateTo(x: CGFloat(base.x + dx), y: CGFloat(base.y), z: CGFloat(base.z), duration: t); a.timingMode = .easeInEaseOut; return a
            }
            arm.runAction(.repeatForever(.sequence([to(-0.45, 0.32), to(0.1, 0.32), to(-0.45, 0.32), to(0.1, 0.32), to(0, 0.3), .wait(duration: 2.4)])))
        }
        if let head = n.childNode(withName: "Head", recursively: true) {
            let b = head.eulerAngles
            let tilt = SCNAction.sequence([.rotateTo(x: CGFloat(b.x + 0.05), y: CGFloat(b.y + 0.06), z: CGFloat(b.z + 0.08), duration: 1.8),
                                           .rotateTo(x: CGFloat(b.x - 0.04), y: CGFloat(b.y - 0.05), z: CGFloat(b.z - 0.06), duration: 1.8)])
            tilt.timingMode = .easeInEaseOut
            head.runAction(.repeatForever(tilt))
        }
        // v7.1：提亮（贴图自发光 + 正面补光/轮廓光），整体挥手式摇摆
        n.enumerateHierarchy { c, _ in
            for m in c.geometry?.materials ?? [] { m.emission.contents = m.diffuse.contents; m.emission.intensity = 0.22 }
        }
        let fill = SCNNode(); fill.light = SCNLight(); fill.light!.type = .omni; fill.light!.intensity = 90
        fill.light!.color = UIColor(red: 1, green: 0.93, blue: 0.85, alpha: 1); fill.light!.attenuationStartDistance = 0.2; fill.light!.attenuationEndDistance = 1.2
        fill.position = SCNVector3(0.9, 1.0, 0.2); n.addChildNode(fill)
        let rim = SCNNode(); rim.light = SCNLight(); rim.light!.type = .omni; rim.light!.intensity = 70
        rim.light!.color = UIColor(red: 1, green: 0.8, blue: 0.6, alpha: 1); rim.light!.attenuationStartDistance = 0.2; rim.light!.attenuationEndDistance = 0.9
        rim.position = SCNVector3(-0.7, 1.4, -0.3); n.addChildNode(rim)
        if n.childNode(withName: "ArmR", recursively: true) == nil {
            func sw(_ a: Float, _ t: TimeInterval) -> SCNAction { let x = SCNAction.rotateTo(x: 0, y: 0, z: CGFloat(a), duration: t, usesShortestUnitArc: true); x.timingMode = .easeInEaseOut; return x }
            let hop = SCNAction.sequence([.moveBy(x: 0, y: 0.05, z: 0, duration: 0.18), .moveBy(x: 0, y: -0.05, z: 0, duration: 0.18)])
            let wave = SCNAction.sequence([sw(0.08, 0.3), sw(-0.08, 0.3), sw(0.08, 0.3), sw(0, 0.3), hop, .wait(duration: 2.6)])
            let body = SCNNode(); body.name = "CaptainWave"
            for c in n.childNodes { body.addChildNode(c) }
            n.addChildNode(body); body.runAction(.repeatForever(wave))
        }
        let breathe = SCNAction.sequence([.scale(to: 1.02, duration: 1.2), .scale(to: 1.0, duration: 1.2)])
        breathe.timingMode = .easeInEaseOut
        (n.childNode(withName: "CaptainWave", recursively: false) ?? n.childNodes.first)?.runAction(.repeatForever(breathe))
        return n
    }

    /// v7.1：Meshy 船体为单网格，补充可动小部件：雷达、旗、灯笼、驾驶室窗光。返回窗户材质（夜间发光）
    static func addProceduralParts(to ship: SCNNode) -> SCNMaterial {
        func mat(_ c: UIColor, emit: UIColor = .black) -> SCNMaterial { let m = SCNMaterial(); m.lightingModel = .physicallyBased; m.diffuse.contents = c; m.roughness.contents = 0.6; m.emission.contents = emit; return m }
        let radar = SCNNode(); radar.name = "Radar"; radar.position = SCNVector3(-2.4, 2.85, 0.15)
        let pole = SCNNode(geometry: SCNCylinder(radius: 0.03, height: 0.3)); pole.geometry!.materials = [mat(.darkGray)]; pole.position.y = 0.15; radar.addChildNode(pole)
        let bar = SCNNode(geometry: SCNBox(width: 0.7, height: 0.07, length: 0.1, chamferRadius: 0.03)); bar.geometry!.materials = [mat(UIColor(white: 0.92, alpha: 1))]; bar.position.y = 0.32; radar.addChildNode(bar)
        radar.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4))); ship.addChildNode(radar)
        let flagRoot = SCNNode(); flagRoot.name = "Flag"; flagRoot.position = SCNVector3(0.5, 5.05, 0.4)
        let fp = SCNPlane(width: 0.55, height: 0.32); fp.widthSegmentCount = 8
        let fm = mat(UIColor(red: 0.85, green: 0.3, blue: 0.28, alpha: 1)); fm.isDoubleSided = true; fp.materials = [fm]
        fp.heightSegmentCount = 2; fp.widthSegmentCount = 16
        // v7.5：布料感——沿旗面传播的波浪（旗杆端固定）
        fm.shaderModifiers = [.geometry: """
        float u = clamp((0.275 - _geometry.position.x) / 0.55, 0.0, 1.0);
        float w = sin(u * 7.0 - scn_frame.time * 8.0);
        _geometry.position.z += w * 0.07 * u;
        _geometry.position.y += cos(u * 5.0 - scn_frame.time * 6.0) * 0.02 * u;
        _geometry.normal = normalize(_geometry.normal + float3(cos(u * 7.0 - scn_frame.time * 8.0) * 0.6 * u, 0.0, 0.0));
        """]
        let flag = SCNNode(geometry: fp); flag.position.x = -0.28; flagRoot.addChildNode(flag)
        flagRoot.eulerAngles.y = 0.5   // v7.5：旗面朝向镜头，避免侧看成一块方块
        let flap = SCNAction.sequence([.rotateTo(x: 0, y: 0.65, z: 0, duration: 1.4), .rotateTo(x: 0, y: 0.35, z: 0, duration: 1.4)]); flap.timingMode = .easeInEaseOut
        flagRoot.runAction(.repeatForever(flap)); ship.addChildNode(flagRoot)
        let lantern = SCNNode(geometry: SCNSphere(radius: 0.09)); lantern.name = "Lantern"
        lantern.geometry!.materials = [mat(UIColor(red: 1, green: 0.55, blue: 0.35, alpha: 1), emit: UIColor(red: 1, green: 0.62, blue: 0.42, alpha: 1))]
        lantern.position = SCNVector3(-1.8, 2.3, -1.05); ship.addChildNode(lantern)
        let wm = mat(UIColor(red: 0.25, green: 0.3, blue: 0.35, alpha: 1)); wm.roughness.contents = 0.08; wm.transparency = 0.0
        let win = SCNNode(geometry: SCNPlane(width: 0.9, height: 0.38)); win.name = "Windows"; win.geometry!.materials = [wm]
        win.position = SCNVector3(-1.72, 1.95, 0); win.eulerAngles.y = .pi / 2; ship.addChildNode(win)
        // 夜间才显示窗光：白天透明
        wm.diffuse.contents = UIColor.clear; wm.blendMode = .add
        return wm
    }

    private static func firstMaterial(_ n: SCNNode?) -> SCNMaterial? {
        var r: SCNMaterial?
        n?.enumerateHierarchy { c, stop in if let m = c.geometry?.firstMaterial { r = m; stop.pointee = true } }
        return r
    }
}

/// 解压反馈：水花 + 鱼跃出水面
enum SoftFX {
    static func splash(at p: SCNVector3, in parent: SCNNode, color: UIColor) {
        let ps = SCNParticleSystem()
        ps.birthRate = 260; ps.emissionDuration = 0.12; ps.loops = false
        ps.particleLifeSpan = 0.9; ps.particleLifeSpanVariation = 0.3
        ps.particleVelocity = 2.4; ps.particleVelocityVariation = 1.0
        ps.emittingDirection = SCNVector3(0, 1, 0); ps.spreadingAngle = 35
        ps.acceleration = SCNVector3(0, -6, 0)
        ps.particleSize = 0.07; ps.particleSizeVariation = 0.04
        ps.particleColor = color; ps.blendMode = .alpha
        ps.particleImage = Tex.dot(.white)
        ps.propertyControllers = [.opacity: SCNParticlePropertyController(animation: {
            let a = CAKeyframeAnimation(); a.values = [1, 0.9, 0]; a.keyTimes = [0, 0.6, 1]; return a }())]
        let n = SCNNode(); n.position = p
        n.addParticleSystem(ps)
        parent.addChildNode(n)
        n.runAction(.sequence([.wait(duration: 2), .removeFromParentNode()]))
    }

    static func fishPop(at p: SCNVector3, in parent: SCNNode, color: UIColor, fishID: String? = nil) {
        let fish = SCNNode()
        if let id = fishID, let m = FishModels.node(id) {
            m.scale = SCNVector3(0.32, 0.32, 0.32); fish.addChildNode(m)
        } else {
        let body = SCNSphere(radius: 0.18); body.segmentCount = 20
        let m = SCNMaterial(); m.lightingModel = .physicallyBased; m.diffuse.contents = color; m.roughness.contents = 0.35
        m.emission.contents = color.withAlphaComponent(0.25)
        body.materials = [m]
        let b = SCNNode(geometry: body); b.scale = SCNVector3(1.6, 0.9, 0.7); fish.addChildNode(b)
        let tail = SCNPyramid(width: 0.26, height: 0.24, length: 0.06); tail.materials = [m]
        let t = SCNNode(geometry: tail); t.eulerAngles.z = .pi / 2; t.position.x = -0.38; t.position.y = -0.12; fish.addChildNode(t)
        }
        fish.position = p; fish.scale = SCNVector3(0.01, 0.01, 0.01)
        parent.addChildNode(fish)
        let up = SCNAction.group([.moveBy(x: 0.6, y: 1.6, z: 0, duration: 0.45), .scale(to: 1, duration: 0.25), .rotateBy(x: 0, y: 0, z: 0.9, duration: 0.45)])
        up.timingMode = .easeOut
        let down = SCNAction.group([.moveBy(x: 0.6, y: -1.7, z: 0, duration: 0.45), .rotateBy(x: 0, y: 0, z: -1.8, duration: 0.45)])
        down.timingMode = .easeIn
        fish.runAction(.sequence([up, down, .run { n in
            DispatchQueue.main.async { splash(at: n.position, in: parent, color: UIColor(white: 1, alpha: 0.9)) }
        }, .scale(to: 0.01, duration: 0.1), .removeFromParentNode()]))
        splash(at: p, in: parent, color: UIColor(white: 1, alpha: 0.9))
    }
}
