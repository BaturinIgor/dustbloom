import Foundation

/// Rocks and dead trees on bought land (mirror of server/internal/game/obstacles.go).
struct ClearResult: Codable, Equatable {
    var kind: String
    var xp: Int
    var levelUp: Bool
    var items: [String: Int]?
}

extension Farm {
    /// "rock", "dead_tree" or nil. Fixed by a hash of the position, never
    /// within 5 tiles of the starting beds; cleared ones are gone for good.
    func obstacle(x: Int, y: Int, config: GameConfig) -> String? {
        guard x >= 0, y >= 0, x < width, y < height, !cleared.contains(y * width + x) else { return nil }
        return Farm.obstacleKind(x: x, y: y, start: config.farm.startTilled)
    }

    /// The layout rule alone (also used for the wasteland outside the farm).
    static func obstacleKind(x: Int, y: Int, start: GameConfig.Area) -> String? {
        let dx = max(start.x - x, 0, x - (start.x + start.width - 1))
        let dy = max(start.y - y, 0, y - (start.y + start.height - 1))
        guard max(dx, dy) >= 5 else { return nil }
        switch abs(x &* 31 &+ y &* 17) % 23 {
        case 0: return "dead_tree"
        case 7, 15: return "rock"
        default: return nil
        }
    }

    mutating func clear(x: Int, y: Int, config: GameConfig) throws -> ClearResult {
        guard index(x: x, y: y) != nil else { throw FarmError.outOfBounds }
        guard let kind = obstacle(x: x, y: y, config: config) else { throw FarmError.noObstacle }
        ensurePlots(config: config)
        guard owns(x: x, y: y, config: config) else { throw FarmError.notOwned }
        let o = config.obstacles?[kind] ?? GameConfig.Obstacle(coins: 0, xp: 0)
        guard coins >= o.coins else { throw FarmError.notEnoughCoins }
        coins -= o.coins
        cleared.append(y * width + x)
        let up = gainXP(o.xp, config: config)
        return ClearResult(kind: kind, xp: o.xp, levelUp: up.levelUp, items: up.items.isEmpty ? nil : up.items)
    }
}
