import Foundation
import UIKit

/// What a tap on a tile did, so the scene can play the right animation.
enum TapOutcome: Equatable {
    /// First tap on grass: show the price, a second tap on the same tile tills.
    case confirmTill(cost: Int)
    case tilled
    case planted(String)
    case harvested(HarvestResult)
    case failed(FarmError)
    case nothing
}

/// Owns the player's farm. Plays offline by default (state saved on the
/// device); when DUSTBLOOM_SERVER_URL is set it also syncs every action with
/// the server, which has the final word.
@MainActor
final class FarmStore: ObservableObject {
    @Published private(set) var farm: Farm
    @Published var selectedCrop: String
    @Published private(set) var isOnline = false
    /// Plot the player tapped on unowned land; the HUD shows the offer.
    @Published var plotOffer: PlotOffer?
    /// Growing crop the player tapped; the HUD offers a speedup.
    @Published var growOffer: TileRef?
    /// The manor card is open (tap on the house).
    @Published var showManor = false
    private var pendingTill: (x: Int, y: Int)?

    let config: GameConfig
    private var api: APIClient?
    /// Server clock minus device clock, so timers match the server.
    private var clockOffset: TimeInterval = 0

    private static let saveKey = "dustbloom.farm.v1"

    /// Demo mode for videos and screenshots (env DUSTBLOOM_DEMO=1): a fresh
    /// farm with spare coins, time running 15x faster, nothing saved.
    let isDemo: Bool
    private let demoStart = Date()

    init(config: GameConfig = .load()) {
        self.config = config
        self.selectedCrop = config.crops.first?.id ?? ""
        let demo = ProcessInfo.processInfo.environment["DUSTBLOOM_DEMO"] == "1"
        self.isDemo = demo
        if demo {
            var fresh = Farm(config: config)
            fresh.coins = 500
            farm = fresh
        } else if let data = UserDefaults.standard.data(forKey: FarmStore.saveKey),
           let saved = try? JSONDecoder().decode(Farm.self, from: data),
           saved.width == config.farm.width, saved.height == config.farm.height {
            var loaded = saved
            loaded.ensurePlots(config: config)
            farm = loaded
        } else {
            farm = Farm(config: config)
        }
        if let raw = ProcessInfo.processInfo.environment["DUSTBLOOM_SERVER_URL"],
           !raw.isEmpty, let url = URL(string: raw) {
            api = APIClient(baseURL: url)
        }
    }

    var now: Date {
        if isDemo { return demoStart.addingTimeInterval(Date().timeIntervalSince(demoStart) * 15) }
        return Date().addingTimeInterval(clockOffset)
    }

    /// Logs in and pulls the server farm. Falls back to offline on failure.
    func connect() async {
        guard var api else { return }
        do {
            let device = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            api.token = try await api.guestLogin(deviceID: device)
            self.api = api
            apply(try await api.farm())
            isOnline = true
        } catch {
            isOnline = false
        }
    }

    /// Decides what a tap means for the tile: till grass, plant, or harvest.
    /// `swipe` is true while the finger slides over beds: it never tills.
    func tap(x: Int, y: Int, swipe: Bool = false) -> TapOutcome {
        guard let tile = farm.tile(x: x, y: y) else { return .nothing }
        if !tile.tilled && !farm.owns(x: x, y: y, config: config) {
            guard !swipe else { return .nothing }
            let ps = config.farm.plotSize
            plotOffer = PlotOffer(px: x / ps, py: y / ps)
            return .nothing
        }
        if !tile.tilled && (swipe || !(pendingTill.map { $0.x == x && $0.y == y } ?? false)) {
            guard !swipe else { return .nothing }
            pendingTill = (x, y)
            return .confirmTill(cost: config.farm.tillCost)
        }
        pendingTill = nil
        var next = farm
        let outcome: TapOutcome
        do {
            if !tile.tilled {
                try next.till(x: x, y: y, config: config)
                outcome = .tilled
                sync { try await $0.till(x: x, y: y) }
            } else if tile.crop == nil {
                try next.plant(x: x, y: y, cropID: selectedCrop, now: now, config: config)
                outcome = .planted(selectedCrop)
                let crop = selectedCrop
                sync { try await $0.plant(x: x, y: y, crop: crop) }
            } else {
                if (progress(of: tile) ?? 0) < 1 {
                    if !swipe { growOffer = TileRef(x: x, y: y) }
                    return .nothing
                }
                let result = try next.harvest(x: x, y: y, now: now, config: config)
                outcome = .harvested(result)
                sync { try await $0.harvest(x: x, y: y) }
            }
        } catch let error as FarmError {
            return .failed(error)
        } catch {
            return .nothing
        }
        farm = next
        save()
        return outcome
    }

    // MARK: - land

    struct TileRef: Identifiable, Equatable {
        var x: Int
        var y: Int
        var id: Int { y * 1000 + x }
    }

    struct PlotOffer: Identifiable, Equatable {
        var px: Int
        var py: Int
        var id: Int { py * 100 + px }
    }

    func buyPlot(px: Int, py: Int) -> FarmError? {
        var next = farm
        do {
            try next.buyPlot(px: px, py: py, config: config)
        } catch let error as FarmError {
            return error
        } catch {
            return nil
        }
        farm = next
        save()
        sync { try await $0.buyPlot(px: px, py: py) }
        return nil
    }

    // MARK: - barn, workshop, raids

