import SwiftUI

/// The optional "What's it for?" field above Scan, with recent intentions as one-tap chips.
struct IntentionField: View {
    @Binding var text: String
    let recent: [String]

    var body: some View {
        VStack(spacing: Space.xs) {
            TextField(text: $text, prompt: Text("What's it for?").foregroundStyle(Color.inkTertiary)) {
                Text("What's it for?")
            }
            .font(.tBody)
            .foregroundStyle(Color.ink)
            .submitLabel(.done)
            .padding(.horizontal, Space.md)
            // Grows with large text; at default sizes the 44pt minimum sets the height.
            .padding(.vertical, Space.xs)
            .frame(minHeight: 44)
            .background(Color.surface1, in: Capsule(style: .continuous))
            .cardShadow()
            .accessibilityHint("Optional")
            .onChange(of: text) { _, new in
                if new.count > AppModel.intentionLimit { text = String(new.prefix(AppModel.intentionLimit)) }
            }
            if !recent.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.xs) {
                        ForEach(recent, id: \.self) { item in
                            ChoiceChip(title: item, isOn: text == item) { text = text == item ? "" : item }
                        }
                    }
                }
            }
        }
    }
}
