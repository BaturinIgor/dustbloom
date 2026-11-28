import Foundation

/// A decoration placed on an island cell.
struct PlacedDecor: Codable, Hashable {
    var kind: String
    var cell: Cell
}

struct DecorDef: Identifiable {
    let id: String
    let title: String
    let gems: Int
}

struct PetDef: Identifiable {
    let id: String
    let title: String
    let gems: Int?        // nil: only in a bundle
    let source: String
}

/// Moment offers: a small glowing button appears when the player could use the thing,
/// lives 48 hours, shows once, never as a popup. Plus pets, decorations and the pass's daily dew.
struct MomentOffer: Identifiable {
    let id: String
    let product: ShopProduct
    let icon: String
    let title: String
    let text: String
}

enum BloomOffers {
    static let window: TimeInterval = 48 * 3600

    static let all: [MomentOffer] = [
        MomentOffer(id: "brave", product: .brave, icon: "bloom_ui_heart_full", title: "Сердце смельчака",
                    text: "+2 сердца навсегда и 100 росинок"),
        MomentOffer(id: "crafter", product: .crafter, icon: "bloom_furnace_0", title: "Мастер на все руки",
                    text: "Все здания работают вдвое быстрее, навсегда"),
        MomentOffer(id: "digger", product: .digger, icon: "bloom_shovel", title: "Кладоискатель",
                    text: "Золотая лопата: клады вдвое богаче навсегда, и 200 росинок"),
        MomentOffer(id: "island", product: .islandPack, icon: "bloom_item_coin", title: "Остров ближе",
                    text: "Монеты на большую часть цены острова и 100 росинок"),
        MomentOffer(id: "friend", product: .friend, icon: "bloom_pet_bee_0", title: "Друг острова",
                    text: "Подарки друзей вдвое больше навсегда и спутник Шмелик"),
        MomentOffer(id: "level10", product: .level10, icon: "bloom_hero_rose_idle_0", title: "Набор 10 уровня",
                    text: "Облик «Розовый сад», 300 росинок, дерево, камень и слитки"),
        MomentOffer(id: "level20", product: .level20, icon: "bloom_pet_owl_0", title: "Набор 20 уровня",
                    text: "Облик «Ночной», спутник Совушка, 800 росинок и редкие ресурсы"),
    ]
    static func offer(_ id: String) -> MomentOffer? { all.first { $0.id == id } }

    static func perk(_ p: ShopProduct) -> String {
        switch p {
        case .brave: return "brave"
        case .crafter: return "crafter"
        case .digger: return "digger"
        case .friend: return "friend"
        case .level10: return "level10"
        case .level20: return "level20"
        default: return ""
        }
    }

    static let pets: [PetDef] = [
        PetDef(id: "fox", title: "Лисёнок", gems: 800, source: ""),
        PetDef(id: "bee", title: "Шмелик", gems: nil, source: "Друг острова"),
        PetDef(id: "owl", title: "Совушка", gems: nil, source: "Набор 20 уровня"),
    ]

    static let decor: [DecorDef] = [
        DecorDef(id: "bed", title: "Клумба", gems: 30),
        DecorDef(id: "lamp", title: "Фонарь", gems: 40),
        DecorDef(id: "flag", title: "Флажок", gems: 40),
        DecorDef(id: "bench", title: "Скамейка", gems: 60),
        DecorDef(id: "shroom", title: "Гриб-светильник", gems: 80),
        DecorDef(id: "scarecrow", title: "Пугало", gems: 100),
        DecorDef(id: "fountain", title: "Фонтан", gems: 150),
        DecorDef(id: "statue", title: "Звёздная статуя", gems: 150),
    ]
    static func decor(_ id: String) -> DecorDef? { decor.first { $0.id == id } }

    static let passDew = 20
}

extension BloomGame {
    func hasPerk(_ p: String) -> Bool { s.perks.contains(p) }
    var friendGiftMult: Int { (passActive ? 2 : 1) * (hasPerk("friend") ? 2 : 1) }

    // MARK: moment offers

    private func offerOwned(_ id: String) -> Bool {
        if id == "island" { return s.islandPacks >= 2 }
        return hasPerk(id)
    }

    /// The offer on screen now, if any: the newest one still inside its 48 hours and not bought.
    var activeOffer: (offer: MomentOffer, until: Date)? {
        let now = Date()
        return s.offers.compactMap { id, at -> (MomentOffer, Date)? in
            guard let o = BloomOffers.offer(id), !offerOwned(id), at.addingTimeInterval(BloomOffers.window) > now else { return nil }
            return (o, at.addingTimeInterval(BloomOffers.window))
        }.max { $0.1 < $1.1 }
    }

