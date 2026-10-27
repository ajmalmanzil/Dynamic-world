import XCTest
@testable import IslandCore

final class ScreenshotLibraryTests: XCTestCase {
    var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
    }

    @discardableResult
    private func makeFile(_ name: String, minutesAgo: Double, tagged: Bool = true) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try Data("x".utf8).write(to: url)
        let date = Date().addingTimeInterval(-minutesAgo * 60)
        try FileManager.default.setAttributes([.creationDate: date], ofItemAtPath: url.path)
        if tagged {
            let value = Data("1".utf8)
            _ = value.withUnsafeBytes { setxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", $0.baseAddress, value.count, 0, 0) }
        }
        return url
    }

    func testLatestReturnsNewestTaggedImagesOnly() throws {
        for i in 0..<7 { try makeFile("Shot \(i).png", minutesAgo: Double(i)) }
        try makeFile("Untagged.png", minutesAgo: 0.1, tagged: false)
        try makeFile("Notes.txt", minutesAgo: 0.1)

        let shots = ScreenshotLibrary.latest(in: folder)
        XCTAssertEqual(shots.map(\.url.lastPathComponent), ["Shot 0.png", "Shot 1.png", "Shot 2.png", "Shot 3.png", "Shot 4.png"])
    }

    func testSinceHidesOlderScreenshots() throws {
        try makeFile("Today 1.png", minutesAgo: 5)
        try makeFile("Today 2.png", minutesAgo: 30)
        try makeFile("Yesterday.png", minutesAgo: 60 * 26)

        let since = Date().addingTimeInterval(-60 * 60)
        XCTAssertEqual(ScreenshotLibrary.latest(in: folder, since: since).map(\.url.lastPathComponent),
                       ["Today 1.png", "Today 2.png"])
        XCTAssertTrue(ScreenshotLibrary.latest(in: folder, since: Date().addingTimeInterval(60)).isEmpty)
        XCTAssertEqual(ScreenshotLibrary.latest(in: folder).count, 3)
    }

    func testCustomPredicateAndMissingFolder() throws {
        try makeFile("a.png", minutesAgo: 1, tagged: false)
        XCTAssertEqual(ScreenshotLibrary.latest(in: folder, isScreenshot: { _ in true }).count, 1)
        XCTAssertTrue(ScreenshotLibrary.latest(in: folder.appendingPathComponent("nope")).isEmpty)
    }

    func testScreenshotFolderSetting() throws {
        let suite = "IslandTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let home = URL(fileURLWithPath: "/Users/someone")

        XCTAssertEqual(ScreenshotLibrary.screenshotFolder(defaults: defaults, home: home).path, "/Users/someone/Desktop")
        defaults.set(folder.path, forKey: "location")
        XCTAssertEqual(ScreenshotLibrary.screenshotFolder(defaults: defaults, home: home).standardizedFileURL.path,
                       folder.standardizedFileURL.path)
        defaults.set("/does/not/exist", forKey: "location")
        XCTAssertEqual(ScreenshotLibrary.screenshotFolder(defaults: defaults, home: home).path, "/Users/someone/Desktop")
    }

    func testTiltIsStableBoundedAndVaried() {
        let names = (0..<50).map { "Screenshot 2026-10-23 at 17.\($0).00.png" }
        let tilts = names.map(ScreenshotLibrary.tilt(for:))
        XCTAssertEqual(tilts, names.map(ScreenshotLibrary.tilt(for:)))
        XCTAssertTrue(tilts.allSatisfy { abs($0) >= 1.5 && abs($0) <= 4 })
        XCTAssertTrue(tilts.contains { $0 > 0 } && tilts.contains { $0 < 0 })
        XCTAssertGreaterThan(Set(tilts).count, 40)
    }

    func testAgeLabel() {
        let now = Date()
        XCTAssertEqual(ScreenshotLibrary.ageLabel(for: now.addingTimeInterval(-20), now: now), "now")
        XCTAssertEqual(ScreenshotLibrary.ageLabel(for: now.addingTimeInterval(-300), now: now), "5m")
        XCTAssertEqual(ScreenshotLibrary.ageLabel(for: now.addingTimeInterval(-3 * 3600), now: now), "3h")
        XCTAssertEqual(ScreenshotLibrary.ageLabel(for: now.addingTimeInterval(-2 * 86_400), now: now), "2d")
    }
}
