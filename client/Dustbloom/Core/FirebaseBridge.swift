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
        // Google Analytics silently drops events that use its reserved names
        // (our "session_start" was one), so those get a "bloom_" prefix.
        let event = reserved.contains(name) ? "bloom_" + name : name
        FirebaseAnalytics.Analytics.logEvent(String(event.prefix(40)), parameters: p)
        #endif
    }

    static let reserved: Set<String> = [
        "ad_activeview", "ad_click", "ad_exposure", "ad_impression", "ad_query", "ad_reward",
        "adunit_exposure", "app_background", "app_clear_data", "app_exception", "app_remove",
        "app_store_refund", "app_store_subscription_cancel", "app_store_subscription_convert",
        "app_store_subscription_renew", "app_update", "app_upgrade", "dynamic_link_app_open",
        "dynamic_link_app_update", "dynamic_link_first_open", "error", "first_open", "first_visit",
        "in_app_purchase", "notification_dismiss", "notification_foreground", "notification_open",
        "notification_receive", "os_update", "session_start", "session_start_with_rollout",
        "user_engagement",
    ]

    /// Stores one player message in Firestore (collection "dustbloom_feedback").
    static func sendFeedback(_ text: String, mood: String, extra: [String: Any]) async -> Bool {
        #if canImport(FirebaseCore)
        guard isOn else { return false }
        var doc: [String: Any] = extra
        doc["text"] = String(text.prefix(2000))
        doc["mood"] = mood
        doc["game"] = "dustbloom"
        doc["at"] = FieldValue.serverTimestamp()
        doc["app"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        doc["lang"] = Locale.current.language.languageCode?.identifier ?? "en"
        do {
            _ = try await Firestore.firestore().collection("dustbloom_feedback").addDocument(data: doc)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
}
