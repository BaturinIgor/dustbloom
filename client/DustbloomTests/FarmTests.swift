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

    // MARK: - land plots (mirrors TestLandPlots in farm_test.go)

    func testLandPlots() throws {
        var farm = Farm(config: config)
        XCTAssertTrue(farm.owns(x: 6, y: 6, config: config))
        XCTAssertFalse(farm.owns(x: 0, y: 0, config: config))
        XCTAssertThrowsError(try farm.till(x: 0, y: 6, config: config)) {
            XCTAssertEqual($0 as? FarmError, .notOwned)
        }
        let price = farm.plotPrice(config: config)
        XCTAssertEqual(price.coins, config.farm.plotBaseCost)
        XCTAssertEqual(price.level, 1)
        XCTAssertEqual(farm.canBuyPlot(px: 3, py: 3, config: config), .notAdjacent)
        XCTAssertEqual(farm.canBuyPlot(px: 1, py: 1, config: config), .alreadyOwned)
        try farm.buyPlot(px: 0, py: 1, config: config)
        XCTAssertEqual(farm.coins, config.farm.startCoins - price.coins)
        try farm.till(x: 0, y: 6, config: config)
        farm.coins = 10_000
        XCTAssertThrowsError(try farm.buyPlot(px: 0, py: 0, config: config)) {
            XCTAssertEqual($0 as? FarmError, .cropLocked)
        }
    }

    // MARK: - storage (mirrors server/internal/game/items_test.go)

    func testStartItemsAndIDs() {
        let farm = Farm(config: config)
        XCTAssertEqual(farm.items, config.items.startItems)
        XCTAssertNotNil(config.speedup("speed_any_24h"))
        XCTAssertNotNil(config.speedup("speed_recruit_1m"))
        XCTAssertNil(config.speedup("speed_any_2m"))
    }

    func testSpeedUpCrop() throws {
        var farm = Farm(config: config)
        farm.items = ["speed_grow_15m": 1, "speed_recruit_5m": 1]
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        try farm.plant(x: 6, y: 6, cropID: "dustwheat", now: t0, config: config)
        let tgt = SpeedTarget(kind: SpeedTarget.grow, x: 6, y: 6)
        XCTAssertThrowsError(try farm.useSpeedups(["speed_recruit_5m": 1], on: tgt, now: t0, config: config)) {
            XCTAssertEqual($0 as? FarmError, .wrongTarget)
        }
        try farm.useSpeedups(["speed_grow_15m": 1], on: tgt, now: t0, config: config)
        XCTAssertNil(farm.items["speed_grow_15m"])
        _ = try farm.harvest(x: 6, y: 6, now: t0, config: config)
    }

    func testPlanSpeedupsMatchesServer() throws {
        var farm = Farm(config: config)
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        farm.queue = [Build(type: "straw_guard", readyAt: t0.addingTimeInterval(47 * 60))]
        farm.items = ["speed_any_1h": 2, "speed_recruit_30m": 1, "speed_any_15m": 3, "speed_any_1m": 5, "speed_grow_1h": 4]
        let plan = try farm.planSpeedups(for: SpeedTarget(kind: SpeedTarget.recruit), now: t0, config: config)
        XCTAssertEqual(plan, ["speed_recruit_30m": 1, "speed_any_15m": 1, "speed_any_1m": 2])

        farm.queue[0].readyAt = t0.addingTimeInterval(70 * 60)
        farm.items = ["speed_any_1h": 3]
        let cover = try farm.planSpeedups(for: SpeedTarget(kind: SpeedTarget.recruit), now: t0, config: config)
        XCTAssertEqual(cover, ["speed_any_1h": 2])
        try farm.useSpeedups(cover, on: SpeedTarget(kind: SpeedTarget.recruit), now: t0, config: config)
        XCTAssertTrue(farm.queue.isEmpty)
        XCTAssertEqual(farm.items["speed_any_1h"], 1)
    }

    func testChestAndLevelUpRewards() throws {
        var farm = Farm(config: config)
        farm.items = ["chest_wood": 2]
        let loot = try farm.openChest("chest_wood", count: 2, config: config)
        XCTAssertFalse(loot.isEmpty)
        XCTAssertNil(farm.items["chest_wood"])
        XCTAssertThrowsError(try farm.openChest("speed_any_1m", count: 1, config: config)) {
            XCTAssertEqual($0 as? FarmError, .notAChest)
        }
        farm.items = [:]
        let up = farm.gainXP(100, config: config)  // level 1 -> 5
        XCTAssertTrue(up.levelUp)
        XCTAssertEqual(up.items["chest_wood"], 4)
        XCTAssertEqual(up.items["chest_iron"], 1)
    }

    // MARK: - manor (mirrors server/internal/game/manor_test.go)

    func testManorUpgradeAndSpeedup() throws {
        var farm = Farm(config: config)
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(farm.manorLevel, 1)
        XCTAssertEqual(config.manor.levels.count, 29)
        let next = try XCTUnwrap(farm.nextManor(config: config))
        try farm.upgradeManor(now: t0, config: config)
        XCTAssertEqual(farm.coins, config.farm.startCoins - next.coins)
        XCTAssertThrowsError(try farm.upgradeManor(now: t0, config: config)) {
            XCTAssertEqual($0 as? FarmError, .busy)
        }
        farm.items = ["speed_build_1m": 1]
        try farm.useSpeedups(["speed_build_1m": 1], on: SpeedTarget(kind: SpeedTarget.build), now: t0, config: config)
        XCTAssertEqual(farm.manorLevel, 2)
        XCTAssertNil(farm.manorReadyAt)
        let slots = farm.armySlots(config: config)
        farm.manor = 3
        XCTAssertEqual(farm.armySlots(config: config), slots + 1)
        farm.manor = 6
        XCTAssertEqual(farm.manorTier, 1)
    }

    // MARK: - working buildings (mirrors server/internal/game/buildings_test.go)

    func testBuildingsCappedByManorWithOneBuilder() throws {
        var farm = Farm(config: config)
        farm.coins = 1_000_000
        farm.barn = ["dustwheat": 500, "emberpumpkin": 500]
        var now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(config.buildings.list.count, 6)
        XCTAssertEqual(farm.buildingLevel("mill", config: config), 1)
        XCTAssertThrowsError(try farm.upgradeBuilding("well", now: now, config: config)) {
            XCTAssertEqual($0 as? FarmError, .manorTooLow)
        }
        try farm.upgradeManor(now: now, config: config)
        XCTAssertThrowsError(try farm.upgradeBuilding("mill", now: now, config: config)) {
            XCTAssertEqual($0 as? FarmError, .busy)
        }
        now = now.addingTimeInterval(3600)
        try farm.upgradeBuilding("well", now: now, config: config)
        XCTAssertThrowsError(try farm.upgradeManor(now: now, config: config)) {
            XCTAssertEqual($0 as? FarmError, .busy)
        }
        farm.items = ["speed_build_5m": 1]
        try farm.useSpeedups(["speed_build_5m": 1], on: SpeedTarget(kind: SpeedTarget.build), now: now, config: config)
        XCTAssertEqual(farm.buildingLevel("well", config: config), 1)
        XCTAssertNil(farm.work)
        XCTAssertGreaterThan(farm.power(config: config), config.manor.startPower)
    }

    func testWellMakesNewPlantingsFaster() throws {
        var farm = Farm(config: config)
        farm.manor = 30
        farm.buildings = ["well": 10, "mill": 10]
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let pumpkin = try XCTUnwrap(config.crop("emberpumpkin"))
        try farm.plant(x: 6, y: 6, cropID: "emberpumpkin", now: t0, config: config)
        let grow = try XCTUnwrap(farm.tile(x: 6, y: 6)?.grow)
        XCTAssertEqual(grow, Int(Double(pumpkin.growSeconds) * 0.85 + 0.5))
        _ = try farm.harvest(x: 6, y: 6, now: t0.addingTimeInterval(Double(grow)), config: config)
        farm.barn = ["emberpumpkin": 10]
        XCTAssertEqual(try farm.sell(cropID: "emberpumpkin", count: 10, config: config), pumpkin.sellPrice * 10 * 120 / 100)
    }
}
