import SceneKit
import UIKit

/// 主动捕鱼小游戏的 3D 表现（v7.2）：声呐盘旋转 + 水面声波环/光罩 + 水下发光鱼群；
/// 收网：吊杆绞索放下 3D 网兜 → 随收线进度拉起，网中 3D 鱼扭动、滴水、出水水花、镜头特写。
/// 由 MinigameModel 通过 NotificationCenter(.minigameStage) 驱动。
extension Notification.Name { static let minigameStage = Notification.Name("minigameStage") }

enum MinigameBus {
    /// stage: "sonar" | "cast" | "reel" | "result" | "end"；progress: 收网进度 0...1
    @MainActor static func post(_ stage: String, progress: Double = 0) {
        NotificationCenter.default.post(name: .minigameStage, object: nil, userInfo: ["stage": stage, "progress": progress])
    }
}

final class MinigameFX {
    private let root: SCNNode, ship: SCNNode, camera: SCNNode
    private let fxRoot = SCNNode()          // 世界坐标：声波环、鱼群
    private let shipFX = SCNNode()          // 船体坐标：声呐盘、网兜、绞索
    private var dish: SCNNode?
    private var net: SCNNode?
    private var cable = SCNNode()
    private var drip = SCNNode()
    private var netFish: [SCNNode] = []
    private var stage = "end"
    private var netY: Float = 3.0
    private var camSaved: (SCNVector3, SCNVector3)?
    private var obs: NSObjectProtocol?
    // 船体局部坐标（Blender +Y 网侧 = SceneKit -Z，朝向镜头）
    private let boomTip = SCNVector3(-0.6, 4.4, -1.9)
    private let haulXZ = (x: Float(-1.1), z: Float(-3.1))
    private let fishIDs = ["cod", "clown", "charr", "barramundi", "bluefin"]

    init(root: SCNNode, ship: SCNNode, camera: SCNNode) {
        self.root = root; self.ship = ship; self.camera = camera
        root.addChildNode(fxRoot); ship.addChildNode(shipFX)
        fxRoot.isHidden = true; shipFX.isHidden = true
        obs = NotificationCenter.default.addObserver(forName: .minigameStage, object: nil, queue: .main) { [weak self] n in
            let s = n.userInfo?["stage"] as? String ?? "end"
            let p = n.userInfo?["progress"] as? Double ?? 0
            self?.handle(s, Float(p))
        }
    }

    private func handle(_ s: String, _ p: Float) {
        if s == stage { if s == "reel" { shipFX.removeAction(forKey: "lower"); setNet(y: -1.6 + 4.4 * min(1, p)) }; return }
        stage = s
        switch s {
        case "sonar": startSonar()
        case "cast": stopSonar(); lowerNet()
        case "reel": closeUp(true)
        case "result": finishHaul()
        default: stopSonar(); cleanupNet(); closeUp(false)
        }
    }

