import AppKit
import BellCore
import Combine
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var phase: BellPhase
    @Published private(set) var isPlaying = false
    @Published var message: Copy?
    @Published private(set) var messageDetail: String?
    @Published private(set) var loginStatus: SMAppService.Status = .notRegistered

    private let store: SettingsStore
    private let audio = BellAudio()
    private var scheduler: BellScheduler
    private var timer: Timer?
    private var saveWork: DispatchWorkItem?
    private var isSleeping = false
    private var isSessionInactive = false
    private var schedulingActivity: (any NSObjectProtocol)?
    private let runtimeEnabled: Bool

    init(store: SettingsStore = SettingsStore(), runtimeEnabled: Bool = true) {
        self.store = store
        self.runtimeEnabled = runtimeEnabled
        let loaded = store.load()
        settings = loaded
        scheduler = BellScheduler(settings: loaded, now: Date())
        phase = scheduler.phase
        if store.recovered { message = .settingsRecovered }
        audio.onChange = { [weak self] in self?.isPlaying = $0 }
        audio.onFailure = { [weak self] error in self?.report(.soundFailed, detail: error.localizedDescription) }
        if runtimeEnabled {
            observeSystemEvents()
            refreshLoginStatus()
            armTimer()
        }
    }

    func text(_ key: Copy) -> String { key.text(settings.language) }
    var locale: Locale { settings.language.locale }

    var statusTitle: String {
        switch phase {
        case .disabled: text(.off)
        case .paused: text(.paused)
        case .quiet: text(.quiet)
        case .waiting: text(.active)
        }
    }

    var statusSymbol: String {
        switch phase {
        case .waiting: "bell"
        case .quiet: "moon"
        case .paused, .disabled: "bell.slash"
        }
    }

    var nextLabel: String {
        switch phase {
        case .waiting: text(.nextBell)
        case .quiet(let until): until == nil ? text(.quietAllWeek) : text(.quietUntil)
        case .paused: text(.pausedUntil)
        case .disabled: text(.switchedOff)
        }
    }

    var phaseDate: Date? {
        switch phase {
        case .waiting(let date), .paused(let date): date
        case .quiet(let date): date
        case .disabled: nil
        }
    }

    func dateText(_ date: Date) -> String {
        if case .waiting = phase, Calendar.autoupdatingCurrent.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute().locale(locale))
        }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute().locale(locale))
    }

    func timeText(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }

    func daysText(_ days: Set<Int>) -> String {
        if days == Set(1...7) { return text(.everyDay) }
        if days == Set(2...6) { return text(.weekdays) }
        if days == Set([1, 7]) { return text(.weekend) }
        return [2, 3, 4, 5, 6, 7, 1].filter { days.contains($0) }.map { weekdayText($0) }.joined(separator: ", ")
    }

    func weekdayText(_ day: Int, full: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        return (full ? formatter.weekdaySymbols : formatter.shortWeekdaySymbols)[day - 1]
    }

    func update(_ edit: (inout AppSettings) -> Void) {
        let old = settings
        var value = settings
        edit(&value)
        guard value.isValid, value != old else { return }
        settings = value
        audio.setVolume(value.volume)
        // Volume and language edits must not delay the next bell.
        if old.intervalMinutes != value.intervalMinutes || old.quietPeriods != value.quietPeriods
            || old.isEnabled != value.isEnabled || old.pauseUntil != value.pauseUntil {
            restart()
        }
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flushSettings() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func setEnabled(_ enabled: Bool) {
        update { $0.isEnabled = enabled; $0.pauseUntil = nil }
        if !enabled { audio.stop() }
    }

    func pause(minutes: Int) {
        update { $0.pauseUntil = Date().addingTimeInterval(Double(minutes) * 60) }
        audio.stop()
    }

    func resume() {
        update { $0.pauseUntil = nil; $0.isEnabled = true }
    }

    func restart() {
        scheduler = BellScheduler(settings: settings, now: Date())
        phase = scheduler.phase
        if case .quiet = phase { audio.stop() }
        if case .disabled = phase { audio.stop() }
        if case .paused = phase { audio.stop() }
        armTimer()
    }

    func preview() {
        if audio.isPlaying { audio.stop(); return }
        play()
    }

    private func play() {
        guard !isSleeping, !isSessionInactive else { return }
        do { try audio.play(volume: settings.volume) }
        catch { report(.soundFailed, detail: error.localizedDescription) }
    }

    func savePeriod(_ period: QuietPeriod) {
        update { settings in
            if let index = settings.quietPeriods.firstIndex(where: { $0.id == period.id }) {
                settings.quietPeriods[index] = period
            } else { settings.quietPeriods.append(period) }
        }
    }

    func removePeriod(_ id: UUID) { update { $0.quietPeriods.removeAll { $0.id == id } } }

    func flushSettings() {
        saveWork?.cancel()
        saveWork = nil
        do { try store.save(settings) }
        catch { report(.settingsSaveFailed, detail: error.localizedDescription) }
    }

    func shutdown() {
        timer?.invalidate()
        timer = nil
        endSchedulingActivity()
        audio.stop()
        flushSettings()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func armTimer() {
        timer?.invalidate()
        timer = nil
        // Keep App Nap from throttling the requested timer; this option still allows Mac sleep.
        if runtimeEnabled, !isSleeping, !isSessionInactive, case .waiting = phase {
            if schedulingActivity == nil {
                schedulingActivity = ProcessInfo.processInfo.beginActivity(
                    options: .userInitiatedAllowingIdleSystemSleep,
                    reason: "Deliver scheduled mindfulness bells")
            }
        } else { endSchedulingActivity() }
        guard runtimeEnabled, !isSleeping, !isSessionInactive, let date = scheduler.nextEvent else { return }
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.timerFired() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func timerFired() {
        guard !isSleeping, !isSessionInactive else { return }
        let shouldPlay = scheduler.advance(now: Date())
        phase = scheduler.phase
        if case .quiet = phase { audio.stop() }
        if shouldPlay && !audio.isPlaying && settings.volume > 0 { play() }
        armTimer()
    }

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(sessionResigned), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspace.addObserver(self, selector: #selector(sessionBecameActive), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(clockChanged), name: .NSSystemTimeZoneDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(clockChanged), name: NSNotification.Name.NSSystemClockDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dayChanged), name: .NSCalendarDayChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshLoginStatus), name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func willSleep() {
        isSleeping = true
        suspend()
    }

    private func suspend() {
        timer?.invalidate()
        timer = nil
        endSchedulingActivity()
        audio.stop()
    }

    private func endSchedulingActivity() {
        if let activity = schedulingActivity {
            ProcessInfo.processInfo.endActivity(activity)
            schedulingActivity = nil
        }
    }

    @objc private func didWake() { isSleeping = false; if !isSessionInactive { restart() } }
    @objc private func sessionResigned() { isSessionInactive = true; suspend() }
    @objc private func sessionBecameActive() { isSessionInactive = false; if !isSleeping { restart() } }
    @objc private func clockChanged() { restart() }
    // Calendar notifications can arrive on a background queue at midnight.
    @objc nonisolated private func dayChanged() {
        Task { @MainActor [weak self] in self?.objectWillChange.send() }
    }

    @objc func refreshLoginStatus() { loginStatus = SMAppService.mainApp.status }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard runtimeEnabled else { return }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { report(.loginFailed, detail: error.localizedDescription) }
        refreshLoginStatus()
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    private func report(_ copy: Copy, detail: String? = nil) {
        messageDetail = detail
        message = copy
    }
}
