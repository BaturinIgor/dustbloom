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
    var cost: Cost {
        switch self {
        case .furnace: return [(.stone, 8), (.wood, 4)]
        case .market: return [(.wood, 10), (.berry, 4)]
        case .anvil: return [(.brick, 4), (.wood, 8)]
        case .loom: return [(.wood, 14), (.iron_bar, 2)]
        case .nursery: return [(.wood, 20), (.brick, 6), (.berry, 10)]
        }
    }
    var unlockLevel: Int {
        switch self {
        case .furnace: return 1
        case .market: return 2
        case .anvil: return 3
        case .loom: return 5
        case .nursery: return 4
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
        4: "Открыт питомник помощников",
        5: "Открыт ткацкий станок",
    ]

    static func xpToNext(_ level: Int) -> Int { 10 + level * 8 + level * level }
    static let maxCombo = 5
    /// Hits that each combo step needs.
    static let hitsPerStep = 5
    static let comboWindow: Double = 1.1

    /// Crit: double damage, big flash.
    static let critChance = 0.1
    /// Chance per respawn tick that a treasure chest appears (one at a time).
    static let chestChance = 0.05

    // helpers
    static let helperColors = ["pink", "sun", "sky", "plum"]
    static let helperNames = ["pink": "Розочка", "sun": "Солнышко", "sky": "Капелька", "plum": "Сливка"]
    static let maxHelpers = 3
    static func helperCost(_ owned: Int) -> Cost {
        [(.berry, 12 + owned * 10), (.flower, 4 + owned * 4)]
    }

    static let goals: [Goal] = [
        Goal(title: "Сруби 5 деревьев", icon: "bloom_tree", key: "gather.tree", target: 5, coins: 8, xp: 5),
        Goal(title: "Разбей 5 камней", icon: "bloom_rock", key: "gather.rock", target: 5, coins: 8, xp: 5),
        Goal(title: "Собери 10 ягод", icon: "bloom_item_berry", key: "item.berry", target: 10, coins: 10, xp: 6),
        Goal(title: "Построй печь", icon: "bloom_furnace_0", key: "build.furnace", target: 1, coins: 10, xp: 8),
        Goal(title: "Купи новый остров", icon: "bloom_sign", key: "islands", target: 2, coins: 15, xp: 10),
        Goal(title: "Обожги 5 кирпичей", icon: "bloom_item_brick", key: "craft.brick", target: 5, coins: 12, xp: 8),
        Goal(title: "Сделай комбо ×3", icon: "bloom_fx_spark", key: "combo", target: 3, coins: 15, xp: 10),
        Goal(title: "Построй рынок", icon: "bloom_market", key: "build.market", target: 1, coins: 10, xp: 8),
        Goal(title: "Открой сундук", icon: "bloom_chest_closed", key: "chest", target: 1, coins: 20, xp: 10),
        Goal(title: "Собери 5 цветов", icon: "bloom_item_flower", key: "item.flower", target: 5, coins: 15, xp: 8),
        Goal(title: "Достигни 4 уровня", icon: "bloom_item_coin", key: "level", target: 4, coins: 25, xp: 0),
        Goal(title: "Добудь 10 железной руды", icon: "bloom_item_iron_ore", key: "item.iron_ore", target: 10, coins: 20, xp: 12),
        Goal(title: "Построй наковальню", icon: "bloom_anvil", key: "build.anvil", target: 1, coins: 20, xp: 12),
        Goal(title: "Выкуй каменную кирку", icon: "bloom_pick_1", key: "pick", target: 1, coins: 25, xp: 15),
        Goal(title: "Построй питомник", icon: "bloom_nursery", key: "build.nursery", target: 1, coins: 25, xp: 15),
        Goal(title: "Вырасти блумлинга", icon: "bloom_helper_pink_idle_0", key: "helpers", target: 1, coins: 30, xp: 20),
        Goal(title: "Владей 3 островами", icon: "bloom_sign", key: "islands", target: 3, coins: 40, xp: 20),
        Goal(title: "Сделай комбо ×5", icon: "bloom_fx_spark", key: "combo", target: 5, coins: 40, xp: 20),
        Goal(title: "Выплавь 5 железных слитков", icon: "bloom_item_iron_bar", key: "craft.iron_bar", target: 5, coins: 40, xp: 20),
        Goal(title: "Открой 5 сундуков", icon: "bloom_chest_closed", key: "chest", target: 5, coins: 60, xp: 25),
        Goal(title: "Выкуй железную кирку", icon: "bloom_pick_2", key: "pick", target: 2, coins: 60, xp: 30),
        Goal(title: "Вырасти 3 блумлингов", icon: "bloom_helper_sun_idle_0", key: "helpers", target: 3, coins: 80, xp: 30),
        Goal(title: "Владей 5 островами", icon: "bloom_sign", key: "islands", target: 5, coins: 100, xp: 40),
        Goal(title: "Добудь 10 золотой руды", icon: "bloom_item_gold_ore", key: "item.gold_ore", target: 10, coins: 80, xp: 40),
        Goal(title: "Выкуй золотую кирку", icon: "bloom_pick_3", key: "pick", target: 3, coins: 120, xp: 50),
        Goal(title: "Открой все острова", icon: "bloom_sign", key: "islands", target: 6, coins: 150, xp: 60),
        Goal(title: "Добудь 5 кристаллов", icon: "bloom_item_crystal", key: "item.crystal", target: 5, coins: 200, xp: 80),
    ]
}

struct Goal {
    let title: String
    let icon: String
    let key: String
    let target: Int
    let coins: Int
    let xp: Int
}
