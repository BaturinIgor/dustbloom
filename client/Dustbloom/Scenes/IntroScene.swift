import SpriteKit
import UIKit

/// Animated splash in the app icon's style. The sunset rises, mesas and hills
/// slide in with parallax, the pumpkin scarecrow rises from the wheat and its
/// eyes light up, then the logo drops in with a shine. Finishes once the
/// animation has played and the farm is ready; a tap skips the wait.
@MainActor
final class IntroScene: SKScene {
    /// Art size of the layers (art/hd/intro.py): 130 x 282 px.
    private let artW: CGFloat = 130
    private let artH: CGFloat = 282
    private let horizon: CGFloat = 176
    private var px: CGFloat = 3

    var isReady: () -> Bool = { true }
    var onDone: () -> Void = {}

    private var started = false
    private var logoLanded = false
    private var finished = false
    private var startTime: TimeInterval?
    private let minDuration: TimeInterval = 3.0
    private let bar = SKSpriteNode(color: UIColor(hex: 0xFFCE50), size: .zero)
    private let barBack = SKSpriteNode(color: UIColor(hex: 0x1A0F28), size: .zero)

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(hex: 0x2C1E4A)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func didMove(to view: SKView) {
        guard !started, size.width > 0 else { return }
        started = true
        Sfx.prepare()
        build()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if started == false, view != nil, size.width > 0 {
            started = true
            Sfx.prepare()
            build()
        }
    }

    // MARK: - layout helpers

    private func tex(_ name: String, smooth: Bool = false) -> SKTexture {
        let t = SKTexture(imageNamed: name)
        t.filteringMode = smooth ? .linear : .nearest
        return t
    }

    /// Sprite for an art layer, placed by its art position measured from the
    /// bottom of the 130 x 282 canvas (the screen's bottom edge).
    private func layer(_ name: String, x: CGFloat, top: CGFloat, z: CGFloat, smooth: Bool = false) -> SKSpriteNode {
        let t = tex(name, smooth: smooth)
        let n = SKSpriteNode(texture: t, size: CGSize(width: t.size().width * px, height: t.size().height * px))
        n.anchorPoint = CGPoint(x: 0, y: 1)
        n.position = point(x: x, y: top)
        n.zPosition = z
        addChild(n)
        return n
    }

