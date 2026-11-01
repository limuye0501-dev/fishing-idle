import SwiftUI
import SceneKit
import FishingCore

/// 把 SceneKit 场景嵌入 SwiftUI
struct SeaSceneView: UIViewRepresentable {
    let state: VoyageState

    func makeCoordinator() -> ShipScene { ShipScene() }

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = context.coordinator.scene
        v.pointOfView = context.coordinator.cameraNode
        v.allowsCameraControl = false
        v.antialiasingMode = .multisampling4X
        v.backgroundColor = UIColor(red: 0.99, green: 0.85, blue: 0.78, alpha: 1)
        v.isPlaying = true
        v.preferredFramesPerSecond = AppSettings.shared.fps   // v8：默认 30fps 省电
        context.coordinator.view = v
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.sync(state: state, now: Date())
        let s = AppSettings.shared
        if uiView.preferredFramesPerSecond != s.fps { uiView.preferredFramesPerSecond = s.fps }
        applyCameraSwell(context.coordinator.cameraNode, enabled: !s.cameraMotionReduced)
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
