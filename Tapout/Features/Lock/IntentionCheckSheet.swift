import SwiftUI

/// A finished lock that had an intention.
struct IntentionCheck: Identifiable, Equatable {
    /// The lock's start, which identifies it in the history.
    let id: Date
    let intention: String
}

/// "Did you do it?" after unlocking. Two equal answers, no score; swiping away records nothing.
struct IntentionCheckSheet: View {
    let check: IntentionCheck
    let onAnswer: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At accessibility sizes the sheet opens full height, the intention shows in full and the answers stack.
        let large = typeSize.isAccessibilitySize
        Group {
            if large {
                ScrollView { content(large: true) }.scrollIndicators(.hidden)
            } else {
                content(large: false)
            }
        }
        .presentationDetents(large ? [.large] : [.height(260), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(Color.surface1)
    }

    private func content(large: Bool) -> some View {
        VStack(spacing: Space.lg) {
            VStack(spacing: Space.xs) {
                Text("Did you do it?").font(.tTitle).foregroundStyle(Color.ink)
                Text(check.intention)
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(large ? nil : 2)
            }
            .multilineTextAlignment(.center)
            (large ? AnyLayout(VStackLayout(spacing: Space.sm)) : AnyLayout(HStackLayout(spacing: Space.sm))) {
                answer("Not yet", done: false)
                answer("Done", done: true)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xl)
        .padding(.bottom, Space.lg)
    }

    private func answer(_ title: String, done: Bool) -> some View {
        Button {
            Haptics.select()
            onAnswer(done)
            dismiss()
        } label: {
            Text(title)
                .font(.tHeadline)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .center : .leading)
                .padding(.horizontal, typeSize.isAccessibilitySize ? Space.md : 0)
                .padding(.vertical, typeSize.isAccessibilitySize ? Space.xs : 0)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color.surface2, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
    }
}

#Preview("Check · dark") {
    Color.bg.sheet(isPresented: .constant(true)) {
        IntentionCheckSheet(check: IntentionCheck(id: .now, intention: "History essay, first paragraph")) { _ in }
    }
    .preferredColorScheme(.dark)
}

#Preview("Check · light") {
    Color.bg.sheet(isPresented: .constant(true)) {
        IntentionCheckSheet(check: IntentionCheck(id: .now, intention: "History essay, first paragraph")) { _ in }
    }
    .preferredColorScheme(.light)
}
