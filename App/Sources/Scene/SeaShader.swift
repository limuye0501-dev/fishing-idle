import SceneKit
import UIKit

/// 海面着色器（SceneKit shader modifier，Metal）：
/// 浅深渐变、柔和焦散、多层流动法线、柔和菲涅尔、太阳闪光、船体泡沫与尾浪
enum SeaShader {
    static let surface: String = """
#pragma arguments
float3 shallowColor;
float3 deepColor;
float3 skyColor;
float3 foamColor;
float3 sunDirW;
float shipYaw;
float wakeOn;
float causticAmt;
float sparkleAmt;
float nightAmt;
texture2d<float> detailN;

#pragma body
float4 wp4 = scn_frame.inverseViewTransform * float4(_surface.position, 1.0);
float2 p = wp4.xz;
float t = scn_frame.time;

// —— v8：Gerstner 多层波（与几何着色器同参数）求解析法线 + 两尺度滚动细节法线贴图 ——
float camDist = length(wp4.xyz - (scn_frame.inverseViewTransform * float4(0.0, 0.0, 0.0, 1.0)).xyz);
float nearF = 1.0 - smoothstep(12.0, 80.0, camDist);
float2 g = float2(0.0);
float hgt = 0.0;
\(SeaShader.waveLoop(normal: true))
hgt = hgt / 0.24;   // 归一化到约 -1…1
// 远处波浪法线减弱（避免远景噪点），近处保留
g *= mix(0.35, 1.0, nearF);
constexpr sampler dS(filter::linear, mip_filter::linear, address::repeat);
float2 uvA = p * 0.11 + float2(t * 0.020, t * 0.013);
float2 uvB = p * 0.37 + float2(-t * 0.031, t * 0.024);
float2 uvC = p * 0.023 + float2(t * 0.006, -t * 0.004);
float2 nA = detailN.sample(dS, uvA).xy * 2.0 - 1.0;
float2 nB = detailN.sample(dS, uvB).xy * 2.0 - 1.0;
float2 nC = detailN.sample(dS, uvC).xy * 2.0 - 1.0;
float detailAmt = mix(0.16, 0.65, nearF);
g += (nA * 0.55 + nB * 0.35) * detailAmt + nC * 0.18;
float3 nW = normalize(float3(-g.x, 1.0, -g.y));
_surface.normal = normalize((scn_frame.viewTransform * float4(nW, 0.0)).xyz);

// 船的局部坐标（泡沫、尾浪、焦散都围绕船）
float cy = cos(shipYaw), sy = sin(shipYaw);
float2 lp = float2(cy * p.x - sy * p.y, sy * p.x + cy * p.y);
float r = length(lp / float2(1.6, 1.0));

// —— 深度/视角渐变：近处俯视更通透的青绿，远处更深更蓝 ——
float3 V = normalize(-_surface.position);
float3 VwE = normalize((scn_frame.inverseViewTransform * float4(V, 0.0)).xyz);
float steep = clamp(VwE.y, 0.0, 1.0);
float depthT = smoothstep(0.08, 0.55, 1.0 - steep) * 0.8 + smoothstep(25.0, 140.0, camDist) * 0.2;
float3 col = mix(shallowColor, deepColor, depthT);
// 波谷更深、波峰更亮（体积感）
col *= 1.0 + hgt * 0.20 * mix(0.4, 1.0, nearF);
// v8b：法线朝向光照的明暗（让波纹/细节法线真正可见）
float3 Lk = normalize(float3(0.35, 0.75, -0.55));
col *= 0.80 + 0.42 * clamp(dot(nW, Lk) * 1.6 - 0.75, 0.0, 1.0) + 0.10 * (nA.x * 0.5 + nB.y * 0.5) * nearF;
col = mix(col, col * float3(0.78, 0.92, 1.0), smoothstep(0.1, 0.9, -hgt) * 0.30 * nearF);

// —— 次表面散射：逆光波峰透出明亮青绿 ——
float3 Ssun = normalize(sunDirW);
float sssBack = pow(clamp(dot(-VwE, float3(Ssun.x, 0.0, Ssun.z)) * 0.5 + 0.5, 0.0, 1.0), 3.0);
float sssMask = smoothstep(-0.1, 0.8, hgt) * (1.0 - steep * 0.6);
col += float3(0.18, 0.55, 0.45) * sssMask * sssBack * 0.55 * (1.0 - nightAmt) * mix(0.4, 1.0, nearF);

// —— 柔和焦散（近船浅水感）——
float2 q = p * 0.85;
float v1 = sin(q.x * 1.7 + t * 0.55 + sin(q.y * 1.3 + t * 0.40) * 1.6) * sin(q.y * 1.9 - t * 0.45 + sin(q.x * 1.1 - t * 0.35) * 1.6);
float caus = pow(1.0 - abs(v1), 10.0) * 0.10;
col += float3(0.85, 1.0, 0.95) * caus * causticAmt * (1.0 - smoothstep(4.0, 22.0, r));

// —— 菲涅尔天空反射（Schlick），反射向量越接近地平线越偏粉金 ——
float3 Rr = reflect(-VwE, nW);
float fres = 0.02 + 0.98 * pow(1.0 - clamp(dot(VwE, nW), 0.0, 1.0), 5.0);
float3 skyR = mix(skyColor, skyColor * float3(0.80, 0.86, 1.02), clamp(Rr.y * 2.0, 0.0, 1.0));
col = mix(col, skyR, clamp(fres * 0.85, 0.0, 0.78));

// —— 波峰碎沫（风浪白头，被细节噪声打碎）——
float foamN = (nA.x + nB.y) * 0.5;
float crest = smoothstep(0.62, 0.92, hgt + foamN * 0.35) * nearF * sparkleAmt;
float fg = 0.0;
// —— 太阳金色波光带（宽高光 + 圆形闪点）——
float3 Vw = normalize((scn_frame.inverseViewTransform * float4(V, 0.0)).xyz);
float3 Rw = reflect(-Vw, nW);
float3 S = normalize(sunDirW);
float rd = max(dot(Rw, S), 0.0);
float spec = pow(rd, 260.0) * 1.8 + pow(rd, 40.0) * 0.6 + pow(rd, 6.0) * 0.12;
float2 cp = p * float2(2.2, 4.0);
float2 cell = floor(cp);
float h = fract(sin(dot(cell, float2(12.9898, 78.233))) * 43758.5453);
float2 fr = fract(cp) - 0.5 - (float2(fract(h * 7.31), fract(h * 3.17)) - 0.5) * 0.5;
float dotm = 1.0 - smoothstep(0.06, 0.16, length(fr * float2(1.0, 1.8)));
float tw = smoothstep(0.55, 1.0, sin(t * (1.5 + h * 2.5) + h * 40.0));
float3 sunCol = mix(float3(1.0, 0.80, 0.45), float3(1.0, 0.97, 0.90), nightAmt);
// 风格化金色波光带：方位角接近太阳方向的海面，被波纹打碎
float3 camW = (scn_frame.inverseViewTransform * float4(0.0, 0.0, 0.0, 1.0)).xyz;
float2 dirH = normalize(wp4.xz - camW.xz);
float2 sunH = normalize(sunDirW.xz + float2(1e-4, 0.0));
float ad = 1.0 - dot(dirH, sunH);
float pathW = mix(0.030, 0.006, smoothstep(10.0, 120.0, camDist));
float band = exp(-ad / pathW) * smoothstep(5.0, 18.0, camDist) * (1.0 - nightAmt * 0.6);
float path = max(smoothstep(0.70, 0.99, rd), band);
float brk = smoothstep(0.15, 0.9, sin(p.y * 5.0 + g.x * 14.0 + t * 1.5) * 0.5 + 0.5 + hgt * 0.4);
col = mix(col, sunCol * 1.15, clamp(band * (0.35 + 0.65 * brk), 0.0, 1.0) * 0.95 * sparkleAmt);
float spark = step(0.55, h) * tw * dotm * path * sparkleAmt;
col += sunCol * (spec + spark * 1.4) * mix(1.0, 0.6, nightAmt);

// —— v5.4：屏幕空间金色波光带（位于画面 30% 处太阳正下方）——
float3 pv = _surface.position;
float sx = (pv.x / max(-pv.z, 0.01)) / 0.4452;
float dep = max(Vw.y, 0.0);
float gc = -0.40;   // v5.5：天空贴图太阳固定在画面 30% 处（左侧）
float gw = 0.05 + dep * 0.55;
float lz = (sx - gc) / gw;
float lobe = exp(-lz * lz) * smoothstep(0.0, 0.015, dep) * (1.0 - smoothstep(0.18, 0.42, dep));
float gn = sin(p.x * 2.7 + g.y * 9.0 + t * 1.7) * sin(p.y * 9.5 - g.x * 7.0 - t * 1.2) + 0.6 * sin(p.x * 6.3 - p.y * 4.1 + t * 2.6);
float gsp = smoothstep(0.35, 1.1, gn + hgt * 0.4);
float3 gold = float3(1.0, 0.80, 0.42);
// v7.6：参考图那样明显的金色波光路径（被波纹打碎成亮片）
float gsp2 = smoothstep(0.55, 1.0, gn + hgt * 0.5);
col = mix(col, gold * 1.15, clamp(lobe * (0.25 + 0.55 * gsp), 0.0, 0.8) * (1.0 - nightAmt));
col += float3(1.0, 0.92, 0.75) * lobe * (gsp * 0.5 + gsp2 * 0.9) * (1.0 - nightAmt);

// —— 船体四周泡沫环（紧贴吃水线）——
float ell = length(lp / float2(4.75, 1.72));
float nz = sin(lp.x * 3.1 + t * 1.3) * sin(lp.y * 4.7 - t * 1.1) * 0.5 + sin(lp.x * 7.0 - t * 2.0) * 0.25;
float churn = 0.5 + 0.5 * sin(lp.x * 11.0 - t * 6.0 + sin(lp.y * 9.0 + t * 4.0) * 2.0) * sin(lp.y * 13.0 + t * 5.0);
float foam = (1.0 - smoothstep(1.0, 1.18, ell + nz * 0.07)) * smoothstep(0.88, 0.99, ell + nz * 0.04) * (0.6 + 0.4 * churn);   // v7.6：细泡沫线
// —— 船首浪：从船头向两侧后方张开的 V ——
float bx = 4.6 - lp.x;
float bowSpread = 1.0 + bx * 0.36;
float bowLine = (1.0 - smoothstep(0.0, 0.22 + bx * 0.02, abs(abs(lp.y) - bowSpread))) * smoothstep(-0.3, 0.6, bx) * (1.0 - smoothstep(2.0, 7.0, bx));   // v7.6：短而碎
// v7.6：船首翻涌白浪——紧贴船头，高频碎沫
float bowFoam = 0.8 * (1.0 - smoothstep(0.2, 1.1, length(float2(lp.x - 4.1, lp.y * 0.9)))) * smoothstep(0.25, 0.75, churn + nz * 0.5);
// —— 尾浪：船尾之后呈 V 形扩散，逐渐淡出 ——
float back = -lp.x - 4.2;
float spread = 0.9 + back * 0.30;
float wakeCore = (1.0 - smoothstep(spread * 0.15, spread * 0.5, abs(lp.y))) * smoothstep(-0.5, 1.0, back) * (1.0 - smoothstep(2.0, 14.0, back)) * 0.6;   // v7.6：收窄尾浪
float wakeEdge = (1.0 - smoothstep(0.0, 0.35, abs(abs(lp.y) - spread))) * smoothstep(0.0, 1.5, back) * (1.0 - smoothstep(5.0, 22.0, back)) * 0.7;
float streaks = 0.55 + 0.45 * sin(lp.y * 9.0 + sin(back * 1.3 - t * 2.0) * 1.5) * sin(back * 2.2 - t * 3.0);
float wake = clamp((wakeCore * 0.9 * streaks + wakeEdge * 1.1 * (0.7 + 0.3 * nz) + bowLine * 0.55 * (0.6 + 0.4 * churn) + bowFoam) * wakeOn, 0.0, 1.0);
float fm = clamp(foam * (0.8 + 0.2 * nz) + wake + crest * 0.8, 0.0, 1.0);
col = mix(col, foamColor * 1.08, clamp(fm * 1.1, 0.0, 1.0));   // v6.1：更白的船首浪

col *= mix(1.0, 0.45, nightAmt);
// v6c：最终叠加金色波光柱（HDR >1 触发泛光）
float gw2 = 0.03 + dep * 0.45;
float lz2 = (sx + 0.40) / gw2;
float vf2 = smoothstep(0.0, 0.01, dep) * (1.0 - smoothstep(0.10, 0.35, dep));
float n1 = sin(p.x * 3.1 + t * 1.9) * sin(p.y * 11.0 - t * 1.3);
float n2 = sin(p.x * 7.7 - p.y * 5.3 + t * 2.7) * sin(p.y * 17.0 + t * 0.9);
float rip = smoothstep(0.25, 0.95, n1 * 0.7 + n2 * 0.5 + 0.2);
float glow2 = exp(-lz2 * lz2) * vf2 * (0.35 + 1.6 * rip) * sparkleAmt * (1.0 - nightAmt);
// v6.1：高频阈值波纹 -> 清晰闪光短条（横向拉长），HDR >1 触发泛光
float2 glQ = p * float2(1.6, 7.5);
float glA = sin(glQ.x * 5.1 + sin(glQ.y * 0.9 + t * 1.1) * 2.0 + t * 2.3) * sin(glQ.y * 3.7 - t * 3.1 + g.x * 6.0);
float glB = sin(glQ.x * 9.3 - glQ.y * 1.7 - t * 3.7) * sin(glQ.y * 6.1 + t * 2.2);
float glS = smoothstep(0.74, 0.80, glA * 0.75 + glB * 0.45 + hgt * 0.2);
float glM = exp(-lz2 * lz2) * vf2 * sparkleAmt * (1.0 - nightAmt);
col += float3(1.0, 0.80, 0.50) * (glM * (0.06 + 0.12 * rip) + exp(-lz2 * lz2 * 0.18) * vf2 * 0.02 * sparkleAmt * (1.0 - nightAmt));
col += float3(1.6, 1.35, 0.95) * glS * glM * 2.2;
// 柱外零星闪点
col += float3(1.4, 1.25, 1.0) * smoothstep(0.86, 0.95, glA * 0.75 + glB * 0.45) * exp(-lz2 * lz2 * 0.08) * vf2 * 0.5 * sparkleAmt * (1.0 - nightAmt);
// —— 柔和地平线雾：远处融入天空粉金 ——
float hz = smoothstep(45.0, 240.0, camDist);
col = mix(col, skyColor * mix(1.0, 0.5, nightAmt), hz * 0.75);
_surface.diffuse = float4(col, 1.0);
"""


