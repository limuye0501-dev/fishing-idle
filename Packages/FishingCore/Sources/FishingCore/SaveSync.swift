import Foundation

/// v8：存档导出/导入 + iCloud 同步的纯逻辑（平台无关，便于测试）
public enum SaveTransfer {
    public static let magic = "captain-dont-come-back-save"

    struct Envelope: Codable {
        var magic: String
        var exportedAt: Date
        var state: VoyageState
    }

    public enum TransferError: Error, Equatable { case notASave, corrupted }

    /// 导出为 JSON 数据（可分享为 .json 文件）
    public static func export(_ s: VoyageState, now: Date = Date()) throws -> Data {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(Envelope(magic: magic, exportedAt: now, state: s))
    }

    /// 导入：接受导出文件，也接受裸存档 JSON
    public static func importSave(_ data: Data) throws -> VoyageState {
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        if let e = try? dec.decode(Envelope.self, from: data) {
            guard e.magic == magic else { throw TransferError.notASave }
            return e.state
        }
        if let s = try? dec.decode(VoyageState.self, from: data) { return s }
        if (try? JSONSerialization.jsonObject(with: data)) != nil { throw TransferError.notASave }
        throw TransferError.corrupted
    }

    /// 进度评分：用于本地/云端冲突时挑“更远”的存档
    public static func progressScore(_ s: VoyageState) -> Double {
        Double(s.totalFishCaught) + Double(s.codex.count) * 50 + Double(s.level) * 100
            + Double(s.unlockedOceans.count) * 500 + (s.isFullVersion ? 1 : 0)
    }

    /// 冲突合并：进度明显更多的赢；否则较新的赢。完整版标记永远保留。
    public static func resolve(local: VoyageState, remote: VoyageState) -> VoyageState {
        let lp = progressScore(local), rp = progressScore(remote)
        var win: VoyageState
        if abs(lp - rp) > 1 { win = lp > rp ? local : remote }
        else { win = remote.lastUpdate > local.lastUpdate ? remote : local }
        win.isFullVersion = local.isFullVersion || remote.isFullVersion
        return win
    }
}

/// 收线小游戏参数（辅助模式加宽安全带）
public enum ReelConfig {
    /// 拉力安全区间（0…1）
    public static func safeBand(assist: Bool) -> ClosedRange<Double> { assist ? 0.22...0.88 : 0.35...0.75 }
    /// 断线阈值
    public static func snapAt(assist: Bool) -> Double { assist ? 1.0 : 1.0 }
    /// 辅助模式下拉力上升更慢
    public static func reelForce(assist: Bool) -> Double { assist ? 0.42 : 0.55 }
}
