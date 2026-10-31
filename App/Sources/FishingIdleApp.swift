import SwiftUI

@main
struct FishingIdleApp: App {
    @StateObject private var game = GameViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active: game.resume()
                    case .inactive, .background: game.pauseAndSave()
                    @unknown default: break
                    }
                }
        }
    }
}