    /// v6：最终叠加的金色波光柱（在雾/调色之前的 fragment 末端以加法叠加，避免被雾冲淡）
    static let fragment = """
#pragma body
float3 pv = _surface.position;
float sx = (pv.x / max(-pv.z, 0.01)) / 0.4452;
float3 Vv = normalize(-pv);
float3 Vw = normalize((scn_frame.inverseViewTransform * float4(Vv, 0.0)).xyz);
float dep = max(Vw.y, 0.0);
float4 wp = scn_frame.inverseViewTransform * float4(pv, 1.0);
float2 p = wp.xz;
float t = scn_frame.time;
float gw = 0.035 + dep * 0.75;
float lz = (sx + 0.40) / gw;
float col = exp(-lz * lz);
float vfade = smoothstep(0.0, 0.01, dep) * (1.0 - smoothstep(0.10, 0.35, dep));
float n1 = sin(p.x * 3.1 + t * 1.9) * sin(p.y * 11.0 - t * 1.3);
float n2 = sin(p.x * 7.7 - p.y * 5.3 + t * 2.7) * sin(p.y * 17.0 + t * 0.9);
float rip = smoothstep(0.25, 0.95, n1 * 0.7 + n2 * 0.5 + 0.2);
float glow = col * vfade * (0.35 + 1.6 * rip) * sparkleAmt * (1.0 - nightAmt);
float halo = exp(-lz * lz * 0.18) * vfade * 0.10 * sparkleAmt * (1.0 - nightAmt);
_output.color.rgb += float3(1.0, 0.78, 0.45) * (glow * 0.9 + halo);
"""

