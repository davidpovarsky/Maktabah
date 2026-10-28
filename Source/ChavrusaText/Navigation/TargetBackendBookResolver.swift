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
        var matchedBook: BooksData?

        switch backend {
        case .otzaria:
            if let locator = backendLocator {
                guard !locator.hasPrefix("sefaria:") else {
                    throw BackendTransitionError.foreignBackendLocator(locator: locator, expectedBackend: .otzaria)
                }
            }
            if let book = ldm.booksById[id] {
                matchedBook = book
            } else if let locator = backendLocator,
                      let book = ldm.booksById.values.first(where: {
                          $0.backendLocator?.workKey == locator ||
                          "\($0.backendLocator?.backend.rawValue ?? ""):\($0.backendLocator?.workKey ?? "")" == locator
                      }) {
                matchedBook = book
            } else if let book = ldm.getBook([id]).first {
                matchedBook = book
            } else if let book = try? OtzariaMaktabahBridge.shared.fetchBook(byId: id) {
                matchedBook = book
            } else if let locator = backendLocator,
                      let resolved = try? OtzariaMaktabahBridge.shared.resolveBook(stableKey: locator, expectedBookId: id) {
                matchedBook = resolved
            }

        case .sefaria:
            if let locator = backendLocator {
                guard !locator.hasPrefix("otzaria:") else {
                    throw BackendTransitionError.foreignBackendLocator(locator: locator, expectedBackend: .sefaria)
                }
            }
            if let book = ldm.booksById[id], book.backendLocator?.backend == .sefaria {
                matchedBook = book
            } else if let locator = backendLocator,
                      let book = ldm.booksById.values.first(where: {
                          $0.backendLocator?.workKey == locator && $0.backendLocator?.backend == .sefaria
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
            if let book = ldm.booksById[id], book.backendLocator?.backend == .sefariaEmbedded {
                matchedBook = book
            } else if let locator = backendLocator,
                      let book = ldm.booksById.values.first(where: {
                          $0.backendLocator?.workKey == locator && $0.backendLocator?.backend == .sefariaEmbedded
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

        guard let valid = matchedBook else {
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
