import Foundation

/// Reasons to come back: a 7-day login calendar, three daily quests and the
/// world rebirth ("Новая весна") with eternal upgrades bought for seeds.

struct DailyQuest: Codable, Equatable {
    let key: String       // lifetime counter, see BloomGame.bump
    let target: Int
    var base: Int         // counter value when the day started
    var claimed = false
}

/// One kind of daily quest. `needs` keeps it out of the draw until it can be done.
struct DailyKind {
    let key: String
    let title: String     // Russian source text with %@ for the target, goes through tr()
    let icon: String
    let base: Int         // target with one island; grows with islands
    let needs: (BloomGame) -> Bool
}

/// A reward of the login calendar.
struct LoginReward {
    let coins: Int        // in "coin units", see BloomGame.coinUnit
    let gems: Int
    let golden: Bool
    let chest: Bool
}

/// Eternal upgrade: survives every new spring.
struct Eternal: Identifiable {
    let id: String
    let title: String
    let text: String      // per level, %@ = percent
    let icon: String
    let step: Double      // bonus per level (0.1 = +10%)
    let max: Int
}

enum BloomMeta {
    static let dailyKinds: [DailyKind] = [
        DailyKind(key: "gather.tree", title: "Сруби %@ деревьев", icon: "bloom_tree", base: 25, needs: { _ in true }),
        DailyKind(key: "gather.rock", title: "Разбей %@ камней", icon: "bloom_rock", base: 25, needs: { _ in true }),
        DailyKind(key: "gather.bush", title: "Обери %@ кустов", icon: "bloom_bush_berry", base: 15, needs: { _ in true }),
        DailyKind(key: "item.flower", title: "Собери %@ цветов", icon: "bloom_item_flower", base: 12, needs: { _ in true }),
        DailyKind(key: "craft.brick", title: "Обожги %@ кирпичей", icon: "bloom_item_brick", base: 8, needs: { $0.isBuilt(.furnace) }),
        DailyKind(key: "craft.iron_bar", title: "Выплавь %@ железных слитков", icon: "bloom_item_iron_bar", base: 5,
                  needs: { $0.isBuilt(.furnace) && $0.owned.contains(2) }),
        DailyKind(key: "craft.cloth", title: "Сотки %@ ткани", icon: "bloom_item_cloth", base: 5, needs: { $0.isBuilt(.loom) }),
        DailyKind(key: "sold", title: "Заработай на рынке %@ монет", icon: "bloom_item_coin", base: 150, needs: { $0.isBuilt(.market) }),
        DailyKind(key: "chest", title: "Открой сундуков: %@", icon: "bloom_chest_closed", base: 2, needs: { _ in true }),
        DailyKind(key: "finds", title: "Найди находок для альбома: %@", icon: "bloom_ui_book", base: 2, needs: { _ in true }),
    ]

    static let login: [LoginReward] = [
        LoginReward(coins: 1, gems: 0, golden: false, chest: false),
        LoginReward(coins: 0, gems: 5, golden: false, chest: false),
        LoginReward(coins: 2, gems: 0, golden: false, chest: false),
        LoginReward(coins: 0, gems: 10, golden: false, chest: false),
        LoginReward(coins: 3, gems: 0, golden: false, chest: true),
        LoginReward(coins: 0, gems: 0, golden: true, chest: false),
        LoginReward(coins: 3, gems: 30, golden: false, chest: true),
    ]

    static let eternals: [Eternal] = [
        Eternal(id: "loot", title: "Щедрая земля", text: "+%@% шанс лишней добычи", icon: "bloom_item_wood", step: 0.1, max: 10),
        Eternal(id: "xp", title: "Мудрость весен", text: "+%@% опыта", icon: "bloom_ui_tree", step: 0.1, max: 10),
        Eternal(id: "coins", title: "Звонкая монета", text: "+%@% монет", icon: "bloom_item_coin", step: 0.1, max: 10),
        Eternal(id: "regrow", title: "Живая роса", text: "Всё отрастает на %@% быстрее", icon: "bloom_ui_fert", step: 0.08, max: 10),
        Eternal(id: "craft", title: "Ловкие руки", text: "Крафт на %@% быстрее", icon: "bloom_furnace_0", step: 0.08, max: 10),
        Eternal(id: "start", title: "Запас на весну", text: "+%@ монет в начале весны", icon: "bloom_chest_closed", step: 300, max: 10),
    ]

    static func eternal(_ id: String) -> Eternal { eternals.first { $0.id == id }! }

    /// Local calendar day, "2026-11-27".
    static func dayKey(_ d: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Small deterministic generator so the day's quests don't change on relaunch.
    struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
}

extension BloomGame {
    // MARK: - eternal upgrades

    func eternalLevel(_ id: String) -> Int { s.eternal[id] ?? 0 }
    /// Bonus fraction of an eternal upgrade (0.3 = +30%).
    func eternalBonus(_ id: String) -> Double { Double(eternalLevel(id)) * BloomMeta.eternal(id).step }
    func eternalMult(_ id: String) -> Double { 1 + eternalBonus(id) }
    func eternalCost(_ e: Eternal) -> Int { 2 + eternalLevel(e.id) * 2 }
    var seeds: Int { s.seeds }
    var springs: Int { s.springs }

    func buyEternal(_ e: Eternal) {
        let c = eternalCost(e)
        guard eternalLevel(e.id) < e.max, s.seeds >= c else { Sfx.play(.error); return }
        s.seeds -= c
        s.eternal[e.id, default: 0] += 1
        Analytics.shared.track("bloom_eternal", ["id": e.id, "level": eternalLevel(e.id), "springs": s.springs])
        Sfx.play(.levelUp)
        save()
    }

