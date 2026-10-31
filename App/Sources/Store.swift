import StoreKit

/// StoreKit 2：一次性非消耗型内购「解锁完整版」
@MainActor
final class StoreManager: ObservableObject {
    /// TODO: 上架前在 App Store Connect 创建同名商品（与 FishingIdle.storekit 一致）
    static let fullVersionID = "com.example.fishingidle.fullversion"

    @Published private(set) var product: Product?
    @Published private(set) var busy = false
    private var updates: Task<Void, Never>?
    private let onEntitled: () -> Void

    init(onEntitled: @escaping () -> Void) {
        self.onEntitled = onEntitled
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await load(); await refreshEntitlements() }
    }

    deinit { updates?.cancel() }

    var priceText: String { product?.displayPrice ?? "—" }

    func load() async {
        product = try? await Product.products(for: [Self.fullVersionID]).first
    }

    /// 购买：成功返回 true
    func purchase() async -> Bool {
        if product == nil { await load() }
        guard let product else { return false }
        busy = true; defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let v):
                await handle(v)
                return (try? v.payloadValue) != nil
            default: return false
            }
        } catch { return false }
    }

    /// 恢复购买：同步 App Store 后重新检查权益
    func restore() async -> Bool {
        busy = true; defer { busy = false }
        try? await AppStore.sync()
        return await refreshEntitlements()
    }

    @discardableResult
    func refreshEntitlements() async -> Bool {
        var found = false
        for await r in Transaction.currentEntitlements {
            if case .verified(let t) = r, t.productID == Self.fullVersionID, t.revocationDate == nil {
                found = true
            }
        }
        if found { onEntitled() }
        return found
    }

    private func handle(_ r: VerificationResult<Transaction>) async {
        guard case .verified(let t) = r else { return }
        if t.productID == Self.fullVersionID, t.revocationDate == nil { onEntitled() }
        await t.finish()
    }
}
