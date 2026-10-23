import XCTest
@testable import IslandCore

final class WorldClockTests: XCTestCase {
    let berlin = TimeZone(identifier: "Europe/Berlin")!
    let kolkata = TimeZone(identifier: "Asia/Kolkata")!
    let newYork = TimeZone(identifier: "America/New_York")!

    /// 2026-10-23 20:15:09 UTC
    let date = Date(timeIntervalSince1970: 1_792_786_509)

    func testTimeStringIs24Hour() {
        XCTAssertEqual(WorldClock.timeString(date, in: TimeZone(identifier: "UTC")!), "20:15")
        XCTAssertEqual(WorldClock.timeString(date, in: newYork, showSeconds: true), "16:15:09")
    }

    func testHalfHourOffset() {
        // Summer time in Berlin (UTC+2) vs India (UTC+5:30).
        XCTAssertEqual(WorldClock.offsetDescription(from: berlin, to: kolkata, at: date), "+3h 30m")
        XCTAssertEqual(WorldClock.offsetDescription(from: kolkata, to: berlin, at: date), "-3h 30m")
        XCTAssertEqual(WorldClock.offsetDescription(from: berlin, to: berlin, at: date), "Same time")
        XCTAssertEqual(WorldClock.offsetDescription(from: berlin, to: newYork, at: date), "-6h")
    }

    func testOffsetFollowsDaylightSaving() {
        // 2026-12-15 12:00 UTC: Berlin back on UTC+1, so India is +4h 30m.
        let winter = Date(timeIntervalSince1970: 1_797_336_000)
        XCTAssertEqual(WorldClock.offsetDescription(from: berlin, to: kolkata, at: winter), "+4h 30m")
    }

    func testDayRelationAcrossMidnight() {
        // 20:15 UTC = 22:15 Berlin, 01:45 next day in Kolkata, 16:15 in New York.
        XCTAssertEqual(WorldClock.dayRelation(at: date, local: berlin, remote: kolkata), .tomorrow)
        XCTAssertEqual(WorldClock.dayRelation(at: date, local: berlin, remote: newYork), .today)
        XCTAssertEqual(WorldClock.dayRelation(at: date, local: kolkata, remote: berlin), .yesterday)
    }

    func testDisplayName() {
        XCTAssertEqual(WorldClock.displayName(forTimeZoneID: "America/New_York"), "New York")
        XCTAssertEqual(WorldClock.displayName(forTimeZoneID: "UTC"), "UTC")
    }

    func testCitySearchFindsNewDelhiAlias() {
        let results = CitySearch.search("delhi")
        XCTAssertEqual(results.first, .newDelhi)
    }

    func testCitySearchPrefixFirstAndNoDuplicates() {
        let results = CitySearch.search("lon", identifiers: ["Europe/London", "America/Barcelona_Lon", "Europe/London"])
        XCTAssertEqual(results.map(\.name), ["London", "Barcelona Lon"])
        XCTAssertTrue(CitySearch.search("   ").isEmpty)
    }

    func testCityIdsDistinguishSharedZones() {
        XCTAssertNotEqual(City.newDelhi.id, City(name: "Mumbai", timeZoneID: "Asia/Kolkata").id)
    }
}
