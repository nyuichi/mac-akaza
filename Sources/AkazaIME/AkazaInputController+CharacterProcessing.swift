import Cocoa

// MARK: - Character processing helpers

extension AkazaInputController {
    func processCharacter(_ char: Character, scalar: UInt32) {
        if scalar >= 0x41 && scalar <= 0x5A {
            // 大文字 ASCII: 直接入力モードへ移行
            enterDirectInputMode(char)
        } else if isDirectInputMode && scalar >= 0x21 && scalar <= 0x7E {
            // 直接入力モード中の printable ASCII: ローマ字変換せず preedit に積む
            composedHiragana += String(char)
        } else {
            isDirectInputMode = false
            feedToRomajiConverter(char)
        }
    }

    func enterDirectInputMode(_ char: Character) {
        if !isDirectInputMode {
            if let flushed = romajiConverter.flush() {
                composedHiragana += flushed
            }
            isDirectInputMode = true
        }
        composedHiragana += String(char)
    }

    func feedToRomajiConverter(_ char: Character) {
        let results = romajiConverter.feed(char)
        for result in results {
            switch result {
            case .converted(let hiragana):
                composedHiragana += applyPunctuationStyle(hiragana)
            case .pending:
                break
            case .passthrough(let character):
                composedHiragana += String(character)
            }
        }
    }
}
