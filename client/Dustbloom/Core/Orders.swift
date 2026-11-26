import Foundation

/// Mirror of server/internal/game/orders.go: an order board of crop requests
/// that pay better than selling.
struct Order: Codable, Equatable {
    var items: [String: Int]
    var coins: Int
    var xp: Int
    var readyAt: Date?
}

struct OrderResult: Codable, Equatable {
    var coins: Int
    var xp: Int
    var levelUp: Bool
}

extension GameConfig {
    struct OrderConfig: Codable, Equatable {
        var slots: Int
        var rewardFactor: Double
        var xpPerCoin: Double
        var skipSeconds: Int
        var maxItemTypes: Int
        var baseCount: Int
        var countPerLevel: Double
    }
}

extension Farm {
    mutating func fillOrders(now: Date, config: GameConfig) {
        var rng = SystemRandomNumberGenerator()
        while orders.count < config.orders.slots { orders.append(newOrder(config: config, using: &rng)) }
        for i in orders.indices {
            if let r = orders[i].readyAt, r <= now { orders[i] = newOrder(config: config, using: &rng) }
        }
    }

    func newOrder<G: RandomNumberGenerator>(config: GameConfig, using rng: inout G) -> Order {
        let pool = config.crops.filter { $0.unlockLevel <= level }.shuffled(using: &rng)
        let types = Int.random(in: 1...max(1, min(config.orders.maxItemTypes, pool.count)), using: &rng)
        var order = Order(items: [:], coins: 0, xp: 0, readyAt: nil)
        var value = 0
        for c in pool.prefix(types) {
            let base = Double(config.orders.baseCount) * 30 / Double(c.growSeconds)
            let scale = 1 + config.orders.countPerLevel * Double(level - 1)
            let n = max(1, Int((base * scale * Double.random(in: 0.7..<1.3, using: &rng)).rounded()))
            order.items[c.id] = n
            value += n * c.sellPrice
        }
        order.coins = Int((Double(value) * config.orders.rewardFactor).rounded())
        order.xp = max(1, Int((Double(order.coins) * config.orders.xpPerCoin).rounded()))
        return order
    }

    func canDeliver(_ i: Int) -> Bool {
        guard orders.indices.contains(i), orders[i].readyAt == nil else { return false }
        return orders[i].items.allSatisfy { barn[$0.key, default: 0] >= $0.value }
    }

    mutating func deliverOrder(_ i: Int, now: Date, config: GameConfig) throws -> OrderResult {
        guard orders.indices.contains(i) else { throw FarmError.noOrder }
        guard orders[i].readyAt == nil else { throw FarmError.orderNotReady }
        guard canDeliver(i) else { throw FarmError.notEnoughCrops }
        let o = orders[i]
        for (k, n) in o.items { take(k, n) }
        let before = level
        coins += o.coins
        xp += o.xp
        var rng = SystemRandomNumberGenerator()
        orders[i] = newOrder(config: config, using: &rng)
        return OrderResult(coins: o.coins, xp: o.xp, levelUp: level > before)
    }

    mutating func skipOrder(_ i: Int, now: Date, config: GameConfig) throws {
        guard orders.indices.contains(i) else { throw FarmError.noOrder }
        guard orders[i].readyAt == nil else { throw FarmError.orderNotReady }
        orders[i] = Order(items: [:], coins: 0, xp: 0, readyAt: now.addingTimeInterval(TimeInterval(config.orders.skipSeconds)))
    }
}
