//
//  TOCNode.swift
//  Maktabah
//

import Foundation

final class TOCNode: Identifiable, @unchecked Sendable {
    let bab: String
    let level: Int
    let sub: Int
    let id: Int
    let entryId: Int
    let parentId: Int?
    var children: [TOCNode] = []
    /// Canonical locator for backend-originated nodes. When present,
    /// navigation should use this directly instead of the legacy integer ``id``.
    var backendLocator: TextLocator?

    var endID: Int = .max

    init(from toc: TOC) {
        bab = toc.bab.convertToArabicDigits()
        level = toc.level
        sub = toc.sub
        id = toc.id
        entryId = toc.entryId
        parentId = toc.parentId
    }

    /// Backend initializer — preserves title verbatim without Arabic digit conversion.
    /// Used for Sefaria/Otzaria TOC entries whose titles must remain as-is.
    init(backendTitle: String, level: Int, sub: Int, id: Int, parentId: Int? = nil, entryId: Int? = nil) {
        bab = backendTitle
        self.level = level
        self.sub = sub
        self.id = id
        self.entryId = entryId ?? id
        self.parentId = parentId
    }
}
