//
//  CleanedTextKey.swift
//  Maktabah
//

import Foundation

struct CleanedTextKey: Hashable {
    let showHarakat: Bool
    let isMultiLanguage: Bool
    let isImported: Bool
    let textHash: Int

    init(showHarakat: Bool, isMultiLanguage: Bool, isImported: Bool, textHash: Int = 0) {
        self.showHarakat = showHarakat
        self.isMultiLanguage = isMultiLanguage
        self.isImported = isImported
        self.textHash = textHash
    }
}
