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
        var localizedName: String {
            let lang = Locale.current.language.languageCode?.identifier ?? "en"
            return name[lang] ?? name["en"] ?? id
        }
    }

    var version: Int
    var farm: FarmConfig
    var crops: [Crop]

    func crop(_ id: String) -> Crop? {
        crops.first { $0.id == id }
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
