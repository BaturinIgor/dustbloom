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
}

struct Tile: Codable, Equatable {
    var tilled: Bool
    var crop: String?
    var plantedAt: Date?
}

/// A harvested crop goes to the barn; it is sold or built into scarecrows.
struct HarvestResult: Codable, Equatable {
    var crop: String
    var count: Int
    var xp: Int
    var levelUp: Bool
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

    private enum CodingKeys: String, CodingKey {
        case width, height, coins, xp, tiles, barn, army, queue, raidReadyAt
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

    mutating func till(x: Int, y: Int, config: GameConfig) throws {
        guard let i = index(x: x, y: y) else { throw FarmError.outOfBounds }
        guard !tiles[i].tilled else { throw FarmError.alreadyTilled }
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
    }

    mutating func harvest(x: Int, y: Int, now: Date, config: GameConfig) throws -> HarvestResult {
        guard let i = index(x: x, y: y) else { throw FarmError.outOfBounds }
        guard let cropID = tiles[i].crop, let plantedAt = tiles[i].plantedAt else { throw FarmError.empty }
        guard let crop = config.crop(cropID) else { throw FarmError.unknownCrop }
        guard Farm.progress(crop: crop, plantedAt: plantedAt, now: now) >= 1 else { throw FarmError.notReady }
        let before = level
        barn[cropID, default: 0] += 1
        xp += crop.xp
        tiles[i].crop = nil
        tiles[i].plantedAt = nil
        return HarvestResult(crop: cropID, count: 1, xp: crop.xp, levelUp: level > before)
    }

    /// Sells crops from the barn. Returns the coins earned.
    mutating func sell(cropID: String, count: Int, config: GameConfig) throws -> Int {
        guard let crop = config.crop(cropID) else { throw FarmError.unknownCrop }
        guard count > 0, barn[cropID, default: 0] >= count else { throw FarmError.notEnoughCrops }
        take(cropID, count)
        let earned = crop.sellPrice * count
        coins += earned
        return earned
    }

    mutating func take(_ cropID: String, _ count: Int) {
        let left = barn[cropID, default: 0] - count
        barn[cropID] = left > 0 ? left : nil
    }

    /// Growth from 0 to 1.
    static func progress(crop: GameConfig.Crop, plantedAt: Date, now: Date) -> Double {
        let elapsed = now.timeIntervalSince(plantedAt)
        guard elapsed > 0 else { return 0 }
        return min(1, elapsed / Double(crop.growSeconds))
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
