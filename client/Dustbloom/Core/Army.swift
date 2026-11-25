import Foundation

/// One scarecrow in the army.
struct ArmyUnit: Codable, Equatable {
    var type: String
}

/// A scarecrow in the workshop.
struct Build: Codable, Equatable {
    var type: String
    var readyAt: Date
}

/// One blow in a raid, replayed by the battle scene.
struct Hit: Codable, Equatable {
    var round: Int
    var fromArmy: Bool
    var from: Int
    var to: Int
    var damage: Int
    var kill: Bool
}

struct RaidResult: Codable, Equatable {
    var raid: String
    var won: Bool
    var lost: [Int]?
    var coins: Int
    var xp: Int
    var levelUp: Bool
    var hits: [Hit]?
}

/// Mirror of server/internal/game/army.go. Offline play runs it locally;
/// online the server simulates the fight and the client only replays it.
extension Farm {
    func armySlots(config: GameConfig) -> Int {
        let n = config.army.baseSlots + config.army.slotsPerLevel * (level - 1)
        return config.army.maxSlots > 0 ? min(n, config.army.maxSlots) : n
    }

    /// Moves finished scarecrows into the army while there is room.
    mutating func settle(now: Date, config: GameConfig) {
        while let first = queue.first, first.readyAt <= now, army.count < armySlots(config: config) {
            army.append(ArmyUnit(type: first.type))
            queue.removeFirst()
        }
    }

    mutating func buildScarecrow(_ id: String, now: Date, config: GameConfig) throws {
        settle(now: now, config: config)
        guard let sc = config.scarecrow(id) else { throw FarmError.unknownScarecrow }
        guard level >= sc.unlockLevel else { throw FarmError.cropLocked }
        guard queue.count < config.army.queueSize,
              army.count + queue.count < armySlots(config: config) else { throw FarmError.queueFull }
        for (crop, n) in sc.cost where barn[crop, default: 0] < n { throw FarmError.notEnoughCrops }
        guard coins >= sc.coins else { throw FarmError.notEnoughCoins }
        for (crop, n) in sc.cost { take(crop, n) }
        coins -= sc.coins
        let start = max(now, queue.last?.readyAt ?? now)
        queue.append(Build(type: id, readyAt: start.addingTimeInterval(TimeInterval(sc.buildSeconds))))
    }

    /// Same battle rules as the server: every living fighter strikes the
    /// front of the other side, scarecrows first, damage +-20%.
    mutating func raid(_ raidID: String, now: Date, config: GameConfig) throws -> RaidResult {
        var rng = SystemRandomNumberGenerator()
        return try raid(raidID, now: now, config: config, using: &rng)
    }

    mutating func raid<G: RandomNumberGenerator>(_ raidID: String, now: Date, config: GameConfig, using rng: inout G) throws -> RaidResult {
        settle(now: now, config: config)
        guard let raid = config.raid(raidID) else { throw FarmError.unknownRaid }
        guard level >= raid.unlockLevel else { throw FarmError.cropLocked }
        if let ready = raidReadyAt[raidID], now < ready { throw FarmError.raidCooldown }
        guard !army.isEmpty else { throw FarmError.noArmy }

        var ours = army.map { u -> (hp: Int, atk: Int) in
            let sc = config.scarecrow(u.type)
            return (sc?.hp ?? 1, sc?.attack ?? 1)
        }
        var theirs = raid.enemies.map { (hp: $0.hp, atk: $0.attack) }
        func front(_ side: [(hp: Int, atk: Int)]) -> Int? { side.firstIndex { $0.hp > 0 } }

        var hits: [Hit] = []
        var round = 1
        while round <= 30, front(ours) != nil, front(theirs) != nil {
            for armySide in [true, false] {
                let attackers = armySide ? ours : theirs
                for (i, a) in attackers.enumerated() where a.hp > 0 {
                    // an attacker killed earlier this round has hp <= 0 in the live array
                    if (armySide ? ours[i].hp : theirs[i].hp) <= 0 { continue }
                    guard let t = armySide ? front(theirs) : front(ours) else { break }
                    let dmg = max(1, Int((Double(a.atk) * Double.random(in: 0.8..<1.2, using: &rng)).rounded()))
                    if armySide { theirs[t].hp -= dmg } else { ours[t].hp -= dmg }
                    let kill = (armySide ? theirs[t].hp : ours[t].hp) <= 0
                    hits.append(Hit(round: round, fromArmy: armySide, from: i, to: t, damage: dmg, kill: kill))
                }
            }
            round += 1
        }
        let won = front(theirs) == nil
        let lost = ours.indices.filter { ours[$0].hp <= 0 }
        army = army.indices.filter { ours[$0].hp > 0 }.map { army[$0] }

        var result = RaidResult(raid: raidID, won: won, lost: lost, coins: 0, xp: 0, levelUp: false, hits: hits)
        if won {
            let before = level
            coins += raid.rewardCoins
            xp += raid.rewardXp
            result.coins = raid.rewardCoins
            result.xp = raid.rewardXp
            result.levelUp = level > before
            raidReadyAt[raidID] = now.addingTimeInterval(TimeInterval(raid.cooldownSeconds))
        }
        settle(now: now, config: config)
        return result
    }
}
