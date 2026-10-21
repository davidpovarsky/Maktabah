//
//  TOC.swift
//  Maktabah
//

import Foundation

struct TOC: Sendable {
    let bab: String // Memetakan ke kolom 'tit'
    let level: Int // Memetakan ke kolom 'lvl'
    let sub: Int
    let id: Int
    let entryId: Int
    let parentId: Int?

    init(bab: String, level: Int, sub: Int, id: Int, parentId: Int? = nil, entryId: Int? = nil) {
        self.bab = bab
        self.level = level
        self.sub = sub
        self.id = id
        self.entryId = entryId ?? id
        self.parentId = parentId
    }
}
