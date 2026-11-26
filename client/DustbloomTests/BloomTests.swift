import XCTest
@testable import Dustbloom

@MainActor
final class BloomTests: XCTestCase {
    func testWorldLoadsAndStartIslandIsFree() {
        let w = BloomWorld.load()
        XCTAssertEqual(w.islands.count, 6)
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
        XCTAssertGreaterThanOrEqual(base, 2)
        XCTAssertGreaterThanOrEqual(boosted, 6)
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
