import CoreGraphics
import XCTest
@testable import IslandCore

final class DotMatrixFontTests: XCTestCase {
    func testAllClockCharactersAre7Rows() {
        for c in "0123456789: " {
            let glyph = DotMatrixFont.glyph(for: c)
            XCTAssertEqual(glyph.count, DotMatrixFont.rows, "glyph \(c)")
            XCTAssertEqual(Set(glyph.map(\.count)).count, 1, "glyph \(c) has ragged rows")
        }
    }

    func testDigitsAreDistinctAndLit() {
        let digits = "0123456789".map { DotMatrixFont.glyph(for: $0) }
        XCTAssertEqual(Set(digits.map { $0.description }).count, 10)
        XCTAssertTrue(digits.allSatisfy { $0.joined().contains(true) })
    }

    func testLettersCoverAlphabetAndAreDistinct() {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { DotMatrixFont.glyph(for: $0) }
        let blank = DotMatrixFont.glyph(for: " ")
        XCTAssertTrue(letters.allSatisfy { $0 != blank && $0.count == 7 && $0.allSatisfy { $0.count == 5 } })
        XCTAssertEqual(Set(letters.map { $0.description }).count, 26)
        XCTAssertEqual(DotMatrixFont.glyph(for: "d"), DotMatrixFont.glyph(for: "D"))
    }

    func testNormalizeFoldsCaseAndAccents() {
        XCTAssertEqual(DotMatrixFont.normalize("São Paulo"), "SAO PAULO")
        XCTAssertEqual(DotMatrixFont.normalize("New Delhi"), "NEW DELHI")
    }

    func testColumns() {
        // 6 digits × 5 + 2 colons × 1 + 7 gaps
        XCTAssertEqual(DotMatrixFont.columns(for: "12:34:56"), 39)
        XCTAssertEqual(DotMatrixFont.columns(for: ""), 0)
        XCTAssertEqual(DotMatrixFont.glyph(for: "?"), DotMatrixFont.glyph(for: " "))
    }
}

final class NotchGeometryTests: XCTestCase {
    func testNotchRectFromAuxiliaryAreas() {
        // 14" MacBook Pro default resolution.
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let rect = NotchGeometry.notchRect(screenFrame: screen, leftAreaWidth: 663, rightAreaWidth: 664, topInset: 32)
        XCTAssertEqual(rect.width, 185)
        XCTAssertEqual(rect.height, 32)
        XCTAssertEqual(rect.maxY, 982)
        XCTAssertEqual(rect.midX, 756)
    }

    func testFallbackWithoutNotch() {
        let screen = CGRect(x: 1512, y: 0, width: 2560, height: 1440)
        let rect = NotchGeometry.notchRect(screenFrame: screen, leftAreaWidth: nil, rightAreaWidth: nil, topInset: 0)
        XCTAssertEqual(rect.size, NotchGeometry.fallbackNotchSize)
        XCTAssertEqual(rect.midX, screen.midX)
        XCTAssertEqual(rect.maxY, screen.maxY)
    }

    func testTopCenteredRect() {
        let notch = CGRect(x: 663, y: 950, width: 185, height: 32)
        let rect = NotchGeometry.topCenteredRect(size: CGSize(width: 480, height: 190), under: notch)
        XCTAssertEqual(rect.midX, notch.midX)
        XCTAssertEqual(rect.maxY, notch.maxY)
        XCTAssertEqual(rect.height, 190)
    }
}

final class DotMatrixIconTests: XCTestCase {
    func testIconsAreSquareAndDistinct() {
        for icon in DotMatrixIcon.allCases {
            XCTAssertEqual(icon.dots.count, DotMatrixIcon.size, "\(icon)")
            XCTAssertTrue(icon.dots.allSatisfy { $0.count == DotMatrixIcon.size }, "\(icon)")
        }
        XCTAssertEqual(Set(DotMatrixIcon.allCases.map { $0.dots.description }).count, DotMatrixIcon.allCases.count)
    }
}
