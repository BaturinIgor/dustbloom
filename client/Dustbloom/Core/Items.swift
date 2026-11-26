import Foundation

/// Mirror of server/internal/game/items.go: the storage (Склад) with
/// speedups and chests.
extension GameConfig {
    struct ItemsConfig: Codable, Equatable {
        var speedupTargets: [String]
        var speedupSeconds: [Int]
        var chests: [Chest]
        var startItems: [String: Int]
        var levelUp: [LevelUpReward]
    }

    struct LevelUpReward: Codable, Equatable {
        var every: Int
        var items: [String: Int]
    }

    struct Chest: Codable, Equatable, Identifiable {
        var id: String
        var name: [String: String]
        var rolls: Int
        var drops: [Drop]

        var localizedName: String { GameConfig.localized(name, fallback: id) }
    }

    struct Drop: Codable, Equatable {
        var item: String
        var min: Int
        var max: Int
        var weight: Int
    }

    struct Speedup: Equatable {
        var id: String
        var target: String
        var seconds: Int
    }

    static let coinsItem = "coins"

    static func speedupLabel(_ seconds: Int) -> String {
        seconds < 3600 ? "\(seconds / 60)m" : "\(seconds / 3600)h"
    }

    static func speedupID(target: String, seconds: Int) -> String {
        "speed_\(target)_\(speedupLabel(seconds))"
    }

    func speedup(_ id: String) -> Speedup? {
        for t in items.speedupTargets {
            for s in items.speedupSeconds where GameConfig.speedupID(target: t, seconds: s) == id {
                return Speedup(id: id, target: t, seconds: s)
            }
        }
        return nil
    }

    func chest(_ id: String) -> Chest? {
        items.chests.first { $0.id == id }
    }

    func isItem(_ id: String) -> Bool {
        speedup(id) != nil || chest(id) != nil
    }

    func levelUpItems(_ level: Int) -> [String: Int] {
        var out: [String: Int] = [:]
        for l in items.levelUp where l.every > 0 && level % l.every == 0 {
            for (id, n) in l.items { out[id, default: 0] += n }
        }
        return out
    }
}

/// What a speedup is used on.
struct SpeedTarget: Codable, Equatable {
    static let recruit = "recruit"
    static let grow = "grow"
    var kind: String
    var x: Int = 0
    var y: Int = 0
}

extension Farm {
    mutating func grant(_ give: [String: Int]) {
        for (id, n) in give {
            if id == GameConfig.coinsItem {
                coins += n
                continue
            }
            let left = items[id, default: 0] + n
            items[id] = left > 0 ? left : nil
        }
    }

    /// Adds XP and grants every level-up reward on the way.
    mutating func gainXP(_ amount: Int, config: GameConfig) -> (levelUp: Bool, items: [String: Int]) {
        let before = level
        xp += amount
        var got: [String: Int] = [:]
        if level > before {
            for l in (before + 1)...level {
                for (id, n) in config.levelUpItems(l) { got[id, default: 0] += n }
            }
        }
        grant(got)
        return (level > before, got)
    }

    /// Seconds the target still needs.
    func remaining(_ t: SpeedTarget, now: Date, config: GameConfig) throws -> Int {
        switch t.kind {
        case SpeedTarget.recruit:
            guard let last = queue.last else { throw FarmError.nothingToSpeedUp }
            return max(0, Int(last.readyAt.timeIntervalSince(now).rounded(.up)))
        case SpeedTarget.build:
            guard let ready = manorReadyAt ?? work?.readyAt else { throw FarmError.nothingToSpeedUp }
            return max(0, Int(ready.timeIntervalSince(now).rounded(.up)))
        case SpeedTarget.grow:
            guard let tl = tile(x: t.x, y: t.y) else { throw FarmError.outOfBounds }
            guard let id = tl.crop, let planted = tl.plantedAt else { throw FarmError.nothingToSpeedUp }
            guard let crop = config.crop(id) else { throw FarmError.unknownCrop }
            let left = TimeInterval(tl.growSeconds(crop)) - now.timeIntervalSince(planted)
            return max(0, Int(left.rounded(.up)))
        default:
            throw FarmError.unknownTarget
        }
    }

