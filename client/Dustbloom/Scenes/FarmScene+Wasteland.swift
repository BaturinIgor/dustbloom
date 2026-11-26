import SpriteKit
import UIKit

/// The wasteland around the farm never changes, so instead of thousands of
/// tile, rock and fog sprites it is drawn once, at art resolution (isometric
/// diamonds), into a single texture and shown as one sprite.
extension FarmScene {
    /// Rock or dead tree standing on (x, y), far enough from the starting beds.
    func wildProp(x: Int, y: Int, start: GameConfig.Area) -> String? {
        let dx = max(start.x - x, 0, x - (start.x + start.width - 1))
        let dy = max(start.y - y, 0, y - (start.y + start.height - 1))
        guard max(dx, dy) >= 5 else { return nil }
        switch abs(x &* 31 &+ y &* 17) % 23 {
        case 0: return "prop_dead_tree"
        case 7, 15: return "prop_rock"
        default: return nil
        }
    }

    func bakeWasteland(layout: FarmLayout, farm: Farm, start: GameConfig.Area) {
        // Diamond tiles in image units (points of the @2x art at 1x): 24 x 12.
        let tw: CGFloat = 24, th: CGFloat = 12
        let pad = min(self.pad, 12)
        let n = farm.width + farm.height + pad * 4  // tiles across the big diamond
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2  // hd art ships as @2x: keep every pixel
        format.opaque = false
        let size = CGSize(width: CGFloat(n) * tw / 2, height: CGFloat(n) * th / 2)
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        var images: [String: UIImage] = [:]
        func image(_ name: String) -> UIImage? {
            if let i = images[name] { return i }
            let i = UIImage(named: name)
            images[name] = i
            return i
        }
        func outside(_ x: Int, _ y: Int) -> Bool { x < 0 || y < 0 || x >= farm.width || y >= farm.height }
        // image position of tile (x, y)'s centre; tile (-pad, -pad) is the top corner
        func center(_ x: Int, _ y: Int) -> CGPoint {
            let i = CGFloat(x + pad), j = CGFloat(y + pad)
            return CGPoint(x: CGFloat(farm.height + pad * 2) * tw / 2 + (i - j) * tw / 2,
                           y: (i + j + 1) * th / 2)
        }
        // back to front: rows of constant x + y
        var order: [(Int, Int)] = []
        for s in 0..<(farm.width + farm.height + pad * 4 - 1) {
            for x in -pad..<(farm.width + pad) {
                let y = s - pad * 2 - x
                if y >= -pad && y < farm.height + pad { order.append((x, y)) }
            }
        }

        let baked = renderer.image { ctx in
            let cg = ctx.cgContext
            cg.interpolationQuality = .none
            for (x, y) in order where outside(x, y) {
                let c = center(x, y)
                image(layout.groundName(farm, x: x, y: y))?
                    .draw(in: CGRect(x: c.x - tw / 2, y: c.y - th / 2, width: tw, height: th))
            }
            // rocks and trees stand on their tile's front corner
            for (x, y) in order where outside(x, y) {
                guard let sprite = wildProp(x: x, y: y, start: start), let img = image(sprite) else { continue }
                let c = center(x, y)
                let bottom = c.y + th / 2
                if let shadow = image(sprite == "prop_dead_tree" ? "shadow_dead_tree" : "shadow_rock") {
                    shadow.draw(in: CGRect(x: c.x - img.size.width / 2, y: bottom - shadow.size.height,
                                           width: shadow.size.width, height: shadow.size.height))
                }
                img.draw(in: CGRect(x: c.x - img.size.width / 2, y: bottom - img.size.height,
                                    width: img.size.width, height: img.size.height))
            }
            // fog: the world fades out into the background colour instead of ending
            for (x, y) in order {
                let d = max(-x, x - (farm.width - 1), -y, y - (farm.height - 1))
                guard d > 4 else { continue }
                let c = center(x, y)
                cg.setFillColor(Palette.dustDeep.withAlphaComponent(min(1, CGFloat(d - 4) / 7)).cgColor)
                cg.beginPath()
                cg.move(to: CGPoint(x: c.x, y: c.y - th / 2 - 0.5))
                cg.addLine(to: CGPoint(x: c.x + tw / 2 + 1, y: c.y))
                cg.addLine(to: CGPoint(x: c.x, y: c.y + th / 2 + 0.5))
                cg.addLine(to: CGPoint(x: c.x - tw / 2 - 1, y: c.y))
                cg.closePath()
                cg.fillPath()
            }
        }

        let tex = SKTexture(image: baked)
        tex.filteringMode = .nearest
        let node = SKSpriteNode(texture: tex, size: CGSize(width: size.width * px, height: size.height * px))
        // tile (-pad, -pad)'s centre maps to its world position
        let anchorImg = center(-pad, -pad)
        let anchorWorld = position(x: -pad, y: -pad, farm: farm)
        node.anchorPoint = CGPoint(x: anchorImg.x / size.width, y: 1 - anchorImg.y / size.height)
        node.position = anchorWorld
        // above farm ground and shadows (so tree tops overlap the edge row),
        // below anything standing on the farm (depth >= 1)
        node.zPosition = 0.9
        node.name = "wasteland"
        world.addChild(node)
    }
}
