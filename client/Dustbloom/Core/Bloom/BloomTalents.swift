import SwiftUI

/// Talent tree ("Древо цветения"): five branches, each a vine of five talents.
/// One talent point per level; the top two of every branch cost 2.
struct Talent: Identifiable {
    let id: String
    let branch: Int
    let tier: Int
    let title: String
    let text: String
    let icon: String
    var cost: Int { tier >= 3 ? 2 : 1 }
    /// The talent below on the same vine.
    var requires: String? { tier == 0 ? nil : BloomTalents.branches[branch].ids[tier - 1] }
}

struct TalentBranch {
    let title: String
    let color: Color
    let ids: [String]
}

enum BloomTalents {
    static let branches: [TalentBranch] = [
        TalentBranch(title: "Добыча", color: Color(red: 1, green: 0.6, blue: 0.25), ids: ["d1", "d2", "d3", "d4", "d5"]),
        TalentBranch(title: "Ремесло", color: Color(red: 0.45, green: 0.75, blue: 1), ids: ["c1", "c2", "c3", "c4", "c5"]),
        TalentBranch(title: "Цветение", color: Color(red: 1, green: 0.55, blue: 0.7), ids: ["b1", "b2", "b3", "b4", "b5"]),
        TalentBranch(title: "Торговля", color: Color(red: 1, green: 0.82, blue: 0.25), ids: ["t1", "t2", "t3", "t4", "t5"]),
        TalentBranch(title: "Помощники", color: Color(red: 0.5, green: 0.9, blue: 0.45), ids: ["h1", "h2", "h3", "h4", "h5"]),
    ]

    static let all: [Talent] = [
        Talent(id: "d1", branch: 0, tier: 0, title: "Крепкая рука", text: "+1 к удару", icon: "bloom_pick_1"),
        Talent(id: "d2", branch: 0, tier: 1, title: "Меткость", text: "+6% шанс крита", icon: "bloom_fx_spark"),
        Talent(id: "d3", branch: 0, tier: 2, title: "Ритм", text: "Комбо держится на 0,4 с дольше", icon: "bloom_rock"),
        Talent(id: "d4", branch: 0, tier: 3, title: "Двойная добыча", text: "15% шанс удвоить добычу", icon: "bloom_item_stone"),
        Talent(id: "d5", branch: 0, tier: 4, title: "Землетряс", text: "Каждый 15-й удар бьёт всё вокруг", icon: "bloom_rock_gold"),

        Talent(id: "c1", branch: 1, tier: 0, title: "Быстрые руки", text: "Крафт на 25% быстрее", icon: "bloom_furnace_0"),
        Talent(id: "c2", branch: 1, tier: 1, title: "Экономный строитель", text: "Постройки на 20% дешевле", icon: "bloom_item_brick"),
        Talent(id: "c3", branch: 1, tier: 2, title: "Жаркая печь", text: "20% шанс сделать 2 вместо 1", icon: "bloom_item_iron_bar"),
        Talent(id: "c4", branch: 1, tier: 3, title: "Кузнец-счастливчик", text: "Удачная ковка +25%", icon: "bloom_anvil"),
        Talent(id: "c5", branch: 1, tier: 4, title: "Мастер", text: "Крафт ещё на 30% быстрее", icon: "bloom_item_gold_bar"),

        Talent(id: "b1", branch: 2, tier: 0, title: "Цветочник", text: "Цветов на островах вдвое больше", icon: "bloom_item_flower"),
        Talent(id: "b2", branch: 2, tier: 1, title: "Быстрый рост", text: "Всё отрастает на 40% быстрее", icon: "bloom_tree"),
        Talent(id: "b3", branch: 2, tier: 2, title: "Нектар", text: "Каждый цветок даёт +5 опыта", icon: "bloom_flower_pink"),
        Talent(id: "b4", branch: 2, tier: 3, title: "Долгий закат", text: "Золотой час длится на 50% дольше", icon: "bloom_item_coin"),
        Talent(id: "b5", branch: 2, tier: 4, title: "Волна удачи", text: "Каждый расцветший остров дарит сундук", icon: "bloom_chest_closed"),

        Talent(id: "t1", branch: 3, tier: 0, title: "Торговец", text: "Рынок платит на 25% больше", icon: "bloom_market"),
        Talent(id: "t2", branch: 3, tier: 1, title: "Монетный дождь", text: "Монеты падают в 1,5 раза чаще", icon: "bloom_item_coin"),
        Talent(id: "t3", branch: 3, tier: 2, title: "Кладоискатель", text: "Сундуки появляются вдвое чаще", icon: "bloom_chest_closed"),
        Talent(id: "t4", branch: 3, tier: 3, title: "Землевладелец", text: "Острова на 20% дешевле", icon: "bloom_sign"),
        Talent(id: "t5", branch: 3, tier: 4, title: "Счастливая находка", text: "Находки для альбома вдвое чаще", icon: "bloom_ui_book"),

        Talent(id: "h1", branch: 4, tier: 0, title: "Заботливый садовник", text: "Блумлинги на 30% дешевле", icon: "bloom_nursery"),
        Talent(id: "h2", branch: 4, tier: 1, title: "Резвые ростки", text: "Помощники бегают на 40% быстрее", icon: "bloom_helper_sky_idle_0"),
        Talent(id: "h3", branch: 4, tier: 2, title: "Сильные ростки", text: "Помощники бьют вдвое сильнее", icon: "bloom_helper_sun_idle_0"),
        Talent(id: "h4", branch: 4, tier: 3, title: "Большая семья", text: "+1 место для помощника", icon: "bloom_helper_plum_idle_0"),
        Talent(id: "h5", branch: 4, tier: 4, title: "Дружба", text: "Помощники тоже бьют критами", icon: "bloom_helper_pink_idle_0"),
    ]

