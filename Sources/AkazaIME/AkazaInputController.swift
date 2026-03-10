import Cocoa
import InputMethodKit

struct ComposingSnapshot {
    let composedHiragana: String
    let romajiBuffer: String
    let rawRomajiInput: String
}

@objc(AkazaInputController)
class AkazaInputController: IMKInputController {
    var composedHiragana: String = ""
    var rawRomajiInput: String = ""
    let romajiConverter = RomajiConverter()
    var inputState: InputState = .composing
    static let candidateWindow = CandidateWindowController()
    var inputHistory: [ComposingSnapshot] = []
    var functionKeyState: FunctionKeyState?

    var pendingSuggestRequestID: Int?
    var latestSuggestYomi: String?

    var candidateWindowVisibilityPolicy: CandidateWindowVisibilityPolicy {
        CandidateWindowVisibilityPolicy(
            showPredictiveCandidates: Settings.shared.showPredictiveCandidates
        )
    }

    // 大文字 ASCII を入力したときに true になる直接入力モード。
    // このモードでは後続の printable ASCII もローマ字変換せず preedit に積み、
    // スペースで変換せずそのままコミットする（例: "Java" → "Java"）。
    var isDirectInputMode = false

    var hasPreedit: Bool {
        if functionKeyState != nil { return true }
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
            return handleBackspaceEvent(event: event, client: client)
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        var resolvedFunctionKey: UInt16?
        if Self.isFunctionKey(keyCode) {
            resolvedFunctionKey = keyCode
        } else if flags == .control {
            resolvedFunctionKey = switch keyCode {
            case 38: 97   // Ctrl+J → F6 (ひらがな)
            case 40: 98   // Ctrl+K → F7 (カタカナ)
            case 37: 101  // Ctrl+L → F9 (全角英数)
            case 41: 100  // Ctrl+; → F8 (半角カタカナ)
            case 39: 109  // Ctrl+: → F10 (半角英数) ※JISキーボード
            default: nil
            }
        }
        if let fk = resolvedFunctionKey, hasPreedit {
            return handleFunctionKeyFromAnyState(keyCode: fk, client: client)
        }
        if Self.isFunctionKey(keyCode) { return false }

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

    // MARK: - Composing state

    private func handleComposingState(event: NSEvent, keyCode: UInt16, client: any IMKTextInput) -> Bool {
        if functionKeyState != nil {
            if keyCode == 53 { return handleEscapeInFunctionKey(client: client) } // Escape
            commitFunctionKeyState(client: client)
            if keyCode == 36 { return true } // Enter
        }

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
        if let flushed = romajiConverter.flush() {
            text += flushed
        }
        guard !text.isEmpty else { return false }

        // 直接入力モードではかな変換せずそのままコミット（例: "Java" → "Java"）
        if isDirectInputMode {
            client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
            composedHiragana = ""
            isDirectInputMode = false
            clearInputHistory()
            Self.candidateWindow.hide()
            return true
        }

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
        if let flushed = romajiConverter.flush() {
            text += flushed
        }
        guard !text.isEmpty else {
            composedHiragana = ""
            isDirectInputMode = false
            clearInputHistory()
            Self.candidateWindow.hide()
            return true
        }

        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        composedHiragana = ""
        isDirectInputMode = false
        rawRomajiInput = ""
        clearInputHistory()
        Self.candidateWindow.hide()
        return true
    }

    private func handleEscapeInComposing(client: any IMKTextInput) -> Bool {
        guard hasPreedit else { return false }
        composedHiragana = ""
        isDirectInputMode = false
        rawRomajiInput = ""
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
        romajiConverter.setBuffer(snapshot.romajiBuffer)
        rawRomajiInput = snapshot.rawRomajiInput
        updateComposingMarkedText(client: client)
        scheduleSuggest(client: client)
        return true
    }

    func handleCharacterInput(event: NSEvent, client: any IMKTextInput) -> Bool {
        guard let characters = event.characters, !characters.isEmpty else {
            return false
        }
        for char in characters {
            guard let scalar = char.unicodeScalars.first?.value else { continue }
            if scalar == 0x08 { return handleBackspaceInComposing(client: client) }
            if scalar < 0x20 || scalar == 0x7F || (0xF700...0xF8FF).contains(scalar) { return true }
            saveInputSnapshot()
            rawRomajiInput.append(char)
            processCharacter(char, scalar: scalar)
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
            rawRomajiInput: rawRomajiInput
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
        if functionKeyState != nil {
            commitFunctionKeyState(client: client)
            return
        }
        var text = composedHiragana
        if let flushed = romajiConverter.flush() {
            text += flushed
        }
        guard !text.isEmpty else {
            composedHiragana = ""
            isDirectInputMode = false
            clearInputHistory()
            return
        }
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        composedHiragana = ""
        isDirectInputMode = false
        rawRomajiInput = ""
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
        functionKeyState = nil
        inputState = .composing
        composedHiragana = ""
        isDirectInputMode = false
        rawRomajiInput = ""
        romajiConverter.clear()
        clearInputHistory()
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

// MARK: - Suggest scheduling

extension AkazaInputController {
    func scheduleSuggest(client: any IMKTextInput) {
        cancelPendingSuggest()

        // 直接入力モード中はサジェストを抑制する
        guard !isDirectInputMode else {
            Self.candidateWindow.hide()
            return
        }

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
}

// MARK: - Character processing helpers

private extension AkazaInputController {
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