    /// v8：Gerstner 波参数（波长 m, 振幅 m, 方向角, 陡度）——几何与片元共用
    static let waves: [(L: Float, A: Float, ang: Float, Q: Float)] = [
        (9.0, 0.085, 0.64, 0.55), (5.6, 0.055, 2.02, 0.6), (3.3, 0.032, -0.31, 0.65), (2.1, 0.020, -2.36, 0.7), (1.3, 0.012, 1.37, 0.7), (0.8, 0.007, 0.25, 0.6)
    ]
    /// 生成展开的波浪求和代码。normal=true 时累加 g（高度梯度）与 hgt；否则累加位移 off
    static func waveLoop(normal: Bool) -> String {
        var out = ""
        for (i, w) in waves.enumerated() {
            let k = 2 * Float.pi / w.L, om = sqrtf(9.8 * k) * 0.75
            let dx = cos(w.ang), dz = sin(w.ang)
            let f = "f\(i)"
            out += "float \(f) = \(k) * dot(p, float2(\(dx), \(dz))) - \(om) * t;\n"
            if normal {
                out += "g += float2(\(dx), \(dz)) * (\(w.A * k) * cos(\(f)));\nhgt += \(w.A) * sin(\(f));\n"
            } else {
                out += "off += float3(\(w.Q * w.A * dx) * cos(\(f)), \(w.A) * sin(\(f)), \(w.Q * w.A * dz) * cos(\(f)));\n"
            }
        }
        return out
    }

