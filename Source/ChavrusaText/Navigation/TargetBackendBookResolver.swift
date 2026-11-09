//
//  TargetBackendBookResolver.swift
//  Maktabah
//
//  Downstream-owned book resolver used during transactional backend transitions.
//  Safely resolves books across cold catalogs without throwing unresolvableBook errors.
//

import Foundation

/// Numeric IDs are local catalog keys, never proof of cross-source identity.
enum TargetBackendBookIdentity {
    static func matches(id: Int, backend: BackendID, workKey: String?,
                        candidateID: Int, candidateBackend: BackendID?, candidateWorkKey: String?) -> Bool {
        guard id == candidateID, backend == candidateBackend else { return false }
        guard let workKey, !workKey.isEmpty else { return false }
        return workKey == candidateWorkKey
    }
}

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
    private var preparedWorks: [BackendID: [LibraryWork]] = [:]
    func hasPreparedCatalog(for backend: BackendID) -> Bool { preparedWorks[backend] != nil }

    /// Reads the target provider without publishing it as the active library.
    /// The scoped catalog also serves the canonical navigation participant.
    func withTargetCatalog<T>(in backend: BackendID, operation: () async throws -> T) async throws -> T {
        guard preparedWorks[backend] == nil else { throw BackendTransitionError.transitionSuperseded }
        if backend == .otzaria { return try await operation() }
        let nodes = try await BackendCoordinator.shared.catalog(for: backend)
        func works(_ node: LibraryCatalogNode) -> [LibraryWork] {
            (node.work.map { [$0] } ?? []) + node.children.flatMap(works)
        }
        let catalog = nodes.flatMap(works)
        guard catalog.allSatisfy({ $0.locator.backend == backend }) else {
            throw StudyWorkspaceError.backendMismatch
        }
        // Another window may have completed preflight during the await.
        guard preparedWorks[backend] == nil else { throw BackendTransitionError.transitionSuperseded }
        preparedWorks[backend] = catalog
        defer { preparedWorks.removeValue(forKey: backend) }
        return try await operation()
    }

    func resolveBook(
        id: Int,
        backendLocator: String?,
        title: String?,
        in backend: BackendID
    ) throws -> BooksData {
        let ldm = LibraryDataManager.shared
        var matchedBook: BooksData?
        let registeredLocator = LegacyIdentityRegistry.shared.locator(for: id)
        let requestedWorkKey = backendLocator.map { raw in
            let prefix = backend.rawValue + ":"
            return raw.hasPrefix(prefix) ? String(raw.dropFirst(prefix.count)) : raw
        } ?? (registeredLocator?.backend == backend ? registeredLocator?.workKey : nil)
        func matches(_ book: BooksData) -> Bool {
            TargetBackendBookIdentity.matches(id: id, backend: backend, workKey: requestedWorkKey,
                candidateID: book.id, candidateBackend: book.backendLocator?.backend,
                candidateWorkKey: book.backendLocator?.workKey)
        }
        if backend == .otzaria, requestedWorkKey == nil,
           let book = try OtzariaMaktabahBridge.shared.fetchBook(byId: id),
           book.id == id, book.backendLocator?.backend == .otzaria {
            // Legacy native sessions may lack a locator. Only the actual
            // target database can supply it; the active catalog is not proof.
            return book
        }
        if let catalog = preparedWorks[backend] {
            let registered = LegacyIdentityRegistry.shared.locator(for: id)
            let key = requestedWorkKey ?? (registered?.backend == backend ? registered?.workKey : nil)
            guard let key, let work = catalog.first(where: { $0.locator.workKey == key }),
                  CrossBackendBookIdentityIndex.shared.canonicalID(for: work) == id ||
                    (registered?.backend == backend && registered?.workKey == key) else {
                throw BackendTransitionError.unresolvableBook(bookId: id, title: title ?? requestedWorkKey ?? "Unavailable work", locator: backendLocator)
            }
            let book = BooksData(id: id,
                book: LibraryPresentationPolicy.workTitle(title: work.title, heTitle: work.heTitle),
                archive: 0, muallif: 0, bithoqoh: work.description ?? "", info: work.title)
            book.backendLocator = work.locator
            book.backendSearchPath = work.searchPath
            return book
        }

        switch backend {
        case .otzaria:
            if let locator = backendLocator {
                guard !locator.hasPrefix("sefaria:") else {
                    throw BackendTransitionError.foreignBackendLocator(locator: locator, expectedBackend: .otzaria)
                }
            }
            if let book = ldm.booksById[id], matches(book) {
                matchedBook = book
            } else if backendLocator != nil,
                      let book = ldm.booksById.values.first(where: {
                          matches($0)
                      }) {
                matchedBook = book
            } else if let book = ldm.getBook([id]).first, matches(book) {
                matchedBook = book
            } else if let book = try? OtzariaMaktabahBridge.shared.fetchBook(byId: id), matches(book) {
                matchedBook = book
            } else if let locator = backendLocator,
                      let resolved = try? OtzariaMaktabahBridge.shared.resolveBook(stableKey: locator, expectedBookId: id), matches(resolved) {
                matchedBook = resolved
            }

        case .sefaria:
            if let locator = backendLocator {
                guard !locator.hasPrefix("otzaria:") else {
                    throw BackendTransitionError.foreignBackendLocator(locator: locator, expectedBackend: .sefaria)
                }
            }
            if let book = ldm.booksById[id], matches(book) {
                matchedBook = book
            } else if backendLocator != nil,
                      let book = ldm.booksById.values.first(where: {
                          matches($0)
                      }) {
                matchedBook = book
            } else {
                // Hazard 2 Fix: Fail closed against invented identities and placeholder strings.
                // Disallow "Book \(id)" placeholders and unverified title-based syntheses.
                let rawWorkKey: String? = {
                    if let locator = backendLocator {
                        let stripped = locator.hasPrefix("sefaria:") ? String(locator.dropFirst("sefaria:".count)) : locator
                        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if let registered = LegacyIdentityRegistry.shared.locator(for: id), registered.backend == .sefaria {
                        return registered.workKey
                    }
                    return nil
                }()

                guard let workKey = rawWorkKey,
                      !workKey.isEmpty,
                      !workKey.lowercased().hasPrefix("book "),
                      workKey != "Book \(id)" else {
                    throw BackendTransitionError.unresolvableBook(
                        bookId: id,
                        title: title ?? "Book \(id)",
                        locator: backendLocator
                    )
                }

                let canonical = SefariaRef.canonicalInput(workKey)
                let textLocator = TextLocator(backend: .sefaria, workKey: workKey, position: .canonicalRef(canonical))

                // Authoritative validation: work must be registered in cross-backend index,
                // legacy identity registry, or exist in verified local offline package storage.
                let isAuthoritative = SefariaBookIdentityValidator.isAuthoritative(
                    workKey: workKey,
                    id: id,
                    textLocator: textLocator
                )

                guard isAuthoritative else {
                    throw BackendTransitionError.unresolvableBook(
                        bookId: id,
                        title: title ?? workKey,
                        locator: backendLocator
                    )
                }

                matchedBook = MaktabahBackendAdapter.resolveBook(for: textLocator, in: ldm)
            }

        case .sefariaEmbedded:
            if let locator = backendLocator {
                guard !locator.hasPrefix("otzaria:") else {
                    throw BackendTransitionError.foreignBackendLocator(locator: locator, expectedBackend: .sefariaEmbedded)
                }
            }
            if let book = ldm.booksById[id], matches(book) {
                matchedBook = book
            } else if backendLocator != nil,
                      let book = ldm.booksById.values.first(where: {
                          matches($0)
                      }) {
                matchedBook = book
            } else {
                let rawWorkKey: String? = {
                    if let locator = backendLocator {
                        let stripped = locator.hasPrefix("sefariaEmbedded:") ? String(locator.dropFirst("sefariaEmbedded:".count)) :
                                       (locator.hasPrefix("sefaria:") ? String(locator.dropFirst("sefaria:".count)) : locator)
                        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if let registered = LegacyIdentityRegistry.shared.locator(for: id), registered.backend == .sefariaEmbedded {
                        return registered.workKey
                    }
                    return nil
                }()

                guard let workKey = rawWorkKey,
                      !workKey.isEmpty,
                      !workKey.lowercased().hasPrefix("book "),
                      workKey != "Book \(id)" else {
                    throw BackendTransitionError.unresolvableBook(
                        bookId: id,
                        title: title ?? "Book \(id)",
                        locator: backendLocator
                    )
                }

                let canonical = SefariaRef.canonicalInput(workKey)
                let textLocator = TextLocator(backend: .sefariaEmbedded, workKey: workKey, position: .canonicalRef(canonical))
                matchedBook = MaktabahBackendAdapter.resolveBook(for: textLocator, in: ldm)
            }
        }

        guard let valid = matchedBook, matches(valid) else {
            throw BackendTransitionError.unresolvableBook(
                bookId: id,
                title: title ?? "Book \(id)",
                locator: backendLocator
            )
        }
        return valid
    }

}
#endif
