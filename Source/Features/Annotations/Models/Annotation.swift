//
//  Annotation.swift
//  Maktabah
//

import Foundation

struct Annotation: Sendable, Equatable, Identifiable {
    var id: Int64? // nil sebelum disimpan
    let bkId: Int // book id
    let contentId: Int // BookContent.id
    var range: NSRange // NSRange berbasis UTF-16 (NSString)
    var rangeDiacritics: NSRange
    var colorHex: String // "#RRGGBB"
    var type: AnnotationMode // "highlight" atau "underline"
    var note: String? // catatan opsional
    let createdAt: Int64 // timestamp
    let context: String // Konteks yang dianotasi
    let page: Int
    let part: Int
    var pageArb: String?
    var partArb: String?
    var tags: [String] = []

    // CloudKit Sync Support
    var ckRecordId: String?
    var lastModified: Int64?
    var backendLocator: TextLocator? = nil
}

enum AnnotationMode: Int, Sendable, Equatable {
    case highlight
    case underline

    static func from(int: Int) -> AnnotationMode {
        switch int {
        case 0: highlight
        case 1: underline
        default: highlight
        }
    }
}

struct ContentKey: Hashable, Sendable {
    let bkId: Int
    let contentId: Int
}

extension Annotation {
    var stableId: Int64 {
        id ?? 0
    }

    var displayTitle: String {
        if let note, !note.isEmpty {
            return note
        }
        return context
    }
}

// MARK: - Cross-Backend Title Resolution

extension Annotation {
    var resolvedBookTitle: String {
        let locator = backendLocator ?? (bkId < 0 ? LegacyIdentityRegistry.shared.locator(for: bkId) : nil)
        if let locator {
            if let cached = LegacyIdentityRegistry.shared.title(for: locator) {
                return cached
            }
            if locator.backend == .sefaria {
                return locator.workKey
            }
            if locator.backend == .otzaria {
                let otzariaId = Self.extractOtzariaBookId(from: locator.workKey)
                if let otzariaId, let book = LibraryDataManager.shared.getBook([otzariaId]).first {
                    return book.book
                }
            }
        }
        if bkId > 0 {
            if let book = LibraryDataManager.shared.getBook([bkId]).first {
                return book.book
            }
            return "ספר #\(bkId)"
        }
        if let loc = LegacyIdentityRegistry.shared.locator(for: bkId) {
            if let cached = LegacyIdentityRegistry.shared.title(for: loc) {
                return cached
            }
            if loc.backend == .sefaria { return loc.workKey }
            if let otzariaId = Self.extractOtzariaBookId(from: loc.workKey),
               let book = LibraryDataManager.shared.getBook([otzariaId]).first {
                return book.book
            }
        }
        return "ספר לא מזוהה (\(bkId))"
    }

    static func extractOtzariaBookId(from workKey: String) -> Int? {
        if workKey.hasPrefix("book:") {
            return Int(workKey.dropFirst("book:".count))
        }
        return Int(workKey)
    }
}

enum CrossBackendAnnotationResolver {
    static func annotations(
        forBookID bookID: Int,
        contentID: Int,
        text: String,
        locator: TextLocator?,
        repository: AnnotationRepository = .shared
    ) -> [Annotation] {
        let exact = (try? repository.getAnnotations(bkId: bookID, contentId: contentID)) ?? []
        guard let locator, !text.isEmpty else { return exact }

        var byID = Dictionary(uniqueKeysWithValues: exact.compactMap { annotation in
            annotation.id.map { ($0, annotation) }
        })
        let source = text as NSString
        let allBookAnnotations = (try? repository.getAnnotations(bkId: bookID)) ?? []
        for annotation in allBookAnnotations {
            guard let id = annotation.id, byID[id] == nil,
                  let annotationLocator = annotation.backendLocator,
                  CrossBackendBookIdentityIndex.shared.areEquivalent(annotationLocator, locator),
                  !annotation.context.isEmpty else { continue }
            let exactMatch = source.range(of: annotation.context)
            let match = exactMatch.location == NSNotFound
                ? normalizedRange(of: annotation.context, in: text)
                : exactMatch
            guard match.location != NSNotFound else { continue }
            var rebased = annotation
            rebased.range = match
            rebased.rangeDiacritics = match
            byID[id] = rebased
        }
        return byID.values.sorted {
            if $0.range.location == $1.range.location { return ($0.id ?? 0) < ($1.id ?? 0) }
            return $0.range.location < $1.range.location
        }
    }

    static func normalizedRange(of needle: String, in text: String) -> NSRange {
        let normalizedNeedle = normalized(needle).text
        guard !normalizedNeedle.isEmpty else { return NSRange(location: NSNotFound, length: 0) }
        let haystack = normalized(text)
        let match = (haystack.text as NSString).range(of: normalizedNeedle)
        guard match.location != NSNotFound,
              match.location < haystack.offsets.count,
              NSMaxRange(match) <= haystack.offsets.count else {
            return NSRange(location: NSNotFound, length: 0)
        }
        let start = haystack.offsets[match.location]
        let end = NSMaxRange(match) == haystack.offsets.count
            ? (text as NSString).length
            : haystack.offsets[NSMaxRange(match)]
        return NSRange(location: start, length: max(0, end - start))
    }

    private static func normalized(_ value: String) -> (text: String, offsets: [Int]) {
        var output = ""
        var offsets: [Int] = []
        var originalOffset = 0
        for scalar in value.unicodeScalars {
            let length = scalar.utf16.count
            let isDirectionalControl = (0x202A...0x202E).contains(Int(scalar.value))
                || (0x2066...0x2069).contains(Int(scalar.value))
            if !CharacterSet.nonBaseCharacters.contains(scalar) && !isDirectionalControl {
                output.unicodeScalars.append(scalar)
                for _ in 0..<length { offsets.append(originalOffset) }
            }
            originalOffset += length
        }
        return (output.lowercased(), offsets)
    }
}
