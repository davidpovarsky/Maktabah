//
//  iOSIdentifiableTOCNode.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 28/05/26.
//

import Foundation

// MARK: - TOC View

/// We need an identifiable wrapper for TOCNode to work nicely with SwiftUI List
struct iOSIdentifiableTOCNode: Identifiable {
    let id: ObjectIdentifier
    let node: TOCNode
    var children: [iOSIdentifiableTOCNode]?

    init(_ node: TOCNode) {
        self.id = ObjectIdentifier(node)
        self.node = node
        if !node.children.isEmpty {
            children = node.children.map { iOSIdentifiableTOCNode($0) }
        } else {
            children = nil
        }
    }
}
