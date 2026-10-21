//
//  BooksData.swift
//  Maktabah
//

import Foundation

final class BooksData: Codable, Identifiable, @unchecked Sendable {
    let id: Int
    let book: String
    let normalizedBook: String

    let archive: Int
    let muallif: Int
    /// Canonical, source-qualified identity for non-legacy backends.
    var backendLocator: TextLocator?
    /// Backend-native search path (for example Sefaria's catalog `path` filter).
    var backendSearchPath: String?
    var catId: Int?
    var downloadFilename: String?
    var compressedDownloadSize: Int64?
    var tafseerNam: String?
    var pdfCs: Int?
    var orderIndex: Int?
    var totalLines: Int?
    var isMultiLanguage: Bool {
        pdfCs == 3
    }

    var isImported: Bool {
        pdfCs == 4
    }

    var bithoqoh: String = .init() {
        didSet {
            bithoqoh = bithoqoh.convertToArabicDigits()
        }
    }

    var info: String = .init() {
        didSet {
            info = info.convertToArabicDigits()
        }
    }

    var isChecked: Bool = true

    init(
        id: Int,
        book: String,
        archive: Int,
        muallif: Int,
        bithoqoh: String = "",
        info: String = "",
        backendLocator: TextLocator? = nil,
        backendSearchPath: String? = nil
    ) {
        self.id = id
        self.book = StringInterner.shared.intern(book)
        normalizedBook = book.normalizeArabic(false)
        self.archive = archive
        self.muallif = muallif
        self.backendLocator = backendLocator
        self.backendSearchPath = backendSearchPath
        self.bithoqoh = bithoqoh.convertToArabicDigits()
        self.info = info.convertToArabicDigits()
    }
}
