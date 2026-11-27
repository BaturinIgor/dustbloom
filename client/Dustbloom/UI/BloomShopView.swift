import SwiftUI

/// The shop, drawn in the game's own style (no system sheets except Apple's payment).
/// Order follows what players buy most: hero offer, free reward, gems, spends, pass, jar.
struct ShopView: View {
    @EnvironmentObject private var game: BloomGame
    @ObservedObject private var store = BloomStore.shared

    var body: some View {
        VStack(spacing: 10) {
            balance
            if !game.isFounder { founderCard }
            adCard
            section("Росинки")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(ShopProduct.gemPacks) { gemPack($0) }
            }
            section("Потратить росинки")
            SpendRow(icon: "bloom_item_coin", title: "Золотой час сейчас", text: "Вся добыча ×2 на 3 минуты",
                     gems: BloomGame.goldenNowGems, active: nil) { game.buyGoldenNow() }
            SpendRow(icon: "bloom_ui_fert", title: "Удобрение", text: "Всё растёт вдвое быстрее, 10 минут",
                     gems: BloomBalance.shared.shop.fertilizerGems, active: game.fertUntil) { game.buyFertilizer() }
            SpendRow(icon: "bloom_item_coin", title: "Мешок монет", text: "+\(game.coinSack.short) монет",
                     gems: BloomGame.coinSackGems, active: nil) { game.buyCoinSack() }
            section("Пропуск цветения")
            passCard
            section("Банка росы")
            jarCard
            Button { Task { await store.restore() } } label: {
                OutlinedText(text: "Восстановить покупки", size: 11, color: BUI.muted)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(width: 322)
    }

    private var balance: some View {
        HStack(spacing: 6) {
            PixelIcon(name: "bloom_item_gem", size: 24)
            OutlinedText(text: "\(game.gems)", size: 18)
            OutlinedText(text: "росинок", size: 13, color: BUI.muted)
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(Capsule().fill(BUI.ink.opacity(0.8)))
    }

    private func section(_ t: String) -> some View {
        HStack {
            OutlinedText(text: t, size: 14, color: BUI.gold)
            Rectangle().fill(BUI.gold.opacity(0.35)).frame(height: 2)
        }
        .padding(.top, 4)
    }

    // MARK: founder pack: the one offer that should catch every eye

    private var founderCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(BUI.gold.opacity(0.25)).frame(width: 60, height: 60)
                    PixelIcon(name: "bloom_helper_gold_idle_0", size: 46)
                }
                VStack(alignment: .leading, spacing: 3) {
                    OutlinedText(text: "Набор основателя", size: 17, color: BUI.gold, fixed: false)
                    OutlinedText(text: "Один раз и навсегда", size: 11, color: BUI.muted)
                }
                Spacer(minLength: 0)
                ZStack {
                    Capsule().fill(BUI.red).frame(width: 58, height: 24)
                    OutlinedText(text: "×10", size: 13)
                }
                .rotationEffect(.degrees(8))
            }
            VStack(alignment: .leading, spacing: 5) {
                perk("bloom_helper_gold_idle_0", "Золотой блумлинг: бьёт вдвое сильнее, не занимает место")
                perk("bloom_ui_fert", "Острова отрастают на 30% быстрее, навсегда")
                perk("bloom_item_gem", "\(BloomBalance.shared.shop.founderGems) росинок сразу")
            }
            BuyButton(product: .founder, wide: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(LinearGradient(colors: [Color(red: 0.55, green: 0.32, blue: 0.08), Color(red: 0.36, green: 0.2, blue: 0.3)],
                                 startPoint: .top, endPoint: .bottom)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(BUI.gold, lineWidth: 3))
    }

