import SwiftUI

@main
struct BugTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            HUDView()
                .preferredColorScheme(.dark)
        }
    }
}
