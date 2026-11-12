import AppKit
import BellCore
import SwiftUI

@MainActor
enum Theme {
    static var accent: Color {
        Color(nsColor: NSColor(name: "MindfulGreen") { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(srgbRed: 0.49, green: 0.77, blue: 0.64, alpha: 1)
                : NSColor(srgbRed: 0.16, green: 0.38, blue: 0.30, alpha: 1)
        })
    }
    static var surface: Color { Color(nsColor: .controlBackgroundColor) }
    static var onAccent: Color {
        Color(nsColor: NSColor(name: "OnMindfulGreen") { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(srgbRed: 0.08, green: 0.16, blue: 0.13, alpha: 1) : .white
        })
    }
}

struct ChoiceButtonStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: selected ? .semibold : .regular))
            .padding(.horizontal, 10).padding(.vertical, 7)
            .foregroundStyle(selected ? Theme.accent : .primary)
            .background(selected ? Theme.accent.opacity(0.12) : Theme.surface, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(selected ? Theme.accent.opacity(0.4) : .primary.opacity(0.15)))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 16).padding(.vertical, 7)
            .foregroundStyle(Theme.onAccent)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 7))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

struct BellMark: View {
    var size: CGFloat = 52

    @MainActor private static let artwork: NSImage = {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) { return image }
        return NSImage(named: NSImage.applicationIconName) ?? NSImage(size: NSSize(width: 64, height: 64))
    }()

    var body: some View {
        Image(nsImage: Self.artwork)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.08)))
    }
}

struct StatusCard: View {
    @ObservedObject var model: AppModel
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: model.statusSymbol)
                .font(.system(size: compact ? 19 : 23, weight: .regular))
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(model.statusTitle).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Spacer(minLength: 8)
                    if model.settings.isEnabled {
                        if case .paused = model.phase {
                            Button(model.text(.resume)) { model.resume() }.controlSize(.small)
                        } else {
                            Menu {
                                Button(model.text(.pause30)) { model.pause(minutes: 30) }
                                Button(model.text(.pause60)) { model.pause(minutes: 60) }
                            } label: { Text(model.text(.pause)) }
                            .fixedSize().controlSize(.small)
                        }
                    }
                }
                Text(model.nextLabel).font(.system(size: compact ? 13 : 14))
                    .fixedSize(horizontal: false, vertical: true)
                if let date = model.phaseDate {
                    Text(model.dateText(date))
                        .font(.system(size: compact ? 17 : 21, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(compact ? 16 : 20)
        .background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.accent.opacity(0.15)))
        .accessibilityElement(children: .contain)
    }
}

struct VolumeControl: View {
    @ObservedObject var model: AppModel
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.text(.volume)).font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(Int((model.settings.volume * 100).rounded()))%")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.1").foregroundStyle(.secondary).accessibilityHidden(true)
                Slider(value: Binding(get: { model.settings.volume }, set: { value in model.update { $0.volume = value } }), in: 0...1)
                    .accessibilityLabel(model.text(.volume))
                    .accessibilityValue("\(Int((model.settings.volume * 100).rounded()))%")
                Image(systemName: "speaker.wave.3").foregroundStyle(.secondary).accessibilityHidden(true)
            }
            if model.settings.volume == 0 {
                Label(model.text(.silentVolume), systemImage: "speaker.slash")
                    .font(.caption).foregroundStyle(.secondary)
            } else if !compact {
                Text(model.text(.volumeNote)).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct PlaybackButton: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Button { model.preview() } label: {
            Label(model.text(model.isPlaying ? .stopSound : .preview), systemImage: model.isPlaying ? "stop.fill" : "play.fill")
        }
        .help(model.text(.previewNote))
    }
}

