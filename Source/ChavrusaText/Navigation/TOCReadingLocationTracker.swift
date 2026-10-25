//
//  TOCReadingLocationTracker.swift
//  Maktabah
//
//  Downstream-owned TOC tracking coordinator that maps the current reading unit locator
//  to the deepest visible TOC leaf or ancestor, keeping the sidebar selection in sync.
//

import Foundation

struct FlattenedTOCItem: Identifiable, Sendable {
    let id: Int
    let title: String
    let level: Int
    let locator: TextLocator?

    init(id: Int, title: String, level: Int, locator: TextLocator?) {
        self.id = id
        self.title = title
        self.level = level
        self.locator = locator
    }
}

enum TOCReadingLocationTracker: Sendable {
    /// Finds the deepest matching TOC node for the given reading unit locator.
    static func findMatchingNodeID(
        for locator: TextLocator,
        in flattenedNodes: [FlattenedTOCItem]
    ) -> Int? {
        guard !flattenedNodes.isEmpty else { return nil }

        // 1. Direct exact match
        if let exact = flattenedNodes.first(where: { $0.locator == locator }) {
            return exact.id
        }

        switch locator.backend {
        case .otzaria:
            // In Otzaria, nodes are indexed by line anchors (.legacyLine)
            guard case .legacyLine(let currentLine) = locator.position else {
                return nil
            }
            // Find all nodes that start at or before currentLine within the same work
            let eligible = flattenedNodes.compactMap { item -> (line: Int, level: Int, id: Int)? in
                guard let nodeLoc = item.locator,
                      nodeLoc.backend == .otzaria,
                      nodeLoc.workKey == locator.workKey,
                      case .legacyLine(let nodeLine) = nodeLoc.position,
                      nodeLine <= currentLine else {
                    return nil
                }
                return (line: nodeLine, level: item.level, id: item.id)
            }
            // Sort by: largest line first (closest heading), then deepest level
            return eligible.max(by: {
                if $0.line != $1.line {
                    return $0.line < $1.line
                }
                return $0.level < $1.level
            })?.id

        case .sefaria:
            // In Sefaria, nodes are canonical refs (.canonicalRef)
            guard case .canonicalRef(let currentRef) = locator.position else {
                return nil
            }
            let canonicalCurrent = SefariaRef.canonicalInput(currentRef)
            let ancestors = Set(SefariaRef.sectionAncestors(of: canonicalCurrent))

            // Find nodes whose locator ref structurally matches an ancestor
            // Eliminates unsafe loose prefix matching that conflates e.g. "Genesis 1" with "Genesis 10"
            let matchingAncestors = flattenedNodes.compactMap { item -> (level: Int, id: Int)? in
                guard let nodeLoc = item.locator,
                      nodeLoc.backend == .sefaria,
                      nodeLoc.workKey == locator.workKey,
                      case .canonicalRef(let nodeRef) = nodeLoc.position else {
                    return nil
                }
                let canonicalNode = SefariaRef.canonicalInput(nodeRef)
                let isStructuralMatch = ancestors.contains(canonicalNode)
                    || canonicalCurrent == canonicalNode
                    || canonicalCurrent.hasPrefix(canonicalNode + ":")
                    || canonicalCurrent.hasPrefix(canonicalNode + " ")
                if isStructuralMatch {
                    return (level: item.level, id: item.id)
                }
                return nil
            }
            // Return deepest matching ancestor
            return matchingAncestors.max(by: { $0.level < $1.level })?.id
        }
    }
}
