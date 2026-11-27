import SwiftUI
import Foundation
enum LibraryBackendKind: Sendable { case otzaria, sefaria }
struct FixtureLocator: Sendable { let backend: LibraryBackendKind; let persistenceKey: String }
struct SearchResultItem {
    let archive: String
    let stableID: String
    let backendLocator: FixtureLocator?
    let resultLanguage: String?
    let versionTitle: String?
    let attributedText: NSAttributedString
}
enum LibraryReaderTextMode { case source, translation, both }
@MainActor final class TextViewState {
    static let shared = TextViewState()
    var readerTextMode = LibraryReaderTextMode.source
}
enum ReaderViewModel { static var kfgqpc: Font { .body } }
extension String {
    var readerPlainText: String { self }
    var isParagraphRTL: Bool { false }
}
struct LibraryTextVersionSelection: Sendable { let title: String; let language: String }
struct FixtureSegment: Sendable {
    let locator: FixtureLocator
    let primaryText: String
    let translation: String?
}
struct LibraryTextSection: Sendable { let segments: [FixtureSegment] }
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    func section(at locator: FixtureLocator) async throws -> LibraryTextSection { fatalError("Compile boundary only") }
    func section(at locator: FixtureLocator, version: LibraryTextVersionSelection) async throws -> LibraryTextSection { fatalError("Compile boundary only") }
}
