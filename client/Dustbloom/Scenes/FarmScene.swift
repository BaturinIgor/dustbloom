import SpriteKit
import UIKit

/// The farm: pixel tiles you can pan, pinch-zoom and tap, with buildings,
/// evening light and ambient life around them.
@MainActor
final class FarmScene: SKScene {
    weak var store: FarmStore? {
        didSet { if store != nil, didBuild == false, view != nil { build() } }
    }

    /// Size of one 16 px tile on screen, in points (16 px x 3).
    let tileSize: CGFloat = 48
    /// One art pixel in points.
    let px: CGFloat = 3
    /// Decorative wasteland drawn beyond the farm edge, in tiles.
    private let pad = 6

    let world = SKNode()
    private let cam = SKCameraNode()
    private var layout: FarmLayout?
    private var groundNodes: [SKSpriteNode] = []
    private var cropNodes: [SKSpriteNode] = []
    private var cropStages: [Int] = []
    private var groundNames: [String] = []
    private var props: [Int: SKSpriteNode] = [:]
    private var didBuild = false
    private var lastRefresh: TimeInterval = 0
    private let light: SKSpriteNode
    private let vignette: SKSpriteNode

    private var touchStart: CGPoint?
    private var panned = false
    private var pinch: UIPinchGestureRecognizer?

    private let lightTap = UIImpactFeedbackGenerator(style: .light)
    private let heavyTap = UIImpactFeedbackGenerator(style: .medium)
    private let warning = UINotificationFeedbackGenerator()

    // MARK: - lifecycle

