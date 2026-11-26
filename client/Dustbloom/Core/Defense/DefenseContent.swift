import Foundation

/// Static Farm Defense content: who walks in the Dust Storm, who guards the
/// fence and which crops shoot. Numbers are multipliers on DefenseBalance.
enum DefenseContent {
    struct EnemyKind {
        let id: String
        let sprite: String       // texture prefix, frames are <sprite>_0...
        let frames: Int
        let frameTime: Double
        let speed: Double        // 1 = crosses the field in killWindowSeconds
        let hpWeight: Double     // share of the wave HP
        let fenceDps: Double     // fence damage per second once at the fence
        let flying: Bool
        let burrows: Bool        // underground (untargetable) for the first half
        let size: Double         // on-screen scale
        let firstWave: Int       // wave inside the land where it starts to appear
        let name: [String: String]
    }

    enum Projectile: String { case arrow, ember, frost, fluff, berry, grain, none }

    enum Skill {
        case wall        // heal the fence, enemies at the fence are knocked back
        case arrowRain   // many arrows on random enemies
        case smash       // big hit + stun near the fence
        case blizzard    // damage + long slow on everything
    }

    struct HeroKind {
        let id: String
        let sprite: String
        let dpsFactor: Double
        let interval: Double     // seconds between attacks
        let range: Double        // reach from the fence, 0...1 of the field
        let melee: Bool
        let splash: Bool         // hits every enemy in range
        let projectile: Projectile
        let slow: Double         // 0...1 slow applied per hit
        let skill: Skill
        let skillCooldown: Double
        let unlockWave: Int
        let name: [String: String]
        let skillName: [String: String]
    }

    struct CropKind {
        let id: String
        let sprite: String       // grown crop texture
        let dpsFactor: Double
        let interval: Double
        let range: Double
        let projectile: Projectile
        let slow: Double
        let fenceHeal: Double    // fence HP per hit
        let coinBonus: Double    // extra share of kill coins
        let unlockWave: Int
        let name: [String: String]
        let role: [String: String]
    }

    static let enemies: [EnemyKind] = [
        EnemyKind(id: "beetle", sprite: "def_beetle", frames: 4, frameTime: 0.14, speed: 1.0, hpWeight: 1.0,
                  fenceDps: 3, flying: false, burrows: false, size: 1.0, firstWave: 1,
                  name: ["ru": "Пыльный жук", "en": "Dust Beetle"]),
        EnemyKind(id: "locust", sprite: "def_locust", frames: 2, frameTime: 0.06, speed: 1.45, hpWeight: 0.6,
                  fenceDps: 2, flying: true, burrows: false, size: 1.0, firstWave: 4,
                  name: ["ru": "Саранча", "en": "Locust"]),
        EnemyKind(id: "tumble", sprite: "def_tumble", frames: 4, frameTime: 0.07, speed: 1.9, hpWeight: 0.5,
                  fenceDps: 2, flying: false, burrows: false, size: 1.0, firstWave: 11,
                  name: ["ru": "Перекати-поле", "en": "Tumbleweed"]),
        EnemyKind(id: "molerat", sprite: "def_molerat", frames: 4, frameTime: 0.16, speed: 0.75, hpWeight: 2.6,
                  fenceDps: 6, flying: false, burrows: true, size: 1.1, firstWave: 21,
                  name: ["ru": "Кротокрыс", "en": "Mole Rat"]),
    ]

    static let boss = EnemyKind(id: "queen", sprite: "def_queen", frames: 4, frameTime: 0.12, speed: 0.7,
                                hpWeight: 14, fenceDps: 18, flying: true, burrows: false, size: 1.0, firstWave: 1,
                                name: ["ru": "Королева саранчи", "en": "Locust Queen"])

