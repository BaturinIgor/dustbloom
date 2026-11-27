import Foundation

/// Static content of the Bloom slice: items, gatherables, buildings, recipes.
enum BItem: String, CaseIterable, Codable, Identifiable {
    case wood, stone, berry, cotton, flower, iron_ore, gold_ore, crystal, brick, iron_bar, gold_bar, cloth

    var id: String { rawValue }
    var sprite: String { "bloom_item_" + rawValue }

    var title: String {
        switch self {
        case .wood: return "Дерево"
        case .stone: return "Камень"
        case .berry: return "Ягоды"
        case .cotton: return "Хлопок"
        case .flower: return "Цветок"
        case .iron_ore: return "Железная руда"
        case .gold_ore: return "Золотая руда"
        case .crystal: return "Кристалл"
        case .brick: return "Кирпич"
        case .iron_bar: return "Железный слиток"
        case .gold_bar: return "Золотой слиток"
        case .cloth: return "Ткань"
        }
    }

    /// Coins the market pays for one (before the market rate).
    var price: Int { BloomBalance.shared.prices[self] ?? 1 }
}

struct Drop {
    let item: BItem
    let min: Int
    let max: Int
    var chance: Double = 1
}

enum GatherKind: String, CaseIterable, Codable {
    case tree, pine, rock, rock_iron, rock_gold, bush_berry, bush_cotton, crystal

    var sprite: String { "bloom_" + rawValue }
    var hp: Int { BloomBalance.shared.gather[self]?.hp ?? 1 }
    var xp: Int { BloomBalance.shared.gather[self]?.xp ?? 1 }
    var drops: [Drop] { BloomBalance.shared.gather[self]?.drops ?? [] }
    /// Stone-like things spray chips, plants spray leaves.
    var isStone: Bool { [.rock, .rock_iron, .rock_gold, .crystal].contains(self) }
    var isSoft: Bool { self == .bush_berry || self == .bush_cotton }
}

typealias Cost = [(BItem, Int)]

struct Recipe: Identifiable {
    let id: String
    let output: BItem
    let cost: Cost
    let seconds: Double
}

enum BuildKind: String, CaseIterable, Codable, Identifiable {
    case furnace, market, anvil, loom, nursery

    var id: String { rawValue }
    var title: String {
        switch self {
        case .furnace: return "Печь"
        case .market: return "Рынок"
        case .anvil: return "Наковальня"
        case .loom: return "Ткацкий станок"
        case .nursery: return "Питомник"
        }
    }
    var blurb: String {
        switch self {
        case .furnace: return "Плавит руду и обжигает кирпич"
        case .market: return "Продаёт ресурсы за монеты"
        case .anvil: return "Куёт кирки, иногда удачно"
        case .loom: return "Ткёт ткань из хлопка"
        case .nursery: return "Выращивает блумлингов-помощников"
        }
    }
    var sprite: String { self == .furnace ? "bloom_furnace_0" : "bloom_" + rawValue }
    var cost: Cost { BloomBalance.shared.buildings[self]?.cost ?? [] }
    var unlockLevel: Int { BloomBalance.shared.buildings[self]?.level ?? 1 }
    var recipes: [Recipe] {
        let order = ["brick", "iron_bar", "gold_bar", "cloth"]
        return order.compactMap { id in
            guard let r = BloomBalance.shared.recipes[id], r.at == rawValue, let out = BItem(rawValue: id) else { return nil }
            return Recipe(id: id, output: out, cost: r.cost, seconds: r.seconds)
        }
    }
}

struct PickTier {
    let title: String
    let damage: Int
    let cost: Cost
}

enum BloomContent {
    static let pickTitles = ["Деревянная кирка", "Каменная кирка", "Железная кирка", "Золотая кирка"]
    static let picks: [PickTier] = BloomBalance.shared.picks.enumerated().map { i, p in
        PickTier(title: i < pickTitles.count ? pickTitles[i] : "Кирка \(i)", damage: p.damage, cost: p.cost)
    }
    /// Chance that the anvil makes a "lucky" pick (+1 damage on top).
    static let luckyChance = 0.25
    static let levelUnlockText: [Int: String] = [
        2: "Открыт рынок",
        3: "Открыта наковальня",
        4: "Открыт питомник помощников",
        5: "Открыт ткацкий станок",
    ]

    static func xpToNext(_ level: Int) -> Int {
        let b = BloomBalance.shared
        return b.xpBase + level * b.xpLin + level * level * b.xpQuad
    }
    static var maxCombo: Int { BloomBalance.shared.maxCombo }
    /// Hits that each combo step needs.
    static var hitsPerStep: Int { BloomBalance.shared.hitsPerStep }
    static var comboWindow: Double { BloomBalance.shared.comboWindow }

    /// Crit: double damage, big flash.
    static var critChance: Double { BloomBalance.shared.critChance }
    /// Chance per respawn tick that a treasure chest appears (one at a time).
    static var chestChance: Double { BloomBalance.shared.chestChance }

    // helpers
    static let helperColors = ["pink", "sun", "sky", "plum"]
    static let helperNames = ["pink": "Розочка", "sun": "Солнышко", "sky": "Капелька", "plum": "Сливка"]
    static var maxHelpers: Int { BloomBalance.shared.maxHelpers }
    static func helperCost(_ owned: Int) -> Cost {
        BloomBalance.shared.helperCost.map { ($0.0, $0.1 + owned * $0.2) }
    }

    static var goals: [Goal] { BloomBalance.shared.goals }
}

struct Goal {
    let title: String
    let icon: String
    let key: String
    let target: Int
    let coins: Int
    let xp: Int
}
