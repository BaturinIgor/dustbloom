import XCTest
@testable import Dustbloom

@MainActor
final class BloomTests: XCTestCase {
    // tests run inside the app host: start every BloomGame from a clean save,
    // not from whatever the last simulator session left behind
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "bloom.save.v2")
    }

    func testWorldLoadsAndStartIslandIsFree() {
        let w = BloomWorld.load()
        XCTAssertEqual(w.islands.count, 12)
        XCTAssertEqual(w.islands[0].price, 0)
        XCTAssertTrue(w.islands.dropFirst().allSatisfy { $0.price > 0 })
        for b in w.bridges {
            XCTAssertNotEqual(b.a, b.b)
        }
    }

    func testComboGrowsAndBreaks() {
        let g = BloomGame()
        var t: TimeInterval = 100
        for _ in 0..<(BloomContent.hitsPerStep * 2) { _ = g.registerHit(now: t); t += 0.3 }
        XCTAssertEqual(g.comboStep, 3)
        _ = g.registerHit(now: t + 5)
        XCTAssertEqual(g.combo, 1)
        XCTAssertEqual(g.comboStep, 1)
    }

    func testComboAddsDrops() {
        let g = BloomGame()
        let base = g.roll(.rock, mult: 1).first!.1
        let boosted = g.roll(.rock, mult: 5).first!.1
        let minDrop = GatherKind.rock.drops[0].min
        XCTAssertGreaterThanOrEqual(base, minDrop)
        XCTAssertGreaterThanOrEqual(boosted, minDrop + 4 / BloomBalance.shared.comboBonusDiv)
    }

    func testBalanceFileLoads() {
        let b = BloomBalance.shared
        XCTAssertEqual(b.islandPrices.count, 12)
        XCTAssertEqual(b.goals.count, 46)
        XCTAssertEqual(BloomContent.picks.count, 6)
        XCTAssertTrue(GatherKind.allCases.allSatisfy { b.gather[$0] != nil })
        XCTAssertFalse(BuildKind.furnace.recipes.isEmpty)
        XCTAssertEqual(BuildKind.loom.recipes.map(\.id), ["cloth"])
    }

    func testMarketNeverEatsItemsForNothing() {
        let g = BloomGame()
        g.add(.wood, 1)
        let coins = g.coins
        g.sell(.wood, all: true)
        if g.coins == coins { XCTAssertEqual(g.count(.wood), 1) }
    }

    func testFurnaceCraftsOverTime() {
        let g = BloomGame()
        g.add(.stone, 6)
        let r = BuildKind.furnace.recipes[0]
        let before = g.count(.brick)
        g.craft(.furnace, r, times: 2)
        XCTAssertEqual(g.count(.stone), 0)
        g.tick(dt: r.seconds + 0.01)
        XCTAssertEqual(g.count(.brick), before + 1)
        g.tick(dt: r.seconds + 0.01)
        XCTAssertEqual(g.count(.brick), before + 2)
    }

    func testLevelUp() {
        let g = BloomGame()
        let l = g.level
        g.gainXP(BloomContent.xpToNext(l))
        XCTAssertEqual(g.level, l + 1)
    }
}
