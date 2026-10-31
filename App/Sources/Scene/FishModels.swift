import SceneKit
import SwiftUI
import UIKit

/// Blender 参数化生成的 39 种 Q 版鱼（USDZ，头朝 +X，长度 2）。带摆尾游动的几何着色器。
enum FishModels {
    private static var cache: [String: SCNNode] = [:]
    static let stiff: Set<String> = ["crab", "kingcrab", "urchin", "abalone", "lobster", "prawn", "krill"]

    static let swim = """
#pragma arguments
float swimAmp;
float swimSpeed;
float fishCX;
float fishHalf;
#pragma body
float x = (_geometry.position.x - fishCX) / fishHalf;
float k = clamp((1.0 - x) * 0.5, 0.0, 1.0);
float ph = scn_frame.time * swimSpeed - x * 2.6;
_geometry.position.z += sin(ph) * swimAmp * k * k * fishHalf;
_geometry.position.y += sin(scn_frame.time * swimSpeed * 0.5) * swimAmp * 0.15 * fishHalf;
"""

    static func prototype(_ id: String) -> SCNNode? {
        // 返回长度为 2、居中的鱼
        if let c = cache[id] { return c }
        let url = Bundle.main.url(forResource: "Fish_\(id)", withExtension: "usdz", subdirectory: "Fish")
            ?? Bundle.main.url(forResource: "Fish_\(id)", withExtension: "usdz")
        guard let url, let s = try? SCNScene(url: url, options: [.checkConsistency: false]) else { return nil }
        let holder = SCNNode()
        for c in s.rootNode.childNodes { holder.addChildNode(c) }
        let flat = holder.flattenedClone()
        let (lo, hi) = flat.boundingBox
        let half = max(Float(hi.x - lo.x) / 2, 0.0001)
        let cx = Float(hi.x + lo.x) / 2
        let amp: Float = stiff.contains(where: { id.contains($0) }) ? 0.02 : 0.16
        for m in flat.geometry?.materials ?? [] {
            m.lightingModel = .physicallyBased
            m.metalness.contents = 0.0
            m.roughness.contents = 0.38
            m.isDoubleSided = true
            m.shaderModifiers = [.geometry: swim]
            m.setValue(NSNumber(value: amp), forKey: "swimAmp")
            m.setValue(NSNumber(value: 5.0), forKey: "swimSpeed")
            m.setValue(NSNumber(value: cx), forKey: "fishCX")
            m.setValue(NSNumber(value: half), forKey: "fishHalf")
        }
        let wrap = SCNNode(); wrap.addChildNode(flat)
        let sc = 1 / half
        flat.scale = SCNVector3(sc, sc, sc)
        flat.position = SCNVector3(-cx * sc, -Float(hi.y + lo.y) / 2 * sc, -Float(hi.z + lo.z) / 2 * sc)
        cache[id] = wrap
        return wrap
    }

    /// 返回可独立放置的鱼节点（共享几何）
    static func node(_ id: String) -> SCNNode? {
        guard let p = prototype(id) else { return nil }
        let n = p.clone(); n.name = "fish:\(id)"
        return n
    }

