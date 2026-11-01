import SwiftUI
import SceneKit
import FishingCore

/// 把 SceneKit 场景嵌入 SwiftUI
struct SeaSceneView: UIViewRepresentable {
    let state: VoyageState
    var photoMode = false
    var catHearts = 0
    var onCatTap: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        let ship = ShipScene()
        var onCatTap: () -> Void = {}
        var lastHearts = 0
        weak var view: SCNView?
        var photoMode = false
        var wasPhoto = false
        var base: (pos: SCNVector3, euler: SCNVector3, fov: CGFloat, sat: CGFloat, con: CGFloat, vig: CGFloat)?
        @objc func tap(_ g: UITapGestureRecognizer) {
            guard let v = view, ShipCatHook.hit(v, at: g.location(in: v)) else { return }
            onCatTap()
        }
        @objc func pan(_ g: UIPanGestureRecognizer) {
            guard photoMode, let v = view else { return }
            let pc = PhotoController.shared
            pc.yaw -= Double(g.translation(in: v).x) / 180
            pc.yaw = max(-1.4, min(1.4, pc.yaw))
            g.setTranslation(.zero, in: v)
        }
        @objc func pinch(_ g: UIPinchGestureRecognizer) {
            guard photoMode else { return }
            let pc = PhotoController.shared
            pc.zoom = max(0.6, min(1.8, pc.zoom / Double(g.scale))); g.scale = 1
        }
    }

    func makeUIView(context: Context) -> SCNView {
        let c = context.coordinator
        let v = SCNView()
        v.scene = c.ship.scene
        v.pointOfView = c.ship.cameraNode
        v.allowsCameraControl = false
        v.antialiasingMode = .multisampling4X
        v.backgroundColor = UIColor(red: 0.99, green: 0.85, blue: 0.78, alpha: 1)
        v.isPlaying = true
        v.preferredFramesPerSecond = AppSettings.shared.fps   // v8：默认 30fps 省电
        c.ship.view = v
        c.view = v
        ShipCatHook.install(in: c.ship.scene)
        v.addGestureRecognizer(UITapGestureRecognizer(target: c, action: #selector(Coordinator.tap(_:))))
        v.addGestureRecognizer(UIPanGestureRecognizer(target: c, action: #selector(Coordinator.pan(_:))))
        v.addGestureRecognizer(UIPinchGestureRecognizer(target: c, action: #selector(Coordinator.pinch(_:))))
        PhotoController.shared.view = v
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let c = context.coordinator
        c.ship.sync(state: state, now: Date())
        c.onCatTap = onCatTap
        c.photoMode = photoMode
        if catHearts != c.lastHearts { c.lastHearts = catHearts; ShipCatHook.hearts(in: c.ship.scene) }
        let s = AppSettings.shared
        if uiView.preferredFramesPerSecond != s.fps { uiView.preferredFramesPerSecond = s.fps }
        applyCameraSwell(c.ship.cameraNode, enabled: !s.cameraMotionReduced && !photoMode)
        applyPhoto(c.ship.cameraNode, c)
        AmbientAudio.shared.update(state: state, now: Date())
    }

    /// 拍照模式：绕原点旋转镜头、缩放 FOV、滤镜（SCNCamera 后期参数）。离开时恢复原值
    private func applyPhoto(_ cam: SCNNode, _ c: Coordinator) {
        let pc = PhotoController.shared
        guard let camera = cam.camera else { return }
        guard photoMode || c.wasPhoto else { return }
        if c.base == nil { c.base = (cam.position, cam.eulerAngles, camera.fieldOfView, camera.saturation, camera.contrast, camera.vignettingIntensity) }
        guard let b = c.base else { return }
        if !photoMode {
            cam.position = b.pos; cam.eulerAngles = b.euler; camera.fieldOfView = b.fov
            camera.saturation = b.sat; camera.contrast = b.con; camera.vignettingIntensity = b.vig; camera.colorFringeStrength = 0
            c.wasPhoto = false; c.base = nil; return
        }
        c.wasPhoto = true
        let yaw = pc.yaw
        let r = Double(sqrt(b.pos.x * b.pos.x + b.pos.z * b.pos.z)) * pc.zoom.squareRoot()
        let a0 = atan2(Double(b.pos.x), Double(b.pos.z))
        cam.position = SCNVector3(Float(r * sin(a0 + yaw)), b.pos.y, Float(r * cos(a0 + yaw)))
        cam.eulerAngles = SCNVector3(b.euler.x, b.euler.y + Float(yaw), b.euler.z)
        camera.fieldOfView = b.fov * CGFloat(pc.zoom)
        camera.saturation = b.sat; camera.contrast = b.con; camera.vignettingIntensity = b.vig; camera.colorFringeStrength = 0
        switch pc.filter {
        case .original: break
        case .warm: camera.saturation = b.sat * 1.15; camera.contrast = b.con + 0.05; camera.vignettingIntensity = 0.5
        case .vivid: camera.saturation = b.sat * 1.45; camera.contrast = b.con + 0.2
        case .mono: camera.saturation = 0; camera.contrast = b.con + 0.25; camera.vignettingIntensity = 0.7
        case .dream: camera.saturation = b.sat * 0.8; camera.contrast = b.con - 0.15; camera.vignettingIntensity = 0.9; camera.colorFringeStrength = 1.5
        }
    }

    /// 轻微“随浪”镜头；“减少镜头晃动”打开时完全静止
    private func applyCameraSwell(_ cam: SCNNode, enabled: Bool) {
        let key = "v8swell"
        if enabled, cam.action(forKey: key) == nil {
            let up = SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 2.6); up.timingMode = .easeInEaseOut
            cam.runAction(.repeatForever(.sequence([up, up.reversed()])), forKey: key)
        } else if !enabled, cam.action(forKey: key) != nil {
            cam.removeAction(forKey: key)
        }
    }
}
