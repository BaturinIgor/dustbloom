import SpriteKit

/// Demo mode (DUSTBLOOM_DEMO=1): the farm plays itself for videos and
/// store screenshots. Harvests what is ripe, plants empty beds with
/// alternating crops, and now and then tills a new bed so grass spreads.
extension FarmScene {
    func startDemo(layout: FarmLayout) {
        var cropIndex = 0
        var steps = 0
        let step = SKAction.run { [weak self] in
            guard let self, let store = self.store else { return }
            steps += 1
            let farm = store.farm
            let beds = (0..<farm.tiles.count).filter { farm.tiles[$0].tilled }
            // 1. harvest the first ripe crop
            if let i = beds.first(where: { i in
                store.progress(of: farm.tiles[i]).map { $0 >= 1 } ?? false
            }) {
                self.handleTap(x: i % farm.width, y: i / farm.width)
                return
            }
            // 2. plant the first empty bed, cycling crops
            if let i = beds.first(where: { farm.tiles[$0].crop == nil }) {
                let crops = store.config.crops
                store.selectedCrop = crops[cropIndex % crops.count].id
                cropIndex += 1
                self.handleTap(x: i % farm.width, y: i / farm.width)
                return
            }
            // 3. every few idle steps, till a new bed next to the farm
            guard steps % 4 == 0 else { return }
            for i in beds {
                let bx = i % farm.width, by = i / farm.width
                for (dx, dy) in [(1, 0), (0, 1), (-1, 0), (0, -1)] {
                    let x = bx + dx, y = by + dy
                    guard let t = farm.tile(x: x, y: y), !t.tilled, !layout.isBlocked(x: x, y: y) else { continue }
                    self.handleTap(x: x, y: y)
                    return
                }
            }
        }
        run(.sequence([.wait(forDuration: 0.8), .repeatForever(.sequence([step, .wait(forDuration: 0.4)]))]), withKey: "demo")
    }
}
