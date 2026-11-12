import Foundation
import Testing
@testable import BellCore

private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
private func calendar(_ zone: String = "Europe/Berlin") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return calendar
}
private func settings(_ periods: [QuietPeriod] = []) -> AppSettings {
    var value = AppSettings()
    value.quietPeriods = periods
    return value
}

@Test func defaultsMatchBrief() {
    let value = AppSettings()
    #expect(value.intervalMinutes == 30)
    #expect(value.volume == 0.5)
    #expect(value.language == .english)
    #expect(value.quietPeriods.count == 1)
    #expect(value.quietPeriods[0].startMinute == 1260)
    #expect(value.quietPeriods[0].endMinute == 480)
    #expect(value.quietPeriods[0].weekdays == Set(1...7))
    #expect(value.isValid)
}

@Test func firstBellWaitsFullInterval() {
    let now = date("2026-11-12T09:12:00Z")
    let scheduler = BellScheduler(settings: settings(), now: now, calendar: calendar())
    #expect(scheduler.nextEvent == now.addingTimeInterval(1800))
}

@Test func ringsOnceThenStartsFreshInterval() {
    let now = date("2026-11-12T09:12:00Z")
    var scheduler = BellScheduler(settings: settings(), now: now, calendar: calendar())
    let early = scheduler.advance(now: now.addingTimeInterval(1799))
    let due = scheduler.advance(now: now.addingTimeInterval(1800))
    let duplicate = scheduler.advance(now: now.addingTimeInterval(1800))
    #expect(!early)
    #expect(due)
    #expect(!duplicate)
    #expect(scheduler.nextEvent == now.addingTimeInterval(3600))
}

@Test func lateCallbackSkipsMissedBell() {
    let now = date("2026-11-12T09:12:00Z")
    var scheduler = BellScheduler(settings: settings(), now: now, calendar: calendar())
    let ring = scheduler.advance(now: now.addingTimeInterval(3600))
    #expect(!ring)
    #expect(scheduler.nextEvent == now.addingTimeInterval(5400))
}

@Test func wakeRestartsIntervalWithoutImmediateRing() {
    let now = date("2026-11-12T09:12:00Z")
    var scheduler = BellScheduler(settings: settings(), now: now, calendar: calendar())
    scheduler.reset(now: now.addingTimeInterval(7200))
    #expect(scheduler.nextEvent == now.addingTimeInterval(9000))
}

@Test func quietHoursAreStartInclusiveEndExclusive() {
    let schedule = QuietSchedule(periods: [QuietPeriod()], calendar: calendar())
    #expect(!schedule.isQuiet(at: date("2026-11-12T19:59:59Z")))
    #expect(schedule.isQuiet(at: date("2026-11-12T20:00:00Z")))
    #expect(schedule.isQuiet(at: date("2026-11-13T06:59:59Z")))
    #expect(!schedule.isQuiet(at: date("2026-11-13T07:00:00Z")))
}

@Test func overnightRangeUsesStartingWeekday() {
    let monday = QuietPeriod(weekdays: [2])
    let schedule = QuietSchedule(periods: [monday], calendar: calendar())
    #expect(schedule.isQuiet(at: date("2026-11-09T21:00:00Z")))
    #expect(schedule.isQuiet(at: date("2026-11-10T06:00:00Z")))
    #expect(!schedule.isQuiet(at: date("2026-11-10T21:00:00Z")))
    #expect(!schedule.isQuiet(at: date("2026-11-09T06:00:00Z")))
}

@Test func overlapAndTouchingRangesDoNotResumeEarly() {
    let schedule = QuietSchedule(periods: [
        QuietPeriod(startMinute: 12 * 60, endMinute: 14 * 60),
        QuietPeriod(startMinute: 13 * 60, endMinute: 15 * 60),
        QuietPeriod(startMinute: 15 * 60, endMinute: 16 * 60)
    ], calendar: calendar())
    #expect(schedule.nextTransition(after: date("2026-11-12T12:00:00Z")) == date("2026-11-12T15:00:00Z"))
}

@Test func quietEntryCancelsPendingBellAndExitRestartsFullInterval() {
    let now = date("2026-11-12T19:45:00Z")
    var scheduler = BellScheduler(settings: AppSettings(), now: now, calendar: calendar())
    #expect(scheduler.nextEvent == date("2026-11-12T20:00:00Z"))
    let entry = scheduler.advance(now: date("2026-11-12T20:00:00Z"))
    #expect(!entry)
    #expect(scheduler.phase == .quiet(until: date("2026-11-13T07:00:00Z")))
    let exit = scheduler.advance(now: date("2026-11-13T07:00:00Z"))
    #expect(!exit)
    #expect(scheduler.phase == .waiting(nextBell: date("2026-11-13T07:30:00Z")))
}

@Test func quietStartWinsWhenBellIsDueAtSameInstant() {
    let now = date("2026-11-12T19:30:00Z")
    var scheduler = BellScheduler(settings: AppSettings(), now: now, calendar: calendar())
    let ring = scheduler.advance(now: date("2026-11-12T20:00:00Z"))
    #expect(!ring)
}

