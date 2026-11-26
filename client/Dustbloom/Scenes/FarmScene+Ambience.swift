import SpriteKit

/// Ambient life: chimney smoke, fireflies over the grass, dust drifting over
/// the wasteland. Cheap sprite actions, capped so they never pile up.
extension FarmScene {
    func chimneySmoke(on house: SKSpriteNode) {
        // chimney top in the 48x48 house sprite: x 35, y 0 (from the top)
        let origin = CGPoint(x: (35 - 24) * px, y: 48 * px)
        let puff = SKAction.run { [weak house] in
            guard let house else { return }
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
        let half = size.width * cam.xScale / tileSize / 2 + 1
        let cx = Int((cam.position.x / tileSize + CGFloat(farm.width) / 2).rounded())
        let cy = Int((CGFloat(farm.height) / 2 - cam.position.y / tileSize).rounded())
        let x = cx + Int.random(in: -Int(half)...Int(half))
        let y = cy + Int.random(in: -Int(half * 2)...Int(half * 2))
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
