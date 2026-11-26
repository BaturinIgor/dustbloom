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

    /// Coins the market pays for one.
    var price: Int {
        switch self {
        case .wood, .stone: return 1
        case .berry, .cotton: return 2
        case .flower: return 3
        case .iron_ore: return 3
        case .gold_ore: return 6
        case .brick: return 5
        case .cloth: return 9
        case .iron_bar: return 10
        case .gold_bar: return 22
        case .crystal: return 40
        }
    }
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
    var hp: Int {
        switch self {
        case .bush_berry, .bush_cotton: return 1
        case .tree: return 3
        case .pine, .rock: return 4
        case .rock_iron: return 7
        case .rock_gold: return 10
        case .crystal: return 14
        }
    }
    var xp: Int {
        switch self {
        case .bush_berry, .bush_cotton: return 1
        case .tree, .rock: return 2
        case .pine: return 3
        case .rock_iron: return 5
        case .rock_gold: return 8
        case .crystal: return 12
        }
    }
    var drops: [Drop] {
        switch self {
        case .tree: return [Drop(item: .wood, min: 2, max: 3), Drop(item: .berry, min: 1, max: 1, chance: 0.3)]
        case .pine: return [Drop(item: .wood, min: 3, max: 4)]
        case .rock: return [Drop(item: .stone, min: 2, max: 3)]
        case .rock_iron: return [Drop(item: .stone, min: 1, max: 1), Drop(item: .iron_ore, min: 2, max: 3)]
        case .rock_gold: return [Drop(item: .stone, min: 1, max: 1), Drop(item: .gold_ore, min: 2, max: 2)]
        case .bush_berry: return [Drop(item: .berry, min: 2, max: 3)]
        case .bush_cotton: return [Drop(item: .cotton, min: 2, max: 2)]
        case .crystal: return [Drop(item: .crystal, min: 1, max: 2)]
        }
    }
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
    case furnace, market, anvil, loom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .furnace: return "Печь"
        case .market: return "Рынок"
        case .anvil: return "Наковальня"
        case .loom: return "Ткацкий станок"
        }
    }
    var blurb: String {
        switch self {
        case .furnace: return "Плавит руду и обжигает кирпич"
        case .market: return "Продаёт ресурсы за монеты"
        case .anvil: return "Куёт кирки, иногда удачно"
        case .loom: return "Ткёт ткань из хлопка"
        }
    }
    var sprite: String { self == .furnace ? "bloom_furnace_0" : "bloom_" + rawValue }
    var cost: Cost {
        switch self {
        case .furnace: return [(.stone, 8), (.wood, 4)]
        case .market: return [(.wood, 10), (.berry, 4)]
        case .anvil: return [(.brick, 4), (.wood, 8)]
        case .loom: return [(.wood, 14), (.iron_bar, 2)]
        }
    }
    var unlockLevel: Int {
        switch self {
        case .furnace: return 1
        case .market: return 2
        case .anvil: return 3
        case .loom: return 5
        }
    }
    var recipes: [Recipe] {
        switch self {
        case .furnace: return [
            Recipe(id: "brick", output: .brick, cost: [(.stone, 3)], seconds: 2),
            Recipe(id: "iron_bar", output: .iron_bar, cost: [(.iron_ore, 2), (.wood, 1)], seconds: 3),
            Recipe(id: "gold_bar", output: .gold_bar, cost: [(.gold_ore, 2), (.wood, 1)], seconds: 4),
        ]
        case .loom: return [Recipe(id: "cloth", output: .cloth, cost: [(.cotton, 3)], seconds: 2.5)]
        default: return []
        }
    }
}

struct PickTier {
    let title: String
    let damage: Int
    let cost: Cost
}

enum BloomContent {
    static let picks: [PickTier] = [
        PickTier(title: "Деревянная кирка", damage: 1, cost: []),
        PickTier(title: "Каменная кирка", damage: 2, cost: [(.stone, 10), (.wood, 8)]),
        PickTier(title: "Железная кирка", damage: 3, cost: [(.iron_bar, 5), (.wood, 10)]),
        PickTier(title: "Золотая кирка", damage: 5, cost: [(.gold_bar, 6), (.iron_bar, 4)]),
    ]
    /// Chance that the anvil makes a "lucky" pick (+1 damage on top).
    static let luckyChance = 0.25
    static let levelUnlockText: [Int: String] = [
        2: "Открыт рынок",
        3: "Открыта наковальня",
        5: "Открыт ткацкий станок",
    ]

    static func xpToNext(_ level: Int) -> Int { 10 + level * 8 + level * level }
    static let maxCombo = 5
    /// Hits that each combo step needs.
    static let hitsPerStep = 5
    static let comboWindow: Double = 1.1
}
