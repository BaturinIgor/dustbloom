import SwiftUI
import UIKit

/// The stage-1 screens in one bottom sheet over the farm: Barn (sell crops),
/// Orders, Workshop (build scarecrows), Raids (send the army), Storage (Склад).
/// Layout rules: docs/ui-guidelines.md.
enum ArmyTab: String, CaseIterable, Identifiable {
    case barn, orders, workshop, raids, storage
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .barn: return "icon_barn"
        case .orders: return "icon_orders"
        case .workshop: return "icon_workshop"
        case .raids: return "icon_raid"
        case .storage: return "icon_storage"
        }
    }

    var title: String {
        let ru = Locale.current.language.languageCode?.identifier == "ru"
        switch self {
        case .barn: return ru ? "Амбар" : "Barn"
        case .orders: return ru ? "Заказы" : "Orders"
        case .workshop: return ru ? "Мастерская" : "Workshop"
        case .raids: return ru ? "Набеги" : "Raids"
        case .storage: return ru ? "Склад" : "Storage"
        }
    }
}

/// Small strings until the localisation files arrive (stage 2).
enum L {
    static var ru: Bool { Locale.current.language.languageCode?.identifier == "ru" }
    static var sell: String { ru ? "Продать" : "Sell" }
    static var sellAll: String { ru ? "Все" : "All" }
    static var build: String { ru ? "Собрать" : "Build" }
    static var attack: String { ru ? "В атаку" : "Attack" }
    static var emptyBarn: String { ru ? "Амбар пуст. Собери урожай на грядках." : "The barn is empty. Harvest your beds." }
    static var army: String { ru ? "Армия" : "Army" }
    static var queue: String { ru ? "В работе" : "Building" }
    static var victory: String { ru ? "Победа!" : "Victory!" }
    static var defeat: String { ru ? "Поражение" : "Defeat" }
    static var defeatHint: String { ru ? "Собери больше пугал и попробуй снова." : "Build more scarecrows and try again." }
    static func fell(_ n: Int) -> String { ru ? "Пало пугал: \(n)" : "Scarecrows lost: \(n)" }
    static func level(_ n: Int) -> String { ru ? "с уровня \(n)" : "level \(n)" }
}

private let ink = Color(uiColor: Palette.ink)
private let bad = Color(red: 0.75, green: 0.18, blue: 0.25)

private func label(_ text: String, size: CGFloat = 15, color: Color = ink) -> some View {
    Text(text).font(.system(size: size, weight: .heavy, design: .rounded)).foregroundStyle(color)
}

struct ArmySheet: View {
    @EnvironmentObject private var store: FarmStore
    @State var tab: ArmyTab

    var body: some View {
        VStack(spacing: 12) {
            // tab bar: five equal slots, centred
            HStack(spacing: 8) {
                ForEach(ArmyTab.allCases) { t in
                    Button {
                        tab = t
                        Sfx.play(.select, volume: 0.6)
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        VStack(spacing: 2) {
                            Image(t.icon).interpolation(.none).resizable().frame(width: 32, height: 32)
                            label(t.title, size: 13)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .padding(.horizontal, 4)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(slot(t == tab))
                    }
                    .buttonStyle(.plain)
                }
            }
            ScrollView {
                switch tab {
                case .barn: BarnTab()
                case .orders: OrdersTab()
                case .workshop: WorkshopTab()
                case .raids: RaidsTab()
                case .storage: StorageTab()
                }
            }
        }
        .padding(16)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in store.settle() }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(uiColor: Palette.parchment))
    }
}

func slot(_ selected: Bool) -> some View {
    Image(selected ? "ui_slot_selected" : "ui_slot")
        .interpolation(.none)
        .resizable(capInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12), resizingMode: .stretch)
}

/// "have / need" cost chip: ink when enough, red when not.
private struct CostChip: View {
    let image: String
    let have: Int
    let need: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(image).interpolation(.none).resizable().scaledToFit().frame(width: 20, height: 24)
            label("\(have)/\(need)", size: 13, color: have >= need ? ink : bad)
                .fixedSize()
        }
    }
}

private struct BarnTab: View {
    @EnvironmentObject private var store: FarmStore

