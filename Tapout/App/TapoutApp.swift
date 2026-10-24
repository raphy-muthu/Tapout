import SwiftUI

@main
struct TapoutApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            RootView(controller: .fromLaunchArguments())
            #else
            RootView()
            #endif
        }
    }
}
