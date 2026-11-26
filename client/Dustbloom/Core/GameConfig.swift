import Foundation

/// Balance file shared with the server (server/internal/game/data/crops.json).
struct GameConfig: Codable, Equatable {
    struct Area: Codable, Equatable {
        var x: Int
        var y: Int
        var width: Int
        var height: Int

        func contains(x px: Int, y py: Int) -> Bool {
            px >= x && py >= y && px < x + width && py < y + height
        }
    }

    struct FarmConfig: Codable, Equatable {
        var width: Int
        var height: Int
        var startCoins: Int
        var startTilled: Area
        var tillCost: Int
        var plotSize: Int
        var startPlots: [[Int]]
        var plotBaseCost: Int
        var plotCostGrowth: Double
        var plotLevelStep: Int

        var plotsX: Int { width / plotSize }
        var plotsY: Int { height / plotSize }
    }

    struct Crop: Codable, Equatable, Identifiable {
        var id: String
        var name: [String: String]
        var growSeconds: Int
        var seedCost: Int
        var sellPrice: Int
        var xp: Int
        var unlockLevel: Int

        /// Name in the device language, falling back to English.
        var localizedName: String { GameConfig.localized(name, fallback: id) }
    }

    struct ArmyConfig: Codable, Equatable {
        var baseSlots: Int
        var slotsPerLevel: Int
        var maxSlots: Int
        var queueSize: Int
    }

    /// A combat scarecrow built from barn crops.
    struct Scarecrow: Codable, Equatable, Identifiable {
        var id: String
        var name: [String: String]
        var cost: [String: Int]
        var coins: Int
        var buildSeconds: Int
        var hp: Int
        var attack: Int
        var unlockLevel: Int

        var localizedName: String { GameConfig.localized(name, fallback: id) }
    }

    struct Enemy: Codable, Equatable {
        var hp: Int
        var attack: Int
    }

    /// A wasteland camp the army can raid.
    struct Raid: Codable, Equatable, Identifiable {
        var id: String
        var name: [String: String]
        var enemies: [Enemy]
        var rewardCoins: Int
        var rewardXp: Int
        var cooldownSeconds: Int
        var unlockLevel: Int
        var drops: [String: Int]?

        var localizedName: String { GameConfig.localized(name, fallback: id) }
    }

    var version: Int
    var farm: FarmConfig
    var crops: [Crop]
    var army: ArmyConfig
    var scarecrows: [Scarecrow]
    var raids: [Raid]
    var orders: OrderConfig
    var items: ItemsConfig

    func crop(_ id: String) -> Crop? {
        crops.first { $0.id == id }
    }

    func scarecrow(_ id: String) -> Scarecrow? {
        scarecrows.first { $0.id == id }
    }

    func raid(_ id: String) -> Raid? {
        raids.first { $0.id == id }
    }

    static func localized(_ names: [String: String], fallback: String) -> String {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return names[lang] ?? names["en"] ?? fallback
    }

    static func load(from bundle: Bundle = .main) -> GameConfig {
        guard let url = bundle.url(forResource: "crops", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(GameConfig.self, from: data)
        else {
            fatalError("crops.json is missing from the app bundle")
        }
        return config
    }
}
