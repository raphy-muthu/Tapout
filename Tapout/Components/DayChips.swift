import SwiftUI

/// Monday-first day toggles sharing one row, for the Modes editor and onboarding.
struct DayChips: View {
    @Binding var days: Set<Int>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ModeSchedule.displayOrder, id: \.self) { day in
                ChoiceChip(title: Calendar.current.veryShortWeekdaySymbols[day - 1], isOn: days.contains(day), fillsWidth: true) {
                    if days.contains(day) { days.remove(day) } else { days.insert(day) }
                }
                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
            }
        }
    }
}
