import SpriteKit
import UIKit

/// Draws the Dust Storm battle that `Battle` simulates: the farm at the
/// bottom behind its fence, the wasteland above, enemies walking down three
/// lanes, scarecrows and crops shooting. Everything that appears often
/// (enemies, shots, numbers, sparks, coins) comes from pools, so a busy wave
/// allocates nothing and stays at 60 fps.
@MainActor
final class DefenseScene: SKScene {
    weak var game: DefenseGame?

    /// One art pixel in points for 1x textures (def_, unit_) and @2x ones (crops, tiles).
    private let px1: CGFloat = 1.5
    private let px2: CGFloat = 3
    private let grid = IsoGrid(width: 6, height: 6)
    private let farmOffset = CGPoint(x: 0, y: -330)

    private let world = SKNode()
    private let cam = SKCameraNode()
    private let fx = SKNode()
    private var built = false
    private var lastTime: TimeInterval = 0
    private var hudClock: TimeInterval = 0
    private var coinSoundClock: TimeInterval = 0
    private let logFPS = ProcessInfo.processInfo.arguments.contains("-showFPS")
    private var fpsFrames = 0
    private var fpsTime: TimeInterval = 0

    private func countNodes(_ n: SKNode) -> Int { n.children.reduce(1) { $0 + countNodes($1) } }

    // lanes: start, control, end (at the fence), all in world points
    private var lanes: [(CGPoint, CGPoint, CGPoint)] = []
    private var heroSpots: [CGPoint] = []
    private var cropSpots: [CGPoint] = []
    private var heroNodes: [SKSpriteNode] = []
    private var cropNodes: [SKSpriteNode] = []

    private var enemyNodes: [Int: SKSpriteNode] = [:]
    private var enemyPool: [SKSpriteNode] = []
    private var bossBar: SKNode?
    private var bossFill: SKSpriteNode?
    private var bossId: Int?
    private var shotPool: [SKSpriteNode] = []
    private var numberPool: [SKLabelNode] = []
    private var sparkPool: [SKSpriteNode] = []
    private var coinPool: [SKSpriteNode] = []
    private var poofPool: [SKSpriteNode] = []

    private var walkCache: [String: SKAction] = [:]
    /// Damage numbers are merged per enemy so a crowd of hits stays readable.
    private var pendingDamage: [Int: (sum: Double, last: TimeInterval)] = [:]
    private lazy var sparkAnim = SKAction.animate(with: (0..<3).map { Textures.named("def_hit_\($0)") }, timePerFrame: 0.045)
    private lazy var poofAnim = SKAction.animate(with: (0..<4).map { Textures.named("def_poof_\($0)") }, timePerFrame: 0.07)
    private let flash = SKAction.sequence([
        .colorize(with: .white, colorBlendFactor: 0.85, duration: 0.02),
        .colorize(withColorBlendFactor: 0, duration: 0.09),
    ])
    private let squash = SKAction.sequence([
        .scaleX(to: 1.18, y: 0.84, duration: 0.04),
        .scaleX(to: 0.94, y: 1.06, duration: 0.06),
        .scale(to: 1, duration: 0.06),
    ])
    private var bossTint: SKSpriteNode?
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(hex: 0xA07848)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func didMove(to view: SKView) {
        guard !built else { return }
        built = true
        view.ignoresSiblingOrder = true
        addChild(world)
        addChild(cam)
        camera = cam
        fitCamera()
        world.addChild(fx)
        fx.zPosition = 500
        buildGround()
        buildLanes()
        buildDecor()
        buildSquad()
        buildStorm()
        buildTrails()
        buildAtmosphere()
        warmPools()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        if built { fitCamera() }
    }

    /// The fence corner sits just above the middle of the screen, the storm
    /// enters right under the top HUD, and the field is 440 points wide on
    /// every phone, so sprites keep one size.
    private var camScale: CGFloat { 440 / max(size.width, 1) }
    private var fenceTop: CGPoint { world(grid.center(fx: 0, fy: 0)) }

    private func fitCamera() {
        let k = camScale
        cam.setScale(k)
        cam.position = CGPoint(x: 0, y: fenceTop.y + size.height * k * 0.02)
        if !lanes.isEmpty { layoutLanes() }
    }

