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

    private static var players: [Track: AVAudioPlayer] = [:]
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
        // another app is playing its own music: stay quiet
        if AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint { return }
        let old = current.flatMap { players[$0] }
        current = t
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
        if let old, old !== p {
            old.setVolume(0, fadeDuration: 2.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
                MainActor.assumeIsolated { if old.volume < 0.01 { old.pause() } }
            }
        }
    }

    static func pause() { players.values.forEach { $0.pause() } }
    static func resume() { if enabled, let t = current, let p = players[t] { p.play() } }

    private static func fadeOutAll() {
        for p in players.values {
            p.setVolume(0, fadeDuration: 0.6)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { MainActor.assumeIsolated { p.pause() } }
        }
        current = nil
    }
}
