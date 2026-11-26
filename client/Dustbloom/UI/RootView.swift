import SpriteKit
import SwiftUI

/// Loading screen first, then the farm with the HUD on top.
struct RootView: View {
    @EnvironmentObject private var store: FarmStore
    @State private var loaded = false
    @State private var connected = false

    var body: some View {
        ZStack {
            if loaded {
                // Farm Defense prototype; the old farm screen (GameView) stays in code for the day phase
                DefenseView()
                    .transition(.opacity)
            } else {
                IntroView(ready: connected) {
                    withAnimation(.easeInOut(duration: 0.6)) { loaded = true }
                }
                .transition(.opacity)
            }
        }
        .task {
            await store.connect()
            connected = true
        }
    }
}

struct GameView: View {
    @EnvironmentObject private var store: FarmStore
    @State private var scene: FarmScene = {
        let s = FarmScene(size: CGSize(width: 390, height: 844))
        return s
    }()

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 60)
                .ignoresSafeArea()
            HUDView()
        }
        .onAppear { scene.store = store }
    }
}

/// The animated splash (Scenes/IntroScene.swift) shown while the farm loads.
struct IntroView: View {
    var ready: Bool
    var onDone: () -> Void
    @State private var scene: IntroScene = IntroScene(size: CGSize(width: 390, height: 844))
    @State private var readyBox = ReadyBox()

    final class ReadyBox { var value = false }

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 60)
            .ignoresSafeArea()
            .onAppear {
                let box = readyBox
                scene.isReady = { box.value }
                scene.onDone = onDone
            }
            .onChange(of: ready, initial: true) { _, now in readyBox.value = now }
    }
}

/// Old static loading screen, kept for previews.
struct LoadingView: View {
    var onDone: () -> Void
    @State private var progress: CGFloat = 0
    @State private var logoIn = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(uiColor: UIColor(hex: 0x2A2233)), Color(uiColor: Palette.dustDeep)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 36) {
                Image("logo_wordmark")
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320)
                    .scaleEffect(logoIn ? 1 : 0.6)
                    .opacity(logoIn ? 1 : 0)

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(uiColor: Palette.outline))
                        .frame(width: 220, height: 14)
                    Rectangle()
                        .fill(Color(uiColor: Palette.goldDeep))
                        .frame(width: 216 * progress, height: 10)
                        .padding(.leading, 2)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { logoIn = true }
            withAnimation(.easeInOut(duration: 1.4)) { progress = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { onDone() }
        }
    }
}
