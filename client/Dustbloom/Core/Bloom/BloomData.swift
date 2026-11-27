import Foundation

/// Static content of the Bloom slice: items, gatherables, buildings, recipes.
enum BItem: String, CaseIterable, Codable, Identifiable {
    case wood, stone, berry, cotton, flower, iron_ore, gold_ore, crystal, brick, iron_bar, gold_bar, cloth
    case sand, glass, fish, smoked_fish, mushroom, honey, jam, elixir, obsidian, stardust, lantern

    var id: String { rawValue }
    var sprite: String { "bloom_item_" + rawValue }

    var title: String {
        switch self {
        case .wood: return tr("Дерево")
        case .stone: return tr("Камень")
        case .berry: return tr("Ягоды")
        case .cotton: return tr("Хлопок")
        case .flower: return tr("Цветок")
        case .iron_ore: return tr("Железная руда")
        case .gold_ore: return tr("Золотая руда")
        case .crystal: return tr("Кристалл")
        case .brick: return tr("Кирпич")
        case .iron_bar: return tr("Железный слиток")
        case .gold_bar: return tr("Золотой слиток")
        case .cloth: return tr("Ткань")
        case .sand: return tr("Песок")
        case .glass: return tr("Стекло")
        case .fish: return tr("Рыба")
        case .smoked_fish: return tr("Копчёная рыба")
        case .mushroom: return tr("Гриб")
        case .honey: return tr("Мёд")
        case .jam: return tr("Варенье")
        case .elixir: return tr("Эликсир")
        case .obsidian: return tr("Обсидиан")
        case .stardust: return tr("Звёздная пыль")
        case .lantern: return tr("Звёздный фонарь")
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
    case dune, palm, pond, mushroom, hive, obsidian, starstone

    var sprite: String { "bloom_" + rawValue }
    var hp: Int { BloomBalance.shared.gather[self]?.hp ?? 1 }
    var xp: Int { BloomBalance.shared.gather[self]?.xp ?? 1 }
    var drops: [Drop] { BloomBalance.shared.gather[self]?.drops ?? [] }
    /// Stone-like things spray chips, plants spray leaves.
    var isStone: Bool { [.rock, .rock_iron, .rock_gold, .crystal, .dune, .obsidian, .starstone].contains(self) }
    var isSoft: Bool { [.bush_berry, .bush_cotton, .mushroom, .pond, .hive].contains(self) }
    /// Trees fall and leave a stump.
    var isTree: Bool { self == .tree || self == .pine || self == .palm }
    var stump: String { self == .pine ? "bloom_stump_pine" : self == .palm ? "bloom_stump_palm" : "bloom_stump" }
}

typealias Cost = [(BItem, Int)]

struct Recipe: Identifiable {
    let id: String
    let output: BItem
    let cost: Cost
    let seconds: Double
}

enum BuildKind: String, CaseIterable, Codable, Identifiable {
    case furnace, market, anvil, loom, nursery, smokehouse, cauldron, observatory

    var id: String { rawValue }
    var title: String {
        switch self {
        case .furnace: return tr("Печь")
        case .market: return tr("Рынок")
        case .anvil: return tr("Наковальня")
        case .loom: return tr("Ткацкий станок")
        case .nursery: return tr("Питомник")
        case .smokehouse: return tr("Коптильня")
        case .cauldron: return tr("Котёл")
        case .observatory: return tr("Обсерватория")
        }
    }
    var blurb: String {
        switch self {
        case .furnace: return tr("Плавит руду и обжигает кирпич")
        case .market: return tr("Продаёт ресурсы за монеты")
        case .anvil: return tr("Куёт кирки, иногда удачно")
        case .loom: return tr("Ткёт ткань из хлопка")
        case .nursery: return tr("Выращивает блумлингов-помощников")
        case .smokehouse: return tr("Коптит рыбу, она дорого стоит")
        case .cauldron: return tr("Варит варенье и эликсиры")
        case .observatory: return tr("Собирает звёздные фонари")
        }
    }
    var sprite: String { self == .furnace ? "bloom_furnace_0" : "bloom_" + rawValue }
    var cost: Cost { BloomBalance.shared.buildings[self]?.cost ?? [] }
    var unlockLevel: Int { BloomBalance.shared.buildings[self]?.level ?? 1 }
    var recipes: [Recipe] {
        let order = ["brick", "iron_bar", "gold_bar", "glass", "cloth", "smoked_fish", "jam", "elixir", "lantern"]
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
    static let pickTitles = [tr("Деревянная кирка"), tr("Каменная кирка"), tr("Железная кирка"), tr("Золотая кирка"),
                                     tr("Хрустальная кирка"), tr("Обсидиановая кирка")]
    static let picks: [PickTier] = BloomBalance.shared.picks.enumerated().map { i, p in
        PickTier(title: i < pickTitles.count ? pickTitles[i] : tr("Кирка %@", i), damage: p.damage, cost: p.cost)
    }
    /// Chance that the anvil makes a "lucky" pick (+1 damage on top).
    static let luckyChance = 0.25
    static let levelUnlockText: [Int: String] = [
        2: tr("Открыт рынок"),
        3: tr("Открыта наковальня"),
        4: tr("Открыт питомник помощников"),
        5: tr("Открыт ткацкий станок"),
        8: tr("Открыта коптильня"),
        10: tr("Открыт котёл"),
        13: tr("Открыта обсерватория"),
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
    static let helperColors = ["pink", "sun", "sky", "plum", "mint"]
    static let helperNames = ["pink": tr("Розочка"), "sun": tr("Солнышко"), "sky": tr("Капелька"), "plum": tr("Сливка")]
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
