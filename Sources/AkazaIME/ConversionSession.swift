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

    // MARK: - Clause boundary manipulation

    var clauseYomis: [String] {
        clauses.map { candidates in
            candidates.first?.yomi ?? ""
        }
    }

    /// 現在の文節を右に1文字伸ばした場合の yomi と force_ranges を返す
    func forceRangesForExtendRight() -> (String, [[Int]])? {
        let yomis = clauseYomis
        // 最後の文節では次の文節がないので伸ばせない
        guard focusedClauseIndex < yomis.count - 1 else { return nil }

        let nextYomi = yomis[focusedClauseIndex + 1]
        guard !nextYomi.isEmpty else { return nil }

        // 次の文節の先頭1文字を現在の文節に移す
        let firstChar = String(nextYomi.prefix(1))
        let remaining = String(nextYomi.dropFirst())

        var newYomis = yomis
        newYomis[focusedClauseIndex] += firstChar
        if remaining.isEmpty {
            newYomis.remove(at: focusedClauseIndex + 1)
        } else {
            newYomis[focusedClauseIndex + 1] = remaining
        }

        return (originalHiragana, buildForceRanges(newYomis))
    }

    /// 現在の文節を左に1文字縮めた場合の yomi と force_ranges を返す
    func forceRangesForExtendLeft() -> (String, [[Int]])? {
        let yomis = clauseYomis
        let currentYomi = yomis[focusedClauseIndex]

        // 1文字しかない文節は縮められない
        guard currentYomi.count > 1 else { return nil }
        // 最後の文節では次の文節に文字を渡せない
        guard focusedClauseIndex < yomis.count - 1 else { return nil }

        // 現在の文節の末尾1文字を次の文節の先頭に移す
        let lastChar = String(currentYomi.suffix(1))
        let shortened = String(currentYomi.dropLast())

        var newYomis = yomis
        newYomis[focusedClauseIndex] = shortened
        newYomis[focusedClauseIndex + 1] = lastChar + newYomis[focusedClauseIndex + 1]

        return (originalHiragana, buildForceRanges(newYomis))
    }

    private func buildForceRanges(_ yomis: [String]) -> [[Int]] {
        var ranges: [[Int]] = []
        var byteOffset = 0
        for yomi in yomis {
            let byteCount = yomi.utf8.count
            ranges.append([byteOffset, byteOffset + byteCount])
            byteOffset += byteCount
        }
        return ranges
    }
}