    // MARK: - new spring (rebirth)

    /// The world can be reborn once every island has bloomed.
    var canRebirth: Bool { s.owned.count >= world.islands.count }
    /// Seeds a new spring would give now.
    var rebirthSeeds: Int { s.level + s.owned.count * 2 + s.springs }
    var onRebirth: (() -> Void)?

    func rebirth() {
        guard canRebirth else { Sfx.play(.error); return }
        let got = rebirthSeeds
        Analytics.shared.track("bloom_rebirth", ["springs": s.springs + 1, "level": s.level, "seeds": got, "minutes": playMinutes])
        var n = BloomSave()
        // what a new spring keeps: purchases, album, calendar, dailies, lifetime stats, eternal tree
        n.gems = s.gems; n.founder = s.founder; n.passUntil = s.passUntil; n.jar = s.jar; n.jarTick = s.jarTick
        n.fertUntil = s.fertUntil; n.adReadyAt = s.adReadyAt; n.finds = s.finds
        n.life = s.life; n.loginDay = s.loginDay; n.loginClaimedOn = s.loginClaimedOn
        n.dailyDate = s.dailyDate; n.dailies = s.dailies; n.dailyBonus = s.dailyBonus
        n.eternal = s.eternal; n.bestLevel = s.bestLevel
        n.springs = s.springs + 1
        n.seeds = s.seeds + got
        n.coins = Int(eternalBonus("start"))
        // the founder's golden bloomling is a purchase, it comes back with the new spring
        s = n
        bump("springs")
        save()
        panel = nil
        onRebirth?()
    }

    // MARK: - login calendar

    var loginReady: Bool { s.loginClaimedOn != BloomMeta.dayKey() }
    var loginDay: Int { s.loginDay % BloomMeta.login.count }
    /// Tile i of this week is already collected.
    func loginDone(_ i: Int) -> Bool {
        if !loginReady && loginDay == 0 && s.loginDay > 0 { return true }   // the whole week just finished
        return i < loginDay
    }
    /// One "coin unit" of a reward: about half a coin sack, so rewards keep up with the islands.
    var coinUnit: Int { max(60, coinSack / 2) }

    func claimLogin() {
        guard loginReady else { return }
        let r = BloomMeta.login[loginDay]
        s.coins += r.coins * coinUnit
        s.gems += r.gems
        if r.chest {
            let c = openChest()
            s.coins += c.coins
            for (i, k) in c.items { add(i, k) }
        }
        if r.golden { onGoldenRequested?(BloomBalance.shared.shop.adGoldenSeconds) }
        Analytics.shared.track("bloom_login", ["day": loginDay + 1, "springs": s.springs])
        s.loginClaimedOn = BloomMeta.dayKey()
        s.loginDay += 1
        Sfx.play(.victory)
        save()
    }

    // MARK: - daily quests

    var dailies: [DailyQuest] { s.dailies }
    var dailyBonusClaimed: Bool { s.dailyBonus }

    /// Draws today's three quests if the day changed. Call on launch and on resume.
    func refreshDailies() {
        let today = BloomMeta.dayKey()
        guard s.dailyDate != today else { return }
        // String.hashValue changes every launch; the date digits do not
        var rng = BloomMeta.SeededRNG(state: UInt64(today.filter(\.isNumber)) ?? 1)
        let kinds = BloomMeta.dailyKinds.filter { $0.needs(self) }.shuffled(using: &rng).prefix(3)
        let scale = 1 + 0.35 * Double(max(0, s.owned.count - 1))
        s.dailies = kinds.map { k in
            let t = max(1, Int((Double(k.base) * scale).rounded()))
            return DailyQuest(key: k.key, target: k.key == "chest" || k.key == "finds" ? k.base : t, base: s.life[k.key] ?? 0)
        }
        s.dailyDate = today
        s.dailyBonus = false
        save()
    }

    func dailyKind(_ q: DailyQuest) -> DailyKind? { BloomMeta.dailyKinds.first { $0.key == q.key } }
    func dailyProgress(_ q: DailyQuest) -> Int { min(q.target, max(0, (s.life[q.key] ?? 0) - q.base)) }
    func dailyDone(_ q: DailyQuest) -> Bool { dailyProgress(q) >= q.target }
    var dailyReward: (coins: Int, gems: Int, xp: Int) { (coinUnit, 5, 10 + s.level * 2) }
    /// Badge count for the calendar button: things ready to collect.
    var dailyReadyCount: Int {
        (loginReady ? 1 : 0) + s.dailies.filter { !$0.claimed && dailyDone($0) }.count
            + (allDailiesClaimed && !s.dailyBonus ? 1 : 0)
    }
    var allDailiesClaimed: Bool { !s.dailies.isEmpty && s.dailies.allSatisfy(\.claimed) }

    func claimDaily(_ i: Int) {
        guard i < s.dailies.count, !s.dailies[i].claimed, dailyDone(s.dailies[i]) else { Sfx.play(.error); return }
        s.dailies[i].claimed = true
        let r = dailyReward
        s.coins += r.coins
        s.gems += r.gems
        Analytics.shared.track("bloom_daily", ["key": s.dailies[i].key, "springs": s.springs])
        Sfx.play(.chest)
        gainXP(r.xp)
        save()
    }

    func claimDailyBonus() {
        guard allDailiesClaimed, !s.dailyBonus else { return }
        s.dailyBonus = true
        s.gems += 15
        let c = openChest()
        s.coins += c.coins
        for (i, k) in c.items { add(i, k) }
        Analytics.shared.track("bloom_daily_bonus", ["springs": s.springs])
        Sfx.play(.victory)
        save()
    }
}
