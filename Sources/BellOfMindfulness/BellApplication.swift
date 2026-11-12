import AppKit
import Combine
import SwiftUI

@main
struct BellApplication {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--version") {
            print(AppVersion.label)
            return
        }
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--self-check") {
            exit(RuntimeChecks.run())
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render-previews"),
           CommandLine.arguments.indices.contains(index + 1) {
            exit(RuntimeChecks.render(to: CommandLine.arguments[index + 1]))
        }
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private var popover: NSPopover?
    private var settingsWindow: NSWindow?
    private var subscription: AnyCancellable?
    private let smokeMode = CommandLine.arguments.contains("--smoke-test") || CommandLine.arguments.contains("--measure-idle")
    private let smokeSuite = "BellOfMindfulness.Smoke.\(UUID().uuidString)"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Opening a second copy focuses the existing app instead of starting a second bell schedule.
        if !smokeMode, let identifier = Bundle.main.bundleIdentifier,
           let other = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            other.activate(options: [])
            NSApplication.shared.terminate(nil)
            return
        }
        model = smokeMode ? AppModel(store: SettingsStore(defaults: UserDefaults(suiteName: smokeSuite)!)) : AppModel()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        refreshStatusItem()
        subscription = model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshStatusItem() }
        }
        configureApplicationMenu()
        if smokeMode {
            if CommandLine.arguments.contains("--measure-idle") {
                finishSmokeCheck()
                return
            }
            showSettings()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.performSmokeCheck() }
            return
        }
        if !UserDefaults.standard.bool(forKey: "bell.hasOpened") {
            UserDefaults.standard.set(true, forKey: "bell.hasOpened")
            showSettings()
        }
    }

    private func configureApplicationMenu() {
        let main = NSMenu()
        let appMenu = NSMenu()
        let root = NSMenuItem()
        root.title = "Bell of Mindfulness"
        root.submenu = appMenu
        main.addItem(root)
        appMenu.addItem(withTitle: model.text(.settings), action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(withTitle: model.text(.close), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: model.text(.quit), action: #selector(quit), keyEquivalent: "q").target = self
        let editRoot = NSMenuItem(title: model.text(.edit), action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: model.text(.edit))
        for (copy, selector, key) in [(Copy.undo, "undo:", "z"), (.redo, "redo:", "Z"),
                                      (.cut, "cut:", "x"), (.copy, "copy:", "c"),
                                      (.paste, "paste:", "v"), (.selectAll, "selectAll:", "a")] {
            editMenu.addItem(withTitle: model.text(copy), action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        editRoot.submenu = editMenu
        main.addItem(editRoot)
        NSApplication.shared.mainMenu = main
    }

    private func refreshStatusItem() {
        guard let model, let button = statusItem?.button else { return }
        button.image = MenuBarIcon.image
        if case .waiting = model.phase { button.alphaValue = 1 }
        else { button.alphaValue = 0.55 }
        button.imagePosition = .imageOnly
        button.toolTip = "Bell of Mindfulness · \(model.statusTitle)\n\(model.nextLabel)\(model.phaseDate.map { ": \(model.dateText($0))" } ?? "")"
        button.setAccessibilityLabel("Bell of Mindfulness: \(model.statusTitle)")
        if let appMenu = NSApplication.shared.mainMenu?.items.first?.submenu {
            appMenu.items.first?.title = model.text(.settings)
            if appMenu.items.count > 1 { appMenu.items[1].title = model.text(.close) }
            appMenu.items.last?.title = model.text(.quit)
        }
        if let editRoot = NSApplication.shared.mainMenu?.items.last, let editMenu = editRoot.submenu {
            editRoot.title = model.text(.edit)
            for (item, copy) in zip(editMenu.items, [Copy.undo, .redo, .cut, .copy, .paste, .selectAll]) {
                item.title = model.text(copy)
            }
        }
        settingsWindow?.title = "Bell of Mindfulness"
    }

    @objc private func statusClicked() {
        guard let button = statusItem.button else { return }
        if NSApplication.shared.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: model.text(.settings), action: #selector(showSettings), keyEquivalent: ",").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: model.text(.quit), action: #selector(quit), keyEquivalent: "q").target = self
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
            return
        }
        if popover?.isShown == true { popover?.performClose(nil); return }
        let panel = NSPopover()
        panel.behavior = .transient
        panel.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.delegate = self
        panel.contentViewController = NSHostingController(rootView: MenuPanel(model: model, openSettings: { [weak self] in
            self?.showSettings()
        }, quit: { [weak self] in self?.quit() }))
        popover = panel
        panel.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        panel.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        popover?.contentViewController = nil
        popover = nil
    }

    @objc func showSettings() {
        guard model != nil else { return }
        popover?.performClose(nil)
        model.refreshLoginStatus()
        NSApplication.shared.setActivationPolicy(.regular)
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 500),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "Bell of Mindfulness"
            window.contentMinSize = NSSize(width: 640, height: 460)
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            let hosting = NSHostingView(rootView: SettingsView(model: model))
            hosting.sizingOptions = []
            window.contentView = hosting
            if !smokeMode {
                window.setFrameAutosaveName("BellSettingsWindowCompact")
                if !window.setFrameUsingName("BellSettingsWindowCompact") { window.center() }
            } else { window.center() }
            settingsWindow = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        if settingsWindow?.isMiniaturized == true { settingsWindow?.deminiaturize(nil) }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) { model?.refreshLoginStatus() }

    func windowWillClose(_ notification: Notification) {
        model?.flushSettings()
        settingsWindow?.contentView = nil
        settingsWindow = nil // Keep the resident app small when settings are closed.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }

    private func performSmokeCheck() {
        guard statusItem.button != nil, settingsWindow?.isVisible == true else {
            print("FAIL: native settings window / menu bar item"); exit(1)
        }
        guard NSApplication.shared.activationPolicy() == .regular,
              NSRunningApplication.current.activationPolicy == .regular else {
            print("FAIL: open settings must participate in Dock / Command+Tab"); exit(1)
        }
        print("PASS: open settings use the regular application policy")
        model.update { $0.language = .german }
        statusClicked()
        guard popover?.isShown == true else { print("FAIL: menu popover"); exit(1) }
        popover?.performClose(nil)
        settingsWindow?.close()
        guard settingsWindow == nil, model.settings.isEnabled else {
            print("FAIL: closing settings should keep scheduling enabled"); exit(1)
        }
        guard NSApplication.shared.activationPolicy() == .accessory else {
            print("FAIL: closed settings must return to menu-bar-only policy"); exit(1)
        }
        showSettings()
        guard settingsWindow?.isVisible == true, NSApplication.shared.activationPolicy() == .regular else {
            print("FAIL: reopening settings must restore the regular application policy"); exit(1)
        }
        settingsWindow?.miniaturize(nil)
        guard NSApplication.shared.activationPolicy() == .regular else {
            print("FAIL: minimized settings should stay in the app switcher"); exit(1)
        }
        showSettings()
        guard settingsWindow?.isMiniaturized == false else {
            print("FAIL: opening settings should restore a minimized window"); exit(1)
        }
        settingsWindow?.close()
        guard NSApplication.shared.activationPolicy() == .accessory, statusItem.button != nil else {
            print("FAIL: closing the reopened window must retain only the menu bar item"); exit(1)
        }
        print("PASS: native settings, menu popover, language switch, reopen/minimize/close activation lifecycle")
        print("IDLE_PID=\(ProcessInfo.processInfo.processIdentifier)")
        fflush(nil)
        finishSmokeCheck()
    }

    private func finishSmokeCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self else { return }
            if let memory = RuntimeChecks.memoryFootprintMiB() {
                print(String(format: "IDLE_MEMORY_FOOTPRINT_MIB=%.1f", memory))
            }
            self.model.shutdown()
            UserDefaults(suiteName: self.smokeSuite)?.removePersistentDomain(forName: self.smokeSuite)
            self.model = nil
            print("PASS: clean shutdown; no audio played and no login item changed")
            NSApplication.shared.terminate(nil)
        }
    }
}
