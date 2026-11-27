import Foundation

/// Weekly events, hero skins and the extra shop offers (starter pack, helper slot, event pass).
/// Each week (Monday to Sunday, local time) runs one event in turn. Everything you gather
/// gives event stars; stars open a free track and, with the event pass, a premium track.

struct BloomEvent {
    let id: String
    let title: String     // Russian source text, goes through tr()
    let text: String
    let icon: String
}

struct EventReward {
    let coins: Int        // in coin units, see BloomGame.coinUnit
    let gems: Int
    let chest: Bool
    let golden: Bool
    let skin: String?
}

struct HeroSkin: Identifiable {
    let id: String
    let title: String
    let gems: Int?        // nil: can't be bought with dew (event or pack only)
}

enum BloomEvents {
    static let events: [BloomEvent] = [
        BloomEvent(id: "fair", title: "Ярмарка", text: "Рынок платит в полтора раза больше", icon: "bloom_market"),
        BloomEvent(id: "starfall", title: "Звездопад", text: "Сундуки и находки попадаются вдвое чаще", icon: "bloom_item_stardust"),
        BloomEvent(id: "festival", title: "Цветочный фестиваль", text: "+25% добычи со всего", icon: "bloom_item_flower"),
    ]

    /// Stars needed for each step of the track.
    static let steps = [100, 300, 600, 1000, 1500, 2200]

    static let free: [EventReward] = [
        EventReward(coins: 2, gems: 0, chest: false, golden: false, skin: nil),
        EventReward(coins: 0, gems: 10, chest: false, golden: false, skin: nil),
        EventReward(coins: 0, gems: 0, chest: true, golden: false, skin: nil),
        EventReward(coins: 0, gems: 20, chest: false, golden: false, skin: nil),
        EventReward(coins: 0, gems: 0, chest: false, golden: true, skin: nil),
        EventReward(coins: 4, gems: 30, chest: false, golden: false, skin: nil),
    ]
    static let premium: [EventReward] = [
        EventReward(coins: 0, gems: 40, chest: false, golden: false, skin: nil),
        EventReward(coins: 4, gems: 0, chest: true, golden: false, skin: nil),
        EventReward(coins: 0, gems: 60, chest: false, golden: false, skin: nil),
        EventReward(coins: 6, gems: 0, chest: true, golden: false, skin: nil),
        EventReward(coins: 0, gems: 100, chest: false, golden: false, skin: nil),
        EventReward(coins: 0, gems: 0, chest: false, golden: false, skin: "star"),
    ]

    static let skins: [HeroSkin] = [
        HeroSkin(id: "pink", title: "Розовый бутон", gems: 0),
        HeroSkin(id: "mint", title: "Мятный", gems: nil),          // starter pack
        HeroSkin(id: "sky", title: "Небесный", gems: 300),
        HeroSkin(id: "sun", title: "Солнечный", gems: 500),
        HeroSkin(id: "star", title: "Звёздный", gems: nil),        // event pass
    ]

    /// Monday 5 January 2026, local time: week 0.
    private static var epoch: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 5)) ?? Date(timeIntervalSince1970: 0)
    }
    static func weekIndex(_ d: Date = Date()) -> Int {
        let days = Calendar.current.dateComponents([.day], from: epoch, to: d).day ?? 0
        return Int((Double(days) / 7).rounded(.down))
    }
    static func current(_ d: Date = Date()) -> BloomEvent {
        let i = weekIndex(d)
        return events[((i % events.count) + events.count) % events.count]
    }
    static func endsAt(_ d: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: (weekIndex(d) + 1) * 7, to: epoch) ?? d
    }
}

extension BloomGame {
    // MARK: - weekly event