    /// Sells crops from the barn. Returns the coins earned, or nil on failure.
    @discardableResult
    func sell(_ cropID: String, count: Int) -> Int? {
        var next = farm
        guard let earned = try? next.sell(cropID: cropID, count: count, config: config) else { return nil }
        farm = next
        save()
        sync { try await $0.sell(crop: cropID, count: count) }
        return earned
    }

    func build(_ scarecrowID: String) -> FarmError? {
        var next = farm
        do {
            try next.buildScarecrow(scarecrowID, now: now, config: config)
        } catch let error as FarmError {
            return error
        } catch {
            return nil
        }
        farm = next
        save()
        sync { try await $0.build(scarecrow: scarecrowID) }
        return nil
    }

    /// Online the server fights the raid; offline it is simulated here.
    func raid(_ raidID: String) async -> Result<RaidResult, FarmError> {
        if isOnline, let api {
            do {
                let resp = try await api.raid(raidID)
                apply(resp)
                if let r = resp.raid { return .success(r) }
                return .failure(.unknownRaid)
            } catch APIClient.APIError.game(let code) {
                return .failure(code)
            } catch {
                isOnline = false  // fall through to the offline fight
            }
        }
        var next = farm
        do {
            let r = try next.raid(raidID, now: now, config: config)
            farm = next
            save()
            return .success(r)
        } catch let error as FarmError {
            return .failure(error)
        } catch {
            return .failure(.unknownRaid)
        }
    }

    @discardableResult
    func deliverOrder(_ i: Int) -> OrderResult? {
        var next = farm
        guard let r = try? next.deliverOrder(i, now: now, config: config) else { return nil }
        farm = next
        save()
        sync { try await $0.deliverOrder(i) }
        return r
    }

    func skipOrder(_ i: Int) {
        var next = farm
        guard (try? next.skipOrder(i, now: now, config: config)) != nil else { return }
        farm = next
        save()
        sync { try await $0.skipOrder(i) }
    }

    // MARK: - manor (Усадьба)

    func upgradeManor() -> FarmError? {
        var next = farm
        do {
            try next.upgradeManor(now: now, config: config)
        } catch let error as FarmError {
            return error
        } catch {
            return nil
        }
        farm = next
        save()
        sync { try await $0.upgradeManor() }
        return nil
    }

    // MARK: - storage (Склад)

    /// Smart speedup: picks the speedups that waste the least and spends them.
    /// Returns the seconds saved and the items used.
    func smartSpeedup(_ target: SpeedTarget) -> Result<(saved: Int, used: [String: Int]), FarmError> {
        var next = farm
        do {
            let plan = try next.planSpeedups(for: target, now: now, config: config)
            let saved = try next.useSpeedups(plan, on: target, now: now, config: config)
            farm = next
            save()
            sync { try await $0.speedup(plan, on: target) }
            return .success((saved, plan))
        } catch let error as FarmError {
            return .failure(error)
        } catch {
            return .failure(.unknownItem)
        }
    }

    /// Spends chosen speedups (the storage screen's manual mode).
    func useSpeedups(_ use: [String: Int], on target: SpeedTarget) -> Result<Int, FarmError> {
        var next = farm
        do {
            let saved = try next.useSpeedups(use, on: target, now: now, config: config)
            farm = next
            save()
            sync { try await $0.speedup(use, on: target) }
            return .success(saved)
        } catch let error as FarmError {
            return .failure(error)
        } catch {
            return .failure(.unknownItem)
        }
    }

    /// Online the server rolls the chest; offline it is rolled here.
    func openChest(_ id: String, count: Int = 1) async -> Result<[String: Int], FarmError> {
        if isOnline, let api {
            do {
                let resp = try await api.openChest(id, count: count)
                apply(resp)
                return .success(resp.loot ?? [:])
            } catch APIClient.APIError.game(let code) {
                return .failure(code)
            } catch {
                isOnline = false
            }
        }
        var next = farm
        do {
            let loot = try next.openChest(id, count: count, config: config)
            farm = next
            save()
            return .success(loot)
        } catch let error as FarmError {
            return .failure(error)
        } catch {
            return .failure(.unknownItem)
        }
    }

    /// Moves finished scarecrows into the army and refills the order board;
    /// call on a timer from the UI.
    func settle() {
        var next = farm
        next.settle(now: now, config: config)
        if !isOnline { next.fillOrders(now: now, config: config) }
        if next != farm {
            farm = next
            save()
        }
    }

    func progress(of tile: Tile) -> Double? {
        guard let id = tile.crop, let planted = tile.plantedAt, let crop = config.crop(id) else { return nil }
        return Farm.progress(crop: crop, plantedAt: planted, now: now)
    }

    func save() {
        guard !isDemo else { return }
        if let data = try? JSONEncoder().encode(farm) {
            UserDefaults.standard.set(data, forKey: FarmStore.saveKey)
        }
    }

    // MARK: - server sync

    private func sync(_ call: @escaping (APIClient) async throws -> APIClient.FarmResponse) {
        guard isOnline, let api else { return }
        Task {
            do {
                apply(try await call(api))
            } catch {
                // The server disagreed or is unreachable: take its state if we can.
                if let fresh = try? await api.farm() {
                    apply(fresh)
                } else {
                    isOnline = false
                }
            }
        }
    }

    private func apply(_ resp: APIClient.FarmResponse) {
        clockOffset = resp.serverTime.timeIntervalSinceNow
        farm = resp.farm
        save()
    }
}
