import SwiftUI
import UIKit

/// Storage (Склад) screens: the storage tab, the item chip, the speedup
/// button and the "speed up this crop" card. Layout rules: docs/ui-guidelines.md.
enum Items {
    static func image(_ id: String) -> String {
        if id.hasPrefix("speed_") {
            let target = id.split(separator: "_").dropFirst().first.map(String.init) ?? "any"
            return "item_speed_\(target)"
        }
        if id == GameConfig.coinsItem { return "ui_coin" }
        return "item_\(id)"
    }

    static func duration(_ seconds: Int) -> String {
        let ru = L.ru
        if seconds < 3600 { return "\(seconds / 60) " + (ru ? "мин" : "min") }
        return "\(seconds / 3600) " + (ru ? "ч" : "h")
    }

    static func title(_ id: String, config: GameConfig) -> String {
        if let s = config.speedup(id) { return duration(s.seconds) }
        if let c = config.chest(id) { return c.localizedName }
        if id == GameConfig.coinsItem { return L.ru ? "Монеты" : "Coins" }
        return id
    }

    static func targetTitle(_ target: String) -> String {
        let ru = L.ru
        switch target {
        case "recruit": return ru ? "Найм пугал" : "Scarecrow building"
        case "grow": return ru ? "Рост урожая" : "Crop growth"
        case "build": return ru ? "Стройка" : "Construction"
        default: return ru ? "Любые ускорения" : "Any speedups"
        }
    }

    static func targetHint(_ target: String) -> String {
        let ru = L.ru
        switch target {
        case "recruit": return ru ? "Только для мастерской" : "Workshop only"
        case "grow": return ru ? "Только для грядок" : "Beds only"
        case "build": return ru ? "Только для зданий" : "Buildings only"
        default: return ru ? "Подходят для всего" : "Work on anything"
        }
    }
}

private let ink = Color(uiColor: Palette.ink)
private let bad = Color(red: 0.75, green: 0.18, blue: 0.25)

private func text(_ s: String, _ size: CGFloat = 15, _ color: Color = ink) -> some View {
    Text(s).font(.system(size: size, weight: .heavy, design: .rounded)).foregroundStyle(color)
}

/// Square item tile: icon, short title under it, count badge in the corner.
struct ItemChip: View {
    let id: String
    let count: Int
    let config: GameConfig

