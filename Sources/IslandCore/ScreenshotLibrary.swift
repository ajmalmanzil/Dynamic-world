import Foundation

public struct Screenshot: Identifiable, Equatable {
    public var url: URL
    public var createdAt: Date
    public var id: URL { url }

    public init(url: URL, createdAt: Date) {
        self.url = url
        self.createdAt = createdAt
    }
}

public enum ScreenshotLibrary {
    /// Where macOS saves screenshots: the `com.apple.screencapture` "location" setting, else the Desktop.
    public static func screenshotFolder(defaults: UserDefaults? = UserDefaults(suiteName: "com.apple.screencapture"),
                                        home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        if let raw = defaults?.string(forKey: "location"), !raw.isEmpty {
            let expanded = (raw as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue {
                return URL(fileURLWithPath: expanded, isDirectory: true)
            }
        }
        return home.appendingPathComponent("Desktop", isDirectory: true)
    }

    /// macOS tags every screenshot with this extended attribute, whatever the system language.
    public static func hasScreenCaptureTag(_ url: URL) -> Bool {
        getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) > 0
    }

    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "gif", "pdf"]

    /// Newest screenshots first, optionally only those created at or after `since`.
    public static func latest(in folder: URL, limit: Int = 5, since: Date? = nil,
                              isScreenshot: (URL) -> Bool = hasScreenCaptureTag) -> [Screenshot] {
        let keys: [URLResourceKey] = [.creationDateKey, .isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                                 options: [.skipsHiddenFiles])) ?? []
        return urls
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) && isScreenshot($0) }
            .compactMap { url -> Screenshot? in
                guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { return nil }
                return Screenshot(url: url, createdAt: values.creationDate ?? .distantPast)
            }
            .filter { shot in since.map { shot.createdAt >= $0 } ?? true }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    /// A random-looking but stable tilt in degrees (1.5°–4°, either direction), seeded by the file name
    /// so a screenshot keeps its angle across launches. Uses FNV-1a because `hashValue` changes per launch.
    public static func tilt(for name: String) -> Double {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in name.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        let magnitude = 1.5 + Double(hash % 1000) / 999 * 2.5
        return (hash >> 32) & 1 == 0 ? magnitude : -magnitude
    }

    /// "now", "5m", "3h", "2d" — compact age shown under each thumbnail.
    public static func ageLabel(for date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        switch seconds {
        case ..<60: return "now"
        case ..<3600: return "\(seconds / 60)m"
        case ..<86_400: return "\(seconds / 3600)h"
        default: return "\(seconds / 86_400)d"
        }
    }
}
