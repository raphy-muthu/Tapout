import SwiftUI

@main
struct TapoutApp: App {
    // State, so a body re-evaluation can't rebuild the model (and re-run -demoData seeding).
    #if DEBUG
    @State private var controller = MockLockController.fromLaunchArguments()
    @State private var model = AppModel.fromLaunchArguments()
    #else
    @State private var controller = MockLockController()
    @State private var model = AppModel.live()
    #endif

    var body: some Scene {
        WindowGroup {
            RootView(controller: controller, model: model)
        }
    }
}
