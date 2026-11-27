import SwiftUI

/// Calendar panel: 7-day login gifts and the three quests of the day.
struct DailyView: View {
    @EnvironmentObject private var game: BloomGame

    var body: some View {
        VStack(spacing: 10) {
            header(tr("Подарок за вход"))
            let cols = [GridItem(.fixed(72), spacing: 8), GridItem(.fixed(72), spacing: 8),
                        GridItem(.fixed(72), spacing: 8), GridItem(.fixed(72), spacing: 8)]
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(0..<BloomMeta.login.count, id: \.self) { i in loginTile(i) }
            }
            if game.loginReady {
                Button { game.claimLogin() } label: {
                    OutlinedText(text: tr("Забрать подарок"), size: 15).frame(maxWidth: .infinity)
                }
                .buttonStyle(BloomButtonStyle(color: BUI.orange, edge: BUI.orangeEdge))
            } else {
                OutlinedText(text: tr("Следующий подарок завтра"), size: 12, color: BUI.muted)
            }
            header(tr("Задания дня"))
            ForEach(Array(game.dailies.enumerated()), id: \.offset) { i, q in questRow(i, q) }
            bonusRow
            OutlinedText(text: tr("Новые задания каждый день в полночь"), size: 11, color: BUI.muted, fixed: false, lines: 2)
        }
    }

    private func header(_ t: String) -> some View {
        HStack(spacing: 8) {
            OutlinedText(text: t, size: 15, color: BUI.gold)
            Rectangle().fill(BUI.gold.opacity(0.35)).frame(height: 2)
        }
    }

    private func loginTile(_ i: Int) -> some View {
        let r = BloomMeta.login[i]
        let cur = game.loginDay
        let done = game.loginDone(i)
        let isNext = i == cur && game.loginReady
        let icon = r.chest ? "bloom_chest_closed" : r.golden ? "bloom_item_coin" : r.gems > 0 ? "bloom_item_gem" : "bloom_item_coin"
        let amount = r.golden ? tr("Золотой час") : r.gems > 0 ? (r.chest ? "\(r.gems) + " + tr("Сундук") : "\(r.gems)") : (r.coins * game.coinUnit).short
        return VStack(spacing: 3) {
            OutlinedText(text: tr("День %@", i + 1), size: 10, color: isNext ? BUI.gold : BUI.muted)
            ZStack {
                PixelIcon(name: icon, size: 28)
                if done { OutlinedText(text: "✓", size: 20, color: BUI.green) }
            }
            .frame(height: 30)
            OutlinedText(text: amount, size: 10, fixed: false)
        }
        .frame(width: 72, height: 78)
        .background(RoundedRectangle(cornerRadius: 12).fill(isNext ? BUI.orange.opacity(0.35) : BUI.panelHi))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isNext ? BUI.gold : BUI.ink.opacity(0.6), lineWidth: 2))
        .opacity(done ? 0.55 : 1)
    }

    private func questRow(_ i: Int, _ q: DailyQuest) -> some View {
        let k = game.dailyKind(q)
        let p = game.dailyProgress(q)
        return Card {
            HStack(spacing: 10) {
                PixelIcon(name: k?.icon ?? "bloom_tree", size: 34)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(BUI.ink.opacity(0.4)))
                VStack(alignment: .leading, spacing: 5) {
                    OutlinedText(text: tr(k?.title ?? "", q.target), size: 12.5, fixed: false, lines: 2, align: .leading)
                    ZStack(alignment: .leading) {
                        Capsule().fill(BUI.ink).frame(height: 10)
                        Capsule().fill(BUI.green).frame(width: max(10, 150 * CGFloat(p) / CGFloat(max(1, q.target))), height: 10)
                    }
                    .frame(width: 150, alignment: .leading)
                    OutlinedText(text: "\(p)/\(q.target)", size: 10, color: BUI.muted)
                }
                Spacer(minLength: 0)
                if q.claimed {
                    OutlinedText(text: "✓", size: 22, color: BUI.green).frame(width: 70)
                } else if game.dailyDone(q) {
                    Button { game.claimDaily(i) } label: { OutlinedText(text: tr("Забрать"), size: 13) }
                        .buttonStyle(BloomButtonStyle())
                        .frame(width: 80)
                } else {
                    VStack(spacing: 2) {
                        HStack(spacing: 2) { PixelIcon(name: "bloom_item_gem", size: 14); OutlinedText(text: "5", size: 11) }
                        HStack(spacing: 2) { PixelIcon(name: "bloom_item_coin", size: 14); OutlinedText(text: game.dailyReward.coins.short, size: 11) }
                    }
                    .frame(width: 70)
                }
            }
        }
    }

    private var bonusRow: some View {
        Card {
            HStack(spacing: 10) {
                PixelIcon(name: "bloom_chest_closed", size: 34).frame(width: 44, height: 44)
                OutlinedText(text: tr("Все три задания: +15 росинок и сундук"), size: 12, fixed: false, lines: 2, align: .leading)
                Spacer(minLength: 0)
                if game.dailyBonusClaimed {
                    OutlinedText(text: "✓", size: 22, color: BUI.green).frame(width: 70)
                } else {
                    Button { game.claimDailyBonus() } label: { OutlinedText(text: tr("Забрать"), size: 13) }
                        .buttonStyle(BloomButtonStyle(color: BUI.orange, edge: BUI.orangeEdge, enabled: game.allDailiesClaimed))
                        .disabled(!game.allDailiesClaimed)
                        .frame(width: 80)
                }
            }
        }
    }
}

