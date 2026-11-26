import Foundation

/// Error codes match the server's (server/internal/game/farm.go).
enum FarmError: String, Error, Codable {
    case outOfBounds = "out_of_bounds"
    case notTilled = "not_tilled"
    case alreadyTilled = "already_tilled"
    case occupied
    case empty
    case notReady = "not_ready"
    case unknownCrop = "unknown_crop"
    case notEnoughCoins = "not_enough_coins"
    case cropLocked = "crop_locked"
    case notEnoughCrops = "not_enough_crops"
    case unknownScarecrow = "unknown_scarecrow"
    case queueFull = "queue_full"
    case unknownRaid = "unknown_raid"
    case raidCooldown = "raid_cooldown"
    case noArmy = "no_army"
    case notOwned = "not_owned"
    case alreadyOwned = "already_owned"
    case notAdjacent = "not_adjacent"
    case noOrder = "no_order"
    case orderNotReady = "order_not_ready"
    case unknownItem = "unknown_item"
    case notEnoughItems = "not_enough_items"
    case wrongTarget = "wrong_target"
    case nothingToSpeedUp = "nothing_to_speed_up"
    case unknownTarget = "unknown_target"
    case notAChest = "not_a_chest"
    case notASpeedup = "not_a_speedup"
    case busy
    case maxLevel = "max_level"
    case unknownBuilding = "unknown_building"
    case manorTooLow = "manor_too_low"
    case obstacle
    case noObstacle = "no_obstacle"
}

struct Tile: Codable, Equatable {
    var tilled: Bool
    var crop: String?
    var plantedAt: Date?
    /// Growth time fixed at planting (with the well bonus); nil = the crop's own.
    var grow: Int?

    func growSeconds(_ crop: GameConfig.Crop) -> Int { grow ?? crop.growSeconds }
}

/// A harvested crop goes to the barn; it is sold or built into scarecrows.
struct HarvestResult: Codable, Equatable {
    var crop: String
    var count: Int
    var xp: Int
    var levelUp: Bool
    /// Level-up rewards put into the storage.
    var items: [String: Int]?
}

/// Mirror of the server farm rules. Offline play runs these locally;
/// online play runs them for instant feedback and then takes the server's state.
struct Farm: Codable, Equatable {
    var width: Int
    var height: Int
    var coins: Int
    var xp: Int
    var tiles: [Tile]
    /// Crop id -> count. Missing keys mean zero.
    var barn: [String: Int] = [:]
    var army: [ArmyUnit] = []
    var queue: [Build] = []
    var raidReadyAt: [String: Date] = [:]
    /// Owned land plots, row-major over the plot grid. Empty in old saves:
    /// `ensurePlots` fills in the start plots.
    var plots: [Bool] = []
    var orders: [Order] = []
    /// The storage (Склад): item id -> count.
    var items: [String: Int] = [:]
    /// Manor (Усадьба) level, 0 in old saves = 1, and its running upgrade.
    var manor: Int = 1
    var manorReadyAt: Date?
    /// Working building levels and the one under construction.
    var buildings: [String: Int] = [:]
    var work: Work?
    /// Tile indices whose rock or dead tree was cleared.
    var cleared: [Int] = []

    private enum CodingKeys: String, CodingKey {
        case width, height, coins, xp, tiles, barn, army, queue, raidReadyAt, plots, orders, items, manor, manorReadyAt, buildings, work, cleared
    }

