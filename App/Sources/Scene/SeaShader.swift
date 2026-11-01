import SceneKit
import UIKit

/// 海面着色器（SceneKit shader modifier，Metal）：
/// 浅深渐变、柔和焦散、多层流动法线、柔和菲涅尔、太阳闪光、船体泡沫与尾浪
enum SeaShader {
    static let surface = """
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

#pragma body
float4 wp4 = scn_frame.inverseViewTransform * float4(_surface.position, 1.0);
float2 p = wp4.xz;
float t = scn_frame.time;

// —— 多层流动法线（v5：更明显的波纹细节）——
float2 g = float2(0.0);
float hgt = 0.0;
float2 d1 = float2(0.55, 0.35), d2 = float2(-0.30, 0.70), d3 = float2(0.80, -0.45), d4 = float2(-0.65, -0.55), d5 = float2(0.15, 0.95);
float a1 = dot(p, d1) * 1.1 + t * 0.9, a2 = dot(p, d2) * 1.7 + t * 1.2, a3 = dot(p, d3) * 2.9 - t * 1.6, a4 = dot(p, d4) * 4.3 + t * 2.1, a5 = dot(p, d5) * 6.5 - t * 2.6;
g += d1 * cos(a1) * 0.20; g += d2 * cos(a2) * 0.15; g += d3 * cos(a3) * 0.10; g += d4 * cos(a4) * 0.07; g += d5 * cos(a5) * 0.05;
hgt = sin(a1) * 0.40 + sin(a2) * 0.30 + sin(a3) * 0.18 + sin(a4) * 0.12;
float camDist = length(wp4.xyz - (scn_frame.inverseViewTransform * float4(0.0, 0.0, 0.0, 1.0)).xyz);
float nearF = 1.0 - smoothstep(12.0, 80.0, camDist);
g *= mix(0.7, 1.0, nearF);
float3 nW = normalize(float3(-g.x, 1.0, -g.y));
_surface.normal = normalize((scn_frame.viewTransform * float4(nW, 0.0)).xyz);

// 船的局部坐标（泡沫、尾浪、焦散都围绕船）
float cy = cos(shipYaw), sy = sin(shipYaw);
float2 lp = float2(cy * p.x - sy * p.y, sy * p.x + cy * p.y);

// —— 浅深渐变 + 波峰亮、波谷暗（饱和青绿）——
float r = length(lp / float2(1.6, 1.0));
float depthT = smoothstep(2.0, 26.0, r);
float3 col = mix(shallowColor, deepColor, depthT);
col *= 1.0 + hgt * 0.16 * nearF;
// v5.1：近景更深更饱和（屏幕下方渐暗）
float fg = 1.0 - smoothstep(8.0, 30.0, camDist);
col = mix(col, col * float3(0.45, 0.78, 0.92), fg * 0.75);
float lum = dot(col, float3(0.3, 0.59, 0.11)); col = mix(float3(lum), col, 1.0 + 0.35 * fg);
col = mix(col, col * float3(0.80, 0.95, 1.0), smoothstep(0.2, 0.9, -hgt) * 0.35 * nearF);

// —— 柔和焦散（近处更明显）——
float2 q = p * 0.85;
float v1 = sin(q.x * 1.7 + t * 0.55 + sin(q.y * 1.3 + t * 0.40) * 1.6) * sin(q.y * 1.9 - t * 0.45 + sin(q.x * 1.1 - t * 0.35) * 1.6);
float caus = pow(1.0 - abs(v1), 10.0) * 0.14;
col += float3(0.85, 1.0, 0.95) * caus * causticAmt * (1.0 - smoothstep(4.0, 30.0, r));

// —— 柔和菲涅尔：掠射角处映出天空色 ——
float3 V = normalize(-_surface.position);
float fres = pow(1.0 - clamp(dot(V, _surface.normal), 0.0, 1.0), 4.0);
col = mix(col, skyColor, clamp(fres * 0.45 * (1.0 - fg * 0.7) + smoothstep(40.0, 200.0, camDist) * 0.55, 0.0, 0.75));

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

// —— 白色浪尖（风浪碎沫）——
float crestN = sin(p.x * 5.3 + p.y * 3.7 + t * 1.1) * sin(p.y * 6.1 - p.x * 2.9 - t * 0.8);
float crest = smoothstep(0.55, 0.70, hgt) * smoothstep(0.80, 0.95, crestN);
crest *= nearF * sparkleAmt;

// —— 船体四周泡沫环（紧贴吃水线）——
float ell = length(lp / float2(4.75, 1.72));
float nz = sin(lp.x * 3.1 + t * 1.3) * sin(lp.y * 4.7 - t * 1.1) * 0.5 + sin(lp.x * 7.0 - t * 2.0) * 0.25;
float foam = (1.0 - smoothstep(1.0, 1.40, ell + nz * 0.07)) * smoothstep(0.78, 0.97, ell + nz * 0.04);
// —— 船首浪：从船头向两侧后方张开的 V ——
float bx = 4.6 - lp.x;
float bowSpread = 1.0 + bx * 0.36;
float bowLine = (1.0 - smoothstep(0.0, 0.30 + bx * 0.03, abs(abs(lp.y) - bowSpread))) * smoothstep(-0.3, 0.6, bx) * (1.0 - smoothstep(5.0, 16.0, bx));
float bowFoam = (1.0 - smoothstep(0.0, 2.0, length(float2(lp.x - 4.4, lp.y * 1.3)))) * 1.0;
float spr = fract(sin(dot(floor(lp * 9.0), float2(127.1, 311.7))) * 43758.5);
bowFoam = max(bowFoam, step(0.55, spr) * (1.0 - smoothstep(0.0, 3.2, length(float2(lp.x - 4.2, (abs(lp.y) - 1.4) * 1.5)))));
// —— 尾浪：船尾之后呈 V 形扩散，逐渐淡出 ——
float back = -lp.x - 4.2;
float spread = 0.9 + back * 0.30;
float wakeCore = (1.0 - smoothstep(spread * 0.30, spread * 0.9, abs(lp.y))) * smoothstep(-0.5, 1.0, back) * (1.0 - smoothstep(4.0, 26.0, back));
float wakeEdge = (1.0 - smoothstep(0.0, 0.7, abs(abs(lp.y) - spread))) * smoothstep(0.0, 1.5, back) * (1.0 - smoothstep(8.0, 34.0, back));
float streaks = 0.55 + 0.45 * sin(lp.y * 9.0 + sin(back * 1.3 - t * 2.0) * 1.5) * sin(back * 2.2 - t * 3.0);
float wake = clamp((wakeCore * 0.9 * streaks + wakeEdge * 1.1 * (0.7 + 0.3 * nz) + bowLine * 1.2 * (0.75 + 0.25 * nz) + bowFoam) * wakeOn, 0.0, 1.0);
float fm = clamp(foam * (0.8 + 0.2 * nz) + wake + crest * 0.8, 0.0, 1.0);
col = mix(col, foamColor, fm * 0.92);

col *= mix(1.0, 0.45, nightAmt);
_surface.diffuse = float4(col, 1.0);
"""

    static func apply(to m: SCNMaterial) {
        m.lightingModel = .constant
        m.shaderModifiers = [.surface: surface]
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
