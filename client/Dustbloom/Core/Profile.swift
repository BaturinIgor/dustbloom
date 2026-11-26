import Foundation

/// The player's face in the game: a nickname and a preset avatar. Kept on
/// the device for now; the server gets them with chat and rankings
/// (stage 2), where custom photo avatars come with moderation.
enum Profile {
    static let nameKey = "dustbloom.profile.name"
    static let avatarKey = "dustbloom.profile.avatar"

    /// Preset avatars (art/hd/avatars.py) and the level each one opens at.
    static let avatarUnlock = [0, 0, 0, 0, 0, 0, 0, 0, 10, 20, 30, 40]
    static var avatarCount: Int { avatarUnlock.count }

    static let minName = 3
    static let maxName = 16

    /// A friendly default until the player picks a name.
    static func defaultName(ru: Bool, seed: Int = Int.random(in: 1000...9999)) -> String {
        (ru ? "Фермер" : "Farmer") + "\(seed)"
    }

    /// Trimmed name if it is allowed, nil otherwise: 3-16 letters (any
    /// script), digits, spaces, "_" or "-", not only spaces or symbols.
    static func validName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
        guard (minName...maxName).contains(name.count) else { return nil }
        let allowed = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: " _-"))
        guard name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        guard name.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) else { return nil }
        return name
    }

    static func isUnlocked(avatar: Int, level: Int) -> Bool {
        avatarUnlock.indices.contains(avatar) && level >= avatarUnlock[avatar]
    }
}

extension Farm {
    /// Share of the way from this level to the next, 0...1 (same curve as `level`).
    var levelProgress: Double {
        var need = 10, rest = xp
        while rest >= need {
            rest -= need
            need += 10
        }
        return Double(rest) / Double(need)
    }
}
