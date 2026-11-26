import Foundation

/// First-party analytics. The server already logs every game action it
/// receives, so the client only sends what the server can't see: sessions,
/// screens, local refusals, level-ups, review and feedback moments.
/// Events are batched (once a minute or 50 at a time), kept across launches
/// if offline (at most 500), and never include advertising ids.
@MainActor
final class Analytics {
    static let shared = Analytics()

    enum Value: Codable, Equatable {
        case text(String)
        case number(Double)
        case flag(Bool)

        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .text(let s): try c.encode(s)
            case .number(let n): try c.encode(n)
            case .flag(let b): try c.encode(b)
            }
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let b = try? c.decode(Bool.self) { self = .flag(b) }
            else if let n = try? c.decode(Double.self) { self = .number(n) }
            else { self = .text(try c.decode(String.self)) }
        }
    }

    struct Event: Codable, Equatable {
        var name: String
        var at: Date
        var props: [String: Value]?
    }

    private struct Batch: Encodable {
        var session: String
        var app: String
        var lang: String
        var events: [Event]
    }

    /// Set by FarmStore once logged in; nil means offline (events wait).
    var sender: ((Data) async throws -> Void)?

    let session = UUID().uuidString
    private var queue: [Event] = []
    private var flushing = false
    private let storeKey = "dustbloom.analytics.queue"
    private static let maxQueue = 500
    private static let batchSize = 50

    private init() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let saved = try? JSONDecoder().decode([Event].self, from: data) {
            queue = saved
        }
    }

    func track(_ name: String, _ props: [String: Any] = [:]) {
        var p: [String: Value] = [:]
        for (k, v) in props {
            switch v {
            case let b as Bool: p[k] = .flag(b)
            case let i as Int: p[k] = .number(Double(i))
            case let d as Double: p[k] = .number(d)
            case let s as String: p[k] = .text(s)
            default: p[k] = .text(String(describing: v))
            }
        }
        queue.append(Event(name: name, at: Date(), props: p.isEmpty ? nil : p))
        if queue.count > Self.maxQueue { queue.removeFirst(queue.count - Self.maxQueue) }
        if queue.count >= Self.batchSize { Task { await flush() } }
    }

    /// Sends what is queued; on failure the events stay for the next try.
    func flush() async {
        guard let sender, !flushing, !queue.isEmpty else { return }
        flushing = true
        defer { flushing = false }
        while !queue.isEmpty {
            let part = Array(queue.prefix(100))
            let batch = Batch(
                session: session,
                app: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
                lang: Locale.current.language.languageCode?.identifier ?? "en",
                events: part)
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            guard let data = try? enc.encode(batch) else { queue.removeFirst(part.count); continue }
            do {
                try await sender(data)
                queue.removeFirst(min(part.count, queue.count))
            } catch {
                return
            }
        }
    }

    /// Keeps unsent events for the next launch.
    func persist() {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }
}

/// When to ask for an App Store rating: only at a happy moment, after the
/// player has had time to like the game, and rarely. Apple shows the dialog
/// at most 3 times a year anyway; we never ask after a loss or an error, and
/// we never pre-filter ("do you like the game?"), which Apple forbids.
struct ReviewPolicy {
    var defaults = UserDefaults.standard

    private let launchesKey = "dustbloom.review.launches"
    private let firstKey = "dustbloom.review.first"
    private let lastKey = "dustbloom.review.last"
    private let versionKey = "dustbloom.review.version"
    private let badKey = "dustbloom.review.bad"

    func noteLaunch(now: Date = Date()) {
        defaults.set(defaults.integer(forKey: launchesKey) + 1, forKey: launchesKey)
        if defaults.object(forKey: firstKey) == nil { defaults.set(now, forKey: firstKey) }
    }

    /// Something went wrong for the player: no asking for a while.
    func noteBadMoment(now: Date = Date()) {
        defaults.set(now, forKey: badKey)
    }

    func shouldAsk(level: Int, now: Date = Date(), version: String) -> Bool {
        guard level >= 5, defaults.integer(forKey: launchesKey) >= 3 else { return false }
        if let first = defaults.object(forKey: firstKey) as? Date, now.timeIntervalSince(first) < 2 * 86400 { return false }
        if let last = defaults.object(forKey: lastKey) as? Date, now.timeIntervalSince(last) < 120 * 86400 { return false }
        if let bad = defaults.object(forKey: badKey) as? Date, now.timeIntervalSince(bad) < 600 { return false }
        return defaults.string(forKey: versionKey) != version
    }

    func noteAsked(now: Date = Date(), version: String) {
        defaults.set(now, forKey: lastKey)
        defaults.set(version, forKey: versionKey)
    }
}
