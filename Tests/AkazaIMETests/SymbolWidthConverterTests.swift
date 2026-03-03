import XCTest

@testable import AkazaIME

final class SymbolWidthConverterTests: XCTestCase {
    func testNormalizeConvertsASCIISymbolsToFullWidth() {
        let text = "!?/@"

        let normalized = SymbolWidthConverter.normalize(text, style: .fullWidth)

        XCTAssertEqual(normalized, "！？／＠")
    }

    func testNormalizeConvertsFullWidthSymbolsToHalfWidth() {
        let text = "！？／＠"

        let normalized = SymbolWidthConverter.normalize(text, style: .halfWidth)

        XCTAssertEqual(normalized, "!?/@")
    }

    func testNormalizeLeavesNonTargetCharactersUnchanged() {
        let text = "A1あ。「Ａ１！"

        let normalized = SymbolWidthConverter.normalize(text, style: .halfWidth)

        XCTAssertEqual(normalized, "A1あ。「Ａ１!")
    }
}
