import XCTest

@testable import AkazaIME

final class SuggestSessionTests: XCTestCase {
    func testNextPathSkipsDuplicateDisplayTexts() {
        var session = SuggestSession(
            originalHiragana: "ab",
            paths: [
                makePath(["ab"]),
                makePath(["a", "b"]),
                makePath(["ac"])
            ]
        )

        session.nextPath()

        XCTAssertEqual(session.selectedPathIndex, 2)
        XCTAssertEqual(session.displayText, "ac")
    }

    func testPreviousPathSkipsDuplicateDisplayTexts() {
        var session = SuggestSession(
            originalHiragana: "ab",
            paths: [
                makePath(["ab"]),
                makePath(["a", "b"]),
                makePath(["ac"])
            ]
        )
        session.selectedPathIndex = 2

        session.previousPath()

        XCTAssertEqual(session.selectedPathIndex, 0)
        XCTAssertEqual(session.displayText, "ab")
    }

    private func makePath(_ surfaces: [String]) -> KBestPath {
        let segments = surfaces.map { surface in
            [ConvertCandidate(surface: surface, yomi: surface, cost: 0)]
        }
        return KBestPath(segments: segments, cost: 0)
    }
}