/// New spring: reborn world for eternal seeds, and the eternal tree to spend them on.
struct SpringView: View {
    @EnvironmentObject private var game: BloomGame
    @State private var confirm = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                PixelIcon(name: "bloom_item_seed", size: 26)
                OutlinedText(text: "\(game.seeds)", size: 20)
                OutlinedText(text: tr("семян вечности"), size: 13, color: BUI.muted)
            }
            if game.springs > 0 {
                OutlinedText(text: tr("Весна №%@", game.springs + 1), size: 12, color: BUI.gold)
            }
            Card {
                VStack(spacing: 8) {
                    OutlinedText(text: tr("Мир уснёт и проснётся заново: острова, постройки, ресурсы и уровень начнутся сначала. Росинки, покупки, альбом и Вечное древо останутся."),
                                 size: 11.5, color: BUI.cream, fixed: false, lines: 5)
                    if game.canRebirth {
                        Button {
                            if confirm { game.rebirth() } else { confirm = true }
                        } label: {
                            OutlinedText(text: confirm ? tr("Точно? Начать заново") : tr("Новая весна: +%@ семян", game.rebirthSeeds), size: 14)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(BloomButtonStyle(color: BUI.orange, edge: BUI.orangeEdge))
                    } else {
                        OutlinedText(text: tr("Открой все острова: %@/%@", game.owned.count, game.world.islands.count),
                                     size: 13, color: BUI.muted)
                    }
                }
            }
            HStack(spacing: 8) {
                OutlinedText(text: tr("Вечное древо"), size: 15, color: BUI.gold)
                Rectangle().fill(BUI.gold.opacity(0.35)).frame(height: 2)
            }
            ForEach(BloomMeta.eternals) { e in eternalRow(e) }
        }
    }

    private func eternalRow(_ e: Eternal) -> some View {
        let lv = game.eternalLevel(e.id)
        let value = e.id == "start" ? "\(Int(e.step) * max(1, lv))" : "\(Int((e.step * 100 * Double(max(1, lv))).rounded()))"
        let cost = game.eternalCost(e)
        return Card {
            HStack(spacing: 10) {
                PixelIcon(name: e.icon, size: 30)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(BUI.ink.opacity(0.4)))
                VStack(alignment: .leading, spacing: 3) {
                    OutlinedText(text: tr(e.title), size: 13.5)
                    OutlinedText(text: tr(e.text, value), size: 11, color: BUI.muted, fixed: false, lines: 2, align: .leading)
                    OutlinedText(text: "\(lv)/\(e.max)", size: 10, color: BUI.gold)
                }
                Spacer(minLength: 0)
                if lv >= e.max {
                    OutlinedText(text: "✓", size: 22, color: BUI.green).frame(width: 74)
                } else {
                    Button { game.buyEternal(e) } label: {
                        HStack(spacing: 3) {
                            PixelIcon(name: "bloom_item_seed", size: 16)
                            OutlinedText(text: "\(cost)", size: 13)
                        }
                    }
                    .buttonStyle(BloomButtonStyle(enabled: game.seeds >= cost))
                    .frame(width: 74)
                }
            }
        }
    }
}

