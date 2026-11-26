import CoreGraphics
import XCTest
@testable import Dustbloom

final class IsoGridTests: XCTestCase {
    func testTileAtCentreRoundTrips() {
        let g = IsoGrid(width: 16, height: 16)
        for (x, y) in [(0, 0), (15, 15), (3, 9), (-4, 20)] {
            let t = g.tile(at: g.center(x: x, y: y))
            XCTAssertEqual(t.x, x)
            XCTAssertEqual(t.y, y)
        }
    }

    func testAxesRunDownTheScreen() {
        let g = IsoGrid(width: 16, height: 16)
        let o = g.center(x: 5, y: 5)
        let right = g.center(x: 6, y: 5)  // +x: lower right
        let left = g.center(x: 5, y: 6)   // +y: lower left
        XCTAssertGreaterThan(right.x, o.x)
        XCTAssertLessThan(right.y, o.y)
        XCTAssertLessThan(left.x, o.x)
        XCTAssertLessThan(left.y, o.y)
    }

    func testPointsNearDiamondEdgePickTheRightTile() {
        let g = IsoGrid(width: 16, height: 16)
        let c = g.center(x: 7, y: 7)
        // just inside the right corner stays on the tile; just past it is the neighbour
        XCTAssertEqual(g.tile(at: CGPoint(x: c.x + IsoGrid.tileW / 2 - 2, y: c.y)).x, 7)
        let past = g.tile(at: CGPoint(x: c.x + IsoGrid.tileW / 2 + 2, y: c.y))
        XCTAssertTrue(past.x == 8 || past.y == 6)
    }

    func testFrontTilesDrawInFront() {
        XCTAssertGreaterThan(IsoGrid.depth(x: 3, y: 4, pad: 16), IsoGrid.depth(x: 3, y: 3, pad: 16))
    }
}
