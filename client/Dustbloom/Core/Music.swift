import AVFoundation

/// Biome music (audio/generate_music.py). One loop per biome, crossfaded when the hero
/// walks onto an island with another biome. Ambient session, so the player's own music wins.
@MainActor
enum Music {
    enum Track: String { case meadow, sand, mushroom, volcano, star }

    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "dustbloom.music") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "dustbloom.music")
            if newValue, let t = wanted { current = nil; play(t) } else { fadeOutAll() }
        }
    }
    static let level: Float = 0.45

    /// AVAudioPlayer's play/pause/prepare stop and start an audio queue synchronously; on the
    /// main thread that froze a frame every time the hero walked into another biome. Every
    /// player call runs on `q`; only the choice of track stays on the main actor.
    nonisolated private static let q = DispatchQueue(label: "dustbloom.music", qos: .userInitiated)
    nonisolated(unsafe) private static var players: [Track: AVAudioPlayer] = [:]  // touched only on `q`
    private static var current: Track?
    private static var wanted: Track?

    static func track(forIsland id: Int) -> Track {
        switch id {
        case 6: return .sand
        case 8: return .mushroom
        case 10: return .volcano
        case 11: return .star
        default: return .meadow
        }
    }

    static func play(_ t: Track) {
        wanted = t
        guard enabled, t != current else { return }
        let old = current
        current = t
        let level = level
        q.async {
            // another app is playing its own music: stay quiet
            if AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint { return }
            if players[t] == nil, let url = Bundle.main.url(forResource: "music_\(t.rawValue)", withExtension: "m4a"),
               let p = try? AVAudioPlayer(contentsOf: url) {
                p.numberOfLoops = -1
                p.prepareToPlay()
                players[t] = p
            }
            guard let p = players[t] else { return }
            p.volume = 0
            if !p.isPlaying { p.currentTime = 0; p.play() }
            p.setVolume(level, fadeDuration: 2.0)
            if let old, old != t, let o = players[old] {
                o.setVolume(0, fadeDuration: 2.0)
                q.asyncAfter(deadline: .now() + 2.1) { if o.volume < 0.01 { o.pause() } }
            }
        }
    }

    static func pause() { q.async { players.values.forEach { $0.pause() } } }
    static func resume() {
        guard enabled, let t = current else { return }
        q.async { players[t]?.play() }
    }

    private static func fadeOutAll() {
        current = nil
        q.async {
            for p in players.values {
                p.setVolume(0, fadeDuration: 0.6)
                q.asyncAfter(deadline: .now() + 0.7) { p.pause() }
            }
        }
    }
}