struct MessageView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        if let message = model.message {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle").accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.text(message))
                    if let detail = model.messageDetail { Text(detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                }
                Spacer(minLength: 0)
                Button { model.message = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).help(model.text(.dismiss)).accessibilityLabel(model.text(.dismiss))
            }
            .font(.callout).padding(14)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct MenuPanel: View {
    @ObservedObject var model: AppModel
    var openSettings: () -> Void
    var quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                BellMark(size: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Bell of Mindfulness").font(.system(size: 15, weight: .semibold))
                    Text(model.text(.tagline)).font(.caption).foregroundStyle(.secondary)
                }
            }
            StatusCard(model: model, compact: true)
            HStack {
                Text(model.text(.enableBell))
                Spacer()
                Toggle(model.text(.enableBell), isOn: Binding(get: { model.settings.isEnabled }, set: { model.setEnabled($0) }))
                    .toggleStyle(.switch).labelsHidden().controlSize(.small)
            }
            VolumeControl(model: model, compact: true)
            HStack {
                PlaybackButton(model: model)
                Spacer()
                if case .waiting = model.phase {
                    Button { model.restart() } label: { Image(systemName: "arrow.clockwise") }
                        .help(model.text(.resetInterval)).accessibilityLabel(model.text(.resetInterval))
                }
            }
            MessageView(model: model)
            Divider()
            HStack {
                Button(model.text(.settings), action: openSettings).keyboardShortcut(",")
                Spacer()
                Button(action: quit) { Image(systemName: "power") }
                    .help(model.text(.quit)).accessibilityLabel(model.text(.quit)).keyboardShortcut("q")
            }.buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(20).frame(width: 360)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(Theme.accent)
        .environment(\.locale, model.locale)
    }
}

struct IntervalControl: View {
    @ObservedObject var model: AppModel
    @State private var draft = ""
    @FocusState private var focused: Bool

    var valid: Bool { Int(draft).map { (1...1440).contains($0) } ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.text(.interval)).font(.system(size: 13, weight: .medium))
                Spacer()
                TextField("30", text: $draft)
                    .textFieldStyle(.roundedBorder).frame(width: 72)
                    .multilineTextAlignment(.trailing).focused($focused)
                    .accessibilityLabel(model.text(.interval))
                    .onSubmit(commit)
                    .onChange(of: focused) { _, value in if !value { commit() } }
                Text(model.text(.minutes)).foregroundStyle(.secondary)
                Stepper(model.text(.interval), value: Binding(get: { model.settings.intervalMinutes }, set: { value in
                    model.update { $0.intervalMinutes = value }; draft = String(value)
                }), in: 1...1440).labelsHidden()
            }
            HStack(spacing: 8) {
                ForEach([15, 30, 45, 60], id: \.self) { value in
                    Button("\(value) \(model.text(.minutes))") {
                        model.update { $0.intervalMinutes = value }; draft = String(value)
                    }
                    .buttonStyle(ChoiceButtonStyle(selected: model.settings.intervalMinutes == value))
                    .accessibilityAddTraits(model.settings.intervalMinutes == value ? .isSelected : [])
                }
            }
            if !valid {
                Text(model.text(.intervalRange)).font(.caption).foregroundStyle(.red)
            }
            Text(model.text(.intervalNote)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { draft = String(model.settings.intervalMinutes) }
        .onChange(of: model.settings.intervalMinutes) { _, value in draft = String(value) }
        .onDisappear(perform: commit)
    }

    private func commit() {
        guard let value = Int(draft), (1...1440).contains(value) else { return }
        model.update { $0.intervalMinutes = value }
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case nextBell = "next-bell"
    case sound
    case quietHours = "quiet-hours"
    case preferences

    var id: String { rawValue }

    var title: Copy {
        switch self {
        case .nextBell: .nextBell
        case .sound: .sound
        case .quietHours: .quietHours
        case .preferences: .general
        }
    }

    var symbol: String {
        switch self {
        case .nextBell: "bell"
        case .sound: "waveform"
        case .quietHours: "moon"
        case .preferences: "slider.horizontal.3"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selectedTab: SettingsTab?

    init(model: AppModel, initialTab: SettingsTab = .nextBell) {
        self.model = model
        _selectedTab = State(initialValue: initialTab)
    }

    private var currentTab: SettingsTab { selectedTab ?? .nextBell }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    List(SettingsTab.allCases, selection: $selectedTab) { tab in
                        Label(model.text(tab.title), systemImage: tab.symbol)
                            .font(.system(size: 13))
                            .padding(.vertical, 5)
                            .tag(tab)
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .padding(.top, 8)
                    Text(AppVersion.label).font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 20).padding(.bottom, 16)
                }.frame(width: 180)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(model.text(currentTab.title)).font(.system(size: 21, weight: .semibold))
                            .accessibilityAddTraits(.isHeader)
                        MessageView(model: model)
                        switch currentTab {
                        case .nextBell: nextBellPane
                        case .sound: SoundSettingsPane(model: model)
                        case .quietHours: QuietHoursPane(model: model)
                        case .preferences: PreferencesPane(model: model)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.surface)
                .id(currentTab)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(Theme.accent)
        .environment(\.locale, model.locale)
        .frame(minWidth: 640, idealWidth: 680, minHeight: 460, idealHeight: 500)
    }

    private var nextBellPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            StatusCard(model: model)
            Toggle(model.text(.enableBell), isOn: Binding(get: { model.settings.isEnabled }, set: { model.setEnabled($0) }))
                .toggleStyle(.switch)
            if case .waiting = model.phase {
                Button { model.restart() } label: {
                    Label(model.text(.resetInterval), systemImage: "arrow.clockwise")
                }
            }
        }
    }
}