    // MARK: 声呐
    private func startSonar() {
        fxRoot.isHidden = false; shipFX.isHidden = false
        fxRoot.childNodes.forEach { $0.removeFromParentNode() }
        let center = ship.convertPosition(SCNVector3(0, 0, 0), to: nil)
        fxRoot.position = SCNVector3(center.x, 0, center.z)
        // 船上声呐盘：碟形 + 支杆，快速旋转
        let d = SCNNode(); d.position = SCNVector3(-2.0, 2.95, -0.7)
        let dm = SCNMaterial(); dm.lightingModel = .physicallyBased; dm.diffuse.contents = UIColor(white: 0.93, alpha: 1); dm.metalness.contents = 0.3; dm.roughness.contents = 0.35
        let mast = SCNNode(geometry: SCNCylinder(radius: 0.035, height: 0.4)); mast.geometry!.materials = [dm]; mast.position.y = 0.2; d.addChildNode(mast)
        let cone = SCNCone(topRadius: 0.32, bottomRadius: 0.04, height: 0.16); cone.materials = [dm]
        let bowl = SCNNode(geometry: cone); bowl.position = SCNVector3(0, 0.45, 0); bowl.eulerAngles.x = -0.9
        let tip = SCNNode(geometry: SCNSphere(radius: 0.04)); let tm = SCNMaterial(); tm.emission.contents = UIColor(red: 0.4, green: 1, blue: 0.85, alpha: 1); tip.geometry!.materials = [tm]
        tip.position.y = 0.12; bowl.addChildNode(tip)
        d.addChildNode(bowl)
        d.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 1.4)), forKey: "spin")
        tip.runAction(.repeatForever(.sequence([.fadeOpacity(to: 0.3, duration: 0.35), .fadeOpacity(to: 1, duration: 0.35)])))
        shipFX.addChildNode(d); dish = d
        // 水面声波环 + 半透明声波穹顶，每 1.4 秒一次
        let ping = SCNAction.run { [weak self] _ in DispatchQueue.main.async { self?.emitPing() } }
        fxRoot.runAction(.repeatForever(.sequence([ping, .wait(duration: 1.4)])), forKey: "ping")
        // 水下鱼群（透过海面可见的暗色剪影，声波扫过时发光）
        for k in 0..<4 {
            // v7.5：鱼群限制在船前方镜头可见扇区内（不再出画）
            let a = 0.45 + Float(k) * 0.75, r: Float = 3.0 + Float(k % 2) * 1.1
            let school = SCNNode(); school.position = SCNVector3(cos(a) * r * 1.1, -0.35, sin(a) * r * 0.7 + 1.2)
            school.eulerAngles.y = -a + .pi / 2
            for j in 0..<5 {
                guard let f = FishModels.node(fishIDs[(k + j) % fishIDs.count]) else { continue }
                f.scale = SCNVector3(0.22, 0.22, 0.22)
                f.position = SCNVector3(Float(j % 3) * 0.55 - 0.5, Float(j % 2) * -0.12, Float(j / 3) * 0.5 - 0.2)
                f.enumerateHierarchy { n, _ in
                    n.renderingOrder = 50
                    for m in n.geometry?.materials ?? [] {
                        m.readsFromDepthBuffer = false; m.transparency = 0.55
                        m.multiply.contents = UIColor(red: 0.25, green: 0.45, blue: 0.5, alpha: 1)
                        m.emission.contents = UIColor(red: 0.3, green: 1, blue: 0.85, alpha: 1); m.emission.intensity = 0
                    }
                }
                school.addChildNode(f)
            }
            school.runAction(.repeatForever(.sequence([.rotateBy(x: 0, y: 0.5, z: 0, duration: 2), .rotateBy(x: 0, y: -0.5, z: 0, duration: 2)])))   // 原地摆动，不游出画面
            // 被声波扫到：发光脉冲（环扩散速度 ~6m/s）
            let delay = Double(r) / 6.5
            let glow = SCNAction.customAction(duration: 0.9) { n, t in
                let v = CGFloat(sin(Double(t) / 0.9 * .pi))
                n.enumerateHierarchy { c, _ in c.geometry?.materials.forEach { $0.emission.intensity = v * 1.4 } }
            }
            school.runAction(.repeatForever(.sequence([.wait(duration: delay), glow, .wait(duration: max(0.1, 1.4 - delay - 0.9))])))
            fxRoot.addChildNode(school)
        }
    }

    private func emitPing() {
        let ringM = SCNMaterial(); ringM.lightingModel = .constant; ringM.diffuse.contents = UIColor(red: 0.45, green: 1, blue: 0.9, alpha: 1)
        ringM.blendMode = .add; ringM.writesToDepthBuffer = false
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 1, pipeRadius: 0.025)); ring.geometry!.materials = [ringM]
        ring.position.y = 0.08; ring.renderingOrder = 40
        let domeM = SCNMaterial(); domeM.lightingModel = .constant; domeM.diffuse.contents = UIColor(red: 0.35, green: 0.95, blue: 0.85, alpha: 1)
        domeM.transparency = 0.14; domeM.blendMode = .add; domeM.writesToDepthBuffer = false; domeM.cullMode = .front
        let dome = SCNNode(geometry: SCNSphere(radius: 1)); dome.geometry!.materials = [domeM]; dome.scale = SCNVector3(1, 0.3, 1); dome.renderingOrder = 39
        for (n, s) in [(ring, 12.0), (dome, 9.0)] {
            fxRoot.addChildNode(n)
            let grow = SCNAction.customAction(duration: 2.2) { nn, t in
                let k = Float(t / 2.2), sc = 1 + Float(s) * k
                nn.scale = SCNVector3(sc, nn === dome ? sc * 0.3 : 1, sc); nn.opacity = CGFloat(1 - k)
            }
            n.runAction(.sequence([grow, .removeFromParentNode()]))
        }
    }

    private func stopSonar() {
        fxRoot.removeAction(forKey: "ping")
        fxRoot.runAction(.sequence([.fadeOut(duration: 0.6), .run { n in n.childNodes.forEach { $0.removeFromParentNode() }; n.opacity = 1 }]))
        dish?.runAction(.sequence([.fadeOut(duration: 0.5), .removeFromParentNode()])); dish = nil
    }

    // MARK: 收网
    private func buildNet() {
        cleanupNet()
        shipFX.isHidden = false
        let n = ModelAssets.load("NetBag") ?? SCNNode()
        n.scale = SCNVector3(1.1, 1.1, 1.1)
        // 网中扭动的 3D 鱼
        netFish = []
        for j in 0..<4 {
            guard let f = FishModels.node(fishIDs[j % fishIDs.count]) else { continue }
            f.scale = SCNVector3(0.2, 0.2, 0.2)
            f.position = SCNVector3(Float(j % 2) * 0.3 - 0.15, -0.75 + Float(j / 2) * 0.25, Float(j % 3) * 0.2 - 0.2)
            f.eulerAngles = SCNVector3(0, Float(j) * 1.3, 0.3)
            let w = SCNAction.sequence([.rotateBy(x: 0.3, y: 0, z: 0.5, duration: 0.18), .rotateBy(x: -0.3, y: 0, z: -0.5, duration: 0.18)])
            f.runAction(.repeatForever(.sequence([w, w, .wait(duration: 0.2, withRange: 0.4)])))
            n.addChildNode(f); netFish.append(f)
        }
        // 滴水
        let ps = SCNParticleSystem()
        ps.birthRate = 0; ps.particleLifeSpan = 0.8; ps.particleVelocity = 0.2; ps.emittingDirection = SCNVector3(0, -1, 0)
        ps.acceleration = SCNVector3(0, -9, 0); ps.particleSize = 0.035; ps.particleSizeVariation = 0.015
        ps.particleColor = UIColor(red: 0.85, green: 0.97, blue: 1, alpha: 0.85); ps.particleImage = Tex.dot(.white); ps.blendMode = .alpha
        ps.emitterShape = SCNSphere(radius: 0.55); ps.birthLocation = .surface
        drip = SCNNode(); drip.position.y = -0.6; drip.addParticleSystem(ps); n.addChildNode(drip)
        let cm = SCNMaterial(); cm.diffuse.contents = UIColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 1)
        cable = SCNNode(geometry: SCNCylinder(radius: 0.022, height: 1)); cable.geometry!.materials = [cm]
        shipFX.addChildNode(cable); shipFX.addChildNode(n); net = n
    }

    private func setNet(y: Float) {
        guard let n = net else { return }
        let prev = netY; netY = y
        n.position = SCNVector3(haulXZ.x, y, haulXZ.z)
        n.eulerAngles.z = 0.06 * sin(Float(CACurrentMediaTime()) * 2.2)
        // 绞索：吊杆顶端 → 网口
        let top = SCNVector3(haulXZ.x, y + 0.05, haulXZ.z)
        let dx = boomTip.x - top.x, dy = boomTip.y - top.y, dz = boomTip.z - top.z
        let len = sqrt(dx * dx + dy * dy + dz * dz)
        (cable.geometry as? SCNCylinder)?.height = CGFloat(len)
        cable.position = SCNVector3((boomTip.x + top.x) / 2, (boomTip.y + top.y) / 2, (boomTip.z + top.z) / 2)
        cable.look(at: ship.convertPosition(boomTip, to: nil), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
        // 出水：水花 + 滴水
        let water = ship.convertPosition(SCNVector3(haulXZ.x, 0, haulXZ.z), to: nil)
        if (prev < 0) != (y < 0) {
            SoftFX.splash(at: SCNVector3(water.x, 0.05, water.z), in: root, color: UIColor(white: 1, alpha: 0.95))
            SoftFX.splash(at: SCNVector3(water.x + 0.4, 0.05, water.z - 0.3), in: root, color: UIColor(white: 1, alpha: 0.9))
        }
        drip.particleSystems?.first?.birthRate = y > -0.2 ? 140 : 0
    }

    private func lowerNet() {
        buildNet(); setNet(y: 3.2)
        let a = SCNAction.customAction(duration: 1.6) { [weak self] _, t in
            let k = Float(t / 1.6)
            self?.setNet(y: 3.2 - 4.8 * k * k)
        }
        shipFX.runAction(a, forKey: "lower")
    }

    private func finishHaul() {
        setNet(y: 2.8)
        if let n = net {
            let w = n.convertPosition(SCNVector3(0, -0.3, 0), to: nil)
            SoftFX.fishPop(at: w, in: root, color: .white, fishID: fishIDs[0])
        }
        shipFX.runAction(.sequence([.wait(duration: 3.0), .run { [weak self] _ in
            DispatchQueue.main.async { self?.closeUp(false) } }]), forKey: "end")
    }

    private func cleanupNet() {
        shipFX.removeAction(forKey: "lower")
        net?.removeFromParentNode(); net = nil
        cable.removeFromParentNode(); netFish = []; netY = 3.0
    }

    // MARK: 镜头特写
    private func closeUp(_ on: Bool) {
        if on, net != nil {
            if camSaved == nil { camSaved = (camera.position, camera.eulerAngles) }
            let w = ship.convertPosition(SCNVector3(haulXZ.x, 1.2, haulXZ.z), to: nil)
            let target = SCNNode(); target.position = w; root.addChildNode(target); target.name = "mgTarget"
            let c = SCNLookAtConstraint(target: target); c.isGimbalLockEnabled = true; c.influenceFactor = 1
            SCNTransaction.begin(); SCNTransaction.animationDuration = 1.4
            camera.position = SCNVector3(w.x - 1.4, w.y + 1.9, w.z + 5.6)
            camera.constraints = [c]
            SCNTransaction.commit()
        } else if let s = camSaved {
            camSaved = nil
            camera.constraints = nil
            root.childNode(withName: "mgTarget", recursively: false)?.removeFromParentNode()
            SCNTransaction.begin(); SCNTransaction.animationDuration = 1.2
            camera.position = s.0; camera.eulerAngles = s.1
            SCNTransaction.commit()
            cleanupNet(); shipFX.isHidden = true
        }
    }
}
