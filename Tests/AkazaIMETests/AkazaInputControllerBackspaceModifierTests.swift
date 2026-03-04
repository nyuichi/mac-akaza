import Cocoa
import InputMethodKit
import XCTest

@testable import AkazaIME

final class AkazaInputControllerBackspaceModifierTests: XCTestCase {
    func testControlModifiedBackspaceIsHandledAsBackspaceInComposing() {
        assertBackspaceHandledInComposing(characters: "\u{7F}", keyCode: 51)
    }

    func testCtrlHCharacterIsHandledAsBackspaceInComposing() {
        assertBackspaceHandledInComposing(characters: "\u{08}", keyCode: 4)
    }

    func testBackspaceInConvertingDeletesOnlyLastCharacter() {
        let client = MockTextInput()
        guard let controller = AkazaInputController(server: nil, delegate: nil, client: nil) else {
            XCTFail("failed to create AkazaInputController")
            return
        }

        controller.inputState = .converting(makeConversionSession(original: "pq"))
        controller.latestSuggestYomi = "p"

        let backspace = makeKeyDownEvent(characters: "\u{7F}", keyCode: 51)
        let handledBackspace = controller.handle(backspace, client: client)

        XCTAssertTrue(handledBackspace)
        XCTAssertEqual(controller.inputStateDescription, "composing")
        XCTAssertEqual(controller.composedHiragana, "p")
        XCTAssertEqual(client.insertedTexts.count, 0)
    }

    func testBackspaceInConvertingHandlesMixedText() {
        let client = MockTextInput()
        guard let controller = AkazaInputController(server: nil, delegate: nil, client: nil) else {
            XCTFail("failed to create AkazaInputController")
            return
        }

        controller.inputState = .converting(makeConversionSession(original: "lえd"))
        controller.latestSuggestYomi = "lえ"

        let backspace = makeKeyDownEvent(characters: "\u{7F}", keyCode: 51)
        let handled = controller.handle(backspace, client: client)

        XCTAssertTrue(handled)
        XCTAssertEqual(controller.inputStateDescription, "composing")
        XCTAssertEqual(controller.composedHiragana, "lえ")
    }

    private func makeConversionSession(original: String) -> ConversionSession {
        let clauses = original.map { character in
            [ConvertCandidate(surface: String(character), yomi: String(character), cost: 0)]
        }
        return ConversionSession(originalHiragana: original, clauses: clauses)
    }

    private func assertBackspaceHandledInComposing(characters: String, keyCode: UInt16) {
        let client = MockTextInput()
        guard let controller = AkazaInputController(server: nil, delegate: nil, client: nil) else {
            XCTFail("failed to create AkazaInputController")
            return
        }

        controller.inputState = .composing
        controller.composedHiragana = "x"
        controller.inputHistory = [
            ComposingSnapshot(
                composedHiragana: "",
                romajiBuffer: "",
                romajiShiftStates: []
            )
        ]

        let event = makeKeyDownEvent(
            characters: characters,
            keyCode: keyCode,
            flags: [.control]
        )
        let handled = controller.handle(event, client: client)

        XCTAssertTrue(handled)
        XCTAssertEqual(controller.composedHiragana, "")
        XCTAssertEqual(client.insertedTexts.count, 0)
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

private extension InputState {
    var description: String {
        switch self {
        case .composing:
            return "composing"
        case .suggesting:
            return "suggesting"
        case .converting:
            return "converting"
        }
    }
}

private extension AkazaInputController {
    var inputStateDescription: String { inputState.description }
}

private final class MockTextInput: NSObject, IMKTextInput {
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
