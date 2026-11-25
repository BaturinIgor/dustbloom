import SpriteKit
import UIKit

/// The farm: a grid of pixel tiles you can pan, pinch-zoom and tap.
@MainActor
final class FarmScene: SKScene {
    weak var store: FarmStore? {
        didSet { if store != nil, didBuild == false, view != nil { build() } }
    }

    /// Size of one 16 px tile on screen, in points (16 px x 3).
    private let tileSize: CGFloat = 48
    private let world = SKNode()
    private let cam = SKCameraNode()
    private var groundNodes: [SKSpriteNode] = []
    private var cropNodes: [SKSpriteNode] = []
    private var cropStages: [Int] = []
    private var groundNames: [String] = []
    private var props: [Int: SKSpriteNode] = [:]
    private var didBuild = false
    private var lastRefresh: TimeInterval = 0

    private var touchStart: CGPoint?
    private var panned = false
    private var pinch: UIPinchGestureRecognizer?

    private let lightTap = UIImpactFeedbackGenerator(style: .light)
    private let heavyTap = UIImpactFeedbackGenerator(style: .medium)
    private let warning = UINotificationFeedbackGenerator()

    // MARK: - lifecycle

    override init(size: CGSize) {
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
        }
        let p = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(p)
        pinch = p
        if store != nil, !didBuild { build() }
    }

    override func willMove(from view: SKView) {
        if let pinch { view.removeGestureRecognizer(pinch) }
    }

    // MARK: - building

    private func position(x: Int, y: Int, farm: Farm) -> CGPoint {
        CGPoint(
            x: (CGFloat(x) + 0.5 - CGFloat(farm.width) / 2) * tileSize,
            y: (CGFloat(farm.height) / 2 - CGFloat(y) - 0.5) * tileSize
        )
    }

    private func build() {
        guard let store else { return }
        didBuild = true
        world.removeAllChildren()
        groundNodes = []
        cropNodes = []
        cropStages = []
        groundNames = []
        props = [:]
        let farm = store.farm
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
                crop.zPosition = 1
                crop.isHidden = true
                ground.addChild(crop)
                cropNodes.append(crop)
                cropStages.append(-1)
                groundNames.append("")
            }
        }
        placeProps(farm: farm)
        refreshAll(animated: false)
    }

    /// Decorations: a scarecrow guarding the start patch, rocks and dead
    /// trees in the wasteland. A prop hides once life reaches its tile.
    private func placeProps(farm: Farm) {
        guard let start = store?.config.farm.startTilled else { return }
        var spots: [(x: Int, y: Int, name: String, w: CGFloat, h: CGFloat)] = [
            (start.x - 2, start.y + 1, "prop_scarecrow", 1, 2),
        ]
        for y in 0..<farm.height {
            for x in 0..<farm.width {
                let dx = max(start.x - x, 0, x - (start.x + start.width - 1))
                let dy = max(start.y - y, 0, y - (start.y + start.height - 1))
                guard max(dx, dy) >= 4 else { continue }
                let h = (x &* 31 &+ y &* 17) % 23
                if h == 0 { spots.append((x, y, "prop_dead_tree", 2, 2)) }
                else if h == 7 || h == 15 { spots.append((x, y, "prop_rock", 1, 1)) }
            }
        }
        for spot in spots {
            guard let i = farm.index(x: spot.x, y: spot.y) else { continue }
            let node = SKSpriteNode(texture: Textures.named(spot.name),
                                    size: CGSize(width: tileSize * spot.w, height: tileSize * spot.h))
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            let p = position(x: spot.x, y: spot.y, farm: farm)
            node.position = CGPoint(x: p.x, y: p.y - tileSize / 2)
            node.zPosition = 1
            world.addChild(node)
            props[i] = node
        }
    }

    /// Grass grows within 2.3 tiles of any bed (same rule as art/generate_sprites.py).
    private func isGreen(_ farm: Farm, _ x: Int, _ y: Int) -> Bool {
        for yy in max(0, y - 2)...min(farm.height - 1, y + 2) {
            for xx in max(0, x - 2)...min(farm.width - 1, x + 2) where farm.tiles[yy * farm.width + xx].tilled {
                let d = Double((xx - x) * (xx - x) + (yy - y) * (yy - y))
                if d <= 2.3 * 2.3 { return true }
            }
        }
        return false
    }

    private func groundName(x: Int, y: Int, farm: Farm) -> String {
        if farm.tiles[y * farm.width + x].tilled { return "tile_bed" }
        guard isGreen(farm, x, y) else { return "tile_dust_\(abs(x &* 7 &+ y &* 13) % 3)" }
        func g(_ xx: Int, _ yy: Int) -> Bool {
            guard xx >= 0, yy >= 0, xx < farm.width, yy < farm.height else { return true }
            return isGreen(farm, xx, yy)
        }
        let mask = (g(x, y - 1) ? 1 : 0) | (g(x + 1, y) ? 2 : 0) | (g(x, y + 1) ? 4 : 0) | (g(x - 1, y) ? 8 : 0)
        if mask == 15 {
            let v = (x * 5 + y * 3) % 7
            return "tile_grass_\(v == 0 ? 1 : v == 3 ? 2 : 0)"
        }
        return "tile_grass_edge_\(mask)"
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
        guard let store, let i = store.farm.index(x: x, y: y) else { return }
        let tile = store.farm.tiles[i]
        let name = groundName(x: x, y: y, farm: store.farm)
        if groundNames[i] != name {
            groundNames[i] = name
            groundNodes[i].texture = Textures.named(name)
            props[i]?.isHidden = name != "" && !name.hasPrefix("tile_dust")
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

    private func handleTap(x: Int, y: Int) {
        guard let store, let i = store.farm.index(x: x, y: y) else { return }
        let outcome = store.tap(x: x, y: y)
        let ground = groundNodes[i]
        switch outcome {
        case .tilled:
            lightTap.impactOccurred()
            refreshTile(x: x, y: y, animated: true)
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
        c.zPosition = 5
        c.setScale(1.25)
        world.addChild(c)
        c.run(.sequence([.scale(to: 1, duration: 0.12), .wait(forDuration: 0.6), .fadeOut(withDuration: 0.25), .removeFromParent()]))
    }

    private func dustPuff(at p: CGPoint) {
        for k in 0..<6 {
            let d = SKSpriteNode(color: Palette.dustLight, size: CGSize(width: 6, height: 6))
            d.position = p
            d.zPosition = 4
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
        s.position = CGPoint(x: CGFloat.random(in: -14...14), y: CGFloat.random(in: 22...40))
        s.zPosition = 2
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
        ghost.zPosition = 6
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
            c.zPosition = 7
            world.addChild(c)
            let dx = CGFloat.random(in: -40...40)
            let up = SKAction.moveBy(x: dx, y: CGFloat.random(in: 40...70), duration: 0.25)
            up.timingMode = .easeOut
            let away = SKAction.moveBy(x: dx * 0.3, y: 400, duration: 0.45)
            away.timingMode = .easeIn
            c.run(.sequence([.wait(forDuration: Double(k) * 0.03), up, .group([away, .fadeOut(withDuration: 0.45)]), .removeFromParent()]))
        }

        let label = SKLabelNode(text: "+\(result.coins)")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 22
        label.fontColor = Palette.gold
        label.position = CGPoint(x: origin.x, y: origin.y + 56)
        label.zPosition = 8
        world.addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: 34, duration: 0.8), .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.4)])]), .removeFromParent()]))
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
}
