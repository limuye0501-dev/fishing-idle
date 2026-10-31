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
                m.emission.contents = UIColor(red: 0.10, green: 0.07, blue: 0.06, alpha: 1)
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
        let breathe = SCNAction.sequence([.scale(to: 1.02, duration: 1.2), .scale(to: 1.0, duration: 1.2)])
        breathe.timingMode = .easeInEaseOut
        n.childNodes.first?.runAction(.repeatForever(breathe))
        return n
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
