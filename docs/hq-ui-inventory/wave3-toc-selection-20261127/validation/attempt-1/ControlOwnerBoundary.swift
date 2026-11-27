import Foundation
import Observation

// Synthetic lifetime boundary only. All layout state implementation below is
// verbatim from the actual app adapter. No UIKit/native acceptance is inferred.
@MainActor private final class MaktabahNativeComponentOwner {
    var activeView: UUID?
    func owns(viewID: UUID) -> Bool { activeView == viewID }
}

