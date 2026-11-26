import SwiftUI
import UIKit

/// Card of a working building, opened by tapping it on the farm or from the
/// manor card. Top: level and a strip of all levels (done, open, locked by
/// the manor). Middle: what the next level gives and costs. «Все уровни»
/// opens the full table. Layout rules: docs/ui-guidelines.md (320 pt card,
/// 48 pt buttons, centred).
struct BuildingCard: View {
    @EnvironmentObject private var store: FarmStore
    let id: String
    @State private var error: FarmError?
    @State private var showAll = false

    var body: some View {
        let farm = store.farm
        let cfg = store.config
        let ru = L.ru
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { store.showBuilding = nil }
            if let b = cfg.building(id) {
                let level = farm.buildingLevel(id, config: cfg)
                VStack(spacing: 12) {
                    BText((b.localizedName) + (ru ? " · ур. " : " · level ") + "\(level)/\(b.maxLevel)", 20)
                    Image(Buildings.image(id, level: level)).interpolation(.none).resizable().scaledToFit()
                        .frame(width: 96, height: 96)
                        .saturation(level == 0 ? 0 : 1)
                        .opacity(level == 0 ? 0.6 : 1)
                    LevelStrip(level: level, max: b.maxLevel, manor: farm.manorLevel, unlock: b.unlockManor)
                    effectLine(b, level: level)
                    builderSection(b, level: level)
                    Button { showAll = true } label: {
                        BText(ru ? "Все уровни" : "All levels", 13, BText.ink.opacity(0.8))
                            .frame(minWidth: 120, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .frame(width: 320)
                .background(
                    Image("ui_panel").interpolation(.none)
                        .resizable(capInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12), resizingMode: .stretch)
                )
                .sheet(isPresented: $showAll) {
                    BuildingLevelsList(building: b, level: level, manor: farm.manorLevel)
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }

    /// "Урожай растёт быстрее: 4.5% → 6%" and the Мощь of the next level.
    @ViewBuilder
    private func effectLine(_ b: GameConfig.BuildingType, level: Int) -> some View {
        let now = b.bonus(at: level)
        let next = level < b.maxLevel ? b.bonus(at: level + 1) : now
        VStack(spacing: 4) {
            BText(Buildings.effectTitle(b.effect), 15)
            HStack(spacing: 6) {
                BText(Buildings.percent(now), 15)
                if next > now {
                    BText("→", 15)
                    BText(Buildings.percent(next), 15, BText.good)
                }
            }
            if level < b.maxLevel {
                BText((L.ru ? "+\(b.levels[level].power) Мощи" : "+\(b.levels[level].power) Power"), 13, BText.ink.opacity(0.75))
            }
        }
    }

    @ViewBuilder
    private func builderSection(_ b: GameConfig.BuildingType, level: Int) -> some View {
        let farm = store.farm
        let cfg = store.config
        let ru = L.ru
        if let w = farm.work, w.building == id {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let left = max(0, Int(w.readyAt.timeIntervalSince(store.now).rounded(.up)))
                let total = Double(farm.nextBuilding(id, config: cfg)?.seconds ?? 1)
                VStack(spacing: 8) {
                    BText((ru ? "Стройка ур. \(level + 1): " : "Building level \(level + 1): ") + Buildings.clock(left))
                    ProgressView(value: max(0, total - Double(left)), total: max(1, total))
                        .tint(Color(red: 0.3, green: 0.5, blue: 0.75))
                        .frame(width: 220)
                }
            }
            HStack(spacing: 12) {
                closeButton
                SpeedUpButton(target: SpeedTarget(kind: SpeedTarget.build), width: 120, height: 48)
            }
        } else if let next = farm.nextBuilding(id, config: cfg) {
            let crops = next.crops ?? [:]
            HStack(spacing: 10) {
                BuildCostChip(image: "ui_coin", have: farm.coins, need: next.coins)
                ForEach(crops.sorted(by: { $0.key < $1.key }), id: \.key) { crop, n in
                    BuildCostChip(image: "\(crop)_3", have: farm.barn[crop, default: 0], need: n)
                }
                BText("⏱ " + Buildings.duration(next.seconds), 13)
            }
            let needManor = max(b.unlockManor, level + 1)
            if farm.manorLevel < needManor {
                BText(ru ? "Нужна Усадьба \(needManor) ур." : "Needs Manor level \(needManor)", 13, BText.bad)
            } else if farm.busy {
                BText(ru ? "Строитель занят другой стройкой" : "The builder is busy", 13, BText.bad)
            } else if let error {
                BText(Buildings.message(error), 13, BText.bad)
            }
            HStack(spacing: 12) {
                closeButton
                let can = farm.manorLevel >= needManor && !farm.busy && farm.coins >= next.coins
                    && crops.allSatisfy { farm.barn[$0.key, default: 0] >= $0.value }
                Button {
                    if let e = store.upgradeBuilding(id) {
                        error = e
                        Sfx.play(.error)
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    } else {
                        error = nil
                        Sfx.play(.till)
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                } label: {
                    BText(level == 0 ? (ru ? "Построить" : "Build") : (ru ? "Улучшить" : "Upgrade"))
                        .frame(width: 120, height: 48).background(slot(can))
                }
                .buttonStyle(.plain)
                .opacity(can ? 1 : 0.5)
            }
        } else {
            BText(ru ? "Максимальный уровень!" : "Top level!")
            closeButton
        }
    }

    private var closeButton: some View {
        Button { store.showBuilding = nil } label: {
            BText(L.ru ? "Закрыть" : "Close").frame(width: 120, height: 48).background(slot(false))
        }
        .buttonStyle(.plain)
    }
}

/// All levels in one strip: filled = built, outlined = can be built now,
/// dim = needs a higher manor. Every fifth level is taller: a new look.
struct LevelStrip: View {
    let level: Int
    let max: Int
    let manor: Int
    let unlock: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(1...max, id: \.self) { l in
                let built = l <= level
                let open = !built && l <= manor && manor >= unlock
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(built ? BText.good : open ? BText.ink.opacity(0.25) : BText.ink.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(BText.ink.opacity(open ? 0.5 : 0.15), lineWidth: 1))
                    .frame(width: 8, height: l % 5 == 0 ? 16 : 11)
            }
        }
        .frame(height: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(level) / \(max)")
    }
}

/// The full table: level, bonus, Мощь, coins, time, state.
struct BuildingLevelsList: View {
    let building: GameConfig.BuildingType
    let level: Int
    let manor: Int

    var body: some View {
        let ru = L.ru
        NavigationStack {
            List {
                ForEach(Array(building.levels.enumerated()), id: \.offset) { i, l in
                    let n = i + 1
                    let needManor = Swift.max(building.unlockManor, n)
                    HStack(spacing: 8) {
                        BText((ru ? "Ур. " : "Lv ") + "\(n)", 14).frame(width: 52, alignment: .leading)
                        BText(Buildings.percent(building.bonus(at: n)), 14).frame(width: 52, alignment: .leading)
                        BText("+\(l.power)", 13, BText.ink.opacity(0.75)).frame(width: 52, alignment: .leading)
                        BText(Buildings.coins(l.coins), 13).frame(width: 56, alignment: .trailing)
                        Spacer(minLength: 4)
                        if n <= level {
                            BText("✓", 15, BText.good)
                        } else if manor < needManor {
                            BText((ru ? "Ус. " : "M ") + "\(needManor)", 12, BText.bad)
                        } else {
                            BText(Buildings.duration(l.seconds), 12, BText.ink.opacity(0.75))
                        }
                    }
                    .frame(minHeight: 36)
                    .listRowBackground(n % 5 == 0 ? BText.good.opacity(0.12) : Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle(building.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 8) {
                    BText(ru ? "Уровень" : "Level", 12).frame(width: 52, alignment: .leading)
                    BText(ru ? "Бонус" : "Bonus", 12).frame(width: 52, alignment: .leading)
                    BText(ru ? "Мощь" : "Power", 12).frame(width: 52, alignment: .leading)
                    BText(ru ? "Цена" : "Cost", 12).frame(width: 56, alignment: .trailing)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(.bar)
            }
        }
    }
}

struct BuildCostChip: View {
    let image: String
    let have: Int
    let need: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(image).interpolation(.none).resizable().scaledToFit().frame(width: 20, height: 24)
            BText(Buildings.coins(need), 13, have >= need ? BText.ink : BText.bad)
        }
    }
}

/// Heavy rounded text used across the building screens.
struct BText: View {
    static let ink = Color(uiColor: Palette.ink)
    static let bad = Color(red: 0.75, green: 0.18, blue: 0.25)
    static let good = Color(red: 0.3, green: 0.62, blue: 0.25)

    let s: String
    let size: CGFloat
    let color: Color

    init(_ s: String, _ size: CGFloat = 15, _ color: Color = BText.ink) {
        self.s = s
        self.size = size
        self.color = color
    }

    var body: some View {
        Text(s).font(.system(size: size, weight: .heavy, design: .rounded)).foregroundStyle(color)
            .lineLimit(2).minimumScaleFactor(0.75)
    }
}

enum Buildings {
    /// Sprite for a building: its look changes every 5 levels (tiers 0...2 for now).
    static func image(_ id: String, level: Int) -> String {
        if id == "mill" { return "prop_windmill" }
        return "bld_\(id)_\(min(2, max(0, level - 1) / 10))"
    }

    static func effectTitle(_ effect: String) -> String {
        let ru = L.ru
        switch effect {
        case Effect.grow: return ru ? "Урожай растёт быстрее" : "Crops grow faster"
        case Effect.sell: return ru ? "Урожай продаётся дороже" : "Crops sell for more"
        case Effect.buildTime: return ru ? "Пугала строятся быстрее" : "Scarecrows build faster"
        case Effect.armyPower: return ru ? "Пугала сильнее в бою" : "Scarecrows fight harder"
        case Effect.orderReward: return ru ? "Больше монет за заказы" : "More coins for orders"
        case Effect.raidCooldown: return ru ? "Лагеря готовы к набегу раньше" : "Camps are ready sooner"
        default: return effect
        }
    }

    static func percent(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))%" : String(format: "%.1f%%", v)
    }

    static func coins(_ n: Int) -> String {
        n >= 10_000 ? "\(n / 1000)k" : "\(n)"
    }

    static func duration(_ s: Int) -> String {
        let ru = L.ru
        if s < 60 { return "\(s) " + (ru ? "сек" : "s") }
        if s < 3600 { return "\(s / 60) " + (ru ? "мин" : "min") }
        let h = s / 3600, m = s % 3600 / 60
        return m == 0 || h >= 10 ? "\(h) " + (ru ? "ч" : "h") : "\(h) " + (ru ? "ч " : "h ") + "\(m) " + (ru ? "мин" : "min")
    }

    static func clock(_ s: Int) -> String {
        if s >= 3600 { return "\(s / 3600):\(String(format: "%02d", s % 3600 / 60)):\(String(format: "%02d", s % 60))" }
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    static func message(_ e: FarmError) -> String {
        let ru = L.ru
        switch e {
        case .notEnoughCoins: return ru ? "Не хватает монет" : "Not enough coins"
        case .notEnoughCrops: return ru ? "Не хватает урожая в амбаре" : "Not enough crops in the barn"
        case .manorTooLow: return ru ? "Сначала улучши Усадьбу" : "Upgrade the manor first"
        case .busy: return ru ? "Строитель занят" : "The builder is busy"
        default: return e.rawValue
        }
    }

    /// Whether the player can start this building's next level right now
    /// (for the red dot on the manor card).
    static func canUpgrade(_ id: String, farm: Farm, config: GameConfig) -> Bool {
        guard let b = config.building(id), !farm.busy, let next = farm.nextBuilding(id, config: config) else { return false }
        let level = farm.buildingLevel(id, config: config)
        guard farm.manorLevel >= max(b.unlockManor, level + 1), farm.coins >= next.coins else { return false }
        return (next.crops ?? [:]).allSatisfy { farm.barn[$0.key, default: 0] >= $0.value }
    }
}