struct SoundSettingsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            IntervalControl(model: model)
            Divider()
            VolumeControl(model: model)
            VStack(alignment: .leading, spacing: 8) {
                PlaybackButton(model: model)
                Text(model.text(.previewNote)).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct QuietHoursPane: View {
    @ObservedObject var model: AppModel
    @State private var editing: QuietPeriod?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.text(.quietNote)).font(.callout).foregroundStyle(.secondary)
            if model.settings.quietPeriods.isEmpty {
                Text(model.text(.noPeriods)).font(.callout).foregroundStyle(.secondary).padding(.vertical, 8)
            }
            ForEach(model.settings.quietPeriods) { period in
                QuietPeriodRow(model: model, period: period, edit: { editing = period })
                Divider()
            }
            Button { editing = QuietPeriod(startMinute: 12 * 60, endMinute: 13 * 60) } label: {
                Label(model.text(.addPeriod), systemImage: "plus")
            }
            if QuietSchedule(periods: model.settings.quietPeriods).coversEntireWeek {
                Label(model.text(.allDayWarning), systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .sheet(item: $editing) { period in
            QuietPeriodEditor(model: model, initial: period,
                              isNew: !model.settings.quietPeriods.contains(where: { $0.id == period.id }))
        }
    }
}

struct PreferencesPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(model.text(.language))
                Spacer()
                Picker(model.text(.language), selection: Binding(get: { model.settings.language }, set: { value in model.update { $0.language = value } })) {
                    Text("EN").tag(AppLanguage.english)
                    Text("DE").tag(AppLanguage.german)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 130)
            }
            Divider()
            Toggle(isOn: Binding(get: { model.loginStatus == .enabled || model.loginStatus == .requiresApproval }, set: { model.setLaunchAtLogin($0) })) {
                Text(model.text(.launchAtLogin))
            }.toggleStyle(.switch)
            Text(model.text(.loginNote)).font(.caption).foregroundStyle(.secondary)
            if model.loginStatus == .requiresApproval {
                Text(model.text(.loginApproval)).font(.caption).foregroundStyle(.secondary)
                Button(model.text(.openSystemSettings)) { model.openLoginSettings() }
            }
        }
    }
}

