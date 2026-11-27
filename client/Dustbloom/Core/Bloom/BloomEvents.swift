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

struct FairOrder: Codable, Equatable {
    let item: String
    let n: Int
    let gems: Int
    let pts: Int
}

struct HeroSkin: Identifiable {
    let id: String
    let title: String
    let gems: Int?        // nil: can't be bought with dew (event or pack only)
}

enum BloomEvents {
    static let events: [BloomEvent] = [
        BloomEvent(id: "fair", title: "Ярмарка", text: "Рынок платит в полтора раза больше, торговцы ждут заказы", icon: "bloom_market"),
        BloomEvent(id: "starfall", title: "Звездопад", text: "С неба падают звёзды: собирай их. Сундуки и находки вдвое чаще", icon: "bloom_item_stardust"),
        BloomEvent(id: "festival", title: "Цветочный фестиваль", text: "Расцветают золотые цветы: собирай их. +25% добычи со всего", icon: "bloom_item_flower"),
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
    // paid track: fixed rewards only, no random chests (no loot boxes)
    static let premium: [EventReward] = [
        EventReward(coins: 0, gems: 40, chest: false, golden: false, skin: nil),
        EventReward(coins: 9, gems: 0, chest: false, golden: false, skin: nil),
        EventReward(coins: 0, gems: 60, chest: false, golden: false, skin: nil),
        EventReward(coins: 12, gems: 0, chest: false, golden: false, skin: nil),
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
        #if DEBUG
        // -bloomEvent starfall: force an event for checks and screenshots
        if let id = UserDefaults.standard.string(forKey: "bloomEvent"), let e = events.first(where: { $0.id == id }) { return e }
        #endif
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

    // MARK: - event rules: fair orders, falling stars, festival blossoms

    /// Fair: three merchant orders a day, drawn from what the player already gathers.
    var fairOrders: [FairOrder] { eventIs("fair") && s.fairDay == BloomMeta.dayKey() ? s.fairOrders : [] }

    /// Draws today's orders once; call when the event panel opens.
    func refreshFair() {
        let day = BloomMeta.dayKey()
        guard eventIs("fair"), s.fairDay != day else { return }
        var rng = BloomMeta.SeededRNG(state: UInt64(day.filter(\.isNumber)) ?? 1)
        let pool = BItem.allCases.filter { $0 != .lantern && ($0.price <= 1 || count($0) > 0) }
        let picks = Array(pool.shuffled(using: &rng).prefix(3)).sorted { $0.price < $1.price }
        s.fairOrders = picks.map { i in
            let value = Double(Int.random(in: 90...170, using: &rng)) * Double(max(3, s.owned.count)) / 3
            var n = max(2, min(60, Int(value / Double(i.price))))
            if n > 10 { n = n / 5 * 5 }
            return FairOrder(item: i.rawValue, n: n, gems: min(30, 6 + n * i.price / 25), pts: 80)
        }
        s.fairDay = day
        s.fairDone = []
    }

    func fairOrderDone(_ i: Int) -> Bool { s.fairDay == BloomMeta.dayKey() && s.fairDone.contains(i) }

    func deliver(_ i: Int) {
        let list = fairOrders
        guard i < list.count, !fairOrderDone(i), let item = BItem(rawValue: list[i].item), count(item) >= list[i].n else {
            Sfx.play(.error); return
        }
        let o = list[i]
        s.inv[item.rawValue, default: 0] -= o.n
        s.gems += o.gems
        s.fairDone.append(i)
        addEventPoints(o.pts)
        Analytics.shared.track("bloom_fair_order", ["item": o.item, "n": o.n, "done": s.fairDone.count])
        Sfx.play(.coin)
        showToast(BloomToast(title: tr("Заказ выполнен!"), subtitle: tr("+%@ росинок", o.gems)))
        save()
    }

    /// Starfall star or festival blossom picked up in the world.
    func eventPickup() -> (BItem?, Int) {
        addEventPoints(20)
        bump("event.pickup")
        if eventIs("starfall") {
            add(.stardust, 1)
            return (.stardust, 1)
        }
        let c = 2 * coinUnit
        addCoins(c)
        add(.flower, 3)
        return (nil, c)
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

// MARK: - first five minutes

/// Short tutorial: one hint at a time, each closes itself when the player does it.
enum BloomTutorial {
    struct Step { let text: String; let icon: String; let done: @MainActor (BloomGame) -> Bool }
    static let steps: [Step] = [
        Step(text: "Подойди к дереву и бей по нему, пока не упадёт", icon: "bloom_tree", done: { $0.life("gather.tree") >= 2 }),
        Step(text: "Теперь разбей камень, он нужен для печи", icon: "bloom_rock", done: { $0.life("gather.rock") >= 2 }),
        Step(text: "Нажми «Строить» внизу и поставь печь", icon: "bloom_furnace_0", done: { $0.isBuilt(.furnace) }),
        Step(text: "Подойди к печи и обожги кирпичи", icon: "bloom_item_brick", done: { $0.life("craft.brick") >= 1 || $0.queue(for: .furnace) != nil }),
        Step(text: "Цель слева вверху: выполни её и забери монеты", icon: "bloom_item_coin", done: { $0.goalIndex >= 1 }),
        Step(text: "Подойди к табличке у моста и купи новый остров", icon: "bloom_sign", done: { $0.owned.count >= 2 }),
    ]
}

extension BloomGame {
    var tutorialStep: BloomTutorial.Step? { s.tut < BloomTutorial.steps.count ? BloomTutorial.steps[s.tut] : nil }
    var tutorialIndex: Int { s.tut }

    /// Moves the tutorial on; called from save().
    func advanceTutorial() {
        while s.tut < BloomTutorial.steps.count, BloomTutorial.steps[s.tut].done(self) {
            Analytics.shared.track("bloom_tut_step", ["step": s.tut + 1, "minutes": playMinutes])
            s.tut += 1
            if s.tut == BloomTutorial.steps.count {
                s.tut = 99
                Analytics.shared.track("bloom_tut_done", ["minutes": playMinutes])
                showToast(BloomToast(title: tr("Обучение пройдено!"), subtitle: tr("Дальше острова расскажут сами")))
            }
        }
    }

    func skipTutorial() {
        Analytics.shared.track("bloom_tut_skip", ["step": s.tut + 1, "minutes": playMinutes])
        s.tut = 99
        save()
    }
}
