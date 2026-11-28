import SpriteKit
import StoreKit
import SwiftUI

/// Bloom screen: the island scene with the HUD and in-game panels on top.
/// All dialogs are drawn by the game (no system popups).
struct BloomView: View {
    @StateObject private var game = BloomGame()
    @State private var scene: BloomScene = {
        let s = BloomScene(size: CGSize(width: 393, height: 852))
        s.scaleMode = .resizeFill
        return s
    }()
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            // equatable: game changes redraw the HUD only, never reconfigure the SpriteKit view
            BloomSceneHost(scene: scene).equatable()
                .ignoresSafeArea()
            // soft vignette pulls the eye to the hero
            RadialGradient(colors: [.clear, .clear, Color(red: 0.05, green: 0.12, blue: 0.25).opacity(0.28)],
                           center: .center, startRadius: 120, endRadius: 520)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            BloomHUD()
        }
        .environmentObject(game)
        .onAppear {
            scene.game = game
            BloomStore.shared.start(game: game)
            game.refreshDailies()
            game.refreshEvent(); game.refreshFair()
            BloomGameCenter.shared.start(game)
            BloomGameCenter.shared.onSignedOut = { [weak g = game] in
                g?.showToast(BloomToast(title: tr("Game Center"), subtitle: tr("Войди в Game Center в настройках iPhone")))
            }
            game.onRebirth = { NotificationCenter.default.post(name: .bloomRebirth, object: nil) }
            game.onAskReview = {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    if let ws = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        Analytics.shared.track("review_prompt")
                        AppStore.requestReview(in: ws)
                    }
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-bloomTour") { tour() }
            // consent form and tracking prompt once the farm is on screen, then the first video loads
            RewardedAds.start()
            #if DEBUG
            // App Store screenshots: -bloomPanel build|talents|shop|album opens one panel
            if let name = UserDefaults.standard.string(forKey: "bloomPanel") {
                let p: BloomPanel? = ["build": .build, "talents": .talents, "shop": .shop, "album": .album,
                                      "daily": .daily, "spring": .spring, "event": .event, "skins": .skins, "feedback": .feedback, "menu": .menu, "bag": .inventory, "anvil": .building(.anvil)][name]
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { game.panel = p }
            }
            #endif
        }
        .onChange(of: phase) { _, p in
            if p != .active { game.save() } else { game.refreshDailies(); game.refreshEvent(); game.refreshFair() }
        }
    }
}

/// The SpriteKit view on its own, so SwiftUI leaves it alone when the game state changes.
private struct BloomSceneHost: View, Equatable {
    let scene: BloomScene
    static func == (a: Self, b: Self) -> Bool { a.scene === b.scene }
    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 60,
                   debugOptions: ProcessInfo.processInfo.arguments.contains("-showFPS") ? [.showsFPS, .showsNodeCount, .showsDrawCount] : [])
    }
}

extension Notification.Name {
    /// A new spring: the whole Bloom view (scene + game) is rebuilt from the fresh save.
    static let bloomRebirth = Notification.Name("bloomRebirth")
}

extension BloomView {
    /// Video tour for previews: opens the main screens one by one.
    func tour() {
        let steps: [(Double, BloomPanel?)] = [(14, .shop), (22, nil), (26, .talents), (32, nil), (36, .album), (41, nil),
                                              (45, .building(.market)), (49, nil)]
        for (t, p) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { game.panel = p }
        }
    }
}

enum BUI {
    static let ink = Color(red: 0.17, green: 0.14, blue: 0.25)
    static let panel = Color(red: 0.23, green: 0.19, blue: 0.35)
    static let panelHi = Color(red: 0.30, green: 0.25, blue: 0.44)
    static let gold = Color(red: 1, green: 0.82, blue: 0.25)
    static let green = Color(red: 0.49, green: 0.80, blue: 0.29)
    static let greenEdge = Color(red: 0.18, green: 0.43, blue: 0.23)
    static let orange = Color(red: 1, green: 0.67, blue: 0.24)
    static let orangeEdge = Color(red: 0.70, green: 0.37, blue: 0.12)
    static let red = Color(red: 1, green: 0.45, blue: 0.45)
    static let cream = Color(red: 1, green: 0.97, blue: 0.9)
    static let muted = Color(red: 0.78, green: 0.74, blue: 0.86)
}

struct PixelIcon: View {
    let name: String
    var size: CGFloat = 24
    var body: some View {
        Image(name).interpolation(.none).resizable().scaledToFit().frame(width: size, height: size)
    }
}

/// Chunky game button with a darker bottom edge.
struct BloomButtonStyle: ButtonStyle {
    var color = BUI.green
    var edge = BUI.greenEdge
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        configuration.label
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(enabled ? edge : Color.gray.opacity(0.5)).offset(y: down ? 1 : 4)
                    RoundedRectangle(cornerRadius: 12).fill(enabled ? color : Color.gray).offset(y: down ? 1 : 0)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(BUI.ink, lineWidth: 2.5).offset(y: down ? 1 : 0))
            .offset(y: down ? 1 : 0)
            .animation(.easeOut(duration: 0.06), value: down)
    }
}

