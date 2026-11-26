import SwiftUI
import Testing
@testable import Tapout

/// The size a view draws at, in points, at a text size.
@MainActor private func drawnSize(_ view: some View, at size: DynamicTypeSize) throws -> CGSize {
    let renderer = ImageRenderer(content: view.environment(\.dynamicTypeSize, size))
    renderer.scale = 1
    return try #require(renderer.uiImage).size
}

@MainActor
struct LargeTextTests {
    @Test func tileNumbersGrowWithTheTextSize() throws {
        let number = Text("10:30–7").font(.numberTile).fixedSize()
        let normal = try drawnSize(number, at: .large)
        let large = try drawnSize(number, at: .accessibility3)
        #expect(large.width > normal.width * 1.3)
    }

    @Test func tileNumbersAreUnchangedAtTheDefaultSize() throws {
        let scaled = try drawnSize(Text("10:30–7").font(.numberTile).fixedSize(), at: .large)
        let fixed = try drawnSize(
            Text("10:30–7").font(.custom(FrauncesFace.number.resolved().rawValue, fixedSize: 20)).fixedSize(), at: .large)
        #expect(scaled == fixed)
    }

    @Test func aPrimaryButtonKeepsRoomAroundALargeLabel() throws {
        let label = try drawnSize(Text("Get started").font(.tHeadline).fixedSize(), at: .accessibility5)
        let button = try drawnSize(PrimaryButton(title: "Get started") {}.frame(width: 600), at: .accessibility5)
        #expect(button.height >= label.height + Space.xs * 2)
    }

    @Test func aPrimaryButtonIsUnchangedAtTheDefaultSize() throws {
        let button = try drawnSize(PrimaryButton(title: "Get started") {}.frame(width: 340), at: .large)
        #expect(button.height == 56)
    }
}

@MainActor
struct LargeTextChipTests {
    @Test func aChipKeepsRoomAroundALargeLabel() throws {
        let label = try drawnSize(Text("Problem set").font(.tSubhead.weight(.medium)).fixedSize(), at: .accessibility5)
        let chip = try drawnSize(ChoiceChip(title: "Problem set", isOn: false) {}, at: .accessibility5)
        #expect(chip.height >= label.height + Space.xxs * 2)
    }

    @Test func aChipIsUnchangedAtTheDefaultSize() throws {
        let chip = try drawnSize(ChoiceChip(title: "Problem set", isOn: false) {}, at: .large)
        #expect(chip.height == 44)
    }
}

struct ReduceMotionTests {
    @Test func somethingThatTravelsHappensAtOnceWithReduceMotion() {
        #expect(Motion.travel(Motion.ui, reduceMotion: true) == nil)
        #expect(Motion.travel(Motion.ui, reduceMotion: false) == Motion.ui)
    }
}

#if DEBUG
/// A reading `minute` minutes into a run.
private func reading(_ minute: Double, battery: Double? = 0.8, charging: Bool = false, heat: PowerHeat = .nominal,
                     lowPower: Bool = false, glass: Bool = true) -> PowerSample {
    PowerSample(date: Date(timeIntervalSinceReferenceDate: minute * 60), battery: battery, charging: charging,
                heat: heat, lowPower: lowPower, glass: glass)
}

/// A reading a minute for an hour: 80%, down to 75% at minute 10, 70% at minute 40.
private let steadyHour = (0...60).map { reading(Double($0), battery: $0 < 10 ? 0.80 : $0 < 40 ? 0.75 : 0.70) }

struct PowerRunTests {
    @Test func drainIsMeasuredBetweenBatterySteps() throws {
        let drain = try #require(PowerRun(label: "Home", samples: steadyHour).drainPerHour)
        #expect(abs(drain - 0.10) < 0.0001) // 5% in the 30 minutes between the steps
    }

    @Test func oneStepIsTooShortToTell() {
        let run = PowerRun(label: "Home", samples: Array(steadyHour.prefix(30)))
        #expect(run.drainPerHour == nil)
        #expect(run.report.contains("too short to tell"))
    }

    @Test func chargingSpoilsTheRun() {
        var samples = steadyHour
        samples[5].charging = true
        let run = PowerRun(label: "Home", samples: samples)
        #expect(run.drainPerHour == nil)
        #expect(run.problems == ["Charging during the run."])
    }

    @Test func timeAwayIsCountedAndReported() {
        let run = PowerRun(label: "Home", samples: [reading(0), reading(1), reading(11), reading(12)])
        #expect(run.timeAway == 9 * 60)
        #expect(run.problems == ["Away from Tapout for 9 min."])
    }

    @Test func aSmallDelayIsNotTimeAway() {
        let run = PowerRun(label: "Home", samples: [reading(0), reading(1.2), reading(2.3)])
        #expect(run.timeAway == 0)
    }

