import Foundation

struct SuggestSession {
    let originalHiragana: String
    let paths: [KBestPath]
    var selectedPathIndex: Int = 0

    var displayText: String {
        guard selectedPathIndex < paths.count else { return originalHiragana }
        let path = paths[selectedPathIndex]
        return path.segments.map { candidates in
            candidates.first?.surface ?? ""
        }.joined()
    }

    var selectedCandidates: [(surface: String, yomi: String)] {
        guard selectedPathIndex < paths.count else { return [] }
        let path = paths[selectedPathIndex]
        return path.segments.compactMap { candidates in
            guard let first = candidates.first else { return nil }
            return (surface: first.surface, yomi: first.yomi)
        }
    }

    mutating func nextPath() {
        guard !paths.isEmpty else { return }
        selectedPathIndex = (selectedPathIndex + 1) % paths.count
    }

    mutating func previousPath() {
        guard !paths.isEmpty else { return }
        selectedPathIndex = (selectedPathIndex - 1 + paths.count) % paths.count
    }

    func toConversionSession() -> ConversionSession {
        guard selectedPathIndex < paths.count else {
            return ConversionSession(originalHiragana: originalHiragana, clauses: [])
        }
        let clauses = paths[selectedPathIndex].segments
        return ConversionSession(originalHiragana: originalHiragana, clauses: clauses)
    }
}
