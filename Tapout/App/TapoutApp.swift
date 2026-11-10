import SwiftUI

@main
struct TapoutApp: App {
    // State, so a body re-evaluation can't rebuild the model (and re-run -demoData seeding).
    // The model comes first: -demoData seeds the passes the engine reads.
    #if DEBUG
    @State private var model = AppModel.fromLaunchArguments()
    @State private var engine = LockEngine.fromLaunchArguments()
    #else
    @State private var model = AppModel.live()
    @State private var engine = LockEngine.live()
    #endif

    var body: some Scene {
        WindowGroup {
            RootView(engine: engine, model: model)
        }
    }
}
