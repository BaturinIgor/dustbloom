import SpriteKit
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
            SpriteView(scene: scene, preferredFramesPerSecond: 60,
                       debugOptions: ProcessInfo.processInfo.arguments.contains("-showFPS") ? [.showsFPS, .showsNodeCount, .showsDrawCount] : [])
                .ignoresSafeArea()
            // soft vignette pulls the eye to the hero
            RadialGradient(colors: [.clear, .clear, Color(red: 0.05, green: 0.12, blue: 0.25).opacity(0.28)],
                           center: .center, startRadius: 120, endRadius: 520)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            BloomHUD()
        }
        .environmentObject(game)
        .onAppear { scene.game = game }
        .onChange(of: phase) { _, p in
            if p != .active { game.save() }
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
                HStack {
                    GoalCard()
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let n = game.nearby { contextButton(n) }
                        buildButton
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                hotbar
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: game.toast)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: game.nearby)

            if let p = game.panel {
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
                        .padding(.top, 118) // below the goal card, so "goal done" doesn't hide the next goal
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
        HStack(spacing: 0) {
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
            Spacer()
            HStack(spacing: 6) {
                PixelIcon(name: "bloom_item_coin", size: 26)
                OutlinedText(text: "\(game.coins)", size: 18)
                    .frame(minWidth: 56)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Capsule().fill(BUI.ink.opacity(0.85)))
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
                OutlinedText(text: "Строить", size: 12.5)
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
        case .island(let id):
            let isl = game.island(id)
            Button { game.panel = .buy(id); Sfx.play(.select) } label: {
                HStack(spacing: 6) {
                    OutlinedText(text: "Остров", size: 14)
                    PixelIcon(name: "bloom_item_coin", size: 20)
                    OutlinedText(text: "\(isl.price)", size: 14, color: game.coins >= isl.price ? BUI.cream : BUI.red)
                }
            }
            .buttonStyle(BloomButtonStyle(color: BUI.green, edge: BUI.greenEdge))
        }
    }

    private var hotbar: some View {
        let items = Array(game.hotbar.prefix(7)).map { $0.0 }
        return HStack(spacing: 6) {
            if items.isEmpty {
                OutlinedText(text: "Подойди к дереву или камню", size: 13)
                    .frame(height: 50)
            }
            ForEach(items) { item in
                let n = game.count(item)
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.12)).frame(width: 46, height: 50)
                    PixelIcon(name: item.sprite, size: 30).frame(width: 46, height: 44)
                    OutlinedText(text: "\(n)", size: 12).padding(.trailing, 4).padding(.bottom, 1)
                }
                .frame(width: 46, height: 50)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(BUI.ink.opacity(0.88)))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .onTapGesture { game.panel = .inventory }
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
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) { content }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
            }
            .frame(maxHeight: 470)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 350)
        .background(RoundedRectangle(cornerRadius: 22).fill(BUI.panel))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(BUI.ink, lineWidth: 4))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }

    private var title: String {
        switch panel {
        case .build: return "Постройки"
        case .building(let k): return k.title
        case .buy(let id): return game.island(id).name
        case .inventory: return "Рюкзак"
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
        HStack(spacing: 8) {
            ForEach(cost.indices, id: \.self) { i in
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
                        OutlinedText(text: k.title, size: 15)
                        Text(k.blurb).font(DText.font(10.5)).foregroundStyle(BUI.cream.opacity(0.75))
                        CostRow(cost: k.cost)
                    }
                    Spacer(minLength: 0)
                    if game.isBuilt(k) {
                        OutlinedText(text: "✓", size: 22, color: BUI.green).frame(width: 74)
                    } else if game.level < k.unlockLevel {
                        VStack(spacing: 0) {
                            OutlinedText(text: "🔒", size: 16)
                            OutlinedText(text: "Ур. \(k.unlockLevel)", size: 11)
                        }
                        .frame(width: 74)
                    } else {
                        Button { game.build(k) } label: { OutlinedText(text: "Строить", size: 12.5) }
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
                        OutlinedText(text: "В работе: \(q.left)", size: 13)
                        TimelineView(.animation) { _ in
                            let p = min(1, (game.progress[kind.rawValue] ?? 0) / r.seconds)
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
                        Text(String(format: "%.0f с за штуку", r.seconds.rounded(.up)))
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
            OutlinedText(text: "Пока нечего продать", size: 14).padding(20)
        }
        ForEach(items) { i in
            Card {
                HStack(spacing: 10) {
                    PixelIcon(name: i.sprite, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        OutlinedText(text: i.title, size: 13)
                        HStack(spacing: 3) {
                            OutlinedText(text: "\(game.count(i)) шт · по", size: 11)
                            PixelIcon(name: "bloom_item_coin", size: 14)
                            OutlinedText(text: "\(i.price)", size: 11, color: BUI.gold)
                        }
                    }
                    Spacer(minLength: 0)
                    Button { game.sell(i, all: false) } label: { OutlinedText(text: "1", size: 13) }
                        .buttonStyle(BloomButtonStyle(color: BUI.panel, edge: BUI.ink))
                    Button { game.sell(i, all: true) } label: { OutlinedText(text: "Все", size: 13) }
                        .buttonStyle(BloomButtonStyle(color: BUI.orange, edge: BUI.orangeEdge))
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
                    OutlinedText(text: "Удар: \(game.damage)", size: 12)
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
                            OutlinedText(text: "Удар: \(next.damage)", size: 12)
                            CostRow(cost: next.cost)
                        }
                        Spacer(minLength: 0)
                    }
                    Text("Шанс \(Int(BloomContent.luckyChance * 100))% на удачную ковку: +1 к удару")
                        .font(DText.font(10.5)).foregroundStyle(BUI.gold.opacity(0.9))
                    Button { game.forgePick() } label: { OutlinedText(text: "Выковать", size: 15).frame(maxWidth: .infinity) }
                        .buttonStyle(BloomButtonStyle(color: BUI.orange, edge: BUI.orangeEdge, enabled: game.has(next.cost)))
                }
            }
        } else {
            OutlinedText(text: "Лучшая кирка уже у тебя", size: 14).padding(12)
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
                OutlinedText(text: "Здесь растёт:", size: 13)
                HStack(spacing: 10) {
                    ForEach(isl.spawn.keys.sorted(), id: \.self) { k in
                        PixelIcon(name: "bloom_" + k, size: 34)
                    }
                }
                Text("Купи остров, и пыль сменится цветами")
                    .font(DText.font(11)).foregroundStyle(BUI.cream.opacity(0.75))
            }
        }
        Button { game.buy(id) } label: {
            HStack(spacing: 6) {
                OutlinedText(text: "Купить за", size: 16)
                PixelIcon(name: "bloom_item_coin", size: 22)
                OutlinedText(text: "\(isl.price)", size: 16)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BloomButtonStyle(enabled: game.coins >= isl.price))
        if game.coins < isl.price {
            OutlinedText(text: "Не хватает \(isl.price - game.coins). Продай ресурсы на рынке", size: 11, color: BUI.red, fixed: false, lines: 2)
        }
    }
}

