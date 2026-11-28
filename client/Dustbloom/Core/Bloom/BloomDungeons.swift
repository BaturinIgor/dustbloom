import Foundation

/// A cave on one island: three rooms' worth of foes in waves, then a boss.
/// The first clear gives the cave's relic (a lasting bonus); later runs give coins and gems.
struct Dungeon: Identifiable {
    let id: String
    let island: Int
    let title: String
    let foe: String
    let relic: String
    let relicTitle: String
    let relicText: String
    /// Damage that makes the fight fair; shown as a hint, never a lock.
    let advisedDamage: Int
}

enum BloomDungeons {
    static let all: [Dungeon] = [
        Dungeon(id: "burrow", island: 1, title: "Пыльная нора", foe: "slime", relic: "fang",
                relicTitle: "Клык норы", relicText: "+1 к удару навсегда", advisedDamage: 2),
        Dungeon(id: "cave", island: 2, title: "Жучиная пещера", foe: "beetle", relic: "shell",
                relicTitle: "Панцирь жука", relicText: "+1 сердце навсегда", advisedDamage: 3),
        Dungeon(id: "crypt", island: 6, title: "Песчаный склеп", foe: "slime", relic: "clover",
                relicTitle: "Клевер удачи", relicText: "+25% монет с добычи", advisedDamage: 5),
        Dungeon(id: "grotto", island: 8, title: "Жабий грот", foe: "toad", relic: "feather",
                relicTitle: "Лёгкое перо", relicText: "+15% к скорости бега", advisedDamage: 7),
        Dungeon(id: "forge", island: 10, title: "Пепельная кузня", foe: "bat", relic: "eye",
                relicTitle: "Огненное око", relicText: "+8% к шансу крита", advisedDamage: 9),
    ]
    static func byId(_ id: String) -> Dungeon? { all.first { $0.id == id } }
}

extension BloomGame {
    func hasRelic(_ r: String) -> Bool { s.relics.contains(r) }

    static let reviveGems = 15
    /// One free get-up a day for a short video.
    var reviveAdReady: Bool { UserDefaults.standard.string(forKey: "dustbloom.reviveAd") != BloomMeta.dayKey() && RewardedAds.isAvailable }

    func answerRevive(gems: Bool) {
        guard reviveAsk else { return }
        if gems {
            guard s.gems >= BloomGame.reviveGems else { Sfx.play(.error); panel = .shop; return }
            _ = spend(BloomGame.reviveGems, "revive")
        }
        reviveAsk = false
        onRevive?(true)
    }

    func reviveWithAd() {
        RewardedAds.show { [weak self] ok in
            guard let self, ok, self.reviveAsk else { return }
            UserDefaults.standard.set(BloomMeta.dayKey(), forKey: "dustbloom.reviveAd")
            Analytics.shared.track("bloom_ad_revive", ["level": self.level])
            self.reviveAsk = false
            self.onRevive?(true)
        }
    }

    func declineRevive() {
        guard reviveAsk else { return }
        reviveAsk = false
        onRevive?(false)
    }
    func cleared(_ d: Dungeon) -> Bool { (s.dungeonRuns[d.id] ?? 0) > 0 }
    var relicCount: Int { s.relics.count }

    /// Called by the scene when the boss falls. Returns what was won, for the banner.
    func dungeonCleared(_ d: Dungeon) -> (relic: Bool, coins: Int, gems: Int) {
        let first = !cleared(d)
        s.dungeonRuns[d.id, default: 0] += 1
        bump("dungeon")
        var coins = 40 + d.island * 25 + level * 4
        var gems = first ? 5 : 1
        if first, !s.relics.contains(d.relic) { s.relics.append(d.relic) } else { coins = coins / 2; gems = Int.random(in: 0...1) }
        s.coins += coins
        s.gems += gems
        hp = maxHP
        Analytics.shared.track("bloom_dungeon", ["id": d.id, "first": first, "level": level])
        save()
        return (first, coins, gems)
    }
}
