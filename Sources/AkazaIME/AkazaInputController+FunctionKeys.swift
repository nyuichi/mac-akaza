import Cocoa
import InputMethodKit

struct FunctionKeyState {
    let originalHiragana: String
    let originalRawRomajiInput: String
    var displayText: String
}

// MARK: - Function key handling (F6-F10)
extension AkazaInputController {
    static func isFunctionKey(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case 97, 98, 100, 101, 109: // F6, F7, F8, F9, F10
            return true
        default:
            return false
        }
    }

    func handleFunctionKeyFromAnyState(keyCode: UInt16, client: any IMKTextInput) -> Bool {
        let hiragana: String
        let romaji: String
        if let fkState = functionKeyState {
            hiragana = fkState.originalHiragana
            romaji = fkState.originalRawRomajiInput
        } else {
            romaji = rawRomajiInput
            switch inputState {
            case .composing:
                var text = composedHiragana
                if let flushed = romajiConverter.flush() { text += flushed }
                hiragana = text
            case .suggesting(let session):
                hiragana = session.originalHiragana
            case .converting(let session):
                hiragana = session.originalHiragana
            }
        }

        guard !hiragana.isEmpty else { return true }

        let converted: String
        switch keyCode {
        case 97: // F6: ひらがな
            converted = hiragana
        case 98: // F7: カタカナ（全角）
            converted = hiragana.toKatakana()
        case 100: // F8: 半角カタカナ
            converted = hiragana.toHalfWidthKatakana()
        case 101: // F9: 全角英数
            converted = romaji.toFullWidthRomaji()
        case 109: // F10: 半角英数
            converted = romaji
        default:
            return false
        }

        guard !converted.isEmpty else { return true }

        resetToComposing()
        functionKeyState = FunctionKeyState(originalHiragana: hiragana, originalRawRomajiInput: romaji, displayText: converted)
        updateComposingMarkedText(client: client)
        return true
    }

    func commitFunctionKeyState(client: any IMKTextInput) {
        guard let fkState = functionKeyState else { return }
        client.insertText(fkState.displayText, replacementRange: NSRange(location: NSNotFound, length: 0))
        resetToComposing()
    }

    func handleEscapeInFunctionKey(client: any IMKTextInput) -> Bool {
        guard let fkState = functionKeyState else { return false }
        functionKeyState = nil
        composedHiragana = fkState.originalHiragana
        rawRomajiInput = fkState.originalRawRomajiInput
        updateComposingMarkedText(client: client)
        scheduleSuggest(client: client)
        return true
    }
}

// MARK: - String conversion helpers
extension String {
    func toKatakana() -> String {
        self.applyingTransform(.hiraganaToKatakana, reverse: false) ?? self
    }

    func toHalfWidthKatakana() -> String {
        let katakana = self.toKatakana()
        return katakana.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? katakana
    }

    func toFullWidthRomaji() -> String {
        self.applyingTransform(.fullwidthToHalfwidth, reverse: true) ?? self
    }
}
