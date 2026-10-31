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

// —— 多层流动法线（四组方向不同的柔和波）——
float2 g = float2(0.0);
g += float2(0.55, 0.35) * cos(dot(p, float2(0.55, 0.35)) * 1.1 + t * 0.9) * 0.12;
g += float2(-0.30, 0.70) * cos(dot(p, float2(-0.30, 0.70)) * 1.7 + t * 1.2) * 0.08;
g += float2(0.80, -0.45) * cos(dot(p, float2(0.80, -0.45)) * 2.9 - t * 1.6) * 0.05;
g += float2(-0.65, -0.55) * cos(dot(p, float2(-0.65, -0.55)) * 4.3 + t * 2.1) * 0.03;
float camDist = length(wp4.xyz - (scn_frame.inverseViewTransform * float4(0.0, 0.0, 0.0, 1.0)).xyz);
g *= mix(1.0, 0.25, smoothstep(15.0, 90.0, camDist));
float3 nW = normalize(float3(-g.x, 1.0, -g.y));
_surface.normal = normalize((scn_frame.viewTransform * float4(nW, 0.0)).xyz);

// 船的局部坐标（泡沫、尾浪、焦散都围绕船）
float cy = cos(shipYaw), sy = sin(shipYaw);
float2 lp = float2(cy * p.x - sy * p.y, sy * p.x + cy * p.y);

// —— 浅深渐变：船周围更通透明亮，远处更深 ——
float r = length(lp / float2(1.6, 1.0));
float depthT = smoothstep(2.5, 30.0, r);
float3 col = mix(shallowColor, deepColor, depthT);

// —— 柔和焦散（近处更明显）——
float2 cp = p * 0.55 + float2(t * 0.05, t * 0.03);
float2 ii = cp;
float c = 1.0;
float inten = 0.008;
for (int n = 0; n < 3; n++) {
    float tt = t * 0.35 * (1.0 - (3.5 / float(n + 1)));
    ii = cp + float2(cos(tt - ii.x) + sin(tt + ii.y), sin(tt - ii.y) + cos(tt + ii.x));
    c += 1.0 / length(float2(cp.x / (sin(ii.x + tt) / inten), cp.y / (cos(ii.y + tt) / inten)));
}
c /= 3.0;
c = 1.17 - pow(c, 1.4);
float caus = clamp(pow(abs(c), 7.0), 0.0, 1.0);
col += float3(1.0, 0.98, 0.9) * caus * causticAmt * (1.0 - smoothstep(4.0, 26.0, r));

// —— 柔和菲涅尔：掠射角处映出天空色 ——
float3 V = normalize(-_surface.position);
float fres = pow(1.0 - clamp(dot(V, _surface.normal), 0.0, 1.0), 3.0);
col = mix(col, skyColor, clamp(fres * 0.85 + smoothstep(25.0, 140.0, camDist) * 0.35, 0.0, 0.9));

// —— 太阳闪光（细碎、柔和）——
float3 Vw = normalize((scn_frame.inverseViewTransform * float4(V, 0.0)).xyz);
float3 Rw = reflect(-Vw, nW);
float spec = pow(max(dot(Rw, normalize(sunDirW)), 0.0), 180.0);
float2 cell = floor(p * 3.0);
float h = fract(sin(dot(cell, float2(12.9898, 78.233))) * 43758.5453);
float tw = smoothstep(0.80, 1.0, sin(t * (1.5 + h * 2.5) + h * 40.0));
float spark = (step(0.86, h) * tw * smoothstep(0.55, 1.0, dot(Rw, normalize(sunDirW)) * 0.5 + 0.5)) * sparkleAmt;
col += float3(1.0, 0.97, 0.88) * (spec * 1.2 + spark * 0.9);

// —— 船体四周泡沫（柔和、随噪声起伏）——
float ell = length(lp / float2(4.9, 1.85));
float nz = sin(lp.x * 3.1 + t * 1.3) * sin(lp.y * 4.7 - t * 1.1) * 0.5 + sin(lp.x * 7.0 - t * 2.0) * 0.25;
float foam = (1.0 - smoothstep(0.98, 1.18, ell + nz * 0.06)) * smoothstep(0.80, 0.97, ell + nz * 0.04);
// —— 尾浪：船尾之后呈 V 形扩散，逐渐淡出 ——
float back = -lp.x - 4.2;
float spread = 0.7 + back * 0.22;
float wakeCore = (1.0 - smoothstep(spread * 0.35, spread, abs(lp.y))) * smoothstep(0.0, 1.5, back) * (1.0 - smoothstep(4.0, 24.0, back));
float wakeEdge = (1.0 - smoothstep(0.0, 0.35, abs(abs(lp.y) - spread))) * smoothstep(0.0, 2.0, back) * (1.0 - smoothstep(6.0, 30.0, back));
float streaks = 0.6 + 0.4 * sin(lp.y * 9.0 + sin(back * 1.3 - t * 2.0) * 1.5) * sin(back * 2.2 - t * 3.0);
float wake = clamp((wakeCore * 0.55 * streaks + wakeEdge * 0.8 * (0.7 + 0.3 * nz)) * wakeOn, 0.0, 1.0);
float fm = clamp(foam * (0.75 + 0.25 * nz) + wake, 0.0, 1.0);
col = mix(col, foamColor, fm * 0.85);

col *= mix(1.0, 0.55, nightAmt);
_surface.diffuse = float4(col * 0.30, 1.0);
_surface.emission = float4(col * 0.78, 1.0);
_surface.roughness = 0.18;
"""

    static func apply(to m: SCNMaterial) {
        m.lightingModel = .physicallyBased
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
