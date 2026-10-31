import UIKit
import FishingCore

/// 场景配色：随昼夜、天气、海域变化
struct SkyPalette: Equatable {
    var zenith: UIColor
    var mid: UIColor
    var horizon: UIColor
    var sun: UIColor
    var sunVisible: Bool
    var sunX: CGFloat          // 0...1
    var cloud: UIColor
    var cloudShade: UIColor
    var mountains: UIColor
    var sea: UIColor
    var lightColor: UIColor
    var lightIntensity: CGFloat
    var ambient: UIColor
    var ambientIntensity: CGFloat
    var lightElevation: Float  // 弧度
    var stars: Bool
    var cloudCount: Int
    var fogStart: CGFloat
    var fogEnd: CGFloat

    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }

    static func make(part: DayPart, weather: Weather, ocean: String) -> SkyPalette {
        var p: SkyPalette
        switch part {
        case .dusk, .dawn:
            // 参考图：粉金色晚霞
            p = SkyPalette(zenith: rgb(0.93, 0.70, 0.74), mid: rgb(0.99, 0.80, 0.72), horizon: rgb(1.0, 0.90, 0.76),
                           sun: rgb(1.0, 0.93, 0.70), sunVisible: true, sunX: part == .dusk ? 0.62 : 0.38,
                           cloud: rgb(1.0, 0.80, 0.80), cloudShade: rgb(0.90, 0.62, 0.70), mountains: rgb(0.78, 0.66, 0.78),
                           sea: rgb(0.33, 0.74, 0.76), lightColor: rgb(1.0, 0.82, 0.68), lightIntensity: 1500,
                           ambient: rgb(1.0, 0.84, 0.82), ambientIntensity: 650, lightElevation: 0.22, stars: false, cloudCount: 7,
                           fogStart: 45, fogEnd: 170)
        case .day:
            p = SkyPalette(zenith: rgb(0.48, 0.74, 0.93), mid: rgb(0.66, 0.85, 0.96), horizon: rgb(0.88, 0.95, 0.96),
                           sun: rgb(1.0, 0.98, 0.88), sunVisible: false, sunX: 0.8,
                           cloud: rgb(1.0, 1.0, 1.0), cloudShade: rgb(0.80, 0.86, 0.94), mountains: rgb(0.64, 0.76, 0.86),
                           sea: rgb(0.28, 0.72, 0.78), lightColor: rgb(1.0, 0.97, 0.90), lightIntensity: 1800,
                           ambient: rgb(0.86, 0.92, 1.0), ambientIntensity: 700, lightElevation: 0.75, stars: false, cloudCount: 6,
                           fogStart: 50, fogEnd: 190)
        case .night:
            p = SkyPalette(zenith: rgb(0.08, 0.10, 0.26), mid: rgb(0.18, 0.18, 0.40), horizon: rgb(0.38, 0.32, 0.52),
                           sun: rgb(0.98, 0.96, 0.85), sunVisible: true, sunX: 0.72,
                           cloud: rgb(0.36, 0.34, 0.55), cloudShade: rgb(0.24, 0.22, 0.42), mountains: rgb(0.22, 0.22, 0.40),
                           sea: rgb(0.13, 0.32, 0.42), lightColor: rgb(0.70, 0.76, 1.0), lightIntensity: 500,
                           ambient: rgb(0.50, 0.52, 0.80), ambientIntensity: 420, lightElevation: 0.5, stars: true, cloudCount: 4,
                           fogStart: 40, fogEnd: 150)
        }
        let polar = ocean == "arctic" || ocean == "southern"
        let tropical = ocean == "pacific" || ocean == "indian"
        if polar { p.sea = p.sea.mix(rgb(0.45, 0.62, 0.75), 0.45); p.mountains = rgb(0.90, 0.93, 0.98).mix(p.mountains, 0.4) }
        if tropical { p.sea = p.sea.mix(rgb(0.25, 0.85, 0.82), 0.3) }
        switch weather {
        case .rain, .storm:
            let grey = weather == .storm ? rgb(0.45, 0.46, 0.56) : rgb(0.70, 0.70, 0.78)
            p.zenith = p.zenith.mix(grey, 0.7); p.mid = p.mid.mix(grey, 0.6); p.horizon = p.horizon.mix(grey, 0.45)
            p.cloud = p.cloud.mix(grey, 0.6); p.cloudShade = p.cloudShade.mix(grey.mix(.black, 0.2), 0.7)
            p.sea = p.sea.mix(rgb(0.35, 0.50, 0.58), 0.45); p.sunVisible = false
            p.lightIntensity *= 0.5; p.cloudCount = 12
        case .fog:
            let pale = rgb(0.90, 0.90, 0.92)
            p.horizon = p.horizon.mix(pale, 0.7); p.mid = p.mid.mix(pale, 0.6); p.zenith = p.zenith.mix(pale, 0.4)
            p.fogStart = 8; p.fogEnd = 60; p.sunVisible = false; p.cloudCount = 2; p.lightIntensity *= 0.6
        case .ice:
            p.cloudCount = 5
        default: break
        }
        return p
    }

    /// 天空背景图（地平线位置 horizon 0...1，自上而下）
    func skyImage(size: CGSize, horizonAt: CGFloat, seed: Int) -> UIImage {
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { ctx in
            let cg = ctx.cgContext
            let hy = size.height * horizonAt
            let colors = [zenith.cgColor, mid.cgColor, horizon.cgColor] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1])!
            cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: hy), options: [.drawsAfterEndLocation])
            var rng = SeededRNG(seed: UInt64(seed))
            if stars {
                for _ in 0..<140 {
                    let x = CGFloat.random(in: 0...size.width, using: &rng), y = CGFloat.random(in: 0...(hy * 0.85), using: &rng)
                    let s = CGFloat.random(in: 1...3.2, using: &rng)
                    cg.setFillColor(UIColor(white: 1, alpha: .random(in: 0.4...0.95, using: &rng)).cgColor)
                    cg.fillEllipse(in: CGRect(x: x, y: y, width: s, height: s))
                }
            }
            // 太阳/月亮 + 光晕
            if sunVisible {
                let night = stars
                let c = CGPoint(x: size.width * sunX, y: night ? hy * 0.35 : hy - size.width * 0.03)
                let glowR = size.width * (night ? 0.22 : 0.55)
                let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [sun.withAlphaComponent(night ? 0.35 : 0.85).cgColor, sun.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
                cg.drawRadialGradient(glow, startCenter: c, startRadius: 0, endCenter: c, endRadius: glowR, options: [])
                let sr = size.width * (night ? 0.045 : 0.075)
                cg.setFillColor(sun.cgColor)
                cg.fillEllipse(in: CGRect(x: c.x - sr, y: c.y - sr, width: sr * 2, height: sr * 2))
            }
            // 远山（两侧）
            func drawRange(_ x0: CGFloat, _ x1: CGFloat, _ peak: CGFloat, _ color: UIColor) {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: x0, y: hy + 1))
                let n = 7
                for i in 0...n {
                    let t = CGFloat(i) / CGFloat(n)
                    let x = x0 + (x1 - x0) * t
                    let bump = sin(t * .pi) * peak * (0.65 + 0.35 * sin(t * 13 + CGFloat(seed)))
                    path.addLine(to: CGPoint(x: x, y: hy - bump))
                }
                path.addLine(to: CGPoint(x: x1, y: hy + 1)); path.close()
                color.setFill(); path.fill()
            }
            let far = mountains.mix(horizon, 0.45)
            drawRange(-size.width * 0.1, size.width * 0.42, size.height * 0.045, far)
            drawRange(size.width * 0.70, size.width * 1.1, size.height * 0.035, far)
            drawRange(-size.width * 0.05, size.width * 0.22, size.height * 0.03, mountains.mix(horizon, 0.2))
            // 蓬松的云
            for k in 0..<cloudCount {
                let cx = CGFloat.random(in: -0.1...1.1, using: &rng) * size.width
                let cy = CGFloat.random(in: 0.12...0.8, using: &rng) * hy
                let scale = CGFloat.random(in: 0.6...1.3, using: &rng) * size.width * 0.14 * (cy / hy * 0.6 + 0.6)
                let puffs = 5 + k % 3
                for layer in 0..<2 {
                    cg.setFillColor((layer == 0 ? cloudShade : cloud).withAlphaComponent(0.92).cgColor)
                    for i in 0..<puffs {
                        let t = CGFloat(i) / CGFloat(puffs - 1) - 0.5
                        let pr = scale * (0.55 + 0.45 * cos(t * .pi)) * (layer == 0 ? 1 : 0.92)
                        let px = cx + t * scale * 2.6
                        let py = cy - pr * 0.5 + (layer == 0 ? scale * 0.12 : 0)
                        cg.fillEllipse(in: CGRect(x: px - pr, y: py - pr * 0.8, width: pr * 2, height: pr * 1.6))
                    }
                    cg.fill(CGRect(x: cx - scale * 1.3, y: cy - scale * 0.3 + (layer == 0 ? scale * 0.12 : 0), width: scale * 2.6, height: scale * 0.32))
                }
            }
            // 地平线以下：与雾同色
            cg.setFillColor(horizon.cgColor)
            cg.fill(CGRect(x: 0, y: hy, width: size.width, height: size.height - hy))
        }
    }

    /// PBR 环境图（2:1 等距柱状投影）：上半天空，下半海
    func environmentImage() -> UIImage {
        let size = CGSize(width: 256, height: 128)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [zenith.cgColor, mid.cgColor, horizon.cgColor] as CFArray, locations: [0, 0.6, 1])!
            cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: 64), options: [])
            cg.setFillColor(sea.mix(.black, 0.3).cgColor); cg.fill(CGRect(x: 0, y: 64, width: 256, height: 64))
            if sunVisible && !stars {
                cg.setFillColor(sun.cgColor); cg.fillEllipse(in: CGRect(x: 128 - 10, y: 56, width: 20, height: 10))
            }
        }
    }
}

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

