import SceneKit
import UIKit

/// 场景布局文件（PortLayout.json）中的一个节点：模型 / 基本体 / 预制件
struct PortNode: Decodable {
    var m: String?
    var k: String?
    var size: [Float]?
    var c: [Float]?
    var p: [Float]?
    var ry: Float?
    var rx: Float?
    var s: [Float]?
    var tint: [Float]?
    var glow: Int?
    var foam: Float?
    var bob: Int?
    var prefab: String?
    var name: String?
    var tex: String?

    enum CodingKeys: String, CodingKey { case m, k, size, c, p, ry, rx, s, tint, glow, foam, bob, prefab, name, tex }

    init(from decoder: Decoder) throws {
        let d = try decoder.container(keyedBy: CodingKeys.self)
        m = try d.decodeIfPresent(String.self, forKey: .m)
        k = try d.decodeIfPresent(String.self, forKey: .k)
        size = try d.decodeIfPresent([Float].self, forKey: .size)
        c = try d.decodeIfPresent([Float].self, forKey: .c)
        p = try d.decodeIfPresent([Float].self, forKey: .p)
        ry = try d.decodeIfPresent(Float.self, forKey: .ry)
        rx = try d.decodeIfPresent(Float.self, forKey: .rx)
        tint = try d.decodeIfPresent([Float].self, forKey: .tint)
        glow = try d.decodeIfPresent(Int.self, forKey: .glow)
        foam = try d.decodeIfPresent(Float.self, forKey: .foam)
        bob = try d.decodeIfPresent(Int.self, forKey: .bob)
        prefab = try d.decodeIfPresent(String.self, forKey: .prefab)
        name = try d.decodeIfPresent(String.self, forKey: .name)
        tex = try d.decodeIfPresent(String.self, forKey: .tex)
        // s 可以是一个数，也可以是 [x, y, z]
        if let one = try? d.decode(Float.self, forKey: .s) {
            s = [one, one, one]
        } else {
            s = try d.decodeIfPresent([Float].self, forKey: .s)
        }
    }
}

struct PortCamera: Decodable { var pos: [Float]; var look: [Float]; var fov: Float }

struct PortLayout: Decodable {
    var camera: PortCamera
    var sunDir: [Float]
    var prefabs: [String: [PortNode]]
    var nodes: [PortNode]

    static func load() -> PortLayout? {
        guard let url = Bundle.main.url(forResource: "PortLayout", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PortLayout.self, from: data)
    }
}

/// 加载 Kenney 低多边形模型（构建时已从 OBJ 转成“顶点 + 法线 + 顶点色”的紧凑二进制 .mesh）
final class ModelLibrary {
    static let shared = ModelLibrary()
    private var cache: [String: SCNGeometry] = [:]

    private func url(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "mesh")
            ?? Bundle.main.url(forResource: name, withExtension: "mesh", subdirectory: "Models")
    }

    func geometry(_ name: String, tint: [Float]?) -> SCNGeometry? {
        let key = name + (tint.map { $0.map { String($0) }.joined(separator: ",") } ?? "")
        if let g = cache[key] { return g }
        guard let u = url(name), var data = try? Data(contentsOf: u), data.count > 4 else { return nil }
        let count: Int = data.withUnsafeBytes { raw in Int(raw.loadUnaligned(fromByteOffset: 0, as: UInt32.self)) }
        var body = data.subdata(in: 4..<data.count)
        if let t = tint, t.count == 3 {
            body.withUnsafeMutableBytes { raw in
                let f = raw.bindMemory(to: Float.self)
                for v in 0..<count {
                    for ch in 0..<3 {
                        let i = v * 9 + 6 + ch
                        f[i] = min(1, f[i] * t[ch])
                    }
                }
            }
        }
        data = body
        let stride = 36
        let vs = SCNGeometrySource(data: data, semantic: .vertex, vectorCount: count, usesFloatComponents: true,
                                   componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: stride)
        let ns = SCNGeometrySource(data: data, semantic: .normal, vectorCount: count, usesFloatComponents: true,
                                   componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 12, dataStride: stride)
        let cs = SCNGeometrySource(data: data, semantic: .color, vectorCount: count, usesFloatComponents: true,
                                   componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 24, dataStride: stride)
        let indices: [UInt32] = (0..<UInt32(count)).map { $0 }
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let g = SCNGeometry(sources: [vs, ns, cs], elements: [element])
        let m = SCNMaterial()
        m.diffuse.contents = UIColor.white
        m.lightingModel = .lambert
        g.materials = [m]
        cache[key] = g
        return g
    }
}

