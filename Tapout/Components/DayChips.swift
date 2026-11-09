import SwiftUI

/// Monday-first day toggles sharing one row, for the Modes editor and onboarding.
struct DayChips: View {
    @Binding var days: Set<Int>

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Two rows at accessibility sizes, so each letter keeps room inside its chip.
        if typeSize.isAccessibilitySize {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) { chips }
        } else {
            HStack(spacing: 6) { chips }
        }
    }

    private var chips: some View {
        ForEach(ModeSchedule.displayOrder, id: \.self) { day in
            ChoiceChip(title: Calendar.current.veryShortWeekdaySymbols[day - 1], isOn: days.contains(day), fillsWidth: true) {
                if days.contains(day) { days.remove(day) } else { days.insert(day) }
            }
            .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
        }
    }
}
