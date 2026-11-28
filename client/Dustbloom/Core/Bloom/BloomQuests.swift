import Foundation

/// Islanders: one on each of the first ten islands, each with a chain of three asks.
/// Finishing a chain makes them a friend who hands over a small gift once a day.
struct QuestStep {
    let line: String
    var items: [(BItem, Int)] = []
    var build: BuildKind?
}

struct Islander: Identifiable {
    let id: String
    let island: Int
    let name: String
    let steps: [QuestStep]
    let gift: [(BItem, Int)]
}

/// A floor puzzle on one island. All three kinds are played by stepping on tiles:
/// plates: light every plate before the time runs out;
/// runes: the tiles flash an order, step on them in that order;
/// lanterns: a step flips a lantern and its neighbours, light them all.
struct FloorPuzzle: Identifiable {
    enum Kind: String { case plates, runes, lanterns }
    let id: String
    let island: Int
    let kind: Kind
    /// plates and lanterns: how many tiles; runes: how long the order is.
    let size: Int
    var seconds: Double = 0
}

enum BloomQuests {
    static let islanders: [Islander] = [
        Islander(id: "olha", island: 0, name: "Бабушка Ольха", steps: [
            QuestStep(line: "Принеси дров на зиму, дружок.", items: [(.wood, 15)]),
            QuestStep(line: "Ягодок бы к чаю!", items: [(.berry, 12)]),
            QuestStep(line: "Поставь печь, буду печь пироги.", build: .furnace),
        ], gift: [(.berry, 6), (.wood, 6)]),
        Islander(id: "bor", island: 1, name: "Лесник Бор", steps: [
            QuestStep(line: "Хлопок нужен на тёплые варежки.", items: [(.cotton, 12)]),
            QuestStep(line: "Брёвна на новую сторожку.", items: [(.wood, 40)]),
            QuestStep(line: "Сотки мне ткани на плащ.", items: [(.cloth, 6)]),
        ], gift: [(.wood, 10), (.cotton, 4)]),
        Islander(id: "grom", island: 2, name: "Кузнец Гром", steps: [
            QuestStep(line: "Неси руду, горн совсем остыл.", items: [(.iron_ore, 15)]),
            QuestStep(line: "Кирпичи на новый горн.", items: [(.brick, 12)]),
            QuestStep(line: "Пять слитков, и мы друзья.", items: [(.iron_bar, 5)]),
        ], gift: [(.iron_ore, 6), (.stone, 8)]),
        Islander(id: "tosya", island: 3, name: "Сластёна Тося", steps: [
            QuestStep(line: "Ягод! Много-много ягод!", items: [(.berry, 25)]),
            QuestStep(line: "Хлопок для моих кукол.", items: [(.cotton, 20)]),
            QuestStep(line: "Построй рынок, я буду торговать!", build: .market),
        ], gift: [(.berry, 10), (.cotton, 4)]),
        Islander(id: "zlat", island: 4, name: "Старатель Злат", steps: [
            QuestStep(line: "Золотая руда, вот что мне снится.", items: [(.gold_ore, 10)]),
            QuestStep(line: "Переплавь её в слитки.", items: [(.gold_bar, 4)]),
            QuestStep(line: "Ещё слитков и кирпичей на сейф.", items: [(.gold_bar, 8), (.brick, 10)]),
        ], gift: [(.gold_ore, 4), (.stone, 10)]),
        Islander(id: "inei", island: 5, name: "Сказочница Иней", steps: [
            QuestStep(line: "Кристаллы светятся, как сказки.", items: [(.crystal, 6)]),
            QuestStep(line: "Железо на рамку для зеркала.", items: [(.iron_bar, 8)]),
            QuestStep(line: "Ещё кристаллов и немного золота.", items: [(.crystal, 12), (.gold_bar, 3)]),
        ], gift: [(.crystal, 2), (.iron_ore, 4)]),
        Islander(id: "yan", island: 6, name: "Стеклодув Ян", steps: [
            QuestStep(line: "Песка, да побольше!", items: [(.sand, 30)]),
            QuestStep(line: "Стекло для моей мастерской.", items: [(.glass, 10)]),
            QuestStep(line: "Построй коптильню, угощу рыбой.", build: .smokehouse),
        ], gift: [(.sand, 12), (.glass, 2)]),
        Islander(id: "karas", island: 7, name: "Рыбак Карась", steps: [
            QuestStep(line: "Наловишь рыбы старику?", items: [(.fish, 12)]),
            QuestStep(line: "Копчёная вкуснее всего.", items: [(.smoked_fish, 6)]),
            QuestStep(line: "На большой праздник у реки!", items: [(.smoked_fish, 12), (.berry, 20)]),
        ], gift: [(.fish, 5), (.wood, 8)]),
        Islander(id: "moh", island: 8, name: "Травница Мох", steps: [
            QuestStep(line: "Грибы для моих отваров.", items: [(.mushroom, 15)]),
            QuestStep(line: "Ещё грибов и дров для котла.", items: [(.mushroom, 30), (.wood, 40)]),
            QuestStep(line: "Сварим эликсир вместе?", items: [(.elixir, 3)]),
        ], gift: [(.mushroom, 6), (.honey, 2)]),
        Islander(id: "pchel", island: 9, name: "Пасечник Шмель", steps: [
            QuestStep(line: "Мёд нужен для пряников.", items: [(.honey, 12)]),
            QuestStep(line: "Котёл бы, варить варенье.", build: .cauldron),
            QuestStep(line: "Банок варенья на всю зиму!", items: [(.jam, 8)]),
        ], gift: [(.honey, 5), (.berry, 8)]),
    ]

