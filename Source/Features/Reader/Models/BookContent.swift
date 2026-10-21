//
//  BookContent.swift
//  Maktabah
//

import Foundation

struct BookContent: Sendable {
    let id: Int
    let nash: String
    let page: Int
    let part: Int

    var surah: Int?
    var aya: Int?
    var heRef: String?
    var backendLocator: TextLocator?

    init(
        id: Int,
        nash: String,
        page: Int = 1,
        part: Int = 1,
        surah: Int? = nil,
        aya: Int? = nil,
        heRef: String? = nil,
        backendLocator: TextLocator? = nil
    ) {
        self.id = id
        self.nash = nash
        self.page = page
        self.part = part
        self.surah = surah
        self.aya = aya
        self.heRef = heRef
        self.backendLocator = backendLocator
    }
}
