import Cocoa
import InputMethodKit
import XCTest

@testable import AkazaIME

final class CandidateNavigationTests: XCTestCase {
    func testSpaceInConvertingAdvancesToNextVisibleCandidate() {
        let client = CandidateNavigationMockTextInput()
        guard let controller = AkazaInputController(server: nil, delegate: nil, client: nil) else {
            XCTFail("AkazaInputController could not be created")
            return
        }

        controller.inputState = .converting(
            makeConversionSession(
                original: "alpha",
                surfaces: ["alpha", "alpha", "beta"]
            )
        )

        let handled = controller.handle(makeKeyDownEvent(characters: " ", keyCode: 49), client: client)

        XCTAssertTrue(handled)
        XCTAssertEqual(selectedSurface(in: controller.inputState), "beta")
    }

    func testUpArrowInConvertingMovesToPreviousVisibleCandidate() {
        let client = CandidateNavigationMockTextInput()
        guard let controller = AkazaInputController(server: nil, delegate: nil, client: nil) else {
            XCTFail("AkazaInputController could not be created")
            return
        }

        var session = makeConversionSession(
            original: "alpha",
            surfaces: ["alpha", "alpha", "beta"]
        )
        session.selectedCandidateIndices[0] = 2
        controller.inputState = .converting(session)

        let handled = controller.handle(makeKeyDownEvent(characters: "", keyCode: 126), client: client)

        XCTAssertTrue(handled)
        XCTAssertEqual(selectedSurface(in: controller.inputState), "alpha")
    }

    func testDisplayedCandidateSelectionUsesVisiblePageIndex() {
        var session = makeConversionSession(
            original: "page",
            surfaces: ["a", "b", "c", "d", "e", "f", "g", "g", "h", "i", "j"]
        )
        session.selectedCandidateIndices[0] = 9
        let pageSize = 9
        let currentPage = session.focusedDisplaySelectedIndex / pageSize
        let displayIndex = currentPage * pageSize + (9 - 1)

        XCTAssertTrue(session.selectDisplayedCandidate(at: displayIndex))
        XCTAssertEqual(session.selectedCandidates.first?.surface, "i")
    }

    private func makeConversionSession(original: String, surfaces: [String]) -> ConversionSession {
        let clauses = [
            surfaces.map { surface in
                ConvertCandidate(surface: surface, yomi: original, cost: 0)
            }
        ]
        return ConversionSession(originalHiragana: original, clauses: clauses)
    }

    private func selectedSurface(in state: InputState) -> String? {
        guard case .converting(let session) = state else { return nil }
        return session.selectedCandidates.first?.surface
    }

    private func makeKeyDownEvent(
        characters: String,
        keyCode: UInt16,
        flags: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        ) else {
            fatalError("failed to create NSEvent")
        }
        return event
    }
}

private final class CandidateNavigationMockTextInput: NSObject, IMKTextInput {
    var insertedTexts: [String] = []

    func insertText(_ string: Any!, replacementRange: NSRange) {
        if let attributed = string as? NSAttributedString {
            insertedTexts.append(attributed.string)
            return
        }
        if let text = string as? String {
            insertedTexts.append(text)
            return
        }
        insertedTexts.append(String(describing: string))
    }

    func setMarkedText(_ string: Any!, selectionRange: NSRange, replacementRange: NSRange) {}
    func selectedRange() -> NSRange { NSRange(location: 0, length: 0) }
    func markedRange() -> NSRange { NSRange(location: NSNotFound, length: 0) }
    func attributedSubstring(from range: NSRange) -> NSAttributedString! { nil }
    func length() -> Int { 0 }
    func characterIndex(
        for point: NSPoint,
        tracking mappingMode: IMKLocationToOffsetMappingMode,
        inMarkedRange: UnsafeMutablePointer<ObjCBool>!
    ) -> Int { 0 }
    func attributes(
        forCharacterIndex index: Int,
        lineHeightRectangle lineRect: UnsafeMutablePointer<NSRect>!
    ) -> [AnyHashable: Any]! { [:] }
    func validAttributesForMarkedText() -> [Any]! { [] }
    func overrideKeyboard(withKeyboardNamed keyboardUniqueName: String!) {}
    func selectMode(_ modeIdentifier: String!) {}
    func supportsUnicode() -> Bool { true }
    func bundleIdentifier() -> String! { "test.client" }
    func windowLevel() -> CGWindowLevel { 0 }
    func supportsProperty(_ property: TSMDocumentPropertyTag) -> Bool { false }
    func uniqueClientIdentifierString() -> String! { "test-client" }
    func string(from range: NSRange, actualRange: NSRangePointer!) -> String! { nil }
    func firstRect(forCharacterRange aRange: NSRange, actualRange: NSRangePointer!) -> NSRect { .zero }
}
