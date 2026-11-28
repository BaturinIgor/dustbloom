import SpriteKit
import UIKit

/// The Bloom island world: walk with a floating stick, auto-mine the nearest
/// thing, drops fly to the hero, buy dusty islands and watch them bloom.
/// World units are art pixels (y up); the camera zooms 3x so 1 art px = 3 pt.
final class BloomScene: SKScene {
    var game: BloomGame! { didSet { if oldValue == nil, view != nil { setUp() } } }

    private let zoom: CGFloat = 3
    private let T: CGFloat = 16
    private let world = SKNode()
    private let cam = SKCameraNode()
    private var built = false

    // textures
    private var texCache: [String: SKTexture] = [:]
    private func tex(_ n: String) -> SKTexture {
        if let t = texCache[n] { return t }
        let t = SKTexture(imageNamed: n)
        t.filteringMode = .nearest
        texCache[n] = t
        #if DEBUG
        if logFPS && now > 1 { print("[tex] late \(n)") }
        #endif
        return t
    }

    // land
    private var islandNodes: [Int: SKSpriteNode] = [:]
    private var bridgeNodes: [Int: SKSpriteNode] = [:]
    private var signs: [Int: SKNode] = [:]          // bridge index -> sign
    private var land = Set<Cell>()
    private var cellIsland: [Cell: Int] = [:]
    private var bridgeCells = Set<Cell>()
    private var nearBridge = Set<Cell>()            // keep free so paths stay open

    // things
    private final class Res {
        let kind: GatherKind
        let cell: Cell
        let island: Int
        var hp: Int
        let node: SKSpriteNode
        let shadow: SKSpriteNode
        var bar: SKSpriteNode?
        var golden = false
        init(kind: GatherKind, cell: Cell, island: Int, node: SKSpriteNode, shadow: SKSpriteNode) {
            self.kind = kind; self.cell = cell; self.island = island; self.hp = kind.hp; self.node = node; self.shadow = shadow
        }
    }
    private var res: [Cell: Res] = [:]
    private var buildingNodes: [Cell: (PlacedBuilding, SKSpriteNode)] = [:]
    private var flowers: [Cell: SKSpriteNode] = [:]

    private final class DropNode {
        let node: SKSpriteNode
        let item: BItem?
        let amount: Int
        var readyAt: TimeInterval
        var speed: CGFloat = 0
        init(node: SKSpriteNode, item: BItem?, amount: Int, readyAt: TimeInterval) {
            self.node = node; self.item = item; self.amount = amount; self.readyAt = readyAt
        }
    }
    private var drops: [DropNode] = []

    // hero
    private let hero = SKNode()
    private let heroSprite = SKSpriteNode()
    private let pickNode = SKSpriteNode()
    private let heroShadow = SKSpriteNode()
    private var heroPos = CGPoint.zero
    private var facing: CGFloat = 1
    private var animClock: TimeInterval = 0
    private var dustClock: TimeInterval = 0
    private var hitTimer: TimeInterval = 0
    private var chestFreeAt: TimeInterval = 0
    private var swinging = false
    private var comboLabel: SKNode?

    // input
    private var stickTouch: UITouch?
    private var stickOrigin = CGPoint.zero
    private var stickStart: TimeInterval = 0
    private var stickMoved: CGFloat = 0
    private var stickVec = CGVector.zero
    private let stickBase = SKShapeNode(circleOfRadius: 56)
    private let stickKnob = SKShapeNode(circleOfRadius: 26)
    private let stickR: CGFloat = 56

    // timers
    private var last: TimeInterval = 0
    private var now: TimeInterval = 0
    private var spawnTimer: TimeInterval = 0
    private var flowerTimer: TimeInterval = 0
    private var nearbyTimer: TimeInterval = 0
    private var saveTimer: TimeInterval = 0
    private var hitHaptic: TimeInterval = 0
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let demo = ProcessInfo.processInfo.arguments.contains("-bloomDemo")
    private let logFPS = ProcessInfo.processInfo.arguments.contains("-showFPS")
    private var fpsFrames = 0
    private var fpsClock: TimeInterval = 0
    private var fpsWorst: TimeInterval = 0
    private var fpsLong = 0
    private var freeze: TimeInterval = 0       // hit-stop: a few frames of stillness that sell a heavy blow
    private var facingUp = false
    private var vel = CGVector.zero            // hero velocity, eased so starts and stops feel soft

    private func buzz(_ g: UIImpactFeedbackGenerator, _ i: CGFloat = 1) { if Haptics.enabled { g.impactOccurred(intensity: i) } }

