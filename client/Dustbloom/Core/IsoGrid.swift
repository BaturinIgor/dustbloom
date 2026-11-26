import CoreGraphics

/// Isometric (2:1) farm grid. Tile (x, y) is a diamond; +x runs to the
/// lower right on screen and +y to the lower left, so the farm's (0, 0)
/// corner is the top of the big diamond. The grid is centred on the farm
/// centre. Scene y grows upwards (SpriteKit).
struct IsoGrid {
    /// Diamond width and height in points (art: 48 x 24 px at 1.5 pt per px).
    static let tileW: CGFloat = 72
    static let tileH: CGFloat = 36

    let width: Int
    let height: Int

    /// Centre of tile (x, y). Works outside the farm too.
    func center(x: Int, y: Int) -> CGPoint {
        center(fx: CGFloat(x) + 0.5, fy: CGFloat(y) + 0.5)
    }

    /// Point for fractional tile coordinates (0...width, 0...height).
    func center(fx: CGFloat, fy: CGFloat) -> CGPoint {
        let u = fx - CGFloat(width) / 2
        let v = fy - CGFloat(height) / 2
        return CGPoint(x: (u - v) * IsoGrid.tileW / 2, y: -(u + v) * IsoGrid.tileH / 2)
    }

    /// Fractional tile coordinates under a scene point.
    func coords(at p: CGPoint) -> (fx: CGFloat, fy: CGFloat) {
        let a = p.x / (IsoGrid.tileW / 2)
        let b = -p.y / (IsoGrid.tileH / 2)
        return ((a + b) / 2 + CGFloat(width) / 2, (b - a) / 2 + CGFloat(height) / 2)
    }

    /// Tile under a scene point (may lie outside the farm).
    func tile(at p: CGPoint) -> (x: Int, y: Int) {
        let c = coords(at: p)
        return (Int(floor(c.fx)), Int(floor(c.fy)))
    }

    /// Bottom (front) corner of a footprint: where a building stands.
    func frontCorner(x: Int, y: Int, w: Int, h: Int) -> CGPoint {
        center(fx: CGFloat(x + w), fy: CGFloat(y + h))
    }

    /// Draw order: tiles further down the screen (larger x + y) go in front.
    static func depth(x: Int, y: Int, pad: Int) -> CGFloat {
        1 + CGFloat(x + y + pad * 2) * 0.005
    }
}
