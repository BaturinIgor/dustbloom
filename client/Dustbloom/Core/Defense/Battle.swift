import Foundation

/// The Dust Storm battle as pure logic, no SpriteKit: enemies walk down three
/// lanes from the wasteland (progress 0) to the farm fence (progress 1);
/// scarecrows at the fence and crops behind it shoot them. The scene only
/// draws what this reports through `events`, so the battle is testable and
/// runs the same at any frame rate (fixed 1/60 s steps).
final class Battle {
    struct Enemy {
        let id: Int
        let kind: DefenseContent.EnemyKind
        let lane: Int
        let jitter: Double        // sideways offset inside the lane, -1...1
        var progress: Double      // 0 spawn ... 1 fence
        var hp: Double
        let maxHP: Double
        var slowUntil: Double = 0
        var slow: Double = 0
        var stunUntil: Double = 0
        var alive = true
        let isBoss: Bool
        var spawnAt: Double

        var spawned: Bool { progress >= 0 }
    }

    struct Shooter {
        enum Source { case hero(Int), crop(Int) }
        let source: Source
        var dps: Double
        let interval: Double
        let range: Double
        let melee: Bool
        let splash: Bool
        let projectile: DefenseContent.Projectile
        let slow: Double
        let fenceHeal: Double
        let coinBonus: Double
        var cooldown: Double
    }

    enum Event {
        case waveStart(wave: Int, boss: Bool)
        case spawn(enemy: Int)
        /// A shot leaves `from` and lands on `enemy` after `delay` seconds.
        case shot(from: Shooter.Source, enemy: Int, projectile: DefenseContent.Projectile, delay: Double)
        case melee(from: Shooter.Source)
        case damage(enemy: Int, amount: Double, crit: Bool, delay: Double)
        case death(enemy: Int, coins: Double, delay: Double)
        case fenceHit(enemy: Int)
        case skill(hero: Int)
        case waveCleared(wave: Int, coins: Double)
        case waveFailed(wave: Int)
    }

    static let step = 1.0 / 60
    static let fenceMax = 100.0
    static let critChance = 0.1
    static let critMult = 2.5
    /// Projectile flight speed in field lengths per second.
    static let shotSpeed = 1.8

    let balance: DefenseBalance
    private(set) var wave: Int
    private(set) var enemies: [Enemy] = []
    private(set) var shooters: [Shooter] = []
    private(set) var fence = Battle.fenceMax
    private(set) var time = 0.0
    private(set) var events: [Event] = []
    private(set) var skillReadyAt: [Double]
    private(set) var waveCoins = 0.0
    private var nextId = 1
    private var acc = 0.0
    private var rng: SplitMix
    private var betweenWaves = 0.0
    /// Damage multiplier on top of levels (stars, gear, talents, Harvest).
    var accountMult = 1.0
    /// When false the battle replays `wave` instead of moving on (after a loss).
    var autoAdvance = true
    var speed = 1.0
    var autoSkills = false
    var onWaveEnd: ((_ wave: Int, _ won: Bool) -> Void)?

    init(balance: DefenseBalance, wave: Int, seed: UInt64 = UInt64(Date().timeIntervalSince1970)) {
        self.balance = balance
        self.wave = max(1, wave)
        self.rng = SplitMix(seed: seed)
        self.skillReadyAt = Array(repeating: 0, count: DefenseContent.heroes.count)
        startWave()
    }

    // MARK: - squad

    /// Rebuilds shooters from levels; keeps cooldowns so upgrades mid-wave are smooth.
    func setSquad(heroLevels: [Int], cropLevels: [Int]) {
        var out: [Shooter] = []
        for (i, h) in DefenseContent.heroes.enumerated() where i < heroLevels.count && heroLevels[i] > 0 {
            let dps = balance.heroBaseDps * h.dpsFactor * balance.levelMult(heroLevels[i]) * accountMult
            out.append(Shooter(source: .hero(i), dps: dps, interval: h.interval, range: h.range, melee: h.melee,
                               splash: h.splash, projectile: h.projectile, slow: h.slow, fenceHeal: 0,
                               coinBonus: 0, cooldown: Double(i) * 0.13))
        }
        for (i, c) in DefenseContent.crops.enumerated() where i < cropLevels.count && cropLevels[i] > 0 {
            let dps = balance.cropBaseDps * c.dpsFactor * balance.levelMult(cropLevels[i]) * accountMult
            out.append(Shooter(source: .crop(i), dps: dps, interval: c.interval, range: c.range, melee: false,
                               splash: false, projectile: c.projectile, slow: c.slow, fenceHeal: c.fenceHeal,
                               coinBonus: c.coinBonus, cooldown: 0.3 + Double(i) * 0.17))
        }
        for i in out.indices {
            if let old = shooters.first(where: { same($0.source, out[i].source) }) { out[i].cooldown = old.cooldown }
        }
        shooters = out
    }

    var totalDPS: Double { shooters.reduce(0) { $0 + $1.dps } }

    // MARK: - loop

