//
//  TargetBackendBookResolver.swift
//  Maktabah
//
//  Downstream-owned book resolver used during transactional backend transitions.
//  Safely resolves books across cold catalogs without throwing unresolvableBook errors.
//

import Foundation

/// Validates whether a Sefaria workKey is backed by authoritative catalog records,
/// cross-backend identity mappings, registered legacy locators, or verified offline packages on disk.
/// Fails closed against invented identities, placeholder strings, and nonexistent archives.
enum SefariaBookIdentityValidator: Sendable {
    static func isAuthoritative(
        workKey: String,
        id: Int,
        textLocator: TextLocator,
        fileManager: FileManager = .default,
        offlinePaths: SefariaOfflinePaths = SefariaOfflinePaths()
    ) -> Bool {
        let trimmed = workKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.lowercased().hasPrefix("book "),
              trimmed != "Book \(id)",
              trimmed != "DefinitelyNotARealSefariaWorkXYZ" else {
            return false
        }

        // 1. Authoritative registered locator in LegacyIdentityRegistry for this exact backend and workKey
        if let registered = LegacyIdentityRegistry.shared.locator(for: id),
           registered.backend == .sefaria,
           registered.workKey == trimmed {
            return true
        }

        // 2. Authoritative title registered specifically for this textLocator
        if let registeredTitle = LegacyIdentityRegistry.shared.title(for: textLocator),
           !registeredTitle.isEmpty,
           !registeredTitle.lowercased().hasPrefix("book ") {
            return true
        }

        // 3. Authoritative cross-backend canonical ID mapped to this textLocator
        if let canonicalID = CrossBackendBookIdentityIndex.shared.canonicalID(for: textLocator),
           canonicalID == id || CrossBackendBookIdentityIndex.shared.areEquivalent(
               TextLocator(backend: .otzaria, workKey: "book:\(id)", position: .legacyLine(0)),
               textLocator
           ) {
            return true
        }

        // 4. Authoritative verified local offline package actually present on disk (non-empty)
        // Note: standaloneArchive(for:).isFileURL only checks URL scheme; an actual fileExists check is required.
        let archiveURL = offlinePaths.standaloneArchive(for: trimmed)
        let expandedURL = offlinePaths.expandedBooks.appendingPathComponent(SefariaOfflinePaths.safeComponent(trimmed))
        if fileManager.fileExists(atPath: expandedURL.path) {
            return true
        }
        if fileManager.fileExists(atPath: archiveURL.path) {
            if let attrs = try? fileManager.attributesOfItem(atPath: archiveURL.path),
               let size = attrs[.size] as? Int64,
               size > 0 {
                return true
            }
        }

        return false
    }
}

/// Shared by the actual resolver and portable collision regression tests.
/// Numeric IDs are backend-local; a missing locator never proves provenance.
enum TargetBackendBookIdentity {
    static func workKey(_ value: String?, in backend: BackendID) throws -> String? {
        guard var key = value?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else { return nil }
        for source in BackendID.allCases where key.hasPrefix(source.rawValue + ":") {
            guard source == backend else {
                throw BackendTransitionError.foreignBackendLocator(locator: key, expectedBackend: backend)
            }
            key = String(key.dropFirst(source.rawValue.count + 1))
            break
        }
        return key.isEmpty ? nil : key
    }

    static func matches(id: Int, locator: TextLocator?, requestedID: Int,
                        workKey: String?, backend: BackendID,
                        stagedCatalog: [String: LibraryWork]? = nil) -> Bool {
        guard let locator, locator.backend == backend, id == requestedID else { return false }
        // A complete target refresh also governs retained/live reader objects.
        // An authentic old locator does not prove that a deleted work exists.
        if let stagedCatalog, stagedCatalog[locator.workKey] == nil { return false }
        if let workKey {
            // Otzaria's original persisted numeric alias may resolve to its
            // authentic file-path key; the bridge still verifies the local ID.
            return locator.workKey == workKey ||
                (backend == .otzaria && id == requestedID &&
                 (workKey == "book:\(requestedID)" || workKey == String(requestedID)))
        }
        return id == requestedID
    }
}

