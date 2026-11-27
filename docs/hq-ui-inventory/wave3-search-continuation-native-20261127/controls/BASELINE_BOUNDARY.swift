
// Explicit original Search/UI/storage boundary substitutes. This executes the
// unchanged first-draft reporting/catch block below, injecting failure only in
// its observation serializer after its real typed return has been produced.
@MainActor private final class MaktabahNativeActionAcceptanceProbe {
    let kind = "search-continuation-hit"
    let token = UUID()
    var written: [[String: Any]] = []
    func write(payload: [String: Any]) throws { written.append(payload) }
}
@MainActor private final class MaktabahNativeSearchContinuationProbeEvidence {
    init(_ probe: MaktabahNativeActionAcceptanceProbe) {}
    func outcome(_ outcome: ActionSearchContinuationOutcome) throws -> [String: Any] {
        // It was successfully projected before the later observation failed.
        ["kind": "refused", "effects": ["pageRequested", "hitSelectionApplied"]]
    }
    func observation(_ value: ActionSearchContinuationObservation) throws -> [String: Any] {
        throw CocoaError(.coderInvalidValue)
    }
    func operation(_ value: ActionSearchContinuationOperation) -> [String: Any] { ["kind": "revealLoadedHit"] }
}
@MainActor private struct ReportingSearchBoundary {
    struct Item { let stableID: String }
    var results = [Item(stableID: "original-row")]
    var submissionRevision = 1, cancellationRevision = 0, paginationRevision = 0
    var hasSubmitted = true, isSearching = false, isLoadingMore = false, resultsAreDirty = false
    var selectedBookIds: Set<Int> = [], query = "אמר", errorMessage: String?
}
