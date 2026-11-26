import SwiftUI
import UIKit

/// Quest texts and icons, built from the goal so every language only needs
/// the verb templates (names come from the balance file).
enum Quests {
    static func title(_ q: Quest, config: GameConfig) -> String {
        let ru = L.ru
        let n = q.count
        let (kind, id) = split(q.goal)
        switch kind {
        case "harvest" where id != nil:
            let name = config.crop(id!)?.localizedName ?? id!
            return ru ? "Собери \(name): \(n)" : "Harvest \(n) \(name)"
        case "harvest": return ru ? "Собери урожай \(n) раз" : "Harvest \(n) crops"
        case "plant": return ru ? "Посади семена \(n) раз" : "Plant \(n) seeds"
        case "till": return ru ? "Вскопай грядки: \(n)" : "Till \(n) beds"
        case "sell": return ru ? "Продай урожай: \(n)" : "Sell \(n) crops"
        case "order": return ru ? "Выполни заказы: \(n)" : "Deliver \(n) orders"
        case "clear": return ru ? "Расчисти завалы: \(n)" : "Clear \(n) rocks or trees"
        case "build" where id != nil:
            let name = config.scarecrow(id!)?.localizedName ?? id!
            return ru ? "Собери пугал «\(name)»: \(n)" : "Build \(n) \(name)"
        case "build": return ru ? "Собери пугал: \(n)" : "Build \(n) scarecrows"
        case "raid_win" where id != nil:
            let name = config.raid(id!)?.localizedName ?? id!
            return ru ? "Победи: \(name)" : "Defeat \(name)"
        case "raid_win": return ru ? "Выиграй набеги: \(n)" : "Win \(n) raids"
        case "level": return ru ? "Достигни \(n) уровня" : "Reach level \(n)"
        case "manor": return ru ? "Улучши усадьбу до \(n) ур." : "Upgrade the manor to level \(n)"
        case "plots", "plot": return ru ? "Купи участки земли: \(n)" : "Buy \(n) land plots"
        case "army": return ru ? "Собери армию из \(n) пугал" : "Have \(n) scarecrows in the army"
        case "building":
            let name = id.flatMap { config.building($0)?.localizedName } ?? (id ?? "")
            return n > 1 ? (ru ? "\(name): уровень \(n)" : "\(name) to level \(n)")
                         : (ru ? "Построй: \(name)" : "Build the \(name)")
        default: return q.id
        }
    }

    static func icon(_ q: Quest, config: GameConfig) -> String {
        let (kind, id) = split(q.goal)
        switch kind {
        case "harvest": return "\(id ?? "dustwheat")_3"
        case "plant": return "dustwheat_2"
        case "till": return "icon_till"
        case "sell": return "ui_coin"
        case "order": return "icon_orders"
        case "clear": return "prop_dead_tree"
        case "build": return id.map { "unit_\($0)" } ?? "icon_workshop"
        case "army": return "unit_straw_guard"
        case "raid_win": return id.map { "enemy_\($0)" } ?? "icon_raid"
        case "manor": return "prop_manor_1"
        case "building": return id.map { "bld_\($0)_0" } ?? "icon_workshop"
        case "level": return "ui_power"
        default: return "icon_quests"
        }
    }

    private static func split(_ goal: String) -> (String, String?) {
        let parts = goal.split(separator: ":", maxSplits: 1).map(String.init)
        return (parts[0], parts.count > 1 ? parts[1] : nil)
    }
}

/// Left-edge tracker under the profile: the first quest and its progress.
/// Glows gold with a count when rewards are waiting. Tap opens the list.
struct QuestTracker: View {
    @EnvironmentObject private var store: FarmStore
    var action: () -> Void

    var body: some View {
        let quests = store.farm.activeQuests(config: store.config)
        let ready = store.farm.claimableQuests(config: store.config)
        let first = quests.first { store.farm.questProgress($0, config: store.config) >= $0.count } ?? quests.first
        Button(action: action) {
            HStack(spacing: 8) {
                Image("icon_quests").interpolation(.none).resizable()
                    .frame(width: 28, height: 28)
                if let q = first {
                    let have = store.farm.questProgress(q, config: store.config)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ready > 0 ? (L.ru ? "Награда ждёт!" : "Reward ready!") : Quests.title(q, config: store.config))
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(uiColor: ready > 0 ? Palette.gold : Palette.parchment))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        ProgressBar(value: Double(have) / Double(max(1, q.count)), height: 6)
                            .frame(width: 104)
                    }
                    .frame(width: 104, alignment: .leading)
                } else {
                    Text(L.ru ? "Задания" : "Quests")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(uiColor: Palette.parchment))
                }
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: UIColor(hex: 0x2E1A10)).opacity(0.9))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(uiColor: ready > 0 ? Palette.gold : Palette.goldDeep).opacity(ready > 0 ? 1 : 0.7),
                                lineWidth: 2))
            )
            .overlay(alignment: .topTrailing) {
                if ready > 0 {
                    Text("\(ready)")
                        .font(.custom("Tiny5-Regular", size: 12))
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(Color(red: 0.85, green: 0.2, blue: 0.3)))
                        .overlay(Circle().stroke(Color(uiColor: Palette.outline), lineWidth: 2))
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.ru ? "Задания" : "Quests")
    }
}