    private func point(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: -size.width / 2 + (x - (artW - size.width / px) / 2) * px, y: -size.height / 2 + (artH - y) * px)
    }

    // MARK: - scene

    private func build() {
        px = max(2, size.width / artW)
        let bottomFill = SKSpriteNode(color: UIColor(hex: 0x3A1C28), size: CGSize(width: size.width, height: size.height))
        bottomFill.position = CGPoint(x: 0, y: -size.height)
        bottomFill.zPosition = -1
        addChild(bottomFill)

        let sky = layer("intro_sky", x: 0, top: 0, z: 0)
        sky.alpha = 0
        sky.run(.fadeIn(withDuration: 0.5))

        // sun and slowly turning rays
        let sunCentre = point(x: artW / 2, y: horizon - 40)
        let rays = SKSpriteNode(texture: tex("intro_rays", smooth: true), size: CGSize(width: 150 * px, height: 150 * px))
        rays.blendMode = .add
        rays.position = CGPoint(x: sunCentre.x, y: sunCentre.y - 30)
        rays.zPosition = 1
        rays.alpha = 0
        addChild(rays)
        rays.run(.group([
            .moveBy(x: 0, y: 30, duration: 1.8),
            .fadeAlpha(to: 0.9, duration: 1.2),
            .repeatForever(.rotate(byAngle: .pi * 2, duration: 40)),
        ]))
        let sun = SKSpriteNode(texture: tex("intro_sun"), size: CGSize(width: 64 * px, height: 64 * px))
        sun.position = CGPoint(x: sunCentre.x, y: sunCentre.y - 30)
        sun.zPosition = 2
        addChild(sun)
        let rise = SKAction.moveBy(x: 0, y: 30, duration: 1.8)
        rise.timingMode = .easeOut
        sun.run(rise)
        sun.run(.repeatForever(.sequence([.scale(to: 1.03, duration: 1.4), .scale(to: 1, duration: 1.4)])))

        // parallax ridges and field slide up from below
        for (name, top, z, delay, drop) in [("intro_mesa", horizon - 34, 3.0, 0.1, 18.0),
                                             ("intro_hills", horizon - 12, 4.0, 0.2, 34.0),
                                             ("intro_field", artH - 64, 6.0, 0.3, 60.0)] {
            let n = layer(name, x: -10, top: top, z: z)
            let final = n.position
            n.position.y -= drop * px / 3
            let move = SKAction.move(to: final, duration: 1.4)
            move.timingMode = .easeOut
            n.run(.sequence([.wait(forDuration: delay), move]))
        }

        // the scarecrow rises from the wheat
        let heroTex = tex("intro_hero")
        let heroScale: CGFloat = 1.35
        let hero = SKSpriteNode(texture: heroTex, size: CGSize(width: heroTex.size().width * px * heroScale,
                                                               height: heroTex.size().height * px * heroScale))
        hero.anchorPoint = CGPoint(x: 0.5, y: 0)
        let heroBase = point(x: artW / 2, y: artH - 18)
        hero.position = CGPoint(x: heroBase.x, y: heroBase.y - hero.size.height)
        hero.zPosition = 5
        addChild(hero)
        let up = SKAction.move(to: heroBase, duration: 0.9)
        up.timingMode = .easeOut
        hero.run(.sequence([.wait(forDuration: 0.6), up,
                            .repeatForever(.sequence([.rotate(toAngle: 0.012, duration: 1.8),
                                                      .rotate(toAngle: -0.012, duration: 1.8)]))]))
        let eyes = SKSpriteNode(texture: tex("intro_hero_eyes"), size: hero.size)
        eyes.anchorPoint = hero.anchorPoint
        eyes.zPosition = 0.1
        eyes.alpha = 0
        eyes.blendMode = .add
        hero.addChild(eyes)
        let halo = SKSpriteNode(texture: tex("intro_sun"), size: CGSize(width: 40 * px, height: 40 * px))
        halo.position = CGPoint(x: 0, y: hero.size.height * 0.62)
        halo.blendMode = .add
        halo.alpha = 0
        halo.zPosition = -0.1
        hero.addChild(halo)
        let ignite = SKAction.run {
            Sfx.play(.levelUp, volume: 0.7)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        eyes.run(.sequence([.wait(forDuration: 1.6), ignite, .fadeAlpha(to: 1, duration: 0.08),
                            .repeatForever(.sequence([.fadeAlpha(to: 0.65, duration: 0.9),
                                                      .fadeAlpha(to: 1, duration: 0.9)]))]))
        halo.run(.sequence([.wait(forDuration: 1.6), .fadeAlpha(to: 0.45, duration: 0.1),
                            .fadeAlpha(to: 0.2, duration: 0.6),
                            .repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.9),
                                                      .fadeAlpha(to: 0.15, duration: 0.9)]))]))

        // swaying stalks in front
        for (i, x) in [6.0, 18.0, 40.0, 92.0, 104.0, 118.0].enumerated() {
            let t = tex("intro_stalk_\(i % 3)")
            let s = SKSpriteNode(texture: t, size: CGSize(width: t.size().width * px, height: t.size().height * px))
            s.anchorPoint = CGPoint(x: 0.5, y: 0)
            s.position = point(x: x + 5, y: artH + 4)
            s.zPosition = 7
            addChild(s)
            let a = 0.05 + Double(i % 3) * 0.015
            let sway = SKAction.sequence([.rotate(toAngle: a, duration: 1.3 + Double(i) * 0.1),
                                          .rotate(toAngle: -a, duration: 1.3 + Double(i) * 0.1)])
            sway.timingMode = .easeInEaseOut
            s.run(.repeatForever(sway))
        }

        // crows crossing the sky, embers rising from the field
        let flap = SKAction.repeatForever(.animate(with: [tex("intro_crow_0"), tex("intro_crow_1")], timePerFrame: 0.18))
        for (i, y) in [70.0, 52.0, 88.0].enumerated() {
            let c = SKSpriteNode(texture: tex("intro_crow_0"), size: CGSize(width: 13 * px, height: 8 * px))
            c.zPosition = 2.5
            addChild(c)
            c.run(flap)
            let from = point(x: -20, y: y)
            let to = point(x: artW + 20, y: y - 14)
            c.position = from
            c.run(.sequence([.wait(forDuration: Double(i) * 2.3 + 0.8),
                             .repeatForever(.sequence([.move(to: to, duration: 9), .move(to: from, duration: 0)]))]))
        }
        run(.repeatForever(.sequence([.run { [weak self] in self?.ember() }, .wait(forDuration: 0.25)])))

        // logo drops in with a bounce and a shine
        let logoTex = tex("logo_wordmark")
        let lw = min(size.width * 0.86, 360)
        let logo = SKSpriteNode(texture: logoTex, size: CGSize(width: lw, height: lw * logoTex.size().height / logoTex.size().width))
        let logoPos = point(x: artW / 2, y: 52)
        logo.position = CGPoint(x: logoPos.x, y: size.height / 2 + logo.size.height)
        logo.zPosition = 10
        addChild(logo)
        let drop = SKAction.move(to: logoPos, duration: 0.35)
        drop.timingMode = .easeIn
        logo.run(.sequence([
            .wait(forDuration: 1.9), drop,
            .run { Sfx.play(.chest, volume: 0.8) },
            .scaleX(to: 1.12, y: 0.86, duration: 0.07), .scaleX(to: 0.96, y: 1.06, duration: 0.09), .scale(to: 1, duration: 0.08),
            .run { [weak self] in self?.logoLanded = true; self?.shine(on: logo) },
            .repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 1.6), .moveBy(x: 0, y: -5, duration: 1.6)])),
        ]))

        // loading bar near the bottom
        let bw = min(size.width * 0.5, 200)
        barBack.size = CGSize(width: bw + 6, height: 12)
        barBack.position = CGPoint(x: 0, y: -size.height / 2 + 64)
        barBack.zPosition = 20
        addChild(barBack)
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        bar.size = CGSize(width: 0, height: 6)
        bar.position = CGPoint(x: -bw / 2, y: 0)
        barBack.addChild(bar)
    }

    private func ember() {
        let e = SKSpriteNode(texture: Textures.named("fx_firefly"), size: CGSize(width: 18, height: 18))
        e.blendMode = .add
        e.position = CGPoint(x: CGFloat.random(in: -size.width / 2...size.width / 2), y: -size.height / 2 + CGFloat.random(in: 40...200))
        e.zPosition = 8
        e.alpha = 0
        addChild(e)
        let life = Double.random(in: 2.5...4)
        e.run(.sequence([
            .group([.moveBy(x: CGFloat.random(in: -30...30), y: CGFloat.random(in: 80...180), duration: life),
                    .sequence([.fadeAlpha(to: 0.9, duration: 0.5), .wait(forDuration: life - 1.2), .fadeOut(withDuration: 0.7)])]),
            .removeFromParent(),
        ]))
    }

    /// A white band sweeps across the logo, clipped to the logo's shape.
    private func shine(on logo: SKSpriteNode) {
        let crop = SKCropNode()
        let mask = SKSpriteNode(texture: logo.texture, size: logo.size)
        crop.maskNode = mask
        crop.zPosition = 0.1
        let band = SKSpriteNode(color: .white, size: CGSize(width: 26, height: logo.size.height * 2))
        band.zRotation = 0.5
        band.alpha = 0.55
        band.blendMode = .add
        band.position = CGPoint(x: -logo.size.width, y: 0)
        crop.addChild(band)
        logo.addChild(crop)
        band.run(.repeatForever(.sequence([
            .move(to: CGPoint(x: logo.size.width, y: 0), duration: 0.7),
            .wait(forDuration: 2.2),
            .move(to: CGPoint(x: -logo.size.width, y: 0), duration: 0),
        ])))
    }

    override func update(_ currentTime: TimeInterval) {
        guard started, !finished else { return }
        if startTime == nil { startTime = currentTime }
        let t = currentTime - (startTime ?? currentTime)
        let ready = isReady()
        // the bar follows time, and waits at 90% until the farm is loaded
        let target = ready ? min(1, t / minDuration) : min(0.9, t / minDuration)
        let bw = barBack.size.width - 6
        bar.size.width = max(bar.size.width, bw * CGFloat(target))
        if ready && t >= minDuration { finish() }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if logoLanded && isReady() { finish() }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onDone()
    }
}
