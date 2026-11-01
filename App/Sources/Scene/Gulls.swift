import SceneKit
import UIKit

/// v7.3：Meshy 生成的 Q 版海鸥（Body + WingL/WingR 两片翅膀，枢轴在肩部）。
/// 每帧参数化路径：绕船盘旋（倾斜转弯、升降翱翔），拍翅/滑翔交替；1 号海鸥会定期落在桅杆顶歇脚。
enum Gulls {
    static func make(ship: SCNNode, perch: SCNVector3) -> SCNNode? {
        guard let proto = ModelAssets.load("Gull") else { return nil }
        proto.enumerateHierarchy { n, _ in
            for m in n.geometry?.materials ?? [] { m.emission.contents = m.diffuse.contents; m.emission.intensity = 0.18 }
        }
        let root = SCNNode()
        for k in 0..<4 {
            let g = proto.clone()
            let s: Float = 1.15 + Float(k % 2) * 0.2   // v7.5：更大更近，画面里能看清翅膀
            g.scale = SCNVector3(s, s, s)
            root.addChildNode(g)
            let wl = g.childNode(withName: "WingL", recursively: true), wr = g.childNode(withName: "WingR", recursively: true)
            let perches = k == 1
            let period: Double = perches ? 24 : 16 + Double(k) * 3.5
            let r = 4.6 + Float(k) * 1.4, h = 5.0 + Float(k) * 0.7, ph = Float(k) * 1.7, dir: Float = k % 2 == 0 ? 1 : -1
            func path(_ t: Float) -> SCNVector3 {
                let a = dir * t * 2 * .pi + ph
                return SCNVector3(cos(a) * r * 1.25, h + sin(a * 2 + ph) * 0.9, sin(a) * r * 0.8 - 2)
            }
            let act = SCNAction.customAction(duration: period) { node, el in
                let u = Float(el) / Float(period)
                var pos: SCNVector3, look: SCNVector3, bank: Float = 0, flap: Float, fold: Float = 0
                let time = Float(CACurrentMediaTime()) + ph
                // 拍翅 3.6Hz 持续 ~1.2s，随后滑翔 ~2s（翅膀微上扬）
                let cyc = fmodf(time, 3.2)
                flap = cyc < 1.2 ? sin(cyc * 2 * .pi * 3.6) * 0.75 : 0.12 + sin(time * 1.3) * 0.05
                let fly = perches ? min(1, u / 0.62) : u
                if perches && u > 0.62 {
                    // 0.62-0.70 降落，0.70-0.90 歇脚，0.90-1.0 起飞
                    let mast = ship.presentation.convertPosition(perch, to: nil)
                    let start = path(1), end = path(0)
                    if u < 0.70 {
                        let k = (u - 0.62) / 0.08; let e = k * k * (3 - 2 * k)
                        pos = SCNVector3(start.x + (mast.x - start.x) * e, start.y + (mast.y - start.y) * e + sin(k * .pi) * 0.6, start.z + (mast.z - start.z) * e)
                        look = mast; flap = sin(time * 2 * .pi * 4) * 0.6 * (1 - k) + 0.3 * k
                    } else if u < 0.90 {
                        pos = mast; look = SCNVector3(mast.x + 1, mast.y, mast.z + 0.4)
                        flap = 0; fold = 1
                    } else {
                        let k = (u - 0.90) / 0.10; let e = k * k
                        pos = SCNVector3(mast.x + (end.x - mast.x) * e, mast.y + (end.y - mast.y) * e, mast.z + (end.z - mast.z) * e)
                        look = end; flap = sin(time * 2 * .pi * 4.2) * 0.8
                    }
                } else {
                    pos = path(fly); let nx = path(fly + 0.01), nn = path(fly + 0.02)
                    look = nx
                    // 倾斜：按航向变化（曲率）侧倾
                    let h1 = atan2(nx.z - pos.z, nx.x - pos.x), h2 = atan2(nn.z - nx.z, nn.x - nx.x)
                    var dh = h2 - h1; if dh > .pi { dh -= 2 * .pi }; if dh < -.pi { dh += 2 * .pi }
                    bank = max(-0.6, min(0.6, dh * 9))
                    if nx.y < pos.y - 0.01 { flap = 0.1 }   // 下降时滑翔
                }
                node.position = pos
                node.look(at: look, up: SCNVector3(0, 1, 0), localFront: SCNVector3(1, 0, 0))
                node.eulerAngles.x += bank
                // 收翅歇脚：翅膀下垂并收拢
                wl?.eulerAngles = SCNVector3(flap - fold * 1.2, fold * 0.6, 0)
                wr?.eulerAngles = SCNVector3(-flap + fold * 1.2, -fold * 0.6, 0)
            }
            g.runAction(.repeatForever(act))
        }
        return root
    }
}
