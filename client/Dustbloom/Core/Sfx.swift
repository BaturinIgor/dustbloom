import AVFoundation

/// Plays the synthesized sound effects (audio/generate_sfx.py).
/// Ambient session: respects the silent switch and mixes with the player's music.
@MainActor
enum Sfx {
    enum Sound: String, CaseIterable {
        case till = "sfx_till", plant = "sfx_plant", harvest = "sfx_harvest", coin = "sfx_coin"
        case levelUp = "sfx_levelup", error = "sfx_error", select = "sfx_select", sparkle = "sfx_sparkle"
    }

    /// Overall level of all effects. The WAVs are mastered near full scale, which is
    /// too loud next to music; 0.4 is about -8 dB. Later this becomes a settings slider.
    static var master: Float = 0.4

    /// Per-sound mix: sounds heard on every tap sit lower, rare rewards stand out.
    private static let mix: [Sound: Float] = [
        .till: 0.6, .plant: 0.7, .select: 0.7, .error: 0.7,
        .harvest: 0.85, .coin: 0.75, .sparkle: 0.8, .levelUp: 1.0,
    ]

    private static var players: [Sound: [AVAudioPlayer]] = [:]
    private static var next: [Sound: Int] = [:]
    private static var ready = false

    static func prepare() {
        guard !ready else { return }
        ready = true
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
