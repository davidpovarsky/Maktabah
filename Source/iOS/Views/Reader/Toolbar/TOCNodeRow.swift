//
//  TOCNodeRow.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 28/05/26.
//

import SwiftUI

struct TOCNodeRow: View {
    let item: iOSIdentifiableTOCNode
    let selectedId: Int?
    let onSelect: (Int) -> Void
    @Binding var expandedPaths: Set<Int>

    var isExpanded: Binding<Bool> {
        Binding(
            get: { expandedPaths.contains(item.id) },
            set: { isExpanding in
                if isExpanding {
                    expandedPaths.insert(item.id)
                } else {
                    expandedPaths.remove(item.id)
                }
            }
        )
    }

    var body: some View {
        if let children = item.children, !children.isEmpty {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(children) { child in
                    TOCNodeRow(
                        item: child,
                        selectedId: selectedId,
                        onSelect: onSelect,
                        expandedPaths: $expandedPaths
                    )
                }
            } label: {
                nodeLabel
            }
            .id(item.id)
        } else {
            nodeLabel
                .id(item.id)
        }
    }

    var nodeLabel: some View {
        Button(action: {
            onSelect(item.node.id)
        }) {
            Text(item.node.bab)
                .font(iOSReaderViewModel.kfgqpcTitle)
                .foregroundColor(
                    item.node.id == selectedId ? .accentColor : .primary
                )
        }
    }
}

#Preview {
    let mockNode = TOCNode(from: TOC(bab: "Chapter 1", level: 1, sub: 0, id: 1))
    let item = iOSIdentifiableTOCNode(mockNode)
    
    return TOCNodeRow(
        item: item,
        selectedId: 1,
        onSelect: { _ in },
        expandedPaths: .constant(Set([1]))
    )
    .padding()
}
