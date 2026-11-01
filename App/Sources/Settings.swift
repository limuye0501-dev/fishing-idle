import SwiftUI
import Combine
import FishingCore

/// v8 设置：省电帧率、减少镜头晃动、辅助模式、iCloud 同步
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    /// 30 = 省电（默认），60，120
    @Published var fps: Int { didSet { d.set(fps, forKey: "fps") } }
    @Published var reduceCameraMotion: Bool { didSet { d.set(reduceCameraMotion, forKey: "reduceCameraMotion") } }
    @Published var assistMode: Bool { didSet { d.set(assistMode, forKey: "assistMode") } }
    @Published var iCloudSync: Bool { didSet { d.set(iCloudSync, forKey: "iCloudSync") } }

    private init() {
        d.register(defaults: ["fps": 30, "reduceCameraMotion": false, "assistMode": false, "iCloudSync": true])
        fps = d.integer(forKey: "fps")
        reduceCameraMotion = d.bool(forKey: "reduceCameraMotion")
        assistMode = d.bool(forKey: "assistMode")
        iCloudSync = d.bool(forKey: "iCloudSync")
    }

    /// 系统“减弱动态效果”也视为减少镜头晃动
    var cameraMotionReduced: Bool { reduceCameraMotion || UIAccessibility.isReduceMotionEnabled }
}

/// iCloud 键值存储同步（NSUbiquitousKeyValueStore，上限 1MB，存档约几十 KB）。
/// 需要在真实开发者 Team 下开启 iCloud Key-Value Storage 能力才会真正同步；
/// 没有权限时 API 静默无效，游戏照常本地存档。
final class CloudSave {
    static let shared = CloudSave()
    private let kv = NSUbiquitousKeyValueStore.default
    private let key = "voyage_save_v2"
    private var lastPush = Date.distantPast

    private init() { kv.synchronize() }

    func push(_ s: VoyageState, force: Bool = false) {
        guard force || Date().timeIntervalSince(lastPush) > 30 else { return }
        lastPush = Date()
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        guard let data = try? enc.encode(s), data.count < 900_000 else { return }
        kv.set(data, forKey: key)
        kv.synchronize()
    }

    func pull() -> VoyageState? {
        kv.synchronize()
        guard let data = kv.data(forKey: key) else { return nil }
        return try? SaveTransfer.importSave(data)
    }
}
