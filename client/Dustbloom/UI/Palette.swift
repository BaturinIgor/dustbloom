import SwiftUI
import UIKit

/// Colours from docs/style-guide.md. Sprites use the same hex values.
enum Palette {
    static let outline = UIColor(hex: 0x2B1D16)
    static let dustDeep = UIColor(hex: 0x4F4959)
    static let dustLight = UIColor(hex: 0xB8B1BB)
    static let gold = UIColor(hex: 0xFFE08A)
    static let goldDeep = UIColor(hex: 0xE8B443)
    static let parchment = UIColor(hex: 0xF4E6C4)
    static let parchmentShade = UIColor(hex: 0xE2CC9A)
    static let ink = UIColor(hex: 0x3A2A20)
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