/// Gold bar on a dark track.
struct ProgressBar: View {
    let value: Double
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(uiColor: UIColor(hex: 0x8A6A4A)).opacity(0.55))
                Capsule().fill(Color(uiColor: Palette.goldDeep))
                    .frame(width: max(height, g.size.width * min(1, max(0, value))))
                    .opacity(value > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.3), value: value)
    }
}

/// The quest list: the active quests with progress and a claim button,
/// and a line on what opens next.
struct QuestSheet: View {
    @EnvironmentObject private var store: FarmStore
    @State private var claimed: QuestResult?

    var body: some View {
        let quests = store.farm.activeQuests(config: store.config)
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image("icon_quests").interpolation(.none).resizable().frame(width: 32, height: 32)
                Text(L.ru ? "Задания" : "Quests")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(uiColor: Palette.ink))
                Spacer()
                Text("\(store.farm.questsDone.count)/\(store.config.quests?.list.count ?? 0)")
                    .font(.custom("Tiny5-Regular", size: 15))
                    .foregroundStyle(Color(uiColor: Palette.ink).opacity(0.7))
            }
            ScrollView {
                VStack(spacing: 8) {
                    if quests.isEmpty {
                        Text(L.ru ? "Новые задания откроются на следующем уровне." : "New quests open at the next level.")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(uiColor: Palette.ink))
                            .multilineTextAlignment(.center)
                            .padding(.top, 24)
                    }
                    ForEach(quests) { q in row(q) }
                }
            }
        }
        .padding(16)
        .overlay(alignment: .center) {
            if let r = claimed {
                rewardToast(r)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation { claimed = nil }
                    }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(uiColor: Palette.parchment))
    }

    private func row(_ q: Quest) -> some View {
        let have = store.farm.questProgress(q, config: store.config)
        let done = have >= q.count
        let ink = Color(uiColor: Palette.ink)
        return HStack(spacing: 12) {
            Image(Quests.icon(q, config: store.config)).interpolation(.none).resizable().scaledToFit()
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(Quests.title(q, config: store.config))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 8) {
                    ProgressBar(value: Double(have) / Double(max(1, q.count)))
                    Text("\(have)/\(q.count)")
                        .font(.custom("Tiny5-Regular", size: 13))
                        .foregroundStyle(ink)
                        .fixedSize()
                }
                rewards(q)
            }
            Button {
                claim(q)
            } label: {
                Text(L.ru ? "Забрать" : "Claim")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                    .frame(width: 72, height: 44)
                    .background(slot(done))
                    .opacity(done ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!done)
        }
        .padding(12)
        .background(slot(false))
    }

    private func rewards(_ q: Quest) -> some View {
        HStack(spacing: 8) {
            if q.coins > 0 { chip("ui_coin", "\(q.coins)") }
            if q.xp > 0 { chip(nil, "+\(q.xp) XP") }
            ForEach((q.items ?? [:]).sorted(by: { $0.key < $1.key }), id: \.key) { id, n in
                chip(Items.image(id), "×\(n)")
            }
        }
    }

    private func chip(_ image: String?, _ text: String) -> some View {
        HStack(spacing: 3) {
            if let image {
                Image(image).interpolation(.none).resizable().scaledToFit().frame(width: 16, height: 16)
            }
            Text(text).font(.custom("Tiny5-Regular", size: 12)).foregroundStyle(Color(uiColor: Palette.ink))
        }
    }

    private func claim(_ q: Quest) {
        switch store.claimQuest(q.id) {
        case .success(let r):
            Sfx.play(.coin, volume: 0.9)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { claimed = r }
        case .failure:
            Sfx.play(.error, volume: 0.6)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func rewardToast(_ r: QuestResult) -> some View {
        VStack(spacing: 6) {
            Text(L.ru ? "Задание выполнено!" : "Quest complete!")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(uiColor: Palette.gold))
            HStack(spacing: 10) {
                if r.coins > 0 {
                    Image("ui_coin").interpolation(.none).resizable().frame(width: 20, height: 20)
                    Text("+\(r.coins)").font(.custom("Tiny5-Regular", size: 17)).foregroundStyle(.white)
                }
                if r.xp > 0 {
                    Text("+\(r.xp) XP").font(.custom("Tiny5-Regular", size: 17)).foregroundStyle(.white)
                }
            }
            if r.levelUp {
                Text(L.ru ? "Новый уровень!" : "Level up!")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(uiColor: Palette.gold))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: UIColor(hex: 0x2E1A10)).opacity(0.95))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(uiColor: Palette.gold), lineWidth: 2))
        )
    }
}
