import AppKit
import AVFoundation
import BellCore
import SwiftUI
import Darwin

/// Explicit developer entry points. They never register login items or play audio.
@MainActor
enum RuntimeChecks {
    static func memoryFootprintMiB() -> Double? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : nil
    }

    static func run() -> Int32 {
        let suite = "BellOfMindfulness.Checks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            guard condition() else { print("FAIL: \(name)"); exit(1) }
            checks += 1
            print("PASS: \(name)")
        }
        let store = SettingsStore(defaults: defaults)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        check(version?.isEmpty == false, "app bundle contains its version")
        check(AppVersion.label == "v\(version ?? "")", "UI version matches app metadata with a v prefix")
        let model = AppModel(store: store, runtimeEnabled: false)
        defer { model.shutdown() }
        check(model.settings.isValid, "valid initial settings")
        let initialPhase = model.phase
        model.update { $0.volume = 0.21 }
        check(model.phase == initialPhase, "volume preserves current interval")
        model.update { $0.language = .german }
        check(model.phase == initialPhase, "language preserves current interval")
        check(model.text(.settings) == "Einstellungen …", "German copy updates immediately")
        check(model.locale.identifier == "de_DE", "German date locale")
        check(Copy.allCases.allSatisfy { !$0.text(.english).isEmpty && !$0.text(.german).isEmpty }, "all copy exists in EN and DE")
        model.setEnabled(false)
        check(model.phase == .disabled, "disable cancels schedule")
        model.resume()
        check(model.settings.isEnabled, "resume enables schedule")
        model.pause(minutes: 30)
        check(model.settings.pauseUntil != nil, "temporary pause saved")
        model.resume()
        check(model.settings.pauseUntil == nil, "resume clears pause")
        let period = QuietPeriod(startMinute: 720, endMinute: 780, weekdays: [2, 3, 4, 5, 6])
        model.savePeriod(period)
        check(model.settings.quietPeriods.count == 2, "add quiet period")
        var changed = period
        changed.endMinute = 810
        model.savePeriod(changed)
        check(model.settings.quietPeriods.last?.endMinute == 810, "edit quiet period")
        model.removePeriod(period.id)
        check(model.settings.quietPeriods.count == 1, "remove quiet period")
        model.flushSettings()
        check(store.load() == model.settings, "settings persistence round trip")
        defaults.set(Data("invalid JSON".utf8), forKey: "bell.settings.v1")
        let recovery = SettingsStore(defaults: defaults)
        check(recovery.load().isValid && recovery.recovered, "invalid settings recovery")
        check(defaults.dictionaryRepresentation().keys.contains(where: { $0.hasPrefix("bell.settings.v1.recovery.") }), "invalid settings backup preserved")
        check(Bundle.main.url(forResource: "Bell of Mindfulness", withExtension: "mp3") != nil, "audio bundled")
        check(Bundle.main.url(forResource: "AppIcon", withExtension: "icns") != nil, "icon bundled")
        do {
            let url = Bundle.main.url(forResource: "Bell of Mindfulness", withExtension: "mp3")!
            let file = try AVAudioFile(forReading: url)
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096)!
            try file.read(into: buffer)
            check(buffer.frameLength > 0 && file.length > 0, "bundled MP3 decodes without playing")
            check(abs(Double(file.length) / file.processingFormat.sampleRate - 27.6) < 0.1, "full original sound duration preserved")
        } catch { print("FAIL: audio decode: \(error)"); return 1 }
        print("\(checks) runtime checks passed. No sound played; no login item changed.")
        return 0
    }

    static func render(to directory: String) -> Int32 {
        let suite = "BellOfMindfulness.Previews.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(store: SettingsStore(defaults: defaults), runtimeEnabled: false)
        defer { model.shutdown() }
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            for language in AppLanguage.allCases {
                model.update { $0.language = language }
                for dark in [false, true] {
                    let name = "\(language.rawValue)-\(dark ? "dark" : "light")"
                    let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
                    NSApplication.shared.appearance = appearance
                    for tab in SettingsTab.allCases {
                        let file = tab == .nextBell ? "settings-\(name)" : "settings-\(tab.rawValue)-\(name)"
                        try snapshot(SettingsView(model: model, initialTab: tab), size: NSSize(width: 680, height: 500),
                                     appearance: appearance, path: "\(directory)/\(file).png")
                    }
                    try snapshot(MenuPanel(model: model, openSettings: {}, quit: {}), size: NSSize(width: 360, height: 440),
                                 appearance: appearance, path: "\(directory)/menu-\(name).png")
                    try snapshot(HStack(spacing: 24) {
                        Image(nsImage: MenuBarIcon.image).frame(width: 18, height: 18)
                        Image(nsImage: MenuBarIcon.image).resizable().frame(width: 72, height: 72)
                    }.foregroundStyle(.primary).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .windowBackgroundColor)),
                        size: NSSize(width: 160, height: 96), appearance: appearance,
                        path: "\(directory)/menu-bar-icon-\(name).png")
                }
            }
            try snapshot(QuietPeriodEditor(model: model, initial: QuietPeriod(), isNew: false),
                         size: NSSize(width: 536, height: 340), appearance: NSAppearance(named: .aqua)!,
                         path: "\(directory)/quiet-editor-de.png")
            print("Rendered EN/DE, light/dark settings and menu previews to \(directory)")
            return 0
        } catch {
            print("Preview failed: \(error)")
            return 1
        }
    }

    private static func snapshot<V: View>(_ view: V, size: NSSize, appearance: NSAppearance, path: String) throws {
        let hosting = NSHostingView(rootView: view
            .environment(\.colorScheme, appearance.name == .darkAqua ? .dark : .light)
            .frame(width: size.width, height: size.height, alignment: .topLeading))
        hosting.sizingOptions = []
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = appearance
        window.contentView = hosting
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        // Native sidebar rows finish their initial layout on the next run-loop pass.
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        hosting.layoutSubtreeIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { throw CocoaError(.fileWriteUnknown) }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: URL(fileURLWithPath: path))
        window.contentView = nil
        window.close()
    }
}
