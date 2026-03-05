import Cocoa
import InputMethodKit
import XCTest

@testable import AkazaIME

final class BackspaceHandlingTests: XCTestCase {
    // Ctrl+Backspace（keyCode=51, chars=0x7F）を composing 中にバックスペースとして処理する
    func testControlModifiedBackspaceIsHandledAsBackspaceInComposing() {
        assertBackspaceHandledInComposing(characters: "\u{7F}", keyCode: 51)
    }

    // Ctrl+H（keyCode=4, chars=0x08）を composing 中にバックスペースとして処理する
    func testCtrlHCharacterIsHandledAsBackspaceInComposing() {
        assertBackspaceHandledInComposing(characters: "\u{08}", keyCode: 4)
    }

    // converting 中に backspace を押すと最後の1文字だけ削除されて composing に戻る
    func testBackspaceInConvertingDeletesOnlyLastCharacter() {
        let client = MockTextInput()
        guard let controller = AkazaInputController(server: nil, delegate: nil, client: nil) else {
            XCTFail("AkazaInputController の生成に失敗しました")
            return
        }

        controller.inputState = .converting(makeConversionSession(original: "pq"))
        controller.latestSuggestYomi = "p"

        let backspace = makeKeyDownEvent(characters: "\u{7F}", keyCode: 51)
        let handledBackspace = controller.handle(backspace, client: client)

        XCTAssertTrue(handledBackspace)
        XCTAssertEqual(controller.inputStateDescription, "composing")
        XCTAssertEqual(controller.composedHiragana, "p")
        // 空文字がコミットされていないこと（issue #60 の再発防止）
        XCTAssertEqual(client.insertedTexts.count, 0)
    }

    // ひらがな・ASCII 混在の originalHiragana でも末尾1文字が正しく削除される
    func testBackspaceInConvertingHandlesMixedText() {
        let client = MockTextInput()
        guard let controller = AkazaInputController(server: nil, delegate: nil, client: nil) else {
            XCTFail("AkazaInputController の生成に失敗しました")
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

    // Cmd+Backspace は IME が処理せず preedit をコミットしてシステムに渡す
    func testCmdBackspaceCommitsPreeditAndPassesToSystem() {
        let client = MockTextInput()
        guard let controller = AkazaInputController(server: nil, delegate: nil, client: nil) else {
            XCTFail("AkazaInputController の生成に失敗しました")
            return
        }

        controller.inputState = .composing
        controller.composedHiragana = "あ"

        let event = makeKeyDownEvent(characters: "\u{7F}", keyCode: 51, flags: [.command])
        let handled = controller.handle(event, client: client)

        // IME は処理しない
        XCTAssertFalse(handled)
        // preedit はコミットされる
        XCTAssertEqual(client.insertedTexts, ["あ"])
    }

    // Option+Backspace は IME が処理せず preedit をコミットしてシステムに渡す
    func testOptionBackspaceCommitsPreeditAndPassesToSystem() {
        let client = MockTextInput()
        guard let controller = AkazaInputController(server: nil, delegate: nil, client: nil) else {
            XCTFail("AkazaInputController の生成に失敗しました")
            return
        }

        controller.inputState = .composing
        controller.composedHiragana = "あ"

        let event = makeKeyDownEvent(characters: "\u{7F}", keyCode: 51, flags: [.option])
        let handled = controller.handle(event, client: client)

        // IME は処理しない
        XCTAssertFalse(handled)
        // preedit はコミットされる
        XCTAssertEqual(client.insertedTexts, ["あ"])
    }

    // converting → composing に戻った後、続けて backspace を押すと
    // inputHistory なしのパス（handleBackspaceWithoutHistoryInComposing）で1文字削除される
    func testBackspaceAfterReturningFromConverting() {
        let client = MockTextInput()
        guard let controller = AkazaInputController(server: nil, delegate: nil, client: nil) else {
            XCTFail("AkazaInputController の生成に失敗しました")
            return
        }

        controller.inputState = .converting(makeConversionSession(original: "ab"))

        let backspace = makeKeyDownEvent(characters: "\u{7F}", keyCode: 51)

        // 1回目: converting → composing、末尾 "b" を削除
        XCTAssertTrue(controller.handle(backspace, client: client))
        XCTAssertEqual(controller.inputStateDescription, "composing")
        XCTAssertEqual(controller.composedHiragana, "a")

        // 2回目: inputHistory が空 → handleBackspaceWithoutHistoryInComposing が動作し "a" を削除
        XCTAssertTrue(controller.handle(backspace, client: client))
        XCTAssertEqual(controller.composedHiragana, "")
        XCTAssertEqual(client.insertedTexts.count, 0)
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
            XCTFail("AkazaInputController の生成に失敗しました")
            return
        }

        controller.inputState = .composing
        controller.composedHiragana = "x"
        controller.inputHistory = [
            ComposingSnapshot(composedHiragana: "", romajiBuffer: "", romajiShiftStates: [])
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
