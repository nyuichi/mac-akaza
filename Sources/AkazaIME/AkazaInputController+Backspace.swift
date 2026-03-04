import Cocoa
import InputMethodKit

// MARK: - Backspace event handling
extension AkazaInputController {
    func isBackspaceEvent(_ event: NSEvent, keyCode: UInt16) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.contains(.command), !flags.contains(.option) else { return false }
        if keyCode == 51 { return true }
        guard let scalar = event.characters?.unicodeScalars.first?.value else { return false }
        return scalar == 0x08 || scalar == 0x7F
    }

    func handleBackspaceEvent(event: NSEvent, client: any IMKTextInput) -> Bool {
        switch inputState {
        case .composing:
            return handleBackspaceInComposing(client: client)
        case .suggesting:
            return handleSuggestingState(event: event, keyCode: 51, client: client)
        case .converting:
            return handleConvertingState(event: event, keyCode: 51, client: client)
        }
    }

    func handleBackspaceWithoutHistoryInComposing(client: any IMKTextInput) -> Bool {
        if romajiConverter.backspace() {
            updateComposingMarkedText(client: client)
            scheduleSuggest(client: client)
            return true
        }
        guard !composedHiragana.isEmpty else { return false }
        composedHiragana.removeLast()
        updateComposingMarkedText(client: client)
        scheduleSuggest(client: client)
        return true
    }
}
