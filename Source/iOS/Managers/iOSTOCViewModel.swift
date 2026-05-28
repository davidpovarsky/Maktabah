//
//  iOSTOCViewModel.swift
//  Maktabah
//

import SwiftUI

@MainActor
@Observable
class iOSTOCViewModel {
    let nodes: [TOCNode]
    let selectedId: Int?

    var expandedPaths: Set<ObjectIdentifier> = []
    var searchText = ""

    init(nodes: [TOCNode], selectedId: Int?) {
        self.nodes = nodes
        self.selectedId = selectedId
    }

    var identifiableNodes: [iOSIdentifiableTOCNode] {
        if searchText.isEmpty {
            return nodes.map { iOSIdentifiableTOCNode($0) }
        } else {
            let normalizedQuery = searchText.normalizeArabic(true)

            func searchAndFlatten(nodes: [TOCNode]) -> [TOCNode] {
                var matches: [TOCNode] = []
                for node in nodes {
                    if node.bab.normalizeArabic(true).localizedStandardContains(
                        normalizedQuery
                    ) {
                        let flatNode = TOCNode(
                            from: TOC(
                                bab: node.bab,
                                level: node.level,
                                sub: node.sub,
                                id: node.id
                            )
                        )
                        matches.append(flatNode)
                    }
                    matches.append(
                        contentsOf: searchAndFlatten(nodes: node.children)
                    )
                }
                return matches
            }

            return searchAndFlatten(nodes: nodes).map {
                iOSIdentifiableTOCNode($0)
            }
        }
    }

    func computeExpandedPaths() {
        guard let targetId = selectedId else { return }
        var paths = Set<ObjectIdentifier>()

        func search(nodes: [TOCNode], path: [ObjectIdentifier]) -> Bool {
            for node in nodes {
                let nodeId = ObjectIdentifier(node)
                if node.id == targetId {
                    paths.formUnion(path)
                    return true
                }
                if !node.children.isEmpty {
                    if search(nodes: node.children, path: path + [nodeId]) {
                        paths.formUnion(path)
                        return true
                    }
                }
            }
            return false
        }

        _ = search(nodes: nodes, path: [])
        expandedPaths = paths
    }
}