/// This week's event: what it changes, the time left and the two reward tracks.
struct EventView: View {
    @EnvironmentObject private var game: BloomGame

    var body: some View {
        let e = game.event
        let pts = game.eventPoints
        let last = BloomEvents.steps.last ?? 1
        VStack(spacing: 10) {
            Card {
                HStack(spacing: 10) {
                    PixelIcon(name: e.icon, size: 36)
                        .frame(width: 48, height: 48)
                        .background(RoundedRectangle(cornerRadius: 10).fill(BUI.ink.opacity(0.4)))
                    VStack(alignment: .leading, spacing: 3) {
                        OutlinedText(text: tr(e.text), size: 12, fixed: false, lines: 2, align: .leading)
                        TimelineView(.periodic(from: .now, by: 30)) { _ in
                            OutlinedText(text: tr("До конца: %@", game.eventLeft), size: 11, color: BUI.gold)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    PixelIcon(name: "bloom_ui_medal", size: 18)
                    OutlinedText(text: "\(min(pts, last)) / \(last)", size: 14)
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(BUI.ink).frame(width: 300, height: 12)
                    Capsule().fill(BUI.gold).frame(width: max(12, 300 * CGFloat(min(pts, last)) / CGFloat(last)), height: 12)
                }
                OutlinedText(text: tr("Звёзды дают: добыча, крафт, сундуки и задания дня"), size: 10.5, color: BUI.muted, fixed: false, lines: 2)
            }
            HStack(spacing: 0) {
                OutlinedText(text: tr("Бесплатно"), size: 12, color: BUI.cream).frame(width: 120)
                Spacer(minLength: 0)
                OutlinedText(text: tr("Пропуск"), size: 12, color: BUI.gold).frame(width: 120)
            }
            .frame(width: 300)
            ForEach(BloomEvents.steps.indices, id: \.self) { i in row(i, pts) }
            if !game.eventPassActive {
                VStack(spacing: 6) {
                    OutlinedText(text: tr("Пропуск события открывает правую колонку, в конце Звёздный облик"),
                                 size: 11, color: BUI.cream, fixed: false, lines: 2)
                    BuyButton(product: .eventPass, wide: true)
                }
                .padding(.top, 4)
            }
        }
    }

    private func row(_ i: Int, _ pts: Int) -> some View {
        let need = BloomEvents.steps[i]
        let open = pts >= need
        return HStack(spacing: 0) {
            cell(BloomEvents.free[i], open: open, claimed: game.eventFreeClaimed(i), locked: false) { game.claimEvent(i, premium: false) }
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(open ? BUI.gold : BUI.ink).frame(width: 40, height: 40)
                    .overlay(Circle().stroke(BUI.ink, lineWidth: 2))
                OutlinedText(text: "\(need)", size: need >= 1000 ? 10 : 11)
            }
            Spacer(minLength: 0)
            cell(BloomEvents.premium[i], open: open, claimed: game.eventPremClaimed(i), locked: !game.eventPassActive) { game.claimEvent(i, premium: true) }
        }
        .frame(width: 300)
    }

    private func cell(_ r: EventReward, open: Bool, claimed: Bool, locked: Bool, _ claim: @escaping () -> Void) -> some View {
        let icon = r.skin != nil ? "bloom_hero_star_idle_0" : r.chest ? "bloom_chest_closed" : r.golden ? "bloom_item_coin" : r.gems > 0 ? "bloom_item_gem" : "bloom_item_coin"
        let label = r.skin != nil ? tr("Облик") : r.golden ? tr("Золотой час") : r.gems > 0 ? "\(r.gems)" : r.chest ? tr("Сундук") : (r.coins * game.coinUnit).short
        let ready = open && !claimed && !locked
        return Button { if ready { claim() } } label: {
            HStack(spacing: 6) {
                ZStack {
                    PixelIcon(name: icon, size: 26)
                    if claimed { OutlinedText(text: "✓", size: 18, color: BUI.green) }
                    if locked { PixelIcon(name: "bloom_ui_lock", size: 14).offset(x: 12, y: 10) }
                }
                .frame(width: 30)
                OutlinedText(text: label, size: 11, fixed: false)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(width: 120, height: 44)
            .background(RoundedRectangle(cornerRadius: 12).fill(ready ? BUI.orange.opacity(0.45) : BUI.panelHi))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ready ? BUI.gold : BUI.ink.opacity(0.6), lineWidth: 2))
            .opacity(claimed || locked ? 0.6 : 1)
        }
        .buttonStyle(.plain)
    }
}

