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
        v.preferredFramesPerSecond = 60
        context.coordinator.view = v
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.sync(state: state, now: Date())
    }
}
