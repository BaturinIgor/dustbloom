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
}

struct Tile: Codable, Equatable {
    var tilled: Bool
    var crop: String?
    var plantedAt: Date?
}

struct HarvestResult: Codable, Equatable {
    var crop: String
    var coins: Int
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
        coins += crop.sellPrice
        xp += crop.xp
        tiles[i].crop = nil
        tiles[i].plantedAt = nil
        return HarvestResult(crop: cropID, coins: crop.sellPrice, xp: crop.xp, levelUp: level > before)
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
