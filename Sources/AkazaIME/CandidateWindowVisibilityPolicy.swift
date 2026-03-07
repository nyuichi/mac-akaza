enum CandidateWindowTrigger {
    case composingSuggestion
    case conversionStarted
    case conversionNavigation
}

struct CandidateWindowVisibilityPolicy {
    let showPredictiveCandidates: Bool

    func shouldShowWindow(for trigger: CandidateWindowTrigger) -> Bool {
        guard !showPredictiveCandidates else { return true }

        switch trigger {
        case .composingSuggestion, .conversionStarted:
            return false
        case .conversionNavigation:
            return true
        }
    }
}
