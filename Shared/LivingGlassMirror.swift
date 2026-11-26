import Foundation

/// The Lab's Living glass switch, copied into the App Group so the widgets, the Live Activity and the shield
/// can follow it; they can't read the app's own settings. Debug builds only: it reads off in Release, whatever
/// is stored. Stands alone, because the shield compiles no other shared file.
enum LivingGlassMirror {
    static let appGroupID = "group.com.raphymuthu.tapout"
    static let key = "livingGlass.surfaces"

    static var shared: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    static func isOn(_ defaults: UserDefaults? = LivingGlassMirror.shared) -> Bool {
        #if DEBUG
        defaults?.bool(forKey: key) ?? false
        #else
        false
        #endif
    }

    /// Writes the switch. Returns true when that changed it, so the surfaces need redrawing.
    @discardableResult
    static func set(_ on: Bool, in defaults: UserDefaults? = LivingGlassMirror.shared) -> Bool {
        guard let defaults, defaults.bool(forKey: key) != on else { return false }
        defaults.set(on, forKey: key)
        return true
    }

    /// The shield's picture: the classic orb, or the glass one (both in the shield's asset catalog).
    static func shieldImageName(glass: Bool) -> String {
        glass ? "SealedOrbGlass" : "SealedOrb"
    }
}
