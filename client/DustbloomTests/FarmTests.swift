import XCTest
@testable import Dustbloom

/// Mirrors server/internal/game/farm_test.go so both sides follow one set of rules.
final class FarmTests: XCTestCase {
    private var config: GameConfig!

    override func setUp() {
        super.setUp()
        config = GameConfig.load(from: Bundle(for: FarmStore.self))
    }

    func testNewFarmStartsWithTilledPatch() {
        let farm = Farm(config: config)
        XCTAssertEqual(farm.width, 16)
        XCTAssertEqual(farm.height, 16)
        let area = config.farm.startTilled
        XCTAssertEqual(farm.tiles.filter(\.tilled).count, area.width * area.height)
        XCTAssertEqual(farm.coins, config.farm.startCoins)
    }

    func testPlantGrowHarvest() throws {
        var farm = Farm(config: config)
        let wheat = try XCTUnwrap(config.crop("dustwheat"))
        let t0 = Date(timeIntervalSince1970: 1_000_000)

        try farm.plant(x: 6, y: 6, cropID: "dustwheat", now: t0, config: config)
        XCTAssertEqual(farm.coins, config.farm.startCoins - wheat.seedCost)
        XCTAssertThrowsError(try farm.plant(x: 6, y: 6, cropID: "dustwheat", now: t0, config: config)) {
            XCTAssertEqual($0 as? FarmError, .occupied)
        }
        XCTAssertThrowsError(try farm.harvest(x: 6, y: 6, now: t0.addingTimeInterval(10), config: config)) {
            XCTAssertEqual($0 as? FarmError, .notReady)
        }
        let result = try farm.harvest(x: 6, y: 6, now: t0.addingTimeInterval(Double(wheat.growSeconds)), config: config)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(farm.barn["dustwheat"], 1)
        XCTAssertNil(farm.tile(x: 6, y: 6)?.crop)
        XCTAssertEqual(try farm.sell(cropID: "dustwheat", count: 1, config: config), wheat.sellPrice)
        XCTAssertEqual(farm.coins, config.farm.startCoins - wheat.seedCost + wheat.sellPrice)
        XCTAssertTrue(farm.barn.isEmpty)
        XCTAssertThrowsError(try farm.sell(cropID: "dustwheat", count: 1, config: config)) {
            XCTAssertEqual($0 as? FarmError, .notEnoughCrops)
        }
    }

    func testPlantRules() {
        var farm = Farm(config: config)
        let now = Date()
        XCTAssertThrowsError(try farm.plant(x: 0, y: 0, cropID: "dustwheat", now: now, config: config)) {
            XCTAssertEqual($0 as? FarmError, .notTilled)
        }
        XCTAssertThrowsError(try farm.plant(x: 16, y: 0, cropID: "dustwheat", now: now, config: config)) {
            XCTAssertEqual($0 as? FarmError, .outOfBounds)
        }
        XCTAssertThrowsError(try farm.plant(x: 6, y: 6, cropID: "banana", now: now, config: config)) {
            XCTAssertEqual($0 as? FarmError, .unknownCrop)
        }
        farm.coins = 0
        XCTAssertThrowsError(try farm.plant(x: 6, y: 6, cropID: "dustwheat", now: now, config: config)) {
            XCTAssertEqual($0 as? FarmError, .notEnoughCoins)
        }
    }

    func testLevelCurve() {
        var farm = Farm(config: config)
        for (xp, level) in [(0, 1), (9, 1), (10, 2), (29, 2), (30, 3), (60, 4)] {
            farm.xp = xp
            XCTAssertEqual(farm.level, level, "xp \(xp)")
        }
    }

    func testStages() {
        XCTAssertEqual(Farm.stage(progress: 0), 0)
        XCTAssertEqual(Farm.stage(progress: 0.3), 1)
        XCTAssertEqual(Farm.stage(progress: 0.7), 2)
        XCTAssertEqual(Farm.stage(progress: 1), 3)
    }