    static let puzzles: [FloorPuzzle] = [
        FloorPuzzle(id: "p1", island: 1, kind: .plates, size: 3, seconds: 9),
        FloorPuzzle(id: "p2", island: 3, kind: .runes, size: 4),
        FloorPuzzle(id: "p3", island: 4, kind: .lanterns, size: 4),
        FloorPuzzle(id: "p4", island: 5, kind: .plates, size: 5, seconds: 11),
        FloorPuzzle(id: "p5", island: 7, kind: .runes, size: 5),
        FloorPuzzle(id: "p6", island: 9, kind: .lanterns, size: 6),
        FloorPuzzle(id: "p7", island: 10, kind: .plates, size: 6, seconds: 11),
        FloorPuzzle(id: "p8", island: 11, kind: .runes, size: 6),
    ]

    static func islander(_ id: String) -> Islander? { islanders.first { $0.id == id } }
    static func puzzle(_ id: String) -> FloorPuzzle? { puzzles.first { $0.id == id } }

    static func rule(_ p: FloorPuzzle) -> String {
        switch p.kind {
        case .plates: return tr("Зажги все плиты за %@ с", Int(p.seconds))
        case .runes: return tr("Запомни, как мигают руны, и пройди по ним")
        case .lanterns: return tr("Шаг меняет фонарь и соседей. Зажги все")
        }
    }
}

extension BloomGame {
    /// Steps of this islander's chain already done (3 = friend).
    func questStep(_ id: String) -> Int { s.quests[id] ?? 0 }
    func isFriend(_ n: Islander) -> Bool { questStep(n.id) >= n.steps.count }
    func giftReady(_ n: Islander) -> Bool { isFriend(n) && s.giftDay[n.id] != BloomMeta.dayKey() }
    var friendCount: Int { BloomQuests.islanders.filter(isFriend).count }
    var puzzleCount: Int { s.puzzles.count }
    func puzzleSolved(_ id: String) -> Bool { s.puzzles.contains(id) }

    func canHandIn(_ step: QuestStep) -> Bool {
        if let b = step.build { return isBuilt(b) }
        return step.items.allSatisfy { count($0.0) >= $0.1 }
    }

    /// What one step pays: grows with the next island's price, so every islander stays worth a visit.
    func questReward(_ n: Islander, step k: Int) -> (coins: Int, gems: Int, xp: Int) {
        let base = max(30, islandPrice(min(n.island + 1, world.islands.count - 1)) / 30)
        let coins = base * (k + 1)
        let gems = k == n.steps.count - 1 ? 8 : 2 + k
        let xp = max(8, BloomContent.xpToNext(max(level, 1)) * (k + 2) / 12)
        return (coins, gems, xp)
    }

    func handIn(_ n: Islander) {
        let k = questStep(n.id)
        guard k < n.steps.count, canHandIn(n.steps[k]) else { Sfx.play(.error); return }
        let step = n.steps[k]
        for (i, c) in step.items { s.inv[i.rawValue, default: 0] -= c }
        let r = questReward(n, step: k)
        s.coins += r.coins
        s.gems += r.gems
        s.quests[n.id] = k + 1
        bump("quest")
        Sfx.play(.coin)
        let friend = k + 1 >= n.steps.count
        showToast(BloomToast(title: friend ? tr("%@ теперь твой друг!", tr(n.name)) : tr("Задание выполнено!"),
                             subtitle: tr("+%@ монет, +%@ росинок", r.coins, r.gems)))
        Analytics.shared.track("bloom_quest", ["npc": n.id, "step": k + 1, "level": level])
        gainXP(r.xp)
        save()
    }

    func takeGift(_ n: Islander) {
        guard giftReady(n) else { return }
        for (i, c) in n.gift { add(i, c) }
        s.giftDay[n.id] = BloomMeta.dayKey()
        bump("gift")
        Sfx.play(.chest)
        showToast(BloomToast(title: tr("Подарок от друга"), subtitle: n.gift.map { "+\($0.1) \($0.0.title)" }.joined(separator: ", ")))
        save()
    }

    /// Called by the scene when a floor puzzle is solved for the first time.
    func puzzleSolvedReward(_ p: FloorPuzzle) -> (coins: Int, gems: Int) {
        guard !puzzleSolved(p.id) else { return (0, 0) }
        s.puzzles.append(p.id)
        let coins = max(40, islandPrice(min(p.island + 1, world.islands.count - 1)) / 15)
        let gems = 4 + p.size
        s.coins += coins
        s.gems += gems
        bump("puzzle")
        gainXP(max(10, BloomContent.xpToNext(max(level, 1)) / 4))
        Analytics.shared.track("bloom_puzzle", ["id": p.id, "level": level])
        save()
        return (coins, gems)
    }
}
