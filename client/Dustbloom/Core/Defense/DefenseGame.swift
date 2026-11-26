import Foundation
import SwiftUI

/// Saved Farm Defense progress (UserDefaults now, Supabase cloud save later).
struct DefenseProgress: Codable, Equatable {
    var coins: Double = 0
    var seeds: Double = 0
    var heroLevels: [Int] = [1, 1, 0, 0]
    var cropLevels: [Int] = [1, 0, 0, 0]
    var wave: Int = 1
    var maxWave: Int = 0
    var lastSeen: Date = Date()
    var kills: Int = 0
}

/// Owns the battle and the economy; the HUD observes it, the scene drives it.
@MainActor
final class DefenseGame: ObservableObject {
    struct OfflineReward: Identifiable, Equatable {
        let id = UUID()
        let seconds: Double
        let capSeconds: Double
        let coins: Double
        let seeds: Double
    }

    let balance: DefenseBalance
    let battle: Battle
    @Published private(set) var progress: DefenseProgress
    @Published var offline: OfflineReward?
    @Published var fast = false { didSet { battle.speed = fast ? 2 : 1 } }
    @Published var autoSkills = false { didSet { battle.autoSkills = autoSkills } }
    /// HUD mirrors of the battle, refreshed a few times per second (not per frame).
    @Published private(set) var fence = 1.0
    @Published private(set) var waveProgress = 0.0
    @Published private(set) var skillCharge: [Double] = Array(repeating: 0, count: DefenseContent.heroes.count)
    @Published private(set) var lostWave: Int?

    private static let key = "defense.progress.v1"

    init(balance: DefenseBalance = .load()) {
        self.balance = balance
        var p = DefenseProgress()
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(DefenseProgress.self, from: data) {
            p = saved
        }
        // test hook: "-defenseDemo N" starts at wave N with a squad strong enough for it
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-defenseDemo"), i + 1 < args.count, let w = Int(args[i + 1]) {
            p = DefenseProgress()
            p.wave = w
            p.maxWave = w - 1
            p.coins = 1e4
            p.seeds = 1e4
            var lvl = 1
            while balance.heroBaseDps * 4.5 * balance.levelMult(lvl) < balance.requiredDPS(w) * 0.9 { lvl += 1 }
            p.heroLevels = DefenseContent.heroes.map { w + 1 >= $0.unlockWave ? lvl : 0 }
            p.cropLevels = DefenseContent.crops.map { w + 1 >= $0.unlockWave ? lvl : 0 }
            p.lastSeen = Date().addingTimeInterval(-3 * 3600)
        }
        progress = p
        battle = Battle(balance: balance, wave: p.wave)
        battle.setSquad(heroLevels: p.heroLevels, cropLevels: p.cropLevels)
        battle.onWaveEnd = { [weak self] wave, won in
            MainActor.assumeIsolated { self?.waveEnded(wave, won: won) }
        }
        computeOffline(now: Date())
    }

    // MARK: - numbers for the HUD

    var land: Int { balance.land(of: battle.wave) }
    var landName: String { DefenseContent.text(DefenseContent.landNames[min(land, 8) - 1]) }
    var waveInLand: Int { balance.inLand(battle.wave) }
    var isBossWave: Bool { balance.isBoss(battle.wave) }

    func heroCost(_ i: Int) -> Double { balance.levelCost(progress.heroLevels[i] + 1) }
    func cropCost(_ i: Int) -> Double { balance.levelCost(progress.cropLevels[i] + 1) }

    func heroUnlocked(_ i: Int) -> Bool { progress.maxWave + 1 >= DefenseContent.heroes[i].unlockWave }
    func cropUnlocked(_ i: Int) -> Bool { progress.maxWave + 1 >= DefenseContent.crops[i].unlockWave }

    func heroDPS(_ i: Int, level: Int? = nil) -> Double {
        balance.heroBaseDps * DefenseContent.heroes[i].dpsFactor * balance.levelMult(level ?? progress.heroLevels[i])
    }

    func cropDPS(_ i: Int, level: Int? = nil) -> Double {
        balance.cropBaseDps * DefenseContent.crops[i].dpsFactor * balance.levelMult(level ?? progress.cropLevels[i])
    }

    /// "Power" shown next to the avatar: total damage per second.
    var power: Double { battle.totalDPS }

    // MARK: - actions

    @discardableResult
    func upgradeHero(_ i: Int) -> Bool {
        guard heroUnlocked(i) else { return false }
        let c = heroCost(i)
        guard progress.coins >= c else { return false }
        progress.coins -= c
        progress.heroLevels[i] += 1
        squadChanged()
        return true
    }

    @discardableResult
    func upgradeCrop(_ i: Int) -> Bool {
        guard cropUnlocked(i) else { return false }
        let c = cropCost(i)
        guard progress.seeds >= c else { return false }
        progress.seeds -= c
        progress.cropLevels[i] += 1
        squadChanged()
        return true
    }

    func useSkill(_ hero: Int) { battle.useSkill(hero) }

    func retryNext() {
        battle.retryNext()
        lostWave = nil
    }

    func collectOffline(double: Bool) {
        guard let r = offline else { return }
        let k = double ? 2.0 : 1.0
        progress.coins += r.coins * k
        progress.seeds += r.seeds * k
        offline = nil
        save()
    }

    // MARK: - battle hooks (called by the scene)

    func earned(coins: Double) {
        progress.coins += coins
        progress.seeds += coins * balance.seedShare
        progress.kills += 1
    }

    /// Called ~8 times a second by the scene to refresh HUD mirrors.
    func syncHUD() {
        let f = battle.fence / Battle.fenceMax
        if abs(f - fence) > 0.004 { fence = f }
        let w = battle.spawnedFraction
        if abs(w - waveProgress) > 0.01 || (w == 0 && waveProgress != 0) { waveProgress = w }
        let charges = DefenseContent.heroes.indices.map { battle.skillCharge($0) }
        if charges.enumerated().contains(where: { abs($0.element - skillCharge[$0.offset]) > 0.01 }) {
            skillCharge = charges
        }
    }

    private func waveEnded(_ wave: Int, won: Bool) {
        if won {
            progress.maxWave = max(progress.maxWave, wave)
            lostWave = nil
        } else {
            lostWave = wave
        }
        progress.wave = battle.wave
        objectWillChange.send()
        save()
        // a new hero or crop may have unlocked
        squadChanged()
    }

    private func squadChanged() {
        var heroes = progress.heroLevels
        for i in heroes.indices where heroUnlocked(i) && heroes[i] == 0 { heroes[i] = 1 }
        var crops = progress.cropLevels
        for i in crops.indices where cropUnlocked(i) && crops[i] == 0 { crops[i] = 1 }
        if heroes != progress.heroLevels { progress.heroLevels = heroes }
        if crops != progress.cropLevels { progress.cropLevels = crops }
        battle.setSquad(heroLevels: progress.heroLevels, cropLevels: progress.cropLevels)
    }

    // MARK: - offline and saving

    func computeOffline(now: Date) {
        let away = now.timeIntervalSince(progress.lastSeen)
        guard away > 120, progress.maxWave > 0 else { return }
        let cap = balance.offlineCap(land: balance.land(of: progress.maxWave)) * 3600
        let t = min(away, cap)
        let coins = balance.farmCoinsPerSecond(progress.maxWave) * t * balance.offlineEfficiency
        offline = OfflineReward(seconds: away, capSeconds: cap, coins: coins, seeds: coins * balance.seedShare)
    }

    func save() {
        progress.lastSeen = Date()
        progress.wave = battle.wave
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func resume() { computeOffline(now: Date()) }
}
