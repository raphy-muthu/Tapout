import Foundation

/// Spec-like sample data: four modes, four places and a week of locks. Used by previews and,
/// in DEBUG, by the `-demoData` launch argument for screenshots. Never runs in normal use.
enum DemoData {
    static let kitchen = TagUID(hex: "04A1B2C3D4E501")
    static let desk = TagUID(hex: "04A1B2C3D4E502")
    static let car = TagUID(hex: "04A1B2C3D4E503")
    static let bedroom = TagUID(hex: "04A1B2C3D4E504")

    /// Replaces modes, places, the default place, the lock history and the passes. Leaves lock state alone.
    static func seed(_ store: SharedStore, now: Date = .now, calendar: Calendar = .current) {
        let pairedAt = now.addingTimeInterval(-30 * 86_400)
        store.pairedTags = [
            PairedTag(uid: kitchen, name: "Kitchen", pairedAt: pairedAt),
            PairedTag(uid: desk, name: "Desk", pairedAt: pairedAt),
            PairedTag(uid: car, name: "Car", pairedAt: pairedAt),
            PairedTag(uid: bedroom, name: "Bedroom", pairedAt: pairedAt),
        ]
        store.defaultPlace = kitchen

        let deepWork = Mode(
            name: "Deep work",
            schedule: ModeSchedule(days: ModeSchedule.weekdays, start: 9 * 60, end: 17 * 60),
            unlockPlaces: [kitchen]
        )
        let evenings = Mode(
            name: "Evenings",
            schedule: ModeSchedule(days: ModeSchedule.everyDay, start: 19 * 60, end: 22 * 60),
            unlockPlaces: [kitchen, desk]
        )
        let weekend = Mode(name: "Weekend", schedule: ModeSchedule(days: ModeSchedule.weekend, start: 10 * 60, end: 18 * 60))
        let sleep = Mode(
            name: "Sleep",
            schedule: ModeSchedule(days: ModeSchedule.everyDay, start: 22 * 60 + 30, end: 7 * 60),
            unlockPlaces: [bedroom]
        )
        store.modes = [deepWork, evenings, weekend, sleep]
        store.activeModeID = deepWork.id
        store.lockHistory = history(deepWork: deepWork.id, evenings: evenings.id, now: now, calendar: calendar)
        store.interests = [.sports, .movies]
        store.passesLeft = 3 // what the specs show
    }

    /// A model over a scratch store, seeded, for `#Preview`s.
    @MainActor
    static func previewModel() -> AppModel {
        let store = SharedStore(defaults: UserDefaults(suiteName: "tapout.preview")!)
        seed(store)
        return AppModel(store: store)
    }

    /// Two locks a day for the past week; nothing in the future.
    private static func history(deepWork: UUID, evenings: UUID, now: Date, calendar: Calendar) -> [LockRecord] {
        let places = [kitchen, desk, car, bedroom]
        var records: [LockRecord] = []
        for day in 0..<7 {
            guard let midnight = calendar.date(byAdding: .day, value: -day, to: calendar.startOfDay(for: now)) else { continue }
            let morning = midnight.addingTimeInterval(9.5 * 3600)
            // Today's goal is unanswered, so Goals done reads "2 of 3" whatever the time of day.
            let goals: [(String, Bool?)] = [("Reading", nil), ("Essay outline", true), ("Chapter 4 notes", true), ("Problem set", false)]
            let goal = day < goals.count ? goals[day] : nil
            records.append(LockRecord(start: morning, end: morning + Double(60 + day * 10) * 60,
                                      placeUID: places[day % places.count], modeID: deepWork,
                                      intention: goal?.0, intentionDone: goal?.1 ?? nil))
            let evening = midnight.addingTimeInterval(19.5 * 3600)
            records.append(LockRecord(start: evening, end: evening + 45 * 60, placeUID: kitchen, modeID: evenings))
        }
        return records.filter { ($0.end ?? now) <= now }
    }
}

#if DEBUG
extension AppModel {
    /// Launch arguments for screenshots and testing:
    /// `-demoData` replaces the App Group's modes, places, history and passes with `DemoData` and skips onboarding;
    /// `-skipOnboarding` skips it without sample data; `-resetOnboarding` shows it again;
    /// `-resetMilestones` lets milestones show again.
    static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> AppModel {
        let store = SharedStore.appGroup()
        if arguments.contains("-demoData") { DemoData.seed(store) }
        if arguments.contains("-demoData") || arguments.contains("-skipOnboarding") {
            UserDefaults.standard.set(true, forKey: AppSettings.onboardedKey)
        }
        if arguments.contains("-resetOnboarding") { UserDefaults.standard.set(false, forKey: AppSettings.onboardedKey) }
        if arguments.contains("-resetMilestones") { store.seenMilestones = [] }
        // Demo modes are for screenshots: they must not register real activities.
        let schedules: any ScheduleRegistering = arguments.contains("-demoData") ? NoSchedules() : ScheduleRegistrars.live(store: store)
        return AppModel(store: store, schedules: schedules)
    }
}
#endif
