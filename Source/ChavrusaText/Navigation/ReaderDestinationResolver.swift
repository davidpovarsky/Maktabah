//
//  ReaderDestinationResolver.swift
//  Maktabah
//
//  Downstream-owned destination resolver that resolves exact passage hits or citations
//  into a bounded canonical reading unit (sectionLocator) and an exact segment (focusLocator).
//

import Foundation

struct ResolvedReaderDestination: Equatable, Sendable {
    let destination: LibraryReaderDestination
    let isSegmentLevelFocus: Bool

    var sectionLocator: TextLocator { destination.sectionLocator }
    var focusLocator: TextLocator? { destination.focusLocator }

    init(destination: LibraryReaderDestination, isSegmentLevelFocus: Bool) {
        self.destination = destination
        self.isSegmentLevelFocus = isSegmentLevelFocus
    }
}

enum ReaderDestinationResolver: Sendable {
    /// Resolves an exact locator into a bounded reading unit and an optional focused segment.
    ///
    /// For Sefaria:
    /// - "Rashi on Berakhot 15b:3:1" -> section: "Rashi on Berakhot 15b", focus: "Rashi on Berakhot 15b:3:1"
    /// - "Genesis 1:3" -> section: "Genesis 1", focus: "Genesis 1:3"
    /// - "Berakhot 15b" -> section: "Berakhot 15b", focus: nil
    ///
    /// For Otzaria:
    /// - Line-anchored locator retains its bounded unit and segment focus.
    static func resolve(locator: TextLocator) -> ResolvedReaderDestination {
        switch locator.backend {
        case .sefaria, .sefariaEmbedded:
            guard case .canonicalRef(let rawRef) = locator.position else {
                return ResolvedReaderDestination(
                    destination: LibraryReaderDestination(sectionLocator: locator, focusLocator: nil),
                    isSegmentLevelFocus: false
                )
            }

            let canonical = SefariaRef.canonicalInput(rawRef)
            let ancestors = SefariaRef.sectionAncestors(of: canonical)

            // If ancestors has more than 1 entry, the last entry is the containing section
            if ancestors.count > 1, let boundedSectionRef = ancestors.last {
                let sectionLocator = TextLocator(
                    backend: locator.backend,
                    workKey: locator.workKey,
                    position: .canonicalRef(boundedSectionRef)
                )
                let destination = LibraryReaderDestination(
                    sectionLocator: sectionLocator,
                    focusLocator: locator
                )
                return ResolvedReaderDestination(destination: destination, isSegmentLevelFocus: true)
            } else {
                // Already a section or root
                return ResolvedReaderDestination(
                    destination: LibraryReaderDestination(sectionLocator: locator, focusLocator: nil),
                    isSegmentLevelFocus: false
                )
            }

        case .otzaria:
            switch locator.position {
            case .legacyLine:
                // Otzaria line-level citation
                let destination = LibraryReaderDestination(
                    sectionLocator: locator,
                    focusLocator: locator
                )
                return ResolvedReaderDestination(destination: destination, isSegmentLevelFocus: true)
            case .canonicalRef:
                return ResolvedReaderDestination(
                    destination: LibraryReaderDestination(sectionLocator: locator, focusLocator: nil),
                    isSegmentLevelFocus: false
                )
            }
        }
    }

    /// Resolves destination from an optional backend locator (e.g. from a search hit item).
    static func resolve(backendLocator: TextLocator?) -> ResolvedReaderDestination? {
        guard let backendLocator else { return nil }
        return resolve(locator: backendLocator)
    }
}
