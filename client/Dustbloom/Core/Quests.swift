import Foundation

/// Quests (mirror of server/internal/game/quests.go). Goal is a counter in
/// `stats` ("harvest:dustwheat", "raid_win", ...) or a derived value:
/// "level", "manor", "plots", "army", "building:<id>".
struct Quest: Codable, Equatable, Identifiable {
    var id: String
    var goal: String
    var count: Int
    var unlockLevel: Int?
    var coins: Int
    var xp: Int
    var items: [String: Int]?
}

struct QuestConfig: Codable, Equatable {
    var active: Int
    var list: [Quest]
}

struct QuestResult: Codable, Equatable {
    var quest: String
    var coins: Int
    var xp: Int
    var levelUp: Bool
    var items: [String: Int]?
}

extension Farm {
    mutating func count(_ key: String, _ n: Int = 1) {
        stats[key, default: 0] += n
    }

    func questProgress(_ q: Quest, config: GameConfig) -> Int {
        let v: Int
        switch q.goal {
        case "level": v = level
        case "manor": v = manorLevel
        case "plots": v = plotsBought(config: config)
        case "army": v = army.count
        case let g where g.hasPrefix("building:"):
            v = buildingLevel(String(g.dropFirst("building:".count)), config: config)
        default: v = stats[q.goal, default: 0]
        }
        return min(v, q.count)
    }

    func activeQuests(config: GameConfig) -> [Quest] {
        guard let qc = config.quests else { return [] }
        var out: [Quest] = []
        for q in qc.list where out.count < qc.active {
            if questsDone.contains(q.id) || level < (q.unlockLevel ?? 0) { continue }
            out.append(q)
        }
        return out
    }

    /// Active quests whose reward can be taken now.
    func claimableQuests(config: GameConfig) -> Int {
        activeQuests(config: config).filter { questProgress($0, config: config) >= $0.count }.count
    }

    mutating func claimQuest(_ id: String, config: GameConfig) throws -> QuestResult {
        guard let q = activeQuests(config: config).first(where: { $0.id == id }) else { throw FarmError.unknownQuest }
        guard questProgress(q, config: config) >= q.count else { throw FarmError.questNotDone }
        questsDone.append(q.id)
        coins += q.coins
        grant(q.items ?? [:])
        let up = gainXP(q.xp, config: config)
        let all = (q.items ?? [:]).merging(up.items, uniquingKeysWith: +)
        return QuestResult(quest: q.id, coins: q.coins, xp: q.xp, levelUp: up.levelUp, items: all.isEmpty ? nil : all)
    }
}
