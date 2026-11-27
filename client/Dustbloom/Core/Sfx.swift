import AVFoundation
import QuartzCore

/// Plays the sound effects built from CC0 Kenney packs (audio/build_sfx.py).
/// Ambient session: respects the silent switch and mixes with the player's music.
@MainActor
enum Sfx {
    enum Sound: String, CaseIterable {
        case till = "sfx_till", plant = "sfx_plant", harvest = "sfx_harvest", coin = "sfx_coin"
        case levelUp = "sfx_levelup", error = "sfx_error", select = "sfx_select", sparkle = "sfx_sparkle"
        case chest = "sfx_chest", speedup = "sfx_speedup", victory = "sfx_victory", defeat = "sfx_defeat"
        case hit = "sfx_hit", shoot = "sfx_shoot", poof = "sfx_poof", skill = "sfx_skill", boss = "sfx_boss"
        case fence = "sfx_fence"
    }

    /// Overall level of all effects. build_sfx.py already levels the WAVs to about
    /// -20 dB RMS, so this only trims a little. Later this becomes a settings slider.
    static var master: Float = 0.8

    /// Per-sound mix: sounds heard on every tap sit lower, rare rewards stand out.
    private static let mix: [Sound: Float] = [
        .till: 0.8, .plant: 0.9, .select: 0.8, .error: 0.8,
        .harvest: 1.0, .coin: 0.9, .sparkle: 0.9, .levelUp: 1.0,
        .chest: 1.0, .speedup: 0.9, .victory: 1.0, .defeat: 0.9,
        .hit: 0.7, .shoot: 0.45, .poof: 0.7, .skill: 1.0, .boss: 1.0, .fence: 0.8,
    ]

    /// AVAudioEngine with decoded buffers: scheduling a buffer returns at once, where
    /// AVAudioPlayer's play/currentTime stop and prime an audio queue synchronously and
    /// held the main thread for tens of ms per sound (seconds when selling a full bag).
    /// Every AVFoundation call runs on `queue`, so the main thread never waits on audio.
    nonisolated private static let queue = DispatchQueue(label: "dustbloom.sfx", qos: .userInitiated)
    nonisolated private static let engine = AVAudioEngine()
    nonisolated(unsafe) private static var buffers: [Sound: AVAudioPCMBuffer] = [:]    // touched only on `queue`
    nonisolated(unsafe) private static var voices: [Sound: [AVAudioPlayerNode]] = [:]  // touched only on `queue`
    private static var next: [Sound: Int] = [:]
    private static var ready = false

    static func prepare() {
        guard !ready else { return }
        ready = true
        if UserDefaults.standard.object(forKey: "dustbloom.volume") != nil {
            master = Float(UserDefaults.standard.double(forKey: "dustbloom.volume"))
        }
        queue.async {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            for s in Sound.allCases {
                guard let url = Bundle.main.url(forResource: s.rawValue, withExtension: "wav"),
                      let f = try? AVAudioFile(forReading: url),
                      let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length)),
                      (try? f.read(into: b)) != nil else { continue }
                buffers[s] = b
                // a few voices per sound so quick taps overlap instead of cutting off
                voices[s] = (0..<3).map { _ in
                    let n = AVAudioPlayerNode()
                    engine.attach(n)
                    engine.connect(n, to: engine.mainMixerNode, format: b.format)
                    return n
                }
            }
            engine.prepare()
            startEngine()
            // a route change or interruption stops the engine; start it again on the next sound
            NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { _ in
                queue.async { startEngine() }
            }
        }
    }

    /// On `queue` only.
    nonisolated private static func startEngine() {
        guard !engine.isRunning else { return }
        try? engine.start()
        if engine.isRunning { for v in voices.values.joined() { v.play() } }
        #if DEBUG
        print("[sfx] engine running \(engine.isRunning), sounds \(buffers.count)")
        #endif
    }
    private static var lastPlayed: [Sound: TimeInterval] = [:]

    /// For battle sounds that fire many times a second: at most one per `gap`.
    static func playThrottled(_ s: Sound, gap: TimeInterval, volume: Float = 1) {
        let now = CACurrentMediaTime()
        if let t = lastPlayed[s], now - t < gap { return }
        lastPlayed[s] = now
        play(s, volume: volume * Float.random(in: 0.85...1))
    }

    static func play(_ s: Sound, volume: Float = 1, after delay: TimeInterval = 0) {
        prepare()
        let i = next[s] ?? 0
        next[s] = (i + 1) % 3
        let v = volume * master * (mix[s] ?? 1)
        guard v > 0 else { return }
        let fire: @Sendable () -> Void = {
            queue.async {
                guard let b = buffers[s], let pool = voices[s], !pool.isEmpty else { return }
                startEngine()
                guard engine.isRunning else { return }
                let n = pool[i % pool.count]
                n.volume = v
                // restarts this voice if it's still sounding, like rewinding a player
                n.scheduleBuffer(b, at: nil, options: .interrupts)
                if !n.isPlaying { n.play() }
            }
        }
        if delay > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: fire) } else { fire() }
    }
}
