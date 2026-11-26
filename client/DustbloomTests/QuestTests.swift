import XCTest
@testable import Dustbloom

/// Mirrors server/internal/game/quests_test.go.
final class QuestTests: XCTestCase {
    private var config: GameConfig!

    override func setUp() {
        super.setUp()
        config = GameConfig.load(from: Bundle(for: FarmStore.self))
    }

    func testConfigHasQuests() throws {
        let qc = try XCTUnwrap(config.quests)
        XCTAssertGreaterThanOrEqual(qc.list.count, 40)
        let farm = Farm(config: config)
        XCTAssertEqual(farm.activeQuests(config: config).count, qc.active)
    }

    func testClaimOnlyWhenDone() throws {
        var farm = Farm(config: config)
        let q = try XCTUnwrap(farm.activeQuests(config: config).first)
        XCTAssertThrowsError(try farm.claimQuest(q.id, config: config))
        farm.stats[q.goal] = q.count
        XCTAssertEqual(farm.claimableQuests(config: config), 1)
        let coins = farm.coins
        let r = try farm.claimQuest(q.id, config: config)
        XCTAssertEqual(farm.coins, coins + r.coins)
        XCTAssertFalse(farm.activeQuests(config: config).contains { $0.id == q.id })
        XCTAssertThrowsError(try farm.claimQuest(q.id, config: config))
    }

    func testActionsCount() throws {
        var farm = Farm(config: config)
        farm.coins = 10_000
        let i = try XCTUnwrap(farm.tiles.firstIndex { $0.tilled })
        let x = i % farm.width, y = i / farm.width
        let now = Date()
        try farm.plant(x: x, y: y, cropID: "dustwheat", now: now, config: config)
        let grow = config.crop("dustwheat")!.growSeconds
        _ = try farm.harvest(x: x, y: y, now: now.addingTimeInterval(TimeInterval(grow)), config: config)
        _ = try farm.sell(cropID: "dustwheat", count: 1, config: config)
        XCTAssertEqual(farm.stats["plant"], 1)
        XCTAssertEqual(farm.stats["harvest:dustwheat"], 1)
        XCTAssertEqual(farm.stats["sell"], 1)
    }

    func testEveryQuestHasText() throws {
        for q in try XCTUnwrap(config.quests).list {
            XCTAssertNotEqual(Quests.title(q, config: config), q.id, q.id)
        }
    }
}
