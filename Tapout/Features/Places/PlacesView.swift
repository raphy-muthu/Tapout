import SwiftUI

/// The Places tab, per the list view in design/screens/Places.dc.html.
struct PlacesView: View {
    let model: AppModel

    @Environment(\.isLocked) private var isLocked
    @State private var pairing = false
    @State private var selected: PairedTag?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Places", addLabel: "Pair a place") { pairing = true }
                Group {
                    if let place = model.defaultPlace {
                        Button { selected = place } label: {
                            DefaultPlaceCard(name: place.name, locks: model.lockCount(at: place.uid))
                        }
                        .buttonStyle(PressScaleStyle())
                    } else {
                        emptyCard
                    }
                }
                .padding(.top, Space.lg)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.sm), GridItem(.flexible())], spacing: Space.sm) {
                    ForEach(model.otherPlaces) { place in
                        Button { selected = place } label: {
                            PlaceTile(name: place.name, locks: model.lockCount(at: place.uid))
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                    DashedTile(title: "Pair") { pairing = true }
                        .disabled(isLocked)
                }
                .padding(.top, Space.sm)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.xs)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $pairing) { PairPlaceSheet(model: model) }
        .sheet(item: $selected) { PlaceSheet(model: model, place: $0) }
        .onChange(of: isLocked) { _, locked in
            if locked { pairing = false }
        }
    }

    private var emptyCard: some View {
        VStack(spacing: Space.xs) {
            Text("No places yet").font(.tTitle).foregroundStyle(Color.ink)
            Text("Pair a tag to make your first place.").font(.tSubhead).foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
        .card(radius: Radius.sheet)
    }
}

#if DEBUG
#Preview("Places · dark") {
    PlacesView(model: DemoData.previewModel()).background(Color.bg).preferredColorScheme(.dark)
}

#Preview("Places · light") {
    PlacesView(model: DemoData.previewModel()).background(Color.bg).preferredColorScheme(.light)
}

#Preview("Places · locked") {
    PlacesView(model: DemoData.previewModel()).background(Color.bg)
        .environment(\.isLocked, true).preferredColorScheme(.dark)
}
#endif
