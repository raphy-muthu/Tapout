import SwiftUI

@main
struct TapoutApp: App {
    // State, so a body re-evaluation can't rebuild the model (and re-run -demoData seeding).
    // The model comes first: -demoData seeds the passes the controller reads.
    #if DEBUG
    @State private var model = AppModel.fromLaunchArguments()
    @State private var controller = MockLockController.fromLaunchArguments()
    #else
    @State private var model = AppModel.live()
    @State private var controller = MockLockController(store: .appGroup())
    #endif

    var body: some Scene {
        WindowGroup {
            RootView(controller: controller, model: model)
        }
    }
}
