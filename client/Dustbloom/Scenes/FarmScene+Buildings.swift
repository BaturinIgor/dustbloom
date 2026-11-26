import SpriteKit

/// Working buildings on the farm. An unbuilt one is a building site with
/// pegs and a sign; its look changes at levels 11 and 21, and a hammer with
/// the time left bobs over it while it is under construction.
extension FarmScene {
    func buildingTexture(_ id: String, farm: Farm) -> String {
        guard let store else { return "bld_site" }
        let level = farm.buildingLevel(id, config: store.config)
        return level == 0 ? "bld_site" : Buildings.image(id, level: level)
    }

    func placeBuilding(_ id: String, piece: FarmLayout.Piece, farm: Farm) {
        let tex = buildingTexture(id, farm: farm)
        let node = stand(tex, x: piece.x, y: piece.y, w: piece.width, h: piece.height, farm: farm,
                         shadow: tex == "bld_site" ? nil : "shadow_\(tex)")
        node.name = "bld_\(id)"
        buildingNodes[id] = node
        buildingShown[id] = tex
        buildingPieces[id] = piece
    }

    func refreshBuildings(_ farm: Farm) {
        for (id, node) in buildingNodes {
            if id != "mill", let shown = buildingShown[id] {
                let tex = buildingTexture(id, farm: farm)
                if tex != shown {
                    buildingShown[id] = tex
                    let t = Textures.named(tex)
                    node.texture = t
                    node.size = CGSize(width: t.size().width * px, height: t.size().height * px)
                    Sfx.play(.levelUp)
                    node.run(.sequence([.scale(to: 1.15, duration: 0.12), .scale(to: 1, duration: 0.25)]))
                    dustPuff(at: CGPoint(x: node.position.x, y: node.position.y + 10))
                }
            }
            let ready = farm.work?.building == id ? farm.work?.readyAt : nil
            constructionBadge(on: node, ready: ready)
        }
    }
}