extension UIColor {
    func mix(_ o: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1); o.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
    }
}

enum Tex {
    /// 可平铺的海浪法线贴图
    static let waterNormal: UIImage = {
        let n = 256
        var h = [Float](repeating: 0, count: n * n)
        let waves: [(Int, Int, Float, Float)] = [(1, 2, 1.0, 0.3), (3, -1, 0.6, 1.1), (-2, 5, 0.35, 2.0), (7, 3, 0.2, 0.7), (-9, 6, 0.14, 2.6), (13, -11, 0.08, 1.9), (17, 19, 0.05, 0.4)]
        for y in 0..<n { for x in 0..<n {
            var v: Float = 0
            for (kx, ky, a, ph) in waves {
                v += a * sin(2 * .pi * (Float(kx * x + ky * y) / Float(n)) + ph)
            }
            h[y * n + x] = v
        } }
        var px = [UInt8](repeating: 255, count: n * n * 4)
        for y in 0..<n { for x in 0..<n {
            let dx = h[y * n + (x + 1) % n] - h[y * n + (x - 1 + n) % n]
            let dy = h[((y + 1) % n) * n + x] - h[((y - 1 + n) % n) * n + x]
            var nx = -dx * 1.4, ny = -dy * 1.4, nz: Float = 1
            let l = sqrt(nx * nx + ny * ny + nz * nz); nx /= l; ny /= l; nz /= l
            let i = (y * n + x) * 4
            px[i] = UInt8((nx * 0.5 + 0.5) * 255); px[i + 1] = UInt8((ny * 0.5 + 0.5) * 255); px[i + 2] = UInt8((nz * 0.5 + 0.5) * 255)
        } }
        return image(px, n, n)
    }()

