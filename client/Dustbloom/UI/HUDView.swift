import StoreKit
import SwiftUI
import UIKit

/// Minimal pixel HUD: profile (avatar, nickname, power) and coins on top,
/// crop picker at the bottom.
/// Rule from the concept: the farm is the main screen, not the buttons.
struct HUDView: View {
    @EnvironmentObject private var store: FarmStore
    @State private var sheet: ArmyTab?
    @State private var showSettings = false
    @State private var showProfile = false
    @State private var showQuests = false
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 8) {
                // who you are and how strong your farm is; tap for the profile
                ProfileBadge {
                    showProfile = true
                    Sfx.play(.select, volume: 0.6)
                }
                Spacer()
                PixelPanel {
                    HStack(spacing: 6) {
                        Image("ui_coin").interpolation(.none).resizable().frame(width: 28, height: 28)
                        PixelText(text: "\(store.farm.coins)", scale: 3)
                            .id(store.farm.coins)
                            .transition(.scale(scale: 1.3).combined(with: .opacity))
                    }
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: store.farm.coins)
                }
                Button {
                    showSettings = true
                    Sfx.play(.select, volume: 0.6)
                } label: {
                    Image("icon_settings").interpolation(.none).resizable()
                        .frame(width: 28, height: 28)
                        .frame(width: 44, height: 44)
                        .background(slot(false))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.ru ? "Настройки" : "Settings")
                if store.isOnline {
                    Rectangle().fill(Color.green).frame(width: 9, height: 9)
                        .overlay(Rectangle().stroke(Color(uiColor: Palette.outline), lineWidth: 3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // quest tracker on the left edge, under the profile
            HStack {
                QuestTracker {
                    showQuests = true
                    Analytics.shared.track("open_sheet", ["tab": "quests"])
                    Sfx.play(.select, volume: 0.6)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            Spacer()

            // action row: five equal 56 pt buttons, centred over the crop bar
            HStack(spacing: 12) {
                ForEach(ArmyTab.allCases) { t in
                    Button {
                        sheet = t
                        Analytics.shared.track("open_sheet", ["tab": t.rawValue])
                        Sfx.play(.select, volume: 0.6)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(t.icon).interpolation(.none).resizable()
                            .frame(width: 36, height: 36)
                            .frame(width: 56, height: 56)
                            .background(slot(false))
                            .overlay(alignment: .topTrailing) { badge(for: t) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(t.title)
                }
            }
            .padding(.bottom, 4)

            PixelPanel(padding: 12) {
                // 12 crops: scrolls sideways, locked ones show the level they open at
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(store.config.crops) { crop in
                                let locked = store.farm.level < crop.unlockLevel
                                CropButton(crop: crop, selected: store.selectedCrop == crop.id, locked: locked) {
                                    guard !locked else {
                                        Sfx.play(.error, volume: 0.6)
                                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                                        return
                                    }
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                                        store.selectedCrop = crop.id
                                    }
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    Sfx.play(.select, volume: 0.6)
                                }
                                .id(crop.id)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .frame(width: 84 * 3 + 10 * 2 + 40)
                    .onAppear { proxy.scrollTo(store.selectedCrop, anchor: .center) }
                }
            }
            .padding(.bottom, 12)
        }
        .sheet(item: $sheet) { t in ArmySheet(tab: t).environmentObject(store) }
        .sheet(isPresented: $showProfile) {
            ProfileSheet().environmentObject(store).presentationDetents([.large])
        }
        .sheet(isPresented: $showQuests) {
            QuestSheet().environmentObject(store)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet().environmentObject(store).presentationDetents([.medium, .large])
        }
        .onChange(of: store.askReview) { _, ask in
            guard ask else { return }
            store.askReview = false
            // a beat after the celebration, not on top of it
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                requestReview()
            }
        }
        .overlay {
            if let offer = store.plotOffer {
                PlotOfferCard(offer: offer)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else if let offer = store.growOffer {
                GrowOfferCard(offer: offer)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else if store.showManor {
                ManorCard()
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else if let id = store.showBuilding {
                BuildingCard(id: id)
                    .id(id)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.plotOffer)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.growOffer)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.showManor)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.showBuilding)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in store.settle() }
    }

    /// Red dot only when the player can act: crops to sell, army ready to raid.
    @ViewBuilder
    private func badge(for t: ArmyTab) -> some View {
        let show: Bool = {
            switch t {
            case .barn: return !store.farm.barn.isEmpty
            case .orders: return store.farm.orders.indices.contains { store.farm.canDeliver($0) }
            case .workshop: return false
            case .raids: return !store.farm.army.isEmpty
            case .storage: return store.config.items.chests.contains { store.farm.items[$0.id, default: 0] > 0 }
            }
        }()
        if show {
            Circle().fill(Color(red: 0.85, green: 0.2, blue: 0.3))
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color(uiColor: Palette.outline), lineWidth: 2))
                .offset(x: 3, y: -3)
        }
    }
}

