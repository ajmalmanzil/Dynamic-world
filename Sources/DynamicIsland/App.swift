import AppKit
import Combine
import IslandCore
import SwiftUI

@main
enum DynamicIslandApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // no Dock icon
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private let todos = TodoStore(fileURL: TodoStore.defaultFileURL)
    private let calendar = CalendarService()
    private let screenshots = ScreenshotStore()

    /// One island per screen, keyed by display ID.
    private var islands: [CGDirectDisplayID: IslandController] = [:]
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var monitors: [Any] = []
    private var cancellables: Set<AnyCancellable> = []

    /// `--pin-expanded` keeps the island open (handy for screenshots and UI work).
    private let pinExpanded = CommandLine.arguments.contains("--pin-expanded")
    /// `--tab <name>` opens islands on that tab.
    private let initialTab: IslandTab? = {
        guard let i = CommandLine.arguments.firstIndex(of: "--tab"), i + 1 < CommandLine.arguments.count else { return nil }
        return IslandTab(rawValue: CommandLine.arguments[i + 1])
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings.$enabledTabs
            .sink { [weak self] enabled in
                if !enabled.contains(.screenshots) { self?.screenshots.stop() }
            }
            .store(in: &cancellables)
        settings.$showOnExternalDisplays
            .dropFirst()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.syncIslands() } }
            .store(in: &cancellables)

        syncIslands()
        setUpStatusItem()

        // Mouse-moved monitors (no Accessibility permission needed) drive hover open/close.
        let handler: (NSEvent) -> Void = { [weak self] _ in self?.islands.values.forEach { $0.handleMouse() } }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { event in
            handler(event)
            return event
        }) {
            monitors.append(local)
        }

        // Monitors plugged in or unplugged, resolution or arrangement changed.
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncIslands() }
        }
    }

    // MARK: Screens

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// Every screen when external displays are on; otherwise just the notched one (or the main screen).
    private var targetScreens: [NSScreen] {
        if settings.showOnExternalDisplays { return NSScreen.screens }
        let notched = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
        return notched.map { [$0] } ?? []
    }

    /// Add islands for new screens, move existing ones, and remove islands for screens that are gone.
    private func syncIslands() {
        var wanted: [CGDirectDisplayID: NSScreen] = [:]
        for screen in targetScreens {
            if let id = Self.displayID(of: screen) { wanted[id] = screen }
        }
        for (id, island) in islands where wanted[id] == nil {
            island.close()
            islands[id] = nil
        }
        for (id, screen) in wanted {
            if let island = islands[id] {
                island.layout(on: screen)
            } else {
                islands[id] = IslandController(screen: screen, services: services, pinExpanded: pinExpanded,
                                               initialTab: initialTab,
                                               openSettings: { [weak self] in self?.showSettings() })
            }
        }
    }

    private var services: IslandServices {
        IslandServices(settings: settings, todos: todos, calendar: calendar, screenshots: screenshots)
    }

    // MARK: Menu bar & Settings

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Dynamic Island")
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Dynamic Island", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func openSettingsFromMenu() { showSettings() }

    private func showSettings() {
        if !pinExpanded { islands.values.forEach { $0.setExpanded(false) } }
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 640),
                                  styleMask: [.titled, .closable],
                                  backing: .buffered, defer: false)
            window.title = "Dynamic Island Settings"
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
