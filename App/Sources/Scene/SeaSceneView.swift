import SwiftUI
import SceneKit
import FishingCore

/// 把 SceneKit 场景嵌入 SwiftUI；每次状态变化时同步船只位置
struct SeaSceneView: UIViewRepresentable {
    let state: GameState
    let config: EconomyConfig

    func makeCoordinator() -> OceanScene { OceanScene() }

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = context.coordinator.scene
        v.pointOfView = context.coordinator.cameraNode
        v.allowsCameraControl = false
        v.antialiasingMode = .multisampling4X
        v.backgroundColor = UIColor(red: 0.55, green: 0.82, blue: 0.95, alpha: 1)
        v.isPlaying = true
        v.preferredFramesPerSecond = 60
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.sync(state: state, config: config)
    }
}
