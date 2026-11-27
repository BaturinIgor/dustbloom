import Foundation
import StoreKit

/// Everything sold for real money. IDs must match App Store Connect.
enum ShopProduct: String, CaseIterable, Identifiable {
    case founder = "bloom.founder"        // non-consumable
    case pass = "bloom.pass28"            // non-renewing, 28 days
    case jar = "bloom.jar"                // consumable, cracks the dew jar
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
        case .gemsS: return "0,99 $"
        case .gemsM: return "4,99 $"
        case .gemsL: return "9,99 $"
        case .gemsXL: return "19,99 $"
        }
    }
    var badge: String? {
        switch self {
        case .gemsM: return "Хит"
        case .gemsXL: return "Выгодно"
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
        guard let product = products[p.rawValue] else {
            #if DEBUG
            try? await Task.sleep(nanoseconds: 400_000_000)
            game?.grant(p)
            #else
            game?.showToast(BloomToast(title: "Магазин скоро откроется", subtitle: "Покупки пока недоступны"))
            #endif
            return
        }
        guard let result = try? await product.purchase() else { return }
        if case .success(let v) = result { await handle(v) }
    }

    func restore() async {
        try? await AppStore.sync()
        for await r in Transaction.currentEntitlements {
            if case .verified(let t) = r, t.productID == ShopProduct.founder.rawValue, game?.isFounder == false {
                game?.grant(.founder)
            }
        }
    }

    private func handle(_ r: VerificationResult<Transaction>) async {
        guard case .verified(let t) = r, let p = ShopProduct(rawValue: t.productID) else { return }
        if t.revocationDate == nil { game?.grant(p) }
        await t.finish()
    }
}

/// Rewarded video. AdMob goes in here; until then debug builds reward right away.
@MainActor
enum RewardedAds {
    static var isAvailable: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static func show(_ done: @escaping (Bool) -> Void) {
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { done(true) }
        #else
        done(false)
        #endif
    }
}
