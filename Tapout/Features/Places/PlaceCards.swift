import SwiftUI

/// The tag "puck" from Places.dc.html: a recessed disc, a slate ring and a glowing ember dot.
struct PlacePuck: View {
    var size: CGFloat = 148

    var body: some View {
        Circle()
            .fill(Color.surface2
                .shadow(.inner(color: .black.opacity(0.2), radius: 7, y: -6))
                .shadow(.inner(color: .white.opacity(0.07), radius: 5, y: 4)))
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .strokeBorder(Color.slateLine, lineWidth: 2)
                    .frame(width: size * 0.65, height: size * 0.65)
                    .opacity(0.8)
            }
            .overlay {
                Circle().fill(Color.ember).frame(width: 14, height: 14).shadow(color: .ember, radius: 8)
            }
            .accessibilityHidden(true)
    }
}

/// The hero card for the default place.
struct DefaultPlaceCard: View {
    let name: String
    let locks: Int

    var body: some View {
        VStack(spacing: 20) {
            PlacePuck()
            VStack(spacing: Space.xxs) {
                Text(name).font(.tTitle1).foregroundStyle(Color.ink)
                Text("Default · \(Copy.count(locks, "lock", "locks"))")
                    .font(.tSubhead)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .card(radius: Radius.sheet)
        .accessibilityElement(children: .combine)
    }
}

/// A grid tile for every other place.
struct PlaceTile: View {
    let name: String
    let locks: Int

    var body: some View {
        HStack(spacing: Space.sm) {
            Circle()
                .fill(Color.surface2)
                .frame(width: 44, height: 44)
                .overlay { Circle().fill(Color.slateLine).frame(width: 8, height: 8) }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.tHeadline).foregroundStyle(Color.ink).lineLimit(1).minimumScaleFactor(0.8)
                Text(Copy.count(locks, "lock", "locks")).font(.tFootnote).foregroundStyle(Color.inkSecondary)
            }
        }
        .card(padding: 20)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
private struct PlaceCardsPreview: View {
    var body: some View {
        VStack(spacing: Space.sm) {
            DefaultPlaceCard(name: "Kitchen", locks: 12)
            PlaceTile(name: "Desk", locks: 3)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg)
    }
}

#Preview("Place cards · dark") { PlaceCardsPreview().preferredColorScheme(.dark) }
#Preview("Place cards · light") { PlaceCardsPreview().preferredColorScheme(.light) }
#endif
