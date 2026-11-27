import SwiftUI

@main
struct DustbloomApp: App {
    @StateObject private var store = FarmStore()
    @Environment(\.scenePhase) private var phase

    init() {
        FirebaseBridge.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .background {
                store.save()
                store.sessionEnd()
            }
        }
    }
}
