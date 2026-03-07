import Foundation

struct DistinctDisplayProjection<Element> {
    let displayedElements: [Element]

    private let displayIndicesByRawIndex: [Int]
    private let rawIndicesByDisplayIndex: [Int]

    init(elements: [Element], key: (Element) -> String) {
        var displayedElements: [Element] = []
        var displayIndicesByRawIndex: [Int] = Array(repeating: 0, count: elements.count)
        var rawIndicesByDisplayIndex: [Int] = []
        var displayIndexByKey: [String: Int] = [:]

        for (rawIndex, element) in elements.enumerated() {
            let elementKey = key(element)
            if let displayIndex = displayIndexByKey[elementKey] {
                displayIndicesByRawIndex[rawIndex] = displayIndex
                continue
            }

            let displayIndex = displayedElements.count
            displayIndexByKey[elementKey] = displayIndex
            displayedElements.append(element)
            displayIndicesByRawIndex[rawIndex] = displayIndex
            rawIndicesByDisplayIndex.append(rawIndex)
        }

        self.displayedElements = displayedElements
        self.displayIndicesByRawIndex = displayIndicesByRawIndex
        self.rawIndicesByDisplayIndex = rawIndicesByDisplayIndex
    }

    var isEmpty: Bool { displayedElements.isEmpty }

    func displayIndex(forRawIndex rawIndex: Int) -> Int {
        guard rawIndex >= 0, rawIndex < displayIndicesByRawIndex.count else { return 0 }
        return displayIndicesByRawIndex[rawIndex]
    }

    func rawIndex(forDisplayIndex displayIndex: Int) -> Int? {
        guard displayIndex >= 0, displayIndex < rawIndicesByDisplayIndex.count else { return nil }
        return rawIndicesByDisplayIndex[displayIndex]
    }
}
