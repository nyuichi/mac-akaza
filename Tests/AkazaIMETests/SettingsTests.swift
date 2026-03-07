import Foundation
import XCTest

@testable import AkazaIME

final class SettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "SettingsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testShowPredictiveCandidatesDefaultsToTrue() {
        let settings = Settings(defaults: defaults)

        XCTAssertTrue(settings.showPredictiveCandidates)
    }

    func testShowPredictiveCandidatesPersistsFalseAndTrueValues() {
        let settings = Settings(defaults: defaults)

        settings.showPredictiveCandidates = false
        XCTAssertFalse(Settings(defaults: defaults).showPredictiveCandidates)

        settings.showPredictiveCandidates = true
        XCTAssertTrue(Settings(defaults: defaults).showPredictiveCandidates)
    }

    func testNumberSymbolStyleDefaultsToFullWidth() {
        let settings = Settings(defaults: defaults)

        XCTAssertEqual(settings.numberSymbolStyle, .fullWidth)
    }

    func testNumberSymbolStylePersistsSelectedValue() {
        let settings = Settings(defaults: defaults)

        settings.numberSymbolStyle = .halfWidth

        XCTAssertEqual(Settings(defaults: defaults).numberSymbolStyle, .halfWidth)
        XCTAssertEqual(defaults.integer(forKey: "numberSymbolStyle"), NumberSymbolStyle.halfWidth.rawValue)
    }
}
