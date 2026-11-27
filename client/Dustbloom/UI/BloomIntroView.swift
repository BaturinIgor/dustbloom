import SwiftUI

/// Bloom loading screen (art/bloom/brand.py). The background is one pixel-art
/// picture; the logo, hero, helper, petals and the vine progress bar live on top.
/// Tap anywhere once the islands are ready; it also moves on by itself.
struct BloomIntroView: View {
    var ready: Bool
    var onDone: () -> Void

    @State private var start = Date()
    @State private var logoIn = false
    @State private var finished = false
    private let artW: CGFloat = 66, artH: CGFloat = 142
    private let minTime: TimeInterval = 2.2
    private let autoGo: TimeInterval = 2.5
    private let tips = [tr("Острова просыпаются…"), tr("Бей по камням в ритм: комбо даёт больше"),
                        tr("Золотой час удваивает всю добычу"), tr("Блумлинги помогают добывать")]

    var body: some View {
        GeometryReader { geo in
            // one art pixel in points: fill the screen, crop the extra sky/sea
            let k = max(geo.size.width / artW, geo.size.height / artH)
            let ox = (geo.size.width - artW * k) / 2, oy = (geo.size.height - artH * k) / 2
            let at = { (x: CGFloat, y: CGFloat) in CGPoint(x: ox + x * k, y: oy + y * k) }
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSince(start)
                let progress = min(1, t / minTime) * (ready ? 1 : 0.85)
                let done = ready && t >= minTime
                ZStack {
                    pixel("bloom_splash_bg", artW * k, artH * k)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    petals(t: t, size: geo.size, k: k)
                    // helper and hero bob on the island (art feet line y = 90)
                    // sprite centres in art pixels (top-left + half size, see brand.py)
                    pixel("bloom_helper_pink_idle_\(Int(t * 2.2) % 2)", 12 * k, 16 * k)
                        .position(at(49, 85))
                    pixel("bloom_pick_3", 13 * k, 14 * k)
                        .rotationEffect(.degrees(sin(t * 3) * 10), anchor: .bottomLeading)
                        .position(at(42.5, 75))
                    pixel("bloom_hero_happy", 16 * k, 24 * k)
                        .offset(y: CGFloat(Int(t * 2.2) % 2) * k)
                        .position(at(33, 81))
                    // logo drops in and breathes
                    VStack(spacing: 8 + k) {
                        pixel("bloom_logo", 43 * k * 1.15, 31 * k * 1.15)
                            .scaleEffect(logoIn ? 1 + 0.02 * sin(t * 2) : 0.4)
                            .opacity(logoIn ? 1 : 0)
                        OutlinedText(text: tr("Преврати пыль в цветущие острова"), size: 16)
                            .opacity(logoIn ? 1 : 0)
                    }
                    .position(x: geo.size.width / 2, y: geo.safeAreaInsets.top + 20 + 31 * k * 0.6 + 40)
                    VStack(spacing: 14) {
                        if done {
                            // one big, obvious call to action
                            Button { finish() } label: {
                                OutlinedText(text: tr("ИГРАТЬ"), size: 26)
                                    .frame(width: 200, height: 40)
                            }
                            .buttonStyle(BloomButtonStyle(color: BUI.orange, edge: BUI.orangeEdge))
                            .scaleEffect(1 + 0.04 * sin(t * 5))
                            .transition(.scale.combined(with: .opacity))
                        }
                        vine(progress, width: min(300, geo.size.width - 90), t: t)
                        OutlinedText(text: done ? tr("Всё готово!") : "\(tips[Int(t / 2.2) % tips.count])  \(Int(progress * 100))%",
                                     size: 13, color: BUI.cream)
                    }
                    .position(x: geo.size.width / 2, y: geo.size.height - geo.safeAreaInsets.bottom - 110)
                }
            }
        }
        .ignoresSafeArea()
        .background(Color(red: 0.17, green: 0.5, blue: 0.88))
        .contentShape(Rectangle())
        .onTapGesture {
            if ready && Date().timeIntervalSince(start) >= minTime { finish() }
        }
        // moves on by itself: a plain timer, because TimelineView may stop redrawing
        // (and an onChange inside it then never fires) while the scene loads
        .task(id: ready) {
            guard ready else { return }
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "bloomHoldIntro") { return }  // store screenshot of the intro
            #endif
            var wait = max(0, start.addingTimeInterval(minTime + autoGo).timeIntervalSinceNow)
            #if DEBUG
            if UserDefaults.standard.string(forKey: "bloomPanel") != nil { wait = 0 }  // panel layout checks
            #endif
            try? await Task.sleep(for: .seconds(wait))
            if !Task.isCancelled { finish() }
        }
        .onAppear {
            Sfx.prepare()
            start = Date()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.25)) { logoIn = true }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        Sfx.play(.select)
        onDone()
    }

    private func pixel(_ name: String, _ w: CGFloat, _ h: CGFloat) -> some View {
        Image(name).interpolation(.none).resizable().frame(width: w, height: h)
    }

    /// Progress as a growing vine: green fill, leaves along it, a flower at the tip.
    private func vine(_ p: Double, width: CGFloat, t: Double) -> some View {
        let fill = max(18, width * p)
        return ZStack(alignment: .leading) {
            Capsule().fill(BUI.ink).frame(width: width + 8, height: 26)
            Capsule().fill(Color(red: 0.23, green: 0.18, blue: 0.36)).frame(width: width, height: 18).padding(.leading, 4)
            Capsule().fill(Color(red: 0.30, green: 0.75, blue: 0.33)).frame(width: fill, height: 18).padding(.leading, 4)
            Capsule().fill(Color(red: 0.5, green: 0.86, blue: 0.37)).frame(width: max(6, fill - 10), height: 4)
                .padding(.leading, 9).offset(y: -4)
            ForEach(Array(stride(from: 24.0, to: Double(fill) - 12, by: 34)), id: \.self) { x in
                Ellipse().fill(Color(red: 0.5, green: 0.86, blue: 0.37))
                    .overlay(Ellipse().stroke(BUI.ink, lineWidth: 2))
                    .frame(width: 13, height: 8)
                    .offset(x: x, y: -12)
            }
            Image("bloom_flower_pink").interpolation(.none).resizable()
                .frame(width: 20, height: 28)
                .rotationEffect(.degrees(sin(t * 4) * 10))
                .offset(x: fill - 8, y: -6)
        }
        .frame(width: width + 8, alignment: .leading)
    }

    /// A few petals drifting down across the screen.
    private func petals(t: Double, size: CGSize, k: CGFloat) -> some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                let speed = 22 + Double(i % 4) * 7
                let y = (t * speed + Double(i) * 97).truncatingRemainder(dividingBy: Double(size.height) + 40) - 20
                let x = Double(i) * Double(size.width) / 10 + sin(t * 1.3 + Double(i)) * 18
                Image(i % 3 == 0 ? "bloom_fx_leaf" : "bloom_fx_petal").interpolation(.none).resizable()
                    .frame(width: 4 * k * 0.6, height: 3 * k * 0.6)
                    .rotationEffect(.degrees(t * 90 + Double(i) * 40))
                    .position(x: x, y: y)
            }
        }
        .allowsHitTesting(false)
    }
}