    private func world(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + farmOffset.x, y: p.y + farmOffset.y) }

    private func sprite(_ name: String, hd: Bool = false) -> SKSpriteNode {
        let t = Textures.named(name)
        let k = hd ? px2 : px1
        return SKSpriteNode(texture: t, size: CGSize(width: t.size().width * k, height: t.size().height * k))
    }

    // MARK: - ground

    /// Ground is baked once into a single texture: grass farm, beds, dust around.
    private func buildGround() {
        let pad = 14
        let tw: CGFloat = 24, th: CGFloat = 12  // tile art in image points
        let n = grid.width + grid.height + pad * 4
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let size = CGSize(width: CGFloat(n) * tw / 2, height: CGFloat(n) * th / 2)
        let beds: Set<[Int]> = [[2, 2], [1, 3], [3, 1], [3, 3], [2, 4], [4, 2], [1, 4], [4, 1]]
        func inside(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < grid.width && y < grid.height }
        func name(_ x: Int, _ y: Int) -> String {
            if inside(x, y) && beds.contains([x, y]) { return "tile_bed" }
            guard inside(x, y) else { return "tile_dust_\(abs(x &* 7 &+ y &* 13) % 3)" }
            let mask = (inside(x, y - 1) ? 1 : 0) | (inside(x + 1, y) ? 2 : 0)
                | (inside(x, y + 1) ? 4 : 0) | (inside(x - 1, y) ? 8 : 0)
            if mask == 15 { return "tile_grass_\((x * 5 + y * 3) % 7 == 0 ? 1 : 0)" }
            return "tile_grass_edge_\(mask)"
        }
        func center(_ x: Int, _ y: Int) -> CGPoint {
            let i = CGFloat(x + pad), j = CGFloat(y + pad)
            return CGPoint(x: CGFloat(grid.height + pad * 2) * tw / 2 + (i - j) * tw / 2, y: (i + j + 1) * th / 2)
        }
        var cache: [String: UIImage] = [:]
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            ctx.cgContext.interpolationQuality = .none
            UIColor(hex: 0xA07848).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            for s in 0..<(n - 1) {
                for x in -pad..<(grid.width + pad) {
                    let y = s - pad * 2 - x
                    guard y >= -pad && y < grid.height + pad else { continue }
                    let nm = name(x, y)
                    let img = cache[nm] ?? UIImage(named: nm)
                    cache[nm] = img
                    let c = center(x, y)
                    img?.draw(in: CGRect(x: c.x - tw / 2, y: c.y - th / 2, width: tw, height: th))
                }
            }
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        let node = SKSpriteNode(texture: tex, size: CGSize(width: size.width * px2, height: size.height * px2))
        // image tile (0,0) centre -> grid tile (0,0) centre
        let c0 = center(0, 0)
        let imgPoint = CGPoint(x: c0.x * px2, y: -c0.y * px2)  // from the image's top-left, y up
        let target = world(grid.center(x: 0, y: 0))
        node.anchorPoint = CGPoint(x: 0, y: 1)
        node.position = CGPoint(x: target.x - imgPoint.x, y: target.y - imgPoint.y)
        node.zPosition = -10
        world.addChild(node)

        // fence along the two top edges of the farm (the storm side)
        for i in 0..<grid.width {
            let p = world(grid.center(fx: CGFloat(i) + 0.5, fy: 0))
            fencePiece(alongX: true, at: p, z: 1)
        }
        for j in 0..<grid.height {
            let p = world(grid.center(fx: 0, fy: CGFloat(j) + 0.5))
            fencePiece(alongX: false, at: p, z: 1)
        }
        // a little life on the farm
        let house = sprite("prop_house", hd: true)
        house.anchorPoint = CGPoint(x: 0.5, y: 0.1)
        house.setScale(0.8)
        house.position = world(grid.center(fx: 1.0, fy: 5.4))
        house.zPosition = 100 - house.position.y * 0.01
        world.addChild(house)
    }

    private func fencePiece(alongX: Bool, at p: CGPoint, z: CGFloat) {
        let n = sprite(alongX ? "edge_fence_x" : "edge_fence_y", hd: true)
        n.anchorPoint = CGPoint(x: 0.5, y: 0)
        n.position = CGPoint(x: p.x, y: p.y - IsoGrid.tileH / 4)
        n.zPosition = z
        world.addChild(n)
    }

    // MARK: - lanes and squad

    private func buildLanes() {
        layoutLanes()
        // big scarecrows stand in a line right behind the fence, spaced so no one hides anyone
        heroSpots = [
            world(grid.center(fx: 0.6, fy: 0.6)),   // guard: the fence corner, first to meet the storm
            world(grid.center(fx: 2.7, fy: 0.6)),   // archer: right
            world(grid.center(fx: 0.6, fy: 2.7)),   // brute: left
            world(grid.center(fx: 4.6, fy: 0.6)),   // frost: far right
        ]
        cropSpots = [[2, 2], [1, 3], [3, 1], [3, 3]].map { world(grid.center(x: $0[0], y: $0[1])) }
    }

    /// Lanes start just below the top HUD (20% from the top of the screen).
    private func layoutLanes() {
        let top = fenceTop
        let leftEnd = world(grid.center(fx: 0, fy: 2.6))
        let rightEnd = world(grid.center(fx: 2.6, fy: 0))
        let yStart = cam.position.y + size.height * camScale * 0.26
        let mid = (yStart + top.y) / 2
        lanes = [
            (CGPoint(x: -175, y: yStart - 20), CGPoint(x: -190, y: mid), leftEnd),
            (CGPoint(x: 0, y: yStart), CGPoint(x: 24, y: mid + 20), CGPoint(x: top.x, y: top.y + 6)),
            (CGPoint(x: 175, y: yStart - 20), CGPoint(x: 190, y: mid), rightEnd),
        ]
    }

    /// Wasteland clutter (bones, rocks, shrubs, cracks) placed off the lanes,
    /// plus a little farm life; positions are fixed so the scene never jumps.
    private func buildDecor() {
        var rng = SplitMix(seed: 42)
        func rnd() -> Double { rng.next() }
        let top = fenceTop
        let farmCenter = world(grid.center(fx: 3, fy: 3))
        let yMax = (lanes.map { $0.0.y }.max() ?? top.y + 400) - 50  // keep clear of the top HUD
        let props: [(String, Bool)] = [
            ("def_bones", false), ("def_skull", false), ("def_wheel", false), ("def_shrub_0", false),
            ("def_shrub_1", false), ("prop_rock", true), ("prop_stones", true), ("prop_dead_tree", true),
            ("def_shrub_0", false), ("def_bones", false), ("prop_rock", true), ("def_shrub_1", false),
        ]
        func nearLane(_ p: CGPoint, _ r: CGFloat) -> Bool {
            for l in lanes {
                for k in 0...20 where hypot(lanePoint(l, Double(k) / 20).x - p.x, lanePoint(l, Double(k) / 20).y - p.y) < r {
                    return true
                }
            }
            return false
        }
        var placed: [CGPoint] = []
        var i = 0
        var tries = 0
        while i < props.count * 2 && tries < 600 {
            tries += 1
            let p = CGPoint(x: CGFloat(rnd() * 360 - 180), y: top.y + 30 + CGFloat(rnd()) * (yMax - top.y))
            // keep off the lanes, off the farm and away from other props
            let farmDistance = abs(p.x - farmCenter.x) / 216 + abs(p.y - farmCenter.y) / 108
            if nearLane(p, 50) || farmDistance < 1.15 || placed.contains(where: { hypot($0.x - p.x, $0.y - p.y) < 70 }) { continue }
            let (name, hd) = props[i % props.count]
            let n = sprite(name, hd: hd)
            n.anchorPoint = CGPoint(x: 0.5, y: 0.1)
            n.position = p
            n.zPosition = 100 - p.y * 0.01 - 0.5
            n.xScale = rnd() < 0.5 ? -1 : 1
            world.addChild(n)
            placed.append(p)
            i += 1
        }
        // flat cracks anywhere on the dust, under everything
        for k in 0..<10 {
            let c = sprite("def_crack_\(k % 2)")
            c.position = CGPoint(x: CGFloat(rnd() * 440 - 220), y: top.y + 40 + CGFloat(rnd()) * (yMax - top.y))
            c.zPosition = -4
            c.alpha = 0.8
            world.addChild(c)
        }
        // farm life: hay and pumpkins in the back corners of the farm
        for (name, tile) in [("def_hay", (4.6, 1.2)), ("def_pumpkins", (1.2, 4.6)), ("def_hay", (2.6, 4.9))] {
            let n = sprite(name)
            n.anchorPoint = CGPoint(x: 0.5, y: 0.15)
            n.position = world(grid.center(fx: tile.0, fy: tile.1))
            n.zPosition = 100 - n.position.y * 0.01
            world.addChild(n)
        }
    }

    private func lanePoint(_ l: (CGPoint, CGPoint, CGPoint), _ t: Double) -> CGPoint {
        let u = CGFloat(t), v = 1 - u
        return CGPoint(x: v * v * l.0.x + 2 * v * u * l.1.x + u * u * l.2.x,
                       y: v * v * l.0.y + 2 * v * u * l.1.y + u * u * l.2.y)
    }

    private func enemyPoint(_ e: Battle.Enemy) -> CGPoint {
        let l = lanes[e.lane]
        let t = max(0, min(1, e.progress))
        let p = lanePoint(l, t)
        let q = lanePoint(l, min(1, t + 0.01))
        let dx = q.x - p.x, dy = q.y - p.y
        let len = max(0.001, hypot(dx, dy))
        let spread = 30 * CGFloat(1 - t * 0.55)
        return CGPoint(x: p.x - dy / len * CGFloat(e.jitter) * spread, y: p.y + dx / len * CGFloat(e.jitter) * spread)
    }

    private func buildSquad() {
        heroNodes = DefenseContent.heroes.enumerated().map { i, h in
            let n = sprite(h.sprite + "_idle_0")
            n.anchorPoint = CGPoint(x: 0.5, y: 0.06)
            n.position = heroSpots[i]
            n.zPosition = 100 - n.position.y * 0.01
            n.isHidden = true
            world.addChild(n)
            idle(n, hero: i)
            return n
        }
        cropNodes = DefenseContent.crops.enumerated().map { i, c in
            let n = sprite(c.sprite, hd: true)
            n.anchorPoint = CGPoint(x: 0.5, y: 0.1)
            n.position = cropSpots[i]
            n.zPosition = 100 - n.position.y * 0.01
            n.isHidden = true
            world.addChild(n)
            return n
        }
        refreshSquad()
    }

    private func heroFrames(_ i: Int, _ names: [String]) -> [SKTexture] {
        names.map { Textures.named(DefenseContent.heroes[i].sprite + "_" + $0) }
    }

    /// Breathing idle, each hero on its own beat.
    private func idle(_ n: SKSpriteNode, hero i: Int) {
        let a = SKAction.animate(with: heroFrames(i, ["idle_0", "idle_1"]), timePerFrame: 0.45 + Double(i) * 0.04)
        n.run(.repeatForever(a), withKey: "idle")
    }

    /// Wind-up, strike, recover; then back to idle. Ignored while a swing is playing.
    private func attack(_ i: Int) {
        let n = heroNodes[i]
        guard !n.isHidden, n.action(forKey: "attack") == nil else { return }
        n.removeAction(forKey: "idle")
        let melee = DefenseContent.heroes[i].melee
        n.run(.sequence([
            .animate(with: heroFrames(i, ["atk_0"]), timePerFrame: melee ? 0.09 : 0.06),
            .group([
                .animate(with: heroFrames(i, ["atk_1"]), timePerFrame: 0.1),
                .sequence([.scaleX(to: 1.06, y: 0.95, duration: 0.05), .scale(to: 1, duration: 0.08)]),
            ]),
            .animate(with: heroFrames(i, ["atk_2"]), timePerFrame: 0.09),
            .run { [weak self] in self?.idle(n, hero: i) },
        ]), withKey: "attack")
    }

    func refreshSquad() {
        guard let game else { return }
        for (i, n) in heroNodes.enumerated() {
            let show = game.progress.heroLevels[i] > 0
            if show && n.isHidden { appear(n) }
            n.isHidden = !show
        }
        for (i, n) in cropNodes.enumerated() {
            let show = game.progress.cropLevels[i] > 0
            if show && n.isHidden { appear(n) }
            n.isHidden = !show
        }
    }

    private func appear(_ n: SKNode) {
        n.setScale(0.2)
        n.run(.sequence([.scale(to: 1.15, duration: 0.15), .scale(to: 1, duration: 0.1)]))
        spark(at: n.position, big: true)
    }

    // MARK: - storm

    private func buildStorm() {
        let cloud = Textures.smooth("def_cloud")
        for k in 0..<9 {
            let c = SKSpriteNode(texture: cloud)
            let w = CGFloat(260 + (k * 53) % 180)
            c.size = CGSize(width: w, height: w * 0.55)
            c.color = UIColor(hex: 0xC8A070)
            c.colorBlendFactor = 1
            c.alpha = 0.18 + CGFloat(k % 3) * 0.05
            let y = farmOffset.y + 420 + CGFloat(k) * 70
            c.position = CGPoint(x: CGFloat((k * 137) % 700) - 350, y: y)
            c.zPosition = 300
            world.addChild(c)
            let dur = 26.0 + Double(k % 4) * 6
            c.run(.repeatForever(.sequence([
                .moveTo(x: 420, duration: dur * Double(420 - c.position.x) / 840),
                .moveTo(x: -420, duration: 0),
                .moveTo(x: c.position.x, duration: dur * Double(c.position.x + 420) / 840),
            ])))
        }
        // warm haze over the wasteland, fading toward the farm
        let haze = SKSpriteNode(color: UIColor(hex: 0x8A6A4A), size: CGSize(width: 900, height: 700))
        haze.alpha = 0.16
        haze.position = CGPoint(x: 0, y: farmOffset.y + 900)
        haze.zPosition = 290
        world.addChild(haze)
    }

    /// Worn dirt paths under the three lanes, baked at art resolution (1 px = 3 pt)
    /// with speckles, so the field reads as a road the storm keeps walking.
    private func buildTrails() {
        let k: CGFloat = 3
        let top = fenceTop
        let ys = lanes.map { $0.0.y }
        let yTop = (ys.max() ?? top.y + 500) + 40
        let yBot = top.y - 30
        let rect = CGRect(x: -240, y: yBot, width: 480, height: yTop - yBot)
        let px = CGSize(width: rect.width / k, height: rect.height / k)
        func toImg(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - rect.minX) / k, y: (rect.maxY - p.y) / k) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        var rng = SplitMix(seed: 7)
        let image = UIGraphicsImageRenderer(size: px, format: format).image { ctx in
            let g = ctx.cgContext
            g.setShouldAntialias(false)
            g.setLineCap(.round)
            for (width, color) in [(15.0, UIColor(hex: 0x8C6640).withAlphaComponent(0.45)),
                                   (9.0, UIColor(hex: 0x7A5636).withAlphaComponent(0.4))] {
                for l in lanes {
                    g.setStrokeColor(color.cgColor)
                    g.setLineWidth(CGFloat(width))
                    g.move(to: toImg(l.0))
                    g.addQuadCurve(to: toImg(l.2), control: toImg(l.1))
                    g.strokePath()
                }
            }
            // speckles: pebbles and footprints along the paths
            for l in lanes {
                for _ in 0..<70 {
                    let t = rng.next()
                    let p = toImg(lanePoint(l, t))
                    let dx = CGFloat(rng.next() * 16 - 8), dy = CGFloat(rng.next() * 6 - 3)
                    let light = rng.next() < 0.5
                    UIColor(hex: light ? 0xC89A64 : 0x5E4028).withAlphaComponent(0.7).setFill()
                    g.fill(CGRect(x: floor(p.x + dx), y: floor(p.y + dy), width: 1, height: 1))
                }
            }
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        let node = SKSpriteNode(texture: tex, size: rect.size)
        node.position = CGPoint(x: rect.midX, y: rect.midY)
        node.zPosition = -5
        world.addChild(node)
    }

    /// Storm mood: dust grains blowing across, and the top of the screen
    /// darkened in hard pixel bands where the storm comes from.
    private func buildAtmosphere() {
        let grain = SKTexture(image: UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        })
        grain.filteringMode = .nearest
        let e = SKEmitterNode()
        e.particleTexture = grain
        e.particleBirthRate = 14
        e.particleLifetime = 7
        e.particleSize = CGSize(width: 4, height: 4)
        e.particleScaleRange = 0.5
        e.particleColor = UIColor(hex: 0xF0D8A8)
        e.particleColorBlendFactor = 1
        e.particleAlpha = 0.55
        e.particleAlphaRange = 0.3
        e.particleAlphaSpeed = -0.06
        e.particleSpeed = 90
        e.particleSpeedRange = 40
        e.emissionAngle = -.pi * 0.06
        e.emissionAngleRange = 0.15
        e.position = CGPoint(x: -260, y: fenceTop.y + 260)
        e.particlePositionRange = CGVector(dx: 10, dy: 700)
        e.zPosition = 310
        e.targetNode = world
        e.advanceSimulationTime(8)
        world.addChild(e)

        let h = size.height * camScale
        let w = size.width * camScale + 20
        for (k, a) in [0.22, 0.14, 0.07].enumerated() {
            let band = SKSpriteNode(color: UIColor(hex: 0x3A2414), size: CGSize(width: w, height: 18))
            band.alpha = a
            band.anchorPoint = CGPoint(x: 0.5, y: 1)
            band.position = CGPoint(x: 0, y: h / 2 - CGFloat(k) * 18)
            band.zPosition = 700
            cam.addChild(band)
        }
    }

    private func setBossTint(_ on: Bool) {
        if on {
            if bossTint == nil {
                let t = SKSpriteNode(color: UIColor(hex: 0x6A1E1E),
                                     size: CGSize(width: size.width * camScale + 40, height: size.height * camScale + 40))
                t.zPosition = 690
                t.alpha = 0
                cam.addChild(t)
                bossTint = t
            }
            bossTint?.run(.fadeAlpha(to: 0.13, duration: 0.6))
        } else {
            bossTint?.run(.fadeAlpha(to: 0, duration: 0.8))
        }
    }

    // MARK: - pools

    private func warmPools() {
        for _ in 0..<64 { enemyPool.append(makeEnemyNode()) }
        for _ in 0..<56 { shotPool.append(makeSprite(z: 400)) }
        for _ in 0..<40 {
            let l = SKLabelNode(fontNamed: DText.fontName)
            l.fontSize = 26
            l.verticalAlignmentMode = .center
            l.horizontalAlignmentMode = .center
            l.zPosition = 600
            l.isHidden = true
            fx.addChild(l)
            numberPool.append(l)
        }
        for _ in 0..<30 { sparkPool.append(makeSprite(z: 450, blend: .add)) }
        for _ in 0..<32 { coinPool.append(makeSprite(z: 460)) }
        for _ in 0..<32 { poofPool.append(makeSprite(z: 440)) }
    }

    private func makeSprite(z: CGFloat, blend: SKBlendMode = .alpha) -> SKSpriteNode {
        let s = SKSpriteNode()
        s.zPosition = z
        s.blendMode = blend
        s.isHidden = true
        fx.addChild(s)
        return s
    }

    private func makeEnemyNode() -> SKSpriteNode {
        let s = SKSpriteNode()
        s.anchorPoint = CGPoint(x: 0.5, y: 0.12)
        s.isHidden = true
        world.addChild(s)
        return s
    }

    private func walk(_ k: DefenseContent.EnemyKind) -> SKAction {
        if let a = walkCache[k.id] { return a }
        let a = SKAction.repeatForever(.animate(with: (0..<k.frames).map { Textures.named("\(k.sprite)_\($0)") },
                                                timePerFrame: k.frameTime))
        walkCache[k.id] = a
        return a
    }

    // MARK: - frame loop

    override func update(_ currentTime: TimeInterval) {
        guard let game else { return }
        let dt = lastTime == 0 ? 0 : currentTime - lastTime
        lastTime = currentTime
        for e in game.battle.update(dt) { handle(e, game: game) }
        // move live enemies
        for e in game.battle.enemies where e.alive && e.spawned {
            guard let n = enemyNodes[e.id] else { continue }
            let p = enemyPoint(e)
            n.position = p
            n.zPosition = 100 - p.y * 0.01 + (e.kind.flying ? 20 : 0)
            let under = e.kind.burrows && e.progress < 0.5
            n.alpha = under ? 0.35 : 1
            if e.isBoss, let fill = bossFill, let bar = bossBar {
                bar.position = CGPoint(x: p.x, y: p.y - 14)  // under its feet: clear of the HUD and the numbers
                fill.xScale = CGFloat(max(0, e.hp / e.maxHP))
            }
        }
        if logFPS {
            fpsFrames += 1
            fpsTime += dt
            if fpsTime >= 5 {
                print(String(format: "[defense] fps %.1f nodes %d enemies %d", Double(fpsFrames) / fpsTime,
                             countNodes(self), game.battle.aliveCount))
                fpsFrames = 0
                fpsTime = 0
            }
        }
        hudClock += dt
        if hudClock > 0.12 {
            hudClock = 0
            game.syncHUD()
        }
    }

    private func handle(_ e: Battle.Event, game: DefenseGame) {
        switch e {
        case let .waveStart(_, boss):
            for (_, n) in enemyNodes { recycle(n) }
            enemyNodes.removeAll()
            pendingDamage.removeAll()
            bossBar?.removeFromParent()
            bossBar = nil
            bossId = nil
            setBossTint(boss)
            if boss {
                heavy.impactOccurred(intensity: 0.6)
                Sfx.play(.boss, volume: 0.9)
            }
        case let .spawn(id):
            guard let en = game.battle.enemy(id: id) else { return }
            let n = enemyPool.popLast() ?? makeEnemyNode()
            let tex = Textures.named("\(en.kind.sprite)_0")
            let scale = en.isBoss ? px1 * 1.6 : px1 * 1.3 * CGFloat(en.kind.size)
            n.texture = tex
            n.size = CGSize(width: tex.size().width * scale, height: tex.size().height * scale)
            n.colorBlendFactor = 0
            n.alpha = 0
            n.isHidden = false
            n.position = enemyPoint(en)
            n.run(walk(en.kind), withKey: "walk")
            n.run(.fadeIn(withDuration: 0.4))
            enemyNodes[id] = n
            if en.isBoss { attachBossBar(id) }
        case let .shot(from, enemy, projectile, delay):
            if case let .hero(i) = from { attack(i) }
            guard let en = game.battle.enemy(id: enemy), let n = enemyNodes[enemy] else { return }
            fireShot(from: origin(from), to: CGPoint(x: n.position.x, y: n.position.y + n.size.height * 0.4),
                     lead: en, projectile: projectile, delay: delay)
        case let .melee(from):
            if case let .hero(i) = from { attack(i) }
            Sfx.playThrottled(.hit, gap: 0.12, volume: 0.8)
        case let .damage(enemy, amount, crit, delay):
            guard let n = enemyNodes[enemy] else { return }
            run(.wait(forDuration: delay)) { [weak self] in
                guard let self else { return }
                n.run(self.flash)
                if n.action(forKey: "squash") == nil { n.run(self.squash, withKey: "squash") }
                var p = self.pendingDamage[enemy] ?? (0, 0)
                p.sum += amount
                if crit || self.lastTime - p.last > 0.22 {
                    let boss = enemy == self.bossId
                    let wide = n.size.width * (boss ? 0.6 : 0.35)
                    let dx: CGFloat = boss ? (Bool.random() ? 1 : -1) * CGFloat.random(in: wide * 0.6...wide) : .random(in: -wide...wide)
                    self.number(p.sum, crit: crit, at: CGPoint(x: n.position.x + dx,
                                                               y: n.position.y + n.size.height * (boss ? 0.55 : 0.85)))
                    p = (0, self.lastTime)
                }
                self.pendingDamage[enemy] = p
                if crit { self.spark(at: CGPoint(x: n.position.x, y: n.position.y + n.size.height * 0.4), big: false) }
            }
        case let .death(enemy, coins, delay):
            guard let n = enemyNodes[enemy] else { return }
            enemyNodes[enemy] = nil
            game.earned(coins: coins)
            run(.wait(forDuration: delay)) { [weak self] in self?.kill(n, boss: enemy == self?.bossId) }
        case .fenceHit:
            haptic.impactOccurred(intensity: 0.4)
            Sfx.playThrottled(.fence, gap: 0.3, volume: 0.8)
        case let .skill(hero):
            skillFX(hero)
        case .waveCleared:
            Sfx.play(.victory, volume: 0.35)
            game.save()
            refreshSquad()
        case .waveFailed:
            Sfx.play(.defeat, volume: 0.6)
            heavy.impactOccurred()
            shake(12)
            for (_, n) in enemyNodes { kill(n, boss: false) }
            enemyNodes.removeAll()
        }
    }

    private func origin(_ s: Battle.Shooter.Source) -> CGPoint {
        switch s {
        case let .hero(i): return CGPoint(x: heroSpots[i].x - 14, y: heroSpots[i].y + 88)
        case let .crop(i): return CGPoint(x: cropSpots[i].x, y: cropSpots[i].y + 40)
        }
    }

    private func texture(for p: DefenseContent.Projectile) -> String {
        switch p {
        case .arrow: return "def_arrow"
        case .ember: return "def_ember"
        case .frost: return "def_frost"
        case .fluff: return "def_frost"
        case .berry: return "def_ember"
        case .grain: return "def_ember"
        case .none: return "def_ember"
        }
    }

    private func fireShot(from a: CGPoint, to target: CGPoint, lead en: Battle.Enemy,
                          projectile: DefenseContent.Projectile, delay: Double) {
        let s = shotPool.popLast() ?? makeSprite(z: 400)
        Sfx.playThrottled(.shoot, gap: 0.09, volume: 0.6)
        let tex = Textures.named(texture(for: projectile))
        s.texture = tex
        let glowing = projectile != .arrow
        let k: CGFloat = glowing ? px1 * 1.6 : px1 * 1.6
        s.size = CGSize(width: tex.size().width * k, height: tex.size().height * k)
        s.blendMode = glowing ? .add : .alpha
        if glowing {
            s.removeAction(forKey: "spin")
            s.run(.repeatForever(.rotate(byAngle: .pi, duration: 0.25)), withKey: "spin")
        }
        switch projectile {
        case .fluff: s.color = .white; s.colorBlendFactor = 0.9
        case .berry: s.color = UIColor(hex: 0xE0405A); s.colorBlendFactor = 0.7
        case .grain: s.color = UIColor(hex: 0xF0C850); s.colorBlendFactor = 0.8
        default: s.colorBlendFactor = 0
        }
        // aim a little ahead: enemies keep walking while the shot flies
        let b = CGPoint(x: target.x, y: target.y - CGFloat(delay) * 30 * CGFloat(en.kind.speed))
        s.position = a
        s.zRotation = projectile == .arrow ? atan2(b.y - a.y, b.x - a.x) : 0
        s.isHidden = false
        s.alpha = 1
        let arc = projectile == .arrow ? 0 : 40.0
        let path = UIBezierPath()
        path.move(to: a)
        path.addQuadCurve(to: b, controlPoint: CGPoint(x: (a.x + b.x) / 2, y: max(a.y, b.y) + arc))
        s.run(.sequence([
            .follow(path.cgPath, asOffset: false, orientToPath: projectile == .arrow, duration: delay),
            .run { [weak self] in
                s.isHidden = true
                s.removeAllActions()
                self?.shotPool.append(s)
                self?.spark(at: b, big: false)
            },
        ]))
    }

    private func number(_ v: Double, crit: Bool, at p: CGPoint) {
        guard let l = numberPool.popLast() else { return }
        // filled text with a dark stroke reads over any ground
        l.attributedText = NSAttributedString(string: BigNumber.format(v) + (crit ? "!" : ""), attributes: [
            .font: UIFont(name: DText.fontName, size: crit ? 40 : 30) ?? UIFont.systemFont(ofSize: 30),
            .foregroundColor: crit ? UIColor(hex: 0xFFD24A) : UIColor.white,
            .strokeColor: UIColor(hex: 0x2A1A10),
            .strokeWidth: -6,
        ])
        l.position = p
        l.alpha = 1
        l.setScale(crit ? 0.6 : 1)
        l.isHidden = false
        l.run(.sequence([
            .group([
                .moveBy(x: 0, y: 46, duration: 0.6),
                .sequence([.scale(to: crit ? 1.25 : 1, duration: 0.08), .scale(to: 1, duration: 0.1)]),
                .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.25)]),
            ]),
            .run { [weak self] in
                l.isHidden = true
                self?.numberPool.append(l)
            },
        ]))
    }

    private func spark(at p: CGPoint, big: Bool) {
        guard let s = sparkPool.popLast() else { return }
        s.texture = Textures.named("def_hit_0")
        let k: CGFloat = big ? px1 * 3 : px1 * 1.6
        s.size = CGSize(width: 13 * k, height: 13 * k)
        s.position = p
        s.isHidden = false
        s.run(.sequence([sparkAnim, .run { [weak self] in
            s.isHidden = true
            self?.sparkPool.append(s)
        }]))
    }

    private func kill(_ n: SKSpriteNode, boss: Bool) {
        let p = n.position
        Sfx.playThrottled(.poof, gap: 0.08, volume: 0.7)
        recycle(n)
        if let s = poofPool.popLast() {
            s.texture = Textures.named("def_poof_0")
            let k = px1 * (boss ? 4 : 1.6)
            s.size = CGSize(width: 20 * k, height: 20 * k)
            s.position = CGPoint(x: p.x, y: p.y + 10)
            s.isHidden = false
            s.run(.sequence([poofAnim, .run { [weak self] in
                s.isHidden = true
                self?.poofPool.append(s)
            }]))
        }
        flyCoin(from: p)
        if boss {
            setBossTint(false)
            bossBar?.removeFromParent()
            bossBar = nil
            bossId = nil
            shake(10)
            heavy.impactOccurred()
            Sfx.play(.chest, volume: 0.8)
        }
    }

    private func recycle(_ n: SKSpriteNode) {
        n.removeAllActions()
        n.setScale(1)
        n.isHidden = true
        enemyPool.append(n)
    }

    /// A coin hops out and flies to the coin counter (top right of the screen).
    private func flyCoin(from p: CGPoint) {
        guard let c = coinPool.popLast() else { return }
        c.texture = Textures.named("ui_coin")
        c.size = CGSize(width: 26, height: 26)
        c.position = p
        c.isHidden = false
        let target = CGPoint(x: cam.position.x + size.width * cam.xScale * 0.38,
                             y: cam.position.y + size.height * cam.yScale * 0.44)
        let path = UIBezierPath()
        path.move(to: p)
        path.addQuadCurve(to: target, controlPoint: CGPoint(x: p.x + 60, y: p.y + 160))
        c.run(.sequence([
            .moveBy(x: 0, y: 26, duration: 0.12),
            .follow(path.cgPath, asOffset: false, orientToPath: false, duration: 0.55),
            .run { [weak self] in
                c.isHidden = true
                self?.coinPool.append(c)
                guard let self else { return }
                if self.lastTime - self.coinSoundClock > 0.12 {
                    self.coinSoundClock = self.lastTime
                    Sfx.play(.coin, volume: 0.25)
                }
            },
        ]))
    }

    private func attachBossBar(_ id: Int) {
        bossBar?.removeFromParent()
        let bar = SKNode()
        bar.zPosition = 520
        let back = SKSpriteNode(color: UIColor(hex: 0x3A2418), size: CGSize(width: 124, height: 14))
        let fill = SKSpriteNode(color: UIColor(hex: 0xD23A44), size: CGSize(width: 118, height: 8))
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: -59, y: 0)
        bar.addChild(back)
        bar.addChild(fill)
        world.addChild(bar)
        bossBar = bar
        bossFill = fill
        bossId = id
    }

    private func skillFX(_ hero: Int) {
        Sfx.play(.skill, volume: 0.9)
        heavy.impactOccurred(intensity: 0.7)
        let n = heroNodes[hero]
        n.run(.sequence([.scale(to: 1.35, duration: 0.1), .scale(to: 1, duration: 0.2)]))
        spark(at: CGPoint(x: n.position.x, y: n.position.y + 40), big: true)
        let tint: UIColor
        switch DefenseContent.heroes[hero].skill {
        case .wall: tint = UIColor(hex: 0xFFE08A)
        case .arrowRain: tint = UIColor(hex: 0xFFFFFF)
        case .smash: tint = UIColor(hex: 0xFF9A3A); shake(9)
        case .blizzard: tint = UIColor(hex: 0x9AD8FF)
        }
        let f = SKSpriteNode(color: tint, size: CGSize(width: size.width * cam.xScale, height: size.height * cam.yScale))
        f.alpha = 0
        f.zPosition = 800
        f.blendMode = .add
        cam.addChild(f)
        f.run(.sequence([.fadeAlpha(to: 0.28, duration: 0.06), .fadeOut(withDuration: 0.35), .removeFromParent()]))
    }

    private func shake(_ amount: CGFloat) {
        let base = cam.position
        var steps: [SKAction] = []
        for k in 0..<6 {
            let a = amount * CGFloat(6 - k) / 6
            steps.append(.move(to: CGPoint(x: base.x + .random(in: -a...a), y: base.y + .random(in: -a...a)), duration: 0.03))
        }
        steps.append(.move(to: base, duration: 0.03))
        cam.run(.sequence(steps), withKey: "shake")
    }
}
