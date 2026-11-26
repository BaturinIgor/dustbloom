import SwiftUI
import UIKit

/// The Усадьба card, opened by tapping the house: level, look, what the next
/// level costs and gives, the build timer with a speedup.
/// Layout rules: docs/ui-guidelines.md (300 pt card, 48 pt buttons, centred).
struct ManorCard: View {
    @EnvironmentObject private var store: FarmStore
    @State private var error: FarmError?

    private let ink = Color(uiColor: Palette.ink)
    private let bad = Color(red: 0.75, green: 0.18, blue: 0.25)

    private func text(_ s: String, _ size: CGFloat = 15, _ color: Color? = nil) -> some View {
        Text(s).font(.system(size: size, weight: .heavy, design: .rounded)).foregroundStyle(color ?? ink)
    }

    var body: some View {
        let farm = store.farm
        let cfg = store.config
        let ru = L.ru
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { store.showManor = false }
            VStack(spacing: 12) {
                text((ru ? "Усадьба · ур. " : "Manor · level ") + "\(farm.manorLevel)/\(cfg.manor.maxLevel)", 20)
                HStack(alignment: .bottom, spacing: 16) {
                    look(farm.manorTier, size: 96)
                    if farm.nextManor(config: cfg) != nil, farm.manorLevel % 5 == 0, farm.manorTier < 5 {
                        // the next level brings a new look
                        text("→", 20)
                        look(farm.manorTier + 1, size: 72).opacity(0.85)
                    }
                }
                text(ru ? "Главное здание. Даёт место в армии каждые \(cfg.manor.armySlotEvery) уровня, а уровни других зданий не выше её уровня."
                        : "The main building. Adds an army slot every \(cfg.manor.armySlotEvery) levels; other buildings can't outgrow it.", 13, ink.opacity(0.75))
                    .multilineTextAlignment(.center)

                if let ready = farm.manorReadyAt {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let left = max(0, Int(ready.timeIntervalSince(store.now).rounded(.up)))
                        // while building, nextManor is the level being built
                        let total = Double(farm.nextManor(config: cfg)?.seconds ?? 1)
                        VStack(spacing: 8) {
                            text((ru ? "Стройка ур. \(farm.manorLevel + 1): " : "Building level \(farm.manorLevel + 1): ") + clock(left))
                            ProgressView(value: max(0, total - Double(left)), total: max(1, total))
                                .tint(Color(red: 0.3, green: 0.5, blue: 0.75))
                                .frame(width: 220)
                        }
                    }
                    HStack(spacing: 12) {
                        closeButton
                        SpeedUpButton(target: SpeedTarget(kind: SpeedTarget.build), width: 120, height: 48)
                    }
                } else if let next = farm.nextManor(config: cfg) {
                    // cost chips: coins, crops, player level, time
                    HStack(spacing: 10) {
                        chip("ui_coin", farm.coins, next.coins)
                        ForEach(next.crops.sorted(by: { $0.key < $1.key }), id: \.key) { crop, n in
                            chip("\(crop)_3", farm.barn[crop, default: 0], n)
                        }
                    }
                    HStack(spacing: 16) {
                        text((ru ? "Уровень " : "Level ") + "\(next.playerLevel)", 13, farm.level >= next.playerLevel ? ink : bad)
                        text("⏱ " + (next.seconds < 60 ? "\(next.seconds) " + (ru ? "сек" : "s") : Items.duration(next.seconds)), 13)
                    }
                    if let error {
                        text(message(error), 13, bad)
                    }
                    HStack(spacing: 12) {
                        closeButton
                        let can = farm.level >= next.playerLevel && farm.coins >= next.coins
                            && next.crops.allSatisfy { farm.barn[$0.key, default: 0] >= $0.value }
                        Button {
                            if let e = store.upgradeManor() {
                                error = e
                                Sfx.play(.error)
                                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            } else {
                                error = nil
                                Sfx.play(.till)
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            }
                        } label: {
                            text(ru ? "Улучшить" : "Upgrade").frame(width: 120, height: 48).background(slot(can))
                        }
                        .buttonStyle(.plain)
                        .opacity(can ? 1 : 0.5)
                    }
                } else {
                    text(ru ? "Усадьба на максимальном уровне!" : "The manor is at its top level!")
                    closeButton
                }
            }
            .padding(20)
            .frame(width: 320)
            .background(
                Image("ui_panel").interpolation(.none)
                    .resizable(capInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12), resizingMode: .stretch)
            )
        }
    }

    private var closeButton: some View {
        Button { store.showManor = false } label: {
            text(L.ru ? "Закрыть" : "Close").frame(width: 120, height: 48).background(slot(false))
        }
        .buttonStyle(.plain)
    }

    private func look(_ tier: Int, size: CGFloat) -> some View {
        Image("prop_manor_\(tier)").interpolation(.none).resizable().frame(width: size, height: size)
    }

    private func chip(_ image: String, _ have: Int, _ need: Int) -> some View {
        HStack(spacing: 4) {
            Image(image).interpolation(.none).resizable().scaledToFit().frame(width: 20, height: 24)
            text(need >= 10_000 ? "\(need / 1000)k" : "\(need)", 13, have >= need ? ink : bad)
        }
    }

    private func message(_ e: FarmError) -> String {
        let ru = L.ru
        switch e {
        case .notEnoughCoins: return ru ? "Не хватает монет" : "Not enough coins"
        case .notEnoughCrops: return ru ? "Не хватает урожая в амбаре" : "Not enough crops in the barn"
        case .cropLocked: return ru ? "Нужен уровень повыше" : "Your level is too low"
        case .busy: return ru ? "Стройка уже идёт" : "Already building"
        default: return e.rawValue
        }
    }

    private func clock(_ s: Int) -> String {
        if s >= 3600 { return "\(s / 3600):\(String(format: "%02d", s % 3600 / 60)):\(String(format: "%02d", s % 60))" }
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}
