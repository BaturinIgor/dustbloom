import Foundation
import GameKit
import UIKit

/// Game Center: three leaderboards and achievements. IDs must match App Store Connect
/// (tools/asc_gamecenter.py creates them). Silent when the player isn't signed in.
struct Achievement {
    let id: String        // "bloom.ach." + id in App Store Connect
    let title: String     // Russian source; the in-game list and the store share it
    let text: String
    let check: @MainActor (BloomGame) -> Bool
}

enum BloomAchievements {
    static let all: [Achievement] = [
        Achievement(id: "first_tree", title: "Первый урожай", text: "Сруби первое дерево", check: { $0.life("gather.tree") >= 1 }),
        Achievement(id: "lumberjack", title: "Лесоруб", text: "Сруби 500 деревьев", check: { $0.life("gather.tree") >= 500 }),
        Achievement(id: "miner", title: "Горняк", text: "Разбей 500 камней", check: { $0.life("gather.rock") >= 500 }),
        Achievement(id: "berry", title: "Ягодник", text: "Обери 300 кустов", check: { $0.life("gather.bush") >= 300 }),
        Achievement(id: "fisher", title: "Рыбак", text: "Порыбачь в прудах 100 раз", check: { $0.life("gather.pond") >= 100 }),
        Achievement(id: "furnace", title: "Огонь в печи", text: "Построй печь", check: { $0.isBuilt(.furnace) }),
        Achievement(id: "builder", title: "Строитель", text: "Построй все постройки", check: { g in BuildKind.allCases.allSatisfy { g.isBuilt($0) } }),
        Achievement(id: "islands3", title: "Путешественник", text: "Владей тремя островами", check: { $0.owned.count >= 3 }),
        Achievement(id: "islands6", title: "Мореход", text: "Владей шестью островами", check: { $0.owned.count >= 6 }),
        Achievement(id: "islands12", title: "Весь архипелаг", text: "Открой все острова", check: { $0.owned.count >= 12 }),
        Achievement(id: "level10", title: "Росток", text: "Достигни 10 уровня", check: { $0.bestLevel >= 10 }),
        Achievement(id: "level25", title: "Цветок", text: "Достигни 25 уровня", check: { $0.bestLevel >= 25 }),
        Achievement(id: "level50", title: "Древо", text: "Достигни 50 уровня", check: { $0.bestLevel >= 50 }),
        Achievement(id: "helpers3", title: "Дружная семья", text: "Вырасти трёх блумлингов", check: { $0.helpers.count >= 3 }),
        Achievement(id: "gold_pick", title: "Золотая кирка", text: "Выкуй золотую кирку", check: { $0.pickTier >= 3 }),
        Achievement(id: "obsidian_pick", title: "Сильнее камня", text: "Выкуй обсидиановую кирку", check: { $0.pickTier >= 5 }),
        Achievement(id: "chests", title: "Кладоискатель", text: "Открой 50 сундуков", check: { $0.life("chest") >= 50 }),
        Achievement(id: "album", title: "Коллекционер", text: "Собери все страницы альбома", check: { g in BloomAlbum.pages.indices.allSatisfy { g.pageDone($0) } }),
        Achievement(id: "spring", title: "Новая весна", text: "Встреть новую весну", check: { $0.springs >= 1 }),
        Achievement(id: "spring5", title: "Вечный сад", text: "Встреть пять новых вёсен", check: { $0.springs >= 5 }),
        Achievement(id: "week", title: "Неделя в саду", text: "Забери все семь подарков за вход", check: { $0.loginTotal >= 7 }),
        Achievement(id: "event", title: "Душа праздника", text: "Пройди событие до конца", check: { $0.eventPoints >= BloomEvents.steps.last ?? 0 }),
        Achievement(id: "lantern", title: "Звездочёт", text: "Собери звёздный фонарь", check: { $0.life("craft.lantern") >= 1 }),
    ]
}

enum BloomLeaderboard: String, CaseIterable {
    case level = "bloom.lb.level"         // best level ever
    case gathered = "bloom.lb.gathered"   // everything gathered, all springs
    case springs = "bloom.lb.springs"     // new springs met
}

@MainActor
final class BloomGameCenter {
    static let shared = BloomGameCenter()
    private(set) var signedIn = false
    private var lastScores: [BloomLeaderboard: Int] = [:]
    var onSignedOut: (() -> Void)?

    /// Signs in quietly. Apple shows its own sign-in only if the player never decided.
    func start(_ game: BloomGame) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-bloomShowcase") { return }
        #endif
        GKLocalPlayer.local.authenticateHandler = { [weak self, weak game] vc, _ in
            Task { @MainActor in
                if let vc, let root = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first {
                    root.present(vc, animated: true)
                    return
                }
                self?.signedIn = GKLocalPlayer.local.isAuthenticated
                Analytics.shared.track("bloom_gamecenter", ["signedIn": self?.signedIn ?? false])
                if let game { self?.sync(game) }
            }
        }
    }

    /// Reports scores and newly earned achievements. Cheap: call after saves.
    func sync(_ game: BloomGame) {
        guard signedIn else { return }
        let scores: [BloomLeaderboard: Int] = [.level: game.bestLevel, .gathered: game.gatheredTotal, .springs: game.springs]
        for (lb, v) in scores where v > 0 && lastScores[lb] != v {
            lastScores[lb] = v
            GKLeaderboard.submitScore(v, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [lb.rawValue]) { _ in }
        }
        let new = BloomAchievements.all.filter { !game.achieved.contains($0.id) && $0.check(game) }
        guard !new.isEmpty else { return }
        let list = new.map { a -> GKAchievement in
            let g = GKAchievement(identifier: "bloom.ach." + a.id)
            g.percentComplete = 100
            g.showsCompletionBanner = true
            return g
        }
        GKAchievement.report(list) { _ in }
        game.markAchieved(new.map(\.id))
    }

    func open() {
        guard signedIn else { onSignedOut?(); return }
        let vc = GKGameCenterViewController(state: .leaderboards)
        vc.gameCenterDelegate = Dismisser.shared
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first?.present(vc, animated: true)
        Analytics.shared.track("bloom_gamecenter_open", [:])
    }

    private final class Dismisser: NSObject, GKGameCenterControllerDelegate {
        static let shared = Dismisser()
        func gameCenterViewControllerDidFinish(_ vc: GKGameCenterViewController) { vc.dismiss(animated: true) }
    }
}

extension BloomGame {
    func life(_ key: String) -> Int { s.life[key] ?? 0 }
    var bestLevel: Int { max(s.bestLevel, s.level) }
    var gatheredTotal: Int { ["gather.tree", "gather.rock", "gather.bush", "gather.pond"].reduce(0) { $0 + life($1) } }
    var achieved: [String] { s.achieved }
    var loginTotal: Int { s.loginDay }
    func markAchieved(_ ids: [String]) {
        for id in ids where !s.achieved.contains(id) {
            s.achieved.append(id)
            Analytics.shared.track("bloom_achievement", ["id": id, "minutes": playMinutes])
        }
    }
}