    /// Advances real time; returns and clears the events since the last call.
    func update(_ dt: Double) -> [Event] {
        acc += min(dt, 0.25) * speed
        while acc >= Battle.step {
            acc -= Battle.step
            tick(Battle.step)
        }
        let out = events
        events.removeAll(keepingCapacity: true)
        return out
    }

    private func tick(_ dt: Double) {
        time += dt
        if betweenWaves > 0 {
            betweenWaves -= dt
            if betweenWaves <= 0 { startWave() }
            return
        }
        moveEnemies(dt)
        fire(dt)
        if autoSkills {
            for i in skillReadyAt.indices where canUseSkill(i) && enemies.contains(where: { $0.alive && $0.spawned }) {
                useSkill(i)
            }
        }
        checkWaveEnd()
    }

    private func moveEnemies(_ dt: Double) {
        let base = 1 / balance.killWindowSeconds
        for i in enemies.indices where enemies[i].alive {
            if enemies[i].progress < 0 {
                if time >= enemies[i].spawnAt {
                    enemies[i].progress = 0
                    events.append(.spawn(enemy: enemies[i].id))
                }
                continue
            }
            if time < enemies[i].stunUntil { continue }
            let slow = time < enemies[i].slowUntil ? enemies[i].slow : 0
            if enemies[i].progress < 1 {
                enemies[i].progress = min(1, enemies[i].progress + base * enemies[i].kind.speed * (1 - slow) * dt)
                if enemies[i].progress >= 1 { events.append(.fenceHit(enemy: enemies[i].id)) }
            } else {
                fence -= enemies[i].kind.fenceDps * dt
            }
        }
    }

    private func targetable(_ e: Enemy, range: Double, melee: Bool) -> Bool {
        guard e.alive, e.spawned else { return false }
        if e.kind.burrows && e.progress < 0.5 { return false }
        if melee && e.kind.flying && !e.isBoss && e.progress < 0.97 { return false }
        return e.progress >= 1 - range
    }

    private func fire(_ dt: Double) {
        for s in shooters.indices {
            shooters[s].cooldown -= dt
            guard shooters[s].cooldown <= 0 else { continue }
            let sh = shooters[s]
            // closest to the fence first
            var best = -1
            var bestP = -1.0
            for i in enemies.indices where targetable(enemies[i], range: sh.range, melee: sh.melee) {
                if enemies[i].progress > bestP { bestP = enemies[i].progress; best = i }
            }
            guard best >= 0 else { shooters[s].cooldown = 0.05; continue }
            shooters[s].cooldown = sh.interval
            let dmgBase = sh.dps * sh.interval
            if sh.melee {
                events.append(.melee(from: sh.source))
                let targets = sh.splash
                    ? enemies.indices.filter { targetable(enemies[$0], range: sh.range, melee: true) }
                    : [best]
                for t in targets { hit(t, dmgBase, by: sh, delay: 0.12) }
            } else {
                let delay = max(0.08, (1 - enemies[best].progress + 0.15) / Battle.shotSpeed)
                events.append(.shot(from: sh.source, enemy: enemies[best].id, projectile: sh.projectile, delay: delay))
                hit(best, dmgBase, by: sh, delay: delay)
            }
        }
    }

    private func hit(_ i: Int, _ base: Double, by sh: Shooter, delay: Double) {
        let crit = rng.next() < Battle.critChance
        let dmg = base * (crit ? Battle.critMult : 1)
        damage(i, dmg, crit: crit, delay: delay, coinBonus: sh.coinBonus)
        if sh.slow > 0 {
            enemies[i].slow = max(enemies[i].slow, sh.slow)
            enemies[i].slowUntil = time + 2
        }
        if sh.fenceHeal > 0 { fence = min(Battle.fenceMax, fence + sh.fenceHeal) }
    }

    private func damage(_ i: Int, _ dmg: Double, crit: Bool, delay: Double, coinBonus: Double = 0) {
        guard enemies[i].alive else { return }
        enemies[i].hp -= dmg
        events.append(.damage(enemy: enemies[i].id, amount: dmg, crit: crit, delay: delay))
        if enemies[i].hp <= 0 {
            enemies[i].alive = false
            let share = enemies[i].maxHP / max(1, balance.waveHP(wave))
            let coins = balance.waveCoins(wave) * share * (1 + coinBonus)
            waveCoins += coins
            events.append(.death(enemy: enemies[i].id, coins: coins, delay: delay))
        }
    }

    // MARK: - skills

    func canUseSkill(_ hero: Int) -> Bool {
        guard hero < skillReadyAt.count, betweenWaves <= 0,
              shooters.contains(where: { if case .hero(hero) = $0.source { return true }; return false })
        else { return false }
        return time >= skillReadyAt[hero]
    }

    /// 0 = ready, 1 = just used.
    func skillCharge(_ hero: Int) -> Double {
        let cd = DefenseContent.heroes[hero].skillCooldown
        return max(0, min(1, (skillReadyAt[hero] - time) / cd))
    }

