import Foundation
import Observation

// Explicit synthetic surrounding domain; the manager setter/metadata and
// presentation policy below are VERBATIM actual product source.
enum AppMode: Equatable { case viewer, history }
final class BooksData {}
enum RouteCode { case unavailable, staleState }
struct UIRouteError: Error {
    let code: RouteCode
    let message: String
    init(_ code: RouteCode, _ message: String) { self.code = code; self.message = message }
}
@MainActor @Observable
final class iOSNavigationManager {
    var currentMode: AppMode = .viewer

    init(revision: UInt64? = 0) { selectedBookPresentationRevision = revision }
}