    override init(size: CGSize) {
        light = SKSpriteNode(texture: Textures.smooth("fx_light"))
        vignette = SKSpriteNode(texture: Textures.smooth("fx_vignette"))
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = Palette.dustDeep
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func didMove(to view: SKView) {
        if camera == nil {
            addChild(world)
            addChild(cam)
            camera = cam
            cam.setScale(0.9)
            // evening light and vignette ride on the camera, above the world
            light.blendMode = .add
            light.alpha = 0.55
            light.zPosition = 900
            vignette.zPosition = 901
            cam.addChild(light)
            cam.addChild(vignette)
            layoutOverlays()
        }
        let p = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(p)
        pinch = p
        if store != nil, !didBuild { build() }
    }

    override func willMove(from view: SKView) {
        if let pinch { view.removeGestureRecognizer(pinch) }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutOverlays()
    }

    private func layoutOverlays() {
        light.size = size
        vignette.size = size
    }

    // MARK: - building

    /// Centre of tile (x, y) in world coordinates. Works outside the farm too.
    func position(x: Int, y: Int, farm: Farm) -> CGPoint {
        CGPoint(
            x: (CGFloat(x) + 0.5 - CGFloat(farm.width) / 2) * tileSize,
            y: (CGFloat(farm.height) / 2 - CGFloat(y) - 0.5) * tileSize
        )
    }

    /// Things lower on screen draw in front.
    func depth(row: Int) -> CGFloat { 1 + CGFloat(row + pad) * 0.01 }

    private func build() {
        guard let store else { return }
        didBuild = true
        let farm = store.farm
        let layout = FarmLayout(config: store.config)
        self.layout = layout
        world.removeAllChildren()
        groundNodes = []
        cropNodes = []
        cropStages = []
        groundNames = []
        props = [:]

        // decorative wasteland around the farm (not interactive)
        for y in -pad..<(farm.height + pad) {
            for x in -pad..<(farm.width + pad) where x < 0 || y < 0 || x >= farm.width || y >= farm.height {
                let n = SKSpriteNode(texture: Textures.named(layout.groundName(farm, x: x, y: y)),
                                     size: CGSize(width: tileSize, height: tileSize))
                n.position = position(x: x, y: y, farm: farm)
                world.addChild(n)
            }
        }
        for y in 0..<farm.height {
            for x in 0..<farm.width {
                let ground = SKSpriteNode(texture: nil, size: CGSize(width: tileSize, height: tileSize))
                ground.position = position(x: x, y: y, farm: farm)
                world.addChild(ground)
                groundNodes.append(ground)

                // crop sprites are 16x24 px: taller than a tile, base on the bed
                let crop = SKSpriteNode(texture: nil, size: CGSize(width: tileSize, height: tileSize * 1.5))
                crop.anchorPoint = CGPoint(x: 0.5, y: 0)
                crop.position = CGPoint(x: 0, y: -tileSize / 2)
                crop.zPosition = depth(row: y)
                crop.isHidden = true
                ground.addChild(crop)
                cropNodes.append(crop)
                cropStages.append(-1)
                groundNames.append("")
            }
        }
        placePieces(layout: layout, farm: farm)
        placeWildProps(farm: farm, start: store.config.farm.startTilled)
        startAmbience(layout: layout)
        if store.isDemo { startDemo(layout: layout) }
        let s = store.config.farm.startTilled
        cam.position = position(x: s.x + 2, y: s.y, farm: farm)
        refreshAll(animated: false)
    }

    /// Adds a sprite standing on the bottom-centre of its footprint, with its
    /// baked evening shadow underneath.
    @discardableResult
    func stand(_ name: String, x: Int, y: Int, w: Int, h: Int, farm: Farm, shadow: String? = nil) -> SKSpriteNode {
        let tex = Textures.named(name)
        let node = SKSpriteNode(texture: tex, size: CGSize(width: tex.size().width * px, height: tex.size().height * px))
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        let left = position(x: x, y: y + h - 1, farm: farm).x - tileSize / 2
        let bottom = position(x: x, y: y + h - 1, farm: farm).y - tileSize / 2
        node.position = CGPoint(x: left + CGFloat(w) * tileSize / 2, y: bottom)
        node.zPosition = depth(row: y + h - 1)
        world.addChild(node)
        if let shadow {
            let st = Textures.named(shadow)
            let s = SKSpriteNode(texture: st, size: CGSize(width: st.size().width * px, height: st.size().height * px))
            s.anchorPoint = .zero
            s.position = CGPoint(x: node.position.x - node.size.width / 2, y: bottom)
            s.zPosition = 0.5
            world.addChild(s)
        }
        return node
    }

    private func placePieces(layout: FarmLayout, farm: Farm) {
        for piece in layout.pieces {
            switch piece.sprite {
            case "prop_house":
                let house = stand("prop_house", x: piece.x, y: piece.y, w: piece.width, h: piece.height,
                                  farm: farm, shadow: "shadow_house")
                chimneySmoke(on: house)
            case "prop_windmill":
                let mill = stand("prop_windmill", x: piece.x, y: piece.y, w: piece.width, h: piece.height,
                                 farm: farm, shadow: "shadow_windmill")
                let sails = SKSpriteNode(texture: Textures.named("prop_windmill_sails"),
                                         size: CGSize(width: 40 * px, height: 40 * px))
                // hub sits 8 px below the top of the 48 px tower sprite
                sails.position = CGPoint(x: 0, y: (48 - 8) * px)
                sails.zPosition = 0.001
                mill.addChild(sails)
                sails.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 9)))
            case "prop_pond":
                let pond = stand("prop_pond_0", x: piece.x, y: piece.y, w: piece.width, h: piece.height, farm: farm)
                pond.zPosition = 0.4
                pond.run(.repeatForever(.animate(with: [Textures.named("prop_pond_0"), Textures.named("prop_pond_1")],
                                                 timePerFrame: 0.7)))
            case "prop_scarecrow":
                let s = stand("prop_scarecrow", x: piece.x, y: piece.y, w: 1, h: 2, farm: farm, shadow: "shadow_scarecrow")
                let lean = SKAction.sequence([.rotate(toAngle: 0.03, duration: 1.6), .rotate(toAngle: -0.03, duration: 1.6)])
                lean.timingMode = .easeInEaseOut
                s.run(.repeatForever(lean))
            case "prop_stones":
                stand("prop_stones", x: piece.x, y: piece.y, w: 1, h: 1, farm: farm).zPosition = 0.3
            default:
                stand(piece.sprite, x: piece.x, y: piece.y, w: piece.width, h: piece.height, farm: farm)
            }
        }
    }

    /// Rocks and dead trees in the wasteland. They fade once life reaches them.
    private func placeWildProps(farm: Farm, start: GameConfig.Area) {
        for y in -pad..<(farm.height + pad) {
            for x in -pad..<(farm.width + pad) {
                let dx = max(start.x - x, 0, x - (start.x + start.width - 1))
                let dy = max(start.y - y, 0, y - (start.y + start.height - 1))
                guard max(dx, dy) >= 5 else { continue }
                let h = abs(x &* 31 &+ y &* 17) % 23
                let node: SKSpriteNode
                if h == 0 {
                    node = stand("prop_dead_tree", x: x, y: y - 1, w: 1, h: 2, farm: farm, shadow: "shadow_dead_tree")
                } else if h == 7 || h == 15 {
                    node = stand("prop_rock", x: x, y: y, w: 1, h: 1, farm: farm, shadow: "shadow_rock")
                } else {
                    continue
                }
                if let i = farm.index(x: x, y: y) { props[i] = node }
            }
        }
    }

    private func refreshAll(animated: Bool) {
        guard let store else { return }
        let farm = store.farm
        for y in 0..<farm.height {
            for x in 0..<farm.width {
                refreshTile(x: x, y: y, animated: animated)
            }
        }
    }

    private func refreshTile(x: Int, y: Int, animated: Bool) {
        guard let store, let layout, let i = store.farm.index(x: x, y: y) else { return }
        let tile = store.farm.tiles[i]
        let name = layout.groundName(store.farm, x: x, y: y)
        if groundNames[i] != name {
            groundNames[i] = name
            groundNodes[i].texture = Textures.named(name)
            if let prop = props[i] {
                let alive = !name.hasPrefix("tile_dust")
                prop.run(.fadeAlpha(to: alive ? 0 : 1, duration: animated ? 0.4 : 0))
            }
        }

        let node = cropNodes[i]
        guard let id = tile.crop, let p = store.progress(of: tile) else {
            if cropStages[i] != -1 {
                node.texture = nil
                node.isHidden = true
                node.removeAllChildren()
                node.removeAllActions()
                node.zRotation = 0
                cropStages[i] = -1
            }
            return
        }
        let stage = Farm.stage(progress: p)
        guard stage != cropStages[i] else { return }
        cropStages[i] = stage
        node.texture = Textures.named("\(id)_\(stage)")
        node.isHidden = false
        node.removeAllActions()
        node.zRotation = 0
        node.setScale(1)

        if animated {
            // growth "pop": squash then settle
            node.run(.sequence([
                .scaleX(to: 1.15, y: 0.85, duration: 0.07),
                .scaleX(to: 0.95, y: 1.1, duration: 0.08),
                .scale(to: 1, duration: 0.08),
            ]))
        }
        if stage >= 1 {
            // gentle wind sway, desynchronised per tile
            let angle = stage == 3 ? 0.06 : 0.04
            let sway = SKAction.sequence([
                .rotate(toAngle: angle, duration: 1.1, shortestUnitArc: true),
                .rotate(toAngle: -angle, duration: 1.1, shortestUnitArc: true),
            ])
            sway.timingMode = .easeInEaseOut
            node.run(.sequence([.wait(forDuration: Double((x * 3 + y * 5) % 10) / 10), .repeatForever(sway)]))
        }
        if stage == 3 {
            node.run(.repeatForever(.sequence([
                .wait(forDuration: 1.5 + Double((x + y) % 4) * 0.4),
                .run { [weak self, weak node] in
                    guard let self, let node else { return }
                    self.sparkle(on: node)
                },
            ])), withKey: "sparkle")
        }
    }

    // MARK: - frame loop

    override func update(_ currentTime: TimeInterval) {
        guard didBuild, currentTime - lastRefresh > 0.25 else { return }
        lastRefresh = currentTime
        refreshAll(animated: true)
    }

    // MARK: - input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        touchStart = t.location(in: view)
        panned = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let start = touchStart, (pinch?.state ?? .possible) == .possible else { return }
        let now = t.location(in: view)
        let prev = t.previousLocation(in: view)
        if hypot(now.x - start.x, now.y - start.y) > 8 { panned = true }
        guard panned else { return }
        // view y grows downwards, scene y upwards
        cam.position.x -= (now.x - prev.x) * cam.xScale
        cam.position.y += (now.y - prev.y) * cam.yScale
        clampCamera()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { touchStart = nil }
        guard !panned, let t = touches.first, let store else { return }
        let p = t.location(in: world)
        let farm = store.farm
        let x = Int(floor(p.x / tileSize + CGFloat(farm.width) / 2))
        let y = Int(floor(CGFloat(farm.height) / 2 - p.y / tileSize))
        guard farm.index(x: x, y: y) != nil else { return }
        if layout?.isBlocked(x: x, y: y) == true {
            lightTap.impactOccurred(intensity: 0.4)
            return
        }
        handleTap(x: x, y: y)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        guard g.state == .changed else { return }
        let next = cam.xScale / g.scale
        cam.setScale(min(max(next, 0.45), 1.6))
        g.scale = 1
        panned = true
        clampCamera()
    }

    private func clampCamera() {
        guard let store else { return }
        let halfW = CGFloat(store.farm.width) * tileSize / 2
        let halfH = CGFloat(store.farm.height) * tileSize / 2
        cam.position.x = min(max(cam.position.x, -halfW), halfW)
        cam.position.y = min(max(cam.position.y, -halfH), halfH)
    }

    // MARK: - actions & juice

    func handleTap(x: Int, y: Int) {
        guard let store, let i = store.farm.index(x: x, y: y) else { return }
        let outcome = store.tap(x: x, y: y)
        let ground = groundNodes[i]
        switch outcome {
        case .tilled:
            lightTap.impactOccurred()
            refreshAll(animated: true)  // grass spreads around the new bed
            dustPuff(at: ground.position)
            ground.run(.sequence([.scale(to: 1.08, duration: 0.06), .scale(to: 1, duration: 0.1)]))
        case .planted:
            lightTap.impactOccurred(intensity: 0.7)
            refreshTile(x: x, y: y, animated: true)
        case .harvested(let result):
            heavyTap.impactOccurred()
            harvestBurst(from: cropNodes[i], result: result)
            refreshTile(x: x, y: y, animated: false)
        case .failed:
            warning.notificationOccurred(.warning)
            ground.run(.sequence([
                .moveBy(x: 4, y: 0, duration: 0.04), .moveBy(x: -8, y: 0, duration: 0.06),
                .moveBy(x: 4, y: 0, duration: 0.04),
            ]))
        case .nothing:
            break
        }
        cursor(at: ground.position)
    }

    private func cursor(at p: CGPoint) {
        world.childNode(withName: "cursor")?.removeFromParent()
        let c = SKSpriteNode(texture: Textures.named("ui_cursor"), size: CGSize(width: tileSize, height: tileSize))
        c.name = "cursor"
        c.position = p
        c.zPosition = 50
        c.setScale(1.25)
        world.addChild(c)
        c.run(.sequence([.scale(to: 1, duration: 0.12), .wait(forDuration: 0.6), .fadeOut(withDuration: 0.25), .removeFromParent()]))
    }

    private func dustPuff(at p: CGPoint) {
        for k in 0..<6 {
            let d = SKSpriteNode(color: Palette.dustLight, size: CGSize(width: 6, height: 6))
            d.position = p
            d.zPosition = 40
            world.addChild(d)
            let a = CGFloat(k) / 6 * .pi * 2
            d.run(.sequence([
                .group([.moveBy(x: cos(a) * 26, y: sin(a) * 18 + 8, duration: 0.35), .fadeOut(withDuration: 0.35)]),
                .removeFromParent(),
            ]))
        }
    }

    private func sparkle(on node: SKSpriteNode) {
        let s = SKSpriteNode(texture: Textures.named("fx_sparkle"), size: CGSize(width: 24, height: 24))
        s.position = CGPoint(x: CGFloat.random(in: -14...14), y: CGFloat.random(in: 30...60))
        s.zPosition = 0.01
        s.setScale(0.2)
        node.addChild(s)
        s.run(.sequence([.scale(to: 1, duration: 0.15), .scale(to: 0.2, duration: 0.25), .removeFromParent()]))
    }

    /// The ripe crop jumps out, coins fly up and the gain floats away.
    private func harvestBurst(from node: SKSpriteNode, result: HarvestResult) {
        guard let parent = node.parent, let tex = node.texture else { return }
        let ghost = SKSpriteNode(texture: tex, size: node.size)
        ghost.anchorPoint = node.anchorPoint
        ghost.position = parent.convert(node.position, to: world)
        ghost.zPosition = 60
        world.addChild(ghost)
        let jump = SKAction.moveBy(x: 0, y: 40, duration: 0.18)
        jump.timingMode = .easeOut
        ghost.run(.sequence([
            .group([jump, .sequence([.scaleX(to: 0.8, y: 1.25, duration: 0.09), .scale(to: 1.2, duration: 0.09)])]),
            .group([.scale(to: 0.2, duration: 0.2), .fadeOut(withDuration: 0.2)]),
            .removeFromParent(),
        ]))

        let origin = ghost.position
        for k in 0..<min(result.coins, 8) {
            let c = SKSpriteNode(texture: Textures.named("ui_coin"), size: CGSize(width: 24, height: 24))
            c.position = CGPoint(x: origin.x, y: origin.y + 20)
            c.zPosition = 61
            world.addChild(c)
            let dx = CGFloat.random(in: -40...40)
            let up = SKAction.moveBy(x: dx, y: CGFloat.random(in: 40...70), duration: 0.25)
            up.timingMode = .easeOut
            let away = SKAction.moveBy(x: dx * 0.3, y: 400, duration: 0.45)
            away.timingMode = .easeIn
            c.run(.sequence([.wait(forDuration: Double(k) * 0.03), up, .group([away, .fadeOut(withDuration: 0.45)]), .removeFromParent()]))
        }

        let label = PixelLabel.make("+\(result.coins)", gold: true, scale: 3)
        label.position = CGPoint(x: origin.x, y: origin.y + 64)
        label.zPosition = 62
        world.addChild(label)
        label.setScale(0.4)
        label.run(.sequence([
            .scale(to: 1, duration: 0.12),
            .group([.moveBy(x: 0, y: 34, duration: 0.8), .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.4)])]),
            .removeFromParent(),
        ]))
    }
}

