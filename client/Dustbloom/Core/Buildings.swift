import Foundation

/// Mirror of server/internal/game/buildings.go: the working buildings.
/// A building's level never passes the manor's, and the manor and the
/// buildings share one builder.
extension GameConfig {
    struct BuildingsConfig: Codable, Equatable {
        var list: [BuildingType]
    }

    struct BuildingType: Codable, Equatable, Identifiable {
        var id: String
        var name: [String: String]
        var effect: String
        var perLevel: Double
        var cap: Double
        var unlockManor: Int
        var startLevel: Int
        /// levels[i] is the cost of reaching level i + 1.
        var levels: [BuildLevel]

        var localizedName: String { GameConfig.localized(name, fallback: id) }
        var maxLevel: Int { levels.count }

        /// Bonus percent at a level, capped.
        func bonus(at level: Int) -> Double {
            let v = perLevel * Double(level)
            return cap > 0 ? min(v, cap) : v
        }
    }

    struct BuildLevel: Codable, Equatable {
        var coins: Int
        var crops: [String: Int]?
        var seconds: Int
        var power: Int
    }

    func building(_ id: String) -> BuildingType? {
        buildings.list.first { $0.id == id }
    }
}

enum Effect {
    static let grow = "grow"
    static let sell = "sell"
    static let buildTime = "build_time"
    static let armyPower = "army_power"
    static let orderReward = "order_reward"
    static let raidCooldown = "raid_cooldown"
}

/// The building under construction.
struct Work: Codable, Equatable {
    var building: String
    var readyAt: Date
}

extension Farm {
    func buildingLevel(_ id: String, config: GameConfig) -> Int {
        buildings[id] ?? config.building(id)?.startLevel ?? 0
    }

    func bonus(_ effect: String, config: GameConfig) -> Double {
        config.buildings.list.filter { $0.effect == effect }
            .reduce(0) { $0 + $1.bonus(at: buildingLevel($1.id, config: config)) }
    }

    /// Same rounding as the server: shorter time, never below 1 s.
    func faster(_ effect: String, _ seconds: Int, config: GameConfig) -> Int {
        let p = bonus(effect, config: config)
        guard p > 0 else { return seconds }
        return max(1, Int(Double(seconds) * (100 - p) / 100 + 0.5))
    }

    func more(_ effect: String, _ n: Int, config: GameConfig) -> Int {
        let p = bonus(effect, config: config)
        guard p > 0 else { return n }
        return Int(Double(n) * (100 + p) / 100 + 0.5)
    }

    /// The builder is working on the manor or a building.
    var busy: Bool { manorReadyAt != nil || work != nil }

    func nextBuilding(_ id: String, config: GameConfig) -> GameConfig.BuildLevel? {
        guard let b = config.building(id) else { return nil }
        let l = buildingLevel(id, config: config)
        return l < b.levels.count ? b.levels[l] : nil
    }

    mutating func settleBuildings(config: GameConfig, now: Date) {
        if let w = work, w.readyAt <= now {
            buildings[w.building] = buildingLevel(w.building, config: config) + 1
            work = nil
        }
    }

    mutating func upgradeBuilding(_ id: String, now: Date, config: GameConfig) throws {
        settle(now: now, config: config)
        guard let b = config.building(id) else { throw FarmError.unknownBuilding }
        guard !busy else { throw FarmError.busy }
        guard let next = nextBuilding(id, config: config) else { throw FarmError.maxLevel }
        guard manorLevel >= b.unlockManor, buildingLevel(id, config: config) + 1 <= manorLevel else {
            throw FarmError.manorTooLow
        }
        let crops = next.crops ?? [:]
        for (crop, n) in crops where barn[crop, default: 0] < n { throw FarmError.notEnoughCrops }
        guard coins >= next.coins else { throw FarmError.notEnoughCoins }
        for (crop, n) in crops { take(crop, n) }
        coins -= next.coins
        work = Work(building: id, readyAt: now.addingTimeInterval(TimeInterval(next.seconds)))
    }

    /// Мощь from the manor and the buildings, same sum as the server.
    func power(config: GameConfig) -> Int {
        var p = config.manor.startPower
        for i in 0..<min(manorLevel - 1, config.manor.levels.count) { p += config.manor.levels[i].power }
        for b in config.buildings.list {
            for i in 0..<min(buildingLevel(b.id, config: config), b.levels.count) { p += b.levels[i].power }
        }
        return p
    }
}
