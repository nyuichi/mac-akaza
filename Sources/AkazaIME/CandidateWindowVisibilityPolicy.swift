import Foundation

enum CandidateWindowTrigger {
    case composingSuggestion
    case conversionStarted
    case conversionNavigation
}

struct CandidateWindowVisibilityPolicy {
    let showOnlyAfterSecondSpace: Bool

    func shouldShowWindow(for trigger: CandidateWindowTrigger) -> Bool {
        guard showOnlyAfterSecondSpace else { return true }

        switch trigger {
        case .composingSuggestion, .conversionStarted:
            return false
        case .conversionNavigation:
            return true
        }
    }
}
