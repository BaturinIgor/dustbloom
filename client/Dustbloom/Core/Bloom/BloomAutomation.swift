import Foundation

/// A garden hut on one owned island. A little helper inside gathers that island's things on its own,
/// online and offline, until the hut is full; the player drops by to collect.
struct HutState: Codable {
    var level: Int
    var since: Date
}

/// Stage 7a: garden huts, auto-repeat crafting and waystones.
extension BloomGame {
    static let hutMaxLevel = 3

    var hutsUnlocked: Bool { s.level >= BloomBalance.shared.huts.level }
    func hut(_ island: Int) -> HutState? { s.huts[String(island)] }
    var hutCount: Int { s.huts.count }

    /// Price of building (level 0 -> 1) or upgrading the hut: coins plus a few things.
    func hutCost(_ island: Int) -> (coins: Int, items: Cost)? {
        let lv = hut(island)?.level ?? 0
        guard lv < BloomGame.hutMaxLevel else { return nil }
        let h = BloomBalance.shared.huts
        let next = min(island + 1, world.islands.count - 1)
        let base = max(80, islandPrice(next) / max(1, h.coinDiv))
        let coins = Int((Double(base) * h.coinMult[lv]).rounded(.up))
        return (coins, h.items[lv])
    }

    func hutInterval(_ lv: Int) -> Double { BloomBalance.shared.huts.interval[max(0, min(2, lv - 1))] }
    func hutCapSeconds(_ lv: Int) -> Double { BloomBalance.shared.huts.capHours[max(0, min(2, lv - 1))] * 3600 }

    /// 0...1: how full the hut is now.
    func hutFill(_ island: Int) -> Double {
        guard let h = hut(island) else { return 0 }
        return min(1, Date().timeIntervalSince(h.since) / hutCapSeconds(h.level))
    }

    /// What the hut holds right now: the island's gatherables by spawn weight, at their average drops.
    func hutStash(_ island: Int) -> [(BItem, Int)] {
        guard let h = hut(island) else { return [] }
        let secs = min(hutCapSeconds(h.level), max(0, Date().timeIntervalSince(h.since)))
        var picks = secs / hutInterval(h.level)
        if passActive { picks *= 1 + BloomBalance.shared.huts.passBonus }
        let spawn = self.island(island).spawn
        let total = Double(spawn.values.reduce(0, +))
        guard total > 0 else { return [] }
        var sum: [BItem: Double] = [:]
        for (k, w) in spawn {
            guard let g = GatherKind(rawValue: k) else { continue }
            for d in g.drops { sum[d.item, default: 0] += picks * Double(w) / total * d.chance * Double(d.min + d.max) / 2 }
        }
        return sum.map { ($0.key, Int($0.value)) }.filter { $0.1 > 0 }.sorted { $0.0.rawValue < $1.0.rawValue }
    }

    var anyHutFull: Bool { s.huts.keys.contains { Int($0).map { hutFill($0) >= 1 } ?? false } }

    func collectHut(_ island: Int) {
        guard var h = hut(island) else { return }
        let got = hutStash(island)
        guard !got.isEmpty else { Sfx.play(.error); return }
        for (i, n) in got { add(i, n) }
        h.since = Date()
        s.huts[String(island)] = h
        bump("hut.collect")
        Sfx.play(.chest)
        showToast(BloomToast(title: tr("Домик собрал урожай"), subtitle: got.prefix(4).map { "+\($0.1) \($0.0.title)" }.joined(separator: ", ")))
        onHutChanged?(island)
        save()
    }

    func canAffordHut(_ island: Int) -> Bool {
        guard let c = hutCost(island) else { return false }
        return s.coins >= c.coins && has(c.items)
    }

    /// Builds or upgrades. What was gathered so far is collected first, so an upgrade never loses anything.
    func upgradeHut(_ island: Int) {
        guard hutsUnlocked, owned.contains(island), let c = hutCost(island), s.coins >= c.coins, has(c.items) else { Sfx.play(.error); return }
        if hut(island) != nil, !hutStash(island).isEmpty { collectHut(island) }
        s.coins -= c.coins
        for (i, n) in c.items { s.inv[i.rawValue, default: 0] -= n }
        let lv = (hut(island)?.level ?? 0) + 1
        s.huts[String(island)] = HutState(level: lv, since: Date())
        bump("hut.build")
        Analytics.shared.track("bloom_hut", ["island": island, "level": lv, "player": s.level])
        Sfx.play(.levelUp)
        showToast(BloomToast(title: lv == 1 ? tr("Домик построен!") : tr("Домик улучшен!"),
                             subtitle: tr("Помощник собирает сам, даже когда ты не в игре")))
        onHutChanged?(island)
        save()
    }

    // MARK: - auto-repeat crafting

    var autoCraftUnlocked: Bool { s.level >= BloomBalance.shared.autoCraftLevel }
    func autoCraftOn(_ b: BuildKind) -> Bool { s.autoCraft.contains(b.rawValue) }

    func toggleAutoCraft(_ b: BuildKind) {
        guard autoCraftUnlocked else { Sfx.play(.error); return }
        if let i = s.autoCraft.firstIndex(of: b.rawValue) { s.autoCraft.remove(at: i) } else { s.autoCraft.append(b.rawValue) }
        Sfx.play(.select)
        save()
    }

    /// When a queue runs dry and auto is on, one more of the same recipe goes in if there is enough.
    func autoRefill(_ b: BuildKind, _ q: inout CraftQueue, _ r: Recipe) {
        guard q.left == 0, autoCraftUnlocked, autoCraftOn(b), has(r.cost) else { return }
        for (i, n) in r.cost { s.inv[i.rawValue, default: 0] -= n }
        q.left = 1
    }

    // MARK: - waystones

    var waystonesUnlocked: Bool { s.owned.count >= 3 }

    func teleport(to island: Int) {
        guard owned.contains(island) else { return }
        panel = nil
        bump("teleport")
        onTeleport?(island)
    }
}
