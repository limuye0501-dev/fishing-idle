import SceneKit
import UIKit
import FishingCore

/// 主场景：一艘渔船、小船长、海、天空和天气
final class ShipScene: NSObject {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    weak var view: SCNView? { didSet { refreshSky(force: true) } }

    private let shipRoot = SCNNode()
    private var shipNode = SCNNode()
    private var nameNode = SCNNode()
    private var windows: SCNMaterial?
    private let sun = SCNNode()
    private let ambient = SCNNode()
    private let seaNode: SCNNode
    private let seaMat = SCNMaterial()
    private let wakeNode: SCNNode
    private let rainNode = SCNNode()
    private let gulls = SCNNode()
    private let iceNode = SCNNode()
    private let portNode = SCNNode()
    private let lanternLight = SCNNode()
    private var lastKey = ""
    private var lastName = ""
    private var palette = SkyPalette.make(part: .dusk, weather: .sunny, ocean: "coastal")
    private var lastSize: CGSize = .zero
    private let pitch: Float = -0.30

    override init() {
        let plane = SCNPlane(width: 600, height: 600)
        seaNode = SCNNode(geometry: plane)
        let wake = SCNPlane(width: 5, height: 22)
        wakeNode = SCNNode(geometry: wake)
        super.init()
        buildCamera()
        buildLights()
        buildSea()
        let built = ShipModel.build(name: "云栖号")
        shipNode = built.ship; nameNode = built.nameNode; windows = built.windows
        built.radar.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4)))
        shipRoot.addChildNode(shipNode)
        // 小船长站在前甲板，面朝镜头偏右
        let captain = CaptainModel.build()
        captain.position = SCNVector3(2.3, ShipModel.deckY(2.3), 0.35)
        captain.eulerAngles.y = -1.15
        captain.scale = SCNVector3(1.2, 1.2, 1.2)
        shipNode.addChildNode(captain)
        // 夜间灯光
        let l = SCNLight(); l.type = .omni; l.color = UIColor(red: 1, green: 0.75, blue: 0.45, alpha: 1); l.intensity = 0
        l.attenuationStartDistance = 0.3; l.attenuationEndDistance = 4.5
        lanternLight.light = l; lanternLight.position = SCNVector3(-0.5, 2.6, 1.6)
        shipNode.addChildNode(lanternLight)
        scene.rootNode.addChildNode(shipRoot)
        shipRoot.eulerAngles.y = 0.42   // 船头偏向右前方，露出右舷
        buildWake()
        buildGulls()
        buildRain()
        buildIce()
        buildPort()
        startMotion(amp: 1)
    }

    // MARK: 构建
    private func buildCamera() {
        let c = SCNCamera()
        c.fieldOfView = 48
        c.projectionDirection = .horizontal
        c.zNear = 0.1; c.zFar = 700
        c.wantsHDR = false
        cameraNode.camera = c
        cameraNode.position = SCNVector3(0.4, 5.6, 12.2)
        cameraNode.eulerAngles = SCNVector3(pitch, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
    }
    private func buildLights() {
        let s = SCNLight(); s.type = .directional; s.castsShadow = true; s.shadowMode = .deferred
        s.shadowColor = UIColor(white: 0, alpha: 0.35); s.shadowRadius = 4; s.shadowSampleCount = 8
        s.orthographicScale = 12; s.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.light = s
        scene.rootNode.addChildNode(sun)
        let a = SCNLight(); a.type = .ambient; ambient.light = a
        scene.rootNode.addChildNode(ambient)
    }
    private func buildSea() {
        seaMat.lightingModel = .physicallyBased
        seaMat.metalness.contents = 0.0
        seaMat.roughness.contents = 0.12
        seaMat.normal.contents = Tex.waterNormal
        seaMat.normal.intensity = 0.6
        seaMat.normal.wrapS = .repeat; seaMat.normal.wrapT = .repeat
        seaMat.normal.contentsTransform = SCNMatrix4MakeScale(60, 60, 1)
        seaMat.fresnelExponent = 2
        seaNode.geometry?.materials = [seaMat]
        seaNode.eulerAngles.x = -.pi / 2
        seaNode.position.y = 0
        scene.rootNode.addChildNode(seaNode)
        // 海面法线流动
        let anim = CABasicAnimation(keyPath: "geometry.firstMaterial.normal.contentsTransform")
        anim.fromValue = NSValue(scnMatrix4: SCNMatrix4MakeScale(60, 60, 1))
        anim.toValue = NSValue(scnMatrix4: SCNMatrix4Mult(SCNMatrix4MakeScale(60, 60, 1), SCNMatrix4MakeTranslation(1, 0.5, 0)))
        anim.duration = 40; anim.repeatCount = .infinity
        seaNode.addAnimation(anim, forKey: "flow")
        // 波光粼粼
        let glitter = SCNParticleSystem()
        glitter.birthRate = 60; glitter.particleLifeSpan = 1.2; glitter.particleSize = 0.12; glitter.particleSizeVariation = 0.08
        glitter.particleImage = Tex.dot(.white, size: 32)
        glitter.particleColor = UIColor(red: 1, green: 0.97, blue: 0.85, alpha: 0.9)
        glitter.emitterShape = SCNBox(width: 70, height: 0.01, length: 50, chamferRadius: 0)
        glitter.birthLocation = .surface; glitter.particleVelocity = 0
        glitter.blendMode = .additive
        glitter.propertyControllers = [.opacity: SCNParticlePropertyController(animation: { let a = CAKeyframeAnimation(); a.values = [0, 1, 0]; return a }())]
        let gn = SCNNode(); gn.position = SCNVector3(4, 0.05, -28); gn.addParticleSystem(glitter); gn.name = "glitter"
        scene.rootNode.addChildNode(gn)
    }
    private func buildWake() {
        let m = SCNMaterial(); m.lightingModel = .constant
        m.diffuse.contents = Tex.wake; m.transparent.contents = Tex.wake; m.blendMode = .alpha; m.writesToDepthBuffer = false
        m.diffuse.wrapT = .repeat; m.transparent.wrapT = .repeat
        wakeNode.geometry?.materials = [m]
        wakeNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, Float.pi / 2)
        wakeNode.position = SCNVector3(ShipModel.sternX - 10.5, 0.03, 0)
        let a = CABasicAnimation(keyPath: "geometry.firstMaterial.transparent.contentsTransform")
        a.fromValue = NSValue(scnMatrix4: SCNMatrix4Identity); a.toValue = NSValue(scnMatrix4: SCNMatrix4MakeTranslation(0, 1, 0))
        a.duration = 6; a.repeatCount = .infinity
        wakeNode.addAnimation(a, forKey: "wake")
        shipRoot.addChildNode(wakeNode)
        // 船体四周的白色泡沫
        let ring = SCNPlane(width: 12.5, height: 5.2)
        let rm = SCNMaterial(); rm.lightingModel = .constant; rm.diffuse.contents = Tex.foamRing; rm.transparent.contents = Tex.foamRing
        rm.blendMode = .alpha; rm.writesToDepthBuffer = false
        ring.materials = [rm]
        let rn = SCNNode(geometry: ring); rn.eulerAngles.x = -.pi / 2; rn.position = SCNVector3(0.2, 0.04, 0)
        rn.runAction(.repeatForever(.sequence([.scale(to: 1.04, duration: 1.5), .scale(to: 0.98, duration: 1.5)])))
        shipRoot.addChildNode(rn)
    }
    private func buildGulls() {
        for k in 0..<3 {
            let g = SCNNode()
            let wingM = ShipModel.mat(.white, rough: 0.8)
            for side in [Float(1), -1] {
                let w = SCNNode(geometry: { let b = SCNBox(width: 0.25, height: 0.02, length: 0.7, chamferRadius: 0.01); b.materials = [wingM]; return b }())
                w.pivot = SCNMatrix4MakeTranslation(0, 0, -side * 0.35)
                w.runAction(.repeatForever(.sequence([.rotateTo(x: CGFloat(side * 0.5), y: 0, z: 0, duration: 0.3), .rotateTo(x: CGFloat(-side * 0.3), y: 0, z: 0, duration: 0.3)])))
                g.addChildNode(w)
            }
            let body = ShipModel.sphere(0.1, .white); body.scale = SCNVector3(2.2, 1, 1); g.addChildNode(body)
            let orbit = SCNNode(); orbit.position = SCNVector3(Float(k) * 1.5 - 1, 6.5 + Float(k) * 0.8, -2)
            g.position = SCNVector3(4 + Float(k), 0, 0); g.eulerAngles.y = -.pi / 2
            orbit.addChildNode(g)
            orbit.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 14 + Double(k) * 3)))
            gulls.addChildNode(orbit)
        }
        scene.rootNode.addChildNode(gulls)
    }
    private func buildRain() {
        let r = SCNParticleSystem()
        r.birthRate = 900; r.particleLifeSpan = 1.4; r.particleSize = 0.05
        r.particleImage = Tex.streak; r.particleColor = UIColor(white: 1, alpha: 0.55)
        r.emitterShape = SCNBox(width: 40, height: 0.1, length: 30, chamferRadius: 0)
        r.birthLocation = .surface; r.emittingDirection = SCNVector3(0.2, -1, 0); r.particleVelocity = 16
        r.stretchFactor = 0.08
        rainNode.position = SCNVector3(0, 16, 0); rainNode.addParticleSystem(r); rainNode.isHidden = true
        scene.rootNode.addChildNode(rainNode)
    }
    private func buildIce() {
        var rng = SeededRNG(seed: 7)
        let m = ShipModel.mat(UIColor(red: 0.95, green: 0.98, blue: 1, alpha: 1), rough: 0.4)
        for _ in 0..<26 {
            let r = CGFloat.random(in: 0.6...2.4, using: &rng)
            let c = SCNCylinder(radius: r, height: 0.35); c.radialSegmentCount = Int.random(in: 5...8, using: &rng); c.materials = [m]
            let n = SCNNode(geometry: c)
            var x = Float.random(in: -30...30, using: &rng), z = Float.random(in: -45...6, using: &rng)
            if abs(x) < 7 && z > -6 { x += 12 }
            if z > 4 { z -= 6 }
            n.position = SCNVector3(x, 0.08, z); n.eulerAngles.y = Float.random(in: 0...6, using: &rng)
            n.scale = SCNVector3(1, 1, Float.random(in: 0.6...1, using: &rng))
            iceNode.addChildNode(n)
        }
        // 远处冰山
        for (x, z, s) in [(-22, -60, 5.0), (26, -70, 7.0), (14, -50, 3.5)] as [(Float, Float, CGFloat)] {
            let p = SCNPyramid(width: s * 2, height: s * 1.4, length: s * 1.6); p.materials = [m]
            let n = SCNNode(geometry: p); n.position = SCNVector3(x, -0.2, z); iceNode.addChildNode(n)
        }
        iceNode.isHidden = true
        scene.rootNode.addChildNode(iceNode)
    }
    private func buildPort() {
        let wood = ShipModel.wood
        let pier = ShipModel.box(16, 0.25, 3.2, wood, chamfer: 0.03); pier.position = SCNVector3(0, 0.9, -4.6)
        let pm = pier.geometry!.firstMaterial!; pm.diffuse.contents = Tex.planks; pm.diffuse.contentsTransform = SCNMatrix4MakeScale(4, 1, 1)
        pm.diffuse.wrapS = .repeat; pm.diffuse.wrapT = .repeat
        portNode.addChildNode(pier)
        for x in stride(from: -7.5, through: 7.5, by: 2.5) {
            for z in [-3.1, -6.1] {
                let p = ShipModel.cyl(0.14, 2.0, ShipModel.darkWood); p.position = SCNVector3(Float(x), 0.1, Float(z)); portNode.addChildNode(p)
            }
        }
        let colors = [ShipModel.rgb(0.98, 0.80, 0.70), ShipModel.rgb(0.80, 0.90, 0.88), ShipModel.rgb(1.0, 0.92, 0.72), ShipModel.rgb(0.88, 0.82, 0.95)]
        for k in 0..<6 {
            let h = SCNNode(); h.position = SCNVector3(Float(k) * 3.4 - 9, 0.9, -10 - Float(k % 2) * 1.5)
            let b = ShipModel.box(2.6, 2.2 + CGFloat(k % 3) * 0.5, 2.4, colors[k % 4], chamfer: 0.05); b.position.y = Float(b.boundingBox.max.y); h.addChildNode(b)
            let roof = SCNPyramid(width: 3.0, height: 1.2, length: 2.8); roof.materials = [ShipModel.mat(k % 2 == 0 ? ShipModel.teal : ShipModel.coral)]
            let rn = SCNNode(geometry: roof); rn.position.y = Float(b.boundingBox.max.y) * 2; h.addChildNode(rn)
            let ground = ShipModel.box(3.2, 0.9, 3.2, ShipModel.rgb(0.85, 0.80, 0.70)); ground.position.y = -0.45; h.addChildNode(ground)
            portNode.addChildNode(h)
        }
        let lh = SCNNode(); lh.position = SCNVector3(12, 0, -9)
        let tower = SCNCone(topRadius: 0.7, bottomRadius: 1.1, height: 6.5); tower.materials = [ShipModel.mat(.white)]
        let tn = SCNNode(geometry: tower); tn.position.y = 3.25; lh.addChildNode(tn)
        for y in [1.5, 3.8] as [Float] { let s = ShipModel.cyl(0.98 - CGFloat(y) * 0.06, 0.7, ShipModel.coral); s.position.y = y; lh.addChildNode(s) }
        let lamp = ShipModel.cyl(0.6, 0.8, ShipModel.rgb(1, 0.92, 0.6)); lamp.position.y = 6.9
        lamp.geometry?.firstMaterial?.emission.contents = ShipModel.rgb(0.9, 0.75, 0.3); lh.addChildNode(lamp)
        let cap = SCNCone(topRadius: 0, bottomRadius: 0.8, height: 0.7); cap.materials = [ShipModel.mat(ShipModel.coral)]
        let cn = SCNNode(geometry: cap); cn.position.y = 7.65; lh.addChildNode(cn)
        portNode.addChildNode(lh)
        portNode.isHidden = true
        scene.rootNode.addChildNode(portNode)
    }

    private func startMotion(amp: Float) {
        shipNode.removeAction(forKey: "bob")
        let a = CGFloat(amp)
        let bob = SCNAction.repeatForever(.sequence([
            .group([.moveBy(x: 0, y: 0.08 * a, z: 0, duration: 1.9), .rotateBy(x: 0.025 * a, y: 0, z: 0.012 * a, duration: 1.9)]),
            .group([.moveBy(x: 0, y: -0.08 * a, z: 0, duration: 1.9), .rotateBy(x: -0.025 * a, y: 0, z: -0.012 * a, duration: 1.9)])]))
        bob.timingMode = .easeInEaseOut
        shipNode.runAction(bob, forKey: "bob")
    }

    // MARK: 同步
    func sync(state: VoyageState, now: Date) {
        if state.shipName != lastName { lastName = state.shipName; ShipModel.setName(nameNode, state.shipName) }
        let part = state.dayPart(now)
        let weather = state.weather(at: now)
        let key = "\(part)-\(weather)-\(state.oceanID)-\(state.phase.rawValue)"
        if key != lastKey {
            lastKey = key
            palette = SkyPalette.make(part: part, weather: weather, ocean: state.oceanID)
            apply(part: part, weather: weather, state: state)
            refreshSky(force: true)
        } else {
            refreshSky(force: false)
        }
    }

    private func apply(part: DayPart, weather: Weather, state: VoyageState) {
        let p = palette
        let night0 = part == .night
        sun.light?.color = p.lightColor; sun.light?.intensity = p.lightIntensity
        sun.eulerAngles = SCNVector3(-p.lightElevation, Float((0.5 - p.sunX) * 1.2), 0)
        ambient.light?.color = p.ambient; ambient.light?.intensity = p.ambientIntensity
        seaMat.diffuse.contents = p.sea
        seaMat.emission.contents = p.sea.mix(.black, night0 ? 0.75 : 0.45)
        scene.fogColor = p.horizon
        scene.fogStartDistance = p.fogStart; scene.fogEndDistance = p.fogEnd; scene.fogDensityExponent = 1.3
        scene.lightingEnvironment.contents = p.environmentImage()
        scene.lightingEnvironment.intensity = part == .night ? 0.35 : 0.9
        let night = part == .night
        windows?.emission.contents = night ? ShipModel.rgb(0.75, 0.55, 0.30) : UIColor.black
        lanternLight.light?.intensity = night ? 220 : 0
        rainNode.isHidden = !(weather == .rain || weather == .storm)
        rainNode.particleSystems?.first?.birthRate = weather == .storm ? 1600 : 700
        gulls.isHidden = night || weather == .storm || weather == .rain
        let polar = state.oceanID == "arctic" || state.oceanID == "southern"
        iceNode.isHidden = !(polar || weather == .ice)
        scene.rootNode.childNode(withName: "glitter", recursively: false)?.isHidden = night || weather == .rain || weather == .storm || weather == .fog
        let docked = state.phase == .docked
        portNode.isHidden = !docked
        wakeNode.isHidden = state.phase != .sailing
        shipRoot.eulerAngles.y = docked ? 0 : 0.42
        startMotion(amp: weather == .storm ? 3.2 : (weather == .rain || weather == .breeze ? 1.6 : 1))
        scene.rootNode.removeAction(forKey: "lightning")
        if weather == .storm {
            let flash = SCNAction.sequence([.wait(duration: 4, withRange: 4), .run { [weak self] _ in
                guard let s = self else { return }
                DispatchQueue.main.async {
                    s.ambient.light?.intensity = 4000
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { s.ambient.light?.intensity = s.palette.ambientIntensity }
                }
            }])
            scene.rootNode.runAction(.repeatForever(flash), forKey: "lightning")
        }
    }

    private func refreshSky(force: Bool) {
        guard let v = view else { return }
        let size = v.bounds.size
        guard size.width > 10, size.height > 10 else { return }
        if !force && size == lastSize { return }
        lastSize = size
        // 地平线在画面中的位置
        let aspect = Float(size.width / size.height)
        let hHalf = tan(Float(48.0 / 2 * .pi / 180))
        let vHalf = hHalf / aspect
        let horizon = CGFloat(0.5 - 0.5 * tan(-pitch) / vHalf)
        let img = palette.skyImage(size: CGSize(width: 512, height: 512 / CGFloat(aspect)), horizonAt: min(0.95, max(0.05, horizon)), seed: 3)
        scene.background.contents = img
    }
}
