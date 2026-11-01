import SwiftUI
import SceneKit
import Photos
import FishingCore

/// v9 拍照模式：隐藏 UI、拖动绕船旋转、双指缩放、滤镜、保存到相册
final class PhotoController: ObservableObject {
    static let shared = PhotoController()
    enum Filter: String, CaseIterable, Identifiable {
        case original, warm, vivid, mono, dream
        var id: String { rawValue }
        var name: String {
            switch self {
            case .original: tr("原图", "Original"); case .warm: tr("暖阳", "Warm"); case .vivid: tr("鲜艳", "Vivid")
            case .mono: tr("黑白", "Mono"); case .dream: tr("梦境", "Dream")
            }
        }
    }
    @Published var filter: Filter = .original
    @Published var yaw: Double = 0        // 绕船旋转（弧度）
    @Published var zoom: Double = 1       // 0.6…1.8
    weak var view: SCNView?

    func snapshot() -> UIImage? { view?.snapshot() }
}

enum PhotoSaver {
    static func save(_ img: UIImage, done: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { st in
            guard st == .authorized || st == .limited else { DispatchQueue.main.async { done(false) }; return }
            PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.creationRequestForAsset(from: img) }) { ok, _ in
                DispatchQueue.main.async { done(ok) }
            }
        }
    }
}

struct PhotoModeOverlay: View {
    @EnvironmentObject var game: GameViewModel
    @ObservedObject var pc = PhotoController.shared
    @State private var flash = false
    @State private var lastShot: UIImage?

    var body: some View {
        VStack {
            HStack {
                Button { withAnimation { game.photoMode = false; pc.yaw = 0; pc.zoom = 1; pc.filter = .original } } label: {
                    Image(systemName: "xmark").font(.headline).padding(12).background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel(tr("退出拍照模式", "Exit photo mode"))
                Spacer()
                Text(tr("拖动旋转 · 双指缩放", "Drag to orbit · pinch to zoom")).font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 6).background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.horizontal)
            Spacer()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PhotoController.Filter.allCases) { f in
                        Button(f.name) { pc.filter = f }
                            .font(.system(.subheadline, design: .rounded).bold())
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(pc.filter == f ? Theme.coral : Color.white.opacity(0.7), in: Capsule())
                            .foregroundStyle(pc.filter == f ? .white : Theme.ink)
                    }
                }
                .padding(.horizontal)
            }
            HStack(spacing: 24) {
                if let img = lastShot {
                    ShareLink(item: Image(uiImage: img), preview: SharePreview(game.state.shipName, image: Image(uiImage: img))) {
                        Image(uiImage: img).resizable().scaledToFill().frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else { Color.clear.frame(width: 52, height: 52) }
                Button(action: shoot) {
                    Circle().fill(.white).frame(width: 72, height: 72).overlay(Circle().stroke(Theme.coral, lineWidth: 4).padding(4))
                }
                .accessibilityLabel(tr("拍照并保存到相册", "Take photo and save to Photos"))
                Color.clear.frame(width: 52, height: 52)
            }
            .padding(.bottom, 30)
        }
        .overlay(Color.white.opacity(flash ? 0.8 : 0).allowsHitTesting(false).ignoresSafeArea())
    }

    private func shoot() {
        guard let img = pc.snapshot() else { return }
        AudioManager.shared.play(.shutter); AudioManager.shared.haptic(.medium)
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        withAnimation(.easeIn(duration: 0.35).delay(0.08)) { flash = false }
        lastShot = img
        PhotoSaver.save(img) { ok in game.toast = ok ? tr("已保存到相册", "Saved to Photos") : tr("没有相册权限，可以点左下角分享", "No Photos access — use Share instead") }
    }
}