    @Test func lowPowerAndASwitchChangeAreProblems() {
        let run = PowerRun(label: "Home", samples: [reading(0, lowPower: true), reading(1, glass: false)])
        #expect(run.problems == ["Low Power Mode was on.", "The switch changed during the run."])
    }

    @Test func aMissingBatteryLevelIsSaid() {
        let run = PowerRun(label: "Home", samples: [reading(0, battery: nil), reading(1, battery: nil)])
        #expect(run.problems == ["iOS gave no battery level."])
    }

    @Test func theReportReadsAtAGlance() {
        var samples = steadyHour
        samples[50].heat = .fair
        let report = PowerRun(label: "Home, an hour", samples: samples).report
        #expect(report == """
        Home, an hour · switch on
        60 min · battery 80% → 70%
        Drain: 10.0% an hour
        Heat: worst fair
        """)
    }
}

@MainActor
struct PowerMeterTests {
    private final class Awake { var values: [Bool] = [] }

    private func scratch(_ name: String = #function) -> UserDefaults {
        let suite = "tapout.power.\(name)"
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    @Test func aRunReadsAtStartAndStopAndKeepsTheDisplayAwake() throws {
        let awake = Awake()
        let meter = PowerMeter(defaults: scratch(), read: { reading(0) }, keepAwake: { awake.values.append($0) })
        meter.start(label: "  Home  ")
        #expect(meter.current?.samples.count == 1)
        meter.stop()
        #expect(meter.current == nil)
        #expect(meter.runs.first?.label == "Home")
        #expect(meter.runs.first?.samples.count == 2)
        #expect(awake.values == [true, false])
    }

    @Test func runsSurviveARelaunchEvenUnfinished() {
        let defaults = scratch()
        let meter = PowerMeter(defaults: defaults, read: { reading(0) }, keepAwake: { _ in })
        meter.start(label: "Home")
        let relaunched = PowerMeter(defaults: defaults, read: { reading(0) }, keepAwake: { _ in })
        #expect(relaunched.runs.map(\.label) == ["Home"])
        #expect(relaunched.current == nil)
        meter.stop()
    }

    @Test func onlyTheLatestRunsAreKept() {
        let meter = PowerMeter(defaults: scratch(), read: { reading(0) }, keepAwake: { _ in })
        for index in 1...12 {
            meter.start(label: "\(index)")
            meter.stop()
        }
        #expect(meter.runs.count == PowerMeter.kept)
        #expect(meter.runs.first?.label == "12")
    }
}
#endif

@MainActor
struct MoreLargeTextTests {
    private func widths(_ font: Font) throws -> (normal: CGFloat, large: CGFloat) {
        let text = Text("12:00 PM").font(font).fixedSize()
        return (try drawnSize(text, at: .large).width, try drawnSize(text, at: .accessibility3).width)
    }

    @Test func smallNumbersGrowWithTheTextSize() throws {
        let width = try widths(.numberSmall)
        #expect(width.large > width.normal * 1.3)
    }

    @Test func tileValuesGrowWithTheTextSize() throws {
        let width = try widths(.numberMedium)
        #expect(width.large > width.normal * 1.2)
    }

    @Test func theTimerReadoutGrowsWithTheTextSize() throws {
        let width = try widths(.numberReadout)
        #expect(width.large > width.normal * 1.1)
    }

    @Test func nothingChangesAtTheDefaultSize() throws {
        let sample = Text("12:00 PM")
        let pairs: [(Font, Font)] = [
            (.numberSmall, .system(size: 17, weight: .medium).monospacedDigit()),
            (.numberMedium, .custom(FrauncesFace.number.resolved().rawValue, fixedSize: 28)),
            (.numberReadout, .custom(FrauncesFace.display.resolved().rawValue, fixedSize: 48)),
        ]
        for (scaling, fixed) in pairs {
            #expect(try drawnSize(sample.font(scaling).fixedSize(), at: .large)
                    == drawnSize(sample.font(fixed).fixedSize(), at: .large))
        }
    }

    /// A widget's frame can't grow, so its numbers keep their size.
    @Test func widgetNumbersStayTheSameSize() throws {
        for font in [Font.widgetValue, .widgetTotal] {
            let width = try widths(font)
            #expect(width.large == width.normal)
        }
    }
}

/// The week chart's value labels may be wider than their columns, but must never widen the chart.
@MainActor
struct WeekChartLargeTextTests {
    @Test func theChartKeepsToItsWidthAtTheLargestSize() throws {
        let renderer = ImageRenderer(content: WeekBars(days: LockSnapshot.sample(.unlocked).days)
            .environment(\.dynamicTypeSize, .accessibility5))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 327, height: nil) // the narrowest iPhone's page
        let width = try #require(renderer.uiImage).size.width
        #expect(width <= 328, "drawn \(width)") // a point of rounding across seven columns
    }
}
