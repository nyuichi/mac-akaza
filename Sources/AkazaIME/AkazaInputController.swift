import Cocoa
import InputMethodKit

@objc(AkazaInputController)
class AkazaInputController: IMKInputController {
    var composedHiragana: String = ""
    let romajiConverter = RomajiConverter()
    var inputState: InputState = .composing
    static let candidateWindow = CandidateWindowController()

    var hasPreedit: Bool {
        switch inputState {
        case .composing:
            return !composedHiragana.isEmpty || !romajiConverter.pendingRomaji.isEmpty
        case .converting:
            return true
        }
    }

    // MARK: - Main event handler

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
            if hasPreedit { commitCurrentState(client: client) }
            return false
        }

        switch inputState {
        case .composing:
            return handleComposingState(event: event, keyCode: keyCode, client: client)
        case .converting:
            return handleConvertingState(event: event, keyCode: keyCode, client: client)
        }
    }

    // MARK: - Composing state

    private func handleComposingState(event: NSEvent, keyCode: UInt16, client: any IMKTextInput) -> Bool {
        switch keyCode {
        case 49: // Space
            return handleSpaceInComposing(client: client)
        case 36: // Enter
            return handleEnterInComposing(client: client)
        case 53: // Escape
            return handleEscapeInComposing(client: client)
        case 51: // Backspace
            return handleBackspaceInComposing(client: client)
        default:
            return handleCharacterInput(event: event, client: client)
        }
    }

    private func handleSpaceInComposing(client: any IMKTextInput) -> Bool {
        guard hasPreedit else {
            return false
        }

        var text = composedHiragana
        if let flushed = romajiConverter.flush() {
            text += flushed
        }
        guard !text.isEmpty else { return false }

        guard let result = akazaClient.convertSync(yomi: text), !result.isEmpty else {
            composedHiragana = text
            updateComposingMarkedText(client: client)
            return true
        }

        let session = ConversionSession(originalHiragana: text, clauses: result)
        inputState = .converting(session)
        composedHiragana = ""
        updateConvertingMarkedText(client: client)
        showCandidateWindow(client: client)
        return true
    }

    private func handleEnterInComposing(client: any IMKTextInput) -> Bool {
        guard hasPreedit else { return false }

        var text = composedHiragana
        if let flushed = romajiConverter.flush() {
            text += flushed
        }
        guard !text.isEmpty else {
            composedHiragana = ""
            return true
        }

        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        composedHiragana = ""
        return true
    }

    private func handleEscapeInComposing(client: any IMKTextInput) -> Bool {
        guard hasPreedit else { return false }
        composedHiragana = ""
        romajiConverter.clear()
        updateComposingMarkedText(client: client)
        return true
    }

    private func handleBackspaceInComposing(client: any IMKTextInput) -> Bool {
        if romajiConverter.backspace() {
            updateComposingMarkedText(client: client)
            return true
        }
        if !composedHiragana.isEmpty {
            composedHiragana.removeLast()
            updateComposingMarkedText(client: client)
            return true
        }
        return false
    }

    func handleCharacterInput(event: NSEvent, client: any IMKTextInput) -> Bool {
        guard let characters = event.characters, !characters.isEmpty else {
            return false
        }
        for char in characters {
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
        updateComposingMarkedText(client: client)
        return true
    }

    // MARK: - Commit helpers

    func commitCurrentState(client: any IMKTextInput) {
        switch inputState {
        case .composing:
            commitComposingText(client: client)
        case .converting:
            commitConvertingText(client: client)
        }
    }

    func commitComposingText(client: any IMKTextInput) {
        var text = composedHiragana
        if let flushed = romajiConverter.flush() {
            text += flushed
        }
        guard !text.isEmpty else {
            composedHiragana = ""
            return
        }
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        composedHiragana = ""
    }

    func commitConvertingText(client: any IMKTextInput) {
        guard case .converting(let session) = inputState else { return }
        let text = session.committedText
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        akazaClient.learnSync(candidates: session.selectedCandidates)
        resetToComposing()
    }

    func resetToComposing() {
        inputState = .composing
        composedHiragana = ""
        romajiConverter.clear()
        Self.candidateWindow.hide()
    }

    // MARK: - Punctuation style

    private func applyPunctuationStyle(_ text: String) -> String {
        guard Settings.shared.punctuationStyle == .commaPeriod else { return text }
        return text.replacingOccurrences(of: "。", with: "．").replacingOccurrences(of: "、", with: "，")
    }

    // MARK: - Menu

    override func menu() -> NSMenu! {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "設定...", action: #selector(openSettings(_:)), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        return menu
    }

    @objc func openSettings(_ sender: Any?) {
        PreferencesWindowController.shared.showWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - IMKInputController overrides

    override func deactivateServer(_ sender: Any!) {
        if let client = sender as? (any IMKTextInput) {
            if hasPreedit {
                commitCurrentState(client: client)
            }
        }
        resetToComposing()
        super.deactivateServer(sender)
    }
}
