import Foundation
import OSLog
// Only logging, unused catalog/title/UI helpers and unused compressed-blob
// decoding are explicit boundaries. Repository, Annotation, SQLiteDatabase,
// SyncPendingStore and actual locator declarations are original production code.
extension Logger {
    static let annotations = Logger(subsystem: "org.otzaria.cloud-import-identity", category: "annotations")
}
enum ReusableFunc {
    static func showAlert(title: String, message: String) { fatalError("Unexpected database connection failure") }
}
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
extension String { func convertToArabicDigits() -> String { self } }
struct LibraryDataManager: Sendable {
    struct Book: Sendable { let book: String }
    static let shared = Self()
    func getBook(_ ids: [Int]) -> [Book] { [] }
}
struct LegacyIdentityRegistry: Sendable {
    static let shared = Self()
    func locator(for id: Int) -> TextLocator? { nil }
    func title(for locator: TextLocator) -> String? { nil }
}
struct CrossBackendBookIdentityIndex: Sendable {
    static let shared = Self()
    func areEquivalent(_ a: TextLocator, _ b: TextLocator) -> Bool { a == b }
}
struct AnnotationManager: Sendable {}