@Test func disabledRangesHaveNoEffect() {
    let schedule = QuietSchedule(periods: [QuietPeriod(isEnabled: false)], calendar: calendar())
    #expect(!schedule.isQuiet(at: date("2026-11-12T23:00:00Z")))
    #expect(schedule.nextTransition(after: date("2026-11-12T23:00:00Z")) == nil)
}

@Test func disabledAppHasNoTimer() {
    var value = AppSettings()
    value.isEnabled = false
    let scheduler = BellScheduler(settings: value, now: date("2026-11-12T09:00:00Z"))
    #expect(scheduler.phase == .disabled)
    #expect(scheduler.nextEvent == nil)
}

@Test func temporaryPauseResumesWithFullInterval() {
    let now = date("2026-11-12T09:00:00Z")
    var value = settings()
    value.pauseUntil = now.addingTimeInterval(3600)
    var scheduler = BellScheduler(settings: value, now: now, calendar: calendar())
    #expect(scheduler.phase == .paused(until: now.addingTimeInterval(3600)))
    let ring = scheduler.advance(now: now.addingTimeInterval(3600))
    #expect(!ring)
    #expect(scheduler.nextEvent == now.addingTimeInterval(5400))
}

@Test func pauseEndingDuringQuietHoursRemainsSilent() {
    var value = AppSettings()
    value.pauseUntil = date("2026-11-12T22:00:00Z")
    var scheduler = BellScheduler(settings: value, now: date("2026-11-12T19:00:00Z"), calendar: calendar())
    let ring = scheduler.advance(now: date("2026-11-12T22:00:00Z"))
    #expect(!ring)
    #expect(scheduler.phase == .quiet(until: date("2026-11-13T07:00:00Z")))
}

@Test func fullWeekCoverageDoesNotInventAnEnd() {
    let schedule = QuietSchedule(periods: [
        QuietPeriod(startMinute: 0, endMinute: 720),
        QuietPeriod(startMinute: 720, endMinute: 0)
    ], calendar: calendar())
    #expect(schedule.coversEntireWeek)
    #expect(schedule.isQuiet(at: date("2026-11-12T09:00:00Z")))
    #expect(schedule.nextTransition(after: date("2026-11-12T09:00:00Z")) == nil)
}

@Test func weeklyCoverageWrapsSaturdayIntoSunday() {
    let schedule = QuietSchedule(periods: [QuietPeriod(startMinute: 1260, endMinute: 480, weekdays: [7])], calendar: calendar())
    #expect(schedule.isQuiet(at: date("2026-11-15T05:00:00Z")))
    #expect(!schedule.coversEntireWeek)
}

@Test func springForwardUsesLocalMorningBoundary() {
    let schedule = QuietSchedule(periods: [QuietPeriod()], calendar: calendar())
    #expect(schedule.nextTransition(after: date("2026-03-28T21:00:00Z")) == date("2026-03-29T06:00:00Z"))
}

@Test func autumnFallbackUsesLocalMorningBoundary() {
    let schedule = QuietSchedule(periods: [QuietPeriod()], calendar: calendar())
    #expect(schedule.nextTransition(after: date("2026-10-24T20:00:00Z")) == date("2026-10-25T07:00:00Z"))
}

@Test func missingSpringTimeMovesToNextValidTime() {
    let schedule = QuietSchedule(periods: [QuietPeriod(startMinute: 90, endMinute: 150)], calendar: calendar())
    #expect(schedule.nextTransition(after: date("2026-03-29T00:45:00Z")) == date("2026-03-29T01:00:00Z"))
}

@Test func repeatedAutumnEndIncludesBothOccurrences() {
    let schedule = QuietSchedule(periods: [QuietPeriod(startMinute: 90, endMinute: 150)], calendar: calendar())
    #expect(schedule.isQuiet(at: date("2026-10-25T01:15:00Z")))
    #expect(schedule.nextTransition(after: date("2026-10-25T00:45:00Z")) == date("2026-10-25T01:30:00Z"))
}

@Test func timeZoneChangesKeepQuietHoursLocal() {
    let now = date("2026-11-12T20:30:00Z")
    #expect(QuietSchedule(periods: [QuietPeriod()], calendar: calendar("Europe/Berlin")).isQuiet(at: now))
    #expect(!QuietSchedule(periods: [QuietPeriod()], calendar: calendar("America/New_York")).isQuiet(at: now))
}

@Test func settingsRoundTripPreservesEditsAndLanguage() throws {
    var value = AppSettings()
    value.language = .german
    value.volume = 0.17
    value.intervalMinutes = 47
    value.quietPeriods.append(QuietPeriod(startMinute: 720, endMinute: 780, weekdays: [2, 3, 4, 5, 6]))
    let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(value))
    #expect(value == decoded)
    #expect(decoded.isValid)
}

@Test func invalidSettingsAreRejected() {
    var value = AppSettings()
    value.intervalMinutes = 0
    #expect(!value.isValid)
    value.intervalMinutes = 30
    value.volume = .nan
    #expect(!value.isValid)
    value.volume = 0.5
    value.quietPeriods = [QuietPeriod(startMinute: 480, endMinute: 480)]
    #expect(!value.isValid)
    value.quietPeriods = [QuietPeriod(weekdays: [])]
    #expect(!value.isValid)
    value.quietPeriods = [QuietPeriod(weekdays: [8])]
    #expect(!value.isValid)
}
