import XCTest
@testable import Dustbloom

/// Battle rules and the shared balance (same numbers as server/internal/defense).
final class DefenseTests: XCTestCase {
    private var balance: DefenseBalance!

    override func setUp() {
        super.setUp()
        balance = DefenseBalance.load(bundle: Bundle(for: DefenseGame.self))
    }

    /// Reference values printed by the Go balance code; both sides must agree.
    func testBalanceMatchesGo() {
        XCTAssertEqual(balance.waveHP(1), 480, accuracy: 0.5)
        XCTAssertEqual(balance.waveHP(10), 1548.472103, accuracy: 0.01)
        XCTAssertEqual(balance.waveHP(60), 65989.12588, accuracy: 0.1)
        XCTAssertEqual(balance.waveHP(121), 1147545.235, accuracy: 1)
        XCTAssertEqual(balance.waveHP(500) / 5.077931329e12, 1, accuracy: 1e-6)
        XCTAssertEqual(balance.waveCoins(60), 155.6023153, accuracy: 1e-4)
    }

    private func run(_ battle: Battle, seconds: Double) -> [Battle.Event] {
        var all: [Battle.Event] = []
        var t = 0.0
        while t < seconds {
            all += battle.update(0.1)
            t += 0.1
        }
        return all
    }

    func testStartingSquadClearsFirstWave() {
        let b = Battle(balance: balance, wave: 1, seed: 7)
        b.setSquad(heroLevels: [1, 1, 0, 0], cropLevels: [1, 0, 0, 0])
        let events = run(b, seconds: 60)
        XCTAssertTrue(events.contains { if case .waveCleared(1, _) = $0 { return true }; return false })
        XCTAssertGreaterThanOrEqual(b.wave, 2)
    }

    func testEmptySquadLosesAndStepsBack() {
        let b = Battle(balance: balance, wave: 5, seed: 7)
        b.setSquad(heroLevels: [0, 0, 0, 0], cropLevels: [0, 0, 0, 0])
        let events = run(b, seconds: 120)
        XCTAssertTrue(events.contains { if case .waveFailed(5) = $0 { return true }; return false })
        XCTAssertFalse(b.autoAdvance)
        XCTAssertLessThan(b.wave, 5)
    }

    func testKillCoinsAddUpToWaveReward() {
        let b = Battle(balance: balance, wave: 3, seed: 1)
        b.setSquad(heroLevels: [40, 40, 0, 0], cropLevels: [40, 0, 0, 0])
        var coins = 0.0
        var cleared: Double?
        for e in run(b, seconds: 40) {
            if case let .death(_, c, _) = e { coins += c }
            if case let .waveCleared(3, c) = e, cleared == nil { cleared = c }
        }
        let wave3 = try? XCTUnwrap(cleared)
        XCTAssertEqual(wave3 ?? 0, balance.waveCoins(3), accuracy: balance.waveCoins(3) * 0.001)
        XCTAssertGreaterThan(coins, 0)
    }

    func testSkillHasCooldown() {
        let b = Battle(balance: balance, wave: 1, seed: 3)
        b.setSquad(heroLevels: [1, 1, 0, 0], cropLevels: [1, 0, 0, 0])
        _ = run(b, seconds: 2)
        XCTAssertTrue(b.canUseSkill(0))
        b.useSkill(0)
        XCTAssertFalse(b.canUseSkill(0))
        XCTAssertGreaterThan(b.skillCharge(0), 0.9)
    }

    func testBigNumbers() {
        XCTAssertEqual(BigNumber.format(999), "999")
        XCTAssertEqual(BigNumber.format(12_400), "12.4K")
        XCTAssertEqual(BigNumber.format(3_100_000), "3.10M")
        XCTAssertEqual(BigNumber.format(2.2e15), "2.20aa")
    }
}
