import Foundation
import SwiftUI
import Testing
@testable import Tapout

struct MotionBudgetTests {
    private func level(reduce: Bool = false, lowPower: Bool = false,
                       thermal: ProcessInfo.ThermalState = .nominal, active: Bool = true) -> MotionLevel {
        MotionBudget.level(reduceMotion: reduce, lowPowerMode: lowPower, thermalState: thermal, sceneActive: active)
    }

    @Test func fullWhenNothingObjects() {
        #expect(level() == .full)
        #expect(level(thermal: .fair) == .full)
    }

    @Test func reduceMotionStopsEverything() { #expect(level(reduce: true) == .still) }
    @Test func lowPowerModeStopsEverything() { #expect(level(lowPower: true) == .still) }
    @Test func aBackgroundedAppStops() { #expect(level(active: false) == .still) }
    @Test func seriousHeatStops() {
        #expect(level(thermal: .serious) == .still)
        #expect(level(thermal: .critical) == .still)
    }

    @Test func framesAreCappedAtThirtyPerSecond() {
        #expect(MotionBudget.frameInterval == 1.0 / 30.0)
    }
}

struct MotionTokensTests {
    @Test func reduceMotionSwapsInTheCrossfade() {
        #expect(Motion.resolved(Motion.bloom, reduceMotion: true) == .easeInOut(duration: 0.25))
        #expect(Motion.resolved(Motion.bloom, reduceMotion: false) == Motion.bloom)
    }
}
