import SpriteKit
import SwiftUI

/// The battle screen: scene underneath, a calm pixel HUD on top.
struct DefenseView: View {
    @StateObject private var game = DefenseGame()
    @State private var scene = DefenseScene(size: CGSize(width: 390, height: 844))
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 60,
                       debugOptions: ProcessInfo.processInfo.arguments.contains("-showFPS") ? [.showsFPS, .showsNodeCount, .showsDrawCount] : [])
                .ignoresSafeArea()
            DefenseHUD(onSquadChange: { scene.refreshSquad() })
            if let r = game.offline {
                OfflineDialog(reward: r) { double in
                    game.collectOffline(double: double)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .environmentObject(game)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: game.offline)
        .onAppear { scene.game = game }
        .onChange(of: phase) { _, p in
            if p == .background { game.save() }
            if p == .active { game.resume() }
        }
    }
}

// MARK: - shared pixel pieces

enum DText {
    static let ink = Color(uiColor: Palette.ink)
    static let cream = Color(red: 1, green: 0.96, blue: 0.86)
    static let gold = Color(uiColor: Palette.gold)

    /// Bold smooth text with a dark outline reads best over pixel art on a phone.
    static let fontName = "Rubik-Bold"
    static func font(_ size: CGFloat) -> Font { .custom(fontName, size: size * 1.1) }
}

/// Pixel text with a 1-point dark outline so it reads over the battlefield.
struct OutlinedText: View {
    let text: String
    var size: CGFloat = 16
    var color: Color = DText.cream
    /// false: one line that shrinks to fit its frame instead of widening the layout.
    var fixed = true
    var lines = 1

    var body: some View {
        let base = ZStack {
            ForEach(0..<4, id: \.self) { k in
                Text(text).font(DText.font(size)).foregroundStyle(Color.black.opacity(0.75))
                    .offset(x: k < 2 ? (k == 0 ? -1.5 : 1.5) : 0, y: k >= 2 ? (k == 2 ? -1.5 : 1.5) : 0)
            }
            Text(text).font(DText.font(size)).foregroundStyle(color)
        }
        .lineLimit(lines)
        .multilineTextAlignment(.center)
        if fixed {
            base.fixedSize()
        } else {
            base.minimumScaleFactor(0.5)
        }
    }
}

/// A number exactly centred in a round badge (used for levels).
struct LevelBadge: View {
    let level: Int
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.23, green: 0.14, blue: 0.09))
            Circle().strokeBorder(DText.gold, lineWidth: 2)
            Text("\(level)")
                .font(DText.font(level >= 100 ? size * 0.4 : size * 0.5))
                .foregroundStyle(DText.cream)
                .frame(width: size, height: size, alignment: .center)
                .multilineTextAlignment(.center)
                .monospacedDigit()
        }
        .frame(width: size, height: size)
    }
}

/// Wooden pixel button with a squash on press.
struct WoodButtonStyle: ButtonStyle {
    var enabled = true
    var minHeight: CGFloat = 44
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .frame(minHeight: minHeight)
            .background(
                Image(enabled ? "ui_slot_selected" : "ui_slot")
                    .interpolation(.none)
                    .resizable(capInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12), resizingMode: .stretch)
            )
            .opacity(enabled ? 1 : 0.6)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - HUD

struct DefenseHUD: View {
    @EnvironmentObject private var game: DefenseGame
    var onSquadChange: () -> Void
    @State private var tab = 0

    var body: some View {
        GeometryReader { g in
            VStack(spacing: 8) {
                topBar
                if let lost = game.lostWave {
                    Button {
                        game.retryNext()
                        Sfx.play(.select, volume: 0.7)
                    } label: {
                        OutlinedText(text: ru ? "Штурм волны \(lost)" : "Storm wave \(lost)", size: 16, color: DText.gold)
                    }
                    .buttonStyle(WoodButtonStyle())
                    .transition(.scale.combined(with: .opacity))
                }
                Spacer(minLength: 0)
                skillRow
                    .padding(.horizontal, 12)
                // the wood panel runs to the screen's bottom edge; its content stays above the home bar
                bottomPanel(bottomInset: g.safeAreaInsets.bottom)
            }
            .frame(width: g.size.width)
            .ignoresSafeArea(edges: .bottom)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: game.lostWave)
    }

