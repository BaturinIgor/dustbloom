import SpriteKit

/// Ambient life: chimney smoke, fireflies over the grass, dust drifting over
/// the wasteland. Cheap sprite actions, capped so they never pile up.
extension FarmScene {
    /// Chimney top above the manor's front corner, in points, per tier
    /// (art/hd/iso_objects.py MANOR); tier 0 is a hut without a chimney.
    static let chimneyTop: [CGPoint?] = [
        nil, CGPoint(x: 6, y: 141), CGPoint(x: 7, y: 151), CGPoint(x: 7, y: 158),
        CGPoint(x: 7, y: 174), CGPoint(x: 8, y: 183),
    ]

    func chimneySmoke(on house: SKSpriteNode) {
        let puff = SKAction.run { [weak self, weak house] in
            guard let self, let house, Self.chimneyTop.indices.contains(self.manorShownTier),
                  let origin = Self.chimneyTop[self.manorShownTier] else { return }
            let s = SKSpriteNode(texture: Textures.named("fx_smoke"), size: CGSize(width: 8 * 3, height: 8 * 3))
            s.position = origin
            s.zPosition = 0.002
            s.alpha = 0.85
            s.setScale(0.6)
            house.addChild(s)
            let rise = SKAction.moveBy(x: CGFloat.random(in: 12...26), y: CGFloat.random(in: 60...80), duration: 2.6)
            rise.timingMode = .easeOut
            s.run(.sequence([.group([rise, .scale(to: 1.6, duration: 2.6), .fadeOut(withDuration: 2.6)]), .removeFromParent()]))
        }
        house.run(.repeatForever(.sequence([puff, .wait(forDuration: 0.8, withRange: 0.4)])))
    }

    func startAmbience(layout: FarmLayout) {
        let spawn = SKAction.run { [weak self] in self?.spawnAmbient(layout: layout) }
        world.run(.repeatForever(.sequence([spawn, .wait(forDuration: 0.35)])), withKey: "ambience")
    }

    private func spawnAmbient(layout: FarmLayout) {
        guard let store, ambientCount < 28, let cam = camera else { return }
        let farm = store.farm
        // pick a random tile near what the camera sees
        let half = size.height * cam.yScale / tileH / 2 + 1
        let (cx, cy) = grid(farm).tile(at: cam.position)
        let x = cx + Int.random(in: -Int(half)...Int(half))
        let y = cy + Int.random(in: -Int(half)...Int(half))
        let p = position(x: x, y: y, farm: farm)
        let at = CGPoint(x: p.x + CGFloat.random(in: -20...20), y: p.y + CGFloat.random(in: -20...20))

        let green = layout.isGreen(farm, x, y) && farm.tile(x: x, y: y)?.tilled == false
        let node: SKSpriteNode
        let life: TimeInterval
        if green {
            node = SKSpriteNode(texture: Textures.named("fx_firefly"), size: CGSize(width: 24, height: 24))
            node.blendMode = .add
            life = 3.2
            let wander = SKAction.sequence((0..<4).map { _ in
                SKAction.moveBy(x: CGFloat.random(in: -18...18), y: CGFloat.random(in: -10...14), duration: life / 4)
            })
            node.run(wander)
            node.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
        } else {
            node = SKSpriteNode(texture: Textures.named("fx_mote"), size: CGSize(width: 12, height: 12))
            life = 4
            node.run(.moveBy(x: CGFloat.random(in: 50...90), y: CGFloat.random(in: -10...20), duration: life))
        }
        node.name = "ambient"
        node.position = at
        node.zPosition = 80
        node.alpha = 0
        world.addChild(node)
        ambientCount += 1
        node.run(.sequence([
            .fadeIn(withDuration: 0.6),
            .wait(forDuration: life - 1.2),
            .fadeOut(withDuration: 0.6),
            .run { [weak self] in self?.ambientCount -= 1 },
            .removeFromParent(),
        ]), withKey: "life")
    }
}
