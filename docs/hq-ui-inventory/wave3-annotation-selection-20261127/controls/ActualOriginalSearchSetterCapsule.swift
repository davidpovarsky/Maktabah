import Foundation

// Exact iOS candidate helper/setter bodies. Only applyFilter is a domain fixture.
@MainActor final class OriginalSearchSetterCapsule {
let nativeRoutingPublication = MaktabahNativeAnnotationListPublication()
private var searchTask: Task<Void,Never>?
var applies = 0
func applyFilter() { applies += 1 }
private func nativeRoutingInputWillChange() {
        nativeRoutingPublication.willPublish()
    }
private func nativeRoutingBeginSearch() -> UUID? {
        return nativeRoutingPublication.beginOriginalSearch()
    }
private func nativeRoutingFinishSearch(_ token: UUID?) {
        if let token { nativeRoutingPublication.finishOriginalSearch(token) }
    }
var searchText: String = "" {
        didSet {
            guard oldValue != searchText else { return }
            searchTask?.cancel()
            searchTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                self?.applyFilter()
            }
        }
    }
}
