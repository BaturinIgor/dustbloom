import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
import FirebaseAnalytics
import FirebaseFirestore
#endif

/// Firebase glue. Analytics events and player feedback go to Firebase when
/// GoogleService-Info.plist is in the app (it lives only on the build Mac, never
/// in the public repo); without it everything is a quiet no-op.
@MainActor
enum FirebaseBridge {
    private(set) static var isOn = false

    static func start() {
        #if canImport(FirebaseCore)
        guard !isOn, Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        FirebaseApp.configure()
        isOn = true
        #endif
    }

    /// Mirrors one of our analytics events. Firebase allows 40-char names and
    /// 100-char string params, so both are trimmed.
    static func log(_ name: String, _ props: [String: Any]) {
        #if canImport(FirebaseCore)
        guard isOn else { return }
        var p: [String: Any] = [:]
        for (k, v) in props.prefix(25) {
            if let s = v as? String { p[String(k.prefix(40))] = String(s.prefix(100)) } else { p[String(k.prefix(40))] = v }
        }
        FirebaseAnalytics.Analytics.logEvent(String(name.prefix(40)), parameters: p)
        #endif
    }

    /// Stores one player message in Firestore (collection "feedback").
    static func sendFeedback(_ text: String, mood: String, extra: [String: Any]) async -> Bool {
        #if canImport(FirebaseCore)
        guard isOn else { return false }
        var doc: [String: Any] = extra
        doc["text"] = String(text.prefix(2000))
        doc["mood"] = mood
        doc["at"] = FieldValue.serverTimestamp()
        doc["app"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        doc["lang"] = Locale.current.language.languageCode?.identifier ?? "en"
        do {
            _ = try await Firestore.firestore().collection("feedback").addDocument(data: doc)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
}