    static func image(_ px: [UInt8], _ w: Int, _ h: Int) -> UIImage {
        let data = Data(px) as CFData
        let provider = CGDataProvider(data: data)!
        let cg = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                         space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                         provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
        return UIImage(cgImage: cg)
    }

    /// 船体色带：木扶手 / 奶油 / 金线 / 青绿 / 船底红
    static let hull: UIImage = {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 256)).image { ctx in
            let bands: [(CGFloat, CGFloat, UIColor)] = [
                (0, 0.035, UIColor(red: 0.55, green: 0.36, blue: 0.22, alpha: 1)),
                (0.035, 0.38, UIColor(red: 0.98, green: 0.94, blue: 0.84, alpha: 1)),
                (0.38, 0.405, UIColor(red: 0.88, green: 0.70, blue: 0.36, alpha: 1)),
                (0.405, 0.60, UIColor(red: 0.22, green: 0.60, blue: 0.62, alpha: 1)),
                (0.60, 1.0, UIColor(red: 0.72, green: 0.36, blue: 0.30, alpha: 1)),
            ]
            for (a, b, c) in bands { c.setFill(); ctx.fill(CGRect(x: 0, y: a * 256, width: 8, height: (b - a) * 256)) }
        }
    }()

    /// 甲板木板
    static let planks: UIImage = {
        UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image { ctx in
            var rng = SeededRNG(seed: 7)
            for i in 0..<8 {
                let base = CGFloat.random(in: 0.88...1.0, using: &rng)
                UIColor(red: 0.80 * base, green: 0.62 * base, blue: 0.42 * base, alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: CGFloat(i) * 32, width: 256, height: 32))
                UIColor(red: 0.55, green: 0.40, blue: 0.27, alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: CGFloat(i) * 32 + 30, width: 256, height: 2))
                let jx = CGFloat.random(in: 20...230, using: &rng)
                ctx.fill(CGRect(x: jx, y: CGFloat(i) * 32, width: 2, height: 32))
            }
        }
    }()

    /// 渔网（透明网格）
    static let net: UIImage = {
        UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { ctx in
            let cg = ctx.cgContext
            cg.setStrokeColor(UIColor(red: 0.62, green: 0.78, blue: 0.70, alpha: 0.95).cgColor)
            cg.setLineWidth(3)
            for i in stride(from: 0, through: 128, by: 16) {
                cg.move(to: CGPoint(x: CGFloat(i), y: 0)); cg.addLine(to: CGPoint(x: CGFloat(i) + 64, y: 128))
                cg.move(to: CGPoint(x: CGFloat(i), y: 0)); cg.addLine(to: CGPoint(x: CGFloat(i) - 64, y: 128))
            }
            cg.strokePath()
        }
    }()

    /// 船尾白浪（V 形，向后渐隐）
    static let wake: UIImage = {
        UIGraphicsImageRenderer(size: CGSize(width: 256, height: 512)).image { ctx in
            let cg = ctx.cgContext
            var rng = SeededRNG(seed: 3)
            for _ in 0..<900 {
                let t = CGFloat.random(in: 0...1, using: &rng)            // 0 船尾 → 1 远处
                let spread = 0.10 + 0.36 * t
                let side: CGFloat = Bool.random(using: &rng) ? 1 : -1
                let edge = CGFloat.random(in: 0.0...1.0, using: &rng)
                let x = 128 + side * spread * 256 * (edge < 0.7 ? CGFloat.random(in: 0.85...1, using: &rng) : CGFloat.random(in: 0...0.5, using: &rng))
                let y = t * 512
                let r = CGFloat.random(in: 2...7, using: &rng) * (1 - t * 0.5)
                cg.setFillColor(UIColor(white: 1, alpha: (1 - t) * 0.75).cgColor)
                cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            // 螺旋桨中线
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor(white: 1, alpha: 0.7).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray, locations: [0, 1])!
            cg.saveGState(); cg.clip(to: CGRect(x: 108, y: 0, width: 40, height: 512))
            cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 300), options: [])
            cg.restoreGState()
        }
    }()

    /// 船身周围的泡沫圈
    static let foamRing: UIImage = {
        UIGraphicsImageRenderer(size: CGSize(width: 512, height: 256)).image { ctx in
            let cg = ctx.cgContext
            var rng = SeededRNG(seed: 11)
            for _ in 0..<700 {
                let a = CGFloat.random(in: 0...(2 * .pi), using: &rng)
                let rr = CGFloat.random(in: 0.78...1.0, using: &rng)
                let x = 256 + cos(a) * 240 * rr, y = 128 + sin(a) * 110 * rr
                let r = CGFloat.random(in: 2...6, using: &rng)
                let bow = max(0, cos(a))          // 船头浪花更多
                cg.setFillColor(UIColor(white: 1, alpha: 0.35 + 0.5 * bow).cgColor)
                cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
        }
    }()

    static func dot(_ color: UIColor, size: CGFloat = 32) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
            ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: size / 2, y: size / 2), startRadius: 0, endCenter: CGPoint(x: size / 2, y: size / 2), endRadius: size / 2, options: [])
        }
    }
    static let streak: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 32)).image { ctx in
        UIColor(white: 1, alpha: 0.6).setFill(); ctx.fill(CGRect(x: 1, y: 0, width: 2, height: 32))
    }
}
