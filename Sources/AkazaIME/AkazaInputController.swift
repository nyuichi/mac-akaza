import Cocoa
import InputMethodKit

struct ComposingSnapshot {
    let composedHiragana: String
    let romajiBuffer: String
    let romajiShiftStates: [Bool]
}

@objc(AkazaInputController)
class AkazaInputController: IMKInputController {
    var composedHiragana: String = ""
    let romajiConverter = RomajiConverter()
    var inputState: InputState = .composing
    static let candidateWindow = CandidateWindowController()
    var inputHistory: [ComposingSnapshot] = []

    var pendingSuggestRequestID: Int?
    var latestSuggestYomi: String?

    var candidateWindowVisibilityPolicy: CandidateWindowVisibilityPolicy {
        CandidateWindowVisibilityPolicy(
            showOnlyAfterSecondSpace: Settings.shared.showCandidateWindowAfterSecondSpace
        )
    }

    var hasPreedit: Bool {
        switch inputState {
        case .composing:
            return !composedHiragana.isEmpty || !romajiConverter.pendingRomaji.isEmpty
        case .suggesting:
            return true
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

        if isBackspaceEvent(event, keyCode: keyCode) {
            switch inputState {
            case .composing:
                return handleBackspaceInComposing(client: client)
            case .suggesting:
                return handleSuggestingState(event: event, keyCode: 51, client: client)
            case .converting:
                return handleConvertingState(event: event, keyCode: 51, client: client)
            }
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
            if hasPreedit { commitCurrentState(client: client) }
            return false
        }

        switch inputState {
        case .composing:
            return handleComposingState(event: event, keyCode: keyCode, client: client)
        case .suggesting:
            return handleSuggestingState(event: event, keyCode: keyCode, client: client)
        case .converting:
            return handleConvertingState(event: event, keyCode: keyCode, client: client)
        }
    }

    private func isBackspaceEvent(_ event: NSEvent, keyCode: UInt16) -> Bool {
        if keyCode == 51 { return true }
        guard let scalar = event.characters?.unicodeScalars.first?.value else { return false }
        return scalar == 0x08 || scalar == 0x7F
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
        case 123, 124, 125, 126: // Arrow keys (Left, Right, Down, Up)
            // If we have preedit, consume the arrow key without doing anything
            // If no preedit, let the system handle it (return false)
            return hasPreedit
        default:
            return handleCharacterInput(event: event, client: client)
        }
    }

    private func handleSpaceInComposing(client: any IMKTextInput) -> Bool {
        guard hasPreedit else {
            return false
        }

        var text = composedHiragana
        if let flushed = romajiConverter.flush(shiftKatakanaEnabled: Settings.shared.shiftKatakanaInputEnabled) {
            text += flushed
        }
        guard !text.isEmpty else { return false }

        guard let result = akazaClient.convertSync(yomi: text), !result.isEmpty else {
            composedHiragana = text
            clearInputHistory()
            updateComposingMarkedText(client: client)
            Self.candidateWindow.hide()
            return true
        }

        let session = ConversionSession(originalHiragana: text, clauses: result)
        inputState = .converting(session)
        composedHiragana = ""
        clearInputHistory()
        updateConvertingMarkedText(client: client)
        updateConversionCandidateWindow(client: client, trigger: .conversionStarted)
        return true
    }

    private func handleEnterInComposing(client: any IMKTextInput) -> Bool {
        guard hasPreedit else { return false }

        var text = composedHiragana
        if let flushed = romajiConverter.flush(shiftKatakanaEnabled: Settings.shared.shiftKatakanaInputEnabled) {
            text += flushed
        }
        guard !text.isEmpty else {
            composedHiragana = ""
            clearInputHistory()
            Self.candidateWindow.hide()
            return true
        }

        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        composedHiragana = ""
        clearInputHistory()
        Self.candidateWindow.hide()
        return true
    }

    private func handleEscapeInComposing(client: any IMKTextInput) -> Bool {
        guard hasPreedit else { return false }
        composedHiragana = ""
        romajiConverter.clear()
        clearInputHistory()
        updateComposingMarkedText(client: client)
        return true
    }

    func handleBackspaceInComposing(client: any IMKTextInput) -> Bool {
        guard !inputHistory.isEmpty else {
            return handleBackspaceWithoutHistoryInComposing(client: client)
        }

        // Skip snapshots with non-empty romajiBuffer to treat multi-key romaji sequences
        // (e.g. "ge" → "げ") as a single character for backspace purposes.
        var snapshot: ComposingSnapshot
        repeat {
            snapshot = inputHistory.removeLast()
        } while !snapshot.romajiBuffer.isEmpty && !inputHistory.isEmpty

        composedHiragana = snapshot.composedHiragana
        romajiConverter.setState(
            buffer: snapshot.romajiBuffer,
            shiftStates: snapshot.romajiShiftStates
        )
        updateComposingMarkedText(client: client)
        scheduleSuggest(client: client)
        return true
    }