    private func perk(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            PixelIcon(name: icon, size: 22)
            OutlinedText(text: text, size: 11.5, fixed: false, lines: 2, align: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
    }

    // MARK: free reward

    private var adCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let left = Int(game.adReadyAt.timeIntervalSince(ctx.date).rounded(.up))
            Card {
                HStack(spacing: 10) {
                    PixelIcon(name: "bloom_ui_ad", size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        OutlinedText(text: "Бесплатно", size: 14, color: BUI.green)
                        OutlinedText(text: "Золотой час 3 мин за короткое видео", size: 11, color: BUI.muted, fixed: false, lines: 2)
                    }
                    Spacer(minLength: 0)
                    if left > 0 {
                        OutlinedText(text: clock(left), size: 13, color: BUI.muted).frame(minWidth: 70)
                    } else {
                        Button {
                            RewardedAds.show { ok in if ok { game.rewardAd() } }
                        } label: {
                            OutlinedText(text: "Смотреть", size: 13).frame(minWidth: 70)
                        }
                        .buttonStyle(BloomButtonStyle(color: BUI.green, edge: BUI.greenEdge))
                        .disabled(!RewardedAds.isAvailable)
                    }
                }
            }
        }
    }

    // MARK: gems

    private func gemPack(_ p: ShopProduct) -> some View {
        VStack(spacing: 6) {
            ZStack {
                ForEach(0..<min(4, ShopProduct.gemPacks.firstIndex(of: p)! + 1), id: \.self) { i in
                    PixelIcon(name: "bloom_item_gem", size: 30)
                        .offset(x: CGFloat(i % 2 == 0 ? -i * 5 : i * 5), y: CGFloat(-i * 2))
                }
            }
            .frame(height: 38)
            OutlinedText(text: "\(p.gems)", size: 16)
            BuyButton(product: p, wide: false)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(BUI.panelHi))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.badge != nil ? BUI.gold : BUI.ink.opacity(0.6), lineWidth: 2))
        .overlay(alignment: .top) {
            if let b = p.badge {
                OutlinedText(text: b, size: 10)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(BUI.red))
                    .offset(y: -9)
            }
        }
    }

    // MARK: pass and jar

    private var passCard: some View {
        Card {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    PixelIcon(name: "bloom_ui_pass", size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        OutlinedText(text: "+25% добычи и опыта", size: 13)
                        OutlinedText(text: "28 дней, без автопродления", size: 11, color: BUI.muted, fixed: false)
                    }
                    Spacer(minLength: 0)
                }
                if let until = game.passUntil {
                    let days = max(1, Int(until.timeIntervalSinceNow / 86400) + 1)
                    OutlinedText(text: "Активен ещё \(days) дн.", size: 12, color: BUI.green)
                }
                BuyButton(product: .pass, wide: true, title: game.passActive ? "Продлить" : nil)
            }
        }
    }

    private var jarCard: some View {
        Card {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    PixelIcon(name: "bloom_ui_jar", size: 38)
                    VStack(alignment: .leading, spacing: 4) {
                        OutlinedText(text: "Копится, пока ты играешь", size: 12, fixed: false)
                        ZStack(alignment: .leading) {
                            Capsule().fill(BUI.ink).frame(height: 14)
                            Capsule().fill(Color(red: 0.28, green: 0.71, blue: 1))
                                .frame(width: max(14, 176 * CGFloat(game.jar) / CGFloat(BloomGame.jarCap)), height: 10)
                                .padding(.leading, 2)
                            OutlinedText(text: "\(game.jar) / \(BloomGame.jarCap)", size: 10)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(width: 180)
                    }
                    Spacer(minLength: 0)
                }
                if game.jar >= 60 {
                    BuyButton(product: .jar, wide: true, title: "Разбить банку: +\(game.jar)")
                } else {
                    OutlinedText(text: "Откроется от 60 росинок", size: 11, color: BUI.muted)
                }
            }
        }
    }

    private func clock(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}

/// Real-money button: price from the App Store, a spinner while paying, "Куплено" when owned.
struct BuyButton: View {
    @EnvironmentObject private var game: BloomGame
    @ObservedObject private var store = BloomStore.shared
    let product: ShopProduct
    var wide: Bool
    var title: String?

    var body: some View {
        let owned = product == .founder && game.isFounder
        Button {
            guard !owned, store.busy == nil else { return }
            Sfx.play(.select)
            Task { await store.buy(product) }
        } label: {
            Group {
                if store.busy == product {
                    ProgressView().tint(.white)
                } else if owned {
                    OutlinedText(text: "Куплено", size: 14)
                } else if let t = title {
                    OutlinedText(text: "\(t) · \(store.price(product))", size: 14)
                } else {
                    OutlinedText(text: store.price(product), size: 14)
                }
            }
            .frame(maxWidth: wide ? .infinity : 96, minHeight: 22)
        }
        .buttonStyle(BloomButtonStyle(color: owned ? BUI.panel : BUI.orange, edge: owned ? BUI.ink : BUI.orangeEdge))
        .disabled(owned)
    }
}

/// Gem spend with a two-tap confirm instead of a popup: first tap arms, second tap buys.
struct SpendRow: View {
    @EnvironmentObject private var game: BloomGame
    let icon: String
    let title: String
    let text: String
    let gems: Int
    let active: Date?
    let action: () -> Void
    @State private var armed = false

    var body: some View {
        Card {
            HStack(spacing: 10) {
                PixelIcon(name: icon, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    OutlinedText(text: title, size: 13)
                    if let a = active {
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            let s = max(0, Int(a.timeIntervalSince(ctx.date)))
                            OutlinedText(text: "Действует ещё \(s / 60):\(String(format: "%02d", s % 60))", size: 11, color: BUI.green)
                        }
                    } else {
                        OutlinedText(text: text, size: 11, color: BUI.muted, fixed: false, lines: 2)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    if armed { action(); armed = false } else { armed = true; Sfx.play(.select) }
                } label: {
                    HStack(spacing: 3) {
                        if armed {
                            OutlinedText(text: "Точно?", size: 13)
                        } else {
                            OutlinedText(text: "\(gems)", size: 14)
                            PixelIcon(name: "bloom_item_gem", size: 16)
                        }
                    }
                    .frame(minWidth: 64)
                }
                .buttonStyle(BloomButtonStyle(color: armed ? BUI.green : (game.gems >= gems ? BUI.orange : BUI.panel),
                                              edge: armed ? BUI.greenEdge : (game.gems >= gems ? BUI.orangeEdge : BUI.ink)))
                .disabled(game.gems < gems)
                .task(id: armed) {
                    guard armed else { return }
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    armed = false
                }
            }
        }
    }
}
