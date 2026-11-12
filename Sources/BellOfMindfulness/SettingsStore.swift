import BellCore
import Foundation

@MainActor
final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "bell.settings.v1"
    private(set) var recovered = false

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> AppSettings {
        guard let data = defaults.data(forKey: key) else { return AppSettings() }
        if let settings = try? JSONDecoder().decode(AppSettings.self, from: data), settings.isValid {
            return settings
        }
        // Keep the original bytes recoverable instead of silently overwriting invalid data.
        defaults.set(data, forKey: "\(key).recovery.\(Int(Date().timeIntervalSince1970))")
        defaults.removeObject(forKey: key)
        recovered = true
        return AppSettings()
    }

    func save(_ settings: AppSettings) throws {
        guard settings.isValid else { throw CocoaError(.coderInvalidValue) }
        defaults.set(try JSONEncoder().encode(settings), forKey: key)
    }
}