    var event: BloomEvent { BloomEvents.current() }
    var eventKey: String { "w\(BloomEvents.weekIndex())" }
    func eventIs(_ id: String) -> Bool { event.id == id }
    var eventPoints: Int { s.eventWeek == eventKey ? s.eventPoints : 0 }
    var eventPassActive: Bool { s.eventPass == eventKey }
    func eventFreeClaimed(_ i: Int) -> Bool { s.eventWeek == eventKey && s.eventFree.contains(i) }
    func eventPremClaimed(_ i: Int) -> Bool { s.eventWeek == eventKey && s.eventPrem.contains(i) }
    var eventReadyCount: Int {
        let p = eventPoints
        return BloomEvents.steps.indices.filter { p >= BloomEvents.steps[$0] && !eventFreeClaimed($0) }.count
            + (eventPassActive ? BloomEvents.steps.indices.filter { p >= BloomEvents.steps[$0] && !eventPremClaimed($0) }.count : 0)
    }
    /// "2д 5ч" until the event ends.
    var eventLeft: String {
        let sec = max(0, Int(BloomEvents.endsAt().timeIntervalSinceNow))
        let d = sec / 86400, h = (sec % 86400) / 3600, m = (sec % 3600) / 60
        return d > 0 ? tr("%@д %@ч", d, h) : tr("%@ч %@м", h, m)
    }

    /// Starts a fresh track when the week changed.
    func refreshEvent() {
        guard s.eventWeek != eventKey else { return }
        s.eventWeek = eventKey
        s.eventPoints = 0
        s.eventFree = []
        s.eventPrem = []
        Analytics.shared.track("bloom_event_start", ["event": event.id, "springs": s.springs])
    }

    func addEventPoints(_ n: Int) {
        guard n > 0 else { return }
        refreshEvent()
        let before = s.eventPoints
        s.eventPoints += n
        if let step = BloomEvents.steps.firstIndex(where: { before < $0 && s.eventPoints >= $0 }) {
            showToast(BloomToast(title: tr(event.title), subtitle: tr("Награда %@ ждёт тебя", step + 1)))
            Analytics.shared.track("bloom_event_step", ["event": event.id, "step": step + 1])
        }
    }

    func claimEvent(_ i: Int, premium: Bool) {
        refreshEvent()
        guard i < BloomEvents.steps.count, s.eventPoints >= BloomEvents.steps[i] else { Sfx.play(.error); return }
        if premium {
            guard eventPassActive, !s.eventPrem.contains(i) else { Sfx.play(.error); return }
            s.eventPrem.append(i)
        } else {
            guard !s.eventFree.contains(i) else { Sfx.play(.error); return }
            s.eventFree.append(i)
        }
        give(premium ? BloomEvents.premium[i] : BloomEvents.free[i])
        Analytics.shared.track("bloom_event_claim", ["event": event.id, "step": i + 1, "premium": premium])
        Sfx.play(.chest)
        save()
    }

    func give(_ r: EventReward) {
        s.coins += r.coins * coinUnit
        s.gems += r.gems
        if r.chest {
            let c = openChest()
            s.coins += c.coins
            for (i, k) in c.items { add(i, k) }
        }
        if r.golden { onGoldenRequested?(BloomBalance.shared.shop.adGoldenSeconds) }
        if let sk = r.skin {
            if s.skins.contains(sk) { s.gems += 150 } else {
                s.skins.append(sk)
                showToast(BloomToast(title: tr("Новый облик!"), subtitle: tr(BloomEvents.skins.first { $0.id == sk }?.title ?? "")))
            }
        }
    }

    // MARK: - hero skins

    var skin: String { s.skin ?? "pink" }
    var heroPrefix: String { skin == "pink" ? "bloom_hero_" : "bloom_hero_\(skin)_" }
    func ownsSkin(_ id: String) -> Bool { id == "pink" || s.skins.contains(id) }

    func pickSkin(_ k: HeroSkin) {
        if !ownsSkin(k.id) {
            guard let g = k.gems, s.gems >= g else { Sfx.play(.error); return }
            s.gems -= g
            s.skins.append(k.id)
            Analytics.shared.track("bloom_skin_buy", ["id": k.id, "gems": g])
        }
        s.skin = k.id
        Sfx.play(.levelUp)
        save()
    }

    // MARK: - offers

    var starterBought: Bool { s.starter }
    var hasSlot: Bool { s.slot }
}
