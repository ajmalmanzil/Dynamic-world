import AppKit
import IslandCore
import QuickLookThumbnailing

/// Watches the screenshot folder and keeps the newest few with thumbnails.
@MainActor
final class ScreenshotStore: ObservableObject {
    static let limit = 5

    @Published private(set) var screenshots: [Screenshot] = []
    @Published private(set) var thumbnails: [URL: NSImage] = [:]
    @Published private(set) var accessDenied = false

    private(set) var folder = ScreenshotLibrary.screenshotFolder()
    private var watcher: DispatchSourceFileSystemObject?
    private var pendingRescan: DispatchWorkItem?

    /// Starts on first use so the Desktop-access prompt appears when you open the tab, not at launch.
    func start() {
        guard watcher == nil else { rescan(); return }
        rescan()
        watch()
    }

    /// Called when the feature is turned off: stop watching the folder and forget the thumbnails.
    func stop() {
        watcher?.cancel()
        watcher = nil
        pendingRescan?.cancel()
        screenshots = []
        thumbnails = [:]
    }

    func rescan() {
        let newFolder = ScreenshotLibrary.screenshotFolder()
        if newFolder != folder {
            folder = newFolder
            watcher?.cancel()
            watcher = nil
            watch()
        }

        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            accessDenied = false
        } catch {
            accessDenied = (error as NSError).code == NSFileReadNoPermissionError
        }

        let latest = ScreenshotLibrary.latest(in: folder, limit: Self.limit)
        guard latest != screenshots else { return }
        screenshots = latest
        thumbnails = thumbnails.filter { url, _ in latest.contains { $0.url == url } }
        for shot in latest where thumbnails[shot.url] == nil { makeThumbnail(for: shot.url) }
    }

    private func watch() {
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete],
                                                               queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.scheduleRescan() }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        watcher = source
    }

    /// The screenshot file lands a moment before its metadata is written, so wait briefly.
    private func scheduleRescan() {
        pendingRescan?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.rescan() }
        pendingRescan = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func makeThumbnail(for url: URL) {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 160, height: 112),
                                                   scale: scale, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, _ in
            guard let image = rep?.nsImage else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.thumbnails[url] = image }
            }
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
            NSWorkspace.shared.open(url)
        }
    }
}
