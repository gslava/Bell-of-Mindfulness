import Foundation

/// Computes civil-time boundaries on demand. No minute-by-minute polling or fixed 24-hour days.
public struct QuietSchedule: Sendable {
    public let periods: [QuietPeriod]
    public var calendar: Calendar

    public init(periods: [QuietPeriod], calendar: Calendar = .autoupdatingCurrent) {
        self.periods = periods.filter { $0.isEnabled && $0.isValid }
        self.calendar = calendar
    }

    public var coversEntireWeek: Bool {
        let week = 7 * 1440
        var segments: [Range<Int>] = []
        for period in periods {
            for day in period.weekdays {
                let start = (day - 1) * 1440 + period.startMinute
                let end = (day - 1) * 1440 + period.endMinute
                    + (period.endMinute < period.startMinute ? 1440 : 0)
                segments.append(start..<min(end, week))
                if end > week { segments.append(0..<(end - week)) }
            }
        }
        var covered = 0
        for segment in segments.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if segment.lowerBound > covered { return false }
            covered = max(covered, segment.upperBound)
        }
        return covered >= week
    }

    public func isQuiet(at date: Date) -> Bool {
        if coversEntireWeek { return true }
        return intervals(around: date).contains { $0.start <= date && date < $0.end }
    }

    /// The next actual change in the union of all periods; overlaps and touching periods are merged.
    public func nextTransition(after date: Date) -> Date? {
        guard !coversEntireWeek else { return nil }
        for interval in intervals(around: date) {
            if interval.start > date { return interval.start }
            if interval.end > date { return interval.end }
        }
        return nil
    }

    private func intervals(around date: Date) -> [DateInterval] {
        let today = calendar.startOfDay(for: date)
        var result: [DateInterval] = []
        // One previous day captures overnight periods. Two future weeks cover merged weekly runs.
        for offset in -1...15 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            for period in periods where period.weekdays.contains(weekday) {
                guard let start = time(period.startMinute, on: day, repeated: .first),
                      let endDay = calendar.date(byAdding: .day,
                          value: period.endMinute < period.startMinute ? 1 : 0, to: day),
                      let end = time(period.endMinute, on: endDay, repeated: .last), end > start else { continue }
                result.append(DateInterval(start: start, end: end))
            }
        }
        var merged: [DateInterval] = []
        for interval in result.sorted(by: { $0.start < $1.start }) {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    private func time(_ minute: Int, on day: Date, repeated: Calendar.RepeatedTimePolicy) -> Date? {
        // Missing spring-forward times move forward; repeated autumn ends include both occurrences.
        calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day,
                      matchingPolicy: .nextTime, repeatedTimePolicy: repeated, direction: .forward)
    }
}
