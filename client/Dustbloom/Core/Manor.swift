import Foundation

/// Mirror of server/internal/game/manor.go: the Усадьба, the main building.
extension GameConfig {
    struct ManorConfig: Codable, Equatable {
        var maxLevel: Int
        var armySlotEvery: Int
        var levels: [ManorLevel]
    }

    /// Cost of one manor level; levels[i] goes from level i+1 to i+2.
    struct ManorLevel: Codable, Equatable {
        var coins: Int
        var crops: [String: Int]
        var seconds: Int
        var playerLevel: Int
    }
}

extension SpeedTarget {
    static let build = "build"
}

extension Farm {
    /// Old saves have no manor yet: they start at 1.
    var manorLevel: Int { max(1, manor) }

    /// One of six looks, changing every five levels.
    var manorTier: Int { min(5, (manorLevel - 1) / 5) }

    func nextManor(config: GameConfig) -> GameConfig.ManorLevel? {
        let l = manorLevel
        guard l < config.manor.maxLevel, l - 1 < config.manor.levels.count else { return nil }
        return config.manor.levels[l - 1]
    }

    mutating func settleManor(now: Date) {
        if let ready = manorReadyAt, ready <= now {
            manor = manorLevel + 1
            manorReadyAt = nil
        }
    }

    mutating func upgradeManor(now: Date, config: GameConfig) throws {
        settle(now: now, config: config)
        guard manorReadyAt == nil else { throw FarmError.busy }
        guard let next = nextManor(config: config) else { throw FarmError.maxLevel }
        guard level >= next.playerLevel else { throw FarmError.cropLocked }
        for (crop, n) in next.crops where barn[crop, default: 0] < n { throw FarmError.notEnoughCrops }
        guard coins >= next.coins else { throw FarmError.notEnoughCoins }
        for (crop, n) in next.crops { take(crop, n) }
        coins -= next.coins
        manor = manorLevel
        manorReadyAt = now.addingTimeInterval(TimeInterval(next.seconds))
    }
}
