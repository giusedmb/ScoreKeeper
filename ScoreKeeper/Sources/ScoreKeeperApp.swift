import SwiftUI

@main
struct ScoreKeeperApp: App {
    @State private var store = GameStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}
