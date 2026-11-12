import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case english = "en"
    case german = "de"

    public var locale: Locale { Locale(identifier: self == .english ? "en_GB" : "de_DE") }
}

public struct QuietPeriod: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var isEnabled: Bool
    public var startMinute: Int
    public var endMinute: Int
    /// Calendar weekday numbers (Sunday = 1). Overnight periods belong to their starting day.
    public var weekdays: Set<Int>

    public init(id: UUID = UUID(), isEnabled: Bool = true, startMinute: Int = 21 * 60,
                endMinute: Int = 8 * 60, weekdays: Set<Int> = Set(1...7)) {
        self.id = id
        self.isEnabled = isEnabled
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.weekdays = weekdays
    }

    public var isValid: Bool {
        (0..<1440).contains(startMinute) && (0..<1440).contains(endMinute)
            && startMinute != endMinute && !weekdays.isEmpty && weekdays.isSubset(of: Set(1...7))
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var intervalMinutes: Int = 30
    public var volume: Double = 0.5
    public var isEnabled: Bool = true
    public var pauseUntil: Date?
    public var language: AppLanguage = .english
    public var quietPeriods: [QuietPeriod] = [QuietPeriod()]

    public init() {}

    public var isValid: Bool {
        (1...1440).contains(intervalMinutes) && volume.isFinite && (0...1).contains(volume)
            && quietPeriods.allSatisfy(\.isValid)
            && Set(quietPeriods.map(\.id)).count == quietPeriods.count
            && (pauseUntil == nil || pauseUntil!.timeIntervalSince1970.isFinite)
    }
}
