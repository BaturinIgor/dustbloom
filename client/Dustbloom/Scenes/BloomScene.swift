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
    private var comboLabel: SKLabelNode?

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

    // MARK: - setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0x4f / 255, green: 0xc4 / 255, blue: 0xec / 255, alpha: 1)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        view.ignoresSiblingOrder = true
        view.isMultipleTouchEnabled = false
        if game != nil { setUp() }
    }

    private func setUp() {
        guard !built else { return }
        built = true
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
        for c in game.helpers { addHelper(c, animated: false) }
        if game.isFounder { addHelper("gold", animated: false) }
        if ProcessInfo.processInfo.arguments.contains("-bloomDemo") {
            run(.sequence([.wait(forDuration: 6), .run { [weak self] in self?.spawnChest(near: true) }]))
        }
    }

    private func spawnPoint() -> CGPoint {
        // centre of the start island, nearest free cell
        let cs = cells(of: 0)
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
        res[c] == nil && buildingNodes[c] == nil && flowers[c] == nil && !nearBridge.contains(c) && land.contains(c) && !bridgeCells.contains(c)
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
        if animated {
            n.position.y += 30
            n.alpha = 0
            n.run(.sequence([.group([.fadeIn(withDuration: 0.1), .moveBy(x: 0, y: -30, duration: 0.22)]),
                             .run { [weak self] in self?.puff(at: p, n: 8); self?.shake(2.5) },
                             .scaleX(to: 1.25, y: 0.8, duration: 0.07), .scale(to: 1, duration: 0.12)]))
            heavy.impactOccurred()
            Sfx.play(.fence)
        }
    }

    private func crafted(_ k: BuildKind, _ item: BItem, _ lucky: Bool) {
        if k == .anvil {
            pickNode.texture = tex("bloom_pick_\(game.pickTier)")
            for _ in 0..<(lucky ? 26 : 12) { spark(at: CGPoint(x: heroPos.x, y: heroPos.y + 10), spread: lucky ? 22 : 12, gold: true) }
            heavy.impactOccurred()
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
        heavy.impactOccurred()
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

    private func floatText(_ s: String, at p: CGPoint, color: UIColor = .white, size: CGFloat = 6, rise: CGFloat = 12) {
        let l = label(s, size: size, color: color)
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
        let dt = last == 0 ? 1 / 60 : min(1 / 20, currentTime - last)
        last = currentTime
        now += dt
        if logFPS {
            fpsFrames += 1; fpsClock += dt
            if fpsClock >= 2 { print(String(format: "[bloom] fps %.1f nodes %d", Double(fpsFrames) / fpsClock, world.children.count)); fpsFrames = 0; fpsClock = 0 }
        }
        if demo { autopilot() }
        moveHero(dt)
        mine(dt)
        updateDrops(dt)
        updateGolden(dt)
        updateHelpers(dt)
        checkChest()
        game.tick(dt: dt)
        game.tickCombo(now: now)
        updateCombo()
        updateGuide(dt)

        spawnTimer += dt
        if spawnTimer > game.respawnInterval {
            spawnTimer = 0
            respawnOne()
        }
        nearbyTimer += dt
        if nearbyTimer > 0.15 { nearbyTimer = 0; updateNearby() }
        saveTimer += dt
        if saveTimer > 10 { saveTimer = 0; game.save() }

        // camera
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
        let len = hypot(stickVec.dx, stickVec.dy)
        let moving = len > 0.15
        animClock += dt
        if moving {
            let speed: CGFloat = 54 * game.runSpeed * min(1, len * 1.35)
            let d = CGVector(dx: stickVec.dx / len * speed * CGFloat(dt), dy: stickVec.dy / len * speed * CGFloat(dt))
            var p = heroPos
            let px = CGPoint(x: p.x + d.dx, y: p.y)
            if canStand(px) { p = px }
            let py = CGPoint(x: p.x, y: p.y + d.dy)
            if canStand(py) { p = py }
            heroPos = p
            if abs(stickVec.dx) > 0.2 { facing = stickVec.dx > 0 ? 1 : -1 }
            let f = Int(animClock * 10) % 4
            heroSprite.texture = tex(game.heroPrefix + "run_\(f)")
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
            heroSprite.texture = tex(game.heroPrefix + (Int(animClock * 2) % 2 == 0 ? "idle_0" : "idle_1"))
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
                light.impactOccurred()
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
        guard !swinging, hitTimer >= 0.3, let r = target() else { return }
        hitTimer = 0
        swinging = true
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
        let dmg = crit ? game.damage * 2 + 1 : game.damage
        if crit { critFX(r) }
        heroHits += 1
        if game.hasT("d5"), heroHits % 15 == 0 { quake(dmg: dmg, mult: mult) }
        applyHit(r, dmg: dmg, mult: mult, dir: facing)
    }

    private var heroHits = 0

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
        heavy.impactOccurred()
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
        let l = label(tr("КРИТ!"), size: 7, color: UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1))
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
        shake(2.2)
        heavy.impactOccurred()
        Sfx.play(.skill, volume: 0.7)
    }

    private func applyHit(_ r: Res, dmg: Int, mult: Int, dir: CGFloat) {
        guard res[r.cell] === r else { return }
        let facing = dir
        r.hp -= dmg
        let hp = CGPoint(x: r.node.position.x - facing * 3, y: r.node.position.y + r.node.size.height * 0.45)
        r.node.removeAction(forKey: "hit")
        r.node.run(.sequence([
            .group([.scaleX(to: 1.15, y: 0.88, duration: 0.05), .moveBy(x: facing * 1.2, y: 0, duration: 0.05)]),
            .group([.scale(to: 1, duration: 0.1), .moveBy(x: -facing * 1.2, y: 0, duration: 0.1)]),
        ]), withKey: "hit")
        for _ in 0..<3 { spark(at: hp) }
        for _ in 0..<3 {
            particle(r.kind.isStone ? "bloom_fx_chip" : "bloom_fx_leaf", at: hp,
                     v: CGVector(dx: CGFloat.random(in: -16...16), dy: CGFloat.random(in: 6...20)), life: 0.5)
        }
        if now - hitHaptic > 0.08 { light.impactOccurred(intensity: 0.6); hitHaptic = now }
        Sfx.playThrottled(.hit, gap: 0.06, volume: 0.6)
        if r.hp <= 0 {
            destroy(r, mult: mult)
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

    private func destroy(_ r: Res, mult: Int) {
        res[r.cell] = nil
        let p = r.node.position
        r.node.removeAllActions()
        r.node.run(.sequence([.group([.scale(to: 0.1, duration: 0.12), .fadeOut(withDuration: 0.12)]), .removeFromParent()]))
        r.shadow.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        puff(at: p, n: 9)
        shake(1.2)
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
        medium.impactOccurred()
        Sfx.playThrottled(.poof, gap: 0.08, volume: 0.7)
        for (item, n) in game.roll(r.kind, mult: mult) { emit(item, n, from: p) }
        let c = game.rollCoins(r.kind, mult: mult)
        if c > 0 { emit(nil, c, from: p) }
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
            n.run(.sequence([.wait(forDuration: dur), .scaleX(to: 0.95, y: 0.6, duration: 0.05), .scale(to: 0.75, duration: 0.08)]))
            drops.append(DropNode(node: n, item: item, amount: amount, readyAt: now + dur + 0.15))
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
        var total = amount
        if let old = pickupLabels[key], now - old.at < 0.6 {
            total += old.total
            old.node.removeFromParent()
        }
        let slot = CGFloat(pickupLabels.filter { $0.key != key && now - $0.value.at < 0.6 }.count)
        let n = SKNode()
        n.position = CGPoint(x: 0, y: 30 + slot * 9)
        n.zPosition = 3000
        let ic = SKSpriteNode(texture: tex(sprite))
        ic.setScale(0.6)
        ic.position = CGPoint(x: -6, y: 2.5)
        n.addChild(ic)
        let l = label("+\(total)", size: 5.5, color: color)
        l.horizontalAlignmentMode = .left
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
        heroSprite.run(.sequence([.scaleY(to: 1.1, duration: 0.04), .scaleY(to: 1, duration: 0.06)]))
    }

    private func updateCombo() {
        let step = game.comboStep
        if game.combo >= BloomContent.hitsPerStep {
            let text = "×\(step)"
            if comboLabel == nil || comboLabel?.name != text {
                comboLabel?.removeFromParent()
                let l = label(text, size: 7, color: UIColor(red: 1, green: 0.82, blue: 0.25, alpha: 1))
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
        if chest == nil, now >= chestFreeAt, Double.random(in: 0..<1) < game.chestChance {
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

    private var chest: (cell: Cell, node: SKSpriteNode)?

    private func spawnChest(near: Bool = false) {
        let owned = game.owned.sorted()
        var cands: [Cell] = []
        for id in owned { cands += cells(of: id).filter(freeCell) }
        cands = cands.filter { hypot(basePoint($0).x - heroPos.x, basePoint($0).y - heroPos.y) > (near ? 16 : 30) }
        if near { cands = cands.filter { hypot(basePoint($0).x - heroPos.x, basePoint($0).y - heroPos.y) < 70 } }
        guard let c = cands.randomElement() else { return }
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
        chest = (c, n)
        for _ in 0..<8 { spark(at: CGPoint(x: p.x, y: p.y + 6), spread: 16, gold: false) }
        Sfx.play(.sparkle, volume: 0.6)
    }

    private func checkChest() {
        guard let ch = chest, hypot(ch.node.position.x - heroPos.x, ch.node.position.y - heroPos.y) < 11 else { return }
        chest = nil
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
                self.heavy.impactOccurred()
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
        heavy.impactOccurred()
        Sfx.play(isNew ? .chest : .coin)
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
        heavy.impactOccurred()
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
        heavy.impactOccurred()
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
        if game.isBuilt(.market), game.count(.wood) - keepWood + game.count(.berry) - keepBerry > 16 {
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
        if goal == nil, let ch = chest { goal = ch.node.position }
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
