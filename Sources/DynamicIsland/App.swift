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
    private let model = IslandModel()

    private var panel: NotchPanel!
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var monitors: [Any] = []
    private var collapseWork: DispatchWorkItem?
    private var notchRect: CGRect = .zero
    private var cancellables: Set<AnyCancellable> = []

    /// `--pin-expanded` keeps the island open (handy for screenshots and UI work).
    private let pinExpanded = CommandLine.arguments.contains("--pin-expanded")

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.openSettings = { [weak self] in self?.showSettings() }
        settings.$cities
            .map { min($0.count, SettingsStore.maxVisibleCities) }
            .sink { [weak self] count in self?.model.clockCityCount = count }
            .store(in: &cancellables)
        if let i = CommandLine.arguments.firstIndex(of: "--tab"), i + 1 < CommandLine.arguments.count,
           let tab = IslandTab(rawValue: CommandLine.arguments[i + 1]) {
            model.tab = tab
        }

        panel = NotchPanel(rootView: IslandView(model: model, settings: settings, todos: todos, calendar: calendar))
        layoutPanel()
        panel.orderFrontRegardless()
        setUpStatusItem()

        // Mouse-moved monitors (no Accessibility permission needed) drive hover open/close.
        let handler: (NSEvent) -> Void = { [weak self] _ in self?.handleMouse() }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { event in
            handler(event)
            return event
        }) {
            monitors.append(local)
        }

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.layoutPanel() }
        }

        if pinExpanded { setExpanded(true) }
    }

    // MARK: Layout

    /// The built-in display is the one with a notch (non-zero top safe area).
    private var targetScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    private func layoutPanel() {
        guard let screen = targetScreen else { return }
        notchRect = NotchGeometry.notchRect(screenFrame: screen.frame,
                                            leftAreaWidth: screen.auxiliaryTopLeftArea?.width,
                                            rightAreaWidth: screen.auxiliaryTopRightArea?.width,
                                            topInset: screen.safeAreaInsets.top)
        model.notchSize = notchRect.size
        // Fixed-size transparent panel; SwiftUI animates the black shape inside it.
        let max = IslandModel.maxExpandedSize
        let panelSize = CGSize(width: max.width + 40, height: max.height + 20)
        panel.setFrame(NotchGeometry.topCenteredRect(size: panelSize, under: notchRect), display: true)
    }

    // MARK: Hover

    private func handleMouse() {
        guard !pinExpanded else { return }
        let point = NSEvent.mouseLocation

        if model.isExpanded {
            let expanded = NotchGeometry.topCenteredRect(size: model.expandedSize, under: notchRect)
                .insetBy(dx: -12, dy: -12)
            if expanded.contains(point) {
                collapseWork?.cancel()
                collapseWork = nil
            } else if collapseWork == nil {
                let work = DispatchWorkItem { [weak self] in self?.setExpanded(false) }
                collapseWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
            }
        } else {
            // Hot zone: the notch itself, a little wider, up to the very top pixel.
            let hot = notchRect.insetBy(dx: -10, dy: 0)
            if point.x >= hot.minX, point.x <= hot.maxX, point.y >= hot.minY {
                setExpanded(true)
            }
        }
    }

    private func setExpanded(_ expanded: Bool) {
        collapseWork?.cancel()
        collapseWork = nil
        guard model.isExpanded != expanded else { return }

        if expanded { calendar.refresh() }
        panel.ignoresMouseEvents = !expanded

        let animation: Animation = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? .easeOut(duration: 0.15)
            : .spring(response: 0.38, dampingFraction: 0.8)
        withAnimation(animation) { model.isExpanded = expanded }

        // If the Todo field had keyboard focus, hand it back to whatever app was in front.
        if !expanded, panel.isKeyWindow {
            panel.makeFirstResponder(nil)
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
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
        if !pinExpanded { setExpanded(false) }
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 540),
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