    /// Older saves and the server's omitempty fields may lack the army keys.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        width = try c.decode(Int.self, forKey: .width)
        height = try c.decode(Int.self, forKey: .height)
        coins = try c.decode(Int.self, forKey: .coins)
        xp = try c.decode(Int.self, forKey: .xp)
        tiles = try c.decode([Tile].self, forKey: .tiles)
        barn = try c.decodeIfPresent([String: Int].self, forKey: .barn) ?? [:]
        army = try c.decodeIfPresent([ArmyUnit].self, forKey: .army) ?? []
        queue = try c.decodeIfPresent([Build].self, forKey: .queue) ?? []
        raidReadyAt = try c.decodeIfPresent([String: Date].self, forKey: .raidReadyAt) ?? [:]
        plots = try c.decodeIfPresent([Bool].self, forKey: .plots) ?? []
        orders = try c.decodeIfPresent([Order].self, forKey: .orders) ?? []
        items = try c.decodeIfPresent([String: Int].self, forKey: .items) ?? [:]
        manor = try c.decodeIfPresent(Int.self, forKey: .manor) ?? 1
        manorReadyAt = try c.decodeIfPresent(Date.self, forKey: .manorReadyAt)
        buildings = try c.decodeIfPresent([String: Int].self, forKey: .buildings) ?? [:]
        work = try c.decodeIfPresent(Work.self, forKey: .work)
        cleared = try c.decodeIfPresent([Int].self, forKey: .cleared) ?? []
    }

    init(config: GameConfig) {
        width = config.farm.width
        height = config.farm.height
        coins = config.farm.startCoins
        xp = 0
        var tiles: [Tile] = []
        tiles.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                tiles.append(Tile(tilled: config.farm.startTilled.contains(x: x, y: y)))
            }
        }
        self.tiles = tiles
        ensurePlots(config: config)
        grant(config.items.startItems)
    }

    /// Each level needs 10 more XP than the previous one.
    var level: Int {
        var level = 1, need = 10, rest = xp
        while rest >= need {
            rest -= need
            level += 1
            need += 10
        }
        return level
    }

    func index(x: Int, y: Int) -> Int? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        return y * width + x
    }

    func tile(x: Int, y: Int) -> Tile? {
        index(x: x, y: y).map { tiles[$0] }
    }

    // MARK: land plots (mirror of server/internal/game/farm.go)

    mutating func ensurePlots(config: GameConfig) {
        let n = config.farm.plotsX * config.farm.plotsY
        guard plots.count != n else { return }
        plots = Array(repeating: false, count: n)
        for p in config.farm.startPlots where p.count == 2 {
            plots[p[1] * config.farm.plotsX + p[0]] = true
        }
    }

    func owns(x: Int, y: Int, config: GameConfig) -> Bool {
        guard x >= 0, y >= 0, x < width, y < height else { return false }
        let ps = config.farm.plotSize
        let i = (y / ps) * config.farm.plotsX + x / ps
        return i < plots.count && plots[i]
    }

    func plotsBought(config: GameConfig) -> Int {
        plots.filter { $0 }.count - config.farm.startPlots.count
    }

    /// Coins and level needed for the next plot.
    func plotPrice(config: GameConfig) -> (coins: Int, level: Int) {
        let b = plotsBought(config: config)
        let coins = Int((Double(config.farm.plotBaseCost) * pow(config.farm.plotCostGrowth, Double(b))).rounded())
        return (coins, 1 + (b + 1) / max(1, config.farm.plotLevelStep))
    }

    func canBuyPlot(px: Int, py: Int, config: GameConfig) -> FarmError? {
        let w = config.farm.plotsX, h = config.farm.plotsY
        guard px >= 0, py >= 0, px < w, py < h, plots.count == w * h else { return .outOfBounds }
        if plots[py * w + px] { return .alreadyOwned }
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            let nx = px + dx, ny = py + dy
            if nx >= 0, ny >= 0, nx < w, ny < h, plots[ny * w + nx] { return nil }
        }
        return .notAdjacent
    }

    mutating func buyPlot(px: Int, py: Int, config: GameConfig) throws {
        ensurePlots(config: config)
        if let e = canBuyPlot(px: px, py: py, config: config) { throw e }
        let price = plotPrice(config: config)
        guard level >= price.level else { throw FarmError.cropLocked }
        guard coins >= price.coins else { throw FarmError.notEnoughCoins }
        coins -= price.coins
        plots[py * config.farm.plotsX + px] = true
    }

    mutating func till(x: Int, y: Int, config: GameConfig) throws {
        guard let i = index(x: x, y: y) else { throw FarmError.outOfBounds }
        guard !tiles[i].tilled else { throw FarmError.alreadyTilled }
        ensurePlots(config: config)
        guard owns(x: x, y: y, config: config) else { throw FarmError.notOwned }
        guard obstacle(x: x, y: y, config: config) == nil else { throw FarmError.obstacle }
        guard coins >= config.farm.tillCost else { throw FarmError.notEnoughCoins }
        coins -= config.farm.tillCost
        tiles[i].tilled = true
    }

    mutating func plant(x: Int, y: Int, cropID: String, now: Date, config: GameConfig) throws {
        guard let i = index(x: x, y: y) else { throw FarmError.outOfBounds }
        guard let crop = config.crop(cropID) else { throw FarmError.unknownCrop }
        guard level >= crop.unlockLevel else { throw FarmError.cropLocked }
        guard tiles[i].tilled else { throw FarmError.notTilled }
        guard tiles[i].crop == nil else { throw FarmError.occupied }
        guard coins >= crop.seedCost else { throw FarmError.notEnoughCoins }
        coins -= crop.seedCost
        tiles[i].crop = cropID
        tiles[i].plantedAt = now
        let g = faster(Effect.grow, crop.growSeconds, config: config)
        tiles[i].grow = g != crop.growSeconds ? g : nil
    }

    mutating func harvest(x: Int, y: Int, now: Date, config: GameConfig) throws -> HarvestResult {
        guard let i = index(x: x, y: y) else { throw FarmError.outOfBounds }
        guard let cropID = tiles[i].crop, let plantedAt = tiles[i].plantedAt else { throw FarmError.empty }
        guard let crop = config.crop(cropID) else { throw FarmError.unknownCrop }
        guard Farm.progress(seconds: tiles[i].growSeconds(crop), plantedAt: plantedAt, now: now) >= 1 else { throw FarmError.notReady }
        barn[cropID, default: 0] += 1
        let up = gainXP(crop.xp, config: config)
        tiles[i].crop = nil
        tiles[i].plantedAt = nil
        tiles[i].grow = nil
        return HarvestResult(crop: cropID, count: 1, xp: crop.xp, levelUp: up.levelUp, items: up.items.isEmpty ? nil : up.items)
    }

    /// Sells crops from the barn. Returns the coins earned.
    mutating func sell(cropID: String, count: Int, config: GameConfig) throws -> Int {
        guard let crop = config.crop(cropID) else { throw FarmError.unknownCrop }
        guard count > 0, barn[cropID, default: 0] >= count else { throw FarmError.notEnoughCrops }
        take(cropID, count)
        let earned = more(Effect.sell, crop.sellPrice * count, config: config)
        coins += earned
        return earned
    }

    mutating func take(_ cropID: String, _ count: Int) {
        let left = barn[cropID, default: 0] - count
        barn[cropID] = left > 0 ? left : nil
    }

    /// Growth from 0 to 1.
    static func progress(seconds: Int, plantedAt: Date, now: Date) -> Double {
        let elapsed = now.timeIntervalSince(plantedAt)
        guard elapsed > 0 else { return 0 }
        return min(1, elapsed / Double(max(1, seconds)))
    }

    /// Sprite stage 0...3: seed, sprout, growing, ripe.
    static func stage(progress: Double) -> Int {
        switch progress {
        case ..<0.15: return 0
        case ..<0.5: return 1
        case ..<1: return 2
        default: return 3
        }
    }
}