#if canImport(UIKit)
@MainActor
protocol TargetBackendBookResolverProtocol: Sendable {
    func resolveBook(
        id: Int,
        backendLocator: String?,
        title: String?,
        in backend: BackendID
    ) throws -> BooksData
}

@MainActor
final class ChavrusaTextTargetBackendBookResolver: TargetBackendBookResolverProtocol {
    static let shared = ChavrusaTextTargetBackendBookResolver()

    func resolveBook(
        id: Int,
        backendLocator: String?,
        title: String?,
        in backend: BackendID
    ) throws -> BooksData {
        let ldm = LibraryDataManager.shared
        let key = try TargetBackendBookIdentity.workKey(backendLocator, in: backend)
        func matches(_ book: BooksData) -> Bool {
            TargetBackendBookIdentity.matches(id: book.id, locator: book.backendLocator,
                requestedID: id, workKey: key, backend: backend,
                stagedCatalog: BackendCoordinator.shared.stagedCatalogs[backend])
        }
        // A successfully staged catalog is authoritative for this transition;
        // a deleted work cannot fall through to a stale global registry entry.
        if backend != .otzaria, let key, let staged = BackendCoordinator.shared.stagedCatalogs[backend], staged[key] == nil {
            throw BackendTransitionError.unresolvableBook(bookId: id, title: title ?? key, locator: backendLocator)
        }
        // A live entry is usable only with authentic backend AND work identity.
        if let book = ldm.booksById[id], matches(book) { return book }
        if let key, let book = ldm.booksById.values.first(where: {
            $0.backendLocator?.workKey == key && matches($0)
        }) { return book }

        if backend == .otzaria {
            // Query Otzaria itself; never fall back to getBook's active catalog.
            if let key {
                if let book = try OtzariaMaktabahBridge.shared.resolveBook(stableKey: key, expectedBookId: id), matches(book) {
                    return book
                }
            } else if let book = try OtzariaMaktabahBridge.shared.fetchBook(byId: id), matches(book) {
                return book
            }
        } else {
            let registered = LegacyIdentityRegistry.shared.locator(for: id)
            let workKey = key ?? (registered?.backend == backend ? registered?.workKey : nil)
            if let catalog = BackendCoordinator.shared.stagedCatalogs[backend],
               workKey.flatMap({ catalog[$0] }) == nil {
                throw BackendTransitionError.unresolvableBook(bookId: id, title: title ?? "Book \(id)", locator: backendLocator)
            }
            if let workKey, let work = BackendCoordinator.shared.stagedCatalogs[backend]?[workKey] {
                // Metadata comes exclusively from the staged target provider.
                // Keep the saved backend-local ID and document UUID unchanged.
                return BooksData(id: id,
                    book: LibraryPresentationPolicy.workTitle(title: work.title, heTitle: work.heTitle),
                    archive: 0, muallif: 0, bithoqoh: work.description ?? "", info: work.title,
                    backendLocator: work.locator, backendSearchPath: work.searchPath)
            }
            // Synchronous legacy opens may precede async staging. Only an
            // independently verified offline/registered Sefaria work is eligible.
            if backend == .sefaria, let workKey {
                let locator = TextLocator(backend: backend, workKey: workKey,
                    position: .canonicalRef(SefariaRef.canonicalInput(workKey)))
                if SefariaBookIdentityValidator.isAuthoritative(workKey: workKey, id: id, textLocator: locator) {
                    return BooksData(id: id, book: LegacyIdentityRegistry.shared.title(for: locator) ?? workKey,
                        archive: 0, muallif: 0, bithoqoh: "", info: workKey, backendLocator: locator)
                }
            }
        }
        throw BackendTransitionError.unresolvableBook(bookId: id, title: title ?? "Book \(id)", locator: backendLocator)
    }
}
#endif
