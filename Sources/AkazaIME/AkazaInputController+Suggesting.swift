import Cocoa
import InputMethodKit

// MARK: - Suggesting state handlers
extension AkazaInputController {
    func handleSuggestingState(event: NSEvent, keyCode: UInt16, client: any IMKTextInput) -> Bool {
        let isShiftPressed = event.modifierFlags.contains(.shift)

        switch keyCode {
        case 48: // Tab
            if isShiftPressed {
                return handlePreviousPathInSuggesting(client: client)
            }
            return handleNextPathInSuggesting(client: client)
        case 49: // Space
            return handleSpaceInSuggesting(client: client)
        case 36: // Enter
            return handleEnterInSuggesting(client: client)
        case 53: // Escape
            return handleEscapeInSuggesting(client: client)
        case 51: // Backspace
            return handleBackspaceInSuggesting(client: client)
        default:
            return handleCharacterInSuggesting(event: event, client: client)
        }
    }

    private func handleNextPathInSuggesting(client: any IMKTextInput) -> Bool {
        guard case .suggesting(var session) = inputState else { return false }
        session.nextPath()
        inputState = .suggesting(session)
        updateSuggestingMarkedText(client: client)
        showSuggestCandidateWindow(client: client)
        return true
    }

    private func handlePreviousPathInSuggesting(client: any IMKTextInput) -> Bool {
        guard case .suggesting(var session) = inputState else { return false }
        session.previousPath()
        inputState = .suggesting(session)
        updateSuggestingMarkedText(client: client)
        showSuggestCandidateWindow(client: client)
        return true
    }

    private func handleSpaceInSuggesting(client: any IMKTextInput) -> Bool {
        guard case .suggesting(let session) = inputState else { return false }
        let conversionSession = session.toConversionSession()
        inputState = .converting(conversionSession)
        composedHiragana = ""
        updateConvertingMarkedText(client: client)
        showCandidateWindow(client: client)
        return true
    }

    private func handleEnterInSuggesting(client: any IMKTextInput) -> Bool {
        commitSuggestingText(client: client)
        return true
    }

    private func handleEscapeInSuggesting(client: any IMKTextInput) -> Bool {
        guard case .suggesting(let session) = inputState else { return false }
        composedHiragana = session.originalHiragana
        inputState = .composing
        Self.candidateWindow.hide()
        updateComposingMarkedText(client: client)
        return true
    }

    private func handleBackspaceInSuggesting(client: any IMKTextInput) -> Bool {
        guard case .suggesting(let session) = inputState else { return false }
        composedHiragana = session.originalHiragana
        inputState = .composing
        // 候補ウィンドウは隠さない（新しいサジェストで更新される）
        return handleBackspaceInComposing(client: client)
    }

    private func handleCharacterInSuggesting(event: NSEvent, client: any IMKTextInput) -> Bool {
        guard case .suggesting(let session) = inputState else { return false }
        composedHiragana = session.originalHiragana
        inputState = .composing
        // 候補ウィンドウは隠さない（新しいサジェストで更新される）
        return handleCharacterInput(event: event, client: client)
    }

    // MARK: - Commit

    func commitSuggestingText(client: any IMKTextInput) {
        guard case .suggesting(let session) = inputState else { return }
        let text = session.displayText
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        akazaClient.learnSync(candidates: session.selectedCandidates)
        resetToComposing()
    }

    // MARK: - Display

    func updateSuggestingMarkedText(client: any IMKTextInput) {
        // preedit はひらがなのまま（composing と同じ表示）
        updateComposingMarkedText(client: client)
    }

    func showSuggestCandidateWindow(client: any IMKTextInput) {
        guard case .suggesting(let session) = inputState else { return }

        let allSurfaces = session.paths.map { path in
            path.segments.map { $0.first?.surface ?? "" }.joined()
        }

        // 文節区切りが異なっても表層が同じになる候補を除去（挿入順を保持）
        var seen = Set<String>()
        let suggestions = allSurfaces.filter { seen.insert($0).inserted }

        guard !suggestions.isEmpty else {
            Self.candidateWindow.hide()
            return
        }

        // 選択中パスの表層に対応するインデックスを求める
        let selectedSurface = allSurfaces[session.selectedPathIndex]
        let selectedIndex = suggestions.firstIndex(of: selectedSurface) ?? 0

        var lineHeightRect = NSRect.zero
        client.attributes(forCharacterIndex: 0, lineHeightRectangle: &lineHeightRect)

        Self.candidateWindow.showSuggestions(
            suggestions: suggestions,
            selectedIndex: selectedIndex,
            cursorRect: lineHeightRect
        )
    }
}