/// Hero skins: pick one you own, or buy with dew (two taps, no popup).
struct SkinsView: View {
    @EnvironmentObject private var game: BloomGame
    @State private var armed: String?

    var body: some View {
        let cols = [GridItem(.fixed(150), spacing: 12), GridItem(.fixed(150), spacing: 12)]
        LazyVGrid(columns: cols, spacing: 12) {
            ForEach(BloomEvents.skins) { k in tile(k) }
        }
    }

    private func tile(_ k: HeroSkin) -> some View {
        let owned = game.ownsSkin(k.id)
        let on = game.skin == k.id
        let sprite = k.id == "pink" ? "bloom_hero_idle_0" : "bloom_hero_\(k.id)_idle_0"
        return VStack(spacing: 6) {
            PixelIcon(name: sprite, size: 56).frame(height: 62)
            OutlinedText(text: tr(k.title), size: 12, fixed: false)
            Group {
                if on {
                    OutlinedText(text: tr("Надет"), size: 12, color: BUI.green).frame(height: 38)
                } else if owned {
                    Button { game.pickSkin(k) } label: { OutlinedText(text: tr("Надеть"), size: 13).frame(width: 100) }
                        .buttonStyle(BloomButtonStyle())
                } else if let g = k.gems {
                    Button {
                        if armed == k.id { game.pickSkin(k); armed = nil } else { armed = k.id; Sfx.play(.select) }
                    } label: {
                        HStack(spacing: 3) {
                            if armed == k.id { OutlinedText(text: tr("Точно?"), size: 13) } else {
                                OutlinedText(text: "\(g)", size: 13); PixelIcon(name: "bloom_item_gem", size: 16)
                            }
                        }
                        .frame(width: 100)
                    }
                    .buttonStyle(BloomButtonStyle(color: game.gems >= g ? BUI.orange : BUI.panel, edge: game.gems >= g ? BUI.orangeEdge : BUI.ink))
                    .disabled(game.gems < g)
                } else {
                    OutlinedText(text: k.id == "mint" ? tr("Стартовый набор") : tr("Пропуск события"),
                                 size: 10.5, color: BUI.muted, fixed: false, lines: 2).frame(height: 38)
                }
            }
        }
        .padding(.vertical, 10)
        .frame(width: 150)
        .background(RoundedRectangle(cornerRadius: 14).fill(on ? BUI.green.opacity(0.25) : BUI.panelHi))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(on ? BUI.green : BUI.ink.opacity(0.6), lineWidth: 2))
    }
}