    static func talent(_ id: String) -> Talent { all.first { $0.id == id }! }
}

/// Album of rare finds (bugs, fossils, gems). A full page gives a lasting bonus.
struct AlbumPage {
    let title: String
    let bonus: String
    let finds: [(id: String, title: String)]
}

enum BloomAlbum {
    static let pages: [AlbumPage] = [
        AlbumPage(title: "Жучки", bonus: "Бег на 15% быстрее", finds: [
            ("ladybug", "Божья коровка"), ("beetle", "Изумрудный жук"), ("snail", "Улитка"),
            ("firefly", "Светлячок"), ("moth", "Лунная моль")]),
        AlbumPage(title: "Окаменелости", bonus: "+15% опыта", finds: [
            ("shell", "Ракушка"), ("bone", "Древняя кость"), ("amber", "Янтарь"),
            ("trilobite", "Трилобит"), ("fern", "Отпечаток папоротника")]),
        AlbumPage(title: "Самоцветы", bonus: "+1 к удару", finds: [
            ("ruby", "Рубин"), ("sapphire", "Сапфир"), ("emerald", "Изумруд"),
            ("topaz", "Топаз"), ("amethyst", "Аметист")]),
    ]

    /// Which page a gatherable can drop a find from.
    static func page(for k: GatherKind) -> Int {
        switch k {
        case .tree, .pine, .bush_berry, .bush_cotton: return 0
        case .rock: return 1
        case .rock_iron, .rock_gold, .crystal: return 2
        }
    }

    static let baseChance = 0.035
    static let duplicateCoins = 15

    static func title(_ id: String) -> String {
        for p in pages { if let f = p.finds.first(where: { $0.id == id }) { return f.title } }
        return id
    }
}

/// Golden hour: every few minutes the islands turn gold and all drops double.
enum GoldenHour {
    static var every: Double { BloomBalance.shared.goldenEvery }
    static var first: Double { BloomBalance.shared.goldenFirst }
    static var duration: Double { BloomBalance.shared.goldenDuration }
}
