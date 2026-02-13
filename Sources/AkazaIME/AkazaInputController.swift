import Cocoa
import InputMethodKit

@objc(AkazaInputController)
class AkazaInputController: IMKInputController {
    private var composedHiragana: String = ""
    private let romajiConverter = RomajiConverter()

    private var hasPreedit: Bool {
        !composedHiragana.isEmpty || !romajiConverter.pendingRomaji.isEmpty
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown else {
            return false
        }
        guard let client = sender as? (any IMKTextInput) else {
            return false
        }

        let keyCode = event.keyCode
        NSLog("AkazaIME: keyCode=\(keyCode) characters=\(event.characters ?? "")")

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
            if hasPreedit { commitText(client: client) }
            return false
        }

        switch keyCode {
        case 36: return handleEnter(client: client)
        case 53: return handleEscape(client: client)
        case 51: return handleBackspace(client: client)
        default: return handleCharacterInput(event: event, client: client)
        }
    }

    private func handleEnter(client: any IMKTextInput) -> Bool {
        guard hasPreedit else { return false }
        commitText(client: client)
        return true
    }

    private func handleEscape(client: any IMKTextInput) -> Bool {
        guard hasPreedit else { return false }
        composedHiragana = ""
        romajiConverter.clear()
        updateMarkedText(client: client)
        return true
    }

    private func handleBackspace(client: any IMKTextInput) -> Bool {
        if romajiConverter.backspace() {
            updateMarkedText(client: client)
            return true
        }
        if !composedHiragana.isEmpty {
            composedHiragana.removeLast()
            updateMarkedText(client: client)
            return true
        }
        return false
    }

    private func handleCharacterInput(event: NSEvent, client: any IMKTextInput) -> Bool {
        guard let characters = event.characters, !characters.isEmpty else {
            return false
        }
        for char in characters {
            let results = romajiConverter.feed(char)
            for result in results {
                switch result {
                case .converted(let hiragana):
                    composedHiragana += hiragana
                case .pending:
                    break
                case .passthrough(let character):
                    if !composedHiragana.isEmpty {
                        commitText(client: client)
                    }
                    client.insertText(
                        String(character),
                        replacementRange: NSRange(location: NSNotFound, length: 0)
                    )
                    return true
                }
            }
        }
        updateMarkedText(client: client)
        return true
    }

    private func commitText(client: any IMKTextInput) {
        var text = composedHiragana
        if let flushed = romajiConverter.flush() {
            text += flushed
        }
        if !text.isEmpty {
            client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        }
        composedHiragana = ""
    }

    private func updateMarkedText(client: any IMKTextInput) {
        let preedit = composedHiragana + romajiConverter.pendingRomaji
        if preedit.isEmpty {
            client.setMarkedText(
                "",
                selectionRange: NSRange(location: 0, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: 0)
            )
        } else {
            client.setMarkedText(
                preedit,
                selectionRange: NSRange(location: preedit.count, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: 0)
            )
        }
    }
}
