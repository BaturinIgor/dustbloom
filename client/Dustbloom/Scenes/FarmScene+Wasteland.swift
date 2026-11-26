import SpriteKit
import UIKit

/// The wasteland around the farm never changes, so instead of thousands of
/// tile, rock and fog sprites it is drawn once, at art resolution (16 px per
/// tile), into a single texture and shown as one sprite.
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
        let art = 16  // art pixels per tile
        let cols = farm.width + pad * 2
        let rows = farm.height + pad * 2
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cols * art, height: rows * art), format: format)
        var images: [String: UIImage] = [:]
        func image(_ name: String) -> UIImage? {
            if let i = images[name] { return i }
            let i = UIImage(named: name)
            images[name] = i
            return i
        }
        func outside(_ x: Int, _ y: Int) -> Bool { x < 0 || y < 0 || x >= farm.width || y >= farm.height }

        let baked = renderer.image { ctx in
            let cg = ctx.cgContext
            cg.interpolationQuality = .none
            // ground
            for y in -pad..<(farm.height + pad) {
                for x in -pad..<(farm.width + pad) where outside(x, y) {
                    image(layout.groundName(farm, x: x, y: y))?
                        .draw(in: CGRect(x: (x + pad) * art, y: (y + pad) * art, width: art, height: art))
                }
            }
            // rocks and trees, top rows first so lower ones overlap them
            for y in -pad..<(farm.height + pad) {
                for x in -pad..<(farm.width + pad) where outside(x, y) {
                    guard let sprite = wildProp(x: x, y: y, start: start), let img = image(sprite) else { continue }
                    let shadow = image(sprite == "prop_dead_tree" ? "shadow_dead_tree" : "shadow_rock")
                    let cx = CGFloat((x + pad) * art + art / 2)
                    let bottom = CGFloat((y + pad + 1) * art)
                    if let shadow {
                        shadow.draw(in: CGRect(x: cx - img.size.width / 2, y: bottom - shadow.size.height,
                                               width: shadow.size.width, height: shadow.size.height))
                    }
                    img.draw(in: CGRect(x: cx - img.size.width / 2, y: bottom - img.size.height,
                                        width: img.size.width, height: img.size.height))
                }
            }
            // fog: the world fades out instead of ending
            for y in -pad..<(farm.height + pad) {
                for x in -pad..<(farm.width + pad) {
                    let d = max(-x, x - (farm.width - 1), -y, y - (farm.height - 1))
                    guard d > 5 else { continue }
                    cg.setFillColor(Palette.dustDeep.withAlphaComponent(min(0.85, CGFloat(d - 5) / 10)).cgColor)
                    cg.fill(CGRect(x: (x + pad) * art, y: (y + pad) * art, width: art, height: art))
                }
            }
        }

        let tex = SKTexture(image: baked)
        tex.filteringMode = .nearest
        let node = SKSpriteNode(texture: tex, size: CGSize(width: CGFloat(cols) * tileSize, height: CGFloat(rows) * tileSize))
        let topLeft = position(x: -pad, y: -pad, farm: farm)
        node.position = CGPoint(x: topLeft.x - tileSize / 2 + node.size.width / 2,
                                y: topLeft.y + tileSize / 2 - node.size.height / 2)
        // above farm ground and shadows (so tree tops overlap the edge row),
        // below anything standing on the farm (depth >= 1)
        node.zPosition = 0.9
        node.name = "wasteland"
        world.addChild(node)
    }
}
