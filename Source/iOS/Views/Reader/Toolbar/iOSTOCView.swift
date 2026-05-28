//
//  iOSTOCView.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 28/05/26.
//

import SwiftUI

struct iOSTOCView: View {
    let nodes: [TOCNode]
    let selectedId: Int?
    let onSelect: (Int) -> Void
    @Environment(\.presentationMode) var presentationMode

    @State private var expandedPaths: Set<Int> = []
    @State private var searchText = ""

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

    func computeExpandedPaths() -> Set<Int> {
        guard let targetId = selectedId else { return [] }
        var paths = Set<Int>()

        func search(nodes: [TOCNode], path: [Int]) -> Bool {
            for node in nodes {
                if node.id == targetId {
                    paths.formUnion(path)
                    return true
                }
                if !node.children.isEmpty {
                    if search(nodes: node.children, path: path + [node.id]) {
                        paths.formUnion(path)
                        return true
                    }
                }
            }
            return false
        }

        _ = search(nodes: nodes, path: [])
        return paths
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ThemeList(isGrouped: true) {
                    ForEach(identifiableNodes) { item in
                        TOCNodeRow(
                            item: item,
                            selectedId: selectedId,
                            onSelect: onSelect,
                            expandedPaths: $expandedPaths
                        )
                    }
                }
                .searchable(text: $searchText, prompt: "Search Contents")
                .navigationTitle("Table of Contents")
                .navigationBarItems(
                    leading: Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
                .onAppear {
                    expandedPaths = computeExpandedPaths()
                    if let selectedId {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation {
                                proxy.scrollTo(selectedId, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}