    /// Shows an offer once in its life. "island" can come back for a later island until two were bought.
    func triggerOffer(_ id: String) {
        guard !offerOwned(id), BloomOffers.offer(id) != nil else { return }
        if let at = s.offers[id], id != "island" || at.addingTimeInterval(BloomOffers.window * 3) > Date() { return }
        // one new offer per session: never stack them
        guard !offerShownThisSession else { return }
        offerShownThisSession = true
        s.offers[id] = Date()
        Analytics.shared.track("bloom_offer_shown", ["id": id, "level": level, "minutes": playMinutes])
        save()
    }

    /// Coins the island pack gives: most of the next island's price.
    var islandPackCoins: Int {
        let next = world.islands.map(\.id).first { !s.owned.contains($0) } ?? (world.islands.count - 1)
        return max(200, Int(Double(islandPrice(next)) * 0.6))
    }

    func grantOffer(_ p: ShopProduct) {
        let perk = BloomOffers.perk(p)
        if !perk.isEmpty && !s.perks.contains(perk) { s.perks.append(perk) }
        Analytics.shared.track("bloom_offer_bought", ["product": p.rawValue, "level": level, "minutes": playMinutes])
        switch p {
        case .brave:
            s.gems += 100
            hp = maxHP
            showToast(BloomToast(title: tr("Сердце смельчака"), subtitle: tr("+2 сердца навсегда")))
        case .crafter:
            showToast(BloomToast(title: tr("Мастер на все руки"), subtitle: tr("Все здания работают вдвое быстрее")))
        case .digger:
            s.gems += 200
            if !s.shovel { s.shovel = true }
            showToast(BloomToast(title: tr("Кладоискатель"), subtitle: tr("Клады теперь вдвое богаче")))
        case .islandPack:
            let c = islandPackCoins
            s.islandPacks += 1
            s.coins += c
            s.gems += 100
            showToast(BloomToast(title: tr("Остров ближе"), subtitle: tr("+%@ монет, +%@ росинок", c, 100)))
        case .friend:
            if !s.pets.contains("bee") { s.pets.append("bee") }
            s.pet = "bee"
            onPetChanged?()
            showToast(BloomToast(title: tr("Друг острова"), subtitle: tr("Шмелик летит к тебе!")))
        case .level10:
            s.gems += 300
            add(.wood, 150); add(.stone, 150); add(.iron_bar, 20)
            if !s.skins.contains("rose") { s.skins.append("rose") }
            s.skin = "rose"
            showToast(BloomToast(title: tr("Набор 10 уровня"), subtitle: tr("Облик «%@» уже на тебе!", tr("Розовый сад"))))
        case .level20:
            s.gems += 800
            add(.gold_bar, 30); add(.glass, 30); add(.crystal, 10)
            if !s.skins.contains("night") { s.skins.append("night") }
            if !s.pets.contains("owl") { s.pets.append("owl") }
            s.skin = "night"
            s.pet = "owl"
            onPetChanged?()
            showToast(BloomToast(title: tr("Набор 20 уровня"), subtitle: tr("Облик «%@» уже на тебе!", tr("Ночной"))))
        default: break
        }
    }

    // MARK: pets

    func ownsPet(_ id: String) -> Bool { s.pets.contains(id) }

    func pickPet(_ p: PetDef) {
        if !ownsPet(p.id) {
            guard let g = p.gems, spend(g, "pet." + p.id) else { if p.gems != nil { panel = .shop }; return }
            s.pets.append(p.id)
            Sfx.play(.victory)
        }
        s.pet = s.pet == p.id ? nil : p.id
        onPetChanged?()
        save()
    }

    // MARK: decorations

    func placeDecor(_ d: DecorDef) {
        guard s.gems >= d.gems else { Sfx.play(.error); panel = .shop; return }
        guard let cell = placeDecorCell?() else { Sfx.play(.error); showToast(BloomToast(title: tr("Здесь тесно"), subtitle: tr("Отойди на свободное место"))); return }
        _ = spend(d.gems, "decor." + d.id)
        let pd = PlacedDecor(kind: d.id, cell: cell)
        s.decor.append(pd)
        bump("decor")
        panel = nil
        onDecorPlaced?(pd)
        save()
    }

    // MARK: pass: daily dew

    var passDewReady: Bool { passActive && s.passDewDay != BloomMeta.dayKey() }

    func claimPassDew() {
        guard passDewReady else { return }
        s.passDewDay = BloomMeta.dayKey()
        s.gems += BloomOffers.passDew
        Sfx.play(.coin)
        showToast(BloomToast(title: tr("Пропуск цветения"), subtitle: tr("+%@ росинок", BloomOffers.passDew)))
        save()
    }
}