    // MARK: - setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0x4f / 255, green: 0xc4 / 255, blue: 0xec / 255, alpha: 1)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        view.ignoresSiblingOrder = true
        view.isMultipleTouchEnabled = false
        if game != nil { setUp() }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Music.resume() }
        }
    }

    private func setUp() {
        guard !built else { return }
        built = true
        let burst = ["bloom_fx_puff", "bloom_fx_leaf", "bloom_fx_chip", "bloom_fx_spark", "bloom_fx_petal", "bloom_item_coin"]
            + BItem.allCases.map(\.sprite) + GatherKind.allCases.flatMap { $0.isTree ? [$0.stump] : [] }
        // everything a gather/break/pickup can show for the first time: a texture is sent to
        // the GPU on its first draw, which stalled the frame where a crack, stump or puff appeared
        let foeTex = ["slime", "beetle", "toad", "bat"].flatMap { ["bloom_foe_\($0)_0", "bloom_foe_\($0)_1"] }
        let fx = ["ash", "bee", "chip", "ember", "firefly", "fly", "leaf", "petal", "puff", "sand", "spark", "spore", "star"].map { "bloom_fx_" + $0 }
        let heroTex = ["idle_0", "idle_1", "run_0", "run_1", "run_2", "run_3", "back_idle_0", "back_run_0", "back_run_1", "back_run_2", "back_run_3"].map { game.heroPrefix + $0 }
        let helperTex = Set(game.helpers + (game.isFounder ? ["gold"] : [])).flatMap { c in
            ["idle_0", "idle_1", "run_0", "run_1"].map { "bloom_helper_\(c)_" + $0 }
        }
        let props = GatherKind.allCases.map(\.sprite) + ["bloom_crack_1", "bloom_crack_2", "bloom_chest_closed", "bloom_chest_open",
                     "bloom_shadow", "bloom_tuft", "bloom_flower_white", "bloom_flower_pink", "bloom_flower_yellow", "bloom_flower_blue"]
            + (0...5).map { "bloom_pick_\($0)" } + BloomAlbum.pages.flatMap { $0.finds.map { "bloom_find_" + $0.id } }
        SKTexture.preload(Array(Set(burst + fx + heroTex + helperTex + props + foeTex)).map(tex)) {}
        warmTextures()
        addChild(world)
        cam.setScale(1 / zoom)
        addChild(cam)
        camera = cam
        Sfx.prepare()

        stickBase.fillColor = UIColor(white: 1, alpha: 0.14)
        stickBase.strokeColor = UIColor(white: 1, alpha: 0.5)
        stickBase.lineWidth = 4
        stickKnob.fillColor = UIColor(white: 1, alpha: 0.75)
        stickKnob.strokeColor = .clear
        stickBase.addChild(stickKnob)
        stickBase.isHidden = true
        stickBase.zPosition = 5000
        cam.addChild(stickBase)

        buildWater()
        buildClouds()
        for isl in game.world.islands {
            for c in isl.cells { cellIsland[Cell(x: c[0], y: c[1])] = isl.id }
            let owned = game.owned.contains(isl.id)
            let n = SKSpriteNode(texture: tex("bloom_isl_\(isl.id)" + (owned ? "" : "_dust")))
            n.anchorPoint = .zero
            n.position = CGPoint(x: isl.origin[0], y: isl.origin[1])
            n.zPosition = -1000
            world.addChild(n)
            islandNodes[isl.id] = n
            let sh = SKSpriteNode(texture: n.texture)
            sh.anchorPoint = .zero
            sh.color = UIColor(red: 0.05, green: 0.25, blue: 0.45, alpha: 1)
            sh.colorBlendFactor = 1
            sh.alpha = 0.22
            sh.position = CGPoint(x: n.position.x + 2, y: n.position.y - 3)
            sh.zPosition = -1050
            world.addChild(sh)
        }
        for (i, b) in game.world.bridges.enumerated() {
            let c = Cell(x: b.tile[0], y: b.tile[1])
            for d in [(-1, 0), (1, 0), (0, -1), (0, 1), (0, 0)] { nearBridge.insert(Cell(x: c.x + d.0, y: c.y + d.1)) }
            if b.vertical {
                for d in [(-1, -1), (1, -1), (-1, 1), (1, 1)] { nearBridge.insert(Cell(x: c.x + d.0, y: c.y + d.1)) }
            }
            refreshBridge(i)
        }
        rebuildLand()
        for b in game.buildings where land.contains(b.cell) { addBuildingNode(b, animated: false) }
        for id in game.owned.sorted() {
            decorate(id)
            fill(id)
        }

        heroShadow.texture = tex("bloom_shadow"); heroShadow.size = heroShadow.texture!.size()
        heroShadow.alpha = 0.9
        heroShadow.position = CGPoint(x: 0, y: 0)
        heroShadow.zPosition = -1300
        hero.addChild(heroShadow)
        heroSprite.texture = tex(game.heroPrefix + "idle_0"); heroSprite.size = heroSprite.texture!.size()
        heroSprite.anchorPoint = CGPoint(x: 0.5, y: 2 / 24)
        hero.addChild(heroSprite)
        pickNode.texture = tex("bloom_pick_\(game.pickTier)"); pickNode.size = pickNode.texture!.size()
        pickNode.anchorPoint = CGPoint(x: 0.5, y: 1 / 14)
        pickNode.position = CGPoint(x: 5, y: 4)
        pickNode.zRotation = -0.5
        pickNode.zPosition = 1
        heroSprite.addChild(pickNode)
        world.addChild(hero)
        heroPos = spawnPoint()
        hero.position = heroPos
        cam.position = heroPos

        game.placeBuilding = { [weak self] k in self?.findBuildCell() }
        game.onBuildingPlaced = { [weak self] b in self?.addBuildingNode(b, animated: true) }
        game.onIslandBought = { [weak self] id in self?.bloom(id) }
        game.onCrafted = { [weak self] k, item, lucky in self?.crafted(k, item, lucky) }
        game.onGoalClaimed = { [weak self] in self?.goalFX() }
        game.onHelperAdded = { [weak self] c in self?.addHelper(c, animated: true) }
        game.onTalentsChanged = { [weak self] in self?.talentsChanged() }
        game.onGoldenRequested = { [weak self] d in self?.startGolden(duration: d) }
        game.onFounder = { [weak self] in self?.addHelper("gold", animated: true) }
        goldenNext = demo ? 20 : GoldenHour.first
        goldOverlay.color = UIColor(red: 1, green: 0.78, blue: 0.3, alpha: 1)
        goldOverlay.size = CGSize(width: 3000, height: 3000)
        goldOverlay.blendMode = .add
        goldOverlay.alpha = 0
        goldOverlay.zPosition = 4000
        cam.addChild(goldOverlay)
        setUpLife()
        for c in game.helpers { addHelper(c, animated: false) }
        if game.isFounder { addHelper("gold", animated: false) }
        if ProcessInfo.processInfo.arguments.contains("-bloomDemo") {
            run(.sequence([.wait(forDuration: 6), .run { [weak self] in self?.spawnChest(near: true) }]))
        }
        #if DEBUG
        // -bloomHappening flock|golden|coins|wind|meteor|treasure: that one, 5 s after start
        if let h = UserDefaults.standard.string(forKey: "bloomHappening") {
            run(.sequence([.wait(forDuration: 5), .run { [weak self] in self?.fireHappening(h) }]))
        }
        // -bloomDig: two dig spots next to the hero right away
        if UserDefaults.standard.object(forKey: "bloomDig") != nil || ProcessInfo.processInfo.arguments.contains("-bloomDig") {
            run(.sequence([.wait(forDuration: 4), .run { [weak self] in self?.spawnDigSpot(near: true); self?.spawnDigSpot(near: true) }]))
        }
        // -bloomHP N: start with N half-hearts, to try hurt and faint
        let startHP = UserDefaults.standard.integer(forKey: "bloomHP")
        if startHP > 0 { game.hp = min(startHP, game.maxHP) }
        // -bloomFoes N [-bloomFoeKind slime|beetle|toad|bat]: N foes near the hero after 3 s
        let nFoes = UserDefaults.standard.integer(forKey: "bloomFoes")
        if nFoes > 0 {
            let k = UserDefaults.standard.string(forKey: "bloomFoeKind")
            run(.sequence([.wait(forDuration: 3), .run { [weak self] in for _ in 0..<nFoes { self?.spawnFoe(kind: k, near: true) } }]))
        }
        // -bloomChests N: several chests at once, to check each one opens
        let nChests = UserDefaults.standard.integer(forKey: "bloomChests")
        if nChests > 0 {
            run(.sequence([.wait(forDuration: 4), .run { [weak self] in for _ in 0..<nChests { self?.spawnChest(near: true) } }]))
        }
        #endif
    }

    private func spawnPoint() -> CGPoint {
        // centre of the start island, nearest free cell
        var start = 0
        #if DEBUG
        // -bloomSpawn 10: start on another owned island (biome checks, screenshots)
        let forced = UserDefaults.standard.integer(forKey: "bloomSpawn")
        if forced > 0, game.owned.contains(forced) { start = forced }
        #endif
        let cs = cells(of: start)
        let cx = CGFloat(cs.map(\.x).reduce(0, +)) / CGFloat(cs.count)
        let cy = CGFloat(cs.map(\.y).reduce(0, +)) / CGFloat(cs.count)
        let best = cs.filter { res[$0] == nil && buildingNodes[$0] == nil }
            .min { hypot(CGFloat($0.x) - cx, CGFloat($0.y) - cy) < hypot(CGFloat($1.x) - cx, CGFloat($1.y) - cy) } ?? cs[0]
        return CGPoint(x: CGFloat(best.x) * T + 8, y: CGFloat(best.y) * T + 6)
    }

    private func buildWater() {
        for _ in 0..<160 {
            let w = CGFloat(Int.random(in: 3...5))
            let n = SKSpriteNode(color: UIColor(red: 0.62, green: 0.9, blue: 0.98, alpha: 1), size: CGSize(width: w, height: 1))
            n.position = CGPoint(x: CGFloat.random(in: -120...600), y: CGFloat.random(in: -120...470)).rounded
            n.zPosition = -1100
            n.alpha = 0
            world.addChild(n)
            let d = Double.random(in: 2.5...4.5)
            n.run(.repeatForever(.sequence([
                .wait(forDuration: Double.random(in: 0...3)),
                .group([.sequence([.fadeAlpha(to: 0.7, duration: d / 2), .fadeAlpha(to: 0, duration: d / 2)]),
                        .moveBy(x: 3, y: 0, duration: d)]),
                .moveBy(x: -3, y: 0, duration: 0),
            ])))
        }
    }

    private func buildClouds() {
        for i in 0..<4 {
            let c = SKSpriteNode(texture: tex("bloom_cloud"))
            c.alpha = 0.09
            c.setScale(CGFloat.random(in: 1.2...1.8))
            c.zPosition = 1950
            let y = CGFloat(-60 + i * 120) + CGFloat.random(in: -20...20)
            let x0 = CGFloat.random(in: -150...550)
            c.position = CGPoint(x: x0, y: y)
            world.addChild(c)
            let speed = CGFloat.random(in: 3...5)
            let first = (650 - x0) / speed
            c.run(.sequence([.moveTo(x: 650, duration: Double(first)), .moveTo(x: -200, duration: 0),
                             .repeatForever(.sequence([.moveTo(x: 650, duration: Double(850 / speed)), .moveTo(x: -200, duration: 0)]))]))
        }
    }

    private func rebuildLand() {
        land.removeAll()
        bridgeCells.removeAll()
        for isl in game.world.islands where game.owned.contains(isl.id) {
            for c in isl.cells { land.insert(Cell(x: c[0], y: c[1])) }
        }
        for b in game.world.bridges where game.owned.contains(b.a) && game.owned.contains(b.b) {
            let c = Cell(x: b.tile[0], y: b.tile[1])
            land.insert(c)
            bridgeCells.insert(c)
        }
    }

    private func refreshBridge(_ i: Int, animated: Bool = false) {
        let b = game.world.bridges[i]
        let oa = game.owned.contains(b.a), ob = game.owned.contains(b.b)
        let c = CGPoint(x: CGFloat(b.tile[0]) * T, y: CGFloat(b.tile[1]) * T)
        if oa && ob {
            if let s = signs[i] { s.removeFromParent(); signs[i] = nil }
            if bridgeNodes[i] == nil {
                let n = SKSpriteNode(texture: tex(b.vertical ? "bloom_bridge_v" : "bloom_bridge_h"))
                n.anchorPoint = .zero
                n.position = b.vertical ? CGPoint(x: c.x, y: c.y - 1) : CGPoint(x: c.x - 1, y: c.y)
                n.zPosition = -990
                world.addChild(n)
                bridgeNodes[i] = n
                if animated {
                    n.setScale(0.2); n.alpha = 0
                    n.run(.group([.fadeIn(withDuration: 0.25), .scale(to: 1, duration: 0.35)]))
                }
            }
        } else if oa != ob {
            guard signs[i] == nil else { return }
            let locked = oa ? b.b : b.a
            let s = SKNode()
            s.position = CGPoint(x: c.x + 8, y: c.y + 2)
            s.zPosition = 900
            let sp = SKSpriteNode(texture: tex("bloom_sign"))
            sp.anchorPoint = CGPoint(x: 0.5, y: 0)
            s.addChild(sp)
            let coin = SKSpriteNode(texture: tex("bloom_item_coin"))
            coin.setScale(0.6)
            coin.position = CGPoint(x: -5, y: 11)
            s.addChild(coin)
            let l = label(game.islandPrice(locked).compact, size: 6, color: UIColor(red: 0.17, green: 0.14, blue: 0.25, alpha: 1), stroke: nil)
            l.horizontalAlignmentMode = .left
            l.verticalAlignmentMode = .center
            l.position = CGPoint(x: -1.5, y: 10.5)
            s.addChild(l)
            s.run(.repeatForever(.sequence([.moveBy(x: 0, y: 1.5, duration: 0.8), .moveBy(x: 0, y: -1.5, duration: 0.8)])))
            world.addChild(s)
            signs[i] = s
        }
    }

    // MARK: - decor & spawning

    private func cells(of id: Int) -> [Cell] { game.island(id).cells.map { Cell(x: $0[0], y: $0[1]) } }

    private func decorate(_ id: Int, delay: Double = 0) {
        var rng = SystemRandomNumberGenerator()
        for c in cells(of: id) {
            for _ in 0..<(Int.random(in: 0...2, using: &rng) == 0 ? 1 : 0) {
                let names = ["bloom_tuft", "bloom_tuft", "bloom_flower_white", "bloom_flower_pink", "bloom_flower_yellow", "bloom_flower_blue"]
                let n = SKSpriteNode(texture: tex(names.randomElement()!))
                n.anchorPoint = CGPoint(x: 0.5, y: 0)
                n.position = CGPoint(x: CGFloat(c.x) * T + CGFloat.random(in: 2...14), y: CGFloat(c.y) * T + CGFloat.random(in: 2...13)).rounded
                n.zPosition = -900
                world.addChild(n)
                if delay > 0 { pop(n, delay: delay + Double.random(in: 0...0.6)) }
                sway(n, phase: CGFloat(c.x) * 0.35 + CGFloat(c.y) * 0.15)
            }
        }
        for _ in 0..<2 { addButterfly(id, delay: delay) }
    }

    private func addButterfly(_ id: Int, delay: Double) {
        let cs = cells(of: id)
        guard let c = cs.randomElement() else { return }
        let n = SKSpriteNode(texture: tex("bloom_fx_fly"))
        n.position = CGPoint(x: CGFloat(c.x) * T + 8, y: CGFloat(c.y) * T + 14)
        n.zPosition = 1900
        n.alpha = 0
        world.addChild(n)
        var steps: [SKAction] = []
        for _ in 0..<8 {
            let t = cs.randomElement()!
            let p = CGPoint(x: CGFloat(t.x) * T + 8, y: CGFloat(t.y) * T + 14)
            steps.append(.move(to: p, duration: Double.random(in: 2.5...4.5)))
        }
        n.run(.sequence([.wait(forDuration: delay), .fadeIn(withDuration: 0.4), .repeatForever(.sequence(steps))]))
        n.run(.repeatForever(.sequence([.scaleX(to: 0.4, duration: 0.12), .scaleX(to: 1, duration: 0.12)])))
    }

    private func freeCell(_ c: Cell) -> Bool {
        res[c] == nil && buildingNodes[c] == nil && flowers[c] == nil && !chests.contains(where: { $0.cell == c }) && !digSpots.contains(where: { $0.cell == c }) && !nearBridge.contains(c) && land.contains(c) && !bridgeCells.contains(c)
    }

    private func randomKind(_ id: Int) -> GatherKind {
        let sp = game.island(id).spawn
        let total = sp.values.reduce(0, +)
        var r = Int.random(in: 0..<max(1, total))
        for (k, n) in sp.sorted(by: { $0.key < $1.key }) {
            if r < n { return GatherKind(rawValue: k) ?? .rock }
            r -= n
        }
        return .rock
    }

    private func fill(_ id: Int, animated: Bool = false, delay: Double = 0) {
        let cap = game.island(id).cap
        var free = cells(of: id).filter(freeCell).shuffled()
        var count = res.values.filter { $0.island == id }.count
        var k = 0
        while count < cap, let c = free.popLast() {
            if heroCell == c { continue }
            spawn(randomKind(id), at: c, island: id, delay: animated ? delay + Double(k) * 0.07 : -1)
            count += 1; k += 1
        }
        let fl = cells(of: id).filter(freeCell).shuffled().prefix(2 * game.flowerFactor)
        for c in fl { addFlower(c, delay: animated ? delay + 0.5 : -1) }
    }

    private var heroCell: Cell { Cell(x: Int(floor(heroPos.x / T)), y: Int(floor(heroPos.y / T))) }

    private func basePoint(_ c: Cell) -> CGPoint { CGPoint(x: CGFloat(c.x) * T + 8, y: CGFloat(c.y) * T + 5) }

    private func spawn(_ k: GatherKind, at c: Cell, island: Int, delay: Double) {
        let t = tex(k.sprite)
        let n = SKSpriteNode(texture: t)
        n.anchorPoint = CGPoint(x: 0.5, y: 2 / t.size().height)
        let p = basePoint(c)
        n.position = p
        n.zPosition = 500 - p.y
        let sh = SKSpriteNode(texture: tex("bloom_shadow"))
        sh.position = CGPoint(x: p.x, y: p.y - 0.5)
        sh.zPosition = -800
        sh.xScale = k.isTree ? 0.9 : 1
        world.addChild(sh)
        world.addChild(n)
        res[c] = Res(kind: k, cell: c, island: island, node: n, shadow: sh)
        if k.isTree || (k.isSoft && k != .pond) {
            let a: CGFloat = k.isSoft ? 0.03 : 0.022
            let d = Double.random(in: 1.4...1.9)
            n.zRotation = -a
            n.run(.sequence([.wait(forDuration: Double.random(in: 0...1.5)),
                             .repeatForever(.sequence([.rotate(toAngle: a, duration: d), .rotate(toAngle: -a, duration: d)]))]))
        }
        if delay >= 0 { pop(n, delay: delay); pop(sh, delay: delay) }
    }

    private func addFlower(_ c: Cell, delay: Double) {
        let n = SKSpriteNode(texture: tex("bloom_item_flower"))
        n.position = CGPoint(x: CGFloat(c.x) * T + 8, y: CGFloat(c.y) * T + 8)
        n.setScale(0.8)
        n.zPosition = 500 - n.position.y
        world.addChild(n)
        n.run(.repeatForever(.sequence([.rotate(toAngle: 0.15, duration: 0.9), .rotate(toAngle: -0.15, duration: 0.9)])))
        flowers[c] = n
        if delay >= 0 { pop(n, delay: delay, to: 0.8) }
    }

    private func pop(_ n: SKNode, delay: Double, to s: CGFloat = 1) {
        n.setScale(0.01)
        n.run(.sequence([.wait(forDuration: delay),
                         .scale(to: s * 1.25, duration: 0.14),
                         .scale(to: s * 0.92, duration: 0.08),
                         .scale(to: s, duration: 0.08)]))
    }

    // MARK: - buildings

    private func findBuildCell() -> Cell? {
        let ahead = CGPoint(x: heroPos.x + facing * 14, y: heroPos.y)
        let candidates = land.filter { freeCell($0) && $0 != heroCell }
        return candidates.min { a, b in
            let pa = basePoint(a), pb = basePoint(b)
            return hypot(pa.x - ahead.x, pa.y - ahead.y) < hypot(pb.x - ahead.x, pb.y - ahead.y)
        }
    }

    private func addBuildingNode(_ b: PlacedBuilding, animated: Bool) {
        if let r = res[b.cell] { r.node.removeFromParent(); r.shadow.removeFromParent(); res[b.cell] = nil }
        if let f = flowers[b.cell] { f.removeFromParent(); flowers[b.cell] = nil }
        let t = tex(b.kind.sprite)
        let n = SKSpriteNode(texture: t)
        n.anchorPoint = CGPoint(x: 0.5, y: 2 / t.size().height)
        let p = basePoint(b.cell)
        n.position = p
        n.zPosition = 500 - p.y
        world.addChild(n)
        let sh = SKSpriteNode(texture: tex("bloom_shadow"))
        sh.position = CGPoint(x: p.x, y: p.y - 0.5)
        sh.xScale = 1.4
        sh.zPosition = -800
        world.addChild(sh)
        if b.kind == .furnace {
            n.run(.repeatForever(.animate(with: [tex("bloom_furnace_0"), tex("bloom_furnace_1")], timePerFrame: 0.18)))
        }
        buildingNodes[b.cell] = (b, n)
        if b.kind == .furnace || b.kind == .smokehouse || b.kind == .cauldron || b.kind == .observatory {
            let g = SKSpriteNode(texture: glowTexture)
            g.blendMode = .add
            g.color = b.kind == .observatory ? UIColor(red: 0.6, green: 0.7, blue: 1, alpha: 1) : UIColor(red: 1, green: 0.62, blue: 0.25, alpha: 1)
            g.colorBlendFactor = 1
            g.setScale(b.kind == .observatory ? 0.7 : 0.9)
            g.position = CGPoint(x: p.x, y: p.y + 8)
            g.zPosition = 3950
            g.alpha = nightLevel * 0.8
            world.addChild(g)
            nightLights.append(g)
        }
        if animated {
            n.position.y += 30
            n.alpha = 0
            n.run(.sequence([.group([.fadeIn(withDuration: 0.1), .moveBy(x: 0, y: -30, duration: 0.22)]),
                             .run { [weak self] in self?.puff(at: p, n: 8); self?.shake(2.5) },
                             .scaleX(to: 1.25, y: 0.8, duration: 0.07), .scale(to: 1, duration: 0.12)]))
            buzz(heavy)
            Sfx.play(.fence)
        }
    }

    private func crafted(_ k: BuildKind, _ item: BItem, _ lucky: Bool) {
        happeningMeter += 2
        if k == .anvil {
            heldTool = "bloom_pick_\(game.pickTier)"
            pickNode.texture = tex(heldTool)
            for _ in 0..<(lucky ? 26 : 12) { spark(at: CGPoint(x: heroPos.x, y: heroPos.y + 10), spread: lucky ? 22 : 12, gold: true) }
            buzz(heavy)
            return
        }
        guard let (_, node) = buildingNodes.values.first(where: { $0.0.kind == k }) else { return }
        if lucky { floatText("×2!", at: CGPoint(x: node.position.x, y: node.position.y + 26), color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)) }
        let ic = SKSpriteNode(texture: tex(item.sprite))
        ic.position = CGPoint(x: node.position.x, y: node.position.y + 14)
        ic.zPosition = 2000
        ic.setScale(0.7)
        world.addChild(ic)
        ic.run(.sequence([.group([.moveBy(x: 0, y: 10, duration: 0.5), .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.2)])]), .removeFromParent()]))
        Sfx.playThrottled(.harvest, gap: 0.3, volume: 0.5)
    }

    // MARK: - bloom wave

    private func bloom(_ id: Int) {
        happeningMeter += 8
        guard let dust = islandNodes[id] else { return }
        // wave starts at the bridge the hero is next to
        var start = heroPos
        var bestD: CGFloat = 60
        for (i, b) in game.world.bridges.enumerated() where (b.a == id || b.b == id) && signs[i] != nil {
            let p = CGPoint(x: CGFloat(b.tile[0]) * T + 8, y: CGFloat(b.tile[1]) * T + 8)
            let d = hypot(p.x - heroPos.x, p.y - heroPos.y)
            if d < bestD { bestD = d; start = p }
        }
        let green = SKSpriteNode(texture: tex("bloom_isl_\(id)"))
        green.anchorPoint = .zero
        let crop = SKCropNode()
        crop.position = dust.position
        crop.zPosition = -999.5
        green.position = .zero
        crop.addChild(green)
        let mask = SKShapeNode(circleOfRadius: 100)
        mask.fillColor = .white
        mask.strokeColor = .clear
        mask.position = CGPoint(x: start.x - dust.position.x, y: start.y - dust.position.y)
        mask.setScale(0.01)
        crop.maskNode = mask
        world.addChild(crop)
        let dur = 1.5
        let cs = cells(of: id)
        mask.run(.customAction(withDuration: dur) { [weak self] _, t in
            guard let self else { return }
            let k = t / CGFloat(dur)
            let r = 100 * (1 - pow(1 - k, 2)) * 1.25
            mask.setScale(max(0.01, r / 100))
            if Int(t * 60) % 2 == 0 {
                let a = CGFloat.random(in: 0..<(2 * .pi))
                let p = CGPoint(x: start.x + cos(a) * r, y: start.y + sin(a) * r)
                let cell = Cell(x: Int(floor(p.x / self.T)), y: Int(floor(p.y / self.T)))
                if cs.contains(cell) { self.petal(at: p) }
            }
        })
        run(.sequence([.wait(forDuration: dur), .run { [weak self] in
            dust.texture = self?.tex("bloom_isl_\(id)")
            crop.removeFromParent()
        }]))
        for (i, b) in game.world.bridges.enumerated() where b.a == id || b.b == id {
            if let s = signs[i], game.owned.contains(b.a) && game.owned.contains(b.b) {
                puff(at: s.position, n: 10)
                s.removeFromParent()
                signs[i] = nil
            }
            refreshBridge(i, animated: true)
        }
        rebuildLand()
        decorate(id, delay: 0.5)
        fill(id, animated: true, delay: 0.6)
        if game.hasT("b5") { run(.sequence([.wait(forDuration: 1.6), .run { [weak self] in self?.spawnChest(near: true) }])) }
        shake(3)
        buzz(heavy)
        Sfx.play(.sparkle)
        Sfx.play(.levelUp, after: 0.3)
    }

    // MARK: - fx

    private func label(_ s: String, size: CGFloat, color: UIColor, stroke: UIColor? = UIColor(red: 0.17, green: 0.14, blue: 0.25, alpha: 1)) -> SKLabelNode {
        let l = SKLabelNode()
        let f = UIFont(name: "Rubik-Bold", size: size * zoom) ?? .boldSystemFont(ofSize: size * zoom)
        var attrs: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: color]
        if let stroke {
            attrs[.strokeColor] = stroke
            attrs[.strokeWidth] = -5
        }
        l.attributedText = NSAttributedString(string: s, attributes: attrs)
        l.setScale(1 / zoom)
        return l
    }

    /// Text drawn once into a texture and reused. An SKLabelNode rasterizes and uploads a
    /// new texture for every string it shows, which stalled the frame of every pickup,
    /// combo and crit; these keep a small cache, so play shows only textures already on the GPU.
    private var textCache: [String: SKTexture] = [:]

    private func textTexture(_ s: String, size: CGFloat, color: UIColor) -> SKTexture {
        let key = "\(s)|\(size)|\(color.hashValue)"
        if let t = textCache[key] { return t }
        let f = UIFont(name: "Rubik-Bold", size: size * zoom) ?? .boldSystemFont(ofSize: size * zoom)
        let attrs: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: color,
                                                    .strokeColor: UIColor(red: 0.17, green: 0.14, blue: 0.25, alpha: 1), .strokeWidth: -5]
        let str = NSAttributedString(string: s, attributes: attrs)
        let pad: CGFloat = 2
        let w = ceil(str.size().width) + pad * 2, h = ceil(f.ascender - f.descender) + pad * 2
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 2
        let img = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { _ in
            str.draw(at: CGPoint(x: pad, y: pad))
        }
        let t = SKTexture(image: img)
        t.filteringMode = .linear
        textCache[key] = t
        #if DEBUG
        if logFPS && now > 1 { print("[tex] late text \(s)") }
        #endif
        return t
    }

    /// Same look as `label`, baseline at y = 0. Digits and signs are separate cached glyphs,
    /// so "+17" after "+16" needs no new texture.
    private func textSprite(_ s: String, size: CGFloat, color: UIColor, alignLeft: Bool = false, glyphs: Bool = false) -> SKNode {
        let f = UIFont(name: "Rubik-Bold", size: size * zoom) ?? .boldSystemFont(ofSize: size * zoom)
        let parts = glyphs ? s.map(String.init) : [s]
        let node = SKNode()
        var x: CGFloat = 0
        var sprites: [SKSpriteNode] = []
        for part in parts {
            let t = textTexture(part, size: size, color: color)
            let sp = SKSpriteNode(texture: t)
            // the 2 pt padding sits on every side; glyphs overlap by it so the outline joins up
            sp.anchorPoint = CGPoint(x: 0, y: (2 - f.descender) / t.size().height)
            sp.position = CGPoint(x: x - 2, y: 0)
            x += t.size().width - 4
            sprites.append(sp)
            node.addChild(sp)
        }
        if !alignLeft { for sp in sprites { sp.position.x -= x / 2 } }
        node.setScale(1 / zoom)
        return node
    }

    /// Glyphs and words that show up mid-play, drawn at load so the first pickup or crit is smooth too.
    private func warmTextures() {
        let colors = [UIColor.white, UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1), UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1),
                      UIColor(red: 1, green: 0.7, blue: 0.8, alpha: 1)]
        var ts: [SKTexture] = []
        for c in colors { for ch in "+0123456789" { ts.append(textTexture(String(ch), size: 5.5, color: c)) } }
        let gold = UIColor(red: 1, green: 0.82, blue: 0.25, alpha: 1)
        for ch in "×0123456789" { ts.append(textTexture(String(ch), size: 7, color: gold)) }
        ts.append(textTexture(tr("КРИТ!"), size: 7, color: UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)))
        SKTexture.preload(ts) {}
    }

    private func floatText(_ s: String, at p: CGPoint, color: UIColor = .white, size: CGFloat = 6, rise: CGFloat = 12) {
        let l = textSprite(s, size: size, color: color)
        l.position = p
        l.zPosition = 3000
        world.addChild(l)
        let s0 = l.xScale
        l.setScale(s0 * 0.4)
        l.run(.sequence([.scale(to: s0 * 1.2, duration: 0.08), .scale(to: s0, duration: 0.08),
                         .group([.moveBy(x: 0, y: rise, duration: 0.7), .sequence([.wait(forDuration: 0.45), .fadeOut(withDuration: 0.25)])]),
                         .removeFromParent()]))
    }

    private func particle(_ name: String, at p: CGPoint, v: CGVector, life: Double, z: CGFloat = 2500, gravity: Bool = true) {
        let n = SKSpriteNode(texture: tex(name))
        n.position = p
        n.zPosition = z
        n.zRotation = CGFloat.random(in: -1...1)
        world.addChild(n)
        let fall = gravity ? -18.0 : 0
        n.run(.sequence([
            .group([.customAction(withDuration: life) { node, t in
                let tt = Double(t)
                node.position = CGPoint(x: p.x + v.dx * CGFloat(tt), y: p.y + v.dy * CGFloat(tt) + CGFloat(fall * tt * tt * 3))
            }, .sequence([.wait(forDuration: life * 0.6), .fadeOut(withDuration: life * 0.4)]),
                    .rotate(byAngle: CGFloat.random(in: -4...4), duration: life)]),
            .removeFromParent()]))
    }

    private func spark(at p: CGPoint, spread: CGFloat = 10, gold: Bool = false) {
        let a = CGFloat.random(in: 0..<(2 * .pi))
        let sp = CGFloat.random(in: spread * 0.6...spread * 1.6)
        particle(gold ? "bloom_item_coin" : "bloom_fx_spark", at: p, v: CGVector(dx: cos(a) * sp, dy: sin(a) * sp + 10), life: 0.4)
    }

    private func petal(at p: CGPoint) {
        particle(Bool.random() ? "bloom_fx_petal" : "bloom_fx_leaf", at: p,
                 v: CGVector(dx: CGFloat.random(in: -10...10), dy: CGFloat.random(in: 8...22)), life: 0.9, gravity: false)
    }

    private func puff(at p: CGPoint, n: Int) {
        for i in 0..<n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let s = SKSpriteNode(texture: tex("bloom_fx_puff"))
            s.position = CGPoint(x: p.x, y: p.y + 3)
            s.zPosition = 2400
            world.addChild(s)
            s.run(.sequence([.group([.moveBy(x: cos(a) * 9, y: sin(a) * 6 + 3, duration: 0.35),
                                     .scale(to: 0.2, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
        }
    }

    private var shakeAmp: CGFloat = 0
    private func shake(_ a: CGFloat) { shakeAmp = max(shakeAmp, a) }

    // MARK: - event pickups: falling stars (Starfall) and golden blossoms (Festival)

    private var eventPicks: [SKSpriteNode] = []
    private var eventPickTimer: TimeInterval = 10

    private func updateEventPickups(_ dt: TimeInterval) {
        let starfall = game.eventIs("starfall"), festival = game.eventIs("festival")
        guard starfall || festival else { return }
        for n in eventPicks where hypot(n.position.x - heroPos.x, n.position.y - heroPos.y - 3) < 9 {
            collectEventPick(n)
        }
        eventPickTimer -= dt
        guard eventPickTimer <= 0, eventPicks.count < 3 else { return }
        eventPickTimer = Double.random(in: 14...22)
        let hc = heroCell
        var cell: Cell?
        for _ in 0..<24 {
            let c = Cell(x: hc.x + Int.random(in: -5...5), y: hc.y + Int.random(in: -4...4))
            if let id = cellIsland[c], game.owned.contains(id), freeCell(c), c != hc { cell = c; break }
        }
        guard let c = cell else { return }
        let p = basePoint(c)
        let n = SKSpriteNode(texture: tex(starfall ? "bloom_fx_star" : "bloom_item_flower"))
        n.anchorPoint = CGPoint(x: 0.5, y: 0.2)
        n.zPosition = 500 - p.y
        world.addChild(n)
        eventPicks.append(n)
        let glow = SKSpriteNode(texture: tex("bloom_fx_puff"))
        glow.color = starfall ? UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1) : UIColor(red: 1, green: 0.8, blue: 0.3, alpha: 1)
        glow.colorBlendFactor = 1
        glow.alpha = 0.55
        glow.setScale(2.2)
        glow.zPosition = -1
        glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.25, duration: 0.6), .fadeAlpha(to: 0.6, duration: 0.6)])))
        n.addChild(glow)
        let bob = SKAction.repeatForever(.sequence([.moveBy(x: 0, y: 1.5, duration: 0.5), .moveBy(x: 0, y: -1.5, duration: 0.5)]))
        if starfall {
            // streaks in from the upper right, lands with a puff
            n.setScale(1.6)
            n.position = CGPoint(x: p.x + 90, y: p.y + 110)
            n.run(.sequence([.move(to: p, duration: 0.7), .run { [weak self] in
                self?.puff(at: p, n: 6)
                self?.shake(0.8)
            }, bob]))
            for i in 0..<8 {
                run(.sequence([.wait(forDuration: Double(i) * 0.08), .run { [weak self, weak n] in
                    guard let self, let n else { return }
                    self.particle("bloom_fx_spark", at: n.position, v: CGVector(dx: 6, dy: 8), life: 0.4, gravity: false)
                }]))
            }
            Sfx.play(.sparkle, volume: 0.5)
        } else {
            n.position = p
            n.setScale(0.1)
            n.color = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
            n.colorBlendFactor = 0.6
            n.run(.sequence([.scale(to: 1.5, duration: 0.25), .scale(to: 1.3, duration: 0.1), bob]))
            for _ in 0..<5 { petal(at: p) }
        }
        // a pickup nobody takes fades after a minute
        n.run(.sequence([.wait(forDuration: 60), .run { [weak self, weak n] in
            guard let self, let n else { return }
            self.eventPicks.removeAll { $0 === n }
            n.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
        }]), withKey: "expire")
    }

    private func collectEventPick(_ n: SKSpriteNode) {
        eventPicks.removeAll { $0 === n }
        n.removeAllActions()
        n.run(.sequence([.group([.moveBy(x: 0, y: 10, duration: 0.2), .fadeOut(withDuration: 0.2)]), .removeFromParent()]))
        for _ in 0..<8 { spark(at: n.position, spread: 12, gold: true) }
        let (item, amount) = game.eventPickup()
        if let item {
            showPickup(item.rawValue, sprite: item.sprite, amount: amount, color: UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1))
        } else {
            showPickup("coin", sprite: "bloom_item_coin", amount: amount, color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1))
        }
        floatText(tr("+20 звёзд события"), at: CGPoint(x: heroPos.x, y: heroPos.y + 26), color: UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1), size: 5)
        Sfx.play(.chest, volume: 0.7)
        buzz(medium)
    }

    // MARK: - fishing: a timing bar instead of hitting

    private final class Fishing {
        let r: Res
        let bar = SKNode()
        let marker = SKSpriteNode(color: .white, size: CGSize(width: 1.5, height: 9))
        let bobber = SKSpriteNode(color: UIColor(red: 0.93, green: 0.25, blue: 0.3, alpha: 1), size: CGSize(width: 3, height: 3))
        var zone: ClosedRange<CGFloat> = -6...6
        var center: CGFloat = 0
        var t: TimeInterval = 0
        var speed: Double = 1
        init(_ r: Res) { self.r = r }
    }
    private var fishing: Fishing?
    private var fishCooldown: TimeInterval = 0
    private let barW: CGFloat = 64

    private func startFishing(_ r: Res) {
        let f = Fishing(r)
        fishing = f
        if abs(r.node.position.x - heroPos.x) > 2 { facing = r.node.position.x > heroPos.x ? 1 : -1 }
        heroSprite.xScale = facing
        let half = barW / 2
        let w = CGFloat.random(in: 12...16) - CGFloat(min(4, game.owned.count / 3))
        f.center = CGFloat.random(in: (-half + w / 2 + 2)...(half - w / 2 - 2))
        f.zone = (f.center - w / 2)...(f.center + w / 2)
        f.speed = Double.random(in: 0.9...1.2)
        let ink = UIColor(red: 0.17, green: 0.14, blue: 0.25, alpha: 1)
        let frame = SKSpriteNode(color: ink, size: CGSize(width: barW + 4, height: 9))
        let back = SKSpriteNode(color: UIColor(red: 0.24, green: 0.42, blue: 0.66, alpha: 1), size: CGSize(width: barW, height: 5))
        let zone = SKSpriteNode(color: UIColor(red: 0.42, green: 0.82, blue: 0.4, alpha: 1), size: CGSize(width: w, height: 5))
        zone.position.x = f.center
        let gold = SKSpriteNode(color: UIColor(red: 1, green: 0.82, blue: 0.25, alpha: 1), size: CGSize(width: 5, height: 5))
        gold.position.x = f.center
        let fish = SKSpriteNode(texture: tex("bloom_item_fish"))
        fish.position = CGPoint(x: -half - 10, y: 0)
        for n in [frame, back, zone, gold, fish, f.marker] as [SKNode] { f.bar.addChild(n) }
        if game.life("gather.pond") < 8 {
            let hint = label(tr("Жми, когда стрелка в зелёном"), size: 4.5, color: .white)
            hint.position = CGPoint(x: 0, y: 7)
            f.bar.addChild(hint)
        }
        f.bar.position = CGPoint(x: heroPos.x, y: heroPos.y + 30)
        f.bar.zPosition = 3100
        f.bar.setScale(0.2)
        world.addChild(f.bar)
        f.bar.run(.scale(to: 1, duration: 0.15))
        // the bobber sits on the pond and dips now and then
        f.bobber.position = CGPoint(x: r.node.position.x + CGFloat.random(in: -3...3), y: r.node.position.y + 4)
        f.bobber.zPosition = 2400
        world.addChild(f.bobber)
        f.bobber.run(.repeatForever(.sequence([.moveBy(x: 0, y: -1, duration: 0.4), .moveBy(x: 0, y: 1, duration: 0.4)])))
        pickNode.run(.rotate(toAngle: 0.6, duration: 0.1))
        Sfx.play(.plant, volume: 0.6)
        buzz(light)
    }

    private func updateFishing(_ dt: TimeInterval) {
        guard let f = fishing else { return }
        if (!demo && stickVec != .zero) || res[f.r.cell] !== f.r || game.panel != nil { endFishing(); return }
        f.t += dt
        // ping-pong across the bar, a little faster the longer you wait
        let ph = f.t * f.speed * (1 + min(0.6, f.t * 0.06))
        let u = abs(ph.truncatingRemainder(dividingBy: 2) - 1)
        f.marker.position.x = (CGFloat(u) - 0.5) * barW
        if demo, f.t > 0.9, abs(f.marker.position.x - f.center) < (Int(f.t * 10) % 3 == 0 ? 2 : 5) { reelIn() }
    }

    private func reelIn() {
        guard let f = fishing else { return }
        let x = f.marker.position.x
        let p = f.r.node.position
        let at = CGPoint(x: heroPos.x, y: heroPos.y + 26)
        endFishing()
        if abs(x - f.center) <= 2.5 {
            floatText(tr("Идеально!"), at: at, color: UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1), size: 7)
            for _ in 0..<10 { spark(at: p, spread: 14) }
            destroy(f.r, mult: game.registerHit(now: now) * 2)
            game.bump("fish.perfect")
            if Int.random(in: 0..<5) == 0 { spawnChest(near: true) }
            Sfx.play(.sparkle)
            buzz(heavy)
        } else if f.zone.contains(x) {
            floatText(tr("Поймал!"), at: at, color: UIColor(red: 0.6, green: 1, blue: 0.55, alpha: 1), size: 6)
            destroy(f.r, mult: game.registerHit(now: now))
            buzz(medium)
        } else {
            floatText(tr("Сорвалась!"), at: at, color: UIColor(red: 1, green: 0.55, blue: 0.5, alpha: 1), size: 6)
            for _ in 0..<6 {
                particle("bloom_fx_spark", at: CGPoint(x: p.x, y: p.y + 4),
                         v: CGVector(dx: CGFloat.random(in: -14...14), dy: CGFloat.random(in: 10...24)), life: 0.5)
            }
            Sfx.play(.error, volume: 0.6)
            fishCooldown = now + 0.8
        }
    }

    private func endFishing() {
        guard let f = fishing else { return }
        fishing = nil
        f.bar.run(.sequence([.scale(to: 0.1, duration: 0.1), .removeFromParent()]))
        f.bobber.removeAllActions()
        f.bobber.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        pickNode.run(.rotate(toAngle: -0.5, duration: 0.1))
    }

    // MARK: - biome ambience: weather particles and music follow the island under the hero

    private var biomeIsland = -2
    private var ambientTimer: TimeInterval = 0
    private var ambientCount = 0

    private func updateBiome(_ dt: TimeInterval) {
        let id = cellIsland[Cell(x: Int(floor(heroPos.x / T)), y: Int(floor(heroPos.y / T)))] ?? biomeIsland
        if id != biomeIsland {
            biomeIsland = id
            if !demo { Music.play(Music.track(forIsland: id)) }
        }
        guard game.owned.contains(id) else { return }
        let rate: TimeInterval
        switch id {
        case 6: rate = 0.07
        case 7, 8, 9, 10: rate = 0.3
        case 11: rate = 0.18
        default: return
        }
        ambientTimer += dt
        guard ambientTimer > rate, ambientCount < 60 else { return }
        ambientTimer = 0
        let hw = size.width / zoom / 2 + 10, hh = size.height / zoom / 2 + 10
        let c = cam.position
        let p = CGPoint(x: c.x + CGFloat.random(in: -hw...hw), y: c.y + CGFloat.random(in: -hh...hh))
        switch id {
        case 6:  // wind carries sand from the left
            ambient("bloom_fx_sand", at: CGPoint(x: c.x - hw, y: p.y), alpha: 0.8, life: 2.4, fadeIn: 0.1,
                    move: .moveBy(x: hw * 2 + 20, y: CGFloat.random(in: -8...8), duration: 2.4), wobble: 2)
        case 7:  // fireflies over the backwater
            ambient("bloom_fx_firefly", at: p, alpha: 1, life: 4, fadeIn: 0.8,
                    move: .moveBy(x: CGFloat.random(in: -14...14), y: CGFloat.random(in: -6...10), duration: 4), wobble: 4, pulse: true)
        case 8:  // spores drift up
            ambient("bloom_fx_spore", at: p, alpha: 0.9, life: 4, fadeIn: 0.8,
                    move: .moveBy(x: CGFloat.random(in: -6...6), y: 26, duration: 4), wobble: 3, pulse: true)
        case 9:  // bees buzz around the hero
            let q = CGPoint(x: heroPos.x + CGFloat.random(in: -60...60), y: heroPos.y + CGFloat.random(in: -40...50))
            ambient("bloom_fx_bee", at: q, alpha: 1, life: 3.5, fadeIn: 0.3,
                    move: .moveBy(x: CGFloat.random(in: -40...40), y: CGFloat.random(in: -10...10), duration: 3.5), wobble: 3, flip: true)
        case 10:  // ash falls, embers rise
            if Bool.random() {
                ambient("bloom_fx_ash", at: CGPoint(x: p.x, y: c.y + hh), alpha: 0.85, life: 4, fadeIn: 0.3,
                        move: .moveBy(x: 18, y: -hh * 2, duration: 4), wobble: 4)
            } else {
                ambient("bloom_fx_ember", at: CGPoint(x: p.x, y: c.y - hh * 0.6 + CGFloat.random(in: 0...hh)), alpha: 1, life: 2.2, fadeIn: 0.2,
                        move: .moveBy(x: CGFloat.random(in: -6...6), y: 30, duration: 2.2), wobble: 2)
            }
        case 11:  // stars twinkle, now and then one falls
            if Int.random(in: 0..<14) == 0 {
                ambient("bloom_fx_star", at: CGPoint(x: p.x, y: c.y + hh), alpha: 1, life: 1.4, fadeIn: 0.05,
                        move: .moveBy(x: -60, y: -50, duration: 1.4), wobble: 0)
            } else {
                ambient("bloom_fx_star", at: p, alpha: 1, life: 1.6, fadeIn: 0.5, move: .moveBy(x: 0, y: 2, duration: 1.6),
                        wobble: 0, pulse: true, small: true)
            }
        default: break
        }
    }

    private func ambient(_ name: String, at p: CGPoint, alpha: CGFloat, life: Double, fadeIn: Double, move: SKAction,
                         wobble: CGFloat, pulse: Bool = false, flip: Bool = false, small: Bool = false, glow: CGFloat = 0) {
        let n = SKSpriteNode(texture: tex(name))
        n.position = p
        n.zPosition = glow > 0 ? 3960 : 2600   // night lights sit above the night tint
        n.alpha = 0
        if small { n.setScale(CGFloat.random(in: 0.5...1)) }
        if glow > 0 { n.setScale(glow); n.blendMode = .add }
        world.addChild(n)
        ambientCount += 1
        var acts: [SKAction] = [move,
                                .sequence([.fadeAlpha(to: alpha, duration: fadeIn), .wait(forDuration: max(0, life - fadeIn - 0.5)),
                                           .fadeOut(withDuration: 0.5)])]
        if wobble > 0 {
            let w = SKAction.sequence([.moveBy(x: 0, y: wobble, duration: 0.5), .moveBy(x: 0, y: -wobble, duration: 0.5)])
            w.timingMode = .easeInEaseOut
            acts.append(.repeat(w, count: Int(life) + 1))
        }
        if pulse {
            acts.append(.repeat(.sequence([.scale(by: 1.4, duration: 0.4), .scale(by: 1 / 1.4, duration: 0.4)]), count: Int(life / 0.8) + 1))
        }
        if flip {
            acts.append(.repeat(.sequence([.scaleX(to: -1, duration: 0), .wait(forDuration: 0.6), .scaleX(to: 1, duration: 0),
                                           .wait(forDuration: 0.6)]), count: Int(life / 1.2) + 1))
        }
        n.run(.sequence([.group(acts), .run { [weak self] in self?.ambientCount -= 1 }, .removeFromParent()]))
    }

    // MARK: - input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard stickTouch == nil, let t = touches.first else { return }
        stickTouch = t
        stickOrigin = t.location(in: cam)
        stickStart = t.timestamp
        stickMoved = 0
        stickBase.position = stickOrigin
        stickKnob.position = .zero
        stickBase.isHidden = false
        stickBase.alpha = 0
        stickBase.run(.fadeIn(withDuration: 0.08))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = stickTouch, touches.contains(t) else { return }
        let p = t.location(in: cam)
        var v = CGVector(dx: p.x - stickOrigin.x, dy: p.y - stickOrigin.y)
        let len = hypot(v.dx, v.dy)
        stickMoved = max(stickMoved, len)
        if len > stickR {
            // the base follows the thumb, so the stick never runs out
            let k = (len - stickR) / len
            stickOrigin.x += v.dx * k
            stickOrigin.y += v.dy * k
            stickBase.position = stickOrigin
            v = CGVector(dx: v.dx * stickR / len, dy: v.dy * stickR / len)
        }
        stickKnob.position = CGPoint(x: v.dx, y: v.dy)
        stickVec = CGVector(dx: v.dx / stickR, dy: v.dy / stickR)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = stickTouch, touches.contains(t) else { return }
        if stickMoved < 10 && t.timestamp - stickStart < 0.35 { tap(t.location(in: world)) }
        endStick()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { endStick() }

    private func endStick() {
        stickTouch = nil
        stickVec = .zero
        stickBase.run(.sequence([.fadeOut(withDuration: 0.1), .hide()]))
    }

    private func tap(_ p: CGPoint) {
        if fishing != nil { reelIn(); return }
        // a tapped chest opens if the hero is close; otherwise say where to go
        if let i = chests.firstIndex(where: { hypot($0.node.position.x - p.x, $0.node.position.y + 6 - p.y) < 14 }) {
            let c = chests[i].node.position
            if hypot(c.x - heroPos.x, c.y - heroPos.y) < 40 { openChest(at: i) }
            else { floatText(tr("Подойди к сундуку"), at: CGPoint(x: c.x, y: c.y + 20), size: 6) }
            return
        }
        for (b, n) in buildingNodes.values where hypot(n.position.x - p.x, n.position.y + 7 - p.y) < 12 {
            game.panel = .building(b.kind)
            Sfx.play(.select)
            return
        }
        for (i, s) in signs where hypot(s.position.x - p.x, s.position.y + 8 - p.y) < 14 {
            let b = game.world.bridges[i]
            game.panel = .buy(game.owned.contains(b.a) ? b.b : b.a)
            Sfx.play(.select)
            return
        }
    }

    // MARK: - loop

    override func update(_ currentTime: TimeInterval) {
        guard built else { return }
        let raw = last == 0 ? 1 / 60 : currentTime - last
        let dt = min(1 / 20, raw)
        last = currentTime
        now += dt
        if logFPS {
            // worst frame and frames over 25 ms show hitches the 2 s average hides
            fpsFrames += 1; fpsClock += raw; fpsWorst = max(fpsWorst, raw); if raw > 0.025 { fpsLong += 1 }
            if raw > 0.06 { print(String(format: "[slow] %.0f ms at %.1f s", raw * 1000, now)) }
            if fpsClock >= 2 {
                print(String(format: "[bloom] fps %.1f worst %.0f ms long %d nodes %d", Double(fpsFrames) / fpsClock, fpsWorst * 1000, fpsLong, world.children.count))
                fpsFrames = 0; fpsClock = 0; fpsWorst = 0; fpsLong = 0
            }
        }
        if freeze > 0 {
            freeze -= dt
            if freeze <= 0 { world.speed = 1 }
            updateCamera(dt)
            return
        }
        if demo && fishing == nil { autopilot() }
        updateFishing(dt)
        moveHero(dt)
        mine(dt)
        updateDrops(dt)
        updateGolden(dt)
        updateHelpers(dt)
        checkChest()
        updateDig(dt)
        updateFoes(dt)
        game.tick(dt: dt)
        game.tickCombo(now: now)
        updateCombo()
        updateGuide(dt)
        updateBiome(dt)
        updateEventPickups(dt)
        updateHappenings(dt)
        updateLife(dt)

        spawnTimer += dt
        if spawnTimer > game.respawnInterval {
            spawnTimer = 0
            respawnOne()
        }
        nearbyTimer += dt
        if nearbyTimer > 0.15 { nearbyTimer = 0; updateNearby() }
        saveTimer += dt
        if saveTimer > 10 { saveTimer = 0; game.save() }
        if game.tutorialIndex < 99, Int(saveTimer * 2) != Int((saveTimer - dt) * 2) { game.advanceTutorial() }

        updateCamera(dt)
    }

    private func hitStop(_ t: TimeInterval) {
        // only while standing and chopping: a stop under a moving finger reads as lag
        guard hypot(stickVec.dx, stickVec.dy) < 0.1 else { return }
        freeze = max(freeze, t)
        world.speed = 0
    }

    private func updateCamera(_ dt: TimeInterval) {
        let k = 1 - exp(-dt * 7)
        var c = CGPoint(x: cam.position.x + (heroPos.x - cam.position.x) * k,
                        y: cam.position.y + (heroPos.y + 6 - cam.position.y) * k)
        if shakeAmp > 0.05 {
            c.x += CGFloat.random(in: -shakeAmp...shakeAmp)
            c.y += CGFloat.random(in: -shakeAmp...shakeAmp)
            shakeAmp *= 0.85
        }
        cam.position = CGPoint(x: (c.x * zoom).rounded() / zoom, y: (c.y * zoom).rounded() / zoom)
    }

    private func moveHero(_ dt: TimeInterval) {
        let len = fainted ? 0 : hypot(stickVec.dx, stickVec.dy)
        // ease towards the stick: quick to start (about 0.1 s), a touch softer to stop
        let speed: CGFloat = 54 * game.runSpeed * windBoost * min(1, len * 1.35)
        let want = len > 0.15 ? CGVector(dx: stickVec.dx / len * speed, dy: stickVec.dy / len * speed) : .zero
        let ease = 1 - exp(-CGFloat(dt) * (len > 0.15 ? 22 : 16))
        vel.dx += (want.dx - vel.dx) * ease
        vel.dy += (want.dy - vel.dy) * ease
        if len <= 0.15, hypot(vel.dx, vel.dy) < 2 { vel = .zero }
        let moving = hypot(vel.dx, vel.dy) > 6
        animClock += dt
        // a slight lean into the run, back upright when standing
        let lean: CGFloat = moving ? -facing * min(1, hypot(vel.dx, vel.dy) / 60) * 0.08 : 0
        heroSprite.zRotation += (lean - heroSprite.zRotation) * min(1, CGFloat(dt) * 14)
        if moving {
            let d = CGVector(dx: vel.dx * CGFloat(dt), dy: vel.dy * CGFloat(dt))
            var p = heroPos
            let px = CGPoint(x: p.x + d.dx, y: p.y)
            if canStand(px) { p = px }
            let py = CGPoint(x: p.x, y: p.y + d.dy)
            if canStand(py) { p = py }
            heroPos = p
            if abs(stickVec.dx) > 0.2 { facing = stickVec.dx > 0 ? 1 : -1 }
            else if len <= 0.15, abs(vel.dx) > 4 { facing = vel.dx > 0 ? 1 : -1 }
            // walking up the screen shows the hero's back
            if vel.dy > abs(vel.dx) * 0.9 { facingUp = true } else if vel.dy < 0 || abs(vel.dx) > vel.dy * 1.2 { facingUp = false }
            pickNode.zPosition = facingUp ? -1 : 1
            let f = Int(animClock * 10) % 4
            heroSprite.texture = tex(game.heroPrefix + (facingUp ? "back_" : "") + "run_\(f)")
            collectFlowers()
            dustClock += dt
            if dustClock > 0.17 {
                dustClock = 0
                let d = SKSpriteNode(texture: tex("bloom_fx_puff"))
                d.position = CGPoint(x: heroPos.x - facing * 3, y: heroPos.y)
                d.zPosition = 500 - heroPos.y + 1
                d.setScale(0.5)
                d.alpha = 0.7
                world.addChild(d)
                d.run(.sequence([.group([.moveBy(x: -facing * 3, y: 2, duration: 0.3), .scale(to: 0.15, duration: 0.3),
                                         .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
            }
        } else {
            // working (swing or dig) turns the hero to face the camera, so the tool shows in front
            let working = swinging || digging
            heroSprite.texture = tex(game.heroPrefix + (facingUp && !working ? "back_idle_0" : (Int(animClock * 2) % 2 == 0 ? "idle_0" : "idle_1")))
            if working { facingUp = false; pickNode.zPosition = 1 }
        }
        heroSprite.xScale = facing
        hero.position = CGPoint(x: (heroPos.x * zoom).rounded() / zoom, y: (heroPos.y * zoom).rounded() / zoom)
        hero.zPosition = 500 - heroPos.y
    }

    private func canStand(_ p: CGPoint) -> Bool {
        for o in [CGPoint(x: -3.5, y: 0), CGPoint(x: 3.5, y: 0), CGPoint(x: 0, y: -1.5), CGPoint(x: 0, y: 3)] {
            let c = Cell(x: Int(floor((p.x + o.x) / T)), y: Int(floor((p.y + o.y) / T)))
            if !land.contains(c) { return false }
        }
        let hc = Cell(x: Int(floor(p.x / T)), y: Int(floor(p.y / T)))
        for dx in -1...1 {
            for dy in -1...1 {
                let c = Cell(x: hc.x + dx, y: hc.y + dy)
                if res[c] != nil || buildingNodes[c] != nil {
                    let b = basePoint(c)
                    let r: CGFloat = buildingNodes[c] != nil ? 7 : 5.5
                    let dNew = hypot(p.x - b.x, (p.y - b.y - 1) * 1.4)
                    let dOld = hypot(heroPos.x - b.x, (heroPos.y - b.y - 1) * 1.4)
                    // never trap the hero inside something that popped up on top of them
                    if dNew < r && dNew <= dOld { return false }
                }
            }
        }
        return true
    }

    private func collectFlowers() {
        let hc = heroCell
        for dx in -1...1 {
            for dy in -1...1 {
                let c = Cell(x: hc.x + dx, y: hc.y + dy)
                guard let f = flowers[c], hypot(f.position.x - heroPos.x, f.position.y - heroPos.y - 4) < 8 else { continue }
                flowers[c] = nil
                f.removeAllActions()
                f.run(.sequence([.group([.moveTo(y: f.position.y + 8, duration: 0.2), .fadeOut(withDuration: 0.2)]), .removeFromParent()]))
                for _ in 0..<5 { petal(at: f.position) }
                game.add(.flower, 1)
                game.gainXP(game.hasT("b3") ? 6 : 1)
                showPickup("flower", sprite: BItem.flower.sprite, amount: 1, color: UIColor(red: 1, green: 0.7, blue: 0.8, alpha: 1))
                Sfx.playThrottled(.sparkle, gap: 0.1, volume: 0.6)
                buzz(light)
            }
        }
    }

    private func target() -> Res? {
        var best: Res?
        var bestScore = CGFloat.greatestFiniteMagnitude
        let hc = heroCell
        for dx in -2...2 {
            for dy in -2...2 {
                guard let r = res[Cell(x: hc.x + dx, y: hc.y + dy)] else { continue }
                let b = r.node.position
                let d = hypot(b.x - heroPos.x, b.y - heroPos.y)
                guard d < 17 else { continue }
                let ahead = (b.x - heroPos.x) * facing > 0 ? -3 : 0
                let score = d + CGFloat(ahead)
                if score < bestScore { bestScore = score; best = r }
            }
        }
        return best
    }

    private func mine(_ dt: TimeInterval) {
        hitTimer += dt
        if fishing != nil { return }
        guard !swinging, !digging, hitTimer >= 0.3, !fainted else { return }
        if let f = nearestFoe(within: 17) { swingAt(f); return }
        guard let r = target() else { return }
        if r.kind == .pond {
            // ponds are fished, not hit: stand still next to one and the cast starts
            if stickVec == .zero, now > fishCooldown { startFishing(r) }
            return
        }
        hitTimer = 0
        swinging = true
        // the right tool for the job: an axe on trees once you have one
        let tool = r.kind.isTree && game.axeTier > 0 ? "bloom_axe_\(game.axeTier)" : "bloom_pick_\(game.pickTier)"
        if heldTool != tool { heldTool = tool; pickNode.texture = tex(tool); pickNode.size = pickNode.texture!.size() }
        if abs(r.node.position.x - heroPos.x) > 2 { facing = r.node.position.x > heroPos.x ? 1 : -1 }
        heroSprite.xScale = facing
        pickNode.run(.sequence([
            .rotate(toAngle: 0.9, duration: 0.07),
            .rotate(toAngle: -1.5, duration: 0.06),
            .run { [weak self] in self?.hit(r) },
            .rotate(toAngle: -0.5, duration: 0.12),
            .run { [weak self] in self?.swinging = false },
        ]))
        heroSprite.run(.sequence([.scaleY(to: 0.9, duration: 0.06), .scaleY(to: 1, duration: 0.1)]))
    }

    private func hit(_ r: Res) {
        guard res[r.cell] === r else { return }
        let mult = game.registerHit(now: now)
        let crit = Double.random(in: 0..<1) < game.critChance + 0.02 * Double(mult - 1)
        let base = game.damage + (r.kind.isTree ? game.axeBonus : 0)
        let dmg = crit ? base * 2 + 1 : base
        if crit { critFX(r) }
        heroHits += 1
        if game.hasT("d5"), heroHits % 15 == 0 { quake(dmg: dmg, mult: mult) }
        applyHit(r, dmg: dmg, mult: mult, dir: facing)
    }

    private var heroHits = 0
    private var lastCollectFX: TimeInterval = 0

    /// Talent "Землетряс": a ring that hits everything around the hero.
    private func quake(dmg: Int, mult: Int) {
        let ring = SKShapeNode(circleOfRadius: 4)
        ring.strokeColor = UIColor(red: 1, green: 0.8, blue: 0.4, alpha: 0.9)
        ring.lineWidth = 1.5
        ring.fillColor = .clear
        ring.position = CGPoint(x: heroPos.x, y: heroPos.y + 2)
        ring.zPosition = 2600
        world.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 7, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        shake(3.5)
        buzz(heavy)
        Sfx.play(.boss, volume: 0.5)
        let hc = heroCell
        var hits: [Res] = []
        for dx in -2...2 {
            for dy in -2...2 {
                if let r = res[Cell(x: hc.x + dx, y: hc.y + dy)],
                   hypot(r.node.position.x - heroPos.x, r.node.position.y - heroPos.y) < 28 { hits.append(r) }
            }
        }
        for r in hits { applyHit(r, dmg: dmg, mult: mult, dir: r.node.position.x > heroPos.x ? 1 : -1) }
    }

    private func critFX(_ r: Res) {
        let p = CGPoint(x: r.node.position.x, y: r.node.position.y + r.node.size.height * 0.6)
        let l = textSprite(tr("КРИТ!"), size: 7, color: UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1))
        l.position = CGPoint(x: p.x, y: p.y + 6)
        l.zPosition = 3200
        world.addChild(l)
        let s0 = l.xScale
        l.setScale(s0 * 2.2)
        l.zRotation = CGFloat.random(in: -0.15...0.15)
        l.run(.sequence([.scale(to: s0 * 0.9, duration: 0.09), .scale(to: s0, duration: 0.06),
                         .group([.moveBy(x: 0, y: 10, duration: 0.5), .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.2)])]),
                         .removeFromParent()]))
        let flash = SKSpriteNode(texture: tex("bloom_fx_puff"))
        flash.position = p
        flash.zPosition = 3150
        flash.color = UIColor(red: 1, green: 0.95, blue: 0.6, alpha: 1)
        flash.colorBlendFactor = 1
        world.addChild(flash)
        flash.run(.sequence([.group([.scale(to: 5, duration: 0.16), .fadeOut(withDuration: 0.16)]), .removeFromParent()]))
        for _ in 0..<10 { spark(at: p, spread: 22) }
        shake(2.6)
        hitStop(0.03)
        buzz(heavy)
        Sfx.play(.skill, volume: 0.7)
    }

    private func applyHit(_ r: Res, dmg: Int, mult: Int, dir: CGFloat) {
        guard res[r.cell] === r else { return }
        let facing = dir
        r.hp -= dmg
        let hp = CGPoint(x: r.node.position.x - facing * 3, y: r.node.position.y + r.node.size.height * 0.45)
        r.node.removeAction(forKey: "hit")
        r.node.run(.sequence([
            .group([.scaleX(to: 1.2, y: 0.84, duration: 0.045), .moveBy(x: facing * 1.6, y: 0, duration: 0.045)]),
            .group([.scaleX(to: 0.94, y: 1.08, duration: 0.07), .moveBy(x: -facing * 1.6, y: 0, duration: 0.07)]),
            .scale(to: 1, duration: 0.08),
        ]), withKey: "hit")
        // one bright frame on every hit: the eye reads it as contact
        r.node.run(.sequence([.colorize(with: .white, colorBlendFactor: r.golden ? 0.4 : 0.75, duration: 0),
                              .colorize(with: r.golden ? Self.goldTint : .white, colorBlendFactor: r.golden ? 0.55 : 0, duration: 0.1)]), withKey: "flash")
        for _ in 0..<3 { spark(at: hp) }
        for _ in 0..<3 {
            particle(r.kind.isStone ? "bloom_fx_chip" : "bloom_fx_leaf", at: hp,
                     v: CGVector(dx: CGFloat.random(in: -16...16), dy: CGFloat.random(in: 6...20)), life: 0.5)
        }
        if now - hitHaptic > 0.08 { buzz(light, 0.6); hitHaptic = now }
        Sfx.playThrottled(.hit, gap: 0.06, volume: 0.6)
        if r.hp <= 0 {
            destroy(r, mult: mult, dir: dir)
        } else {
            showBar(r)
        }
    }

    private func showBar(_ r: Res) {
        let w: CGFloat = 12
        if r.bar == nil {
            let bg = SKSpriteNode(color: UIColor(red: 0.17, green: 0.14, blue: 0.25, alpha: 1), size: CGSize(width: w + 2, height: 3))
            bg.anchorPoint = CGPoint(x: 0, y: 0.5)
            bg.position = CGPoint(x: -w / 2 - 1, y: r.node.size.height - 1)
            bg.zPosition = 10
            let fill = SKSpriteNode(color: UIColor(red: 1, green: 0.42, blue: 0.29, alpha: 1), size: CGSize(width: w, height: 1))
            fill.anchorPoint = CGPoint(x: 0, y: 0.5)
            fill.position = CGPoint(x: 1, y: 0)
            fill.name = "fill"
            bg.addChild(fill)
            r.node.addChild(bg)
            r.bar = bg
        }
        if r.kind.isStone {
            let ratio = CGFloat(r.hp) / CGFloat(r.kind.hp)
            let stage = ratio < 0.34 ? 2 : (ratio < 0.67 ? 1 : 0)
            if stage > 0, r.node.childNode(withName: "crack\(stage)") == nil {
                r.node.childNode(withName: "crack\(stage - 1)")?.removeFromParent()
                let ck = SKSpriteNode(texture: tex("bloom_crack_\(stage)"))
                ck.anchorPoint = r.node.anchorPoint
                ck.name = "crack\(stage)"
                ck.zPosition = 1
                r.node.addChild(ck)
            }
        }
        if let f = r.bar?.childNode(withName: "fill") as? SKSpriteNode {
            f.run(.resize(toWidth: max(1, w * CGFloat(r.hp) / CGFloat(r.kind.hp)), duration: 0.08))
        }
    }

    private func destroy(_ r: Res, mult: Int, dir: CGFloat = 1) {
        res[r.cell] = nil
        let p = r.node.position
        r.node.removeAllActions()
        r.bar?.removeFromParent()
        if r.kind.isTree {
            // trees tip over away from the hero and land with a thump
            r.node.zPosition = 500 - p.y + 1
            let fall = SKAction.rotate(toAngle: -dir * 1.5, duration: 0.3)
            fall.timingMode = .easeIn
            r.node.run(.sequence([fall,
                                  .run { [weak self] in
                                      guard let self else { return }
                                      self.puff(at: CGPoint(x: p.x + dir * 14, y: p.y), n: 7)
                                      self.shake(1.6)
                                      self.buzz(self.light, 0.7)
                                  },
                                  .group([.fadeOut(withDuration: 0.25), .moveBy(x: 0, y: -2, duration: 0.25)]),
                                  .removeFromParent()]))
        } else {
            // stones and bushes swell for a frame, then burst
            r.node.run(.sequence([.scale(to: 1.18, duration: 0.04),
                                  .group([.scale(to: 0.1, duration: 0.1), .fadeOut(withDuration: 0.1)]), .removeFromParent()]))
        }
        r.shadow.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        puff(at: p, n: 9)
        shake(r.golden ? 3 : 1.8)
        hitStop(r.golden ? 0.05 : 0.025)
        if r.kind.isTree {
            let st = SKSpriteNode(texture: tex(r.kind.stump))
            st.anchorPoint = CGPoint(x: 0.5, y: 2 / 10)
            st.position = p
            st.zPosition = 500 - p.y - 0.5
            world.addChild(st)
            st.run(.sequence([.wait(forDuration: 6), .fadeOut(withDuration: 0.6), .removeFromParent()]))
            for _ in 0..<10 {
                particle("bloom_fx_leaf", at: CGPoint(x: p.x, y: p.y + 14),
                         v: CGVector(dx: CGFloat.random(in: -26...26), dy: CGFloat.random(in: 4...26)), life: 0.8)
            }
        } else if r.kind.isStone {
            for _ in 0..<8 {
                particle("bloom_fx_chip", at: CGPoint(x: p.x, y: p.y + 5),
                         v: CGVector(dx: CGFloat.random(in: -28...28), dy: CGFloat.random(in: 8...30)), life: 0.6)
            }
        }
        buzz(medium)
        Sfx.playThrottled(.poof, gap: 0.08, volume: 0.7)
        let bonus = r.golden ? 5 : 1
        for (item, n) in game.roll(r.kind, mult: mult) { emit(item, n * bonus, from: p, maxPieces: r.golden ? 8 : 4, spread: r.golden ? 20 : 12) }
        let c = game.rollCoins(r.kind, mult: mult) * bonus + (r.golden ? 10 : 0)
        if c > 0 { emit(nil, c, from: p, maxPieces: r.golden ? 8 : 4, spread: r.golden ? 20 : 12) }
        if r.golden {
            for _ in 0..<16 { spark(at: CGPoint(x: p.x, y: p.y + 8), spread: 26, gold: true) }
            Sfx.play(.victory, volume: 0.6)
        }
        happeningMeter += 1
        game.gainXP(r.kind.xp)
        game.gathered(r.kind)
        if let (f, isNew) = game.rollFind(r.kind) { findFX(f, isNew: isNew, at: p) }
    }

    private func emit(_ item: BItem?, _ total: Int, from p: CGPoint, maxPieces: Int = 4, spread: CGFloat = 12) {
        let pieces = min(total, maxPieces)
        var left = total
        for i in 0..<pieces {
            let amount = i == pieces - 1 ? left : max(1, total / pieces)
            left -= amount
            let n = SKSpriteNode(texture: tex(item?.sprite ?? "bloom_item_coin"))
            n.setScale(0.75)
            n.zPosition = 2200
            n.position = p
            world.addChild(n)
            let a = CGFloat.random(in: 0..<(2 * .pi))
            let dist = CGFloat.random(in: 5...spread)
            let dest = CGPoint(x: p.x + cos(a) * dist, y: p.y + sin(a) * dist * 0.6)
            let up = CGFloat.random(in: 10...16)
            let dur = 0.38
            n.run(.customAction(withDuration: dur) { node, t in
                let k = t / CGFloat(dur)
                node.position = CGPoint(x: p.x + (dest.x - p.x) * k, y: p.y + (dest.y - p.y) * k + up * 4 * k * (1 - k))
            })
            let hop = up * 0.3
            n.run(.sequence([.wait(forDuration: dur), .scaleX(to: 0.95, y: 0.55, duration: 0.04), .scale(to: 0.75, duration: 0.06),
                             .moveBy(x: 0, y: hop, duration: 0.09), .moveBy(x: 0, y: -hop, duration: 0.09),
                             .scaleX(to: 0.85, y: 0.65, duration: 0.03), .scale(to: 0.75, duration: 0.05)]))
            drops.append(DropNode(node: n, item: item, amount: amount, readyAt: now + dur + 0.32))
        }
    }

    private func updateDrops(_ dt: TimeInterval) {
        guard !drops.isEmpty else { return }
        var keep: [DropNode] = []
        for d in drops {
            if now < d.readyAt { keep.append(d); continue }
            let dx = heroPos.x - d.node.position.x, dy = heroPos.y + 6 - d.node.position.y
            let dist = hypot(dx, dy)
            if dist < 4 {
                collect(d)
                continue
            }
            if dist < 110 {
                d.speed = min(260, d.speed + 520 * CGFloat(dt))
                let step = min(dist, d.speed * CGFloat(dt))
                d.node.position.x += dx / dist * step
                d.node.position.y += dy / dist * step
            }
            keep.append(d)
        }
        drops = keep
    }

    /// One rolling "+N [icon]" per item kind above the hero, so fast pickups
    /// add up instead of piling labels on top of each other.
    private var pickupLabels: [String: (node: SKNode, total: Int, at: TimeInterval)] = [:]

    private func showPickup(_ key: String, sprite: String, amount: Int, color: UIColor) {
        // still on screen: bump the number in place instead of building a new label
        if let old = pickupLabels[key], now - old.at < 0.6, old.node.parent != nil,
           let l = old.node.childNode(withName: "n") {
            let total = old.total + amount
            let fresh = textSprite("+\(total)", size: 5.5, color: color, alignLeft: true, glyphs: true)
            fresh.name = "n"
            fresh.position = l.position
            l.removeFromParent()
            old.node.addChild(fresh)
            old.node.removeAllActions()
            old.node.alpha = 1
            old.node.setScale(1)
            old.node.run(.sequence([.scale(to: 1.12, duration: 0.05), .scale(to: 1, duration: 0.05),
                                    .wait(forDuration: 0.45),
                                    .group([.moveBy(x: 0, y: 6, duration: 0.25), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
            pickupLabels[key] = (old.node, total, now)
            return
        }
        let total = amount
        let slot = CGFloat(pickupLabels.filter { $0.key != key && now - $0.value.at < 0.6 }.count)
        let n = SKNode()
        n.position = CGPoint(x: 0, y: 30 + slot * 9)
        n.zPosition = 3000
        let ic = SKSpriteNode(texture: tex(sprite))
        ic.setScale(0.6)
        ic.position = CGPoint(x: -6, y: 2.5)
        n.addChild(ic)
        let l = textSprite("+\(total)", size: 5.5, color: color, alignLeft: true, glyphs: true)
        l.name = "n"
        l.position = CGPoint(x: -1.5, y: 0)
        n.addChild(l)
        hero.addChild(n)
        n.setScale(0.6)
        n.run(.sequence([.scale(to: 1.15, duration: 0.07), .scale(to: 1, duration: 0.07),
                         .wait(forDuration: 0.45),
                         .group([.moveBy(x: 0, y: 6, duration: 0.25), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        pickupLabels[key] = (n, total, now)
    }

    private func collect(_ d: DropNode) {
        d.node.removeFromParent()
        if let i = d.item {
            game.add(i, d.amount)
            showPickup(i.rawValue, sprite: i.sprite, amount: d.amount, color: .white)
        } else {
            game.addCoins(d.amount)
            showPickup("coin", sprite: "bloom_item_coin", amount: d.amount, color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1))
        }
        Sfx.playThrottled(.coin, gap: 0.05, volume: 0.45)
        if now - lastCollectFX > 0.08 {
            lastCollectFX = now
            particle("bloom_fx_spark", at: CGPoint(x: heroPos.x + CGFloat.random(in: -3...3), y: heroPos.y + 10),
                     v: CGVector(dx: CGFloat.random(in: -8...8), dy: 14), life: 0.35, gravity: false)
        }
        heroSprite.run(.sequence([.scaleY(to: 1.1, duration: 0.04), .scaleY(to: 1, duration: 0.06)]))
    }

    private func updateCombo() {
        let step = game.comboStep
        if game.combo >= BloomContent.hitsPerStep {
            let text = "×\(step)"
            if comboLabel == nil || comboLabel?.name != text {
                comboLabel?.removeFromParent()
                let l = textSprite(text, size: 7, color: UIColor(red: 1, green: 0.82, blue: 0.25, alpha: 1), glyphs: true)
                l.name = text
                l.zPosition = 3100
                hero.addChild(l)
                comboLabel = l
                let s0 = 1 / zoom
                l.setScale(s0 * 0.3)
                l.run(.sequence([.scale(to: s0 * 1.5, duration: 0.1), .scale(to: s0, duration: 0.1)]))
                if step > 1 {
                    for _ in 0..<8 { spark(at: CGPoint(x: heroPos.x, y: heroPos.y + 24), spread: 14) }
                    Sfx.play(.speedup, volume: 0.6)
                }
            }
            comboLabel?.position = CGPoint(x: 0, y: 26)
        } else if let l = comboLabel {
            comboLabel = nil
            l.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        }
    }

    private func respawnOne() {
        if chests.isEmpty, now >= chestFreeAt, Double.random(in: 0..<1) < game.chestChance {
            chestFreeAt = now + BloomBalance.shared.chestCooldown
            spawnChest()
        }
        let owned = game.owned.sorted()
        let counts = Dictionary(grouping: res.values, by: { $0.island }).mapValues(\.count)
        let candidates = owned.filter { (counts[$0] ?? 0) < game.island($0).cap }
        guard let id = candidates.randomElement() else { return }
        let free = cells(of: id).filter { freeCell($0) && hypot(basePoint($0).x - heroPos.x, basePoint($0).y - heroPos.y) > 20 }
        guard let c = free.randomElement() else { return }
        spawn(randomKind(id), at: c, island: id, delay: 0)
        for _ in 0..<4 { petal(at: basePoint(c)) }
        flowerTimer += 1
        if flowerTimer >= 4, let f = cells(of: id).filter(freeCell).randomElement() {
            flowerTimer = 0
            if flowers.count < game.owned.count * 3 * game.flowerFactor { addFlower(f, delay: 0) }
        }
    }

    private func updateNearby() {
        var n: BloomGame.Nearby?
        var best: CGFloat = 22
        for (b, node) in buildingNodes.values {
            let d = hypot(node.position.x - heroPos.x, node.position.y - heroPos.y)
            if d < best { best = d; n = .building(b.kind) }
        }
        // an island sign wins when it is closer than the building (or the building is a bit far)
        best = n == nil ? 26 : min(26, best + 6)
        do {
            for (i, s) in signs {
                let d = hypot(s.position.x - heroPos.x, s.position.y - heroPos.y)
                if d < best {
                    best = d
                    let b = game.world.bridges[i]
                    n = .island(game.owned.contains(b.a) ? b.b : b.a)
                }
            }
        }
        if n != game.nearby { game.nearby = n }
    }

    // MARK: - treasure chests

    /// Several can be out at once (talent, rewards, random spawn); each opens on its own.
    private var chests: [(cell: Cell, node: SKSpriteNode)] = []

    private func spawnChest(near: Bool = false) {
        let owned = game.owned.sorted()
        var cands: [Cell] = []
        for id in owned { cands += cells(of: id).filter(freeCell) }
        cands = cands.filter { hypot(basePoint($0).x - heroPos.x, basePoint($0).y - heroPos.y) > (near ? 16 : 30) }
        if near { cands = cands.filter { hypot(basePoint($0).x - heroPos.x, basePoint($0).y - heroPos.y) < 70 } }
        // keep it off the HUD: under the top bar, the right-hand buttons or the hotbar a tap
        // lands on the button instead of the chest
        let clear = cands.filter { !underHUD(basePoint($0)) }
        guard let c = (clear.isEmpty ? cands : clear).randomElement() else { return }
        let n = SKSpriteNode(texture: tex("bloom_chest_closed"))
        n.anchorPoint = CGPoint(x: 0.5, y: 2 / 16)
        let p = basePoint(c)
        n.position = p
        n.zPosition = 500 - p.y
        world.addChild(n)
        pop(n, delay: 0)
        n.run(.repeatForever(.sequence([.wait(forDuration: 1.2), .scaleX(to: 1.12, y: 0.9, duration: 0.08),
                                        .scaleX(to: 0.95, y: 1.1, duration: 0.08), .scale(to: 1, duration: 0.1)])), withKey: "wiggle")
        n.run(.repeatForever(.sequence([.run { [weak self] in
            self?.particle("bloom_fx_spark", at: CGPoint(x: p.x + CGFloat.random(in: -6...6), y: p.y + CGFloat.random(in: 4...12)),
                           v: CGVector(dx: 0, dy: 8), life: 0.6, gravity: false)
        }, .wait(forDuration: 0.25)])))
        chests.append((c, n))
        #if DEBUG
        print("[chest] spawned, \(chests.count) out")
        #endif
        for _ in 0..<8 { spark(at: CGPoint(x: p.x, y: p.y + 6), spread: 16, gold: false) }
        Sfx.play(.sparkle, volume: 0.6)
    }

    /// True when a world point shows under the SwiftUI HUD (top bar and goal, the right
    /// column of round buttons, the build button and hotbar) with the camera where it is now.
    private func underHUD(_ p: CGPoint) -> Bool {
        guard let v = view else { return false }
        let q = convertPoint(toView: world.convert(CGPoint(x: p.x, y: p.y + 8), to: self))
        let w = v.bounds.width, h = v.bounds.height
        return q.y < 210 || q.y > h - 220 || q.x < 28 || q.x > w - 28 || (q.x > w - 120 && q.y < 440)
    }

    private func checkChest() {
        guard let i = chests.firstIndex(where: { hypot($0.node.position.x - heroPos.x, $0.node.position.y - heroPos.y) < 14 }) else { return }
        openChest(at: i)
    }

    private func openChest(at i: Int) {
        let ch = chests.remove(at: i)
        #if DEBUG
        print("[chest] opened, \(chests.count) left")
        #endif
        let n = ch.node
        let p = n.position
        n.removeAllActions()
        n.run(.sequence([
            .scaleX(to: 1.3, y: 0.75, duration: 0.08), .scaleX(to: 0.9, y: 1.2, duration: 0.08),
            .run { [weak self] in
                guard let self else { return }
                n.texture = self.tex("bloom_chest_open")
                let loot = self.game.openChest()
                self.emit(nil, loot.coins, from: CGPoint(x: p.x, y: p.y + 6), maxPieces: 12, spread: 22)
                for (i, k) in loot.items { self.emit(i, k, from: CGPoint(x: p.x, y: p.y + 6), maxPieces: 3, spread: 20) }
                for _ in 0..<24 { self.spark(at: CGPoint(x: p.x, y: p.y + 10), spread: 30, gold: true) }
                self.shake(3)
                self.buzz(self.heavy)
                self.floatText(tr("Сундук!"), at: CGPoint(x: p.x, y: p.y + 22), color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), size: 7, rise: 14)
            },
            .scale(to: 1, duration: 0.12),
            .wait(forDuration: 2.5), .fadeOut(withDuration: 0.4), .removeFromParent(),
        ]))
    }

    // MARK: - album finds

    private func findFX(_ id: String, isNew: Bool, at p: CGPoint) {
        let n = SKSpriteNode(texture: tex("bloom_find_" + id))
        n.position = CGPoint(x: p.x, y: p.y + 8)
        n.zPosition = 3300
        world.addChild(n)
        let glow = SKSpriteNode(texture: tex("bloom_fx_puff"))
        glow.color = isNew ? UIColor(red: 0.8, green: 0.5, blue: 1, alpha: 1) : UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1)
        glow.colorBlendFactor = 1
        glow.setScale(3)
        glow.alpha = 0.6
        glow.zPosition = -1
        n.addChild(glow)
        glow.run(.repeatForever(.sequence([.scale(to: 3.8, duration: 0.3), .scale(to: 3, duration: 0.3)])))
        n.setScale(0.2)
        n.run(.sequence([
            .group([.moveBy(x: 0, y: 18, duration: 0.35), .scale(to: 1.6, duration: 0.35)]),
            .wait(forDuration: 0.7),
            .group([.move(to: CGPoint(x: heroPos.x, y: heroPos.y + 10), duration: 0.3), .scale(to: 0.4, duration: 0.3)]),
            .removeFromParent(),
        ]))
        floatText(isNew ? tr("НАХОДКА!") : "+\(BloomAlbum.duplicateCoins)", at: CGPoint(x: p.x, y: p.y + 34),
                  color: isNew ? UIColor(red: 0.85, green: 0.65, blue: 1, alpha: 1) : UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), size: 6.5, rise: 10)
        for _ in 0..<16 { spark(at: CGPoint(x: p.x, y: p.y + 20), spread: 24) }
        buzz(heavy)
        Sfx.play(isNew ? .chest : .coin)
    }

    // MARK: - happenings: small events that the farm's own work sets off
    // Every break, craft and new island fills a meter; when it tips over, something
    // happens by itself near the hero. No buttons, nothing to accept: just a reward.

    private static let goldTint = UIColor(red: 1, green: 0.82, blue: 0.25, alpha: 1)
    private var happeningMeter = 0
    private var happeningAt = Int.random(in: 14...22)
    private var windLeft: TimeInterval = 0
    private var windBoost: CGFloat { windLeft > 0 ? 1.4 : 1 }
    private var windClock: TimeInterval = 0
    private var lastHappening = ""

    private func updateHappenings(_ dt: TimeInterval) {
        if windLeft > 0 {
            windLeft -= dt
            windClock += dt
            if windClock > 0.12 {
                windClock = 0
                particle("bloom_fx_leaf", at: CGPoint(x: heroPos.x - facing * 6, y: heroPos.y + CGFloat.random(in: 2...14)),
                         v: CGVector(dx: -facing * CGFloat.random(in: 20...34), dy: CGFloat.random(in: -4...6)), life: 0.5, gravity: false)
            }
        }
        guard happeningMeter >= happeningAt, fishing == nil, goldenLeft <= 0 else { return }
        happeningMeter = 0
        happeningAt = Int.random(in: 18...30)
        var pool = ["flock", "golden", "coins", "wind", "meteor", "treasure"]
        pool.removeAll { $0 == lastHappening }
        if !chests.isEmpty { pool.removeAll { $0 == "treasure" } }
        fireHappening(pool.randomElement() ?? "coins")
    }

    private func fireHappening(_ pick: String) {
        lastHappening = pick
        if logFPS { print(String(format: "[event] happening %@ at %.1f s", pick, now)) }
        switch pick {
        case "flock": flock()
        case "golden": goldenThing()
        case "wind": wind()
        case "meteor": meteor()
        case "treasure":
            spawnChest(near: true)
            game.showToast(BloomToast(title: tr("Клад!"), subtitle: tr("Рядом появился сундук")))
        default: coinRain()
        }
        Analytics.shared.track("bloom_happening", ["kind": pick])
        game.bump("happening")
    }

    /// Free cells near the hero on owned islands, nearest first.
    private func cellsNearHero(_ maxDist: CGFloat, minDist: CGFloat = 12) -> [(Cell, Int)] {
        var out: [(Cell, Int, CGFloat)] = []
        for id in game.owned {
            for c in cells(of: id) where freeCell(c) {
                let d = hypot(basePoint(c).x - heroPos.x, basePoint(c).y - heroPos.y)
                if d >= minDist && d <= maxDist && !underHUD(basePoint(c)) { out.append((c, id, d)) }
            }
        }
        return out.sorted { $0.2 < $1.2 }.map { ($0.0, $0.1) }
    }

    /// A flock flies over and sows: a handful of things sprout around the hero.
    private func flock() {
        let y0 = heroPos.y + CGFloat.random(in: 10...30)
        let from = heroPos.x - 120 * facing
        for i in 0..<6 {
            let b = SKSpriteNode(texture: tex("bloom_fx_bird_0"))
            b.xScale = facing
            b.position = CGPoint(x: from - facing * CGFloat(i % 3) * 10, y: y0 + CGFloat(i) * 5 + CGFloat(i % 2) * 4)
            b.zPosition = 3800
            world.addChild(b)
            b.run(.repeatForever(.animate(with: [tex("bloom_fx_bird_0"), tex("bloom_fx_bird_1")], timePerFrame: 0.12)))
            b.run(.sequence([.wait(forDuration: Double(i) * 0.06), .moveBy(x: facing * 260, y: 14, duration: 2.6), .removeFromParent()]))
        }
        let spots = Array(cellsNearHero(60).shuffled().prefix(5))
        for (k, (c, id)) in spots.enumerated() {
            run(.sequence([.wait(forDuration: 0.8 + Double(k) * 0.18), .run { [weak self] in
                guard let self, self.freeCell(c) else { return }
                self.spawn(self.randomKind(id), at: c, island: id, delay: 0)
                for _ in 0..<5 { self.petal(at: self.basePoint(c)) }
                Sfx.playThrottled(.harvest, gap: 0.1, volume: 0.35)
            }]))
        }
        Sfx.play(.sparkle, volume: 0.5)
        game.showToast(BloomToast(title: tr("Стая птиц"), subtitle: tr("Птицы посеяли семена вокруг")))
    }

    /// The nearest tree or stone turns golden: five times the loot.
    private func goldenThing() {
        let near = res.values.filter { !$0.golden && $0.kind != .pond }
            .sorted { hypot($0.node.position.x - heroPos.x, $0.node.position.y - heroPos.y) <
                      hypot($1.node.position.x - heroPos.x, $1.node.position.y - heroPos.y) }
        guard let r = near.first(where: { !underHUD($0.node.position) }) ?? near.first else { coinRain(); return }
        r.golden = true
        r.node.run(.colorize(with: Self.goldTint, colorBlendFactor: 0.55, duration: 0.3))
        let p = r.node.position
        r.node.run(.repeatForever(.sequence([.run { [weak self] in
            self?.particle("bloom_fx_spark", at: CGPoint(x: p.x + CGFloat.random(in: -6...6), y: p.y + CGFloat.random(in: 2...18)),
                           v: CGVector(dx: 0, dy: 10), life: 0.6, gravity: false)
        }, .wait(forDuration: 0.18)])), withKey: "glow")
        for _ in 0..<12 { spark(at: CGPoint(x: p.x, y: p.y + 8), spread: 18, gold: true) }
        Sfx.play(.sparkle, volume: 0.7)
        game.showToast(BloomToast(title: tr("Золотая находка"), subtitle: tr("Разбей сияющий ресурс: добыча ×5")))
    }

    /// Coins rain down around the hero for a few seconds; they land as normal drops.
    private func coinRain() {
        let total = max(8, 4 + game.level * 2)
        let pieces = 12
        for i in 0..<pieces {
            run(.sequence([.wait(forDuration: Double(i) * 0.15), .run { [weak self] in
                guard let self else { return }
                let p = CGPoint(x: self.heroPos.x + CGFloat.random(in: -40...40), y: self.heroPos.y + CGFloat.random(in: -24...24))
                let n = SKSpriteNode(texture: self.tex("bloom_item_coin"))
                n.setScale(0.75)
                n.zPosition = 2200
                n.position = CGPoint(x: p.x, y: p.y + 110)
                self.world.addChild(n)
                let fall = SKAction.move(to: p, duration: 0.45)
                fall.timingMode = .easeIn
                n.run(.sequence([fall, .scaleX(to: 0.95, y: 0.55, duration: 0.04), .scale(to: 0.75, duration: 0.06)]))
                self.drops.append(DropNode(node: n, item: nil, amount: max(1, total / pieces), readyAt: self.now + 0.6))
                Sfx.playThrottled(.coin, gap: 0.08, volume: 0.3)
            }]))
        }
        game.showToast(BloomToast(title: tr("Монетный дождь"), subtitle: tr("Собирай, пока падают")))
    }

    /// A tail wind: the hero runs faster for a while.
    private func wind() {
        windLeft = 20
        for _ in 0..<14 {
            particle("bloom_fx_leaf", at: CGPoint(x: heroPos.x + CGFloat.random(in: -20...20), y: heroPos.y + CGFloat.random(in: 0...20)),
                     v: CGVector(dx: CGFloat.random(in: 30...60), dy: CGFloat.random(in: -6...10)), life: 0.8, gravity: false)
        }
        Sfx.play(.speedup, volume: 0.6)
        game.showToast(BloomToast(title: tr("Попутный ветер"), subtitle: tr("20 секунд бегаешь быстрее")))
    }

    /// A small meteor falls close by and leaves a rare stone to break.
    private func meteor() {
        guard let spot = cellsNearHero(55, minDist: 18).first else { coinRain(); return }
        let (c, id) = spot
        let rare: [GatherKind] = game.level >= 12 ? [.starstone, .obsidian, .crystal, .rock_gold] : [.crystal, .rock_gold, .rock_iron]
        let k = rare.randomElement() ?? .crystal
        let p = basePoint(c)
        let star = SKSpriteNode(texture: tex("bloom_fx_spark"))
        star.setScale(2.5)
        star.color = UIColor(red: 1, green: 0.7, blue: 0.3, alpha: 1)
        star.colorBlendFactor = 0.6
        star.position = CGPoint(x: p.x - 70, y: p.y + 140)
        star.zPosition = 3900
        world.addChild(star)
        let fall = SKAction.move(to: CGPoint(x: p.x, y: p.y + 4), duration: 0.55)
        fall.timingMode = .easeIn
        star.run(.repeatForever(.sequence([.run { [weak self, weak star] in
            guard let self, let star else { return }
            self.particle("bloom_fx_puff", at: star.position, v: CGVector(dx: 0, dy: 0), life: 0.3, z: 3850, gravity: false)
        }, .wait(forDuration: 0.03)])))
        star.run(.sequence([fall, .run { [weak self] in
            guard let self else { return }
            self.puff(at: p, n: 12)
            for _ in 0..<12 { self.spark(at: CGPoint(x: p.x, y: p.y + 4), spread: 24) }
            self.shake(4)
            self.buzz(self.heavy)
            Sfx.play(.boss, volume: 0.5)
            if self.freeCell(c) { self.spawn(k, at: c, island: id, delay: 0) }
        }, .removeFromParent()]))
        game.showToast(BloomToast(title: tr("Метеорит"), subtitle: tr("Упал редкий камень, разбей его")))
    }

    // MARK: - living world: day and night, swaying grass, birds, jumping fish, falling leaves
    // Everything here is decoration: cheap, capped in number, and never in the way.

    private let nightOverlay = SKSpriteNode()
    private let heroLight = SKSpriteNode()
    private var nightLights: [SKSpriteNode] = []
    private var dayClock: TimeInterval = 0.12     // 0..1 through one day
    private let dayLength: TimeInterval = 420      // seven minutes: a dusk or a night in almost every session
    private var nightLevel: CGFloat = 0
    private var lifeTimer: TimeInterval = 0
    private var fishTimer: TimeInterval = 5
    private var leafTimer: TimeInterval = 0
    private var groundBirds: [SKSpriteNode] = []

    /// A soft round light, drawn once.
    private lazy var glowTexture: SKTexture = {
        let size = CGSize(width: 64, height: 64)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let cs = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor(white: 1, alpha: 0.55).cgColor, UIColor(white: 1, alpha: 0.18).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 0.45, 1]) {
                ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 32, y: 32), startRadius: 0,
                                                 endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
            }
        }
        return SKTexture(image: img)
    }()

    private func setUpLife() {
        nightOverlay.color = UIColor(red: 0.12, green: 0.14, blue: 0.38, alpha: 1)
        nightOverlay.size = CGSize(width: 3000, height: 3000)
        nightOverlay.alpha = 0
        nightOverlay.zPosition = 3940
        cam.addChild(nightOverlay)
        heroLight.texture = glowTexture
        heroLight.size = CGSize(width: 64, height: 64)
        heroLight.setScale(1.3)
        heroLight.blendMode = .add
        heroLight.color = UIColor(red: 1, green: 0.85, blue: 0.55, alpha: 1)
        heroLight.colorBlendFactor = 1
        heroLight.alpha = 0
        heroLight.zPosition = 3945
        world.addChild(heroLight)
        #if DEBUG
        if let d = UserDefaults.standard.string(forKey: "bloomDay"), let v = Double(d) { dayClock = v }   // -bloomDay 0.75 = night
        #endif
        applyDayLight()
    }

    /// Night strength 0...1 and the tint for the time of day.
    private func applyDayLight() {
        let t = dayClock
        var night: CGFloat = 0
        var tint = UIColor(red: 0.12, green: 0.14, blue: 0.38, alpha: 1)
        switch t {
        case 0.55..<0.65:   // dusk: warm, then cooling
            let k = CGFloat((t - 0.55) / 0.1)
            night = k
            tint = UIColor(red: 0.12 + 0.5 * (1 - k), green: 0.14 + 0.1 * (1 - k), blue: 0.38 - 0.1 * (1 - k), alpha: 1)
        case 0.65..<0.88: night = 1
        case 0.88..<1:      // dawn: pink, fading out
            let k = CGFloat((t - 0.88) / 0.12)
            night = 1 - k
            tint = UIColor(red: 0.12 + 0.55 * k, green: 0.14 + 0.1 * k, blue: 0.38, alpha: 1)
        default: night = 0
        }
        nightLevel = night
        nightOverlay.color = tint
        nightOverlay.alpha = night * 0.3          // never dark enough to hide what you are doing
        heroLight.alpha = night * 0.55
        for g in nightLights { g.alpha = night * 0.8 }
    }

    /// Grass and flowers that lean in the wind. One loop moves only those inside the camera,
    /// instead of a forever-action on every tuft of every island (that cost frames on big farms).
    private var swayers: [(node: SKNode, phase: CGFloat)] = []
    private var swayClock: TimeInterval = 0

    private func sway(_ n: SKNode, phase: CGFloat) {
        swayers.append((n, phase))
    }

    private func updateSway(_ dt: TimeInterval) {
        swayClock += dt
        let hw = size.width / zoom / 2 + 16, hh = size.height / zoom / 2 + 24
        let c = cam.position
        let w = CGFloat(swayClock) * .pi / 1.6      // a full lean there and back in 3.2 s
        var i = 0
        while i < swayers.count {
            let (n, ph) = swayers[i]
            if n.parent == nil { swayers.swapAt(i, swayers.count - 1); swayers.removeLast(); continue }
            if abs(n.position.x - c.x) < hw, abs(n.position.y - c.y) < hh {
                n.zRotation = 0.09 * sin(w + ph * 2)
            }
            i += 1
        }
    }

    private func updateLife(_ dt: TimeInterval) {
        updateSway(dt)
        dayClock += dt / dayLength
        if dayClock >= 1 { dayClock -= 1 }
        lifeTimer += dt
        if lifeTimer > 0.5 { lifeTimer = 0; applyDayLight() }
        heroLight.position = CGPoint(x: hero.position.x, y: hero.position.y + 8)
        let hw = size.width / zoom / 2, hh = size.height / zoom / 2
        let c = cam.position

        // fireflies around the hero at night
        if nightLevel > 0.6, ambientCount < 40, Int.random(in: 0..<6) == 0 {
            let p = CGPoint(x: heroPos.x + CGFloat.random(in: -70...70), y: heroPos.y + CGFloat.random(in: -50...60))
            ambient("bloom_fx_firefly", at: p, alpha: 1, life: 4, fadeIn: 0.8,
                    move: .moveBy(x: CGFloat.random(in: -14...14), y: CGFloat.random(in: -6...10), duration: 4), wobble: 4, pulse: true,
                    glow: 1.6)
        }

        // a leaf drifts down from a tree on screen
        leafTimer += dt
        if leafTimer > 0.9 {
            leafTimer = 0
            if let r = res.values.first(where: { $0.kind.isTree && abs($0.node.position.x - c.x) < hw && abs($0.node.position.y - c.y) < hh }) {
                let p = CGPoint(x: r.node.position.x + CGFloat.random(in: -5...5), y: r.node.position.y + CGFloat.random(in: 12...20))
                particle("bloom_fx_leaf", at: p, v: CGVector(dx: CGFloat.random(in: -6...6), dy: -6), life: 2.2, z: 1800, gravity: false)
            }
        }

        // a fish jumps out of the water now and then
        fishTimer -= dt
        if fishTimer <= 0 {
            fishTimer = Double.random(in: 5...9)
            for _ in 0..<8 {
                let p = CGPoint(x: c.x + CGFloat.random(in: -hw...hw) * 0.85, y: c.y + CGFloat.random(in: -hh...hh) * 0.6)
                let cell = Cell(x: Int(floor(p.x / T)), y: Int(floor(p.y / T)))
                guard cellIsland[cell] == nil, !land.contains(cell), !bridgeCells.contains(cell) else { continue }
                // keep clear of shores so it never jumps out of the sand
                let shore = [(-1, 0), (1, 0), (0, -1), (0, 1)].contains { cellIsland[Cell(x: cell.x + $0.0, y: cell.y + $0.1)] != nil }
                if shore || underHUD(p) { continue }
                fishJump(at: p)
                break
            }
        }

        // birds land near the hero, peck, and fly off when you come close
        if groundBirds.count < 2, Int.random(in: 0..<600) == 0, nightLevel < 0.4 { landBird() }
        for b in groundBirds {
            if hypot(b.position.x - heroPos.x, b.position.y - heroPos.y) < 22 { flyOff(b) }
        }
    }

    private func fishJump(at p: CGPoint) {
        let f = SKSpriteNode(texture: tex("bloom_item_fish"))
        f.setScale(0.7)
        f.position = p
        f.zPosition = -950
        let dir: CGFloat = Bool.random() ? 1 : -1
        f.xScale = 0.7 * dir
        world.addChild(f)
        let dur = 0.7
        f.run(.sequence([.group([.customAction(withDuration: dur) { node, t in
            let k = t / CGFloat(dur)
            node.position = CGPoint(x: p.x + dir * 12 * k, y: p.y + 14 * 4 * k * (1 - k))
            node.zRotation = dir * (0.9 - 1.8 * k)
        }]), .removeFromParent()]))
        splash(at: p)
        run(.sequence([.wait(forDuration: dur), .run { [weak self] in self?.splash(at: CGPoint(x: p.x + dir * 12, y: p.y)) }]))
    }

    private func splash(at p: CGPoint) {
        let ring = SKShapeNode(ellipseOf: CGSize(width: 6, height: 3))
        ring.strokeColor = UIColor(white: 1, alpha: 0.8)
        ring.lineWidth = 0.6
        ring.position = p
        ring.zPosition = -960
        world.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 2.4, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
        for _ in 0..<4 {
            particle("bloom_fx_spark", at: p, v: CGVector(dx: CGFloat.random(in: -10...10), dy: CGFloat.random(in: 10...18)), life: 0.35, z: -955)
        }
    }

    private func landBird() {
        let cells = cellsNearHero(70, minDist: 34)
        guard let spot = cells.randomElement() else { return }
        let cell = spot.0
        let p = CGPoint(x: basePoint(cell).x + CGFloat.random(in: -4...4), y: basePoint(cell).y + CGFloat.random(in: -2...4))
        let b = SKSpriteNode(texture: tex("bloom_fx_bird_0"))
        let dir: CGFloat = p.x > heroPos.x ? -1 : 1
        b.xScale = dir
        b.anchorPoint = CGPoint(x: 0.5, y: 0)
        b.position = CGPoint(x: p.x - dir * 80, y: p.y + 60)
        b.zPosition = 3800
        b.userData = NSMutableDictionary()
        world.addChild(b)
        groundBirds.append(b)
        let flap = SKAction.repeatForever(.animate(with: [tex("bloom_fx_bird_0"), tex("bloom_fx_bird_1")], timePerFrame: 0.1))
        b.run(flap, withKey: "flap")
        let land = SKAction.move(to: p, duration: 1.4)
        land.timingMode = .easeOut
        b.run(.sequence([land, .run { [weak b] in
            guard let b else { return }
            b.removeAction(forKey: "flap")
            b.texture = SKTexture(imageNamed: "bloom_fx_bird_1")
            b.texture?.filteringMode = .nearest
            b.zPosition = 500 - p.y
            // peck and hop about
            b.run(.repeatForever(.sequence([
                .wait(forDuration: Double.random(in: 0.6...1.4)),
                .rotate(toAngle: -0.35 * b.xScale, duration: 0.06), .rotate(toAngle: 0, duration: 0.08),
                .wait(forDuration: Double.random(in: 0.3...0.9)),
                .moveBy(x: CGFloat.random(in: -3...3), y: 1.5, duration: 0.08), .moveBy(x: 0, y: -1.5, duration: 0.08),
            ])), withKey: "peck")
        }]))
        // it leaves by itself after a while
        b.run(.sequence([.wait(forDuration: 18), .run { [weak self, weak b] in if let b { self?.flyOff(b) } }]), withKey: "timer")
    }

    private func flyOff(_ b: SKSpriteNode) {
        guard b.userData?["leaving"] == nil else { return }
        b.userData?["leaving"] = true
        b.removeAllActions()
        b.zPosition = 3800
        let dir: CGFloat = b.position.x > heroPos.x ? 1 : -1
        b.xScale = dir
        b.run(.repeatForever(.animate(with: [tex("bloom_fx_bird_0"), tex("bloom_fx_bird_1")], timePerFrame: 0.08)))
        let away = SKAction.moveBy(x: dir * 120, y: 90, duration: 1.6)
        away.timingMode = .easeIn
        groundBirds.removeAll { $0 === b }
        b.run(.sequence([away, .removeFromParent()]))
        Sfx.playThrottled(.select, gap: 0.3, volume: 0.25)
    }

    // MARK: - dig spots: buried treasure for the shovel

    private var heldTool = ""
    private var digSpots: [(cell: Cell, node: SKSpriteNode)] = []
    private var digTimer: TimeInterval = 20
    private var digHintAt: TimeInterval = 0
    private var digging = false

    private func updateDig(_ dt: TimeInterval) {
        digTimer -= dt
        if digTimer <= 0 {
            digTimer = BloomBalance.shared.digEvery * Double.random(in: 0.8...1.3)
            if digSpots.count < BloomBalance.shared.digMax, game.level >= 3 { spawnDigSpot() }
        }
        guard !digging, !swinging, fishing == nil, stickVec == .zero,
              let i = digSpots.firstIndex(where: { hypot($0.node.position.x - heroPos.x, $0.node.position.y - heroPos.y) < 13 }) else { return }
        if !game.hasShovel {
            if now > digHintAt {
                #if DEBUG
                print("[dig] hint: no shovel")
                #endif
                digHintAt = now + 5
                floatText(tr("Нужна лопата: наковальня"), at: CGPoint(x: heroPos.x, y: heroPos.y + 28), color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), size: 5.5)
            }
            return
        }
        dig(at: i)
    }

    private func spawnDigSpot(near: Bool = false) {
        let cands = game.owned.flatMap { id in cells(of: id).filter(freeCell).map { ($0, id) } }
            .filter {
                let d = hypot(basePoint($0.0).x - heroPos.x, basePoint($0.0).y - heroPos.y)
                return !underHUD(basePoint($0.0)) && d > (near ? 14 : 30) && (!near || d < 50)
            }
        guard let pick = cands.randomElement() else { return }
        let c = pick.0
        let n = SKSpriteNode(texture: tex("bloom_dig"))
        n.anchorPoint = CGPoint(x: 0.5, y: 0.2)
        let p = basePoint(c)
        n.position = p
        n.zPosition = -850
        n.userData = ["island": pick.1]
        world.addChild(n)
        pop(n, delay: 0)
        n.run(.repeatForever(.sequence([.wait(forDuration: 1.6), .run { [weak self] in
            self?.particle("bloom_fx_spark", at: CGPoint(x: p.x + CGFloat.random(in: -5...5), y: p.y + 4), v: CGVector(dx: 0, dy: 9), life: 0.5, gravity: false)
        }])))
        digSpots.append((c, n))
    }

    private func dig(at i: Int) {
        #if DEBUG
        print("[dig] start")
        #endif
        digging = true
        let spot = digSpots[i]
        let p = spot.node.position
        facing = p.x >= heroPos.x ? 1 : -1
        heroSprite.xScale = facing
        heldTool = "bloom_shovel"
        pickNode.texture = tex(heldTool)
        pickNode.size = pickNode.texture!.size()
        var acts: [SKAction] = []
        for k in 0..<3 {
            acts += [.rotate(toAngle: 0.7, duration: 0.08), .rotate(toAngle: -1.4, duration: 0.07),
                     .run { [weak self] in
                         guard let self else { return }
                         self.puff(at: p, n: 4)
                         for _ in 0..<3 {
                             self.particle("bloom_fx_chip", at: CGPoint(x: p.x, y: p.y + 2),
                                           v: CGVector(dx: CGFloat.random(in: -14...14), dy: CGFloat.random(in: 10...22)), life: 0.45)
                         }
                         spot.node.run(.sequence([.scaleX(to: 1.15, y: 0.8, duration: 0.05), .scale(to: 1 - CGFloat(k) * 0.2, duration: 0.08)]))
                         self.buzz(self.light, 0.6)
                         Sfx.playThrottled(.till, gap: 0.05, volume: 0.6)
                     },
                     .rotate(toAngle: -0.5, duration: 0.1)]
        }
        acts.append(.run { [weak self] in self?.finishDig(spot) })
        pickNode.run(.sequence(acts))
    }

    private func finishDig(_ spot: (cell: Cell, node: SKSpriteNode)) {
        digging = false
        digSpots.removeAll { $0.cell == spot.cell }
        let p = spot.node.position
        spot.node.removeAllActions()
        spot.node.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        let id = (spot.node.userData?["island"] as? Int) ?? 0
        let kind = randomKind(id)
        let r = game.digReward(kind)
        #if DEBUG
        print("[dig] done: \(r.coins) coins, items \(r.items.map { "\($0.0.rawValue)×\($0.1)" }), gem \(r.gem)")
        #endif
        emit(nil, r.coins, from: p, maxPieces: 6, spread: 16)
        for (item, n) in r.items { emit(item, n, from: p, maxPieces: 4, spread: 16) }
        if r.gem { showPickup("gem", sprite: "bloom_item_gem", amount: 1, color: UIColor(red: 0.6, green: 0.9, blue: 1, alpha: 1)) }
        if let (f, isNew) = game.rollFind(kind) { findFX(f, isNew: isNew, at: p) }
        for _ in 0..<10 { spark(at: CGPoint(x: p.x, y: p.y + 6), spread: 20, gold: true) }
        shake(1.8)
        buzz(medium)
        Sfx.play(.chest, volume: 0.7)
        happeningMeter += 2
        heldTool = ""
    }

    // MARK: - foes: dust creatures that roam the islands
    // They walk up to the hero; the hero fights them the same way it gathers: stand
    // close and the swings come by themselves. Losing all hearts costs nothing but a walk home.

    private struct FoeKind {
        let id: String, hp: Int, speed: CGFloat, dmg: Int, xp: Int, flies: Bool, frame: Double
    }
    private static let foeKinds: [String: FoeKind] = [
        "slime": FoeKind(id: "slime", hp: 4, speed: 20, dmg: 1, xp: 3, flies: false, frame: 0.28),
        "beetle": FoeKind(id: "beetle", hp: 12, speed: 17, dmg: 2, xp: 5, flies: false, frame: 0.16),
        "toad": FoeKind(id: "toad", hp: 16, speed: 28, dmg: 2, xp: 7, flies: false, frame: 0.35),
        "bat": FoeKind(id: "bat", hp: 10, speed: 34, dmg: 2, xp: 6, flies: true, frame: 0.12),
    ]
    private func foeKind(forIsland id: Int) -> String {
        if nightLevel > 0.6, game.level >= 8, Int.random(in: 0..<3) == 0 { return "bat" }
        switch id {
        case 2, 4, 5: return "beetle"
        case 7, 8, 9: return "toad"
        case 10, 11: return "bat"
        default: return "slime"
        }
    }

    private final class Foe {
        let kind: FoeKind
        let node: SKSpriteNode
        let shadow: SKSpriteNode
        let island: Int
        var hp: Int
        var pos: CGPoint
        let home: CGPoint
        var wander: CGPoint
        var wanderAt: TimeInterval = 0
        var knock = CGVector.zero
        var stunUntil: TimeInterval = 0
        init(kind: FoeKind, node: SKSpriteNode, shadow: SKSpriteNode, island: Int, hp: Int, pos: CGPoint) {
            self.kind = kind; self.node = node; self.shadow = shadow; self.island = island
            self.hp = hp; self.pos = pos; self.home = pos; self.wander = pos
        }
    }

    private var foes: [Foe] = []
    private var foeTimer: TimeInterval = 12
    private var hurtUntil: TimeInterval = 0
    private var lastHurt: TimeInterval = -100
    private var regenClock: TimeInterval = 0
    private var fainted = false
    private var foeIntroShown = UserDefaults.standard.bool(forKey: "dustbloom.foeIntro")

    private func updateFoes(_ dt: TimeInterval) {
        // health comes back on its own when nothing has hit you for a while
        if game.hp < game.maxHP, now - lastHurt > 8, !fainted {
            regenClock += dt
            if regenClock > 3 { regenClock = 0; game.hp += 1 }
        }
        guard game.foesOn || !foes.isEmpty else { return }
        foeTimer -= dt
        let cap = min(6, 1 + game.owned.count / 2)
        if foeTimer <= 0 {
            foeTimer = (nightLevel > 0.6 ? 14 : 28) * Double.random(in: 0.8...1.2)
            if foes.count < cap, game.foesOn, !fainted { spawnFoe() }
        }
        for f in foes { moveFoe(f, dt) }
    }

    private func spawnFoe(kind forced: String? = nil, near: Bool = false) {
        let cands = game.owned.flatMap { id in cells(of: id).filter(freeCell).map { ($0, id) } }.filter {
            let d = hypot(basePoint($0.0).x - heroPos.x, basePoint($0.0).y - heroPos.y)
            return near ? (d > 30 && d < 70) : (d > 50 && d < 120)
        }
        guard let pick = cands.randomElement(), let kind = Self.foeKinds[forced ?? foeKind(forIsland: pick.1)] else { return }
        let p = basePoint(pick.0)
        let t0 = tex("bloom_foe_\(kind.id)_0")
        let n = SKSpriteNode(texture: t0)
        n.anchorPoint = CGPoint(x: 0.5, y: kind.flies ? 0 : 1 / t0.size().height)
        n.position = p
        n.zPosition = 500 - p.y
        let sh = SKSpriteNode(texture: tex("bloom_shadow"))
        sh.position = CGPoint(x: p.x, y: p.y - 0.5)
        sh.zPosition = -800
        sh.setScale(0.8)
        world.addChild(sh)
        world.addChild(n)
        n.run(.repeatForever(.animate(with: [t0, tex("bloom_foe_\(kind.id)_1")], timePerFrame: kind.frame)), withKey: "anim")
        // tougher on later islands
        let hp = Int((Double(kind.hp) * (1 + Double(pick.1) * 0.4)).rounded())
        foes.append(Foe(kind: kind, node: n, shadow: sh, island: pick.1, hp: hp, pos: p))
        // rises out of the dust
        n.setScale(0.1); n.alpha = 0
        n.run(.group([.fadeIn(withDuration: 0.25), .sequence([.scale(to: 1.2, duration: 0.18), .scale(to: 1, duration: 0.1)])]))
        puff(at: p, n: 6)
        if !foeIntroShown {
            foeIntroShown = true
            UserDefaults.standard.set(true, forKey: "dustbloom.foeIntro")
            game.showToast(BloomToast(title: tr("Пыльные создания!"), subtitle: tr("Подойди и бей их, как ресурсы")))
        }
    }

    private func moveFoe(_ f: Foe, _ dt: TimeInterval) {
        let dx = heroPos.x - f.pos.x, dy = heroPos.y - f.pos.y
        let d = hypot(dx, dy)
        var v = CGVector.zero
        if now >= f.stunUntil {
            if d < 75, !fainted {
                v = CGVector(dx: dx / max(d, 0.1) * f.kind.speed, dy: dy / max(d, 0.1) * f.kind.speed)
            } else {
                if now > f.wanderAt || hypot(f.wander.x - f.pos.x, f.wander.y - f.pos.y) < 2 {
                    f.wanderAt = now + Double.random(in: 2...4)
                    f.wander = CGPoint(x: f.home.x + CGFloat.random(in: -24...24), y: f.home.y + CGFloat.random(in: -16...16))
                }
                let wx = f.wander.x - f.pos.x, wy = f.wander.y - f.pos.y, wd = max(0.1, hypot(wx, wy))
                v = CGVector(dx: wx / wd * f.kind.speed * 0.45, dy: wy / wd * f.kind.speed * 0.45)
            }
        }
        v.dx += f.knock.dx; v.dy += f.knock.dy
        f.knock.dx *= 0.82; f.knock.dy *= 0.82
        let step = CGPoint(x: f.pos.x + v.dx * CGFloat(dt), y: f.pos.y + v.dy * CGFloat(dt))
        if f.kind.flies {
            f.pos = step
        } else {
            if canStand(CGPoint(x: step.x, y: f.pos.y)) { f.pos.x = step.x }
            if canStand(CGPoint(x: f.pos.x, y: step.y)) { f.pos.y = step.y }
        }
        if abs(v.dx) > 2 { f.node.xScale = abs(f.node.xScale) * (v.dx > 0 ? 1 : -1) }
        let bob: CGFloat = f.kind.flies ? 8 + sin(CGFloat(now) * 6 + f.home.x) * 2 : 0
        f.node.position = CGPoint(x: (f.pos.x * zoom).rounded() / zoom, y: ((f.pos.y + bob) * zoom).rounded() / zoom)
        f.node.zPosition = 500 - f.pos.y
        f.shadow.position = CGPoint(x: f.pos.x, y: f.pos.y - 0.5)
        // touch hurts the hero
        if d < 7, now >= f.stunUntil, now >= hurtUntil, !fainted { hurtHero(f) }
    }

    private func nearestFoe(within r: CGFloat) -> Foe? {
        foes.filter { $0.hp > 0 && hypot($0.pos.x - heroPos.x, $0.pos.y - heroPos.y) < r }
            .min { hypot($0.pos.x - heroPos.x, $0.pos.y - heroPos.y) < hypot($1.pos.x - heroPos.x, $1.pos.y - heroPos.y) }
    }

    private func swingAt(_ f: Foe) {
        hitTimer = 0
        swinging = true
        let tool = "bloom_pick_\(game.pickTier)"
        if heldTool != tool { heldTool = tool; pickNode.texture = tex(tool) }
        if abs(f.pos.x - heroPos.x) > 1 { facing = f.pos.x > heroPos.x ? 1 : -1 }
        heroSprite.xScale = facing
        pickNode.run(.sequence([
            .rotate(toAngle: 0.9, duration: 0.06),
            .rotate(toAngle: -1.5, duration: 0.05),
            .run { [weak self] in self?.hitFoe(f) },
            .rotate(toAngle: -0.5, duration: 0.1),
            .run { [weak self] in self?.swinging = false },
        ]))
        heroSprite.run(.sequence([.scaleY(to: 0.9, duration: 0.05), .scaleY(to: 1, duration: 0.09)]))
    }

    private func hitFoe(_ f: Foe) {
        guard f.hp > 0, foes.contains(where: { $0 === f }) else { return }
        let crit = Double.random(in: 0..<1) < game.critChance
        let dmg = crit ? game.damage * 2 + 1 : game.damage
        f.hp -= dmg
        if logFPS { print("[foe] hit \(f.kind.id) for \(dmg)\(crit ? " crit" : ""), hp left \(f.hp)") }
        let dx = f.pos.x - heroPos.x, dy = f.pos.y - heroPos.y, d = max(0.1, hypot(dx, dy))
        f.knock = CGVector(dx: dx / d * 140, dy: dy / d * 140)
        f.stunUntil = now + 0.35
        f.node.run(.sequence([.colorize(with: .white, colorBlendFactor: 0.85, duration: 0),
                              .colorize(withColorBlendFactor: 0, duration: 0.12)]), withKey: "flash")
        let sx: CGFloat = f.node.xScale < 0 ? -1 : 1
        f.node.run(.sequence([.scaleX(to: 1.25 * sx, y: 0.8, duration: 0.05), .scaleX(to: sx, y: 1, duration: 0.1)]), withKey: "squash")
        floatText("\(dmg)", at: CGPoint(x: f.pos.x, y: f.pos.y + 16), color: crit ? UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1) : .white,
                  size: crit ? 7 : 5.5, rise: 10)
        for _ in 0..<4 { spark(at: CGPoint(x: f.pos.x, y: f.pos.y + 6), spread: 14) }
        shake(crit ? 2.4 : 1.2)
        buzz(light, 0.7)
        Sfx.playThrottled(.hit, gap: 0.05, volume: 0.7)
        if f.hp <= 0 { killFoe(f) }
    }

    private func killFoe(_ f: Foe) {
        if logFPS { print("[foe] killed \(f.kind.id)") }
        foes.removeAll { $0 === f }
        let p = f.pos
        f.node.removeAllActions()
        f.node.run(.sequence([.group([.scale(to: 1.4, duration: 0.08), .fadeAlpha(to: 0.6, duration: 0.08)]),
                              .group([.scale(to: 0.1, duration: 0.12), .fadeOut(withDuration: 0.12)]), .removeFromParent()]))
        f.shadow.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        puff(at: p, n: 10)
        for _ in 0..<8 { spark(at: CGPoint(x: p.x, y: p.y + 6), spread: 20, gold: true) }
        shake(2.2)
        buzz(medium)
        Sfx.play(.poof, volume: 0.8)
        emit(nil, Int.random(in: 2...4) + f.island * 2, from: p, maxPieces: 4, spread: 14)
        for (item, n) in game.roll(randomKind(f.island), mult: 1) { emit(item, n, from: p) }
        _ = game.gainXP(f.kind.xp + f.island)
        game.bump("kill")
        happeningMeter += 1
    }

    private func hurtHero(_ f: Foe) {
        hurtUntil = now + 1.1
        lastHurt = now
        regenClock = 0
        game.hp = max(0, game.hp - f.kind.dmg)
        if logFPS { print("[foe] \(f.kind.id) hurts hero: hp \(game.hp)/\(game.maxHP)") }
        // push the hero back and the foe away
        let dx = heroPos.x - f.pos.x, dy = heroPos.y - f.pos.y, d = max(0.1, hypot(dx, dy))
        vel = CGVector(dx: dx / d * 120, dy: dy / d * 120)
        f.knock = CGVector(dx: -dx / d * 80, dy: -dy / d * 80)
        f.stunUntil = now + 0.5
        heroSprite.run(.sequence([.colorize(with: UIColor(red: 1, green: 0.25, blue: 0.25, alpha: 1), colorBlendFactor: 0.8, duration: 0),
                                  .colorize(withColorBlendFactor: 0, duration: 0.25)]), withKey: "hurt")
        hero.run(.repeat(.sequence([.fadeAlpha(to: 0.35, duration: 0.09), .fadeAlpha(to: 1, duration: 0.09)]), count: 5), withKey: "blink")
        shake(3)
        buzz(heavy)
        Sfx.play(.defeat, volume: 0.35)
        if game.hp <= 0 { faint() }
    }

    /// Out of hearts: the hero flops, then wakes up at home with full health. Nothing is lost.
    private func faint() {
        if logFPS { print("[foe] hero fainted") }
        fainted = true
        vel = .zero
        hero.removeAction(forKey: "blink")
        hero.run(.sequence([
            .group([.rotate(toAngle: -facing * 1.3, duration: 0.25), .fadeAlpha(to: 0.5, duration: 0.25)]),
            .wait(forDuration: 0.8),
            .fadeOut(withDuration: 0.2),
            .run { [weak self] in
                guard let self else { return }
                self.heroPos = self.spawnPoint()
                self.hero.position = self.heroPos
                self.cam.position = self.heroPos
                self.hero.zRotation = 0
                self.game.hp = self.game.maxHP
                // wake up in peace: anything waiting at home crumbles back into dust
                for f in self.foes where hypot(f.pos.x - self.heroPos.x, f.pos.y - self.heroPos.y) < 90 {
                    self.foes.removeAll { $0 === f }
                    self.puff(at: f.pos, n: 6)
                    f.node.run(.sequence([.group([.scale(to: 0.1, duration: 0.15), .fadeOut(withDuration: 0.15)]), .removeFromParent()]))
                    f.shadow.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
                }
                self.foeTimer = max(self.foeTimer, 20)
                self.fainted = false
                self.hurtUntil = self.now + 2
                self.puff(at: self.heroPos, n: 8)
            },
            .fadeIn(withDuration: 0.3),
        ]))
        game.showToast(BloomToast(title: tr("Ты устал"), subtitle: tr("Отдохнул дома, все сердца снова целы")))
        game.bump("faint")
    }

    // MARK: - golden hour (our own event: everything turns gold, drops double)

    private let goldOverlay = SKSpriteNode()
    private var goldenNext: TimeInterval = 75
    private var goldenLeft: TimeInterval = 0
    private var petalClock: TimeInterval = 0

    private func updateGolden(_ dt: TimeInterval) {
        if goldenLeft > 0 {
            goldenLeft -= dt
            petalClock += dt
            while petalClock > 0.06 {
                petalClock -= 0.06
                let p = CGPoint(x: cam.position.x + CGFloat.random(in: -70...70), y: cam.position.y + 150)
                let coin = Int.random(in: 0..<3) == 0
                let n = SKSpriteNode(texture: tex(coin ? "bloom_item_coin" : "bloom_fx_petal"))
                n.setScale(coin ? 0.45 : 1)
                n.position = p
                n.zPosition = 3900
                world.addChild(n)
                let fall = CGFloat.random(in: 40...60)
                n.run(.sequence([.group([.moveBy(x: CGFloat.random(in: -30...30), y: -300, duration: Double(300 / fall)),
                                         .rotate(byAngle: CGFloat.random(in: -6...6), duration: Double(300 / fall))]),
                                 .removeFromParent()]))
            }
            if goldenLeft <= 0 { endGolden() }
            return
        }
        goldenNext -= dt
        if goldenNext <= 0 { startGolden() }
    }

    // MARK: - guide arrow (show, don't tell: points at what the current goal needs)

    private let guide = SKSpriteNode()
    private let guideHolder = SKNode()
    private var guideClock: TimeInterval = 0
    private var lastHeroHits = 0
    private var idleTime: TimeInterval = 0

    private func updateGuide(_ dt: TimeInterval) {
        if guide.parent == nil {
            guide.texture = tex("bloom_ui_arrow")
            guide.size = guide.texture!.size()
            guideHolder.zPosition = 3500
            guideHolder.alpha = 0
            world.addChild(guideHolder)
            guideHolder.addChild(guide)
            guide.run(.repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 0.35), .moveBy(x: 0, y: -3, duration: 0.35)])))
        }
        // only while learning (first goals) or when the player seems stuck
        idleTime = heroHits == lastHeroHits ? idleTime + dt : 0
        lastHeroHits = heroHits
        guideClock += dt
        guard guideClock > 0.4 else { return }
        guideClock = 0
        let show = game.panel == nil && (game.goalIndex < 8 || idleTime > 8)
        let p = show ? guideTarget() : nil
        if let p {
            if guideHolder.alpha == 0 { guideHolder.position = p } else {
                guideHolder.run(.move(to: p, duration: 0.25), withKey: "move")
            }
            guideHolder.run(.fadeAlpha(to: 1, duration: 0.2), withKey: "fade")
        } else if guideHolder.alpha > 0 {
            guideHolder.run(.fadeAlpha(to: 0, duration: 0.25), withKey: "fade")
        }
    }

    private func guideTarget() -> CGPoint? {
        guard let g = game.goal, !game.goalDone else { return nil }
        let kinds: [GatherKind]
        if g.key == "gather.tree" { kinds = [.tree, .pine, .palm] }
        else if g.key == "gather.rock" { kinds = [.rock, .rock_iron, .rock_gold] }
        else if g.key.hasPrefix("item."), let it = BItem(rawValue: String(g.key.dropFirst(5))) {
            kinds = GatherKind.allCases.filter { $0.drops.contains { $0.item == it } }
        } else if g.key == "islands" {
            let near = signs.values.min { hypot($0.position.x - heroPos.x, $0.position.y - heroPos.y) < hypot($1.position.x - heroPos.x, $1.position.y - heroPos.y) }
            return near.map { CGPoint(x: $0.position.x, y: $0.position.y + 26) }
        } else { return nil }
        let best = res.values.filter { kinds.contains($0.kind) }
            .min { hypot($0.node.position.x - heroPos.x, $0.node.position.y - heroPos.y) < hypot($1.node.position.x - heroPos.x, $1.node.position.y - heroPos.y) }
        guard let b = best, hypot(b.node.position.x - heroPos.x, b.node.position.y - heroPos.y) > 14 else { return nil }
        return CGPoint(x: b.node.position.x, y: b.node.position.y + b.node.size.height + 2)
    }

    private func startGolden(duration: Double? = nil) {
        let d = duration ?? game.goldenDuration
        if goldenLeft > 0 {  // already golden: just make it last longer
            goldenLeft += d
            game.goldenUntil = Date().addingTimeInterval(goldenLeft)
            Sfx.play(.sparkle)
            return
        }
        goldenLeft = d
        game.goldenUntil = Date().addingTimeInterval(d)
        goldOverlay.run(.fadeAlpha(to: 0.16, duration: 0.8))
        world.run(.sequence([.wait(forDuration: 0.2), .run { [weak self] in self?.spawnChest(near: true) }]))
        shake(2)
        buzz(heavy)
        Sfx.play(.victory)
        Sfx.play(.sparkle, after: 0.4)
    }

    private func endGolden() {
        goldenLeft = 0
        goldenNext = GoldenHour.every
        game.goldenUntil = nil
        goldOverlay.run(.fadeAlpha(to: 0, duration: 1.2))
    }

    private func talentsChanged() {
        for (_, s) in signs { s.removeFromParent() }
        signs.removeAll()
        for i in game.world.bridges.indices { refreshBridge(i) }
        for _ in 0..<20 { petal(at: CGPoint(x: heroPos.x + CGFloat.random(in: -10...10), y: heroPos.y + 6)) }
    }

    // MARK: - goals

    private func goalFX() {
        for i in 0..<28 {
            let a = CGFloat(i) / 28 * 2 * .pi
            particle(i % 2 == 0 ? "bloom_fx_petal" : "bloom_fx_spark", at: CGPoint(x: heroPos.x, y: heroPos.y + 10),
                     v: CGVector(dx: cos(a) * 34, dy: sin(a) * 34 + 14), life: 0.8)
        }
        shake(2)
        buzz(heavy)
    }

    // MARK: - helpers (Bloomlings)

    private final class Helper {
        let color: String
        let node = SKSpriteNode()
        let shadow = SKSpriteNode()
        var pos: CGPoint
        weak var target: Res?
        var hitTimer: TimeInterval = 0
        var clock: TimeInterval = 0
        init(color: String, pos: CGPoint) { self.color = color; self.pos = pos }
    }
    private var helpers: [Helper] = []

    private func addHelper(_ color: String, animated: Bool) {
        let h = Helper(color: color, pos: CGPoint(x: heroPos.x + CGFloat.random(in: -10...10), y: heroPos.y - 6))
        h.node.texture = tex("bloom_helper_\(color)_idle_0")
        h.node.size = h.node.texture!.size()
        h.node.anchorPoint = CGPoint(x: 0.5, y: 2 / 16)
        h.shadow.texture = tex("bloom_shadow")
        h.shadow.size = CGSize(width: 9, height: 3)
        h.shadow.zPosition = -800
        world.addChild(h.shadow)
        world.addChild(h.node)
        helpers.append(h)
        if animated {
            pop(h.node, delay: 0)
            for _ in 0..<14 { petal(at: CGPoint(x: h.pos.x, y: h.pos.y + 6)) }
            shake(2)
        }
    }

    private func updateHelpers(_ dt: TimeInterval) {
        let heroTarget = target()
        for (i, h) in helpers.enumerated() {
            h.clock += dt
            h.hitTimer += dt
            if let t = h.target, res[t.cell] !== t { h.target = nil }
            if h.target == nil {
                var best: Res?
                var bd: CGFloat = 70
                let taken = Set(helpers.compactMap { $0.target.map { ObjectIdentifier($0) } })
                for r in res.values where r !== heroTarget && !taken.contains(ObjectIdentifier(r)) {
                    let d = hypot(r.node.position.x - heroPos.x, r.node.position.y - heroPos.y)
                    if d < bd { bd = d; best = r }
                }
                h.target = best
            }
            var goal: CGPoint
            var working = false
            if let t = h.target {
                let side: CGFloat = h.pos.x < t.node.position.x ? -7 : 7
                goal = CGPoint(x: t.node.position.x + side, y: t.node.position.y)
                working = hypot(goal.x - h.pos.x, goal.y - h.pos.y) < 2.5
            } else {
                let a = CGFloat(i) * 2.1 + 2.4
                goal = CGPoint(x: heroPos.x + cos(a) * 14, y: heroPos.y + sin(a) * 9)
            }
            let d = CGVector(dx: goal.x - h.pos.x, dy: goal.y - h.pos.y)
            let l = hypot(d.dx, d.dy)
            let moving = l > 2.5
            if moving {
                let sp: CGFloat = min(l * 4, 46 * game.helperSpeed) * CGFloat(dt)
                let np = CGPoint(x: h.pos.x + d.dx / l * sp, y: h.pos.y + d.dy / l * sp)
                let c = Cell(x: Int(floor(np.x / T)), y: Int(floor(np.y / T)))
                if land.contains(c) { h.pos = np } else { h.target = nil }
                if abs(d.dx) > 0.5 { h.node.xScale = d.dx > 0 ? 1 : -1 }
                h.node.texture = tex("bloom_helper_\(h.color)_run_\(Int(h.clock * 8) % 2)")
            } else {
                h.node.texture = tex("bloom_helper_\(h.color)_idle_\(Int(h.clock * 2) % 2)")
            }
            let golden = h.color == "gold"
            if working, let t = h.target, h.hitTimer > (golden ? 0.6 : 0.9) {
                h.hitTimer = 0
                h.node.xScale = t.node.position.x > h.pos.x ? 1 : -1
                h.node.run(.sequence([.moveBy(x: 0, y: 2, duration: 0.06), .moveBy(x: 0, y: -2, duration: 0.08)]))
                var dmg = game.helperDamage * (golden ? 2 : 1)
                if game.hasT("h5"), Double.random(in: 0..<1) < 0.12 {
                    dmg *= 2
                    floatText(tr("крит"), at: CGPoint(x: t.node.position.x, y: t.node.position.y + 16), color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), size: 4.5, rise: 8)
                }
                applyHit(t, dmg: dmg, mult: 1, dir: h.node.xScale)
            }
            if hypot(h.pos.x - heroPos.x, h.pos.y - heroPos.y) > 90 {
                // lost behind water: hop back to the hero with a puff
                puff(at: h.pos, n: 5)
                h.pos = CGPoint(x: heroPos.x + CGFloat.random(in: -6...6), y: heroPos.y - 4)
                h.target = nil
                puff(at: h.pos, n: 5)
            }
            h.node.position = CGPoint(x: (h.pos.x * zoom).rounded() / zoom, y: (h.pos.y * zoom).rounded() / zoom)
            h.node.zPosition = 500 - h.pos.y
            h.shadow.position = CGPoint(x: h.node.position.x, y: h.node.position.y - 0.5)
        }
    }

    // MARK: - demo autopilot (video capture without touching the screen)

    private var demoPause: TimeInterval = 0
    private var demoCheckAt: TimeInterval = 0
    private var demoCheckPos = CGPoint.zero
    private var demoDetour = CGVector.zero
    private var demoDetourUntil: TimeInterval = 0
    private var demoDetourSign: CGFloat = 1
    private var demoSign: Int?                       // sign the autopilot is walking to
    private var demoBestDist: CGFloat = .infinity
    private var demoBestAt: TimeInterval = 0
    private var demoSkip: [Int: TimeInterval] = [:]  // signs it couldn't reach, ignored until the time
    private var demoMarketAt: TimeInterval = 0
    private func autopilot() {
        if game.panel != nil { stickVec = .zero; return }
        if now < demoPause { stickVec = .zero; return }
        if game.goalDone { game.claimGoal(); demoPause = now + 1.2; return }
        for k in [BuildKind.furnace, .market, .anvil, .nursery] where !game.isBuilt(k) && game.canBuild(k) {
            game.build(k); demoPause = now + 1; return
        }
        if game.isBuilt(.nursery) && game.canGrowHelper {
            game.panel = .building(.nursery)
            demoPause = now + 1.8
            run(.sequence([.wait(forDuration: 0.8), .run { [weak self] in self?.game.growHelper() }]))
            return
        }
        if !game.isBuilt(.market) && game.canBuild(.market) {
            game.build(.market); demoPause = now + 1; return
        }
        // keep what the nursery and the next Bloomling need, sell the rest
        let saving = game.s.level >= BuildKind.nursery.unlockLevel
        let keepWood = saving && !game.isBuilt(.nursery) ? 28 : 8
        let keepBerry = saving ? 12 + game.helpers.count * 10 + 10 : 0
        let keepFlower = saving ? 4 + game.helpers.count * 4 : 0
        if game.isBuilt(.market), now > demoMarketAt, !ProcessInfo.processInfo.arguments.contains("-bloomShowcase"), game.count(.wood) - keepWood + game.count(.berry) - keepBerry > 16 {
            demoMarketAt = now + 20
            game.panel = .building(.market)
            demoPause = now + 1.6
            run(.sequence([.wait(forDuration: 0.7), .run { [weak self] in
                guard let g = self?.game else { return }
                for (item, keep) in [(BItem.berry, keepBerry), (.flower, keepFlower), (.wood, keepWood)] where g.count(item) > keep {
                    for _ in 0..<(g.count(item) - keep) { g.sell(item, all: false) }
                }
            }, .wait(forDuration: 0.8), .run { [weak self] in self?.game.panel = nil }]))
            return
        }
        if game.isBuilt(.furnace), game.queue(for: .furnace)?.left ?? 0 == 0, game.count(.stone) >= 9,
           let r = BuildKind.furnace.recipes.first {
            game.craft(.furnace, r, times: 3)
        }
        // go buy the cheapest island we can afford
        var goal: CGPoint?
        var sign: Int?
        var bestPrice = Int.max
        for (i, s) in signs where (demoSkip[i] ?? 0) < now {
            let b = game.world.bridges[i]
            let id = game.owned.contains(b.a) ? b.b : b.a
            let price = game.islandPrice(id)
            guard game.coins >= price, price < bestPrice else { continue }
            if hypot(s.position.x - heroPos.x, s.position.y - heroPos.y) < 26 {  // same reach as the context button
                game.buy(id); demoPause = now + 2.5; return
            }
            bestPrice = price; goal = s.position; sign = i
        }
        if sign != demoSign { demoSign = sign; demoBestDist = .infinity; demoBestAt = now }
        if let i = sign, let g = goal {
            // a sign across the water can't be reached in a straight line: give up on it for a while
            let dist = hypot(g.x - heroPos.x, g.y - heroPos.y)
            if dist < demoBestDist - 4 { demoBestDist = dist; demoBestAt = now }
            else if now - demoBestAt > 4 { demoSkip[i] = now + 25; demoSign = nil; return }
        }
        if goal == nil, let ch = chests.first { goal = ch.node.position }
        if goal == nil, game.hasShovel, let d = digSpots.first { goal = d.node.position }
        // show off fishing: walk to a pond nearby and stand next to it
        if goal == nil, now > fishCooldown {
            let hc = heroCell
            if let pond = res.values.filter({ $0.kind == .pond && abs($0.cell.x - hc.x) + abs($0.cell.y - hc.y) <= 8 })
                .min(by: { hypot($0.node.position.x - heroPos.x, $0.node.position.y - heroPos.y)
                    < hypot($1.node.position.x - heroPos.x, $1.node.position.y - heroPos.y) }) {
                let d = hypot(pond.node.position.x - heroPos.x, pond.node.position.y - heroPos.y)
                if d < 14 { stickVec = .zero; startFishing(pond); return }
                goal = pond.node.position
            }
        }
        if goal == nil, target() == nil {
            let hc = heroCell
            goal = res.values.min { a, b in
                hypot(CGFloat(a.cell.x - hc.x), CGFloat(a.cell.y - hc.y)) < hypot(CGFloat(b.cell.x - hc.x), CGFloat(b.cell.y - hc.y))
            }?.node.position
        }
        guard let g = goal else { stickVec = .zero; return }
        // straight-line walking can pin the hero against a building: sidestep when stuck
        if now < demoDetourUntil { stickVec = demoDetour; return }
        let d = CGVector(dx: g.x - heroPos.x, dy: g.y - heroPos.y)
        let l = hypot(d.dx, d.dy)
        stickVec = l < 8 ? .zero : CGVector(dx: d.dx / l, dy: d.dy / l)
        if now - demoCheckAt > 0.5 {
            let moved = hypot(heroPos.x - demoCheckPos.x, heroPos.y - demoCheckPos.y)
            if stickVec != .zero, moved < 3 {
                demoDetourSign = -demoDetourSign
                demoDetour = CGVector(dx: -stickVec.dy * demoDetourSign, dy: stickVec.dx * demoDetourSign)
                demoDetourUntil = now + 0.7
            }
            demoCheckAt = now
            demoCheckPos = heroPos
        }
    }
}

private extension CGPoint {
    var rounded: CGPoint { CGPoint(x: x.rounded(), y: y.rounded()) }
}