/// 2D 气泡贴图（鱼获气泡、出海计时胶囊）
enum BubbleArt {
    static func fishBubble(count: Int) -> UIImage {
        let size = CGSize(width: 220, height: 200)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let g = ctx.cgContext
            let bubble = UIBezierPath(ovalIn: CGRect(x: 10, y: 8, width: 170, height: 140))
            let tail = UIBezierPath()
            tail.move(to: CGPoint(x: 80, y: 140)); tail.addLine(to: CGPoint(x: 95, y: 178)); tail.addLine(to: CGPoint(x: 112, y: 140))
            g.setShadow(offset: CGSize(width: 0, height: 4), blur: 6, color: UIColor.black.withAlphaComponent(0.25).cgColor)
            UIColor(red: 1, green: 0.98, blue: 0.93, alpha: 1).setFill()
            bubble.fill(); tail.fill()
            g.setShadow(offset: .zero, blur: 0, color: nil)
            let fish = "🐟" as NSString
            fish.draw(at: CGPoint(x: 42, y: 26), withAttributes: [.font: UIFont.systemFont(ofSize: 80)])
            let badge = CGRect(x: 150, y: 100, width: 62, height: 62)
            UIColor(red: 0.45, green: 0.30, blue: 0.20, alpha: 1).setFill()
            UIBezierPath(ovalIn: badge).fill()
            UIColor.white.setStroke()
            let ring = UIBezierPath(ovalIn: badge.insetBy(dx: 3, dy: 3)); ring.lineWidth = 4; ring.stroke()
            let text = "\(count)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 34, weight: .heavy),
                                                        .foregroundColor: UIColor.white]
            let ts = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: badge.midX - ts.width / 2, y: badge.midY - ts.height / 2), withAttributes: attrs)
        }
    }

    static func timerPill(_ text: String, progress: Double) -> UIImage {
        let size = CGSize(width: 300, height: 110)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let pill = UIBezierPath(roundedRect: CGRect(x: 6, y: 6, width: 288, height: 98), cornerRadius: 26)
            UIColor(red: 0.12, green: 0.20, blue: 0.30, alpha: 0.88).setFill()
            pill.fill()
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedDigitSystemFont(ofSize: 40, weight: .bold),
                                                        .foregroundColor: UIColor.white]
            ("⚓︎" as NSString).draw(at: CGPoint(x: 26, y: 14), withAttributes: attrs)
            (text as NSString).draw(at: CGPoint(x: 100, y: 14), withAttributes: attrs)
            let track = CGRect(x: 26, y: 74, width: 248, height: 14)
            UIColor.white.withAlphaComponent(0.25).setFill()
            UIBezierPath(roundedRect: track, cornerRadius: 7).fill()
            let p = CGFloat(max(0, min(1, progress)))
            UIColor(red: 0.25, green: 0.62, blue: 1, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: track.minX, y: track.minY, width: max(14, track.width * p), height: track.height),
                         cornerRadius: 7).fill()
        }
    }

    /// 白色泡沫环（中间透明，外缘柔和）
    static let foamRing: UIImage = {
        let size = CGSize(width: 256, height: 256)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor.white.withAlphaComponent(0).cgColor,
                          UIColor.white.withAlphaComponent(0.0).cgColor,
                          UIColor.white.withAlphaComponent(0.85).cgColor,
                          UIColor.white.withAlphaComponent(0.35).cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let locs: [CGFloat] = [0, 0.52, 0.66, 0.8, 1]
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) {
                let c = CGPoint(x: 128, y: 128)
                ctx.cgContext.drawRadialGradient(grad, startCenter: c, startRadius: 0, endCenter: c, endRadius: 128, options: [])
            }
        }
    }()
}
