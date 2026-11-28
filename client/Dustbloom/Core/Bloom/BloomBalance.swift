import Foundation

/// All Bloom balance numbers, loaded from bloom_balance.json.
/// The same file drives tools/bloom_sim.py, so the bots and the game never disagree.
struct BloomBalance {
    struct Gather { let hp: Int; let xp: Int; let drops: [Drop] }
    struct Build { let level: Int; let cost: Cost }
    struct Craft { let at: String; let cost: Cost; let seconds: Double }
    struct Shop {
        var founderGems = 300, founderHelperPower = 3, founderRegrow = 0.3
        var passDrop = 0.25, passXP = 0.25
        var adGoldenSeconds = 180.0, adGoldenCooldown = 900.0
        var fertilizerGems = 40, fertilizerMinutes = 10.0, fertilizerMult = 2.0
        var gemCoins = 10
    }

    var xpBase = 20, xpLin = 20, xpQuad = 6
    var gather: [GatherKind: Gather] = [:]
    var prices: [BItem: Int] = [:]
    var sellRate = 1.0
    var coinChance = 0.28
    var respawnSeconds = 2.2, respawnPerIsland = 0.0
    var chestChance = 0.05, chestCooldown = 60.0, chestCoinsMin = 10, chestCoinsMax = 20, chestCoinsPerIsland = 8
    var goldenEvery = 240.0, goldenFirst = 75.0, goldenDuration = 25.0
    var critChance = 0.1
    var maxHelpers = 3
    var comboWindow = 1.1, hitsPerStep = 5, maxCombo = 5, comboBonusDiv = 1
    var islandPrices: [Int] = []
    var picks: [(damage: Int, cost: Cost)] = []
    var axes: [(bonus: Int, cost: Cost)] = []
    var shovelCost: Cost = []
    var digEvery = 40.0, digMax = 2
    var buildings: [BuildKind: Build] = [:]
    var recipes: [String: Craft] = [:]
    var helperCost: [(BItem, Int, Int)] = []
    var goals: [Goal] = []
    var shop = Shop()
    /// Garden huts (BloomAutomation.swift): per level 1...3.
    struct Huts { var level = 8; var interval = [90.0, 60, 40]; var capHours = [2.0, 4, 6]; var coinDiv = 8; var coinMult = [1.0, 2.5, 6]
        var items: [Cost] = [[(.wood, 25), (.stone, 15)], [(.brick, 10), (.wood, 30)], [(.iron_bar, 6), (.brick, 15)]]; var passBonus = 0.5 }
    var huts = Huts()
    var autoCraftLevel = 10

