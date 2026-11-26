import Foundation
import SwiftUI
import Testing
@testable import Tapout

struct LivingGlassMirrorTests {
    private func scratch(_ name: String = #function) -> UserDefaults {
        let suite = "tapout.mirror.\(name)"
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    @Test func itIsOffUntilTheAppSaysOtherwise() {
        #expect(!LivingGlassMirror.isOn(scratch()))
        #expect(!LivingGlassMirror.isOn(nil))
    }

    @Test func itRemembersTheSwitch() {
        let defaults = scratch()
        LivingGlassMirror.set(true, in: defaults)
        #expect(LivingGlassMirror.isOn(defaults)) // tests are a Debug build; Release always reads false
        LivingGlassMirror.set(false, in: defaults)
        #expect(!LivingGlassMirror.isOn(defaults))
    }

    @Test func itReportsOnlyRealChanges() {
        let defaults = scratch()
        #expect(!LivingGlassMirror.set(false, in: defaults))
        #expect(LivingGlassMirror.set(true, in: defaults))
        #expect(!LivingGlassMirror.set(true, in: defaults))
    }

    @Test func itUsesTheAppsSharedGroup() {
        #expect(LivingGlassMirror.appGroupID == SharedStore.appGroupID)
    }
}

struct FlatPosterTests {
    private let now = Date.now

    @Test func aLockIsEmberAndNamesTheMode() {
        let poster = FlatPoster.home(.sample(.locked(countingFrom: now - 60)), date: now)
        #expect(poster == FlatPoster(tone: .ember, heading: "Locked", footer: "Deep work"))
    }

    @Test func aTimerLockSaysTimeLeft() {
        let poster = FlatPoster.home(.sample(.locked(countingFrom: now - 60), timerEndsAt: now + 600), date: now)
        #expect(poster == FlatPoster(tone: .ember, heading: "Time left", footer: "Deep work"))
    }

    @Test func aPassIsSlateWhileAppsAreOpen() {
        let snapshot = LockSnapshot.sample(.open(relockAt: now + 200, resumesFrom: now - 60))
        #expect(FlatPoster.home(snapshot, date: now) == FlatPoster(tone: .slate, heading: "Relocks in", footer: "Open"))
        // Once the relock time comes the face reads as the lock again.
        #expect(FlatPoster.home(snapshot, date: now + 201).tone == .ember)
    }

    @Test func unlockedIsSlateWithToday() {
        let poster = FlatPoster.home(.sample(.unlocked), date: now)
        #expect(poster == FlatPoster(tone: .slate, heading: "Today", footer: "phone-free"))
    }

    @Test func totalsStackHoursOverMinutes() {
        #expect(FlatPoster.stacked(6300) == ["1h", "45m"])
        #expect(FlatPoster.stacked(18_000) == ["5h"])
        #expect(FlatPoster.stacked(0) == ["0m"])
    }
}

struct FlatInkTests {
    @Test func textOnTheFieldIsNearBlack() {
        #expect(OrbTone.ember.flatInk(hasBackground: true, fullColor: true) == .onEmber)
        #expect(OrbTone.slate.flatInk(hasBackground: true, fullColor: true) == .onSlate)
    }

    @Test func withoutTheFieldTextTakesTheStateColor() {
        #expect(OrbTone.ember.flatInk(hasBackground: false, fullColor: true) == .ember)
    }

    @Test func aTintedHomeScreenUsesTheSystemColor() {
        #expect(OrbTone.ember.flatInk(hasBackground: false, fullColor: false) == .primary)
        #expect(OrbTone.slate.flatInk(hasBackground: true, fullColor: false) == .primary)
    }
}

struct FlatActivityTests {
    private let locked = LockActivityAttributes.ContentState.sample()

    @Test func aLockedCardNamesModeAndPlace() {
        let poster = FlatPoster.activity(locked, isStale: false)
        #expect(poster == FlatPoster(tone: .ember, heading: "Deep work · Locked", footer: "Kitchen"))
    }

    @Test func aTimerCardSaysTimeLeft() {
        let state = LockActivityAttributes.ContentState.sampleTimer(length: 2700, left: 1860)
        #expect(FlatPoster.activity(state, isStale: false).heading == "Deep work · Time left")
    }

    @Test func aPassCardIsSlate() {
        let poster = FlatPoster.activity(.sample(open: true), isStale: false)
        #expect(poster.tone == .slate)
        #expect(poster.heading == "Open · Relocks in")
    }

    @Test func aStalePassReadsLockedAgain() {
        #expect(FlatPoster.activity(.sample(open: true), isStale: true).tone == .ember)
    }

    @Test func aFinishedTimerIsSlateAndSaysSo() {
        let poster = FlatPoster.activity(.sampleTimerDone(), isStale: true)
        #expect(poster == FlatPoster(tone: .slate, heading: "Time's up", footer: "Deep work"))
    }

    @Test func theContentStateCarriesTheLookOnlyWhenOn() {
        let snapshot = LockSnapshot.sample(.locked(countingFrom: .now - 60))
        #expect(LiveActivityPlan.content(for: snapshot)?.flat == nil)
        #expect(LiveActivityPlan.content(for: snapshot, flat: true)?.flat == true)
    }

    @Test func flippingTheSwitchUpdatesARunningActivity() throws {
        let snapshot = LockSnapshot.sample(.locked(countingFrom: .now - 60))
        let current = try #require(LiveActivityPlan.content(for: snapshot))
        let wanted = try #require(LiveActivityPlan.content(for: snapshot, flat: true))
        #expect(LiveActivityPlan.decide(snapshot: snapshot, enabled: true, current: current, flat: true) == .update(wanted))
    }

    @Test func anOlderActivityStillDecodes() throws {
        let old = #"{"lockedFrom":0,"modeName":"Deep work"}"#
        let state = try JSONDecoder().decode(LockActivityAttributes.ContentState.self, from: Data(old.utf8))
        #expect(state.flat == nil)
    }
}

struct SealedArtChoiceTests {
    @Test func theShieldPicksTheGlassOrbWithTheSwitch() {
        #expect(LivingGlassMirror.shieldImageName(glass: false) == "SealedOrb")
        #expect(LivingGlassMirror.shieldImageName(glass: true) == "SealedOrbGlass")
    }
}
