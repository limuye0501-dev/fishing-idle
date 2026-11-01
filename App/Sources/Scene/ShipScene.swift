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
    private var usingModels = false
    private var lastCaught = -1
    private let rim = SCNNode()
    private let cloudRoot = SCNNode()
    private let glitterNode = SCNNode()
    private let sprayNode = SCNNode()
    private var palette = SkyPalette.make(part: .dusk, weather: .sunny, ocean: "coastal")
    private var lastSize: CGSize = .zero
    private let pitch: Float = -0.30
    private var minigameFX: MinigameFX?

    override init() {
        let plane = SCNPlane(width: 600, height: 600)
        seaNode = SCNNode(geometry: plane)
        let wake = SCNPlane(width: 5, height: 22)
        wakeNode = SCNNode(geometry: wake)
        super.init()
        buildCamera()
        buildLights()
        buildSea()
        // 优先使用 Blender 制作的 USDZ 模型；名字牌仍用 SCNText 贴在右舷
        let built = ShipModel.build(name: "云栖号")
        nameNode = built.nameNode
        if let m = ModelAssets.ship() {
            shipNode = m.node; windows = m.windows; usingModels = true
            m.radar?.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4)))
            let sway = SCNAction.sequence([.rotateBy(x: 0.05, y: 0, z: 0.04, duration: 1.7), .rotateBy(x: -0.05, y: 0, z: -0.04, duration: 1.7)])
            sway.timingMode = .easeInEaseOut
            m.net?.runAction(.repeatForever(sway))
            nameNode.removeFromParentNode()
            shipNode.addChildNode(nameNode)
            // v7.1：船名牌贴在镜头侧（Blender +Y = SceneKit -Z）船首外板
            nameNode.position = SCNVector3(2.1, 0.78, -1.47); nameNode.eulerAngles.y = .pi - 0.4
            nameNode.scale = SCNVector3(0.8, 0.8, 0.8)
            windows = ModelAssets.addProceduralParts(to: shipNode)
        } else {
            shipNode = built.ship; windows = built.windows
            built.radar.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4)))
        }
        shipRoot.addChildNode(shipNode)
        if usingModels { cameraNode.position = SCNVector3(-0.9, 4.9, 10.8) }   // v7.1b：船头朝左后整体左移，避免船头出画
        minigameFX = MinigameFX(root: scene.rootNode, ship: shipNode, camera: cameraNode)   // v7.2：小游戏 3D 声呐/收网
        // 小船长站在前甲板，面朝镜头偏右
        let captain = ModelAssets.captain() ?? CaptainModel.build()
        captain.position = usingModels ? SCNVector3(0.55, 0.59, -0.85) : SCNVector3(-0.3, ShipModel.deckY(-0.3), 1.45)   // v7：Meshy 船甲板高 0.59   // v5.5：驾驶室旁靠镜头一侧   // v5.4：船尾甲板，远离网兜   // v5.2：移到桅杆后方近镜头侧，避免被网兜遮挡
        captain.eulerAngles.y = usingModels ? 1.02 : 0.85 - .pi / 2   // v6.1：模型正面为 +X，世界朝向 +Z（镜头）   // v5.3b：模型正面朝 -Z，翻转使其面向镜头
        captain.scale = usingModels ? SCNVector3(1.75, 1.75, 1.75) : SCNVector3(1.6, 1.6, 1.6)   // v7：Meshy 船长高 1.4   // v6：更大更显眼
        shipNode.addChildNode(captain)
        // 夜间灯光
        let l = SCNLight(); l.type = .omni; l.color = UIColor(red: 1, green: 0.75, blue: 0.45, alpha: 1); l.intensity = 0
        l.attenuationStartDistance = 0.3; l.attenuationEndDistance = 4.5
        lanternLight.light = l; lanternLight.position = usingModels ? SCNVector3(-1.8, 2.4, -1.3) : SCNVector3(-0.5, 2.6, 1.6)
        shipNode.addChildNode(lanternLight)
        scene.rootNode.addChildNode(shipRoot)
        shipRoot.eulerAngles.y = usingModels ? -2.42 : -0.85   // v7.1：船头朝左、网侧朝镜头 // v5：船头朝向右前方（靠近镜头），三分之四视角
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
        // HDR 后期：柔光泛光、暗角、调色 LUT、轻微景深
        c.wantsHDR = true
        c.wantsExposureAdaptation = false
        c.exposureOffset = -0.12   // v7.4：船体不再过曝
        c.whitePoint = 1.0
        c.minimumExposure = -1; c.maximumExposure = 1
        c.contrast = 0.12   // v6：更柔和
        c.saturation = 1.12
        c.bloomIntensity = 0.35
        c.bloomThreshold = 0.95
        c.bloomBlurRadius = 20
        c.vignettingIntensity = 0.30
        c.vignettingPower = 0.9
        if let lut = UIImage(named: "GradeLUT.png") { c.colorGrading.contents = lut; c.colorGrading.intensity = 0.6 }
        c.wantsDepthOfField = true
        c.focusDistance = 10.0
        c.fStop = 4.5
        c.apertureBladeCount = 6
        c.focalBlurSampleCount = 6
        // 柔和环境光遮蔽，让模型更有体积感
        c.screenSpaceAmbientOcclusionIntensity = 0.6
        c.screenSpaceAmbientOcclusionRadius = 0.35
        c.screenSpaceAmbientOcclusionNormalThreshold = 0.3
        c.screenSpaceAmbientOcclusionDepthThreshold = 0.2
        cameraNode.camera = c
        cameraNode.position = SCNVector3(0.2, 4.7, 9.6)   // v5：更近的三分之四视角
        cameraNode.eulerAngles = SCNVector3(pitch, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
    }
    private func buildLights() {
        let s = SCNLight(); s.type = .directional; s.castsShadow = true; s.shadowMode = .deferred
        s.shadowColor = UIColor(red: 0.12, green: 0.10, blue: 0.22, alpha: 0.28); s.shadowRadius = 8; s.shadowSampleCount = 16
        s.orthographicScale = 12; s.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.light = s
        scene.rootNode.addChildNode(sun)
        let a = SCNLight(); a.type = .ambient; ambient.light = a
        scene.rootNode.addChildNode(ambient)
        // 暖色轮廓光（从船后上方打来）
        let r = SCNLight(); r.type = .directional; r.color = UIColor(red: 1, green: 0.78, blue: 0.62, alpha: 1); r.intensity = 450
        rim.light = r; rim.eulerAngles = SCNVector3(-0.5, .pi * 0.85, 0)
        scene.rootNode.addChildNode(rim)
    }
    private func buildSea() {
        SeaShader.apply(to: seaMat)
        let plane = SCNPlane(width: 600, height: 600); plane.widthSegmentCount = 1
        seaNode.geometry = plane
        seaNode.geometry?.materials = [seaMat]
        seaNode.eulerAngles.x = -.pi / 2
        seaNode.position.y = 0
        scene.rootNode.addChildNode(seaNode)
        // 波光粼粼
        let glitter = SCNParticleSystem()
        glitter.birthRate = 25; glitter.particleLifeSpan = 1.2; glitter.particleSize = 0.12; glitter.particleSizeVariation = 0.08
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
        wakeNode.isHidden = true   // v4：尾浪与船体泡沫由海面着色器绘制
        buildClouds()
        buildGlitter()
        buildSpray()
    }

    /// v5.3：柔和圆点贴图
    private static func softDot(_ n: Int = 64) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: n, height: n)).image { ctx in
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor(white: 1, alpha: 1).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray, locations: [0, 1])!
            let c = CGPoint(x: n / 2, y: n / 2)
            ctx.cgContext.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: CGFloat(n) / 2, options: [])
        }
    }

    /// v5.3：太阳金色波光带（加法混合的条带，贴在海面上，从镜头前方延伸到地平线）
    private func buildGlitter() {
        let W: CGFloat = 512, H: CGFloat = 2048
        var rng = SeededRNG(seed: 7)
        let img = UIGraphicsImageRenderer(size: CGSize(width: W, height: H)).image { ctx in
            let cg = ctx.cgContext
            for _ in 0..<1400 {
                let v = CGFloat.random(in: 0...1, using: &rng)          // 0 远 … 1 近
                let spread = 0.12 + 0.38 * v
                let u = 0.5 + CGFloat.random(in: -1...1, using: &rng) * CGFloat.random(in: 0...1, using: &rng) * spread
                let w = CGFloat.random(in: 6...26, using: &rng) * (0.4 + v), h = w * CGFloat.random(in: 0.18...0.32, using: &rng)
                let a = CGFloat.random(in: 0.35...1, using: &rng) * (1 - abs(u - 0.5) / max(spread, 0.01) * 0.8) * (0.55 + 0.45 * (1 - v))
                let c = CGPoint(x: u * W, y: v * H)
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor(red: 1, green: 0.88, blue: 0.6, alpha: max(a, 0)).cgColor, UIColor(red: 1, green: 0.7, blue: 0.4, alpha: 0).cgColor] as CFArray, locations: [0, 1])!
                cg.saveGState(); cg.translateBy(x: c.x, y: c.y); cg.scaleBy(x: 1, y: h / w)
                cg.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: w, options: [])
                cg.restoreGState()
            }
        }
        let pl = SCNPlane(width: 26, height: 150)
        let m = SCNMaterial(); m.lightingModel = .constant
        m.diffuse.contents = img; m.blendMode = .add; m.writesToDepthBuffer = false; m.isDoubleSided = true
        pl.materials = [m]
        glitterNode.geometry = pl
        // v5.3b：挂在相机下的屏幕锚定条带：从太阳下方地平线延伸到画面下部；不读深度，在海面之后、船之前绘制
        m.readsFromDepthBuffer = false
        glitterNode.renderingOrder = -1
        seaNode.renderingOrder = -2
        let D: Float = 40, halfW = tanf(24 * .pi / 180) * D, halfH = halfW / 0.46
        let top = (0.5 - 0.345) * 2 * halfH, bot = (0.5 - 0.78) * 2 * halfH
        pl.width = CGFloat(halfW * 0.75); pl.height = CGFloat(top - bot)
        glitterNode.position = SCNVector3(-0.36 * halfW, (top + bot) / 2, -D)
        let shimmer = SCNAction.repeatForever(.sequence([.fadeOpacity(to: 0.75, duration: 0.9), .fadeOpacity(to: 1.0, duration: 0.9)]))
        glitterNode.runAction(shimmer)
    }

    private func placeGlitter(sunDir: SCNVector3, visible: Bool) {
        glitterNode.isHidden = true   // v5.4：改为海面着色器绘制
    }

    /// v5.3：船首白色水花（柔和圆形粒子）
    private func buildSpray() {
        let ps = SCNParticleSystem()
        ps.particleImage = ShipScene.softDot()
        ps.birthRate = 620
        ps.particleLifeSpan = 0.8; ps.particleLifeSpanVariation = 0.25
        ps.particleSize = 0.24; ps.particleSizeVariation = 0.06
        ps.particleVelocity = 1.1; ps.particleVelocityVariation = 0.5
        ps.emittingDirection = SCNVector3(0, 1, 0); ps.spreadingAngle = 55
        ps.acceleration = SCNVector3(0, -4.5, 0)
        ps.particleColor = UIColor(white: 1, alpha: 0.9)
        ps.blendMode = .alpha
        ps.emitterShape = SCNBox(width: 3.2, height: 0.02, length: 2.6, chamferRadius: 0)   // v5.4：沿船首两舷连续水花
        ps.birthLocation = .surface
        ps.isAffectedByGravity = false
        let fade = SCNParticlePropertyController(animation: {
            let a = CAKeyframeAnimation(); a.values = [0.0, 1.0, 0.0]; a.keyTimes = [0, 0.2, 1]; return a }())
        ps.propertyControllers = [.opacity: fade]
        sprayNode.addParticleSystem(ps)
        sprayNode.position = SCNVector3(3.0, 0.08, 0)
        shipRoot.addChildNode(sprayNode)
    }

    /// 缓慢漂移的柔软云朵（手绘风贴图，带视差）
    private func buildClouds() {
        cloudRoot.name = "clouds"
        scene.rootNode.addChildNode(cloudRoot)
        let specs: [(Float, Float, Float, CGFloat, Int)] = [(-34, 22, -70, 26, 0), (8, 30, -82, 30, 1), (40, 19, -66, 22, 2),
                                                            (-10, 15, -58, 16, 3), (26, 34, -95, 34, 4), (-48, 31, -90, 28, 1)]
        for (x, y, z, w, k) in specs {
            guard let img = UIImage(named: "Cloud_\(k).png") else { continue }
            let pl = SCNPlane(width: w, height: w * img.size.height / img.size.width)
            let m = SCNMaterial(); m.lightingModel = .constant
            m.diffuse.contents = img; m.blendMode = .alpha; m.writesToDepthBuffer = false
            m.multiply.contents = UIColor.white
            pl.materials = [m]
            let n = SCNNode(geometry: pl); n.position = SCNVector3(x, y, z)
            n.constraints = [SCNBillboardConstraint()]
            n.renderingOrder = -10
            let speed = Double(0.35 + 0.15 * Float(k % 3))
            let span: Float = 120
            let dur = Double(span) / speed
            let start = Double((x + 60) / span) * dur
            n.runAction(.sequence([.moveBy(x: CGFloat(60 - x), y: 0, z: 0, duration: dur - start),
                                   .repeatForever(.sequence([.moveBy(x: -CGFloat(span), y: 0, z: 0, duration: 0), .moveBy(x: CGFloat(span), y: 0, z: 0, duration: dur)]))]))
            cloudRoot.addChildNode(n)
        }
    }
    private func buildGulls() {
        if usingModels, let g = Gulls.make(ship: shipNode, perch: SCNVector3(0.5, 5.32, 0.4)) {   // v7.3：Meshy 海鸥
            gulls.addChildNode(g); scene.rootNode.addChildNode(gulls); addFunnelSmoke(); return
        }
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
    /// v7.3：Meshy 船的烟囱烟（柔和、随风拉长、逐渐变大变淡）
    private func addFunnelSmoke() {
        let smoke = SCNParticleSystem()
        smoke.birthRate = 5; smoke.particleLifeSpan = 4.5; smoke.particleLifeSpanVariation = 1
        smoke.particleSize = 0.22; smoke.particleSizeVariation = 0.08
        smoke.particleImage = Tex.dot(UIColor(white: 1, alpha: 0.6), size: 64)
        smoke.particleColor = UIColor(white: 0.9, alpha: 0.35); smoke.particleColorVariation = SCNVector4(0, 0, 0.05, 0.1)
        smoke.emittingDirection = SCNVector3(0, 1, 0); smoke.spreadingAngle = 10
        smoke.particleVelocity = 0.6; smoke.acceleration = SCNVector3(-0.35, 0.08, 0)
        smoke.particleAngularVelocity = 20; smoke.particleAngularVelocityVariation = 40
        smoke.propertyControllers = [.size: SCNParticlePropertyController(animation: {
            let a = CAKeyframeAnimation(); a.values = [0.5, 1.8, 3.4]; a.keyTimes = [0, 0.4, 1]; return a }()),
            .opacity: SCNParticlePropertyController(animation: {
            let a = CAKeyframeAnimation(); a.values = [0, 0.8, 0.45, 0]; a.keyTimes = [0, 0.12, 0.5, 1]; return a }())]
        smoke.isLocal = false
        let n = SCNNode(); n.position = SCNVector3(-2.0, 4.15, -0.8); n.addParticleSystem(smoke)
        shipNode.addChildNode(n)
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
        if lastCaught >= 0, state.totalFishCaught > lastCaught, state.phase == .fishing || state.phase == .sailing {
            let colors = [UIColor(red: 1, green: 0.62, blue: 0.48, alpha: 1), UIColor(red: 0.98, green: 0.80, blue: 0.42, alpha: 1),
                          UIColor(red: 0.55, green: 0.80, blue: 0.86, alpha: 1)]
            let p = shipRoot.convertPosition(SCNVector3(3.9, 0, 2.1), to: scene.rootNode)
            SoftFX.fishPop(at: p, in: scene.rootNode, color: colors[state.totalFishCaught % colors.count], fishID: state.hold.last?.fishID)
        }
        lastCaught = state.totalFishCaught
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
        let ys = Float((p.sunX - 0.5) * 0.9), se: Float = night0 ? 0.35 : 0.12
        let sunDir = SCNVector3(sin(ys) * cos(se), sin(se), -cos(ys) * cos(se))
        let shallow = p.sea.mix(SkyPalette.rgb(0.30, 0.70, 0.70), night0 ? 0.0 : 0.75)
        let deep = p.sea.mix(SkyPalette.rgb(0.10, 0.45, 0.50), night0 ? 0.0 : 0.75)
        SeaShader.set(seaMat, shallow: shallow, deep: deep, sky: p.horizon.mix(p.mid, 0.3), foam: p.horizon.mix(.white, 0.97),
                      sunDir: sunDir, yaw: state.phase == .docked ? 0 : (usingModels ? -2.42 : -0.85), wake: state.phase == .sailing ? 1 : (state.phase == .fishing ? 0.75 : 0.5), night: night0 ? 0.6 : 0)
        seaMat.setValue(NSNumber(value: weather == .storm || weather == .rain || weather == .fog ? 0.3 : 1.0), forKey: "causticAmt")
        seaMat.setValue(NSNumber(value: night0 ? 0.6 : (weather == .storm || weather == .fog ? 0.2 : 1.0)), forKey: "sparkleAmt")
        for n in cloudRoot.childNodes { n.geometry?.firstMaterial?.multiply.contents = p.cloud.mix(.white, 0.35) }
        placeGlitter(sunDir: sunDir, visible: p.sunVisible && !night0 && weather != .storm && weather != .fog && weather != .rain)
        sprayNode.isHidden = state.phase != .sailing && state.phase != .fishing
        cloudRoot.isHidden = true   // v5：手绘天空贴图自带云层
        scene.fogColor = p.horizon
        scene.fogStartDistance = p.fogStart; scene.fogEndDistance = p.fogEnd; scene.fogDensityExponent = 1.3
        scene.lightingEnvironment.contents = p.environmentImage()
        scene.lightingEnvironment.intensity = part == .night ? 0.35 : 0.9
        let night = part == .night
        windows?.emission.contents = night ? ShipModel.rgb(0.75, 0.55, 0.30) : UIColor.black
        lanternLight.light?.intensity = night ? 220 : 0
        rim.light?.intensity = night ? 160 : (part == .dusk || part == .dawn ? 900 : 420)
        rainNode.isHidden = !(weather == .rain || weather == .storm)
        rainNode.particleSystems?.first?.birthRate = weather == .storm ? 1600 : 700
        gulls.isHidden = night || weather == .storm || weather == .rain
        let polar = state.oceanID == "arctic" || state.oceanID == "southern"
        iceNode.isHidden = !(polar || weather == .ice)
        scene.rootNode.childNode(withName: "glitter", recursively: false)?.isHidden = true   // v5：波光由海面着色器绘制
        let docked = state.phase == .docked
        portNode.isHidden = !docked
        wakeNode.isHidden = true
        shipRoot.eulerAngles.y = docked ? 0 : (usingModels ? -2.42 : -0.85)
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
        let img = palette.skyImage(size: CGSize(width: 1024, height: 1024 / CGFloat(aspect)), horizonAt: min(0.95, max(0.05, horizon)), seed: 3)
        scene.background.contents = img
    }
}
