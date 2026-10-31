import SceneKit
import UIKit

/// 程序建模：奶油色 + 青绿色的大拖网渔船（船头朝 +x，右舷 +z）
enum ShipModel {
    static let sternX: Float = -4.3
    static let bowX: Float = 4.7
    static let beam: Float = 1.65

    static func mat(_ c: UIColor, rough: CGFloat = 0.7, metal: CGFloat = 0, emission: UIColor? = nil) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = c
        m.roughness.contents = rough
        m.metalness.contents = metal
        if let e = emission { m.emission.contents = e }
        return m
    }
    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
    static let cream = rgb(0.98, 0.94, 0.84)
    static let teal = rgb(0.22, 0.60, 0.62)
    static let navy = rgb(0.14, 0.22, 0.38)
    static let wood = rgb(0.62, 0.42, 0.26)
    static let darkWood = rgb(0.45, 0.30, 0.19)
    static let brass = rgb(0.88, 0.70, 0.36)
    static let charcoal = rgb(0.22, 0.23, 0.26)
    static let coral = rgb(0.90, 0.40, 0.32)

    // MARK: 船形函数
    static func u(_ x: Float) -> Float { (x - sternX) / (bowX - sternX) }
    static func halfWidth(_ x: Float) -> Float {
        let t = u(x)
        if t < 0.55 { return beam * (0.86 + 0.14 * min(1, t / 0.25)) }
        let k = (t - 0.55) / 0.45
        return beam * sqrt(max(0, 1 - k * k)) * (1 - 0.05 * k)
    }
    static func top(_ x: Float) -> Float { let t = u(x); return 1.25 + 0.55 * pow(max(0, (t - 0.55) / 0.45), 2) + 0.12 * pow(max(0, (0.12 - t) / 0.12), 2) }
    static func bottom(_ x: Float) -> Float { let t = u(x); return -0.75 + 0.75 * pow(max(0, (t - 0.72) / 0.28), 2) + 0.25 * pow(max(0, (0.1 - t) / 0.1), 2) }
    static func deckY(_ x: Float) -> Float { 0.95 + 0.35 * pow(max(0, (u(x) - 0.6) / 0.4), 2) }

    /// 船体网格（两舷 + 尾板），uv.v 从舷边 0 到龙骨 1
    static func hullGeometry() -> SCNGeometry {
        let N = 48, M = 18
        var verts: [SCNVector3] = [], uvs: [CGPoint] = [], idx: [Int32] = []
        func section(_ x: Float, _ s: Float) -> (Float, Float) {
            let w = halfWidth(x), t = top(x), b = bottom(x)
            let y = t - (t - b) * s
            let k = max(0, (s - 0.38) / 0.62)
            let z = w * sqrt(max(0, 1 - k * k))
            return (y, z)
        }
        for side in [Float(1), -1] {
            let base = Int32(verts.count)
            for i in 0...N {
                let x = sternX + (bowX - sternX) * Float(i) / Float(N)
                for j in 0...M {
                    let s = Float(j) / Float(M)
                    let (y, z) = section(x, s)
                    verts.append(SCNVector3(x, y, z * side))
                    uvs.append(CGPoint(x: CGFloat(i) / CGFloat(N) * 6, y: CGFloat(s)))
                }
            }
            for i in 0..<N { for j in 0..<M {
                let a = base + Int32(i * (M + 1) + j), b = a + Int32(M + 1)
                if side > 0 { idx += [a, b, a + 1, a + 1, b, b + 1] } else { idx += [a, a + 1, b, a + 1, b + 1, b] }
            } }
        }
        // 尾板
        let tb = Int32(verts.count)
        verts.append(SCNVector3(sternX, (top(sternX) + bottom(sternX)) / 2, 0)); uvs.append(CGPoint(x: 0, y: 0.3))
        for j in 0...M {
            let (y, z) = section(sternX, Float(j) / Float(M))
            verts.append(SCNVector3(sternX, y, z)); uvs.append(CGPoint(x: 0, y: CGFloat(j) / CGFloat(M)))
        }
        for j in (0...M).reversed() {
            let (y, z) = section(sternX, Float(j) / Float(M))
            verts.append(SCNVector3(sternX, y, -z)); uvs.append(CGPoint(x: 0, y: CGFloat(j) / CGFloat(M)))
        }
        let ring = Int32(2 * (M + 1))
        for k in 0..<(ring - 1) { idx += [tb, tb + 2 + k, tb + 1 + k] }
        let normals = computeNormals(verts, idx)
        let g = SCNGeometry(sources: [SCNGeometrySource(vertices: verts), SCNGeometrySource(normals: normals), SCNGeometrySource(textureCoordinates: uvs)],
                            elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
        let m = mat(.white, rough: 0.55)
        m.diffuse.contents = Tex.hull
        m.diffuse.wrapS = .repeat
        m.isDoubleSided = true
        g.materials = [m]
        return g
    }

    static func computeNormals(_ v: [SCNVector3], _ idx: [Int32]) -> [SCNVector3] {
        var n = [SIMD3<Float>](repeating: .zero, count: v.count)
        for t in stride(from: 0, to: idx.count, by: 3) {
            let a = Int(idx[t]), b = Int(idx[t + 1]), c = Int(idx[t + 2])
            let pa = SIMD3<Float>(v[a].x, v[a].y, v[a].z), pb = SIMD3<Float>(v[b].x, v[b].y, v[b].z), pc = SIMD3<Float>(v[c].x, v[c].y, v[c].z)
            let f = simd_cross(pb - pa, pc - pa)
            n[a] += f; n[b] += f; n[c] += f
        }
        return n.map { let l = simd_length($0); let k = l > 0 ? $0 / l : SIMD3<Float>(0, 1, 0); return SCNVector3(k.x, k.y, k.z) }
    }

    /// 甲板（随船形收窄）
    static func deckGeometry() -> SCNGeometry {
        let N = 40
        var verts: [SCNVector3] = [], uvs: [CGPoint] = [], idx: [Int32] = []
        for i in 0...N {
            let x = sternX + 0.05 + (bowX - 0.25 - sternX) * Float(i) / Float(N)
            let w = halfWidth(x) * 0.93, y = deckY(x)
            verts.append(SCNVector3(x, y, -w)); verts.append(SCNVector3(x, y, w))
            uvs.append(CGPoint(x: CGFloat(x) / 2, y: CGFloat(-w) / 2)); uvs.append(CGPoint(x: CGFloat(x) / 2, y: CGFloat(w) / 2))
        }
        for i in 0..<N {
            let a = Int32(i * 2)
            idx += [a, a + 1, a + 2, a + 1, a + 3, a + 2]
        }
        let normals = computeNormals(verts, idx)
        let g = SCNGeometry(sources: [SCNGeometrySource(vertices: verts), SCNGeometrySource(normals: normals), SCNGeometrySource(textureCoordinates: uvs)],
                            elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
        let m = mat(.white, rough: 0.8)
        m.diffuse.contents = Tex.planks; m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
        m.isDoubleSided = true
        g.materials = [m]
        return g
    }

    static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ c: UIColor, chamfer: CGFloat = 0.04, rough: CGFloat = 0.7) -> SCNNode {
        let b = SCNBox(width: w, height: h, length: l, chamferRadius: chamfer); b.materials = [mat(c, rough: rough)]
        return SCNNode(geometry: b)
    }
    static func cyl(_ r: CGFloat, _ h: CGFloat, _ c: UIColor, rough: CGFloat = 0.6, metal: CGFloat = 0) -> SCNNode {
        let g = SCNCylinder(radius: r, height: h); g.materials = [mat(c, rough: rough, metal: metal)]
        return SCNNode(geometry: g)
    }
    static func sphere(_ r: CGFloat, _ c: UIColor, rough: CGFloat = 0.6) -> SCNNode {
        let g = SCNSphere(radius: r); g.segmentCount = 32; g.materials = [mat(c, rough: rough)]
        return SCNNode(geometry: g)
    }
    /// 两点之间的细杆/绳
    static func line(_ a: SCNVector3, _ b: SCNVector3, r: CGFloat, color: UIColor) -> SCNNode {
        let d = SIMD3<Float>(b.x - a.x, b.y - a.y, b.z - a.z)
        let len = simd_length(d)
        let n = cyl(r, CGFloat(len), color)
        n.simdPosition = SIMD3<Float>((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)
        let up = SIMD3<Float>(0, 1, 0), dir = d / max(len, 0.0001)
        let axis = simd_cross(up, dir)
        let angle = acos(max(-1, min(1, simd_dot(up, dir))))
        if simd_length(axis) > 1e-5 { n.simdOrientation = simd_quatf(angle: angle, axis: simd_normalize(axis)) }
        return n
    }

    /// 贴在右舷外板上的节点（自动对齐船体斜率）
    static func onStarboard(_ node: SCNNode, x: Float, y: Float, out: Float = 0.02) {
        let dx: Float = 0.05
        let slope = (halfWidth(x + dx) - halfWidth(x - dx)) / (2 * dx)
        node.position = SCNVector3(x, y, halfWidth(x) + out)
        node.eulerAngles.y = atan(slope)
    }

    // MARK: 整船
    static func build(name: String) -> (ship: SCNNode, nameNode: SCNNode, radar: SCNNode, windows: SCNMaterial, net: SCNNode) {
        let ship = SCNNode()
        ship.addChildNode(SCNNode(geometry: hullGeometry()))
        ship.addChildNode(SCNNode(geometry: deckGeometry()))

        // 舷墙扶手 + 立柱
        var prev: SCNVector3?
        for side in [Float(1), -1] {
            prev = nil
            for i in 0...22 {
                let x = sternX + 0.1 + (bowX - 0.35 - sternX) * Float(i) / 22
                let p = SCNVector3(x, top(x) + 0.32, side * halfWidth(x) * 0.97)
                if let q = prev { ship.addChildNode(line(q, p, r: 0.035, color: darkWood)) }
                let post = line(SCNVector3(x, top(x), side * halfWidth(x) * 0.97), p, r: 0.025, color: cream)
                ship.addChildNode(post)
                prev = p
            }
        }
        // 舷窗（黄铜圈 + 深色玻璃）
        let windowGlass = mat(rgb(0.16, 0.26, 0.36), rough: 0.15)
        for x in [-3.3, -2.5, -1.7, -0.9] as [Float] {
            let port = SCNNode()
            let ring = SCNTorus(ringRadius: 0.17, pipeRadius: 0.04); ring.materials = [mat(brass, rough: 0.3, metal: 0.8)]
            let rn = SCNNode(geometry: ring); rn.eulerAngles.x = .pi / 2; port.addChildNode(rn)
            let glass = SCNCylinder(radius: 0.15, height: 0.02); glass.materials = [windowGlass]
            let gn = SCNNode(geometry: glass); gn.eulerAngles.x = .pi / 2; port.addChildNode(gn)
            onStarboard(port, x: x, y: 0.72)
            ship.addChildNode(port)
        }
        // 锚徽（海军蓝圆牌 + 金锚）
        let emblem = SCNNode()
        let plate = cyl(0.36, 0.03, navy, rough: 0.4); plate.eulerAngles.x = .pi / 2; emblem.addChildNode(plate)
        let rim = SCNTorus(ringRadius: 0.36, pipeRadius: 0.03); rim.materials = [mat(brass, rough: 0.3, metal: 0.8)]
        let rimN = SCNNode(geometry: rim); rimN.eulerAngles.x = .pi / 2; emblem.addChildNode(rimN)
        let gold = brass
        let anchor = SCNNode(); anchor.position.z = 0.03
        anchor.addChildNode({ let n = cyl(0.025, 0.42, gold, rough: 0.3, metal: 0.8); n.position.y = 0.0; return n }())
        anchor.addChildNode({ let n = cyl(0.022, 0.26, gold, rough: 0.3, metal: 0.8); n.eulerAngles.z = .pi / 2; n.position.y = 0.12; return n }())
        anchor.addChildNode({ let t = SCNTorus(ringRadius: 0.05, pipeRadius: 0.018); t.materials = [mat(gold, rough: 0.3, metal: 0.8)]
                              let n = SCNNode(geometry: t); n.eulerAngles.x = .pi / 2; n.position.y = 0.25; return n }())
        let arc = SCNTube(innerRadius: 0.15, outerRadius: 0.19, height: 0.03); arc.materials = [mat(gold, rough: 0.3, metal: 0.8)]
        let arcN = SCNNode(geometry: arc); arcN.eulerAngles.x = .pi / 2; arcN.position.y = -0.08
        // 只露出下半圈
        let arcClip = SCNNode(); arcClip.addChildNode(arcN)
        anchor.addChildNode(arcClip)
        let cover = cyl(0.2, 0.031, navy, rough: 0.4); cover.eulerAngles.x = .pi / 2; cover.position = SCNVector3(0, 0.02, 0.0); cover.scale = SCNVector3(1, 1, 0.55)
        anchor.addChildNode(cover)
        anchor.addChildNode({ let n = cyl(0.025, 0.42, gold, rough: 0.3, metal: 0.8); n.position.z = 0.02; return n }())
        emblem.addChildNode(anchor)
        onStarboard(emblem, x: 3.0, y: 0.95, out: 0.03)
        ship.addChildNode(emblem)

        // 船名
        let nameNode = SCNNode()
        setName(nameNode, name)
        onStarboard(nameNode, x: 1.15, y: 0.62, out: 0.08)
        ship.addChildNode(nameNode)

        // 驾驶室
        let house = SCNNode(); house.position = SCNVector3(-1.6, deckY(-1.6), 0)
        let body = box(1.7, 1.45, 2.2, cream, chamfer: 0.08); body.position.y = 0.72; house.addChildNode(body)
        let roof = box(2.1, 0.14, 2.6, teal, chamfer: 0.06); roof.position.y = 1.52; house.addChildNode(roof)
        let trim = box(1.74, 0.1, 2.24, teal, chamfer: 0.02); trim.position.y = 0.08; house.addChildNode(trim)
        let windows = mat(rgb(0.20, 0.30, 0.42), rough: 0.12)
        for z in [-0.6, 0, 0.6] as [Float] {   // 前窗
            let f = box(0.04, 0.5, 0.5, .white, chamfer: 0.02); f.position = SCNVector3(0.86, 1.0, z); house.addChildNode(f)
            let w = SCNNode(geometry: SCNBox(width: 0.05, height: 0.4, length: 0.4, chamferRadius: 0.02)); w.geometry?.materials = [windows]
            w.position = SCNVector3(0.875, 1.0, z); house.addChildNode(w)
        }
        for x in [-0.4, 0.25] as [Float] {     // 侧窗
            let f = box(0.48, 0.48, 0.04, .white, chamfer: 0.02); f.position = SCNVector3(x, 1.0, 1.1); house.addChildNode(f)
            let w = SCNNode(geometry: SCNBox(width: 0.38, height: 0.38, length: 0.05, chamferRadius: 0.02)); w.geometry?.materials = [windows]
            w.position = SCNVector3(x, 1.0, 1.115); house.addChildNode(w)
        }
        let door = box(0.5, 0.95, 0.04, wood, chamfer: 0.03); door.position = SCNVector3(0.35, 0.5, 1.11); door.isHidden = true; house.addChildNode(door)
        // 救生圈
        let ringG = SCNTorus(ringRadius: 0.2, pipeRadius: 0.06)
        ringG.materials = [mat(coral, rough: 0.5)]
        let lr = SCNNode(geometry: ringG); lr.eulerAngles.x = .pi / 2; lr.position = SCNVector3(-0.45, 0.45, 1.14); house.addChildNode(lr)
        for k in 0..<4 {
            let band = box(0.08, 0.13, 0.13, .white, chamfer: 0.02)
            let a = Float(k) * .pi / 2 + .pi / 4
            band.position = SCNVector3(-0.45 + 0.2 * cos(a), 0.45 + 0.2 * sin(a), 1.14); band.eulerAngles.z = a
            house.addChildNode(band)
        }
        // 红灯笼
        let lantern = sphere(0.11, coral, rough: 0.4)
        lantern.geometry?.firstMaterial?.emission.contents = rgb(0.5, 0.15, 0.05)
        lantern.position = SCNVector3(0.9, 1.25, 1.15); lantern.scale = SCNVector3(1, 1.25, 1); house.addChildNode(lantern)
        // 顶部雷达与探照灯
        let mastTop = cyl(0.05, 0.6, cream); mastTop.position = SCNVector3(-0.3, 1.9, 0); house.addChildNode(mastTop)
        let radar = SCNNode(); radar.position = SCNVector3(-0.3, 2.22, 0)
        radar.addChildNode(box(0.1, 0.06, 0.9, .white, chamfer: 0.02))
        house.addChildNode(radar)
        let light = cyl(0.1, 0.16, brass, rough: 0.3, metal: 0.7); light.eulerAngles.z = .pi / 2; light.position = SCNVector3(0.6, 1.68, -0.6); house.addChildNode(light)
        // 顶层栏杆
        for z in [-1.2, 1.2] as [Float] { house.addChildNode(line(SCNVector3(-1.0, 1.85, z), SCNVector3(1.0, 1.85, z), r: 0.025, color: .white)) }
        house.addChildNode(line(SCNVector3(1.0, 1.85, -1.2), SCNVector3(1.0, 1.85, 1.2), r: 0.025, color: .white))
        for x in [-1.0, 0, 1.0] as [Float] { for z in [-1.2, 1.2] as [Float] { house.addChildNode(line(SCNVector3(x, 1.58, z), SCNVector3(x, 1.85, z), r: 0.02, color: .white)) } }
        ship.addChildNode(house)

        // 烟囱
        let funnel = SCNNode(); funnel.position = SCNVector3(-2.95, deckY(-2.95), -0.15)
        let fBody = cyl(0.3, 2.0, charcoal, rough: 0.5); fBody.position.y = 1.0; funnel.addChildNode(fBody)
        let fBand = cyl(0.31, 0.25, teal, rough: 0.5); fBand.position.y = 1.55; funnel.addChildNode(fBand)
        let fTop = cyl(0.33, 0.08, charcoal.mix(.black, 0.3), rough: 0.5); fTop.position.y = 2.02; funnel.addChildNode(fTop)
        funnel.eulerAngles.z = 0.12
        ship.addChildNode(funnel)
        let smoke = SCNParticleSystem()
        smoke.birthRate = 3; smoke.particleLifeSpan = 5; smoke.particleSize = 0.35; smoke.particleSizeVariation = 0.1
        smoke.particleImage = Tex.dot(UIColor(white: 1, alpha: 0.7), size: 64)
        smoke.particleColor = UIColor(white: 0.95, alpha: 0.55)
        smoke.emittingDirection = SCNVector3(-0.3, 1, 0); smoke.spreadingAngle = 12
        smoke.particleVelocity = 0.5; smoke.acceleration = SCNVector3(-0.15, 0.05, 0)
        smoke.propertyControllers = [.size: SCNParticlePropertyController(animation: {
            let a = CAKeyframeAnimation(); a.values = [0.3, 1.4]; return a }()),
                                     .opacity: SCNParticlePropertyController(animation: {
            let a = CAKeyframeAnimation(); a.values = [0.0, 0.6, 0.0]; return a }())]
        let smokeNode = SCNNode(); smokeNode.position = SCNVector3(-2.75, deckY(-2.95) + 2.1, -0.15); smokeNode.addParticleSystem(smoke)
        ship.addChildNode(smokeNode)

        // 主桅 + 吊杆 + 网
        let mastX: Float = 0.7
        let mastBase = SCNVector3(mastX, deckY(mastX), 0)
        let mastTopP = SCNVector3(mastX, deckY(mastX) + 4.6, 0)
        ship.addChildNode(line(mastBase, mastTopP, r: 0.08, color: cream))
        ship.addChildNode(line(SCNVector3(mastX, mastTopP.y - 1.0, -0.8), SCNVector3(mastX, mastTopP.y - 1.0, 0.8), r: 0.045, color: cream))
        let flag = SCNNode(geometry: { let p = SCNPlane(width: 0.5, height: 0.28); p.materials = [mat(teal, rough: 0.8)]; p.firstMaterial?.isDoubleSided = true; return p }())
        flag.position = SCNVector3(mastX - 0.26, mastTopP.y - 0.05, 0)
        flag.runAction(.repeatForever(.sequence([.rotateBy(x: 0, y: 0.25, z: 0, duration: 0.8), .rotateBy(x: 0, y: -0.25, z: 0, duration: 0.8)])))
        ship.addChildNode(flag)
        let lamp = sphere(0.08, rgb(1, 0.95, 0.8)); lamp.position = SCNVector3(mastX, mastTopP.y + 0.08, 0)
        lamp.geometry?.firstMaterial?.emission.contents = rgb(0.6, 0.5, 0.3); ship.addChildNode(lamp)
        // 右舷吊杆，伸向船外
        let boomBase = SCNVector3(mastX, deckY(mastX) + 1.0, 0.1)
        let boomTip = SCNVector3(mastX + 1.7, deckY(mastX) + 3.6, 3.0)
        ship.addChildNode(line(boomBase, boomTip, r: 0.06, color: cream.mix(wood, 0.3)))
        ship.addChildNode(line(mastTopP, boomTip, r: 0.012, color: darkWood))
        // 左舷吊杆（收起）
        ship.addChildNode(line(SCNVector3(mastX, deckY(mastX) + 1.0, -0.1), SCNVector3(mastX - 0.6, deckY(mastX) + 3.9, -1.6), r: 0.055, color: cream.mix(wood, 0.3)))
        // 挂着的网
        let net = SCNNode(); net.position = boomTip
        let rope = cyl(0.012, 0.6, darkWood); rope.position.y = -0.3; net.addChildNode(rope)
        let cone = SCNCone(topRadius: 0.15, bottomRadius: 0.75, height: 1.7)
        let nm = mat(.white, rough: 0.9); nm.diffuse.contents = Tex.net; nm.transparent.contents = Tex.net; nm.isDoubleSided = true
        nm.diffuse.contentsTransform = SCNMatrix4MakeScale(4, 2, 1); nm.diffuse.wrapS = .repeat; nm.diffuse.wrapT = .repeat
        nm.transparent.contentsTransform = SCNMatrix4MakeScale(4, 2, 1); nm.transparent.wrapS = .repeat; nm.transparent.wrapT = .repeat
        nm.blendMode = .alpha
        cone.materials = [nm]
        let coneN = SCNNode(geometry: cone); coneN.position.y = -1.45; net.addChildNode(coneN)
        let bag = sphere(0.72, .white); bag.geometry?.materials = [nm]; bag.scale = SCNVector3(1, 0.6, 1); bag.position.y = -2.25; net.addChildNode(bag)
        // 网里的鱼（若隐若现）
        for k in 0..<5 {
            let f = sphere(0.12, k % 2 == 0 ? rgb(0.75, 0.82, 0.88) : rgb(0.95, 0.62, 0.45), rough: 0.3)
            f.scale = SCNVector3(1.6, 0.7, 0.6); f.position = SCNVector3(Float(k % 3) * 0.2 - 0.2, -2.25 - Float(k / 3) * 0.15, Float(k % 2) * 0.2 - 0.1)
            net.addChildNode(f)
        }
        // 浮子
        for k in 0..<6 {
            let a = Float(k) / 6 * 2 * .pi
            let b = sphere(0.07, rgb(1, 0.6, 0.2), rough: 0.4); b.position = SCNVector3(0.75 * cos(a), -2.3, 0.75 * sin(a)); net.addChildNode(b)
        }
        net.runAction(.repeatForever(.sequence([.rotateBy(x: 0.06, y: 0, z: 0.05, duration: 1.6), .rotateBy(x: -0.06, y: 0, z: -0.05, duration: 1.6)])))
        ship.addChildNode(net)
        // 索具
        ship.addChildNode(line(mastTopP, SCNVector3(bowX - 0.3, top(bowX - 0.3) + 0.3, 0), r: 0.012, color: darkWood))
        ship.addChildNode(line(mastTopP, SCNVector3(-1.6, deckY(-1.6) + 1.6, 0), r: 0.012, color: darkWood))
        for side in [Float(1), -1] {
            ship.addChildNode(line(SCNVector3(mastX, mastTopP.y - 1.0, side * 0.8), SCNVector3(mastX - 0.2, top(mastX) + 0.3, side * halfWidth(mastX) * 0.95), r: 0.01, color: darkWood))
        }

        // 船尾绞车与卷起的绿网
        let winch = SCNNode(); winch.position = SCNVector3(-3.75, deckY(-3.75) + 0.35, 0)
        let drum = cyl(0.3, 1.8, rgb(0.35, 0.55, 0.42), rough: 0.9); drum.eulerAngles.x = .pi / 2; winch.addChildNode(drum)
        for z in [-0.95, 0.95] as [Float] { let s = cyl(0.36, 0.08, coral, rough: 0.5); s.eulerAngles.x = .pi / 2; s.position.z = z; winch.addChildNode(s) }
        ship.addChildNode(winch)
        // A 字架
        ship.addChildNode(line(SCNVector3(-4.1, deckY(-4.1), 1.2), SCNVector3(-4.25, deckY(-4.1) + 2.0, 0.6), r: 0.06, color: coral))
        ship.addChildNode(line(SCNVector3(-4.1, deckY(-4.1), -1.2), SCNVector3(-4.25, deckY(-4.1) + 2.0, -0.6), r: 0.06, color: coral))
        ship.addChildNode(line(SCNVector3(-4.25, deckY(-4.1) + 2.0, 0.6), SCNVector3(-4.25, deckY(-4.1) + 2.0, -0.6), r: 0.06, color: coral))

        // 甲板杂物：木箱、木桶、浮球、缆绳
        func crate(_ x: Float, _ z: Float, _ s: CGFloat, _ yaw: Float, stack: Int = 0) {
            let c = box(s, s, s, wood, chamfer: 0.02, rough: 0.85)
            c.position = SCNVector3(x, deckY(x) + Float(s) / 2 + Float(stack) * Float(s), z); c.eulerAngles.y = yaw
            for dy in [-0.32, 0.32] as [Float] {
                let slat = box(s * 1.02, s * 0.12, s * 1.02, darkWood, chamfer: 0.01); slat.position.y = Float(s) * dy; c.addChildNode(slat)
            }
            ship.addChildNode(c)
        }
        crate(1.35, 0.85, 0.42, 0.2); crate(1.4, 0.82, 0.36, -0.1, stack: 1); crate(1.6, -0.8, 0.36, 0.5); crate(-0.35, -0.9, 0.4, 0.1)
        func barrel(_ x: Float, _ z: Float) {
            let b = cyl(0.2, 0.5, wood, rough: 0.8); b.position = SCNVector3(x, deckY(x) + 0.25, z)
            for dy in [-0.15, 0.15] as [Float] { let h = cyl(0.205, 0.04, charcoal, rough: 0.4, metal: 0.5); h.position.y = dy; b.addChildNode(h) }
            ship.addChildNode(b)
        }
        barrel(0.15, 1.05); barrel(-0.25, 1.15); barrel(2.6, -0.6)
        for (x, z) in [(1.2, -1.2), (2.0, -1.0), (-0.6, 1.25)] as [(Float, Float)] {
            let b = sphere(0.14, rgb(1, 0.55, 0.2), rough: 0.4); b.position = SCNVector3(x, deckY(x) + 0.14, z); ship.addChildNode(b)
        }
        let coil = SCNTorus(ringRadius: 0.28, pipeRadius: 0.06); coil.materials = [mat(rgb(0.80, 0.68, 0.48), rough: 0.9)]
        let coilN = SCNNode(geometry: coil); coilN.position = SCNVector3(3.5, deckY(3.5) + 0.06, -0.3); ship.addChildNode(coilN)
        let coil2 = SCNNode(geometry: coil); coil2.position = SCNVector3(3.5, deckY(3.5) + 0.16, -0.3); coil2.scale = SCNVector3(0.8, 1, 0.8); ship.addChildNode(coil2)
        // 绳梯
        let lx: Float = 0.1, lz = halfWidth(0.1) + 0.06
        for dz in [-0.18, 0.18] as [Float] {
            ship.addChildNode(line(SCNVector3(lx + dz, top(lx) + 0.3, lz), SCNVector3(lx + dz, 0.0, lz + 0.05), r: 0.015, color: rgb(0.80, 0.68, 0.48)))
        }
        for k in 0..<6 {
            let y = top(lx) + 0.15 - Float(k) * 0.27
            ship.addChildNode(line(SCNVector3(lx - 0.18, y, lz + 0.01 * Float(k)), SCNVector3(lx + 0.18, y, lz + 0.01 * Float(k)), r: 0.022, color: wood))
        }
        // 船头锚链孔
        let hawse = SCNTorus(ringRadius: 0.09, pipeRadius: 0.03); hawse.materials = [mat(charcoal, rough: 0.4, metal: 0.6)]
        let hn = SCNNode(geometry: hawse); hn.eulerAngles.x = .pi / 2
        let hw = SCNNode(); hw.addChildNode(hn); onStarboard(hw, x: 3.9, y: 1.25); ship.addChildNode(hw)

        return (ship, nameNode, radar, windows, net)
    }

    static func setName(_ node: SCNNode, _ name: String) {
        node.childNodes.forEach { $0.removeFromParentNode() }
        let t = SCNText(string: name, extrusionDepth: 0.02)
        t.font = UIFont.systemFont(ofSize: 0.42, weight: .heavy)
        t.flatness = 0.005
        t.materials = [mat(navy, rough: 0.5)]
        let n = SCNNode(geometry: t)
        let (minB, maxB) = n.boundingBox
        let w = maxB.x - minB.x, h = maxB.y - minB.y
        let scale = min(1, 1.45 / max(w, 0.01))
        n.scale = SCNVector3(scale, scale, 1)
        n.position = SCNVector3(-(minB.x + w / 2) * scale, -(minB.y + h / 2) * scale, 0)
        node.addChildNode(n)
    }
}

/// Q 版小船长：大头大眼、白色船长帽+金徽、青蓝外套、深色裤子、棕靴
enum CaptainModel {
    static func build() -> SCNNode {
        let r = ShipModel.self
        let root = SCNNode()
        let skin = r.rgb(1.0, 0.85, 0.74)
        let coat = r.rgb(0.20, 0.52, 0.62)
        let trousers = r.rgb(0.16, 0.20, 0.30)
        let boots = r.rgb(0.48, 0.30, 0.18)
        let hair = r.rgb(0.40, 0.25, 0.15)
        // 靴子
        for z in [-0.09, 0.09] as [Float] {
            let b = r.sphere(0.08, boots, rough: 0.6); b.scale = SCNVector3(1.4, 0.8, 1); b.position = SCNVector3(0.03, 0.05, z); root.addChildNode(b)
            let leg = r.cyl(0.065, 0.22, trousers); leg.position = SCNVector3(0, 0.2, z); root.addChildNode(leg)
        }
        // 外套（下摆张开）
        let body = SCNCone(topRadius: 0.15, bottomRadius: 0.22, height: 0.36); body.materials = [r.mat(coat, rough: 0.75)]
        let bodyN = SCNNode(geometry: body); bodyN.position.y = 0.47; root.addChildNode(bodyN)
        let hem = r.cyl(0.225, 0.04, coat.mix(.black, 0.15)); hem.position.y = 0.3; root.addChildNode(hem)
        // 白领、金扣
        let collar = SCNTorus(ringRadius: 0.12, pipeRadius: 0.035); collar.materials = [r.mat(.white, rough: 0.6)]
        let cn = SCNNode(geometry: collar); cn.position.y = 0.66; root.addChildNode(cn)
        for k in 0..<3 {
            let b = r.sphere(0.022, r.brass, rough: 0.3); b.position = SCNVector3(0.17 - Float(k) * 0.012, 0.58 - Float(k) * 0.09, 0.0); root.addChildNode(b)
        }
        // 手臂（一只挥手）
        let armL = SCNNode(); armL.position = SCNVector3(0, 0.6, -0.17)
        let al = SCNCapsule(capRadius: 0.05, height: 0.28); al.materials = [r.mat(coat, rough: 0.75)]
        let aln = SCNNode(geometry: al); aln.position.y = -0.12; armL.addChildNode(aln)
        let hl = r.sphere(0.05, skin); hl.position.y = -0.27; armL.addChildNode(hl)
        armL.eulerAngles.x = 0.25; root.addChildNode(armL)
        let armR = SCNNode(); armR.name = "wave"; armR.position = SCNVector3(0, 0.6, 0.17)
        let ar = SCNNode(geometry: al.copy() as? SCNGeometry); ar.position.y = 0.12; armR.addChildNode(ar)
        let hr = r.sphere(0.05, skin); hr.position.y = 0.27; armR.addChildNode(hr)
        armR.eulerAngles.x = -0.5; root.addChildNode(armR)
        armR.runAction(.repeatForever(.sequence([.rotateTo(x: -0.9, y: 0, z: 0, duration: 0.35), .rotateTo(x: -0.4, y: 0, z: 0, duration: 0.35),
                                                 .rotateTo(x: -0.9, y: 0, z: 0, duration: 0.35), .rotateTo(x: -0.4, y: 0, z: 0, duration: 0.35),
                                                 .wait(duration: 2.5)])))
        // 大头
        let head = SCNNode(); head.name = "head"; head.position.y = 0.95
        let face = r.sphere(0.3, skin, rough: 0.7); face.scale = SCNVector3(1, 0.95, 1); head.addChildNode(face)
        let back = r.sphere(0.305, hair, rough: 0.8); back.position = SCNVector3(-0.04, 0.02, 0); back.scale = SCNVector3(0.95, 0.95, 1.02)
        head.addChildNode(back)
        // 刘海
        for (dz, dy) in [(-0.14, 0.12), (0.0, 0.15), (0.14, 0.12), (-0.22, 0.02), (0.22, 0.02)] as [(Float, Float)] {
            let b = r.sphere(0.09, hair, rough: 0.8); b.position = SCNVector3(0.22, dy, dz); b.scale = SCNVector3(0.6, 0.9, 1); head.addChildNode(b)
        }
        // 大眼睛（深棕 + 高光）
        for z in [-0.11, 0.11] as [Float] {
            let eye = r.sphere(0.06, r.rgb(0.20, 0.13, 0.10), rough: 0.2); eye.scale = SCNVector3(0.5, 1.25, 0.9)
            eye.position = SCNVector3(0.27, -0.02, z); head.addChildNode(eye)
            let hi = r.sphere(0.02, .white, rough: 0.1); hi.geometry?.firstMaterial?.emission.contents = UIColor(white: 0.6, alpha: 1)
            hi.position = SCNVector3(0.3, 0.02, z + 0.02); head.addChildNode(hi)
            let cheek = r.sphere(0.05, r.rgb(1.0, 0.62, 0.62), rough: 0.9); cheek.scale = SCNVector3(0.4, 0.6, 1)
            cheek.position = SCNVector3(0.255, -0.11, z * 1.6); head.addChildNode(cheek)
        }
        let mouth = SCNTorus(ringRadius: 0.03, pipeRadius: 0.008); mouth.materials = [r.mat(r.rgb(0.55, 0.25, 0.2))]
        let mn = SCNNode(geometry: mouth); mn.eulerAngles.z = .pi / 2; mn.position = SCNVector3(0.29, -0.14, 0); mn.scale = SCNVector3(1, 1, 0.6); head.addChildNode(mn)
        // 船长帽：白色帽顶 + 海军蓝帽带 + 黑帽檐 + 金徽
        let cap = SCNNode(); cap.position.y = 0.22; cap.eulerAngles.z = -0.08
        let crown = SCNCone(topRadius: 0.36, bottomRadius: 0.29, height: 0.16); crown.materials = [r.mat(.white, rough: 0.5)]
        let crN = SCNNode(geometry: crown); crN.position.y = 0.1; cap.addChildNode(crN)
        let topDisc = r.cyl(0.36, 0.04, .white, rough: 0.5); topDisc.position.y = 0.19; cap.addChildNode(topDisc)
        let band = r.cyl(0.295, 0.08, r.navy, rough: 0.6); band.position.y = 0.03; cap.addChildNode(band)
        let visor = r.sphere(0.2, r.rgb(0.10, 0.10, 0.14), rough: 0.25); visor.scale = SCNVector3(0.85, 0.12, 1.15); visor.position = SCNVector3(0.2, -0.01, 0)
        cap.addChildNode(visor)
        let badge = r.cyl(0.055, 0.02, r.brass, rough: 0.25, metal: 0.9); badge.eulerAngles.z = .pi / 2; badge.position = SCNVector3(0.3, 0.07, 0)
        cap.addChildNode(badge)
        let badgeIn = r.sphere(0.025, r.rgb(1, 0.85, 0.4), rough: 0.2); badgeIn.position = SCNVector3(0.31, 0.07, 0); cap.addChildNode(badgeIn)
        head.addChildNode(cap)
        root.addChildNode(head)
        head.runAction(.repeatForever(.sequence([.rotateTo(x: 0.08, y: 0, z: 0.03, duration: 1.8), .rotateTo(x: -0.06, y: 0, z: -0.02, duration: 1.8)])))
        root.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 0.03, z: 0, duration: 0.6), .moveBy(x: 0, y: -0.03, z: 0, duration: 0.6)])))
        return root
    }
}
