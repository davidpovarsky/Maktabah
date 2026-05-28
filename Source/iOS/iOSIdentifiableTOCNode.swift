//
//  iOSIdentifiableTOCNode.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 28/05/26.
//


// MARK: - TOC View

/// We need an identifiable wrapper for TOCNode to work nicely with SwiftUI List
struct iOSIdentifiableTOCNode: Identifiable {
    let id: Int
    let node: TOCNode
    var children: [iOSIdentifiableTOCNode]?

    init(_ node: TOCNode) {
        id = node.id
        self.node = node
        if !node.children.isEmpty {
            children = node.children.map { iOSIdentifiableTOCNode($0) }
        } else {
            children = nil
        }
    }
}