    /// v8：顶点位移（只用于近景细分网格；边缘渐隐为 0 与远景平面衔接）
    static let geometry: String = """
#pragma arguments
float dispAmt;
#pragma body
float4 wpG = scn_node.modelTransform * float4(_geometry.position.xyz, 1.0);
float2 p = wpG.xz;
float t = scn_frame.time;
float3 off = float3(0.0);
\(waveLoop(normal: false))
float edge = 1.0 - smoothstep(26.0, 40.0, length(p));
float4 dW = float4(off * edge * dispAmt, 0.0);
_geometry.position.xyz += (scn_node.inverseModelTransform * dW).xyz;
"""

    /// v8：可平铺细节法线贴图（整数频率正弦叠加 → 无缝），RG 存坡度
    static let detailNormalImage: UIImage = {
        let n = 256
        var hgt = [Float](repeating: 0, count: n * n)
        var rng = SeaRNG(seed: 11)
        var comps: [(Float, Float, Float, Float)] = []
        for _ in 0..<28 {
            let fx = Float(Int.random(in: -9...9, using: &rng)), fy = Float(Int.random(in: -9...9, using: &rng))
            if fx == 0 && fy == 0 { continue }
            let fr = sqrtf(fx * fx + fy * fy)
            comps.append((fx, fy, Float.random(in: 0..<(2 * .pi), using: &rng), 1 / powf(fr, 1.3)))
        }
        for y in 0..<n { for x in 0..<n {
            let u = Float(x) / Float(n) * 2 * .pi, v = Float(y) / Float(n) * 2 * .pi
            var h: Float = 0
            for c in comps { h += c.3 * sinf(c.0 * u + c.1 * v + c.2) }
            hgt[y * n + x] = h
        } }
        var px = [UInt8](repeating: 255, count: n * n * 4)
        var mx: Float = 1e-4
        var gs = [(Float, Float)](repeating: (0, 0), count: n * n)
        for y in 0..<n { for x in 0..<n {
            let gx = hgt[y * n + (x + 1) % n] - hgt[y * n + (x + n - 1) % n]
            let gy = hgt[((y + 1) % n) * n + x] - hgt[((y + n - 1) % n) * n + x]
            gs[y * n + x] = (gx, gy); mx = max(mx, abs(gx), abs(gy))
        } }
        for i in 0..<(n * n) {
            px[i * 4] = UInt8(max(0, min(255, (gs[i].0 / mx * 0.5 + 0.5) * 255)))
            px[i * 4 + 1] = UInt8(max(0, min(255, (gs[i].1 / mx * 0.5 + 0.5) * 255)))
            px[i * 4 + 2] = 255
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        let img: CGImage = px.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            return ctx.makeImage()!
        }
        return UIImage(cgImage: img)
    }()

