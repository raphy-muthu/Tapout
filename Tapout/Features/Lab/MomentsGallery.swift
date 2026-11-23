#if DEBUG
import SwiftUI

/// DEBUG-only: the full-screen moments, for the simulator. The Sealed screen is the shield extension's
/// look; the Milestone rows open the real celebration.
struct MomentsGallery: View {
    let model: AppModel
    @State private var milestone: Milestone?
    @State private var timerDone: GalleryTimer?
    @State private var showingTimer = false
    @State private var timerHasApps = true
    @State private var intention = ""

    var body: some View {
        List {
            NavigationLink("Sealed screen") { SealedScreenMock() }
            Section("Timer") {
                Toggle("Mode has apps", isOn: $timerHasApps)
                Button("Timer sheet") { showingTimer = true }
                Button("Time's up, 45 min") { timerDone = GalleryTimer(duration: 45 * 60) }
                Button("Time's up, 1 h 30 min") { timerDone = GalleryTimer(duration: 90 * 60) }
                Button("Time's up, handed over to Evenings") {
                    timerDone = GalleryTimer(duration: 45 * 60, handedOverTo: "Evenings")
                }
            }
            Section("Milestone") {
                ForEach(Milestone.allCases) { item in
                    Button(item.title) { milestone = item }
                }
            }
        }
        .navigationTitle("Moments")
        .sheet(isPresented: $showingTimer) {
            // Start only closes the sheet here; nothing locks.
            TimerSheet(modeName: model.activeMode.name, hasApps: timerHasApps, hasTags: !model.places.isEmpty,
                       intention: $intention, recent: model.recentIntentions) { _ in true }
        }
        .fullScreenCover(item: $timerDone) {
            TimerDoneView(duration: $0.duration, handedOverTo: $0.handedOverTo) {}
        }
        .fullScreenCover(item: $milestone) { item in
            MilestoneView(milestone: item,
                          subtitle: item.subtitle(totalLocked: 36_000, interests: [.sports, .movies]))
        }
    }
}

private struct GalleryTimer: Identifiable {
    let duration: TimeInterval
    var handedOverTo: String? = nil
    var id: String { "\(duration)-\(handedOverTo ?? "")" }
}

/// The shield as iOS draws it: the icon centred, the title and subtitle in the system font, and a
/// full-width button at the bottom, on the background colour. This approximates iOS's layout; the real
/// screen is checked on the iPhone.
private struct SealedScreenMock: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            if let image = ShieldOrbArt.render() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120)
                    .accessibilityHidden(true)
            }
            Text("Sealed")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.ink)
                .padding(.top, Space.sm)
            Text("Tap a tag to open this app.")
                .font(.system(size: 17))
                .foregroundStyle(Color.inkSecondary)
                .padding(.top, Space.xxs)
            Spacer()
            Button {} label: {
                Text("Close")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.onEmber)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.ember, in: Capsule())
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .navigationTitle("Sealed screen")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
