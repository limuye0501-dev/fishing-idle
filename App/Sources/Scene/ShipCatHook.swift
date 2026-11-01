import SceneKit
import UIKit

/// v9：船猫挂点。3D 同事可以在船模型里放一个名为 "ShipCat" 的节点（或替换本占位节点的几何体），
/// 这里只负责：没有时放一个简单占位（橘色圆团 + 耳朵）、点击检测、爱心粒子。
enum ShipCatHook {
    static let nodeName = "ShipCat"

    static func install(in scene: SCNScene) {
        guard scene.rootNode.childNode(withName: nodeName, recursively: true) == nil else { return }
        let cat = SCNNode(); cat.name = nodeName
        let fur = SCNMaterial(); fur.diffuse.contents = UIColor(red: 0.96, green: 0.62, blue: 0.30, alpha: 1); fur.roughness.contents = 0.9
        let body = SCNNode(geometry: SCNSphere(radius: 0.16)); body.scale = SCNVector3(1.3, 0.8, 1); body.geometry?.materials = [fur]
        let head = SCNNode(geometry: SCNSphere(radius: 0.11)); head.position = SCNVector3(0.2, 0.1, 0); head.geometry?.materials = [fur]
        for z: Float in [-0.06, 0.06] {
            let ear = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.04, height: 0.08)); ear.geometry?.materials = [fur]
            ear.position = SCNVector3(0.2, 0.21, z); cat.addChildNode(ear)
        }
        cat.addChildNode(body); cat.addChildNode(head)
        // 呼吸
        let br = SCNAction.sequence([.scale(to: 1.04, duration: 1.4), .scale(to: 1.0, duration: 1.4)]); br.timingMode = .easeInEaseOut
        cat.runAction(.repeatForever(br))
        // 放在船长附近（若找得到船长），否则放在甲板中心附近
        if let cap = scene.rootNode.childNode(withName: "CaptainWave", recursively: true), let holder = cap.parent?.parent ?? cap.parent {
            let w = cap.convertPosition(SCNVector3(0, 0, 0), to: holder)
            cat.position = SCNVector3(w.x - 0.7, w.y, w.z + 0.35)
            holder.addChildNode(cat)
        } else {
            cat.position = SCNVector3(-0.8, 0.62, 0.6)
            scene.rootNode.addChildNode(cat)
        }
    }

    /// 点击命中船猫（含其子节点）
    static func hit(_ view: SCNView, at p: CGPoint) -> Bool {
        let hits = view.hitTest(p, options: [.searchMode: SCNHitTestSearchMode.all.rawValue, .boundingBoxOnly: true])
        return hits.contains { h in
            var n: SCNNode? = h.node
            while let c = n { if c.name == nodeName { return true }; n = c.parent }
            return false
        }
    }

    /// 爱心飘起
    static func hearts(in scene: SCNScene) {
        guard let cat = scene.rootNode.childNode(withName: nodeName, recursively: true) else { return }
        let ps = SCNParticleSystem()
        ps.birthRate = 30; ps.emissionDuration = 0.4; ps.loops = false
        ps.particleLifeSpan = 1.2; ps.particleSize = 0.08; ps.particleVelocity = 0.8; ps.spreadingAngle = 30
        ps.emittingDirection = SCNVector3(0, 1, 0); ps.particleColor = UIColor(red: 1, green: 0.4, blue: 0.5, alpha: 1)
        ps.particleImage = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { _ in
            ("❤️" as NSString).draw(at: .zero, withAttributes: [.font: UIFont.systemFont(ofSize: 54)])
        }
        ps.isAffectedByGravity = false
        cat.addParticleSystem(ps)
        let hop = SCNAction.sequence([.moveBy(x: 0, y: 0.12, z: 0, duration: 0.15), .moveBy(x: 0, y: -0.12, z: 0, duration: 0.2)])
        cat.runAction(hop)
    }
}