    private var ru: Bool { Locale.preferredLanguages.first?.hasPrefix("ru") ?? false }

    // MARK: top

    private var topBar: some View {
        HStack(alignment: .top, spacing: 8) {
            PixelPanel {
                VStack(alignment: .leading, spacing: 4) {
                    OutlinedText(text: game.landName, size: 13, color: DText.gold)
                    HStack(spacing: 6) {
                        OutlinedText(text: (ru ? "Волна " : "Wave ") + "\(game.waveInLand)/\(game.balance.wavesPerLand)", size: 16)
                        if game.isBossWave {
                            OutlinedText(text: ru ? "БОСС" : "BOSS", size: 13, color: Color(red: 1, green: 0.4, blue: 0.35))
                        }
                    }
                    bar(value: game.waveProgress, color: DText.gold, width: 140)
                    HStack(spacing: 4) {
                        Image("edge_fence_x").interpolation(.none).resizable().frame(width: 16, height: 14)
                        bar(value: game.fence, color: fenceColor, width: 120)
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                currency("ui_coin", game.progress.coins)
                currency("dustwheat_3", game.progress.seeds)
            }
        }
        .padding(.top, 4)
        .padding(.horizontal, 12)
    }

    private var fenceColor: Color {
        game.fence > 0.5 ? Color(red: 0.45, green: 0.75, blue: 0.3)
            : (game.fence > 0.25 ? Color(red: 0.95, green: 0.7, blue: 0.2) : Color(red: 0.9, green: 0.25, blue: 0.25))
    }

    private func bar(value: Double, color: Color, width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Color.black.opacity(0.55))
            Rectangle().fill(color).frame(width: max(0, (width - 4) * CGFloat(value)))
                .padding(2)
        }
        .frame(width: width, height: 10)
        .overlay(Rectangle().strokeBorder(Color(red: 0.23, green: 0.14, blue: 0.09), lineWidth: 1))
        .animation(.linear(duration: 0.12), value: value)
    }

    private func currency(_ icon: String, _ v: Double) -> some View {
        PixelPanel(padding: 5) {
            HStack(spacing: 6) {
                Image(icon).interpolation(.none).resizable().scaledToFit().frame(width: 24, height: 24)
                OutlinedText(text: BigNumber.format(v), size: 17)
                    .frame(minWidth: 64, alignment: .trailing)
            }
        }
    }

    // MARK: skills