/// Parchment panel drawn from the 9-slice sprite (pre-scaled x3, 12 pt corners).
struct PixelPanel<Content: View>: View {
    var image = "ui_panel"
    var padding: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, padding + 4)
            .padding(.vertical, padding)
            .background(
                Image(image)
                    .interpolation(.none)
                    .resizable(capInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12), resizingMode: .stretch)
            )
    }
}

/// Text in the game's pixel font. Supports digits, "+", "L" and "V" for now.
struct PixelText: View {
    let text: String
    var scale: CGFloat = 3
    var gold = false

    var body: some View {
        HStack(spacing: -scale) {  // 7 px glyphs share one blank column
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                if let name = PixelLabel.glyphName(ch, gold: gold) {
                    Image(name)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 7 * scale, height: 10 * scale)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(text)
    }
}

private struct CropButton: View {
    let crop: GameConfig.Crop
    let selected: Bool
    var locked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image("\(crop.id)_3")
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 48, height: 72)
                    .padding(.top, -14)  // sprite has empty space above short crops
                if locked {
                    PixelText(text: "LV\(crop.unlockLevel)", scale: 2)
                } else {
                    HStack(spacing: 4) {
                        Image("ui_coin").interpolation(.none).resizable().frame(width: 16, height: 16)
                        PixelText(text: "\(crop.seedCost)", scale: 2)
                    }
                }
            }
            .saturation(locked ? 0 : 1)
            .opacity(locked ? 0.6 : 1)
            .frame(width: 84, height: 92)
            .background(
                Image(selected ? "ui_slot_selected" : "ui_slot")
                    .interpolation(.none)
                    .resizable(capInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12), resizingMode: .stretch)
            )
            .offset(y: selected ? -4 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(crop.localizedName)
    }
}

/// "Buy this plot?" card: what you get, price, level gate, buy / close.
private struct PlotOfferCard: View {
    @EnvironmentObject private var store: FarmStore
    let offer: FarmStore.PlotOffer
    @State private var error: FarmError?

    private var ink: Color { Color(uiColor: Palette.ink) }
    private var bad: Color { Color(red: 0.75, green: 0.18, blue: 0.25) }

    var body: some View {
        let cfg = store.config
        let price = store.farm.plotPrice(config: cfg)
        let sale = store.farm.canBuyPlot(px: offer.px, py: offer.py, config: cfg)
        let levelOK = store.farm.level >= price.level
        let coinsOK = store.farm.coins >= price.coins
        let ru = L.ru
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { store.plotOffer = nil }
            VStack(spacing: 12) {
                Text(ru ? "Участок земли" : "Land plot")
                    .font(.system(size: 20, weight: .heavy, design: .rounded)).foregroundStyle(ink)
                Text(sale == .notAdjacent
                     ? (ru ? "Сначала купи соседний участок." : "Buy a neighbouring plot first.")
                     : (ru ? "\(cfg.farm.plotSize)×\(cfg.farm.plotSize) клеток под грядки. Каждый следующий участок дороже."
                           : "\(cfg.farm.plotSize)×\(cfg.farm.plotSize) tiles for beds. Each next plot costs more."))
                    .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(ink)
                    .multilineTextAlignment(.center)
                if sale == nil {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image("ui_coin").interpolation(.none).resizable().frame(width: 24, height: 24)
                            Text("\(price.coins)").font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(coinsOK ? ink : bad)
                        }
                        Text((ru ? "Уровень " : "Level ") + "\(price.level)")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(levelOK ? ink : bad)
                    }
                    let owned = store.farm.plots.filter { $0 }.count
                    Text(ru ? "Твоя земля: \(owned) из \(store.farm.plots.count) участков" : "Your land: \(owned) of \(store.farm.plots.count) plots")
                        .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(ink.opacity(0.7))
                }
                HStack(spacing: 12) {
                    Button { store.plotOffer = nil } label: {
                        Text(ru ? "Закрыть" : "Close").font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(ink).frame(width: 120, height: 48).background(slot(false))
                    }
                    if sale == nil {
                        Button {
                            if let e = store.buyPlot(px: offer.px, py: offer.py) {
                                error = e
                                Sfx.play(.error)
                                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            } else {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                store.plotOffer = nil
                            }
                        } label: {
                            Text(ru ? "Купить" : "Buy").font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(ink).frame(width: 120, height: 48).background(slot(true))
                        }
                        .disabled(!levelOK || !coinsOK)
                        .opacity(levelOK && coinsOK ? 1 : 0.5)
                    }
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
}