    @discardableResult
    mutating func useSpeedups(_ use: [String: Int], on t: SpeedTarget, now: Date, config: GameConfig) throws -> Int {
        settle(now: now, config: config)
        let left = try remaining(t, now: now, config: config)
        guard left > 0 else { throw FarmError.nothingToSpeedUp }
        var total = 0
        for (id, n) in use {
            guard let s = config.speedup(id) else {
                throw config.isItem(id) ? FarmError.notASpeedup : FarmError.unknownItem
            }
            guard s.target == "any" || s.target == t.kind else { throw FarmError.wrongTarget }
            guard n > 0, items[id, default: 0] >= n else { throw FarmError.notEnoughItems }
            total += s.seconds * n
        }
        guard total > 0 else { throw FarmError.notEnoughItems }
        for (id, n) in use { grant([id: -n]) }
        let d = TimeInterval(total)
        switch t.kind {
        case SpeedTarget.recruit:
            for i in queue.indices {
                queue[i].readyAt = max(now, queue[i].readyAt.addingTimeInterval(-d))
            }
            settle(now: now, config: config)
        case SpeedTarget.build:
            if let ready = manorReadyAt {
                manorReadyAt = max(now, ready.addingTimeInterval(-d))
            } else if let w = work {
                work?.readyAt = max(now, w.readyAt.addingTimeInterval(-d))
            }
            settle(now: now, config: config)
        default:
            if let i = index(x: t.x, y: t.y), let p = tiles[i].plantedAt {
                tiles[i].plantedAt = p.addingTimeInterval(-d)
            }
        }
        return min(total, left)
    }

    /// Same plan as the server: whole items that fit (largest first, own kind
    /// before "any"), then the smallest single item that covers the rest.
    func planSpeedups(for t: SpeedTarget, now: Date, config: GameConfig) throws -> [String: Int] {
        var left = try remaining(t, now: now, config: config)
        guard left > 0 else { throw FarmError.nothingToSpeedUp }
        struct Cand { var s: GameConfig.Speedup; var have: Int; var specific: Bool }
        var cs: [Cand] = items.compactMap { id, n in
            guard let s = config.speedup(id), n > 0, s.target == t.kind || s.target == "any" else { return nil }
            return Cand(s: s, have: n, specific: s.target == t.kind)
        }
        guard !cs.isEmpty else { throw FarmError.notEnoughItems }
        cs.sort {
            if $0.s.seconds != $1.s.seconds { return $0.s.seconds > $1.s.seconds }
            if $0.specific != $1.specific { return $0.specific }
            return $0.s.id < $1.s.id
        }
        var plan: [String: Int] = [:]
        for i in cs.indices {
            let k = min(cs[i].have, left / cs[i].s.seconds)
            if k > 0 {
                plan[cs[i].s.id, default: 0] += k
                cs[i].have -= k
                left -= k * cs[i].s.seconds
            }
        }
        if left > 0 {
            for i in cs.indices.reversed() where cs[i].have > 0 && cs[i].s.seconds >= left {
                var j = i
                while j > 0, cs[j - 1].s.seconds == cs[i].s.seconds, cs[j - 1].have > 0 { j -= 1 }
                plan[cs[j].s.id, default: 0] += 1
                break
            }
        }
        return plan
    }

    /// Offline chest opening; online the server rolls the loot.
    mutating func openChest(_ id: String, count: Int, config: GameConfig) throws -> [String: Int] {
        guard let ch = config.chest(id) else {
            throw config.isItem(id) ? FarmError.notAChest : FarmError.unknownItem
        }
        guard count > 0, items[id, default: 0] >= count else { throw FarmError.notEnoughItems }
        grant([id: -count])
        let total = ch.drops.reduce(0) { $0 + $1.weight }
        var got: [String: Int] = [:]
        for _ in 0..<(count * ch.rolls) {
            var pick = Int.random(in: 0..<max(1, total))
            for d in ch.drops {
                if pick < d.weight {
                    got[d.item, default: 0] += Int.random(in: d.min...d.max)
                    break
                }
                pick -= d.weight
            }
        }
        grant(got)
        return got
    }
}