    static let shared: BloomBalance = {
        guard let url = Bundle.main.url(forResource: "bloom_balance", withExtension: "json")
                ?? Bundle(for: BundleToken.self).url(forResource: "bloom_balance", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { fatalError("bloom_balance.json missing") }
        return BloomBalance(root)
    }()

    private final class BundleToken {}

    init(_ j: [String: Any]) {
        func d(_ v: Any?) -> Double? { (v as? NSNumber)?.doubleValue }
        func i(_ v: Any?) -> Int? { (v as? NSNumber)?.intValue }
        func cost(_ v: Any?) -> Cost {
            ((v as? [[Any]]) ?? []).compactMap { e in
                guard let s = e.first as? String, let it = BItem(rawValue: s), let n = i(e.last) else { return nil }
                return (it, n)
            }
        }
        if let x = j["xp"] as? [String: Any] {
            xpBase = i(x["base"]) ?? xpBase; xpLin = i(x["lin"]) ?? xpLin; xpQuad = i(x["quad"]) ?? xpQuad
        }
        for (k, v) in (j["gather"] as? [String: [String: Any]]) ?? [:] {
            guard let g = GatherKind(rawValue: k) else { continue }
            let drops: [Drop] = ((v["drops"] as? [[Any]]) ?? []).compactMap { e in
                guard e.count == 4, let s = e[0] as? String, let it = BItem(rawValue: s),
                      let lo = i(e[1]), let hi = i(e[2]), let ch = d(e[3]) else { return nil }
                return Drop(item: it, min: lo, max: hi, chance: ch)
            }
            gather[g] = Gather(hp: i(v["hp"]) ?? 1, xp: i(v["xp"]) ?? 1, drops: drops)
        }
        for (k, v) in (j["prices"] as? [String: Any]) ?? [:] { if let it = BItem(rawValue: k), let n = i(v) { prices[it] = n } }
        sellRate = d(j["sellRate"]) ?? sellRate
        coinChance = d(j["coinChance"]) ?? coinChance
        respawnSeconds = d(j["respawnSeconds"]) ?? respawnSeconds
        respawnPerIsland = d(j["respawnPerIsland"]) ?? respawnPerIsland
        if let c = j["chest"] as? [String: Any] {
            chestChance = d(c["chance"]) ?? chestChance; chestCooldown = d(c["cooldown"]) ?? chestCooldown
            chestCoinsMin = i(c["coinsMin"]) ?? chestCoinsMin; chestCoinsMax = i(c["coinsMax"]) ?? chestCoinsMax
            chestCoinsPerIsland = i(c["coinsPerIsland"]) ?? chestCoinsPerIsland
        }
        if let g = j["golden"] as? [String: Any] {
            goldenEvery = d(g["every"]) ?? goldenEvery; goldenFirst = d(g["first"]) ?? goldenFirst
            goldenDuration = d(g["duration"]) ?? goldenDuration
        }
        critChance = d(j["critChance"]) ?? critChance
        maxHelpers = i(j["maxHelpers"]) ?? maxHelpers
        if let c = j["combo"] as? [String: Any] {
            comboWindow = d(c["window"]) ?? comboWindow; hitsPerStep = i(c["hitsPerStep"]) ?? hitsPerStep
            maxCombo = i(c["max"]) ?? maxCombo; comboBonusDiv = max(1, i(c["bonusDiv"]) ?? comboBonusDiv)
        }
        islandPrices = ((j["islandPrices"] as? [Any]) ?? []).compactMap { i($0) }
        picks = ((j["picks"] as? [[String: Any]]) ?? []).map { (i($0["damage"]) ?? 1, cost($0["cost"])) }
        axes = ((j["axes"] as? [[String: Any]]) ?? []).map { (i($0["bonus"]) ?? 0, cost($0["cost"])) }
        if let sh = j["shovel"] as? [String: Any] {
            shovelCost = cost(sh["cost"]); digEvery = d(sh["every"]) ?? digEvery; digMax = i(sh["max"]) ?? digMax
        }
        for (k, v) in (j["buildings"] as? [String: [String: Any]]) ?? [:] {
            if let b = BuildKind(rawValue: k) { buildings[b] = Build(level: i(v["level"]) ?? 1, cost: cost(v["cost"])) }
        }
        for (k, v) in (j["recipes"] as? [String: [String: Any]]) ?? [:] {
            recipes[k] = Craft(at: v["at"] as? String ?? "", cost: cost(v["cost"]), seconds: d(v["seconds"]) ?? 2)
        }
        for (k, v) in (j["helperCost"] as? [String: [Any]]) ?? [:] {
            if let it = BItem(rawValue: k), v.count == 2, let a = i(v[0]), let b = i(v[1]) { helperCost.append((it, a, b)) }
        }
        helperCost.sort { $0.0.rawValue < $1.0.rawValue }
        goals = ((j["goals"] as? [[String: Any]]) ?? []).map {
            Goal(title: tr($0["title"] as? String ?? ""), icon: $0["icon"] as? String ?? "", key: $0["key"] as? String ?? "",
                 target: i($0["target"]) ?? 1, coins: i($0["coins"]) ?? 0, xp: i($0["xp"]) ?? 0)
        }
        if let h = j["huts"] as? [String: Any] {
            huts.level = i(h["level"]) ?? huts.level
            huts.interval = (h["interval"] as? [NSNumber])?.map(\.doubleValue) ?? huts.interval
            huts.capHours = (h["capHours"] as? [NSNumber])?.map(\.doubleValue) ?? huts.capHours
            huts.coinDiv = i(h["coinDiv"]) ?? huts.coinDiv
            huts.coinMult = (h["coinMult"] as? [NSNumber])?.map(\.doubleValue) ?? huts.coinMult
            if let it = h["items"] as? [Any], it.count == 3 { huts.items = it.map { cost($0) } }
            huts.passBonus = d(h["passBonus"]) ?? huts.passBonus
        }
        autoCraftLevel = i(j["autoCraftLevel"]) ?? autoCraftLevel
        if let s = j["shop"] as? [String: Any] {
            if let f = s["founder"] as? [String: Any] {
                shop.founderGems = i(f["gems"]) ?? shop.founderGems
                shop.founderHelperPower = i(f["helperPower"]) ?? shop.founderHelperPower
                shop.founderRegrow = d(f["regrowBonus"]) ?? shop.founderRegrow
            }
            if let p = s["pass"] as? [String: Any] {
                shop.passDrop = d(p["dropBonus"]) ?? shop.passDrop; shop.passXP = d(p["xpBonus"]) ?? shop.passXP
            }
            if let a = s["adGolden"] as? [String: Any] {
                shop.adGoldenSeconds = d(a["duration"]) ?? shop.adGoldenSeconds
                shop.adGoldenCooldown = d(a["cooldown"]) ?? shop.adGoldenCooldown
            }
            if let f = s["fertilizer"] as? [String: Any] {
                shop.fertilizerGems = i(f["gems"]) ?? shop.fertilizerGems
                shop.fertilizerMinutes = d(f["minutes"]) ?? shop.fertilizerMinutes
                shop.fertilizerMult = d(f["mult"]) ?? shop.fertilizerMult
            }
            shop.gemCoins = i(s["gemCoins"]) ?? shop.gemCoins
        }
    }
}

extension Int {
    /// 12 500 → "12 500", 125 000 → "125K": readable at a glance, never wraps.
    var short: String {
        if self >= 100_000 { return "\(self / 1000)K" }
        if self >= 10_000 {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.groupingSeparator = "\u{2009}"
            return f.string(from: NSNumber(value: self)) ?? "\(self)"
        }
        return "\(self)"
    }
}

extension Int {
    /// For tiny labels (island signs): 950, 1K, 3.5K, 20K.
    var compact: String {
        if self < 1000 { return "\(self)" }
        let k = Double(self) / 1000
        return k < 10 && self % 1000 != 0 ? String(format: "%.1fK", k) : "\(self / 1000)K"
    }
}
