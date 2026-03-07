import XCTest

@testable import AkazaIME

final class CandidateWindowVisibilityPolicyTests: XCTestCase {
    func testShowPredictiveCandidatesDisplaysWindowForAllTriggers() {
        let policy = CandidateWindowVisibilityPolicy(showPredictiveCandidates: true)

        XCTAssertTrue(policy.shouldShowWindow(for: .composingSuggestion))
        XCTAssertTrue(policy.shouldShowWindow(for: .conversionStarted))
        XCTAssertTrue(policy.shouldShowWindow(for: .conversionNavigation))
    }

    func testHidingPredictiveCandidatesStillShowsWindowDuringConversionNavigation() {
        let policy = CandidateWindowVisibilityPolicy(showPredictiveCandidates: false)

        XCTAssertFalse(policy.shouldShowWindow(for: .composingSuggestion))
        XCTAssertFalse(policy.shouldShowWindow(for: .conversionStarted))
        XCTAssertTrue(policy.shouldShowWindow(for: .conversionNavigation))
    }
}
