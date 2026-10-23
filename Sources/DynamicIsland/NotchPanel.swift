import AppKit
import SwiftUI

/// Borderless, transparent panel that sits over the notch, above the menu bar, on every Space.
final class NotchPanel: NSPanel {
    init<Content: View>(rootView: Content) {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        // Collapsed by default: let clicks pass through to the menu bar.
        ignoresMouseEvents = true

        let host = NSHostingView(rootView: rootView)
        host.sizingOptions = []
        contentView = host
    }

    // Needed so the Todo text field can receive typing without activating the app.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Don't let AppKit push the window below the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
