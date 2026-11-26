import SwiftUI
import UIKit

/// Top-left of the HUD: avatar in an XP ring with the level on it, the
/// nickname and the farm's power. Tap opens the profile.
struct ProfileBadge: View {
    @EnvironmentObject private var store: FarmStore
    @AppStorage(Profile.nameKey) private var name = ""
    @AppStorage(Profile.avatarKey) private var avatar = 0
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AvatarRing(avatar: avatar, level: store.farm.level, progress: store.farm.levelProgress)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name.isEmpty ? Profile.defaultName(ru: L.ru, seed: 1) : name)
                        .font(.custom("Tiny5-Regular", size: 15))
                        .foregroundStyle(Color(uiColor: Palette.parchment))
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.6), radius: 0, x: 1, y: 1)
                    HStack(spacing: 4) {
                        Image("ui_power").interpolation(.none).resizable().frame(width: 16, height: 16)
                        Text(store.farm.power(config: store.config).formatted())
                            .font(.custom("Tiny5-Regular", size: 15))
                            .foregroundStyle(Color(uiColor: Palette.gold))
                            .shadow(color: .black.opacity(0.6), radius: 0, x: 1, y: 1)
                    }
                }
                .padding(.trailing, 6)
            }
            .padding(4)
            .padding(.trailing, 4)
            .background(
                Capsule().fill(Color(uiColor: UIColor(hex: 0x2E1A10)).opacity(0.9))
                    .overlay(Capsule().stroke(Color(uiColor: Palette.goldDeep).opacity(0.7), lineWidth: 2))
            )
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.ru ? "Профиль" : "Profile")
        .onAppear {
            if name.isEmpty { name = Profile.defaultName(ru: L.ru) }
        }
    }
}

/// Round avatar with a gold XP ring and a small level badge.
struct AvatarRing: View {
    let avatar: Int
    let level: Int
    let progress: Double
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle().stroke(Color.black.opacity(0.45), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(Color(uiColor: Palette.goldDeep), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: progress)
            Image("avatar_\(avatar)").interpolation(.none).resizable()
                .frame(width: size - 10, height: size - 10)
                .clipShape(Circle())
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            Text("\(level)")
                .font(.custom("Tiny5-Regular", size: 13))
                .foregroundStyle(Color(uiColor: Palette.ink))
                .frame(minWidth: 22, minHeight: 22)
                .background(Circle().fill(Color(uiColor: Palette.gold)))
                .overlay(Circle().stroke(Color(uiColor: Palette.outline), lineWidth: 2))
                .offset(x: 4, y: 4)
        }
    }
}

/// Nickname and avatar picker. Locked avatars show the level they open at.
struct ProfileSheet: View {
    @EnvironmentObject private var store: FarmStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Profile.nameKey) private var name = ""
    @AppStorage(Profile.avatarKey) private var avatar = 0
    @State private var draft = ""
    @FocusState private var typing: Bool

    var body: some View {
        let ru = L.ru
        let valid = Profile.validName(draft)
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        AvatarRing(avatar: avatar, level: store.farm.level, progress: store.farm.levelProgress, size: 72)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(name).font(.custom("Tiny5-Regular", size: 20))
                            HStack(spacing: 6) {
                                Image("ui_power").interpolation(.none).resizable().frame(width: 18, height: 18)
                                Text((ru ? "Мощь " : "Power ") + store.farm.power(config: store.config).formatted())
                                    .font(.custom("Tiny5-Regular", size: 15))
                            }
                            Text((ru ? "Уровень " : "Level ") + "\(store.farm.level)")
                                .font(.custom("Tiny5-Regular", size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    TextField(ru ? "Ник" : "Nickname", text: $draft)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($typing)
                        .onChange(of: draft) { _, v in
                            if v.count > Profile.maxName { draft = String(v.prefix(Profile.maxName)) }
                        }
                    Button(ru ? "Сохранить ник" : "Save nickname") {
                        guard let v = valid else { return }
                        name = v
                        typing = false
                        Sfx.play(.select, volume: 0.6)
                        Analytics.shared.track("profile_name", [:])
                    }
                    .disabled(valid == nil || valid == name)
                    .frame(minHeight: 44)
                } header: {
                    Text(ru ? "Ник" : "Nickname")
                } footer: {
                    Text(ru ? "3–16 символов: буквы, цифры, пробел, _ и -."
                            : "3–16 characters: letters, digits, space, _ and -.")
                }

                Section(ru ? "Аватар" : "Avatar") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(0..<Profile.avatarCount, id: \.self) { i in
                            avatarCell(i)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(ru ? "Профиль" : "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ru ? "Готово" : "Done") { dismiss() }
                }
            }
        }
        .onAppear { draft = name }
    }

    private func avatarCell(_ i: Int) -> some View {
        let open = Profile.isUnlocked(avatar: i, level: store.farm.level)
        return Button {
            guard open else {
                Sfx.play(.error, volume: 0.6)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            avatar = i
            UISelectionFeedbackGenerator().selectionChanged()
            Sfx.play(.select, volume: 0.6)
            Analytics.shared.track("profile_avatar", ["avatar": "\(i)"])
        } label: {
            Image("avatar_\(i)").interpolation(.none).resizable()
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .saturation(open ? 1 : 0)
                .opacity(open ? 1 : 0.55)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(avatar == i ? Color(uiColor: Palette.goldDeep) : .clear, lineWidth: 4)
                }
                .overlay(alignment: .bottom) {
                    if !open {
                        Text("LV \(Profile.avatarUnlock[i])")
                            .font(.custom("Tiny5-Regular", size: 12))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.7)))
                            .padding(.bottom, 4)
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(open ? "\(i + 1)" : (L.ru ? "Закрыто до уровня \(Profile.avatarUnlock[i])" : "Locked until level \(Profile.avatarUnlock[i])"))
    }
}