struct QuietPeriodRow: View {
    @ObservedObject var model: AppModel
    let period: QuietPeriod
    let edit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Toggle(model.text(.enabled), isOn: Binding(get: { period.isEnabled }, set: { value in
                var changed = period; changed.isEnabled = value; model.savePeriod(changed)
            })).toggleStyle(.switch).labelsHidden().controlSize(.small)
                .accessibilityLabel("\(model.text(.enabled)): \(model.timeText(period.startMinute))–\(model.timeText(period.endMinute))")
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("\(model.timeText(period.startMinute)) – \(model.timeText(period.endMinute))")
                        .font(.system(size: 16, weight: .medium, design: .rounded)).monospacedDigit()
                    if period.endMinute < period.startMinute {
                        Text("+1").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 3)
                            .background(.primary.opacity(0.06), in: Capsule()).help(model.text(.nextDay))
                    }
                }
                Text(model.daysText(period.weekdays)).font(.caption).foregroundStyle(.secondary)
            }.opacity(period.isEnabled ? 1 : 0.55)
            Spacer(minLength: 4)
            Button(action: edit) { Image(systemName: "pencil") }
                .help(model.text(.editPeriod)).accessibilityLabel(model.text(.editPeriod))
            Button(role: .destructive) { model.removePeriod(period.id) } label: { Image(systemName: "trash") }
                .help(model.text(.deletePeriod)).accessibilityLabel(model.text(.deletePeriod))
        }.padding(.vertical, 3)
    }
}

struct QuietPeriodEditor: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: QuietPeriod
    let isNew: Bool

    init(model: AppModel, initial: QuietPeriod, isNew: Bool) {
        self.model = model; self.isNew = isNew
        _draft = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(model.text(isNew ? .newPeriod : .editPeriod)).font(.title2.weight(.semibold))
            HStack(spacing: 32) {
                DatePicker(model.text(.start), selection: timeBinding(start: true), displayedComponents: .hourAndMinute)
                DatePicker(model.text(.end), selection: timeBinding(start: false), displayedComponents: .hourAndMinute)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text(model.text(.days)).font(.headline)
                HStack(spacing: 7) {
                    ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                        Button(model.weekdayText(day)) {
                            if draft.weekdays.contains(day) { draft.weekdays.remove(day) } else { draft.weekdays.insert(day) }
                        }.buttonStyle(ChoiceButtonStyle(selected: draft.weekdays.contains(day)))
                            .accessibilityLabel(model.weekdayText(day, full: true))
                            .accessibilityAddTraits(draft.weekdays.contains(day) ? .isSelected : [])
                            .accessibilityValue(model.text(draft.weekdays.contains(day) ? .active : .off))
                    }
                }
                HStack(spacing: 12) {
                    Button(model.text(.everyDay)) { draft.weekdays = Set(1...7) }
                    Button(model.text(.weekdays)) { draft.weekdays = Set(2...6) }
                    Button(model.text(.weekend)) { draft.weekdays = [1, 7] }
                }.buttonStyle(.link).font(.caption)
            }
            if draft.startMinute == draft.endMinute {
                Text(model.text(.equalTimesError)).font(.callout).foregroundStyle(.red)
            } else if draft.endMinute < draft.startMinute {
                Label(model.text(.overnightNote), systemImage: "moon")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if draft.weekdays.isEmpty { Text(model.text(.noDaysError)).font(.callout).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button(model.text(.cancel)) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(model.text(.save)) { model.savePeriod(draft); dismiss() }
                    .buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction).disabled(!draft.isValid)
            }
        }
        .padding(28).frame(width: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.locale, model.locale).tint(Theme.accent)
    }

    private func timeBinding(start: Bool) -> Binding<Date> {
        Binding(get: {
            let minute = start ? draft.startMinute : draft.endMinute
            return Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 15, hour: minute / 60, minute: minute % 60))!
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            if start { draft.startMinute = minute } else { draft.endMinute = minute }
        })
    }
}
