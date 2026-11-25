import Foundation
import UIKit

/// What a tap on a tile did, so the scene can play the right animation.
enum TapOutcome: Equatable {
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

    let config: GameConfig
    private var api: APIClient?
    /// Server clock minus device clock, so timers match the server.
    private var clockOffset: TimeInterval = 0

    private static let saveKey = "dustbloom.farm.v1"

    init(config: GameConfig = .load()) {
        self.config = config
        self.selectedCrop = config.crops.first?.id ?? ""
        if let data = UserDefaults.standard.data(forKey: FarmStore.saveKey),
           let saved = try? JSONDecoder().decode(Farm.self, from: data),
           saved.width == config.farm.width, saved.height == config.farm.height {
            farm = saved
        } else {
            farm = Farm(config: config)
        }
        if let raw = ProcessInfo.processInfo.environment["DUSTBLOOM_SERVER_URL"],
           !raw.isEmpty, let url = URL(string: raw) {
            api = APIClient(baseURL: url)
        }
    }

    var now: Date { Date().addingTimeInterval(clockOffset) }

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
    func tap(x: Int, y: Int) -> TapOutcome {
        guard let tile = farm.tile(x: x, y: y) else { return .nothing }
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

    func progress(of tile: Tile) -> Double? {
        guard let id = tile.crop, let planted = tile.plantedAt, let crop = config.crop(id) else { return nil }
        return Farm.progress(crop: crop, plantedAt: planted, now: now)
    }

    func save() {
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