    private var skillRow: some View {
        HStack(spacing: 8) {
            ForEach(DefenseContent.heroes.indices, id: \.self) { i in
                if game.progress.heroLevels[i] > 0 {
                    SkillButton(hero: i, charge: game.skillCharge[i]) {
                        game.useSkill(i)
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                toggle(on: game.autoSkills, label: "AUTO") { game.autoSkills.toggle() }
                toggle(on: game.fast, label: "x2") { game.fast.toggle() }
            }
        }
    }

    private func toggle(on: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Sfx.play(.select, volume: 0.6)
        } label: {
            OutlinedText(text: label, size: 13, color: on ? DText.gold : DText.cream)
                .frame(width: 40, height: 22)
        }
        .buttonStyle(WoodButtonStyle(enabled: on, minHeight: 26))
    }

    // MARK: bottom

    private func bottomPanel(bottomInset: CGFloat) -> some View {
        PixelPanel(padding: 8) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    tabButton(0, ru ? "Пугала" : "Scarecrows")
                    tabButton(1, ru ? "Грядки" : "Crops")
                }
                HStack(spacing: 6) {
                    if tab == 0 {
                        ForEach(DefenseContent.heroes.indices, id: \.self) { i in heroCard(i) }
                    } else {
                        ForEach(DefenseContent.crops.indices, id: \.self) { i in cropCard(i) }
                    }
                }
            }
            .padding(.bottom, max(0, bottomInset - 6))
        }
    }

    private func tabButton(_ t: Int, _ title: String) -> some View {
        Button {
            tab = t
            Sfx.play(.select, volume: 0.5)
        } label: {
            OutlinedText(text: title, size: 14, color: tab == t ? DText.gold : DText.cream, fixed: false)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(WoodButtonStyle(enabled: tab == t))
    }

    private func heroCard(_ i: Int) -> some View {
        let h = DefenseContent.heroes[i]
        let level = game.progress.heroLevels[i]
        return UpgradeCard(
            image: h.sprite + "_idle_0", hd: false, level: level, locked: !game.heroUnlocked(i),
            unlockWave: h.unlockWave, title: DefenseContent.text(h.name),
            dps: game.heroDPS(i), cost: game.heroCost(i), currency: "ui_coin",
            canAfford: game.progress.coins >= game.heroCost(i)
        ) {
            if game.upgradeHero(i) { Sfx.play(.levelUp, volume: 0.5); onSquadChange() } else { Sfx.play(.error, volume: 0.5) }
        }
    }

    private func cropCard(_ i: Int) -> some View {
        let c = DefenseContent.crops[i]
        let level = game.progress.cropLevels[i]
        return UpgradeCard(
            image: c.sprite, hd: true, level: level, locked: !game.cropUnlocked(i),
            unlockWave: c.unlockWave, title: DefenseContent.text(c.role),
            dps: game.cropDPS(i), cost: game.cropCost(i), currency: "dustwheat_3",
            canAfford: game.progress.seeds >= game.cropCost(i)
        ) {
            if game.upgradeCrop(i) { Sfx.play(.levelUp, volume: 0.5); onSquadChange() } else { Sfx.play(.error, volume: 0.5) }
        }
    }
}

/// One upgrade card; four of them share the row equally. Hold to keep buying.
struct UpgradeCard: View {
    let image: String
    let hd: Bool
    let level: Int
    let locked: Bool
    let unlockWave: Int
    let title: String
    let dps: Double
    let cost: Double
    let currency: String
    let canAfford: Bool
    let buy: () -> Void
    @State private var holding: Timer?

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(image).interpolation(.none).resizable().scaledToFit()
                    .frame(width: 52, height: 52)
                    .saturation(locked ? 0 : 1)
                    .opacity(locked ? 0.45 : 1)
                    .frame(maxWidth: .infinity)
                if !locked { LevelBadge(level: level, size: 24) }
            }
            OutlinedText(text: title, size: 12.5, fixed: false, lines: 2)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
            if locked {
                OutlinedText(text: (Locale.preferredLanguages.first?.hasPrefix("ru") ?? false ? "волна " : "wave ") + "\(unlockWave)",
                             size: 11, color: DText.cream.opacity(0.7))
                    .frame(height: 30)
            } else {
                HStack(spacing: 3) {
                    Image(currency).interpolation(.none).resizable().scaledToFit().frame(width: 14, height: 14)
                    OutlinedText(text: BigNumber.format(cost), size: 13,
                                 color: canAfford ? DText.cream : Color(red: 1, green: 0.45, blue: 0.4))
                }
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(
                    Image(canAfford ? "ui_slot_selected" : "ui_slot").interpolation(.none)
                        .resizable(capInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12), resizingMode: .stretch)
                )
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.18).clipShape(RoundedRectangle(cornerRadius: 4)))
        .contentShape(Rectangle())
        .onTapGesture { if !locked { buy() } }
        .onLongPressGesture(minimumDuration: 0.35, pressing: { pressing in
            holding?.invalidate()
            holding = nil
            guard pressing, !locked else { return }
            // repeat only after a real hold, so a quick tap buys exactly once
            let t = Timer(fire: Date().addingTimeInterval(0.4), interval: 0.12, repeats: true) { _ in
                MainActor.assumeIsolated { buy() }
            }
            RunLoop.main.add(t, forMode: .common)
            holding = t
        }, perform: {})
        .accessibilityLabel("\(title), \(level)")
    }
}

