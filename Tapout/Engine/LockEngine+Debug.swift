#if DEBUG
import Foundation

extension LockEngine {
    /// `-mockState locked|emergency` starts in that state, for screenshots. `locked` writes the
    /// App Group like a real lock; `emergency` runs on a scratch store, so it can't spend a real pass.
    static func fromLaunchArguments(
        _ arguments: [String] = ProcessInfo.processInfo.arguments,
        store: SharedStore = .appGroup()
    ) -> LockEngine {
        // Timer screenshots. They write the App Group like a real timer lock (the simulator's stand-ins
        // shield nothing), so Home, the record and the clock all follow. The engine's `tick()` ends them.
        // `-demoTimer`: 45 min with 31:20 left. `-demoTimerShort`: 8 s left, to watch it end.
        // `-demoTimerDone`: one that ended while Tapout was closed, for the Time's up cover at launch.
        // `-demoTimerHandover`: the same, ended inside a scheduled window, so a mode's scheduled lock took over.
        if arguments.contains("-demoTimer") {
            DemoData.seedTimer(store, left: 31 * 60 + 20)
            return live(store: store)
        }
        if arguments.contains("-demoTimerShort") {
            DemoData.seedTimer(store, left: 8)
            return live(store: store)
        }
        if arguments.contains("-demoTimerHandover") {
            DemoData.seedFinishedTimer(store, handedOver: true)
            return live(store: store)
        }
        if arguments.contains("-demoTimerDone") {
            DemoData.seedFinishedTimer(store)
            return live(store: store)
        }
        guard let index = arguments.firstIndex(of: "-mockState"), index + 1 < arguments.count else {
            return live(store: store)
        }
        let now = Date()
        switch arguments[index + 1] {
        case "locked":
            store.session = .locked(since: now - (47 * 60 + 12))
            return live(store: store)
        case "emergency":
            return preview(session: .emergency(relockAt: now + (4 * 60 + 32), duration: emergencyDuration), passesLeft: 2)
        default:
            return live(store: store)
        }
    }

    /// An engine on a scratch store with no Screen Time, for `#Preview`s.
    static func preview(session: LockSession = .unlocked, passesLeft: Int = SharedStore.totalPasses) -> LockEngine {
        let store = SharedStore(defaults: UserDefaults(suiteName: "tapout.preview.\(UUID().uuidString)")!)
        store.session = session
        store.passesLeft = passesLeft
        return LockEngine(store: store, shields: NoShields(), relock: NoRelock(), passes: MemoryPassVault())
    }
}
#endif