    func testDecodesServerFarmJSON() throws {
        // Shape produced by the Go server, including fractional-second dates.
        let json = """
        {"farm":{"width":2,"height":1,"coins":98,"xp":0,
          "tiles":[{"tilled":true,"crop":"dustwheat","plantedAt":"2026-11-26T09:00:00.123456789Z"},{"tilled":false}]},
         "level":1,"serverTime":"2026-11-26T09:00:05Z"}
        """
        let resp = try APIClient.decoder.decode(APIClient.FarmResponse.self, from: Data(json.utf8))
        XCTAssertEqual(resp.farm.coins, 98)
        XCTAssertEqual(resp.farm.tiles[0].crop, "dustwheat")
        XCTAssertNotNil(resp.farm.tiles[0].plantedAt)
        XCTAssertNil(resp.farm.tiles[1].crop)
    }

    func testLayoutBlocksBuildingsAndGrowsGrass() {
        let farm = Farm(config: config)
        let layout = FarmLayout(config: config)
        let s = config.farm.startTilled
        XCTAssertTrue(layout.isBlocked(x: s.x, y: s.y - 4), "house tile")
        XCTAssertFalse(layout.isBlocked(x: s.x, y: s.y), "bed tile")
        XCTAssertEqual(layout.groundName(farm, x: s.x, y: s.y), "tile_bed")
        XCTAssertTrue(layout.isGreen(farm, s.x - 2, s.y))
        XCTAssertFalse(layout.isGreen(farm, 0, farm.height - 1))
        XCTAssertTrue(layout.groundName(farm, x: -3, y: -3).hasPrefix("tile_dust"))
    }

    // MARK: - army (mirrors server/internal/game/army_test.go)

    func testBuildScarecrowQueue() throws {
        var farm = Farm(config: config)
        let guardian = try XCTUnwrap(config.scarecrow("straw_guard"))
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertThrowsError(try farm.buildScarecrow("straw_guard", now: t0, config: config)) {
            XCTAssertEqual($0 as? FarmError, .notEnoughCrops)
        }
        farm.barn = ["dustwheat": 10]
        try farm.buildScarecrow("straw_guard", now: t0, config: config)
        try farm.buildScarecrow("straw_guard", now: t0, config: config)
        XCTAssertTrue(farm.barn.isEmpty)
        XCTAssertEqual(farm.queue[1].readyAt, t0.addingTimeInterval(2 * Double(guardian.buildSeconds)))
        farm.settle(now: t0.addingTimeInterval(Double(guardian.buildSeconds)), config: config)
        XCTAssertEqual(farm.army.count, 1)
        XCTAssertEqual(farm.queue.count, 1)
        XCTAssertThrowsError(try farm.buildScarecrow("moon_witch", now: t0, config: config)) {
            XCTAssertEqual($0 as? FarmError, .cropLocked)
        }
    }

    func testRaidWinLoseAndCooldown() throws {
        var farm = Farm(config: config)
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertThrowsError(try farm.raid("dust_rats", now: t0, config: config)) {
            XCTAssertEqual($0 as? FarmError, .noArmy)
        }
        farm.army = [ArmyUnit(type: "pumpkin_brute"), ArmyUnit(type: "straw_guard"), ArmyUnit(type: "straw_guard")]
        let coins = farm.coins
        let result = try farm.raid("dust_rats", now: t0, config: config)
        XCTAssertTrue(result.won)
        XCTAssertEqual(farm.coins, coins + (config.raid("dust_rats")?.rewardCoins ?? 0))
        XCTAssertThrowsError(try farm.raid("dust_rats", now: t0.addingTimeInterval(60), config: config)) {
            XCTAssertEqual($0 as? FarmError, .raidCooldown)
        }

        var weak = Farm(config: config)
        weak.xp = 1000
        weak.army = [ArmyUnit(type: "straw_guard")]
        let lost = try weak.raid("scrap_golem", now: t0, config: config)
        XCTAssertFalse(lost.won)
        XCTAssertTrue(weak.army.isEmpty)
    }

    func testOldSaveWithoutArmyStillDecodes() throws {
        let json = #"{"width":1,"height":1,"coins":5,"xp":0,"tiles":[{"tilled":true}]}"#
        let farm = try JSONDecoder().decode(Farm.self, from: Data(json.utf8))
        XCTAssertTrue(farm.barn.isEmpty)
        XCTAssertTrue(farm.army.isEmpty)
    }
}