/// Numbers drawn with the game's pixel font sprites (font_0 ... font_9, font_plus, font_L, font_V).
enum PixelLabel {
    static func glyphName(_ ch: Character, gold: Bool) -> String? {
        let key: String
        switch ch {
        case "+": key = "plus"
        case "0"..."9", "L", "V": key = String(ch)
        default: return nil
        }
        return (gold ? "font_gold_" : "font_") + key
    }

    @MainActor
    static func make(_ text: String, gold: Bool, scale: CGFloat) -> SKNode {
        let node = SKNode()
        let names = text.compactMap { glyphName($0, gold: gold) }
        let step = 6 * scale  // 7 px glyphs share one column
        var x = -CGFloat(names.count - 1) * step / 2
        for name in names {
            let g = SKSpriteNode(texture: Textures.named(name), size: CGSize(width: 7 * scale, height: 10 * scale))
            g.position = CGPoint(x: x, y: 0)
            node.addChild(g)
            x += step
        }
        return node
    }
}

/// Caches textures and keeps pixel art crisp.
@MainActor
enum Textures {
    private static var cache: [String: SKTexture] = [:]

    static func named(_ name: String) -> SKTexture {
        if let t = cache[name] { return t }
        let t = SKTexture(imageNamed: name)
        t.filteringMode = .nearest
        cache[name] = t
        return t
    }

    /// Smooth textures (light, vignette) are scaled with linear filtering.
    static func smooth(_ name: String) -> SKTexture {
        let t = SKTexture(imageNamed: name)
        t.filteringMode = .linear
        return t
    }
}
