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
        TalentBranch(title: tr("Добыча"), color: Color(red: 1, green: 0.6, blue: 0.25), ids: ["d1", "d2", "d3", "d4", "d5"]),
        TalentBranch(title: tr("Ремесло"), color: Color(red: 0.45, green: 0.75, blue: 1), ids: ["c1", "c2", "c3", "c4", "c5"]),
        TalentBranch(title: tr("Цветение"), color: Color(red: 1, green: 0.55, blue: 0.7), ids: ["b1", "b2", "b3", "b4", "b5"]),
        TalentBranch(title: tr("Торговля"), color: Color(red: 1, green: 0.82, blue: 0.25), ids: ["t1", "t2", "t3", "t4", "t5"]),
        TalentBranch(title: tr("Помощники"), color: Color(red: 0.5, green: 0.9, blue: 0.45), ids: ["h1", "h2", "h3", "h4", "h5"]),
    ]

    static let all: [Talent] = [
        Talent(id: "d1", branch: 0, tier: 0, title: tr("Крепкая рука"), text: tr("+1 к удару"), icon: "bloom_pick_1"),
        Talent(id: "d2", branch: 0, tier: 1, title: tr("Меткость"), text: tr("+6% шанс крита"), icon: "bloom_fx_spark"),
        Talent(id: "d3", branch: 0, tier: 2, title: tr("Ритм"), text: tr("Комбо держится на 0,4 с дольше"), icon: "bloom_rock"),
        Talent(id: "d4", branch: 0, tier: 3, title: tr("Двойная добыча"), text: tr("15% шанс удвоить добычу"), icon: "bloom_item_stone"),
        Talent(id: "d5", branch: 0, tier: 4, title: tr("Землетряс"), text: tr("Каждый 15-й удар бьёт всё вокруг"), icon: "bloom_rock_gold"),

        Talent(id: "c1", branch: 1, tier: 0, title: tr("Быстрые руки"), text: tr("Крафт на 25% быстрее"), icon: "bloom_furnace_0"),
        Talent(id: "c2", branch: 1, tier: 1, title: tr("Экономный строитель"), text: tr("Постройки на 20% дешевле"), icon: "bloom_item_brick"),
        Talent(id: "c3", branch: 1, tier: 2, title: tr("Жаркая печь"), text: tr("20% шанс сделать 2 вместо 1"), icon: "bloom_item_iron_bar"),
        Talent(id: "c4", branch: 1, tier: 3, title: tr("Кузнец-счастливчик"), text: tr("Удачная ковка +25%"), icon: "bloom_anvil"),
        Talent(id: "c5", branch: 1, tier: 4, title: tr("Мастер"), text: tr("Крафт ещё на 30% быстрее"), icon: "bloom_item_gold_bar"),

        Talent(id: "b1", branch: 2, tier: 0, title: tr("Цветочник"), text: tr("Цветов на островах вдвое больше"), icon: "bloom_item_flower"),
        Talent(id: "b2", branch: 2, tier: 1, title: tr("Быстрый рост"), text: tr("Всё отрастает на 40% быстрее"), icon: "bloom_tree"),
        Talent(id: "b3", branch: 2, tier: 2, title: tr("Нектар"), text: tr("Каждый цветок даёт +5 опыта"), icon: "bloom_flower_pink"),
        Talent(id: "b4", branch: 2, tier: 3, title: tr("Долгий закат"), text: tr("Золотой час длится на 50% дольше"), icon: "bloom_item_coin"),
        Talent(id: "b5", branch: 2, tier: 4, title: tr("Волна удачи"), text: tr("Каждый расцветший остров дарит сундук"), icon: "bloom_chest_closed"),

        Talent(id: "t1", branch: 3, tier: 0, title: tr("Торговец"), text: tr("Рынок платит на 25% больше"), icon: "bloom_market"),
        Talent(id: "t2", branch: 3, tier: 1, title: tr("Монетный дождь"), text: tr("Монеты падают в 1,5 раза чаще"), icon: "bloom_item_coin"),
        Talent(id: "t3", branch: 3, tier: 2, title: tr("Кладоискатель"), text: tr("Сундуки появляются вдвое чаще"), icon: "bloom_chest_closed"),
        Talent(id: "t4", branch: 3, tier: 3, title: tr("Землевладелец"), text: tr("Острова на 20% дешевле"), icon: "bloom_sign"),
        Talent(id: "t5", branch: 3, tier: 4, title: tr("Счастливая находка"), text: tr("Находки для альбома вдвое чаще"), icon: "bloom_ui_book"),

        Talent(id: "h1", branch: 4, tier: 0, title: tr("Заботливый садовник"), text: tr("Блумлинги на 30% дешевле"), icon: "bloom_nursery"),
        Talent(id: "h2", branch: 4, tier: 1, title: tr("Резвые ростки"), text: tr("Помощники бегают на 40% быстрее"), icon: "bloom_helper_sky_idle_0"),
        Talent(id: "h3", branch: 4, tier: 2, title: tr("Сильные ростки"), text: tr("Помощники бьют вдвое сильнее"), icon: "bloom_helper_sun_idle_0"),
        Talent(id: "h4", branch: 4, tier: 3, title: tr("Большая семья"), text: tr("+1 место для помощника"), icon: "bloom_helper_plum_idle_0"),
        Talent(id: "h5", branch: 4, tier: 4, title: tr("Дружба"), text: tr("Помощники тоже бьют критами"), icon: "bloom_helper_pink_idle_0"),
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
        AlbumPage(title: tr("Жучки"), bonus: tr("Бег на 15% быстрее"), finds: [
            ("ladybug", tr("Божья коровка")), ("beetle", tr("Изумрудный жук")), ("snail", tr("Улитка")),
            ("firefly", tr("Светлячок")), ("moth", tr("Лунная моль"))]),
        AlbumPage(title: tr("Окаменелости"), bonus: tr("+15% опыта"), finds: [
            ("shell", tr("Ракушка")), ("bone", tr("Древняя кость")), ("amber", tr("Янтарь")),
            ("trilobite", tr("Трилобит")), ("fern", tr("Отпечаток папоротника"))]),
        AlbumPage(title: tr("Самоцветы"), bonus: tr("+1 к удару"), finds: [
            ("ruby", tr("Рубин")), ("sapphire", tr("Сапфир")), ("emerald", tr("Изумруд")),
            ("topaz", tr("Топаз")), ("amethyst", tr("Аметист"))]),
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
