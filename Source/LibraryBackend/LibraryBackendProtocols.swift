import Foundation

protocol LibraryCatalogProviding: Sendable {
    func catalog(forceRefresh: Bool) async throws -> [LibraryCatalogNode]
}

protocol LibraryTextProviding: Sendable {
    func section(at locator: TextLocator) async throws -> LibraryTextSection
}

protocol LibraryNavigationProviding: Sendable {
    func normalizedLocator(for input: String) async throws -> TextLocator
    func tableOfContents(for work: LibraryWork) async throws -> [LibraryTOCNode]
}

protocol LibrarySearchProviding: Sendable {
    func search(_ request: LibrarySearchRequest) async throws -> LibrarySearchPage
}

protocol LibraryAuthorsProviding: Sendable {
    func authors() async throws -> [LibraryAuthor]
}

protocol LibraryMetadataProviding: Sendable {
    func versions(for workKey: String) async throws -> [TextVersionMetadata]
    func related(to locator: TextLocator) async throws -> [TextLocator]
}

protocol OfflineLibraryProviding: Sendable {
    func packages(forceRefresh: Bool) async throws -> [OfflinePackage]
    func installedPackageIDs() async -> Set<String>
    func install(packageIDs: Set<String>, progress: @escaping @Sendable (OfflineInstallProgress) -> Void) async throws
    func remove(packageIDs: Set<String>) async throws
    func availableUpdates() async throws -> OfflineUpdateSummary
    func update(progress: @escaping @Sendable (OfflineInstallProgress) -> Void) async throws
    func cancelInstall() async
}

struct LibraryBackendRegistration: Sendable {
    let id: BackendID
    let sourceDescription: String
    let capabilities: BackendCapabilities
    let catalog: (any LibraryCatalogProviding)?
    let text: (any LibraryTextProviding)?
    let navigation: (any LibraryNavigationProviding)?
    let search: (any LibrarySearchProviding)?
    let authors: (any LibraryAuthorsProviding)?
    let metadata: (any LibraryMetadataProviding)?
    let offline: (any OfflineLibraryProviding)?
    /// Existing Maktabah/Otzaria models remain the most compatible presentation path.
    /// Backends that return only neutral models opt into the narrow compatibility bridge.
    let usesNativeMaktabahDataPath: Bool
    let invalidateTransientState: @Sendable () async -> Void
}

struct OfflinePackage: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let heTitle: String?
    let parentID: String?
    let compressedSize: Int64
    let indexTitles: [String]?
    let isCompleteLibrary: Bool
}

struct OfflineInstallProgress: Sendable {
    enum Phase: String, Sendable { case preparing, downloading, validating, installing, finished }
    let phase: Phase
    let packageID: String?
    let completedBytes: Int64
    let totalBytes: Int64
}

struct OfflineUpdateSummary: Codable, Hashable, Sendable {
    let changedWorkCount: Int
    let affectedPackageIDs: Set<String>
    var hasUpdates: Bool { changedWorkCount > 0 }
}

enum OfflinePackageSelection {
    static func resolve(_ ids: Set<String>, from packages: [OfflinePackage]) -> [OfflinePackage] {
        let selected = packages.filter { ids.contains($0.id) }
        if let complete = selected.first(where: \.isCompleteLibrary) { return [complete] }
        return selected.filter { candidate in
            !selected.contains { ancestor in
                var parent = candidate.parentID
                while let value = parent {
                    if value == ancestor.id { return true }
                    parent = packages.first(where: { $0.id == value })?.parentID
                }
                return false
            }
        }
    }
}
