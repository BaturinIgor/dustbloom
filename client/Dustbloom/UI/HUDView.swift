import SwiftUI
import UIKit

/// Minimal pixel HUD: coins and level on top, crop picker at the bottom.
/// Rule from the concept: the farm is the main screen, not the buttons.
struct HUDView: View {
    @EnvironmentObject private var store: FarmStore

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                PixelPanel {
                    HStack(spacing: 6) {
                        Image("ui_coin").interpolation(.none).resizable().frame(width: 28, height: 28)
                        PixelText(text: "\(store.farm.coins)", scale: 3)
                            .id(store.farm.coins)
                            .transition(.scale(scale: 1.3).combined(with: .opacity))
                    }
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: store.farm.coins)
                }
                PixelPanel {
                    PixelText(text: "LV\(store.farm.level)", scale: 3)
                }
                Spacer()
                if store.isOnline {
                    Rectangle().fill(Color.green).frame(width: 9, height: 9)
                        .overlay(Rectangle().stroke(Color(uiColor: Palette.outline), lineWidth: 3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            PixelPanel(padding: 12) {
                HStack(spacing: 10) {
                    ForEach(store.config.crops) { crop in
                        CropButton(crop: crop, selected: store.selectedCrop == crop.id) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                                store.selectedCrop = crop.id
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    }
                }
            }
            .padding(.bottom, 12)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image("\(crop.id)_3")
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 48, height: 72)
                    .padding(.top, -14)  // sprite has empty space above short crops
                HStack(spacing: 4) {
                    Image("ui_coin").interpolation(.none).resizable().frame(width: 16, height: 16)
                    PixelText(text: "\(crop.seedCost)", scale: 2)
                }
            }
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
