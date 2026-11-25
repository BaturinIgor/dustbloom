import Foundation

/// Where buildings and decorations stand, and where grass grows.
/// Mirrors STRUCTURES / DECOR / ground_name in art/generate_sprites.py,
/// so the preview image and the game look the same.
struct FarmLayout {
    struct Piece {
        var sprite: String
        var x: Int          // top-left tile
        var y: Int
        var width: Int      // footprint in tiles
        var height: Int
        var blocksTaps: Bool
        var bringsLife: Bool
    }

    let width: Int
    let height: Int
    let pieces: [Piece]
    private var blocked: Set<Int> = []
    private var lifeTiles: Set<Int> = []

    init(config: GameConfig) {
        width = config.farm.width
        height = config.farm.height
        let sx = config.farm.startTilled.x
        let sy = config.farm.startTilled.y
        var p: [Piece] = [
            Piece(sprite: "prop_house", x: sx - 1, y: sy - 5, width: 3, height: 3, blocksTaps: true, bringsLife: true),
            Piece(sprite: "prop_windmill", x: sx + 3, y: sy - 5, width: 2, height: 3, blocksTaps: true, bringsLife: true),
            Piece(sprite: "prop_pond", x: sx + 3, y: sy + 5, width: 3, height: 2, blocksTaps: true, bringsLife: true),
            Piece(sprite: "prop_stones", x: sx, y: sy - 2, width: 1, height: 1, blocksTaps: true, bringsLife: false),
            Piece(sprite: "prop_stones", x: sx, y: sy - 1, width: 1, height: 1, blocksTaps: true, bringsLife: false),
            Piece(sprite: "prop_scarecrow", x: sx - 1, y: sy + 1, width: 1, height: 2, blocksTaps: true, bringsLife: false),
        ]
        for fx in [sx - 2, sx - 1, sx + 1, sx + 2, sx + 3] {
            p.append(Piece(sprite: "prop_fence", x: fx, y: sy - 2, width: 1, height: 1, blocksTaps: true, bringsLife: false))
        }
        pieces = p
        for piece in p {
            for y in piece.y..<(piece.y + piece.height) {
                for x in piece.x..<(piece.x + piece.width) where x >= 0 && y >= 0 && x < width && y < height {
                    if piece.blocksTaps { blocked.insert(y * width + x) }
                    if piece.bringsLife { lifeTiles.insert(y * width + x) }
                }
            }
        }
    }

    func isBlocked(x: Int, y: Int) -> Bool {
        blocked.contains(y * width + x)
    }

    /// Grass grows within 2.3 tiles of a bed or a building.
    func isGreen(_ farm: Farm, _ x: Int, _ y: Int) -> Bool {
        guard x >= 0, y >= 0, x < width, y < height else { return false }
        for yy in max(0, y - 2)...min(height - 1, y + 2) {
            for xx in max(0, x - 2)...min(width - 1, x + 2) {
                let i = yy * width + xx
                guard farm.tiles[i].tilled || lifeTiles.contains(i) else { continue }
                let d = Double((xx - x) * (xx - x) + (yy - y) * (yy - y))
                if d <= 2.3 * 2.3 { return true }
            }
        }
        return false
    }

    /// Texture name for the ground at (x, y); works outside the farm too.
    func groundName(_ farm: Farm, x: Int, y: Int) -> String {
        let inside = x >= 0 && y >= 0 && x < width && y < height
        if inside && farm.tiles[y * width + x].tilled { return "tile_bed" }
        guard inside, isGreen(farm, x, y) else {
            return "tile_dust_\(abs(x &* 7 &+ y &* 13) % 3)"
        }
        let mask = (isGreen(farm, x, y - 1) ? 1 : 0) | (isGreen(farm, x + 1, y) ? 2 : 0)
            | (isGreen(farm, x, y + 1) ? 4 : 0) | (isGreen(farm, x - 1, y) ? 8 : 0)
        if mask == 15 {
            let v = (x * 5 + y * 3) % 7
            return "tile_grass_\(v == 0 ? 1 : v == 3 ? 2 : 0)"
        }
        return "tile_grass_edge_\(mask)"
    }
}
