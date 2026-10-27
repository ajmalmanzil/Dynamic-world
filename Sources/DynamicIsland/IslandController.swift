import AppKit
import Combine
import IslandCore
import SwiftUI

/// Data shared by every island (one per screen).
struct IslandServices {
    let settings: SettingsStore
    let todos: TodoStore
    let calendar: CalendarService
    let screenshots: ScreenshotStore
}

/// One island on one screen: its panel, open/closed state, hover zone and close timer.
/// Each screen's island opens and closes on its own; the data behind it is shared.
@MainActor
final class IslandController {
    let model = IslandModel()

    private let panel: NotchPanel
    private let services: IslandServices
    private let pinExpanded: Bool
    private var notchRect: CGRect = .zero
    private var collapseWork: DispatchWorkItem?
    private var cancellables: Set<AnyCancellable> = []

    init(screen: NSScreen, services: IslandServices, pinExpanded: Bool, initialTab: IslandTab?,
         openSettings: @escaping () -> Void) {
        self.services = services
        self.pinExpanded = pinExpanded
        panel = NotchPanel(rootView: IslandView(model: model, settings: services.settings, todos: services.todos,
                                                calendar: services.calendar, screenshots: services.screenshots))
        model.openSettings = openSettings
        if let initialTab, services.settings.isEnabled(initialTab) { model.tab = initialTab }

        services.settings.$cities
            .map { min($0.count, SettingsStore.maxVisibleCities) }
            .sink { [weak self] count in self?.model.clockCityCount = count }
            .store(in: &cancellables)
        // After a drop, close the island if the mouse ended up outside it.
        model.$isDraggingOut
            .removeDuplicates()
            .filter { !$0 }
            .sink { [weak self] _ in DispatchQueue.main.async { self?.handleMouse() } }
            .store(in: &cancellables)
        // Keep the selected tab valid when features are switched off.
        services.settings.$enabledTabs
            .sink { [weak self] enabled in
                guard let self, !enabled.contains(self.model.tab),
                      let first = IslandTab.allCases.first(where: enabled.contains) else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { self.model.tab = first }
            }
            .store(in: &cancellables)

        layout(on: screen)
        panel.orderFrontRegardless()
        if pinExpanded { setExpanded(true) }
    }

    /// Notched screens use the notch; others get a pill centred in their menu bar.
    func layout(on screen: NSScreen) {
        notchRect = NotchGeometry.notchRect(screenFrame: screen.frame,
                                            leftAreaWidth: screen.auxiliaryTopLeftArea?.width,
                                            rightAreaWidth: screen.auxiliaryTopRightArea?.width,
                                            topInset: screen.safeAreaInsets.top,
                                            menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY)
        model.notchSize = notchRect.size
        // Fixed-size transparent panel; SwiftUI animates the black shape inside it.
        let max = IslandModel.maxExpandedSize
        let panelSize = CGSize(width: max.width + 40, height: max.height + 20)
        panel.setFrame(NotchGeometry.topCenteredRect(size: panelSize, under: notchRect), display: true)
    }

    func close() {
        collapseWork?.cancel()
        cancellables.removeAll()
        panel.orderOut(nil)
    }

    // MARK: Hover

    func handleMouse() {
        guard !pinExpanded else { return }
        if model.isDraggingOut {
            collapseWork?.cancel()
            collapseWork = nil
            return
        }
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
            // Hot zone: the island itself, a little wider, up to the very top pixel of this screen.
            let hot = notchRect.insetBy(dx: -10, dy: 0)
            if point.x >= hot.minX, point.x <= hot.maxX, point.y >= hot.minY, point.y <= hot.maxY + 1 {
                setExpanded(true)
            }
        }
    }

    func setExpanded(_ expanded: Bool) {
        collapseWork?.cancel()
        collapseWork = nil
        guard model.isExpanded != expanded else { return }

        if expanded {
            if services.settings.isEnabled(.meetings) { services.calendar.refresh() }
            if model.tab == .screenshots { services.screenshots.rescan() }
        }
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
}
