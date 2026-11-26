import Metal
import SwiftUI

/// Whether the app's default Metal library contains the `glassOrb` shader. Without it the glass orb
/// cannot draw, so the flag must never select it.
enum GlassOrbShader {
    static let isAvailable: Bool =
        MTLCreateSystemDefaultDevice()?.makeDefaultLibrary()?.makeFunction(name: "glassOrb") != nil
}

/// Which orb to draw.
enum LivingOrbChoice: Equatable {
    case classic, glass

    /// `shaderAvailable` is evaluated last, so with the flag off the Metal library is never probed.
    static func choose(flag: Bool, level: MotionLevel,
                       shaderAvailable: @autoclosure () -> Bool = GlassOrbShader.isAvailable) -> LivingOrbChoice {
        flag && level == .full && shaderAvailable() ? .glass : .classic
    }

    /// Only the background stills the orb. The NFC sheet, Control Center and the app switcher make
    /// the scene inactive, and swapping the orb then would flash classic during every lock and unlock.
    static func sceneCountsAsActive(_ phase: ScenePhase) -> Bool {
        phase != .background
    }
}

/// The Lab's living-glass switch, observed (`@AppStorage`), with `AppSettings.livingGlassEnabled`'s
/// semantics: off unless set, and always false in Release.
@propertyWrapper
struct LivingGlassFlag: DynamicProperty {
    @AppStorage(AppSettings.livingGlassKey) private var stored = false

    var wrappedValue: Bool {
        #if DEBUG
        stored
        #else
        false
        #endif
    }
}

/// Reads what decides the orb (the Debug-only flag, Reduce Motion, scene phase, the motion environment,
/// and the shader only when the flag is on) and hands the choice to `content`.
struct LivingGlassReader<Content: View>: View {
    private let content: (LivingOrbChoice) -> Content

    /// The Lab's switch. Always false in Release (see `AppSettings.livingGlassEnabled`).
    @LivingGlassFlag private var flag
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private let environment = MotionEnvironment.shared

    init(@ViewBuilder content: @escaping (LivingOrbChoice) -> Content) {
        self.content = content
    }

    private var choice: LivingOrbChoice {
        LivingOrbChoice.choose(
            flag: flag,
            level: MotionBudget.level(reduceMotion: reduceMotion, lowPowerMode: environment.lowPowerMode,
                                      thermalState: environment.thermalState,
                                      // Not `== .active`: the NFC sheet makes the scene inactive and must
                                      // not swap the orb mid-scan.
                                      sceneActive: LivingOrbChoice.sceneCountsAsActive(scenePhase)))
    }

    var body: some View { content(choice) }
}

/// `OrbView`'s signature. Draws the shader orb when the flag is on, the motion budget allows and the
/// shader is in the library, otherwise exactly the classic orb.
struct LivingOrb: View {
    var tone: OrbTone
    var ringTone: OrbTone? = nil
    var ring: Double = 0
    var size: CGFloat = 300
    /// A ripple when the orb appears in a new tone, which is how a lock or unlock shows on Home.
    /// The same tone appearing again (a tab return, the background, the keyboard) does not ripple.
    var ripplesOnAppear = false
    /// A soft glow of the state's color behind the glass orb. The classic orb never has it.
    var warmth = false
    /// The tone the orb just changed from, for a caller that knows the change itself (the lock moment,
    /// Time's up): on the orb's first appearance the warmth starts from it and, with `ripplesOnAppear`, the orb
    /// ripples, whatever the memory says. Otherwise the orb swings only if the glass orb last showed a different
    /// tone (`OrbToneMemory`).
    var changedFrom: OrbTone? = nil
    /// Seconds between ripples the glass orb sends by itself, as while a tag is awaited; nil for none.
    var rippleEvery: TimeInterval? = nil

    @State private var ripples = OrbRipples()
    /// The tone the shader is drawing, 0 slate to 1 ember. Animated in its own transaction (`Motion.tone`),
    /// so the caller's animation, such as the lock's seal spring, keeps its own timing for the ring.
    @State private var shownTone: Double?
    /// Decided as the glass orb appears; the warmth waits for it so it starts in the right color.
    @State private var entrance: OrbEntrance?
    /// `changedFrom` counts once: coming back from the background is not the change again.
    @State private var appeared = false
    /// Counts taps on the glass orb; each one bounces it.
    @State private var taps = 0
    private let motion = MotionSource.shared

    private var targetTone: Double { tone == .ember ? 1 : 0 }
    /// Only orbs that show a state change (ripple or warmth) read and write the shared memory.
    private var remembers: Bool { ripplesOnAppear || warmth }

    var body: some View {
        LivingGlassReader { choice in
            switch choice {
            case .classic:
                OrbView(tone: tone, ringTone: ringTone, ring: ring, size: size)
            case .glass:
                // The tilt is pulled by the orb's own timeline each frame, not observed here.
                GlassOrbView(tone: shownTone ?? targetTone, ringTone: ringTone, ring: ring, size: size,
                             tilt: { MotionSource.shared.tilt }, ripples: ripples)
                    .background {
                        if warmth, let entrance {
                            OrbWarmth(tone: tone, from: entrance.warmFrom, size: size)
                                .animation(Motion.tone, value: tone)
                        }
                    }
                    // Alongside any Button around the orb, so the locked orb still starts a scan.
                    .simultaneousGesture(TapGesture().onEnded {
                        taps += 1
                        ripples.add(at: Date.timeIntervalSinceReferenceDate)
                        HapticEngine.shared.play(.scrub)
                    })
                    .keyframeAnimator(initialValue: 1.0, trigger: taps) { view, scale in
                        view.scaleEffect(scale)
                    } keyframes: { _ in
                        CubicKeyframe(0.94, duration: 0.09)
                        SpringKeyframe(1.0, duration: 0.45, spring: .bouncy)
                    }
                    .task(id: rippleEvery) {
                        guard let rippleEvery else { return }
                        while !Task.isCancelled {
                            ripples.add(at: Date.timeIntervalSinceReferenceDate)
                            try? await Task.sleep(for: .seconds(rippleEvery))
                        }
                    }
                    .onAppear {
                        shownTone = targetTone
                        motion.acquire()
                        let known = appeared ? nil : changedFrom
                        appeared = true
                        let remembered = remembers ? OrbToneMemory.shared.swap(tone) : nil
                        let decided = OrbEntrance.decide(known: known, remembered: remembered, tone: tone)
                        entrance = decided
                        if ripplesOnAppear && decided.ripples { ripples.add(at: Date.timeIntervalSinceReferenceDate) }
                    }
                    .onDisappear {
                        motion.release()
                        entrance = nil
                        shownTone = nil
                    }
                    .onChange(of: tone) {
                        withAnimation(Motion.tone) { shownTone = targetTone }
                        ripples.add(at: Date.timeIntervalSinceReferenceDate)
                        if remembers { _ = OrbToneMemory.shared.swap(tone) }
                    }
            }
        }
    }
}
