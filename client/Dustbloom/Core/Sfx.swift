import AVFoundation

/// Plays the sound effects built from CC0 Kenney packs (audio/build_sfx.py).
/// Ambient session: respects the silent switch and mixes with the player's music.
@MainActor
enum Sfx {
    enum Sound: String, CaseIterable {
        case till = "sfx_till", plant = "sfx_plant", harvest = "sfx_harvest", coin = "sfx_coin"
        case levelUp = "sfx_levelup", error = "sfx_error", select = "sfx_select", sparkle = "sfx_sparkle"
        case chest = "sfx_chest", speedup = "sfx_speedup", victory = "sfx_victory", defeat = "sfx_defeat"
    }

    /// Overall level of all effects. build_sfx.py already levels the WAVs to about
    /// -20 dB RMS, so this only trims a little. Later this becomes a settings slider.
    static var master: Float = 0.8

    /// Per-sound mix: sounds heard on every tap sit lower, rare rewards stand out.
    private static let mix: [Sound: Float] = [
        .till: 0.8, .plant: 0.9, .select: 0.8, .error: 0.8,
        .harvest: 1.0, .coin: 0.9, .sparkle: 0.9, .levelUp: 1.0,
        .chest: 1.0, .speedup: 0.9, .victory: 1.0, .defeat: 0.9,
    ]

    private static var players: [Sound: [AVAudioPlayer]] = [:]
    private static var next: [Sound: Int] = [:]
    private static var ready = false

    static func prepare() {
        guard !ready else { return }
        ready = true
        if UserDefaults.standard.object(forKey: "dustbloom.volume") != nil {
            master = Float(UserDefaults.standard.double(forKey: "dustbloom.volume"))
        }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for s in Sound.allCases {
            guard let url = Bundle.main.url(forResource: s.rawValue, withExtension: "wav") else { continue }
            // a few voices per sound so quick taps overlap instead of cutting off
            players[s] = (0..<3).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                return p
            }
        }
    }

    static func play(_ s: Sound, volume: Float = 1, after delay: TimeInterval = 0) {
        prepare()
        guard let pool = players[s], !pool.isEmpty else { return }
        let i = (next[s] ?? 0) % pool.count
        next[s] = i + 1
        let p = pool[i]
        p.volume = volume * master * (mix[s] ?? 1)
        p.currentTime = 0
        if delay > 0 {
            p.play(atTime: p.deviceCurrentTime + delay)
        } else {
            p.play()
        }
    }
}