    var body: some View {
        let rows = store.config.crops.filter { store.farm.barn[$0.id, default: 0] > 0 }
        VStack(spacing: 8) {
            if rows.isEmpty {
                label(L.emptyBarn).multilineTextAlignment(.center).padding(.top, 24)
            }
            ForEach(rows) { crop in
                let have = store.farm.barn[crop.id, default: 0]
                HStack(spacing: 12) {
                    Image("\(crop.id)_3").interpolation(.none).resizable().frame(width: 32, height: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        label(crop.localizedName)
                        HStack(spacing: 4) {
                            label("×\(have)", size: 13)
                            Image("ui_coin").interpolation(.none).resizable().frame(width: 14, height: 14)
                            label("\(crop.sellPrice)", size: 13)
                        }
                    }
                    Spacer()
                    sellButton(L.sell + " 1") { store.sell(crop.id, count: 1) }
                    sellButton(L.sellAll) { store.sell(crop.id, count: have) }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 64)
                .background(slot(false))
            }
        }
    }

    private func sellButton(_ title: String, _ action: @escaping () -> Int?) -> some View {
        Button {
            if action() != nil {
                Sfx.play(.coin, volume: 0.8)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } label: {
            label(title, size: 13).frame(minWidth: 56, minHeight: 44).background(slot(true))
        }
        .buttonStyle(.plain)
    }
}

private struct OrdersTab: View {
    @EnvironmentObject private var store: FarmStore
    @State private var paid: Int?

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(store.farm.orders.enumerated()), id: \.offset) { i, order in
                HStack(spacing: 12) {
                    if let ready = order.readyAt {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            label((L.ru ? "Новый заказ через " : "New order in ") + timeLeft(ready, store.now), size: 13)
                        }
                        Spacer()
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                ForEach(order.items.sorted(by: { $0.key < $1.key }), id: \.key) { crop, n in
                                    CostChip(image: "\(crop)_3", have: store.farm.barn[crop, default: 0], need: n)
                                }
                            }
                            HStack(spacing: 4) {
                                Image("ui_coin").interpolation(.none).resizable().frame(width: 16, height: 16)
                                label("\(order.coins)", size: 13)
                                label("  XP \(order.xp)", size: 13)
                            }
                        }
                        Spacer()
                        Button {
                            store.skipOrder(i)
                            Sfx.play(.select, volume: 0.5)
                        } label: {
                            label("✕", size: 15).frame(width: 44, height: 44).background(slot(false))
                        }
                        .buttonStyle(.plain)
                        let can = store.farm.canDeliver(i)
                        Button {
                            if let r = store.deliverOrder(i) {
                                Sfx.play(.coin)
                                if r.levelUp { Sfx.play(.levelUp, after: 0.3) }
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { paid = r.coins }
                            }
                        } label: {
                            label(L.ru ? "Отдать" : "Deliver", size: 13).frame(minWidth: 72, minHeight: 44).background(slot(can))
                        }
                        .buttonStyle(.plain)
                        .disabled(!can)
                        .opacity(can ? 1 : 0.5)
                    }
                }
                .padding(12)
                .frame(minHeight: 72)
                .background(slot(false))
            }
            if let paid {
                HStack(spacing: 4) {
                    Image("ui_coin").interpolation(.none).resizable().frame(width: 20, height: 20)
                    PixelText(text: "+\(paid)", scale: 2)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

private struct WorkshopTab: View {
    @EnvironmentObject private var store: FarmStore
    @State private var shake: String?

    var body: some View {
        VStack(spacing: 8) {
            // army strip: filled and free slots
            HStack(spacing: 4) {
                label("\(L.army) \(store.farm.army.count)/\(store.farm.armySlots(config: store.config))", size: 13)
                Spacer()
                if !store.farm.queue.isEmpty {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        label("\(L.queue): \(store.farm.queue.count) · \(timeLeft(store.farm.queue[0].readyAt, store.now))", size: 13)
                    }
                }
            }
            if !store.farm.queue.isEmpty {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    if let last = store.farm.queue.last {
                        HStack {
                            label((L.ru ? "Вся очередь: " : "Whole queue: ") + timeLeft(last.readyAt, store.now), size: 13)
                            Spacer()
                            SpeedUpButton(target: SpeedTarget(kind: SpeedTarget.recruit))
                        }
                    }
                }
            }
            ForEach(store.config.scarecrows) { sc in
                let locked = store.farm.level < sc.unlockLevel
                HStack(spacing: 12) {
                    Image("unit_\(sc.id)").interpolation(.none).resizable().frame(width: 48, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        label(sc.localizedName)
                        label("♥\(sc.hp)  ⚔\(sc.attack)  ⏱\(sc.buildSeconds)s", size: 12)
                        HStack(spacing: 8) {
                            ForEach(sc.cost.sorted(by: { $0.key < $1.key }), id: \.key) { crop, n in
                                CostChip(image: "\(crop)_3", have: store.farm.barn[crop, default: 0], need: n)
                            }
                            CostChip(image: "ui_coin", have: store.farm.coins, need: sc.coins)
                        }
                    }
                    Spacer()
                    Button {
                        if let err = store.build(sc.id) {
                            Sfx.play(.error)
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            withAnimation(.default) { shake = sc.id }
                            _ = err
                        } else {
                            Sfx.play(.plant)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    } label: {
                        label(locked ? L.level(sc.unlockLevel) : L.build, size: 13)
                            .frame(minWidth: 72, minHeight: 44)
                            .background(slot(!locked))
                    }
                    .buttonStyle(.plain)
                    .disabled(locked)
                }
                .padding(12)
                .background(slot(false))
                .opacity(locked ? 0.6 : 1)
                .offset(x: shake == sc.id ? 6 : 0)
                .onChange(of: shake) { _, v in
                    if v != nil { withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) { shake = nil } }
                }
            }
        }
    }
}

