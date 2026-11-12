import Foundation

public enum BellPhase: Equatable, Sendable {
    case disabled
    case paused(until: Date)
    case quiet(until: Date?)
    case waiting(nextBell: Date)
}

/// A deterministic state machine. The app owns one non-repeating timer for `nextEvent`.
public struct BellScheduler: Sendable {
    public private(set) var phase: BellPhase = .disabled
    public private(set) var nextEvent: Date?
    private var settings: AppSettings
    private var schedule: QuietSchedule

    public init(settings: AppSettings, now: Date, calendar: Calendar = .autoupdatingCurrent) {
        self.settings = settings
        self.schedule = QuietSchedule(periods: settings.quietPeriods, calendar: calendar)
        reset(now: now)
    }

    public mutating func reset(now: Date) {
        if !settings.isEnabled {
            phase = .disabled
        } else if let until = settings.pauseUntil, until > now {
            phase = .paused(until: until)
        } else if schedule.isQuiet(at: now) {
            phase = .quiet(until: schedule.nextTransition(after: now))
        } else {
            phase = .waiting(nextBell: now.addingTimeInterval(Double(settings.intervalMinutes) * 60))
        }
        updateEvent(now: now)
    }

    /// Delayed events are discarded rather than replayed after sleep, a clock jump or a busy run loop.
    @discardableResult public mutating func advance(now: Date) -> Bool {
        if !settings.isEnabled || (settings.pauseUntil.map { $0 > now } ?? false) || schedule.isQuiet(at: now) {
            reset(now: now)
            return false
        }
        if case let .waiting(nextBell) = phase {
            if now < nextBell {
                updateEvent(now: now)
                return false
            }
            let shouldRing = now.timeIntervalSince(nextBell) <= 5
            reset(now: now)
            return shouldRing
        }
        reset(now: now)
        return false
    }

    private mutating func updateEvent(now: Date) {
        switch phase {
        case .disabled: nextEvent = nil
        case .paused(let until): nextEvent = until
        case .quiet(let until): nextEvent = until
        case .waiting(let bell): nextEvent = min(bell, schedule.nextTransition(after: now) ?? bell)
        }
    }
}