    static func tankBG() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 256)).image { ctx in
            let cs = CGColorSpaceCreateDeviceRGB()
            let g = CGGradient(colorsSpace: cs, colors: [UIColor(red: 0.70, green: 0.94, blue: 0.93, alpha: 1).cgColor,
                                                         UIColor(red: 0.20, green: 0.58, blue: 0.70, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
        }
    }

    static func softLights(_ root: SCNNode, warm: Bool = true) {
        let k = SCNNode(); let l = SCNLight(); l.type = .directional; l.intensity = 900
        l.color = warm ? UIColor(red: 1, green: 0.93, blue: 0.85, alpha: 1) : UIColor.white
        k.light = l; k.eulerAngles = SCNVector3(-0.8, 0.6, 0); root.addChildNode(k)
        let a = SCNNode(); let al = SCNLight(); al.type = .ambient; al.intensity = 520
        al.color = UIColor(red: 0.80, green: 0.88, blue: 1.0, alpha: 1); a.light = al; root.addChildNode(a)
    }
}

/// 3D 生态鱼缸：鱼在缸里来回游，点鱼打开小百科
struct Aquarium3D: UIViewRepresentable {
    let ids: [String]
    let onTap: (String) -> Void

    final class Coord: NSObject {
        var onTap: (String) -> Void = { _ in }
        var ids: [String] = []
        weak var view: SCNView?
        @objc func tap(_ g: UITapGestureRecognizer) {
            guard let v = view else { return }
            for h in v.hitTest(g.location(in: v), options: [.searchMode: SCNHitTestSearchMode.all.rawValue]) {
                var n: SCNNode? = h.node
                while let c = n { if let nm = c.name, nm.hasPrefix("fish:") { onTap(String(nm.dropFirst(5))); return }; n = c.parent }
            }
        }
    }
    func makeCoordinator() -> Coord { Coord() }

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView(); v.antialiasingMode = .multisampling4X; v.isPlaying = true
        v.backgroundColor = .clear
        context.coordinator.view = v
        v.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coord.tap(_:))))
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        context.coordinator.onTap = onTap
        guard context.coordinator.ids != ids || v.scene == nil else { return }
        context.coordinator.ids = ids
        v.scene = Self.build(ids)
    }

    static func build(_ ids: [String]) -> SCNScene {
        let s = SCNScene()
        s.background.contents = FishModels.tankBG()
        let cam = SCNNode(); let c = SCNCamera(); c.fieldOfView = 40; c.wantsHDR = true; c.bloomIntensity = 0.3; c.bloomThreshold = 0.9
        c.vignettingIntensity = 0.3; cam.camera = c; cam.position = SCNVector3(0, 0.2, 9); s.rootNode.addChildNode(cam)
        FishModels.softLights(s.rootNode)
        // 沙底 + 水草 + 光柱
        let sand = SCNNode(geometry: SCNBox(width: 14, height: 0.6, length: 4, chamferRadius: 0.3))
        sand.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.97, green: 0.89, blue: 0.72, alpha: 1)
        sand.position = SCNVector3(0, -2.4, -1); s.rootNode.addChildNode(sand)
        for k in 0..<7 {
            let w = SCNNode(geometry: SCNCapsule(capRadius: 0.08, height: 1.2 + CGFloat(k % 3) * 0.4))
            w.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.42, green: 0.78, blue: 0.55, alpha: 1)
            w.position = SCNVector3(Float(k) * 1.6 - 4.8, -1.6, -1.5 + Float(k % 2) * 0.6)
            w.pivot = SCNMatrix4MakeTranslation(0, -0.6, 0)
            w.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: 0, z: 0.15, duration: 1.6), .rotateTo(x: 0, y: 0, z: -0.15, duration: 1.6)])))
            s.rootNode.addChildNode(w)
        }
        for (i, id) in ids.enumerated() {
            guard let f = FishModels.node(id) else { continue }
            let holder = SCNNode(); holder.name = "fish:\(id)"
            f.scale = SCNVector3(0.55, 0.55, 0.55); holder.addChildNode(f)
            let y = Float(i % 4) * 0.8 - 1.0
            let z = Float(i % 3) * -0.8
            let span: Float = 3.6
            let dur = 5.0 + Double(i % 5) * 0.9
            holder.position = SCNVector3(-span + Float(i * 37 % 7), y, z)
            let mR: SCNAction = SCNAction.move(to: SCNVector3(span, y, z), duration: dur)
            let mL: SCNAction = SCNAction.move(to: SCNVector3(-span, y, z), duration: dur)
            let tR: SCNAction = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.5, usesShortestUnitArc: true)
            let tL: SCNAction = SCNAction.rotateTo(x: 0, y: CGFloat.pi, z: 0, duration: 0.5, usesShortestUnitArc: true)
            let goR: SCNAction = SCNAction.group([mR, tR])
            let goL: SCNAction = SCNAction.group([mL, tL])
            mR.timingMode = SCNActionTimingMode.easeInEaseOut; mL.timingMode = SCNActionTimingMode.easeInEaseOut
            let loop: SCNAction = SCNAction.repeatForever(SCNAction.sequence([goR, goL]))
            holder.runAction(SCNAction.sequence([SCNAction.wait(duration: Double(i) * 0.3), loop]))
            s.rootNode.addChildNode(holder)
        }
        let bubbles = SCNParticleSystem(); bubbles.birthRate = 6; bubbles.particleLifeSpan = 4
        bubbles.particleVelocity = 0.8; bubbles.emitterShape = SCNBox(width: 10, height: 0.1, length: 2, chamferRadius: 0)
        bubbles.particleSize = 0.06; bubbles.particleImage = Tex.dot(.white); bubbles.particleColor = UIColor(white: 1, alpha: 0.7)
        bubbles.emittingDirection = SCNVector3(0, 1, 0)
        let bn = SCNNode(); bn.position = SCNVector3(0, -2, 0); bn.addParticleSystem(bubbles); s.rootNode.addChildNode(bn)
        return s
    }
}

/// 小百科中的旋转 3D 模型（可拖动查看）
struct FishTurntable: UIViewRepresentable {
    let id: String
    func makeUIView(context: Context) -> SCNView {
        let v = SCNView(); v.antialiasingMode = .multisampling4X; v.isPlaying = true; v.allowsCameraControl = true
        v.backgroundColor = .clear
        let s = SCNScene()
        let cam = SCNNode(); let c = SCNCamera(); c.fieldOfView = 34; cam.camera = c; cam.position = SCNVector3(0, 0.5, 5.2)
        cam.look(at: SCNVector3(0, 0, 0)); s.rootNode.addChildNode(cam)
        FishModels.softLights(s.rootNode)
        if let f = FishModels.node(id) {
            let spin = SCNNode(); spin.addChildNode(f); f.eulerAngles.y = 0.3
            spin.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 9)))
            s.rootNode.addChildNode(spin)
        }
        v.scene = s; v.pointOfView = cam
        return v
    }
    func updateUIView(_ v: SCNView, context: Context) {}
}