    private func handleBackspaceWithoutHistoryInComposing(client: any IMKTextInput) -> Bool {
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

    func handleCharacterInput(event: NSEvent, client: any IMKTextInput) -> Bool {
        guard let characters = event.characters, !characters.isEmpty else {
            return false
        }
        let isShiftPressed = event.modifierFlags.contains(.shift)
        for char in characters {
            guard let scalar = char.unicodeScalars.first?.value else { continue }
            // Ctrl+H (BS = 0x08): treat as backspace
            if scalar == 0x08 {
                return handleBackspaceInComposing(client: client)
            }
            // Skip other control characters (e.g. Ctrl+P = 0x10, DEL = 0x7F)
            if scalar < 0x20 || scalar == 0x7F {
                return true
            }

            // Save current state before processing input
            saveInputSnapshot()

            let results = romajiConverter.feed(
                char,
                isShiftPressed: isShiftPressed,
                shiftKatakanaEnabled: Settings.shared.shiftKatakanaInputEnabled
            )
            for result in results {
                switch result {
                case .converted(let hiragana):
                    composedHiragana += applyPunctuationStyle(hiragana)
                case .pending:
                    break
                case .passthrough(let character):
                    composedHiragana += SymbolWidthConverter.normalize(
                        String(character),
                        style: Settings.shared.symbolStyle
                    )
                }
            }
        }
        updateComposingMarkedText(client: client)
        scheduleSuggest(client: client)
        return true
    }

    // MARK: - Input history

    private func saveInputSnapshot() {
        let snapshot = ComposingSnapshot(
            composedHiragana: composedHiragana,
            romajiBuffer: romajiConverter.pendingRomaji,
            romajiShiftStates: romajiConverter.pendingShiftStates
        )
        inputHistory.append(snapshot)
    }

    private func clearInputHistory() {
        inputHistory.removeAll()
    }

    // MARK: - Commit helpers

    func commitCurrentState(client: any IMKTextInput) {
        switch inputState {
        case .composing:
            commitComposingText(client: client)
        case .suggesting:
            commitSuggestingText(client: client)
        case .converting:
            commitConvertingText(client: client)
        }
    }

    func commitComposingText(client: any IMKTextInput) {
        var text = composedHiragana
        if let flushed = romajiConverter.flush(shiftKatakanaEnabled: Settings.shared.shiftKatakanaInputEnabled) {
            text += flushed
        }
        guard !text.isEmpty else {
            composedHiragana = ""
            clearInputHistory()
            return
        }
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        composedHiragana = ""
        clearInputHistory()
    }

    func commitConvertingText(client: any IMKTextInput) {
        guard case .converting(let session) = inputState else { return }
        let text = session.committedText
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        akazaClient.learnSync(candidates: session.selectedCandidates)
        resetToComposing()
    }

    func resetToComposing() {
        cancelPendingSuggest()
        inputState = .composing
        composedHiragana = ""
        romajiConverter.clear()
        clearInputHistory()
        Self.candidateWindow.hide()
    }

    // MARK: - Suggest scheduling

    func scheduleSuggest(client: any IMKTextInput) {
        cancelPendingSuggest()

        let yomi = composedHiragana
        guard !yomi.isEmpty else {
            latestSuggestYomi = nil
            Self.candidateWindow.hide()
            return
        }
        guard yomi != latestSuggestYomi else { return }

        latestSuggestYomi = yomi
        let requestID = akazaClient.convertKBestAsync(yomi: yomi, maxPaths: Settings.shared.suggestMaxPaths) { [weak self] paths in
            guard let self = self else { return }
            guard case .composing = self.inputState else { return }
            guard let paths = paths, !paths.isEmpty else { return }
            guard self.composedHiragana == yomi else { return }

            let session = SuggestSession(originalHiragana: yomi, paths: paths)
            self.inputState = .suggesting(session)
            self.updateSuggestingMarkedText(client: client)
            self.showSuggestCandidateWindow(client: client)
        }
        pendingSuggestRequestID = requestID
    }

    func cancelPendingSuggest() {
        if let id = pendingSuggestRequestID {
            akazaClient.cancelRequest(id: id)
            pendingSuggestRequestID = nil
        }
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
        cancelPendingSuggest()
        if let client = sender as? (any IMKTextInput) {
            if hasPreedit {
                commitCurrentState(client: client)
            }
        }
        resetToComposing()
        super.deactivateServer(sender)
    }
}
