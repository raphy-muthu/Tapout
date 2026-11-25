import Testing
@testable import Tapout

struct DialMathTests {
    @Test func anglesRunClockwiseFromTwelve() {
        #expect(DialMath.angle(dx: 0, dy: -10) == 0)
        #expect(abs(DialMath.angle(dx: 10, dy: 0) - 90) < 0.0001)
        #expect(abs(DialMath.angle(dx: 0, dy: 10) - 180) < 0.0001)
        #expect(abs(DialMath.angle(dx: -10, dy: 0) - 270) < 0.0001)
    }

    @Test func deltaTakesTheShortWayAcrossTwelve() {
        #expect(abs(DialMath.delta(from: 350, to: 10) - 20) < 0.0001)
        #expect(abs(DialMath.delta(from: 10, to: 350) + 20) < 0.0001)
        #expect(abs(DialMath.delta(from: 90, to: 120) - 30) < 0.0001)
    }

    /// Exactly half a turn is ambiguous; it resolves to -180, still inside -180..<180.
    @Test func halfATurnIsMinusOneEighty() {
        #expect(DialMath.delta(from: 0, to: 180) == -180)
        #expect(DialMath.delta(from: 180, to: 0) == -180)
        #expect(DialMath.delta(from: 90, to: 270) == -180)
    }

    @Test func draggingPastTwelveStartsTheSecondLap() {
        // 55 min, then a drag from 330° to 30° (60° clockwise = 10 min).
        #expect(abs(DialMath.dragged(minutes: 55, from: 330, to: 30) - 65) < 0.0001)
    }

    @Test func draggingBackPastTwelveReturnsToTheFirstLap() {
        #expect(abs(DialMath.dragged(minutes: 65, from: 30, to: 330) - 55) < 0.0001)
    }

    @Test func theDialStopsAtFiveMinutesAndTwoHours() {
        #expect(DialMath.dragged(minutes: 118, from: 0, to: 90) == 120)
        #expect(DialMath.dragged(minutes: 7, from: 90, to: 0) == 5)
    }

    @Test func valuesSnapToFiveMinutes() {
        #expect(DialMath.snapped(62.4) == 60)
        #expect(DialMath.snapped(63) == 65)
        #expect(DialMath.snapped(2) == 5)
        #expect(DialMath.snapped(200) == 120)
    }

    /// The rounding rule the dead band is built on: a value exactly between two steps goes up.
    @Test func aHalfStepRoundsUp() {
        #expect(DialMath.snapped(62.5) == 65)
        #expect(DialMath.snapped(57.5) == 60)
    }

    /// A finger resting on the boundary between two steps must not flip between them.
    @Test func theValueHoldsInsideTheDeadBand() {
        // Holding 60: just past the 62.5 boundary is not enough.
        #expect(DialMath.snapped(62.6, holding: 60) == 60)
        #expect(DialMath.snapped(63.2, holding: 60) == 60)
        #expect(DialMath.snapped(63.3, holding: 60) == 65)
        // Holding 65: back past the boundary is not enough either.
        #expect(DialMath.snapped(62.4, holding: 65) == 65)
        #expect(DialMath.snapped(61.8, holding: 65) == 65)
        #expect(DialMath.snapped(61.7, holding: 65) == 60)
    }

    @Test func aFastDragStillSnapsStraightThrough() {
        #expect(DialMath.snapped(81, holding: 60) == 80)
        #expect(DialMath.snapped(5, holding: 30) == 5)
        #expect(DialMath.snapped(120, holding: 115) == 120)
    }

    @Test func ticksFillTheOuterRingThenTheInner() {
        #expect(DialMath.litTicks(minutes: 45) == DialMath.Ticks(outer: 45, inner: 0))
        #expect(DialMath.litTicks(minutes: 85) == DialMath.Ticks(outer: 60, inner: 25))
        #expect(DialMath.litTicks(minutes: 120) == DialMath.Ticks(outer: 60, inner: 60))
    }

    @Test func theHandleSitsOnTheRingOfItsLap() {
        #expect(DialMath.handle(minutes: 45) == DialMath.Handle(angle: 270, lap: 0))
        #expect(DialMath.handle(minutes: 60) == DialMath.Handle(angle: 360, lap: 0))
        #expect(DialMath.handle(minutes: 75) == DialMath.Handle(angle: 90, lap: 1))
        #expect(DialMath.handle(minutes: 120) == DialMath.Handle(angle: 360, lap: 1))
    }
}

struct TimerSheetDialTests {
    @Test func theDialShowsWithTheSwitchOn() {
        #expect(TimerSheet.showsDial(livingGlass: true, accessibilitySize: false, voiceOver: false, longer: false))
    }

    /// The dial is an input, not a motion effect: only these four inputs decide it.
    @Test func eachOfTheseBringsBackTheWheel() {
        #expect(!TimerSheet.showsDial(livingGlass: false, accessibilitySize: false, voiceOver: false, longer: false))
        #expect(!TimerSheet.showsDial(livingGlass: true, accessibilitySize: true, voiceOver: false, longer: false))
        #expect(!TimerSheet.showsDial(livingGlass: true, accessibilitySize: false, voiceOver: true, longer: false))
        #expect(!TimerSheet.showsDial(livingGlass: true, accessibilitySize: false, voiceOver: false, longer: true))
    }

    /// Entering dial mode from the wheel puts the value on the dial's 5-minute grid, within 5 min to 2 h.
    @Test func enteringTheDialSnapsTheValue() {
        #expect(TimerSheet.dialDuration(67 * 60) == 65 * 60)
        #expect(TimerSheet.dialDuration(45 * 60) == 45 * 60)
        #expect(TimerSheet.dialDuration(3 * 3600) == 2 * 3600)
        #expect(TimerSheet.dialDuration(2 * 60) == 5 * 60)
    }
}