    static let heroes: [HeroKind] = [
        HeroKind(id: "straw_guard", sprite: "unit_straw_guard", dpsFactor: 1.0, interval: 0.7, range: 0.13,
                 melee: true, splash: false, projectile: .none, slow: 0, skill: .wall, skillCooldown: 25,
                 unlockWave: 1, name: ["ru": "Соломенный страж", "en": "Straw Guard"],
                 skillName: ["ru": "Соломенная стена", "en": "Straw Wall"]),
        HeroKind(id: "crow_archer", sprite: "unit_crow_archer", dpsFactor: 1.0, interval: 0.55, range: 0.92,
                 melee: false, splash: false, projectile: .arrow, slow: 0, skill: .arrowRain, skillCooldown: 20,
                 unlockWave: 1, name: ["ru": "Вороний лучник", "en": "Crow Archer"],
                 skillName: ["ru": "Град стрел", "en": "Arrow Rain"]),
        HeroKind(id: "pumpkin_brute", sprite: "unit_pumpkin_brute", dpsFactor: 1.15, interval: 1.2, range: 0.16,
                 melee: true, splash: true, projectile: .none, slow: 0, skill: .smash, skillCooldown: 30,
                 unlockWave: 25, name: ["ru": "Тыквенный громила", "en": "Pumpkin Brute"],
                 skillName: ["ru": "Тыквенный удар", "en": "Pumpkin Smash"]),
        HeroKind(id: "frost_sentinel", sprite: "unit_frost_sentinel", dpsFactor: 0.9, interval: 0.9, range: 0.7,
                 melee: false, splash: false, projectile: .frost, slow: 0.3, skill: .blizzard, skillCooldown: 35,
                 unlockWave: 60, name: ["ru": "Морозный часовой", "en": "Frost Sentinel"],
                 skillName: ["ru": "Стужа", "en": "Blizzard"]),
    ]

    static let crops: [CropKind] = [
        CropKind(id: "emberpepper", sprite: "emberpepper_3", dpsFactor: 1.2, interval: 0.6, range: 0.75,
                 projectile: .ember, slow: 0, fenceHeal: 0, coinBonus: 0, unlockWave: 1,
                 name: ["ru": "Угольный перец", "en": "Ember Pepper"],
                 role: ["ru": "Стреляет огнём", "en": "Shoots fire"]),
        CropKind(id: "cottonpuff", sprite: "cottonpuff_3", dpsFactor: 0.6, interval: 0.8, range: 0.6,
                 projectile: .fluff, slow: 0.35, fenceHeal: 0, coinBonus: 0, unlockWave: 8,
                 name: ["ru": "Пушной хлопок", "en": "Cotton Puff"],
                 role: ["ru": "Замедляет", "en": "Slows"]),
        CropKind(id: "bloodberry", sprite: "bloodberry_3", dpsFactor: 0.7, interval: 0.9, range: 0.55,
                 projectile: .berry, slow: 0, fenceHeal: 0.6, coinBonus: 0, unlockWave: 15,
                 name: ["ru": "Кровяника", "en": "Bloodberry"],
                 role: ["ru": "Чинит забор", "en": "Mends the fence"]),
        CropKind(id: "dustwheat", sprite: "dustwheat_3", dpsFactor: 0.5, interval: 1.0, range: 0.5,
                 projectile: .grain, slow: 0, fenceHeal: 0, coinBonus: 0.15, unlockWave: 35,
                 name: ["ru": "Пыльный колос", "en": "Dustwheat"],
                 role: ["ru": "Больше монет", "en": "More coins"]),
    ]

    static let landNames: [[String: String]] = [
        ["ru": "Пыльные поля", "en": "Dust Fields"],
        ["ru": "Ржавый овраг", "en": "Rust Gully"],
        ["ru": "Солончак", "en": "Salt Flats"],
        ["ru": "Мёртвый сад", "en": "Dead Orchard"],
        ["ru": "Стеклянные дюны", "en": "Glass Dunes"],
        ["ru": "Грибные топи", "en": "Fungal Mire"],
        ["ru": "Пепельный каньон", "en": "Ash Canyon"],
        ["ru": "Сердце Бури", "en": "Heart of the Storm"],
    ]

    static func text(_ dict: [String: String]) -> String {
        let lang = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
        return dict[lang] ?? dict["en"] ?? dict.values.first ?? ""
    }
}