struct InventoryGrid: View {
    @EnvironmentObject private var game: BloomGame
    var body: some View {
        let cols = Array(repeating: GridItem(.fixed(70), spacing: 8), count: 4)
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(BItem.allCases) { i in
                VStack(spacing: 2) {
                    PixelIcon(name: i.sprite, size: 32).opacity(game.count(i) > 0 ? 1 : 0.25)
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
                            OutlinedText(text: "Забрать награду!", size: 11, color: BUI.gold)
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
                OutlinedText(text: "Твои помощники: \(game.helpers.count)/\(BloomContent.maxHelpers)", size: 13)
                HStack(spacing: 14) {
                    ForEach(0..<BloomContent.maxHelpers, id: \.self) { i in
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
                Text("Блумлинги сами бегут к ближайшему дереву или камню и добывают для тебя")
                    .font(DText.font(10.5)).foregroundStyle(BUI.cream.opacity(0.75)).multilineTextAlignment(.center)
            }
        }
        if game.helpers.count < BloomContent.maxHelpers {
            Card {
                VStack(spacing: 8) {
                    CostRow(cost: game.helperCost)
                    Button { game.growHelper() } label: {
                        OutlinedText(text: "Вырастить блумлинга", size: 15).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BloomButtonStyle(enabled: game.canGrowHelper))
                }
            }
        }
    }
}
