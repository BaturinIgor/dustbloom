import AppTrackingTransparency
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// Rewarded video through Google AdMob (shop: golden hour for a short video).
/// Start order: consent (UMP, needed in Europe), the iOS tracking prompt, the SDK, then the first video.
/// App id: Info.plist GADApplicationIdentifier. Ad unit for App Store builds: AdMobRewardedUnit.
/// Debug and TestFlight builds always get Google's test video (marked "Test Ad", earns nothing):
/// watching your own real ads gets the AdMob account banned.
@MainActor
final class RewardedAds: NSObject, FullScreenContentDelegate {
    static let shared = RewardedAds()

    /// Google's test rewarded unit.
    static let testUnit = "ca-app-pub-3940256099942544/1712485313"

    /// nil: no ads in this build (App Store build before the real unit id is filled in).
    static var unitId: String? {
        #if DEBUG
        return testUnit
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" { return testUnit }
        let value = (Bundle.main.object(forInfoDictionaryKey: "AdMobRewardedUnit") as? String) ?? ""
        return value.isEmpty ? nil : value
        #endif
    }

    /// Store screenshots and the demo autopilot: no consent form, no video, reward at once.
    private static var instant: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-bloomShowcase") || args.contains("-bloomDemo")
        #else
        return false
        #endif
    }

    private var started = false
    private var sdkReady = false
    private var loading = false
    private var ad: RewardedAd?
    private var loadedAt = Date.distantPast
    private var retry = 0
    private var waiting: ((Bool) -> Void)?
    private var presenting: ((Bool) -> Void)?
    private var earned = false

    /// Debug builds: every step into the device log (filter "[ads]").
    private static func trace(_ text: String) {
        #if DEBUG
        NSLog("[ads] %@", text)
        #endif
    }

    // MARK: the API the shop uses

    /// The "watch" button is enabled: this build has an ad unit and the player may see ads.
    static var isAvailable: Bool {
        if instant { return true }
        guard unitId != nil else { return false }
        return !shared.sdkReady || ConsentInformation.shared.canRequestAds
    }

    /// Plays a video; `done(true)` only when it was watched to the end.
    static func show(_ done: @escaping (Bool) -> Void) { shared.showRewarded(done) }

    /// Called once the farm is on screen. A second call does nothing.
    static func start() { shared.start() }

    /// Google's privacy options form (required where GDPR applies).
    static var privacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    static func showPrivacyOptions() {
        guard let vc = topController() else { return }
        ConsentForm.presentPrivacyOptionsForm(from: vc) { _ in
            Task { @MainActor in
                if ConsentInformation.shared.canRequestAds { shared.startSDK() }
            }
        }
    }

    // MARK: start

    private func start() {
        guard !started, !Self.instant, Self.unitId != nil else { return }
        started = true
        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { error in
            Task { @MainActor in
                if let error { Analytics.shared.track("ads_consent_error", ["error": error.localizedDescription]) }
                self.presentConsentIfNeeded()
            }
        }
        // consent from an earlier launch: the SDK may start right away
        if ConsentInformation.shared.canRequestAds { startSDK() }
    }

    private func presentConsentIfNeeded() {
        guard let vc = Self.topController() else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { MainActor.assumeIsolated { self.presentConsentIfNeeded() } }
            return
        }
        ConsentForm.loadAndPresentIfRequired(from: vc) { error in
            Task { @MainActor in
                if let error { Analytics.shared.track("ads_consent_form_error", ["error": error.localizedDescription]) }
                Analytics.shared.track("ads_consent", ["can_request": ConsentInformation.shared.canRequestAds])
                self.requestTracking {
                    if ConsentInformation.shared.canRequestAds { self.startSDK() }
                }
            }
        }
    }

    /// The system tracking question. Without a yes the videos still play, just not personalized.
    private func requestTracking(_ done: @escaping @MainActor () -> Void) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return done() }
        // the prompt only appears while the app is active: give the window a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            ATTrackingManager.requestTrackingAuthorization { status in
                Task { @MainActor in
                    Analytics.shared.track("att", ["status": status == .authorized ? "authorized" : "other"])
                    done()
                }
            }
        }
    }

    private func startSDK() {
        guard !sdkReady else { return }
        sdkReady = true
        Self.trace("sdk start")
        MobileAds.shared.start { _ in Task { @MainActor in self.load() } }
    }

    // MARK: loading

    /// A loaded video lives about an hour.
    private var adFresh: Bool { ad != nil && Date().timeIntervalSince(loadedAt) < 3500 }

    private func load() {
        guard sdkReady, !loading, !adFresh, let unit = Self.unitId else { return }
        loading = true
        RewardedAd.load(with: unit, request: Request()) { ad, error in
            Task { @MainActor in
                self.loading = false
                Self.trace("loaded: \(ad != nil) \(error?.localizedDescription ?? "")")
                if let ad {
                    ad.fullScreenContentDelegate = self
                    self.ad = ad
                    self.loadedAt = Date()
                    self.retry = 0
                    if let waiting = self.waiting {
                        self.waiting = nil
                        self.present(waiting)
                    }
                } else {
                    self.ad = nil
                    Analytics.shared.track("ad_load_error", ["error": error?.localizedDescription ?? ""])
                    self.failWaiting()
                    // retry with a growing pause: 4, 8, 16, 32 s
                    self.retry = min(self.retry + 1, 4)
                    let delay = pow(2.0, Double(self.retry)) * 2
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { MainActor.assumeIsolated { self.load() } }
                }
            }
        }
    }

    // MARK: showing

    private func showRewarded(_ done: @escaping (Bool) -> Void) {
        if Self.instant {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { done(true) }
            return
        }
        Self.trace("show: fresh=\(adFresh) sdk=\(sdkReady) presenting=\(presenting != nil) waiting=\(waiting != nil)")
        guard presenting == nil, waiting == nil else { return }
        Analytics.shared.track("ad_request", ["ready": adFresh])
        if adFresh { return present(done) }
        // no video yet: wait for it a few seconds
        if !started { start() }
        waiting = done
        load()
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { MainActor.assumeIsolated { self.failWaiting() } }
    }

    private func failWaiting() {
        guard let waiting else { return }
        self.waiting = nil
        Analytics.shared.track("ad_fail", ["reason": "not_loaded"])
        waiting(false)
    }

    private func present(_ done: @escaping (Bool) -> Void) {
        Self.trace("present: ad=\(ad != nil) vc=\(String(describing: Self.topController()))")
        guard let ad, let vc = Self.topController() else { return done(false) }
        self.ad = nil
        earned = false
        presenting = done
        Music.pause()
        Analytics.shared.track("ad_show")
        ad.present(from: vc) { [weak self] in
            Task { @MainActor in self?.earned = true }
        }
    }

    private func finish() {
        Music.resume()
        guard let done = presenting else { return }
        presenting = nil
        let ok = earned
        Analytics.shared.track(ok ? "ad_watched" : "ad_fail", ok ? [:] : ["reason": "closed_early"])
        // reward after the video closes, so the golden hour animation is seen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { done(ok) }
        load()
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            Analytics.shared.track("ad_present_error", ["error": message])
            self.earned = false
            self.finish()
        }
    }

    // MARK: window

    static func topController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return nil }
        let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        var vc = window?.rootViewController
        while let next = vc?.presentedViewController, !next.isBeingDismissed { vc = next }
        return vc
    }
}
