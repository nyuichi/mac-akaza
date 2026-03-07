import Foundation

struct SuggestSession {
    let originalHiragana: String
    let paths: [KBestPath]
    var selectedPathIndex: Int = 0

    var displayText: String {
        guard selectedPathIndex < paths.count else { return originalHiragana }
        return Self.displayText(for: paths[selectedPathIndex])
    }

    var selectedCandidates: [(surface: String, yomi: String)] {
        guard selectedPathIndex < paths.count else { return [] }
        let path = paths[selectedPathIndex]
        return path.segments.compactMap { candidates in
            guard let first = candidates.first else { return nil }
            return (surface: first.surface, yomi: first.yomi)
        }
    }

    var displayTexts: [String] {
        distinctPathProjection.displayedElements.map(Self.displayText(for:))
    }

    var selectedDisplayIndex: Int {
        distinctPathProjection.displayIndex(forRawIndex: selectedPathIndex)
    }

    mutating func nextPath() {
        moveDisplayedPath(offset: 1)
    }

    mutating func previousPath() {
        moveDisplayedPath(offset: -1)
    }

    func toConversionSession() -> ConversionSession {
        guard selectedPathIndex < paths.count else {
            return ConversionSession(originalHiragana: originalHiragana, clauses: [])
        }
        let clauses = paths[selectedPathIndex].segments
        return ConversionSession(originalHiragana: originalHiragana, clauses: clauses)
    }

    private static func displayText(for path: KBestPath) -> String {
        path.segments.map { candidates in
            candidates.first?.surface ?? ""
        }.joined()
    }

    private var distinctPathProjection: DistinctDisplayProjection<KBestPath> {
        DistinctDisplayProjection(elements: paths, key: Self.displayText(for:))
    }

    private mutating func moveDisplayedPath(offset: Int) {
        let projection = distinctPathProjection
        guard !projection.isEmpty else { return }

        let count = projection.displayedElements.count
        let nextDisplayIndex = (selectedDisplayIndex + offset + count) % count
        guard let rawIndex = projection.rawIndex(forDisplayIndex: nextDisplayIndex) else { return }
        selectedPathIndex = rawIndex
    }
}
