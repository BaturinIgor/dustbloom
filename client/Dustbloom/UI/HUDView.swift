import SwiftUI
import UIKit

/// Minimal HUD: coins and level on top, crop picker at the bottom.
/// Rule from the concept: the farm is the main screen, not the buttons.
struct HUDView: View {
    @EnvironmentObject private var store: FarmStore

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Pill {
                    Image("ui_coin").interpolation(.none).resizable().frame(width: 22, height: 22)
                    Text("\(store.farm.coins)")
                        .contentTransition(.numericText())
                        .animation(.snappy, value: store.farm.coins)
                }
                Pill {
                    Text("LV \(store.farm.level)")
                        .contentTransition(.numericText())
                        .animation(.snappy, value: store.farm.level)
                }
                Spacer()
                if store.isOnline {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            HStack(spacing: 12) {
                ForEach(store.config.crops) { crop in
                    CropButton(crop: crop, selected: store.selectedCrop == crop.id) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                            store.selectedCrop = crop.id
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(uiColor: Palette.parchment))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(uiColor: Palette.outline), lineWidth: 3))
            )
            .padding(.bottom, 12)
        }
        .font(.system(size: 17, weight: .heavy, design: .rounded))
    }
}

private struct Pill<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 6) { content }
            .foregroundStyle(Color(uiColor: Palette.ink))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color(uiColor: Palette.parchment))
                    .overlay(Capsule().stroke(Color(uiColor: Palette.outline), lineWidth: 3))
            )
    }
}

private struct CropButton: View {
    let crop: GameConfig.Crop
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image("\(crop.id)_3")
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 40, height: 60)
                HStack(spacing: 2) {
                    Image("ui_coin").interpolation(.none).resizable().frame(width: 14, height: 14)
                    Text("\(crop.seedCost)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(Color(uiColor: Palette.ink))
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: selected ? Palette.gold : Palette.parchmentShade))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(uiColor: selected ? Palette.goldDeep : .clear), lineWidth: 3)
            )
            .scaleEffect(selected ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(crop.localizedName)
    }
}