    func useSkill(_ hero: Int) {
        guard canUseSkill(hero),
              let sh = shooters.first(where: { if case .hero(hero) = $0.source { return true }; return false })
        else { return }
        let kind = DefenseContent.heroes[hero]
        skillReadyAt[hero] = time + kind.skillCooldown
        events.append(.skill(hero: hero))
        let live = enemies.indices.filter { enemies[$0].alive && enemies[$0].spawned }
        switch kind.skill {
        case .wall:
            fence = min(Battle.fenceMax, fence + 40)
            for i in live where enemies[i].progress > 0.8 {
                enemies[i].progress = max(0.55, enemies[i].progress - 0.25)
                damage(i, sh.dps * 3, crit: false, delay: 0.1)
            }
        case .arrowRain:
            for k in 0..<12 {
                guard let i = live.filter({ enemies[$0].alive }).randomElement(using: &rng) else { break }
                let d = 0.25 + Double(k) * 0.06
                events.append(.shot(from: .hero(hero), enemy: enemies[i].id, projectile: .arrow, delay: d))
                damage(i, sh.dps * 1.5, crit: true, delay: d)
            }
        case .smash:
            for i in live where enemies[i].progress > 0.6 {
                enemies[i].stunUntil = time + 2.5
                damage(i, sh.dps * 8, crit: true, delay: 0.15)
            }
        case .blizzard:
            for i in live {
                enemies[i].slow = 0.6
                enemies[i].slowUntil = time + 5
                damage(i, sh.dps * 3, crit: false, delay: 0.2)
            }
        }
    }

    // MARK: - waves

    var waveInProgress: Bool { betweenWaves <= 0 }
    var aliveCount: Int { enemies.reduce(0) { $0 + ($1.alive ? 1 : 0) } }
    var spawnedFraction: Double {
        guard !enemies.isEmpty else { return 0 }
        let done = enemies.filter { !$0.alive }.count
        return Double(done) / Double(enemies.count)
    }

    private func startWave() {
        enemies.removeAll(keepingCapacity: true)
        fence = Battle.fenceMax
        waveCoins = 0
        let b = balance
        let inLand = b.inLand(wave)
        let boss = b.isBoss(wave)
        let pool = DefenseContent.enemies.filter { $0.firstWave <= inLand }
        var kinds: [DefenseContent.EnemyKind] = []
        // a crowd sells the fight: many small enemies, same total HP and coins
        let count = boss ? 8 + min(8, inLand / 12) : 12 + min(24, inLand / 4)
        for _ in 0..<count { kinds.append(pool[Int(rng.next() * Double(pool.count)) % pool.count]) }
        if boss { kinds.append(DefenseContent.boss) }
        let total = kinds.reduce(0) { $0 + $1.hpWeight * (b.isLandBoss(wave) && $1.id == "queen" ? 2 : 1) }
        let hp = b.waveHP(wave)
        let spread = 11.0
        for (k, kind) in kinds.enumerated() {
            let isBoss = kind.id == DefenseContent.boss.id
            let w = kind.hpWeight * (b.isLandBoss(wave) && isBoss ? 2 : 1)
            let ehp = hp * w / total
            // enemies come in packs of three, a beat apart, so the field fills with groups
            let pack = Double(k / 3 * 3) / Double(max(1, count))
            let at = isBoss ? time + spread * 0.6 : time + spread * pack + rng.next() * 0.9
            enemies.append(Enemy(id: nextId, kind: kind, lane: isBoss ? 1 : Int(rng.next() * 3) % 3,
                                 jitter: isBoss ? 0 : rng.next() * 2 - 1, progress: -1, hp: ehp, maxHP: ehp,
                                 isBoss: isBoss, spawnAt: at))
            nextId += 1
        }
        events.append(.waveStart(wave: wave, boss: boss))
    }

    private func checkWaveEnd() {
        if fence <= 0 {
            let lost = wave
            events.append(.waveFailed(wave: lost))
            for i in enemies.indices { enemies[i].alive = false }
            autoAdvance = false
            onWaveEnd?(lost, false)
            wave = max(1, wave - 1)
            betweenWaves = 2.0
            return
        }
        if !enemies.isEmpty && !enemies.contains(where: { $0.alive }) {
            events.append(.waveCleared(wave: wave, coins: waveCoins))
            onWaveEnd?(wave, true)
            if autoAdvance && wave < balance.totalWaves { wave += 1 }
            betweenWaves = 1.2
        }
    }

    /// Player pressed "storm the next wave" after a loss.
    func retryNext() {
        autoAdvance = true
        if betweenWaves > 0, wave < balance.totalWaves { wave += 1 }
    }

    func enemy(id: Int) -> Enemy? { enemies.first { $0.id == id } }

    private func same(_ a: Shooter.Source, _ b: Shooter.Source) -> Bool {
        switch (a, b) {
        case let (.hero(x), .hero(y)), let (.crop(x), .crop(y)): return x == y
        default: return false
        }
    }
}

/// Small fast deterministic RNG so tests and replays are stable.
struct SplitMix: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in 0..<1.
    mutating func next() -> Double {
        let v: UInt64 = next()
        return Double(v >> 11) / Double(UInt64(1) << 53)
    }
}
