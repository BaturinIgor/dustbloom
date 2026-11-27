import Foundation
import StoreKit

/// Everything sold for real money. IDs must match App Store Connect.
enum ShopProduct: String, CaseIterable, Identifiable {
    case founder = "bloom.founder"        // non-consumable
    case pass = "bloom.pass28"            // non-renewing, 28 days
    case jar = "bloom.jar"                // consumable, cracks the dew jar
    case starter = "bloom.starter"        // non-consumable, once
    case slot = "bloom.slot"              // non-consumable, +1 Bloomling
    case eventPass = "bloom.eventpass"    // consumable, premium track of this week's event
    case gemsS = "bloom.gems.80"
    case gemsM = "bloom.gems.450"
    case gemsL = "bloom.gems.1000"
    case gemsXL = "bloom.gems.2200"

    var id: String { rawValue }
    static let gemPacks: [ShopProduct] = [.gemsS, .gemsM, .gemsL, .gemsXL]

    var gems: Int {
        switch self {
        case .gemsS: return 80
        case .gemsM: return 450
        case .gemsL: return 1000
        case .gemsXL: return 2200
        default: return 0
        }
    }
    /// Shown until StoreKit returns the local price.
    var fallbackPrice: String {
        switch self {
        case .founder: return "4,99 $"
        case .pass: return "7,99 $"
        case .jar: return "2,99 $"
        case .starter: return "0,99 $"
        case .slot: return "1,99 $"
        case .eventPass: return "2,99 $"
        case .gemsS: return "0,99 $"
        case .gemsM: return "4,99 $"
        case .gemsL: return "9,99 $"
        case .gemsXL: return "19,99 $"
        }
    }
    var badge: String? {
        switch self {
        case .gemsM: return tr("Хит")
        case .gemsXL: return tr("Выгодно")
        default: return nil
        }
    }
}

/// StoreKit 2 wrapper. Until the products exist in App Store Connect, debug
/// builds grant purchases locally so the whole flow can be played and tested.
@MainActor
final class BloomStore: ObservableObject {
    static let shared = BloomStore()
    @Published private(set) var products: [String: Product] = [:]
    @Published var busy: ShopProduct?
    private var updates: Task<Void, Never>?
    weak var game: BloomGame?

    func start(game: BloomGame) {
        self.game = game
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await load() }
    }

    func load() async {
        guard let list = try? await Product.products(for: ShopProduct.allCases.map(\.rawValue)) else { return }
        products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }

    func price(_ p: ShopProduct) -> String { products[p.rawValue]?.displayPrice ?? p.fallbackPrice }

    func buy(_ p: ShopProduct) async {
        busy = p
        defer { busy = nil }
        Analytics.shared.track("bloom_purchase_start", ["product": p.rawValue, "level": game?.s.level ?? 0])
        guard let product = products[p.rawValue] else {
            #if DEBUG
            try? await Task.sleep(nanoseconds: 400_000_000)
            game?.grant(p)
            #else
            game?.showToast(BloomToast(title: tr("Магазин скоро откроется"), subtitle: tr("Покупки пока недоступны")))
            #endif
            return
        }
        guard let result = try? await product.purchase() else {
            Analytics.shared.track("bloom_purchase_fail", ["product": p.rawValue]); return
        }
        switch result {
        case .success(let v): await handle(v)
        case .userCancelled: Analytics.shared.track("bloom_purchase_cancel", ["product": p.rawValue])
        case .pending: Analytics.shared.track("bloom_purchase_pending", ["product": p.rawValue])
        @unknown default: break
        }
    }

    func restore() async {
        try? await AppStore.sync()
        for await r in Transaction.currentEntitlements {
            guard case .verified(let t) = r, let p = ShopProduct(rawValue: t.productID) else { continue }
            switch p {
            case .founder where game?.isFounder == false: game?.grant(.founder)
            case .starter where game?.starterBought == false: game?.grant(.starter)
            case .slot where game?.hasSlot == false: game?.grant(.slot)
            default: break
            }
        }
    }

    private func handle(_ r: VerificationResult<Transaction>) async {
        guard case .verified(let t) = r, let p = ShopProduct(rawValue: t.productID) else { return }
        if t.revocationDate == nil { game?.grant(p) }
        await t.finish()
    }
}
