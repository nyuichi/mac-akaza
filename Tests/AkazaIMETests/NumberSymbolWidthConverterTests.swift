import XCTest

@testable import AkazaIME

final class NumberSymbolWidthConverterTests: XCTestCase {
    func testNormalizeConvertsASCIINumbersAndSymbolsToFullWidth() {
        let text = "123!?/@"

        let normalized = NumberSymbolWidthConverter.normalize(text, style: .fullWidth)

        XCTAssertEqual(normalized, "１２３！？／＠")
    }

    func testNormalizeConvertsFullWidthNumbersAndSymbolsToHalfWidth() {
        let text = "１２３！？／＠"

        let normalized = NumberSymbolWidthConverter.normalize(text, style: .halfWidth)

        XCTAssertEqual(normalized, "123!?/@")
    }

    func testNormalizeLeavesNonTargetCharactersUnchanged() {
        let text = "Azあ。「Ａｚあ。"

        let normalized = NumberSymbolWidthConverter.normalize(text, style: .halfWidth)

        XCTAssertEqual(normalized, "Azあ。「Ａｚあ。")
    }
}
