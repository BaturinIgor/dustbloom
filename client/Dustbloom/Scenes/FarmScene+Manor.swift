import SpriteKit

/// The Усадьба on the farm: swaps its look when a five-level tier is reached
/// and shows a bobbing hammer with the time left while it is being built.
extension FarmScene {
    func refreshManor(_ farm: Farm) {
        guard let house = manorNode else { return }
        if farm.manorTier != manorShownTier {
            let tier = farm.manorTier
            let tex = Textures.named("prop_manor_\(tier)")
            let first = manorShownTier < 0
            manorShownTier = tier
            house.texture = tex
            if let shadow = house.parent?.children.first(where: { $0.name == "manorShadow" }) as? SKSpriteNode {
                shadow.texture = Textures.named("shadow_manor_\(tier)")
            }
            if !first {
                Sfx.play(.levelUp)
                house.run(.sequence([.scale(to: 1.12, duration: 0.12), .scale(to: 1, duration: 0.25)]))
                for i in 0..<14 {
                    let s = SKSpriteNode(texture: Textures.named("fx_sparkle"), size: CGSize(width: 24, height: 24))
                    s.position = CGPoint(x: CGFloat.random(in: -70...70), y: CGFloat.random(in: 20...150))
                    s.zPosition = 0.01
                    s.setScale(0.2)
                    house.addChild(s)
                    s.run(.sequence([
                        .wait(forDuration: Double(i) * 0.04),
                        .group([.scale(to: 1, duration: 0.2), .moveBy(x: 0, y: 30, duration: 0.8)]),
                        .fadeOut(withDuration: 0.3), .removeFromParent(),
                    ]))
                }
            }
        }
        let badgeName = "manorBuild"
        if let ready = farm.manorReadyAt, let store {
            let badge: SKNode
            if let b = house.childNode(withName: badgeName) {
                badge = b
            } else {
                badge = SKNode()
                badge.name = badgeName
                badge.position = CGPoint(x: 0, y: house.size.height + 18)
                badge.zPosition = 0.02
                let hammer = SKSpriteNode(texture: Textures.named("icon_workshop"), size: CGSize(width: 36, height: 36))
                hammer.name = "hammer"
                let swing = SKAction.sequence([.rotate(toAngle: 0.5, duration: 0.18), .rotate(toAngle: -0.2, duration: 0.3)])
                hammer.run(.repeatForever(swing))
                badge.addChild(hammer)
                let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
                label.name = "time"
                label.fontSize = 18
                label.fontColor = .white
                label.position = CGPoint(x: 0, y: -40)
                label.verticalAlignmentMode = .center
                let back = SKShapeNode(rectOf: CGSize(width: 86, height: 26), cornerRadius: 6)
                back.fillColor = UIColor(white: 0.1, alpha: 0.65)
                back.strokeColor = .clear
                back.position = label.position
                back.zPosition = -0.001
                badge.addChild(back)
                badge.addChild(label)
                house.addChild(badge)
            }
            let s = max(0, Int(ready.timeIntervalSince(store.now).rounded(.up)))
            let text = s >= 3600 ? "\(s / 3600)h \(s % 3600 / 60)m" : "\(s / 60):\(String(format: "%02d", s % 60))"
            (badge.childNode(withName: "time") as? SKLabelNode)?.text = text
        } else if let b = house.childNode(withName: badgeName) {
            b.removeFromParent()
            dustPuff(at: CGPoint(x: house.position.x, y: house.position.y + 10))
        }
    }
}
