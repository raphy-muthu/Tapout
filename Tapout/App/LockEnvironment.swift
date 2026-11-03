import SwiftUI

extension EnvironmentValues {
    /// True while a lock (or an emergency pass within it) is running. Everything editable is read-only then.
    @Entry var isLocked = false
}
