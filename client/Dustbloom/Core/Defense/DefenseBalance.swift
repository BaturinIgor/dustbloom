import Foundation

/// Farm Defense economy, decoded from the same balance.json the Go balance
/// simulator tunes (server/internal/defense/balance.json). The formulas here
/// mirror server/internal/defense/balance.go one to one.
struct DefenseBalance: Codable, Equatable {
    var lands: Int
    var wavesPerLand: Int
    var waveSeconds: Double
    var killWindowSeconds: Double
    var hpBase: Double
    var hpGrowth: Double
    var bossEvery: Int
    var bossMult: Double
    var landBossMult: Double
    var rewardBase: Double
    var rewardGrowth: Double
    var seedShare: Double
    var offlineEfficiency: Double
    var offlineCapHours: Double
    var offlineCapPerLand: Double
    var offlineCapMaxHours: Double
    var heroBaseDps: Double
    var cropBaseDps: Double
    var levelCostBase: Double
    var levelCostGrowth: Double
    var milestoneEvery: Int
    var milestoneMult: Double
    var heroSlotsStart: Int
    var heroSlotsMax: Int
    var cropSlotsStart: Int
    var cropSlotsPerLand: Int
    var cropSlotsMax: Int
    var landHP: [Double]

    static func load(bundle: Bundle = .main) -> DefenseBalance {
        guard let url = bundle.url(forResource: "balance", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let b = try? JSONDecoder().decode(DefenseBalance.self, from: data)
        else { fatalError("balance.json missing from the app bundle") }
        return b
    }

    var totalWaves: Int { lands * wavesPerLand }

    func land(of wave: Int) -> Int { wave < 1 ? 1 : (wave - 1) / wavesPerLand + 1 }

    /// Wave number inside its land, 1...wavesPerLand.
    func inLand(_ wave: Int) -> Int { (wave - 1) % wavesPerLand + 1 }

    func isLandBoss(_ wave: Int) -> Bool {
        let i = inLand(wave)
        return i == wavesPerLand || i == wavesPerLand / 2
    }

    func isBoss(_ wave: Int) -> Bool { isLandBoss(wave) || inLand(wave) % bossEvery == 0 }

    func waveHP(_ wave: Int) -> Double {
        var hp = hpBase * pow(hpGrowth, Double(wave - 1))
        hp *= landFactor(wave)
        if isLandBoss(wave) { hp *= landBossMult } else if isBoss(wave) { hp *= bossMult }
        return hp
    }

    /// Mirrors Balance.LandFactor in Go: glides from one land's factor to the next.
    func landFactor(_ wave: Int) -> Double {
        guard let last = landHP.last else { return 1 }
        let k = land(of: wave) - 1
        guard k + 1 < landHP.count else { return last }
        let t = Double((wave - 1) % wavesPerLand) / Double(wavesPerLand)
        return exp(log(landHP[k]) * (1 - t) + log(landHP[k + 1]) * t)
    }

    func requiredDPS(_ wave: Int) -> Double { waveHP(wave) / killWindowSeconds }

    func waveCoins(_ wave: Int) -> Double { rewardBase * pow(rewardGrowth, Double(max(wave, 1) - 1)) }

    func farmCoinsPerSecond(_ wave: Int) -> Double { waveCoins(max(wave, 1)) / waveSeconds }

    func levelCost(_ level: Int) -> Double { levelCostBase * pow(levelCostGrowth, Double(level - 1)) }

    func levelMult(_ level: Int) -> Double {
        level < 1 ? 0 : Double(level) * pow(milestoneMult, Double(level / milestoneEvery))
    }

    func offlineCap(land: Int) -> Double {
        min(offlineCapMaxHours, offlineCapHours + offlineCapPerLand * Double(land - 1))
    }

    func heroSlots(land: Int) -> Int { min(heroSlotsMax, heroSlotsStart + land - 1) }
    func cropSlots(land: Int) -> Int { min(cropSlotsMax, cropSlotsStart + cropSlotsPerLand * (land - 1)) }
}

/// Big idle numbers: 950, 12.4K, 3.1M, 7.8B, 2.2T, then aa, ab...
enum BigNumber {
    static func format(_ v: Double) -> String {
        if v < 1000 { return String(Int(v.rounded(.down))) }
        let units = ["K", "M", "B", "T"]
        var x = v
        var i = -1
        while x >= 1000 { x /= 1000; i += 1 }
        let suffix: String
        if i < units.count {
            suffix = units[i]
        } else {
            let n = i - units.count
            let a = Character(UnicodeScalar(97 + (n / 26) % 26)!)
            let b = Character(UnicodeScalar(97 + n % 26)!)
            suffix = String([a, b])
        }
        let digits = x < 10 ? 2 : (x < 100 ? 1 : 0)
        return String(format: "%.\(digits)f", x) + suffix
    }
}
