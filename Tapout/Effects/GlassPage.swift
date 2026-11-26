import SwiftUI

/// The page color, and with the switch on the breathing glow over it. Behind the tabs, sheets and onboarding.
struct GlassPageBackground: View {
    let tone: OrbTone
    var isOn: Bool
    /// 1 is Home's glow; screens made mostly of text use `BackdropPlan.readingStrength`.
    var strength: Double = BackdropPlan.readingStrength

    var body: some View {
        ZStack {
            Color.bg
            if isOn {
                LivingGlassReader { choice in
                    LivingBackdrop(tone: tone, animates: choice == .glass)
                        .opacity(strength)
                }
            }
        }
    }
}

/// Fades a page out where it passes under the status bar, without painting over the glow behind it.
struct StatusBarFade: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content.mask {
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        // Gone behind the clock, so a scrolled title never competes with it.
                        LinearGradient(stops: [.init(color: .clear, location: 0.55), .init(color: .black, location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: proxy.safeAreaInsets.top)
                        Color.black
                    }
                    .ignoresSafeArea()
                }
            }
        } else {
            content
        }
    }
}
