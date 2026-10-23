import XCTest
@testable import IslandCore

final class TodoStoreTests: XCTestCase {
    var fileURL: URL!

    override func setUp() {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("todos.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    func testAddTrimsAndRejectsBlank() {
        let store = TodoStore(fileURL: fileURL)
        XCTAssertNil(store.add("   "))
        XCTAssertEqual(store.add("  Buy milk \n")?.title, "Buy milk")
        XCTAssertEqual(store.items.count, 1)
    }

    func testToggleRemoveAndOrdering() {
        let store = TodoStore(fileURL: fileURL)
        let a = store.add("A")!, b = store.add("B")!, c = store.add("C")!
        store.toggle(a.id)
        XCTAssertEqual(store.sortedItems.map(\.title), ["B", "C", "A"])
        XCTAssertEqual(store.remainingCount, 2)
        store.remove(b.id)
        store.clearCompleted()
        XCTAssertEqual(store.items.map(\.id), [c.id])
    }

    func testPersistsAcrossInstances() {
        let store = TodoStore(fileURL: fileURL)
        let item = store.add("Persist me")!
        store.toggle(item.id)
        let reloaded = TodoStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.items, store.items)
        XCTAssertTrue(reloaded.items[0].isDone)
    }
}

final class MeetingScheduleTests: XCTestCase {
    var calendar: Calendar!
    var now: Date!

    override func setUp() {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 14, minute: 0))!
    }

    private func at(_ hour: Int, _ minute: Int = 0, dayOffset: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 23 + dayOffset, hour: hour, minute: minute))!
    }

    private func meeting(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false) -> Meeting {
        Meeting(id: title, title: title, start: start, end: end, isAllDay: allDay)
    }

    func testUpcomingTodayFiltersAndSorts() {
        let meetings = [
            meeting("Later", at(16), at(17)),
            meeting("Finished", at(9), at(10)),
            meeting("Ongoing", at(13, 30), at(14, 30)),
            meeting("All day", at(0), at(0, dayOffset: 1), allDay: true),
            meeting("Tomorrow", at(9, dayOffset: 1), at(10, dayOffset: 1)),
        ]
        let upcoming = MeetingSchedule.upcomingToday(meetings, now: now, calendar: calendar)
        XCTAssertEqual(upcoming.map(\.title), ["Ongoing", "Later"])
    }

    func testStatusLabels() {
        XCTAssertEqual(MeetingSchedule.status(of: meeting("x", at(13, 30), at(14, 30)), now: now).label, "Now · 30m left")
        XCTAssertEqual(MeetingSchedule.status(of: meeting("x", at(14, 5), at(15)), now: now).label, "in 5m")
        XCTAssertEqual(MeetingSchedule.status(of: meeting("x", at(16), at(17)), now: now).label, "in 2h")
        XCTAssertEqual(MeetingSchedule.status(of: meeting("x", at(15, 20), at(16)), now: now).label, "in 1h 20m")
    }

    func testVideoLinkDetection() {
        let zoom = Meeting(id: "1", title: "Sync", start: now, end: now,
                           notes: "Join: https://acme.zoom.us/j/123456?pwd=abc (passcode 1)")
        XCTAssertEqual(zoom.joinURL?.absoluteString, "https://acme.zoom.us/j/123456?pwd=abc")

        let meet = Meeting(id: "2", title: "1:1", start: now, end: now, location: "https://meet.google.com/abc-defg-hij")
        XCTAssertEqual(meet.joinURL?.host, "meet.google.com")

        let none = Meeting(id: "3", title: "Lunch", start: now, end: now, location: "Cafe",
                           notes: "Menu at https://example.com/zoom.us")
        XCTAssertNil(none.joinURL)
    }
}