struct BloomHUD: View {
    @EnvironmentObject private var game: BloomGame

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                HStack(alignment: .top) {
                    GoalCard()
                    Spacer()
                    // one column: what you come back for; the rest lives in the menu
                    VStack(spacing: 10) {
                        RoundIconButton(icon: "bloom_ui_menu", badge: 0, dot: game.canRebirth) { game.panel = .menu }
                        RoundIconButton(icon: "bloom_ui_calendar", badge: game.dailyReadyCount) { game.panel = .daily }
                        RoundIconButton(icon: "bloom_ui_event", badge: game.eventReadyCount) { game.panel = .event }
                        RoundIconButton(icon: "bloom_ui_tree", badge: game.talentPoints) { game.panel = .talents }
                        ShopButton()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                GoldenBanner()
                Spacer()
                if let t = game.tutorialStep, game.panel == nil { TutorialBubble(step: t) }
                // two round buttons of the same size in the corners; the world stays clear between them
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let n = game.nearby { contextButton(n) }
                        if !game.inDungeon { buildButton }
                    }
                    Spacer()
                    bagButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: game.toast)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: game.nearby)

            if game.panel == .talents {
                TalentTreeView()
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
            } else if let p = game.panel {
                Color.black.opacity(0.45).ignoresSafeArea()
                    .onTapGesture { game.panel = nil }
                    .transition(.opacity)
                PanelHost(panel: p)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
            // toasts sit above panels so they never look dimmed
            VStack {
                if let t = game.toast {
                    ToastView(toast: t)
                        .padding(.top, 142) // below the goal card, so "goal done" doesn't hide the next goal
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .id(t.id)
                        .task(id: t.id) {
                            try? await Task.sleep(nanoseconds: 2_300_000_000)
                            if game.toast?.id == t.id { game.nextToast() }
                        }
                }
                Spacer()
            }
            .allowsHitTesting(false)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: game.toast)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: game.panel)
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
            // level + xp
            ZStack(alignment: .leading) {
                Capsule().fill(BUI.ink.opacity(0.85)).frame(width: 170, height: 30).padding(.leading, 22)
                Capsule().fill(BUI.green)
                    .frame(width: max(14, 156 * CGFloat(game.xp) / CGFloat(max(1, game.xpNeed))), height: 20)
                    .padding(.leading, 30)
                OutlinedText(text: "\(game.xp) / \(game.xpNeed)", size: 12)
                    .frame(width: 150).padding(.leading, 38)
                ZStack {
                    Circle().fill(BUI.ink).frame(width: 46, height: 46)
                    Circle().fill(BUI.gold).frame(width: 38, height: 38)
                    Text("\(game.level)").font(DText.font(19)).foregroundStyle(BUI.ink)
                }
            }
            // hearts, once dust creatures roam (level 5)
            if game.foesOn {
                HStack(spacing: 3) {
                    ForEach(0..<(game.maxHP / 2), id: \.self) { i in
                        let left = game.hp - i * 2
                        PixelIcon(name: left >= 2 ? "bloom_ui_heart_full" : (left == 1 ? "bloom_ui_heart_half" : "bloom_ui_heart_empty"), size: 20)
                    }
                }
                .padding(.leading, 50)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: game.hp)
            }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    PixelIcon(name: "bloom_item_coin", size: 26)
                    OutlinedText(text: game.coins.short, size: 18)
                        .frame(minWidth: 64, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .frame(width: 124, height: 36)
                .background(Capsule().fill(BUI.ink.opacity(0.85)))
                // gems: tapping the counter is the most common way into a shop
                Button { game.panel = .shop; Sfx.play(.select) } label: {
                    HStack(spacing: 6) {
                        PixelIcon(name: "bloom_item_gem", size: 22)
                        OutlinedText(text: "\(game.gems)", size: 15)
                            .frame(minWidth: 40, alignment: .trailing)
                        ZStack {
                            Circle().fill(BUI.green).frame(width: 20, height: 20)
                            Text("+").font(DText.font(15)).foregroundStyle(.white)
                        }
                    }
                    .padding(.leading, 12).padding(.trailing, 6)
                    .frame(width: 124, height: 30)
                    .background(Capsule().fill(BUI.ink.opacity(0.85)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var buildButton: some View {
        Button {
            game.panel = .build
            Sfx.play(.select)
        } label: {
            ZStack {
                Circle().fill(BUI.ink).frame(width: 78, height: 78)
                Circle().fill(BUI.orange).frame(width: 68, height: 68)
                Circle().fill(Color.white.opacity(0.25)).frame(width: 52, height: 28).offset(y: -16)
                OutlinedText(text: tr("Строить"), size: 12.5)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func contextButton(_ n: BloomGame.Nearby) -> some View {
        switch n {
        case .building(let k):
            Button { game.panel = .building(k); Sfx.play(.select) } label: {
                HStack(spacing: 6) {
                    PixelIcon(name: k.sprite, size: 26)
                    OutlinedText(text: k.title, size: 14)
                }
            }
            .buttonStyle(BloomButtonStyle(color: BUI.panelHi, edge: BUI.ink))
        case .dungeon(let id):
            Button { game.panel = .dungeon(id); Sfx.play(.select) } label: {
                HStack(spacing: 6) {
                    PixelIcon(name: "bloom_cave", size: 28)
                    OutlinedText(text: tr(BloomDungeons.byId(id)?.title ?? ""), size: 14)
                }
            }
            .buttonStyle(BloomButtonStyle(color: BUI.panelHi, edge: BUI.ink))
        case .island(let id):
            let isl = game.island(id)
            Button { game.panel = .buy(id); Sfx.play(.select) } label: {
                HStack(spacing: 6) {
                    OutlinedText(text: tr("Остров"), size: 14)
                    PixelIcon(name: "bloom_item_coin", size: 20)
                    OutlinedText(text: "\(game.islandPrice(id))", size: 14, color: game.coins >= game.islandPrice(id) ? BUI.cream : BUI.red)
                }
            }
            .buttonStyle(BloomButtonStyle(color: BUI.green, edge: BUI.greenEdge))
        }
    }

    /// The backpack: resources live here instead of a bar across the screen.
    private var bagButton: some View {
        Button {
            game.panel = .inventory
            Sfx.play(.select)
        } label: {
            ZStack {
                Circle().fill(BUI.ink).frame(width: 78, height: 78)
                Circle().fill(BUI.panelHi).frame(width: 68, height: 68)
                Circle().fill(Color.white.opacity(0.18)).frame(width: 52, height: 28).offset(y: -16)
                PixelIcon(name: "bloom_ui_bag", size: 44)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ToastView: View {
    let toast: BloomToast
    var body: some View {
        VStack(spacing: 2) {
            OutlinedText(text: toast.title, size: 20, color: BUI.gold)
            OutlinedText(text: toast.subtitle, size: 13)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(BUI.ink.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(BUI.gold, lineWidth: 2))
    }
}

// MARK: - panels

struct PanelHost: View {
    @EnvironmentObject private var game: BloomGame
    let panel: BloomPanel

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                OutlinedText(text: title, size: 20, color: BUI.gold)
                HStack {
                    Spacer()
                    Button { game.panel = nil } label: {
                        ZStack {
                            Circle().fill(BUI.ink).frame(width: 34, height: 34)
                            Text("✕").font(DText.font(15)).foregroundStyle(BUI.cream)
                        }
                        .frame(width: 44, height: 44)   // Apple's minimum touch target
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            ScrollView(showsIndicators: false) {
                // explicit width: without it long translated lines made rows wider than the panel
                VStack(spacing: 10) { content }
                    .frame(width: 350 - 28)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
            }
            .frame(maxHeight: panel == .shop ? 520 : 470)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 350)
        .background(RoundedRectangle(cornerRadius: 22).fill(BUI.panel))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(BUI.ink, lineWidth: 4))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }

    private var title: String {
        switch panel {
        case .build: return tr("Постройки")
        case .building(let k): return k.title
        case .buy(let id): return tr(game.island(id).name)
        case .inventory: return tr("Рюкзак")
        case .talents: return tr("Древо цветения")
        case .album: return tr("Альбом находок")
        case .shop: return tr("Лавка")
        case .feedback: return tr("Написать нам")
        case .daily: return tr("Календарь")
        case .spring: return tr("Новая весна")
        case .event: return tr(game.event.title)
        case .skins: return tr("Облик героя")
        case .menu: return tr("Меню")
        case .dungeon(let id): return tr(BloomDungeons.byId(id)?.title ?? "")
        }
    }

    @ViewBuilder private var content: some View {
        switch panel {
        case .build: BuildList()
        case .building(.market): MarketList()
        case .building(.anvil): AnvilView()
        case .building(.nursery): NurseryView()
        case .building(let k): CraftList(kind: k)
        case .buy(let id): BuyView(id: id)
        case .inventory: InventoryGrid()
        case .talents: EmptyView()
        case .album: AlbumView()
        case .shop: ShopView()
        case .feedback: FeedbackView()
        case .daily: DailyView()
        case .spring: SpringView()
        case .event: EventView()
        case .skins: SkinsView()
        case .menu: MenuView()
        case .dungeon(let id): DungeonView(id: id)
        }
    }
}

struct Card<C: View>: View {
    @ViewBuilder let content: C
    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(BUI.panelHi))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(BUI.ink.opacity(0.6), lineWidth: 2))
    }
}

struct CostRow: View {
    @EnvironmentObject private var game: BloomGame
    let cost: Cost
    var times = 1
    var body: some View {
        // two per line: three costs in one line made cards wider than the panel
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(stride(from: 0, to: cost.count, by: 2)), id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row..<min(row + 2, cost.count), id: \.self) { i in
                        let (item, n) = cost[i]
                        HStack(spacing: 2) {
                            PixelIcon(name: item.sprite, size: 18)
                            OutlinedText(text: "\(game.count(item))/\(n * times)", size: 11,
                                         color: game.count(item) >= n * times ? BUI.cream : BUI.red)
                        }
                    }
                }
            }
        }
    }
}

struct BuildList: View {
    @EnvironmentObject private var game: BloomGame
    var body: some View {
        ForEach(BuildKind.allCases) { k in
            Card {
                HStack(spacing: 10) {
                    PixelIcon(name: k.sprite, size: 46)
                        .frame(width: 54, height: 54)
                        .background(RoundedRectangle(cornerRadius: 10).fill(BUI.ink.opacity(0.4)))
                    VStack(alignment: .leading, spacing: 4) {
                        OutlinedText(text: k.title, size: 15, fixed: false, align: .leading)
                        Text(k.blurb).font(DText.font(10.5)).foregroundStyle(BUI.cream.opacity(0.75))
                            .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                        CostRow(cost: game.cost(k))
                    }
                    Spacer(minLength: 0)
                    if game.isBuilt(k) {
                        OutlinedText(text: "✓", size: 22, color: BUI.green).frame(width: 74)
                    } else if game.level < k.unlockLevel {
                        VStack(spacing: 0) {
                            OutlinedText(text: "🔒", size: 16)
                            OutlinedText(text: tr("Ур. %@", k.unlockLevel), size: 11)
                        }
                        .frame(width: 74)
                    } else {
                        Button { game.build(k) } label: { OutlinedText(text: tr("Строить"), size: 12.5) }
                            .buttonStyle(BloomButtonStyle(enabled: game.canBuild(k)))
                            .frame(width: 84)
                    }
                }
            }
        }
    }
}

struct CraftList: View {
    @EnvironmentObject private var game: BloomGame
    let kind: BuildKind
    var body: some View {
        if let q = game.queue(for: kind), q.left > 0,
           let r = kind.recipes.first(where: { $0.id == q.recipe }) {
            Card {
                HStack(spacing: 10) {
                    PixelIcon(name: r.output.sprite, size: 34)
                    VStack(alignment: .leading, spacing: 5) {
                        OutlinedText(text: tr("В работе: %@", q.left), size: 13)
                        TimelineView(.animation) { _ in
                            let p = min(1, (game.progress[kind.rawValue] ?? 0) / game.secs(r))
                            ZStack(alignment: .leading) {
                                Capsule().fill(BUI.ink).frame(height: 12)
                                Capsule().fill(BUI.gold).frame(width: max(12, 200 * p), height: 12)
                            }
                            .frame(width: 204, alignment: .leading)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        ForEach(kind.recipes) { r in
            Card {
                HStack(spacing: 10) {
                    PixelIcon(name: r.output.sprite, size: 38)
                        .frame(width: 50, height: 50)
                        .background(RoundedRectangle(cornerRadius: 10).fill(BUI.ink.opacity(0.4)))
                    VStack(alignment: .leading, spacing: 4) {
                        OutlinedText(text: r.output.title, size: 14)
                        CostRow(cost: r.cost)
                        Text(String(format: tr("%.0f с за штуку"), game.secs(r).rounded(.up)))
                            .font(DText.font(10)).foregroundStyle(BUI.cream.opacity(0.7))
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 8) {
                        Button { game.craft(kind, r, times: 1) } label: { OutlinedText(text: "×1", size: 13) }
                            .buttonStyle(BloomButtonStyle(enabled: game.maxCraft(r) >= 1))
                        Button { game.craft(kind, r, times: 5) } label: { OutlinedText(text: "×5", size: 13) }
                            .buttonStyle(BloomButtonStyle(color: BUI.orange, edge: BUI.orangeEdge, enabled: game.maxCraft(r) >= 1))
                    }
                    .frame(width: 58)
                }
            }
        }
    }
}

struct MarketList: View {
    @EnvironmentObject private var game: BloomGame
    var body: some View {
        let items = BItem.allCases.filter { game.count($0) > 0 }
        if items.isEmpty {
            OutlinedText(text: tr("Пока нечего продать"), size: 14).padding(20)
        }
        ForEach(items) { i in
            Card {
                HStack(spacing: 10) {
                    PixelIcon(name: i.sprite, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        OutlinedText(text: i.title, size: 13)
                        OutlinedText(text: tr("%@ шт", game.count(i)), size: 11, color: BUI.muted)
                    }
                    Spacer(minLength: 0)
                    let value = game.sellValue(i, game.count(i))
                    Button { game.sell(i, all: true) } label: {
                        HStack(spacing: 4) {
                            OutlinedText(text: value > 0 ? "+\(value)" : tr("мало"), size: 13)
                            if value > 0 { PixelIcon(name: "bloom_item_coin", size: 16) }
                        }
                        .frame(minWidth: 64)
                    }
                    .buttonStyle(BloomButtonStyle(color: value > 0 ? BUI.orange : BUI.panel, edge: value > 0 ? BUI.orangeEdge : BUI.ink))
                    .disabled(value == 0)
                }
            }
        }
    }
}

struct AnvilView: View {
    @EnvironmentObject private var game: BloomGame
    var body: some View {
        Card {
            HStack(spacing: 12) {
                PixelIcon(name: "bloom_pick_\(game.pickTier)", size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    OutlinedText(text: BloomContent.picks[game.pickTier].title + (game.pickLucky ? " ★" : ""), size: 14,
                                 color: game.pickLucky ? BUI.gold : BUI.cream)
                    OutlinedText(text: tr("Удар: %@", game.damage), size: 12)
                }
                Spacer(minLength: 0)
            }
        }
        if let next = game.nextPick {
            Card {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        PixelIcon(name: "bloom_pick_\(game.pickTier + 1)", size: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            OutlinedText(text: next.title, size: 14)
                            OutlinedText(text: tr("Удар: %@", next.damage), size: 12)
                            CostRow(cost: next.cost)
                        }
                        Spacer(minLength: 0)
                    }
                    Text(tr("Шанс %@% на удачную ковку: +1 к удару", Int(BloomContent.luckyChance * 100)))
                        .font(DText.font(10.5)).foregroundStyle(BUI.gold.opacity(0.9))
                    Button { game.forgePick() } label: { OutlinedText(text: tr("Выковать"), size: 15).frame(maxWidth: .infinity) }
                        .buttonStyle(BloomButtonStyle(color: BUI.orange, edge: BUI.orangeEdge, enabled: game.has(next.cost)))
                }
            }
        } else {
            OutlinedText(text: tr("Лучшая кирка уже у тебя"), size: 14).padding(12)
        }
        // axe: its own line of upgrades, only for trees
        Card {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    PixelIcon(name: "bloom_axe_\(max(1, game.nextAxe == nil ? game.axeTier : game.axeTier + 1))", size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        OutlinedText(text: game.nextAxe?.title ?? BloomGame.axeTitles[game.axeTier], size: 14)
                        OutlinedText(text: tr("Деревья: +%@ к удару", game.nextAxe?.bonus ?? game.axeBonus), size: 12)
                        if let a = game.nextAxe { CostRow(cost: a.cost) }
                    }
                    Spacer(minLength: 0)
                }
                if game.nextAxe != nil {
                    Button { game.forgeAxe() } label: { OutlinedText(text: tr("Выковать"), size: 15).frame(maxWidth: .infinity) }
                        .buttonStyle(BloomButtonStyle(color: BUI.orange, edge: BUI.orangeEdge, enabled: game.has(game.nextAxe!.cost)))
                }
            }
        }
        // shovel: one purchase, opens dig spots
        Card {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    PixelIcon(name: "bloom_shovel", size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        OutlinedText(text: tr("Лопата"), size: 14)
                        OutlinedText(text: tr("Копай бугорки с крестиком: монеты, ресурсы, иногда кристалл"), size: 11, color: BUI.muted, fixed: false, lines: 2, align: .leading)
                        if !game.hasShovel { CostRow(cost: BloomBalance.shared.shovelCost) }
                    }
                    Spacer(minLength: 0)
                }
                if game.hasShovel {
                    OutlinedText(text: tr("Уже у тебя"), size: 13, color: BUI.green)
                } else {
                    Button { game.forgeShovel() } label: { OutlinedText(text: tr("Выковать"), size: 15).frame(maxWidth: .infinity) }
                        .buttonStyle(BloomButtonStyle(color: BUI.orange, edge: BUI.orangeEdge, enabled: game.has(BloomBalance.shared.shovelCost)))
                }
            }
        }
    }
}

struct BuyView: View {
    @EnvironmentObject private var game: BloomGame
    let id: Int
    var body: some View {
        let isl = game.island(id)
        Card {
            VStack(spacing: 10) {
                OutlinedText(text: tr("Здесь растёт:"), size: 13)
                HStack(spacing: 10) {
                    ForEach(isl.spawn.keys.sorted(), id: \.self) { k in
                        PixelIcon(name: "bloom_" + k, size: 34)
                    }
                }
                Text(tr("Купи остров, и пыль сменится цветами"))
                    .font(DText.font(11)).foregroundStyle(BUI.cream.opacity(0.75))
            }
        }
        Button { game.buy(id) } label: {
            HStack(spacing: 6) {
                OutlinedText(text: tr("Купить за"), size: 16)
                PixelIcon(name: "bloom_item_coin", size: 22)
                OutlinedText(text: game.islandPrice(id).short, size: 16)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BloomButtonStyle(enabled: game.coins >= game.islandPrice(id)))
        if game.coins < game.islandPrice(id) {
            OutlinedText(text: tr("Не хватает %@. Продай ресурсы на рынке", (game.islandPrice(id) - game.coins).short), size: 11, color: BUI.red, fixed: false, lines: 2)
        }
    }
}

struct InventoryGrid: View {
    @EnvironmentObject private var game: BloomGame
    var body: some View {
        let cols = Array(repeating: GridItem(.fixed(70), spacing: 8), count: 4)
        // only what the player has: twenty greyed "0" tiles were noise
        let have = BItem.allCases.filter { game.count($0) > 0 }
        if have.isEmpty {
            OutlinedText(text: tr("Рюкзак пуст"), size: 14, color: BUI.muted).padding(.vertical, 24)
        }
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(have) { i in
                VStack(spacing: 2) {
                    PixelIcon(name: i.sprite, size: 32)
                    OutlinedText(text: "\(game.count(i))", size: 12)
                }
                .frame(width: 70, height: 64)
                .background(RoundedRectangle(cornerRadius: 12).fill(BUI.panelHi))
            }
        }
    }
}


/// Current goal under the level bar. Glows and pulses when it can be claimed.
struct GoalCard: View {
    @EnvironmentObject private var game: BloomGame
    @State private var pulse = false

    var body: some View {
        if let g = game.goal {
            let done = game.goalDone
            Button {
                if done { game.claimGoal() }
            } label: {
                HStack(spacing: 8) {
                    PixelIcon(name: g.icon, size: 26)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 8).fill(BUI.ink.opacity(0.5)))
                    VStack(alignment: .leading, spacing: 3) {
                        OutlinedText(text: g.title, size: 12)
                        if done {
                            OutlinedText(text: tr("Забрать награду!"), size: 11, color: BUI.gold)
                        } else {
                            ZStack(alignment: .leading) {
                                Capsule().fill(BUI.ink).frame(width: 110, height: 9)
                                Capsule().fill(BUI.gold)
                                    .frame(width: max(9, 110 * CGFloat(game.goalProgress) / CGFloat(max(1, g.target))), height: 9)
                                OutlinedText(text: "\(game.goalProgress)/\(g.target)", size: 8).frame(width: 110)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 12).fill(done ? BUI.greenEdge.opacity(0.95) : BUI.ink.opacity(0.8)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(done ? BUI.gold : Color.clear, lineWidth: 2))
                .scaleEffect(done && pulse ? 1.06 : 1)
            }
            .buttonStyle(.plain)
            .onAppear { withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true } }
        }
    }
}

struct NurseryView: View {
    @EnvironmentObject private var game: BloomGame
    var body: some View {
        Card {
            VStack(spacing: 8) {
                OutlinedText(text: tr("Твои помощники: %@/%@", game.helpers.count, game.maxHelpers), size: 13)
                HStack(spacing: 14) {
                    ForEach(0..<game.maxHelpers, id: \.self) { i in
                        if i < game.helpers.count {
                            VStack(spacing: 2) {
                                PixelIcon(name: "bloom_helper_\(game.helpers[i])_idle_0", size: 44)
                                OutlinedText(text: BloomContent.helperNames[game.helpers[i]] ?? "", size: 10)
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 10).fill(BUI.ink.opacity(0.4))
                                .frame(width: 52, height: 60)
                                .overlay(OutlinedText(text: "?", size: 20, color: BUI.cream.opacity(0.5)))
                        }
                    }
                }
                Text(tr("Блумлинги сами бегут к ближайшему дереву или камню и добывают для тебя"))
                    .font(DText.font(10.5)).foregroundStyle(BUI.cream.opacity(0.75)).multilineTextAlignment(.center)
            }
        }
        if game.helpers.count < game.maxHelpers {
            Card {
                VStack(spacing: 8) {
                    CostRow(cost: game.helperCost)
                    Button { game.growHelper() } label: {
                        OutlinedText(text: tr("Вырастить блумлинга"), size: 15).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BloomButtonStyle(enabled: game.canGrowHelper))
                }
            }
        }
    }
}


struct RoundIconButton: View {
    let icon: String
    var badge: Int
    var dot = false
    let action: () -> Void
    var body: some View {
        Button {
            Sfx.play(.select)
            action()
        } label: {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle().fill(BUI.ink.opacity(0.88)).frame(width: 50, height: 50)
                    Circle().stroke(BUI.gold.opacity(badge > 0 ? 1 : 0.35), lineWidth: 2).frame(width: 46, height: 46)
                    PixelIcon(name: icon, size: 32)
                }
                if badge > 0 {
                    ZStack {
                        Circle().fill(BUI.red).frame(width: 22, height: 22)
                        Text("\(badge)").font(DText.font(12)).foregroundStyle(.white)
                    }
                    .offset(x: 4, y: -4)
                } else if dot {
                    Circle().fill(BUI.green).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(BUI.ink, lineWidth: 2))
                        .offset(x: 1, y: -1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// One tutorial hint above the hotbar, with a quiet "skip".
struct TutorialBubble: View {
    @EnvironmentObject private var game: BloomGame
    let step: BloomTutorial.Step
    var body: some View {
        HStack(spacing: 10) {
            PixelIcon(name: step.icon, size: 30)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(BUI.ink.opacity(0.4)))
            VStack(alignment: .leading, spacing: 2) {
                OutlinedText(text: tr(step.text), size: 12.5, fixed: false, lines: 2, align: .leading)
                OutlinedText(text: "\(game.tutorialIndex + 1)/\(BloomTutorial.steps.count)", size: 10, color: BUI.gold)
            }
            Spacer(minLength: 0)
            Button { game.skipTutorial() } label: {
                OutlinedText(text: tr("Пропустить"), size: 10, color: BUI.muted).frame(height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 350)
        .background(RoundedRectangle(cornerRadius: 16).fill(BUI.panel.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(BUI.gold, lineWidth: 2.5))
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .id(game.tutorialIndex)
    }
}

/// Shop entry with a green dot when the free reward is ready.
struct ShopButton: View {
    @EnvironmentObject private var game: BloomGame
    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { ctx in
            RoundIconButton(icon: "bloom_ui_shop", badge: 0, dot: game.adReadyAt <= ctx.date && RewardedAds.isAvailable) {
                game.panel = .shop
            }
        }
    }
}

struct GoldenBanner: View {
    @EnvironmentObject private var game: BloomGame
    var body: some View {
        if let until = game.goldenUntil {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let left = max(0, Int(until.timeIntervalSince(ctx.date).rounded(.up)))
                HStack(spacing: 8) {
                    PixelIcon(name: "bloom_item_coin", size: 22)
                    OutlinedText(text: tr("ЗОЛОТОЙ ЧАС  ×2"), size: 16, color: BUI.gold)
                    OutlinedText(text: "\(left / 60):\(String(format: "%02d", left % 60))", size: 14)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(red: 0.45, green: 0.25, blue: 0.05).opacity(0.9)))
                .overlay(Capsule().stroke(BUI.gold, lineWidth: 2))
            }
            .padding(.top, 8)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - talent tree

struct TalentTreeView: View {
    @EnvironmentObject private var game: BloomGame
    @State private var selected: String?
    @State private var glow = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.08, blue: 0.22), Color(red: 0.12, green: 0.20, blue: 0.20),
                                    Color(red: 0.10, green: 0.25, blue: 0.14)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            // stars
            Canvas { ctx, size in
                var rng = SystemRandomNumberGenerator()
                for i in 0..<60 {
                    let x = CGFloat((i * 73) % 997) / 997 * size.width
                    let y = CGFloat((i * 151) % 991) / 991 * size.height * 0.6
                    let r: CGFloat = i % 7 == 0 ? 1.6 : 0.9
                    _ = rng.next()
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.5)))
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            GeometryReader { screen in
            VStack(spacing: 0) {
                header
                GeometryReader { geo in
                    let lay = Layout(size: geo.size)
                    ZStack {
                        Canvas { ctx, _ in drawTree(ctx, lay) }
                        ForEach(0..<5, id: \.self) { b in
                            // a column wide minus a gap, so the outer titles keep the same margin as the nodes
                            OutlinedText(text: BloomTalents.branches[b].title, size: 11, color: BloomTalents.branches[b].color, fixed: false)
                                .frame(width: lay.size.width * 0.2 - 12)
                                .position(x: lay.x(b), y: lay.y(4) - 44)
                        }
                        ForEach(BloomTalents.all) { t in
                            node(t).position(x: lay.x(t.branch), y: lay.y(t.tier))
                        }
                    }
                }
                detail
            }
            .frame(width: screen.size.width, height: screen.size.height)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { glow = true } }
    }

    struct Layout {
        let size: CGSize
        func x(_ b: Int) -> CGFloat { size.width * (0.1 + CGFloat(b) * 0.2) }
        var trunkTop: CGFloat { size.height - 36 }
        func y(_ tier: Int) -> CGFloat {
            let top: CGFloat = 70, bottom = size.height - 92
            return bottom - CGFloat(tier) * (bottom - top) / 4
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                OutlinedText(text: tr("Древо цветения"), size: 22, color: BUI.gold, fixed: false, align: .leading)
                OutlinedText(text: tr("Очко таланта за каждый уровень"), size: 11, color: BUI.cream.opacity(0.8), fixed: false, align: .leading)
            }
            Spacer()
            HStack(spacing: 6) {
                PixelIcon(name: "bloom_fx_spark", size: 16)
                OutlinedText(text: "\(game.talentPoints)", size: 20, color: game.talentPoints > 0 ? BUI.gold : BUI.cream)
            }
            .padding(.horizontal, 12).frame(height: 38)
            .background(Capsule().fill(BUI.ink.opacity(0.9)))
            Button { game.panel = nil } label: {
                ZStack {
                    Circle().fill(BUI.ink).frame(width: 38, height: 38)
                    Text("✕").font(DText.font(16)).foregroundStyle(BUI.cream)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func state(_ t: Talent) -> Int {   // 2 owned, 1 available, 0 locked
        if game.hasT(t.id) { return 2 }
        if (t.requires.map(game.hasT) ?? true) { return 1 }
        return 0
    }

    private func drawTree(_ ctx: GraphicsContext, _ lay: Layout) {
        let mid = lay.size.width / 2
        // trunk
        var trunk = Path()
        trunk.move(to: CGPoint(x: mid - 16, y: lay.size.height))
        trunk.addQuadCurve(to: CGPoint(x: mid - 6, y: lay.trunkTop - 10), control: CGPoint(x: mid - 4, y: lay.size.height - 20))
        trunk.addLine(to: CGPoint(x: mid + 6, y: lay.trunkTop - 10))
        trunk.addQuadCurve(to: CGPoint(x: mid + 16, y: lay.size.height), control: CGPoint(x: mid + 4, y: lay.size.height - 20))
        trunk.closeSubpath()
        ctx.fill(trunk, with: .color(Color(red: 0.45, green: 0.28, blue: 0.16)))
        for b in 0..<5 {
            let color = BloomTalents.branches[b].color
            let ids = BloomTalents.branches[b].ids
            // root branch from the trunk to the first node
            var root = Path()
            root.move(to: CGPoint(x: mid, y: lay.trunkTop - 6))
            root.addQuadCurve(to: CGPoint(x: lay.x(b), y: lay.y(0)), control: CGPoint(x: lay.x(b), y: lay.trunkTop - 4))
            let rootOn = game.hasT(ids[0])
            ctx.stroke(root, with: .color(Color(red: 0.45, green: 0.28, blue: 0.16)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            if rootOn { ctx.stroke(root, with: .color(color.opacity(0.9)), style: StrokeStyle(lineWidth: 3, lineCap: .round)) }
            for k in 1..<5 {
                let a = CGPoint(x: lay.x(b), y: lay.y(k - 1)), z = CGPoint(x: lay.x(b), y: lay.y(k))
                var v = Path()
                v.move(to: a)
                let wig: CGFloat = (k + b) % 2 == 0 ? 14 : -14
                v.addQuadCurve(to: z, control: CGPoint(x: a.x + wig, y: (a.y + z.y) / 2))
                let on = game.hasT(ids[k])
                ctx.stroke(v, with: .color(on ? color : Color(red: 0.25, green: 0.4, blue: 0.3).opacity(0.7)),
                           style: StrokeStyle(lineWidth: on ? 5 : 4, lineCap: .round))
                // leaves
                let lp = CGPoint(x: a.x + wig * 0.55, y: (a.y + z.y) / 2)
                let leaf = Path(ellipseIn: CGRect(x: lp.x + (wig > 0 ? 2 : -12), y: lp.y - 4, width: 10, height: 6))
                ctx.fill(leaf, with: .color(on ? Color(red: 0.5, green: 0.9, blue: 0.4) : Color(red: 0.25, green: 0.45, blue: 0.3).opacity(0.7)))
            }
        }
    }

    private func node(_ t: Talent) -> some View {
        let st = state(t)
        let color = BloomTalents.branches[t.branch].color
        let sel = selected == t.id
        return Button {
            selected = t.id
            Sfx.play(.select)
        } label: {
            ZStack {
                if st == 2 {
                    Circle().fill(color.opacity(0.45)).frame(width: 66, height: 66).blur(radius: 6)
                }
                Circle().fill(st == 2 ? color : BUI.ink).frame(width: 52, height: 52)
                Circle().stroke(st == 1 ? BUI.gold.opacity(glow ? 1 : 0.4) : (st == 2 ? Color.white.opacity(0.8) : Color.gray.opacity(0.4)),
                                lineWidth: sel ? 4 : 2.5)
                    .frame(width: 52, height: 52)
                PixelIcon(name: t.icon, size: 30)
                    .opacity(st == 0 ? 0.35 : 1)
                    .saturation(st == 0 ? 0 : 1)
                if st != 2 {
                    ZStack {
                        Circle().fill(st == 1 ? BUI.gold : Color.gray).frame(width: 20, height: 20)
                        Text("\(t.cost)").font(DText.font(11)).foregroundStyle(BUI.ink)
                    }
                    .offset(x: 19, y: 19)
                }
            }
            .scaleEffect(sel ? 1.12 : 1)
        }
        .buttonStyle(.plain)
    }

    private var detail: some View {
        let t = BloomTalents.talent(selected ?? BloomTalents.all.first(where: { state($0) == 1 && !game.hasT($0.id) })?.id ?? "d1")
        let st = state(t)
        return HStack(spacing: 12) {
            PixelIcon(name: t.icon, size: 40)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 12).fill(BloomTalents.branches[t.branch].color.opacity(0.35)))
            VStack(alignment: .leading, spacing: 3) {
                OutlinedText(text: t.title, size: 16, color: BloomTalents.branches[t.branch].color, fixed: false, align: .leading)
                OutlinedText(text: t.text, size: 12, fixed: false, lines: 2, align: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            if st == 2 {
                OutlinedText(text: tr("Изучено"), size: 13, color: BUI.green).frame(width: 96)
            } else if st == 0 {
                OutlinedText(text: tr("Сначала нижний талант"), size: 11, color: BUI.cream.opacity(0.7), fixed: false, lines: 2).frame(width: 96)
            } else {
                Button { game.learn(t) } label: {
                    VStack(spacing: 0) {
                        OutlinedText(text: tr("Изучить"), size: 14)
                        // dark on the orange button: an outline at this size smeared the digits together
                        Text(tr("%@ очк.", t.cost)).font(DText.font(11)).foregroundStyle(BUI.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .buttonStyle(BloomButtonStyle(color: BUI.orange, edge: BUI.orangeEdge, enabled: game.canLearn(t)))
                .frame(width: 96)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(BUI.panel))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(BUI.ink, lineWidth: 3))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - album

struct AlbumView: View {
    @EnvironmentObject private var game: BloomGame
    var body: some View {
        ForEach(BloomAlbum.pages.indices, id: \.self) { pi in
            let page = BloomAlbum.pages[pi]
            let done = game.pageDone(pi)
            Card {
                VStack(spacing: 8) {
                    HStack {
                        OutlinedText(text: page.title, size: 15, color: done ? BUI.gold : BUI.cream)
                        Spacer()
                        OutlinedText(text: done ? "✓ " + page.bonus : page.bonus, size: 11, color: done ? BUI.green : BUI.cream.opacity(0.7))
                    }
                    HStack(spacing: 6) {
                        ForEach(page.finds, id: \.id) { f in
                            let n = game.finds[f.id] ?? 0
                            VStack(spacing: 1) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10).fill(BUI.ink.opacity(0.55)).frame(width: 54, height: 54)
                                    if n > 0 {
                                        PixelIcon(name: "bloom_find_" + f.id, size: 36)
                                    } else {
                                        PixelIcon(name: "bloom_find_" + f.id, size: 36).colorMultiply(.black).opacity(0.45)
                                        OutlinedText(text: "?", size: 16, color: BUI.cream.opacity(0.6))
                                    }
                                }
                                OutlinedText(text: n > 0 ? "×\(n)" : " ", size: 9)
                            }
                        }
                    }
                }
            }
        }
        OutlinedText(text: tr("Находки иногда выпадают из деревьев, кустов и камней"), size: 11, color: BUI.cream.opacity(0.7), fixed: false, lines: 2)
            .padding(.top, 4)
    }
}

/// Player feedback in the game's own style: a mood, a message, and a rating button.
struct FeedbackView: View {
    @EnvironmentObject private var game: BloomGame
    @Environment(\.requestReview) private var requestReview
    @State private var text = ""
    @State private var mood = "good"
    @State private var state = 0   // 0 idle, 1 sending, 2 sent, 3 failed
    @FocusState private var typing: Bool

    private let moods = [("love", "😍"), ("good", "🙂"), ("meh", "😕")]

    var body: some View {
        VStack(spacing: 12) {
            OutlinedText(text: tr("Как тебе игра? Каждое сообщение читаем сами"), size: 13, color: BUI.muted, fixed: false, lines: 2)
            HStack(spacing: 14) {
                ForEach(moods, id: \.0) { m in
                    Button { mood = m.0; Sfx.play(.select) } label: {
                        Text(m.1).font(.system(size: 30))
                            .frame(width: 60, height: 52)
                            .background(RoundedRectangle(cornerRadius: 14).fill(mood == m.0 ? BUI.gold.opacity(0.35) : BUI.panelHi))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(mood == m.0 ? BUI.gold : BUI.ink.opacity(0.6), lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14).fill(BUI.ink.opacity(0.7))
                if text.isEmpty {
                    Text(tr("Что понравилось, что мешает, чего хочется…"))
                        .font(DText.font(13)).foregroundStyle(BUI.muted.opacity(0.7))
                        .padding(12)
                }
                TextEditor(text: $text)
                    .font(DText.font(14))
                    .foregroundStyle(BUI.cream)
                    .scrollContentBackground(.hidden)
                    .focused($typing)
                    .padding(6)
            }
            .frame(height: 120)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(BUI.ink, lineWidth: 2))
            Button {
                Task { await send() }
            } label: {
                Group {
                    switch state {
                    case 1: ProgressView().tint(.white)
                    case 2: OutlinedText(text: tr("Спасибо! Отправлено"), size: 15)
                    default: OutlinedText(text: tr("Отправить"), size: 15)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(BloomButtonStyle(color: state == 2 ? BUI.green : BUI.orange, edge: state == 2 ? BUI.greenEdge : BUI.orangeEdge))
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state == 1 || state == 2)
            if state == 3 {
                OutlinedText(text: tr("Нет связи. Попробуй чуть позже"), size: 12, color: BUI.red)
            }
            Button {
                Analytics.shared.track("review_manual")
                requestReview()
            } label: {
                HStack(spacing: 6) {
                    Text("⭐️").font(.system(size: 16))
                    OutlinedText(text: tr("Оценить в App Store"), size: 14)
                }
                .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(BloomButtonStyle(color: BUI.panelHi, edge: BUI.ink))
        }
        .frame(width: 322)
        .onAppear { if state == 2 { state = 0; text = "" } }
    }

    private func send() async {
        typing = false
        state = 1
        let ok = await FirebaseBridge.sendFeedback(text.trimmingCharacters(in: .whitespacesAndNewlines), mood: mood,
                                                   extra: ["level": game.level, "islands": game.owned.count, "minutes": game.playMinutes])
        Analytics.shared.track("feedback", ["mood": mood, "sent": ok])
        state = ok ? 2 : 3
        if ok { Sfx.play(.victory) }
    }
}

// MARK: - menu

/// Everything that doesn't need to sit on the play screen: album, achievements, letters,
/// a new spring and the sound switches. Tiles are one fixed size so the grid stays even.
struct MenuView: View {
    @EnvironmentObject private var game: BloomGame
    @State private var musicOn = Music.enabled
    @State private var soundOn = Sfx.master > 0
    @State private var hapticsOn = Haptics.enabled

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.fixed(156), spacing: 10), GridItem(.fixed(156), spacing: 10)], spacing: 10) {
                tile("bloom_ui_book", tr("Альбом находок")) { game.panel = .album }
                tile("bloom_ui_trophy", tr("Рекорды")) { game.panel = nil; BloomGameCenter.shared.open() }
                tile("bloom_ui_skin", tr("Облик героя")) { game.panel = .skins }
                tile("bloom_ui_mail", tr("Написать нам")) { game.panel = .feedback }
                if game.canRebirth || game.springs > 0 {
                    tile("bloom_ui_spring", tr("Новая весна"), dot: game.canRebirth) { game.panel = .spring }
                }
            }
            HStack(spacing: 10) {
                toggle("🎵", tr("Музыка"), musicOn) { musicOn.toggle(); Music.enabled = musicOn }
                toggle("🔊", tr("Звуки"), soundOn) {
                    soundOn.toggle()
                    Sfx.master = soundOn ? 0.8 : 0
                    UserDefaults.standard.set(Double(Sfx.master), forKey: "dustbloom.volume")
                }
                toggle("📳", tr("Вибрация"), hapticsOn) { hapticsOn.toggle(); Haptics.enabled = hapticsOn }
            }
        }
        .frame(width: 322)
    }

    private func tile(_ icon: String, _ title: String, dot: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button { Sfx.play(.select); action() } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    PixelIcon(name: icon, size: 36)
                    OutlinedText(text: title, size: 13, fixed: false, lines: 2)
                        .frame(width: 140, height: 34)
                }
                .frame(width: 156, height: 92)
                .background(RoundedRectangle(cornerRadius: 16).fill(BUI.panelHi))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(BUI.ink, lineWidth: 2.5))
                if dot {
                    Circle().fill(BUI.green).frame(width: 16, height: 16)
                        .overlay(Circle().stroke(BUI.ink, lineWidth: 2))
                        .offset(x: -6, y: 6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ icon: String, _ title: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button { action(); Sfx.play(.select) } label: {
            VStack(spacing: 2) {
                Text(icon).font(.system(size: 17)).opacity(on ? 1 : 0.45)
                OutlinedText(text: title, size: 12, color: on ? BUI.cream : BUI.muted)
            }
            // room above the icon and below the word, so neither touches the button's edge
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(BloomButtonStyle(color: on ? BUI.green : BUI.panelHi, edge: on ? BUI.greenEdge : BUI.ink))
    }
}

// MARK: - dungeon entrance

struct DungeonView: View {
    @EnvironmentObject private var game: BloomGame
    let id: String

    var body: some View {
        if let d = BloomDungeons.byId(id) {
            Card {
                VStack(spacing: 8) {
                    OutlinedText(text: tr("Две волны пыльных созданий, затем хозяин пещеры"), size: 12.5, color: BUI.muted, fixed: false, lines: 2)
                    HStack(spacing: 12) {
                        PixelIcon(name: "bloom_relic_" + d.relic, size: 44)
                            .frame(width: 56, height: 56)
                            .background(RoundedRectangle(cornerRadius: 12).fill(BUI.ink.opacity(0.4)))
                        VStack(alignment: .leading, spacing: 3) {
                            OutlinedText(text: tr(d.relicTitle), size: 14, color: BUI.gold)
                            OutlinedText(text: tr(d.relicText), size: 12, fixed: false, lines: 2, align: .leading)
                            if game.cleared(d) {
                                OutlinedText(text: tr("Реликвия уже у тебя"), size: 11, color: BUI.green)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 6) {
                        OutlinedText(text: tr("Советуем удар: %@", d.advisedDamage), size: 12,
                                     color: game.damage >= d.advisedDamage ? BUI.green : BUI.red)
                        OutlinedText(text: "·", size: 12, color: BUI.muted)
                        OutlinedText(text: tr("У тебя: %@", game.damage), size: 12)
                    }
                }
            }
            Button {
                game.panel = nil
                game.onEnterDungeon?(d.id)
            } label: {
                OutlinedText(text: game.cleared(d) ? tr("Пройти ещё раз") : tr("Войти"), size: 16).frame(maxWidth: .infinity)
            }
            .buttonStyle(BloomButtonStyle(color: BUI.orange, edge: BUI.orangeEdge))
            OutlinedText(text: tr("Если устанешь, просто вернёшься домой"), size: 11, color: BUI.muted, fixed: false, lines: 2)
        }
    }
}
