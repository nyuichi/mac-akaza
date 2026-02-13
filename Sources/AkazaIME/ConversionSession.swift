import Foundation

enum InputState {
    case composing
    case converting(ConversionSession)
}

struct ConversionSession {
    let originalHiragana: String
    let clauses: [[ConvertCandidate]]
    var focusedClauseIndex: Int = 0
    var selectedCandidateIndices: [Int]

    init(originalHiragana: String, clauses: [[ConvertCandidate]]) {
        self.originalHiragana = originalHiragana
        self.clauses = clauses
        self.selectedCandidateIndices = Array(repeating: 0, count: clauses.count)
    }

    var committedText: String {
        clauses.enumerated().map { index, candidates in
            guard !candidates.isEmpty else { return "" }
            return candidates[selectedCandidateIndices[index]].surface
        }.joined()
    }

    var focusedCandidates: [ConvertCandidate] {
        guard focusedClauseIndex < clauses.count else { return [] }
        return clauses[focusedClauseIndex]
    }

    var focusedSelectedIndex: Int {
        guard focusedClauseIndex < selectedCandidateIndices.count else { return 0 }
        return selectedCandidateIndices[focusedClauseIndex]
    }

    mutating func nextCandidate() {
        guard !focusedCandidates.isEmpty else { return }
        let count = focusedCandidates.count
        selectedCandidateIndices[focusedClauseIndex] = (selectedCandidateIndices[focusedClauseIndex] + 1) % count
    }

    mutating func previousCandidate() {
        guard !focusedCandidates.isEmpty else { return }
        let count = focusedCandidates.count
        let current = selectedCandidateIndices[focusedClauseIndex]
        selectedCandidateIndices[focusedClauseIndex] = (current - 1 + count) % count
    }

    mutating func focusPreviousClause() {
        if focusedClauseIndex > 0 {
            focusedClauseIndex -= 1
        }
    }

    mutating func focusNextClause() {
        if focusedClauseIndex < clauses.count - 1 {
            focusedClauseIndex += 1
        }
    }

    mutating func selectCandidate(number: Int) -> Bool {
        let index = number - 1
        guard index >= 0, index < focusedCandidates.count else { return false }
        selectedCandidateIndices[focusedClauseIndex] = index
        return true
    }
}
