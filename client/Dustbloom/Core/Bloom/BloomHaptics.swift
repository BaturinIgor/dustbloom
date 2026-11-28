import Foundation

/// Player switch for vibration (Menu → Вибрация). On by default.
enum Haptics {
    private static let key = "dustbloom.haptics"
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
