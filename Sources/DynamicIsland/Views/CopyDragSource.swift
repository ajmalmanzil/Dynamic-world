import AppKit
import SwiftUI

/// Drags a file out as a copy-only operation, so Finder copies it (never moves it) and chat apps
/// like Slack or Teams just upload it. The original file is never touched.
struct CopyDragSource: NSViewRepresentable {
    let url: URL
    let image: NSImage?
    var onDragChanged: (Bool) -> Void = { _ in }

    func makeNSView(context: Context) -> DragSourceView {
        DragSourceView()
    }

    func updateNSView(_ view: DragSourceView, context: Context) {
        view.url = url
        view.image = image
        view.onDragChanged = onDragChanged
        view.toolTip = "\(url.lastPathComponent)\nDrag to copy · double-click to open"
    }

    final class DragSourceView: NSView, NSDraggingSource {
        var url: URL?
        var image: NSImage?
        var onDragChanged: (Bool) -> Void = { _ in }
        private var isDragging = false

        // The island panel is never the key window; react to the very first click.
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2, let url { NSWorkspace.shared.open(url) }
        }

        override func mouseDragged(with event: NSEvent) {
            guard !isDragging, let url else { return }
            isDragging = true
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            item.setDraggingFrame(bounds, contents: image ?? NSWorkspace.shared.icon(forFile: url.path))
            beginDraggingSession(with: [item], event: event, source: self)
            onDragChanged(true)
        }

        func draggingSession(_ session: NSDraggingSession,
                             sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            .copy
        }

        // Holding ⌘ normally turns a Finder drag into a move; ignore it so it always copies.
        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }

        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            isDragging = false
            onDragChanged(false)
        }
    }
}
