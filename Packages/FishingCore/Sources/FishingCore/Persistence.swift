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
