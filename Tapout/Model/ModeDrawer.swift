import Foundation

/// Which Modes card sits where, and which one is open, with the Living glass switch on.
enum ModeDrawer {
    /// The cards' order. On arrival the active mode leads; after that cards hold their places, so one doesn't
    /// jump when it becomes active. New modes go last and deleted ones drop out.
    static func order(_ ids: [UUID], held: [UUID], active: UUID) -> [UUID] {
        if held.isEmpty { return ids.filter { $0 == active } + ids.filter { $0 != active } }
        let kept = held.filter(ids.contains)
        return kept + ids.filter { !kept.contains($0) }
    }

    /// One drawer at a time; tapping the open one closes it.
    static func toggled(_ id: UUID, open: UUID?) -> UUID? {
        open == id ? nil : id
    }
}