    static func apply(to m: SCNMaterial, displaced: Bool = false) {
        m.lightingModel = .constant
        m.shaderModifiers = displaced ? [.geometry: geometry, .surface: surface] : [.surface: surface]
        m.setValue(NSNumber(value: displaced ? 1.0 : 0.0), forKey: "dispAmt")
        let dp = SCNMaterialProperty(contents: detailNormalImage)
        dp.wrapS = .repeat; dp.wrapT = .repeat; dp.mipFilter = .linear
        m.setValue(dp, forKey: "detailN")
        m.metalness.contents = 0.0
        m.roughness.contents = 0.18
        m.normal.contents = nil
        set(m, shallow: UIColor(red: 0.55, green: 0.92, blue: 0.88, alpha: 1), deep: UIColor(red: 0.20, green: 0.66, blue: 0.74, alpha: 1),
            sky: UIColor(red: 1, green: 0.88, blue: 0.84, alpha: 1), foam: .white, sunDir: SCNVector3(0.4, 0.3, -0.85), yaw: 0.42, wake: 1, night: 0)
        m.setValue(NSNumber(value: 1.0), forKey: "causticAmt")
        m.setValue(NSNumber(value: 1.0), forKey: "sparkleAmt")
    }

    static func vec(_ c: UIColor) -> NSValue {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return NSValue(scnVector3: SCNVector3(Float(r), Float(g), Float(b)))
    }

    static func set(_ m: SCNMaterial, shallow: UIColor, deep: UIColor, sky: UIColor, foam: UIColor, sunDir: SCNVector3, yaw: Float, wake: Float, night: Float) {
        m.setValue(vec(shallow), forKey: "shallowColor")
        m.setValue(vec(deep), forKey: "deepColor")
        m.setValue(vec(sky), forKey: "skyColor")
        m.setValue(vec(foam), forKey: "foamColor")
        m.setValue(NSValue(scnVector3: sunDir), forKey: "sunDirW")
        m.setValue(NSNumber(value: yaw), forKey: "shipYaw")
        m.setValue(NSNumber(value: wake), forKey: "wakeOn")
        m.setValue(NSNumber(value: night), forKey: "nightAmt")
    }
}

/// v8：确定性随机（细节法线贴图每次启动一致）
struct SeaRNG: RandomNumberGenerator {
    var s: UInt64
    init(seed: UInt64) { s = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> UInt64 { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return s }
}