private struct RaidsTab: View {
    @EnvironmentObject private var store: FarmStore
    @State private var result: RaidResult?
    @State private var busy = false

    var body: some View {
        VStack(spacing: 8) {
            if let r = result {
                VStack(spacing: 4) {
                    label(r.won ? L.victory : L.defeat, size: 22, color: r.won ? ink : bad)
                    if r.won {
                        HStack(spacing: 4) {
                            Image("ui_coin").interpolation(.none).resizable().frame(width: 20, height: 20)
                            PixelText(text: "+\(r.coins)", scale: 2)
                        }
                    } else {
                        label(L.defeatHint, size: 13)
                    }
                    if let lost = r.lost, !lost.isEmpty { label(L.fell(lost.count), size: 13) }
                }
                .frame(maxWidth: .infinity, minHeight: 88)
                .background(slot(r.won))
                .transition(.scale.combined(with: .opacity))
            }
            ForEach(store.config.raids) { raid in
                let locked = store.farm.level < raid.unlockLevel
                HStack(spacing: 12) {
                    Image("enemy_\(raid.id)").interpolation(.none).resizable().scaledToFit().frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        label(raid.localizedName)
                        label("×\(raid.enemies.count)  ♥\(raid.enemies.map(\.hp).reduce(0, +))  ⚔\(raid.enemies.map(\.attack).reduce(0, +))", size: 12)
                        HStack(spacing: 4) {
                            Image("ui_coin").interpolation(.none).resizable().frame(width: 14, height: 14)
                            label("\(raid.rewardCoins)", size: 13)
                        }
                    }
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let ready = store.farm.raidReadyAt[raid.id].map { $0 <= store.now } ?? true
                        Button { Task { await attack(raid.id) } } label: {
                            label(locked ? L.level(raid.unlockLevel) : ready ? L.attack : timeLeft(store.farm.raidReadyAt[raid.id]!, store.now), size: 13)
                                .frame(minWidth: 80, minHeight: 44)
                                .background(slot(!locked && ready))
                        }
                        .buttonStyle(.plain)
                        .disabled(locked || !ready || busy || store.farm.army.isEmpty)
                    }
                }
                .padding(12)
                .background(slot(false))
                .opacity(locked ? 0.6 : 1)
            }
        }
    }

    private func attack(_ id: String) async {
        busy = true
        defer { busy = false }
        switch await store.raid(id) {
        case .success(let r):
            Sfx.play(r.won ? .victory : .defeat)
            UINotificationFeedbackGenerator().notificationOccurred(r.won ? .success : .error)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { result = r }
        case .failure:
            Sfx.play(.error)
        }
    }
}

private func timeLeft(_ date: Date, _ now: Date) -> String {
    let s = max(0, Int(date.timeIntervalSince(now).rounded(.up)))
    return s >= 60 ? "\(s / 60):\(String(format: "%02d", s % 60))" : "\(s)s"
}
