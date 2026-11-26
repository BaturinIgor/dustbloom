import XCTest
@testable import Dustbloom

/// Mirrors server/internal/game/obstacles_test.go.
final class ObstacleTests: XCTestCase {
    private var config: GameConfig!

    override func setUp() {
        super.setUp()
        config = GameConfig.load(from: Bundle(for: FarmStore.self))
    }

    private func ownedObstacle(_ farm: inout Farm) -> (Int, Int)? {
        for i in farm.plots.indices { farm.plots[i] = true }
        for y in 0..<farm.height {
            for x in 0..<farm.width where farm.obstacle(x: x, y: y, config: config) != nil {
                return (x, y)
            }
        }
        return nil
    }

    func testObstacleBlocksTillingUntilCleared() throws {
        var farm = Farm(config: config)
        farm.coins = 1000
        let (x, y) = try XCTUnwrap(ownedObstacle(&farm))
        XCTAssertThrowsError(try farm.till(x: x, y: y, config: config)) {
            XCTAssertEqual($0 as? FarmError, .obstacle)
        }
        let kind = try XCTUnwrap(farm.obstacle(x: x, y: y, config: config))
        let cost = try XCTUnwrap(config.obstacles?[kind]).coins
        let result = try farm.clear(x: x, y: y, config: config)
        XCTAssertEqual(result.kind, kind)
        XCTAssertEqual(farm.coins, 1000 - cost)
        XCTAssertNil(farm.obstacle(x: x, y: y, config: config))
        XCTAssertNoThrow(try farm.till(x: x, y: y, config: config))
    }

    func testStartBedsAreClear() {
        let farm = Farm(config: config)
        let s = config.farm.startTilled
        for y in (s.y - 4)..<(s.y + s.height + 4) {
            for x in (s.x - 4)..<(s.x + s.width + 4) {
                XCTAssertNil(farm.obstacle(x: x, y: y, config: config), "\(x),\(y)")
            }
        }
    }
}
