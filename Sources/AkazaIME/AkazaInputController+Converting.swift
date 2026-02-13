import Cocoa
import InputMethodKit

// MARK: - Converting state handlers
extension AkazaInputController {
    func handleConvertingState(event: NSEvent, keyCode: UInt16, client: any IMKTextInput) -> Bool {
        switch keyCode {
        case 49, 125: // Space, Down arrow
            return handleNextCandidateInConverting(client: client)
        case 126: // Up arrow
            return handlePreviousCandidateInConverting(client: client)
        case 123: // Left arrow
            return handlePreviousClauseInConverting(client: client)
        case 124: // Right arrow
            return handleNextClauseInConverting(client: client)
        case 36: // Enter
            return handleEnterInConverting(client: client)
        case 53, 51: // Escape, Backspace
            return handleEscapeInConverting(client: client)
        default:
            return handleDefaultKeyInConverting(event: event, client: client)
        }
    }

    private func handleDefaultKeyInConverting(event: NSEvent, client: any IMKTextInput) -> Bool {
        if let characters = event.characters, let char = characters.first,
           let number = Int(String(char)), (1...9).contains(number) {
            return handleNumberKeyInConverting(number: number, client: client)
        }

        if let characters = event.characters, let first = characters.first,
           !first.isNewline && !first.isWhitespace && (first.isLetter || first.isNumber || first.isPunctuation || first.isSymbol) {
            commitConvertingText(client: client)
            return handleCharacterInput(event: event, client: client)
        }

        return true
    }

    private func handleNextCandidateInConverting(client: any IMKTextInput) -> Bool {
        guard case .converting(var session) = inputState else { return false }
        session.nextCandidate()
        inputState = .converting(session)
        updateConvertingMarkedText(client: client)
        showCandidateWindow(client: client)
        return true
    }

    private func handlePreviousCandidateInConverting(client: any IMKTextInput) -> Bool {
        guard case .converting(var session) = inputState else { return false }
        session.previousCandidate()
        inputState = .converting(session)
        updateConvertingMarkedText(client: client)
        showCandidateWindow(client: client)
        return true
    }

    private func handlePreviousClauseInConverting(client: any IMKTextInput) -> Bool {
        guard case .converting(var session) = inputState else { return false }
        session.focusPreviousClause()
        inputState = .converting(session)
        updateConvertingMarkedText(client: client)
        showCandidateWindow(client: client)
        return true
    }

    private func handleNextClauseInConverting(client: any IMKTextInput) -> Bool {
        guard case .converting(var session) = inputState else { return false }
        session.focusNextClause()
        inputState = .converting(session)
        updateConvertingMarkedText(client: client)
        showCandidateWindow(client: client)
        return true
    }

    private func handleEnterInConverting(client: any IMKTextInput) -> Bool {
        commitConvertingText(client: client)
        return true
    }

    private func handleEscapeInConverting(client: any IMKTextInput) -> Bool {
        guard case .converting(let session) = inputState else { return false }
        composedHiragana = session.originalHiragana
        inputState = .composing
        Self.candidateWindow.hide()
        updateComposingMarkedText(client: client)
        return true
    }

    private func handleNumberKeyInConverting(number: Int, client: any IMKTextInput) -> Bool {
        guard case .converting(var session) = inputState else { return false }
        if session.selectCandidate(number: number) {
            inputState = .converting(session)
            commitConvertingText(client: client)
        }
        return true
    }
}

// MARK: - Marked text display
extension AkazaInputController {
    func updateComposingMarkedText(client: any IMKTextInput) {
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

    func updateConvertingMarkedText(client: any IMKTextInput) {
        guard case .converting(let session) = inputState else { return }

        let attributed = NSMutableAttributedString()

        for (clauseIndex, candidates) in session.clauses.enumerated() {
            guard !candidates.isEmpty else { continue }
            let selectedIndex = session.selectedCandidateIndices[clauseIndex]
            let surface = candidates[selectedIndex].surface
            let isFocused = clauseIndex == session.focusedClauseIndex

            let underlineStyle: NSUnderlineStyle = isFocused ? .thick : .single
            let attrs: [NSAttributedString.Key: Any] = [
                .underlineStyle: underlineStyle.rawValue,
                .markedClauseSegment: clauseIndex
            ]
            let segment = NSAttributedString(string: surface, attributes: attrs)
            attributed.append(segment)
        }

        let fullLength = attributed.length
        client.setMarkedText(
            attributed,
            selectionRange: NSRange(location: fullLength, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
    }

    func showCandidateWindow(client: any IMKTextInput) {
        guard case .converting(let session) = inputState else { return }

        let candidates = session.focusedCandidates
        guard !candidates.isEmpty else {
            Self.candidateWindow.hide()
            return
        }

        var lineHeightRect = NSRect.zero
        client.attributes(forCharacterIndex: 0, lineHeightRectangle: &lineHeightRect)

        Self.candidateWindow.show(
            candidates: candidates,
            selectedIndex: session.focusedSelectedIndex,
            cursorRect: lineHeightRect
        )
    }
}
