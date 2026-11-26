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
            // 0. every 10th step: upgrade the manor, show its card, speed it up
            if steps % 10 == 5, farm.manorReadyAt == nil, store.upgradeManor() == nil {
                store.showManor = true
                self.run(.sequence([
                    .wait(forDuration: 1.4),
                    .run { _ = store.smartSpeedup(SpeedTarget(kind: SpeedTarget.build)); Sfx.play(.speedup) },
                    .wait(forDuration: 1.2),
                    .run { store.showManor = false },
                ]))
                return
            }
            // 0b. in between: build or upgrade a working building the same way
            if steps % 10 == 0, !farm.busy,
               let b = store.config.buildings.list.first(where: { Buildings.canUpgrade($0.id, farm: farm, config: store.config) }),
               store.upgradeBuilding(b.id) == nil {
                store.showBuilding = b.id
                self.run(.sequence([
                    .wait(forDuration: 1.4),
                    .run { _ = store.smartSpeedup(SpeedTarget(kind: SpeedTarget.build)); Sfx.play(.speedup) },
                    .wait(forDuration: 1.2),
                    .run { store.showBuilding = nil },
                ]))
                return
            }
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
            // 3. every few idle steps, till a new bed next to the farm, but
            // only where the whole bed is on screen, clear of the HUD
            guard steps % 4 == 0, beds.count < Self.demoMaxBeds else { return }
            for i in beds {
                let bx = i % farm.width, by = i / farm.width
                for (dx, dy) in [(1, 0), (0, 1), (-1, 0), (0, -1)] {
                    let x = bx + dx, y = by + dy
                    guard let t = farm.tile(x: x, y: y), !t.tilled, !layout.isBlocked(x: x, y: y),
                          farm.owns(x: x, y: y, config: store.config),
                          y > store.config.farm.startTilled.y - 2,  // keep the yard by the house free
                          self.demoFits(x: x, y: y, farm: farm) else { continue }
                    self.handleTap(x: x, y: y)  // shows the price
                    self.handleTap(x: x, y: y)  // confirms
                    return
                }
            }
        }
        run(.sequence([.wait(forDuration: 0.8), .repeatForever(.sequence([step, .wait(forDuration: 0.4)]))]), withKey: "demo")
    }

    static let demoMaxBeds = 24

    /// True when tile (x, y) sits fully inside the visible area, with room
    /// for the top bar and the seed bar, so the video never shows cut beds.
    func demoFits(x: Int, y: Int, farm: Farm) -> Bool {
        let p = position(x: x, y: y, farm: farm)
        let s = cam.xScale
        let half = tileSize / 2
        let left = cam.position.x - size.width / 2 * s + 8 * s
        let right = cam.position.x + size.width / 2 * s - 8 * s
        let top = cam.position.y + size.height / 2 * s - 150 * s
        let bottom = cam.position.y - size.height / 2 * s + 230 * s
        return p.x - half >= left && p.x + half <= right && p.y + half <= top && p.y - half >= bottom
    }
}
