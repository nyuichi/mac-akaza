import XCTest

@testable import AkazaIME

final class RomajiConverterShiftKatakanaTests: XCTestCase {
    private let testMapping: [String: String] = [
        "ka": "か",
        "na": "な",
        "n": "ん"
    ]

    func testAllShiftSequenceBecomesKatakanaWhenEnabled() {
        let converter = RomajiConverter(mapping: testMapping)

        _ = converter.feed("K", isShiftPressed: true, shiftKatakanaEnabled: true)
        let results = converter.feed("A", isShiftPressed: true, shiftKatakanaEnabled: true)

        XCTAssertEqual(firstConverted(from: results), "カ")
    }

    func testLowercaseSequenceStaysHiraganaWhenEnabled() {
        let converter = RomajiConverter(mapping: testMapping)

        _ = converter.feed("k", isShiftPressed: false, shiftKatakanaEnabled: true)
        let results = converter.feed("a", isShiftPressed: false, shiftKatakanaEnabled: true)

        XCTAssertEqual(firstConverted(from: results), "か")
    }

    func testMixedShiftSequenceStaysHiraganaWhenEnabled() {
        let converter1 = RomajiConverter(mapping: testMapping)
        _ = converter1.feed("K", isShiftPressed: true, shiftKatakanaEnabled: true)
        let results1 = converter1.feed("a", isShiftPressed: false, shiftKatakanaEnabled: true)
        XCTAssertEqual(firstConverted(from: results1), "か")

        let converter2 = RomajiConverter(mapping: testMapping)
        _ = converter2.feed("k", isShiftPressed: false, shiftKatakanaEnabled: true)
        let results2 = converter2.feed("A", isShiftPressed: true, shiftKatakanaEnabled: true)
        XCTAssertEqual(firstConverted(from: results2), "か")
    }

    func testShiftedSequenceStaysHiraganaWhenSettingDisabled() {
        let converter = RomajiConverter(mapping: testMapping)

        _ = converter.feed("K", isShiftPressed: true, shiftKatakanaEnabled: false)
        let results = converter.feed("A", isShiftPressed: true, shiftKatakanaEnabled: false)

        XCTAssertEqual(firstConverted(from: results), "か")
    }

    func testFlushNRespectsShiftKatakana() {
        let shiftedConverter = RomajiConverter(mapping: testMapping)
        _ = shiftedConverter.feed("N", isShiftPressed: true, shiftKatakanaEnabled: true)
        XCTAssertEqual(shiftedConverter.flush(shiftKatakanaEnabled: true), "ン")

        let plainConverter = RomajiConverter(mapping: testMapping)
        _ = plainConverter.feed("n", isShiftPressed: false, shiftKatakanaEnabled: true)
        XCTAssertEqual(plainConverter.flush(shiftKatakanaEnabled: true), "ん")
    }

    func testSetStateRestoresShiftHistory() {
        let converter = RomajiConverter(mapping: testMapping)

        _ = converter.feed("K", isShiftPressed: true, shiftKatakanaEnabled: true)
        let snapshotBuffer = converter.pendingRomaji
        let snapshotShiftStates = converter.pendingShiftStates

        converter.clear()
        converter.setState(buffer: snapshotBuffer, shiftStates: snapshotShiftStates)

        let results = converter.feed("A", isShiftPressed: true, shiftKatakanaEnabled: true)
        XCTAssertEqual(firstConverted(from: results), "カ")
    }

    private func firstConverted(from results: [ConversionResult]) -> String? {
        for result in results {
            if case .converted(let value) = result {
                return value
            }
        }
        return nil
    }
}
