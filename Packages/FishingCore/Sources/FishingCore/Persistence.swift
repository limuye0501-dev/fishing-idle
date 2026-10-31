import Foundation

/// JSON 文件存档
public struct SaveStore: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public static func defaultStore() -> SaveStore {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return SaveStore(url: dir.appendingPathComponent("fishing_idle_save.json"))
    }

    public func save(_ state: GameState) throws {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        try enc.encode(state).write(to: url, options: .atomic)
    }

    public func load() -> GameState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        return try? dec.decode(GameState.self, from: data)
    }
}

/// v2 存档（单船）。首次启动时若存在 v1 存档则迁移
public struct VoyageStore: Sendable {
    public let url: URL
    public let legacy: SaveStore
    public init(url: URL, legacy: SaveStore) { self.url = url; self.legacy = legacy }
    public static func defaultStore() -> VoyageStore {
        let old = SaveStore.defaultStore()
        return VoyageStore(url: old.url.deletingLastPathComponent().appendingPathComponent("fishing_v2_save.json"), legacy: old)
    }
    public func save(_ s: VoyageState) throws {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        try enc.encode(s).write(to: url, options: .atomic)
    }
    /// (状态, 是否刚从旧存档迁移)
    public func load(now: Date = Date()) -> (VoyageState, Bool)? {
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        if let d = try? Data(contentsOf: url), let s = try? dec.decode(VoyageState.self, from: d) { return (s, false) }
        if let old = legacy.load() { return (VoyageState.migrate(old, now: now), true) }
        return nil
    }
}