/// Round skill button with the hero's face and a cooldown sweep.
struct SkillButton: View {
    let hero: Int
    let charge: Double
    let tap: () -> Void

    var body: some View {
        Button {
            guard charge <= 0 else { Sfx.play(.error, volume: 0.4); return }
            tap()
        } label: {
            ZStack {
                Circle().fill(Color(red: 0.23, green: 0.14, blue: 0.09))
                Image(DefenseContent.heroes[hero].sprite + "_idle_0").interpolation(.none).resizable().scaledToFit()
                    .frame(width: 40, height: 40)
                    .offset(y: 4)
                    .clipShape(Circle())
                if charge > 0 {
                    Circle()
                        .trim(from: 0, to: charge)
                        .rotation(.degrees(-90))
                        .fill(Color.black.opacity(0.6))
                }
                Circle().strokeBorder(charge <= 0 ? DText.gold : Color.gray, lineWidth: 3)
            }
            .frame(width: 52, height: 52)
            .scaleEffect(charge <= 0 ? 1 : 0.94)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: charge <= 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(DefenseContent.text(DefenseContent.heroes[hero].skillName))
    }
}

/// Our own pixel dialog (never a system alert): what the farm earned while away.
struct OfflineDialog: View {
    let reward: DefenseGame.OfflineReward
    let collect: (_ double: Bool) -> Void
    private var ru: Bool { Locale.preferredLanguages.first?.hasPrefix("ru") ?? false }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            PixelPanel(padding: 16) {
                VStack(spacing: 14) {
                    OutlinedText(text: ru ? "Пока тебя не было" : "While you were away", size: 20, color: DText.gold)
                    OutlinedText(text: away, size: 13)
                    HStack(spacing: 24) {
                        amount("ui_coin", reward.coins)
                        amount("dustwheat_3", reward.seeds)
                    }
                    HStack(spacing: 10) {
                        Button { collect(false) } label: {
                            OutlinedText(text: ru ? "Забрать" : "Collect", size: 16).frame(width: 110)
                        }
                        .buttonStyle(WoodButtonStyle(enabled: false))
                        Button { collect(true) } label: {
                            OutlinedText(text: ru ? "x2 за ролик" : "x2 for an ad", size: 16, color: DText.gold).frame(width: 110)
                        }
                        .buttonStyle(WoodButtonStyle(enabled: true))
                    }
                }
                .frame(width: 280)
            }
        }
    }

    private var away: String {
        func hm(_ s: Double) -> String {
            let h = Int(s) / 3600, m = Int(s) % 3600 / 60
            return ru ? (h > 0 ? "\(h) ч \(m) мин" : "\(m) мин") : (h > 0 ? "\(h)h \(m)m" : "\(m)m")
        }
        let capped = reward.seconds > reward.capSeconds
        return (ru ? "Тебя не было " : "Away ") + hm(reward.seconds)
            + (capped ? (ru ? " · амбар полон (\(Int(reward.capSeconds / 3600)) ч)" : " · barn full (\(Int(reward.capSeconds / 3600))h)") : "")
    }

    private func amount(_ icon: String, _ v: Double) -> some View {
        VStack(spacing: 4) {
            Image(icon).interpolation(.none).resizable().scaledToFit().frame(width: 40, height: 40)
            OutlinedText(text: "+" + BigNumber.format(v), size: 20)
        }
    }
}