    var body: some View {
        VStack(spacing: 2) {
            Image(Items.image(id)).interpolation(.none).resizable().frame(width: 32, height: 32)
            text(Items.title(id, config: config), 12)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 64, height: 64)
        .background(slot(false))
        .overlay(alignment: .topTrailing) {
            if count > 1 {
                text("×\(count)", 11, .white)
                    .padding(.horizontal, 4)
                    .background(Capsule().fill(Color(uiColor: Palette.outline)))
                    .offset(x: 4, y: -4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Items.title(id, config: config)) ×\(count)")
    }
}

struct StorageTab: View {
    @EnvironmentObject private var store: FarmStore
    @State private var loot: [String: Int]?
    @State private var busy = false

    private let columns = Array(repeating: GridItem(.fixed(64), spacing: 8), count: 4)

    var body: some View {
        let cfg = store.config
        let items = store.farm.items
        VStack(spacing: 12) {
            if let loot {
                LootBanner(loot: loot, config: cfg)
                    .transition(.scale.combined(with: .opacity))
                    .onTapGesture { withAnimation { self.loot = nil } }
            }
            // chests first: they are what the player acts on
            let chests = cfg.items.chests.filter { items[$0.id, default: 0] > 0 }
            ForEach(chests) { ch in
                let n = items[ch.id, default: 0]
                HStack(spacing: 12) {
                    Image(Items.image(ch.id)).interpolation(.none).resizable().frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        text(ch.localizedName)
                        text("×\(n)", 13)
                    }
                    Spacer()
                    Button { Task { await open(ch.id, 1) } } label: {
                        text(L.ru ? "Открыть" : "Open", 13).frame(minWidth: 80, minHeight: 44).background(slot(true))
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                    if n > 1 {
                        Button { Task { await open(ch.id, n) } } label: {
                            text(L.ru ? "Все" : "All", 13).frame(minWidth: 56, minHeight: 44).background(slot(false))
                        }
                        .buttonStyle(.plain)
                        .disabled(busy)
                    }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 72)
                .background(slot(false))
            }
            ForEach(cfg.items.speedupTargets, id: \.self) { target in
                let ids = cfg.items.speedupSeconds.map { GameConfig.speedupID(target: target, seconds: $0) }
                    .filter { items[$0, default: 0] > 0 }
                if !ids.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(Items.image("speed_\(target)_1m")).interpolation(.none).resizable().frame(width: 24, height: 24)
                            text(Items.targetTitle(target))
                            Spacer()
                            text(Items.targetHint(target), 12, ink.opacity(0.7))
                        }
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                            ForEach(ids, id: \.self) { id in
                                ItemChip(id: id, count: items[id, default: 0], config: cfg)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(slot(false))
                }
            }
            if items.isEmpty {
                text(L.ru ? "Склад пуст. Ускорения и сундуки дают за новый уровень, набеги и задания."
                          : "Storage is empty. Level-ups, raids and quests fill it with speedups and chests.")
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
            } else {
                text(L.ru ? "Нажми «Ускорить» в мастерской, у Усадьбы или на растущей грядке: лучшие ускорения подберутся сами."
                          : "Tap Speed up in the workshop, at the manor or on a growing bed: the best speedups are picked for you.", 12, ink.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func open(_ id: String, _ n: Int) async {
        busy = true
        defer { busy = false }
        switch await store.openChest(id, count: n) {
        case .success(let got):
            Sfx.play(.chest)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { loot = got }
        case .failure:
            Sfx.play(.error)
        }
    }
}

/// "You got": a row of item chips that pops in after a chest opens.
struct LootBanner: View {
    let loot: [String: Int]
    let config: GameConfig

    var body: some View {
        VStack(spacing: 8) {
            text(L.ru ? "Добыча!" : "Loot!", 20)
            HStack(spacing: 8) {
                ForEach(loot.sorted(by: { $0.key < $1.key }), id: \.key) { id, n in
                    ItemChip(id: id, count: n, config: config)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(slot(true))
    }
}

/// Smart speedup button: shows the time it will save and spends the
/// speedups that waste the least. Hidden when nothing fits.
struct SpeedUpButton: View {
    @EnvironmentObject private var store: FarmStore
    let target: SpeedTarget
    var width: CGFloat? = nil
    var height: CGFloat = 44
    var onDone: (Int) -> Void = { _ in }

    var body: some View {
        let plan = (try? store.farm.planSpeedups(for: target, now: store.now, config: store.config)) ?? [:]
        let total = plan.reduce(0) { $0 + (store.config.speedup($1.key)?.seconds ?? 0) * $1.value }
        Button {
            switch store.smartSpeedup(target) {
            case .success(let r):
                Sfx.play(.speedup)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onDone(r.saved)
            case .failure:
                Sfx.play(.error)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        } label: {
            HStack(spacing: 4) {
                Image("item_speed_any").interpolation(.none).resizable().frame(width: 20, height: 20)
                text((L.ru ? "Ускорить " : "Speed up ") + Items.duration(max(60, total)), 13)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 8)
            .frame(minWidth: width ?? 88, maxWidth: width, minHeight: height)
            .background(slot(true))
        }
        .buttonStyle(.plain)
        .opacity(plan.isEmpty ? 0 : 1)
        .disabled(plan.isEmpty)
        .accessibilityHidden(plan.isEmpty)
    }
}

/// Card shown when the player taps a growing crop: time left and a speedup.
struct GrowOfferCard: View {
    @EnvironmentObject private var store: FarmStore
    let offer: FarmStore.TileRef

    var body: some View {
        let tile = store.farm.tile(x: offer.x, y: offer.y)
        let crop = tile?.crop.flatMap { store.config.crop($0) }
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { store.growOffer = nil }
            VStack(spacing: 12) {
                if let crop, let planted = tile?.plantedAt {
                    Image("\(crop.id)_3").interpolation(.none).resizable().frame(width: 48, height: 72)
                    text(crop.localizedName, 20)
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let total = tile?.growSeconds(crop) ?? crop.growSeconds
                        let left = max(0, Int((TimeInterval(total) - store.now.timeIntervalSince(planted)).rounded(.up)))
                        VStack(spacing: 8) {
                            text(left > 0 ? ((L.ru ? "Созреет через " : "Ripe in ") + clock(left))
                                          : (L.ru ? "Готово! Нажми на грядку." : "Ready! Tap the bed."), 15)
                            if left > 0 {
                                ProgressView(value: Double(total - left), total: Double(total))
                                    .tint(Color(red: 0.3, green: 0.62, blue: 0.25))
                                    .frame(width: 200)
                            }
                        }
                    }
                    let hasItems = (try? store.farm.planSpeedups(for: target, now: store.now, config: store.config)) != nil
                    HStack(spacing: 12) {
                        Button { store.growOffer = nil } label: {
                            text(L.ru ? "Закрыть" : "Close").frame(width: 120, height: 48).background(slot(false))
                        }
                        .buttonStyle(.plain)
                        if hasItems {
                            SpeedUpButton(target: target, width: 120, height: 48) { _ in store.growOffer = nil }
                        }
                    }
                    if !hasItems {
                        text(L.ru ? "Нет ускорений роста на складе." : "No growth speedups in storage.", 13, ink.opacity(0.7))
                    }
                } else {
                    text(L.ru ? "Грядка пуста" : "Empty bed", 18)
                    Button { store.growOffer = nil } label: {
                        text(L.ru ? "Закрыть" : "Close").frame(width: 120, height: 48).background(slot(false))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(width: 300)
            .background(
                Image("ui_panel").interpolation(.none)
                    .resizable(capInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12), resizingMode: .stretch)
            )
        }
    }

    private var target: SpeedTarget { SpeedTarget(kind: SpeedTarget.grow, x: offer.x, y: offer.y) }

    private func clock(_ s: Int) -> String {
        if s >= 3600 { return "\(s / 3600):\(String(format: "%02d", s % 3600 / 60)):\(String(format: "%02d", s % 60))" }
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}
