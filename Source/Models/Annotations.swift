//
//  Annotations.swift
//  annotations
//
//  Created by MacBook on 13/12/25.
//  Granular UI Update
//

#if canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
#elseif canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
#endif

extension RandomAccessCollection {
    /// Menentukan indeks di mana sebuah elemen harus disisipkan ke dalam koleksi
    /// yang sudah diurutkan agar urutan tetap terjaga. (O(log n))
    func insertionIndex<T>(
        for element: T,
        using areInIncreasingOrder: (Element, T) -> Bool
    ) -> Index {
        var low = startIndex
        var high = endIndex

        while low < high {
            let mid = index(low, offsetBy: distance(from: low, to: high) / 2)
            if areInIncreasingOrder(self[mid], element) {
                low = index(after: mid)
            } else {
                high = mid
            }
        }
        return low
    }
}

// MARK: - Models

enum AnnotationSortField: Int {
    case createdAt
    case context
    case page
    case part
}

enum AnnotationGroupingMode: Int {
    case book
    case tag
}

struct AnnotationSortOption {
    let field: AnnotationSortField
    let isAscending: Bool
}

struct Annotation {
    var id: Int64?            // nil sebelum disimpan
    let bkId: Int             // book id
    let contentId: Int        // BookContent.id
    var range: NSRange        // NSRange berbasis UTF-16 (NSString)
    var rangeDiacritics: NSRange
    var colorHex: String      // "#RRGGBB"
    var type: AnnotationMode          // "highlight" atau "underline"
    var note: String?         // catatan opsional
    let createdAt: Int64      // timestamp
    let context: String       // Konteks yang dianotasi
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

enum AnnotationNodeKind {
    case root
    case book
    case tag
    case untagged
    case annotation
}

final class AnnotationNode: Equatable, Hashable {
    var title: String
    var children: [AnnotationNode] = []
    var annotation: Annotation? // optional, kalau node ini representasi annotation
    var kind: AnnotationNodeKind

    init(
        title: String,
        kind: AnnotationNodeKind = .book,
        annotation: Annotation? = nil
    ) {
        self.title = title
        self.kind = kind
        self.annotation = annotation
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    static func == (lhs: AnnotationNode, rhs: AnnotationNode) -> Bool {
        lhs === rhs
    }
}

struct ContentKey: Hashable {
    let bkId: Int
    let contentId: Int
}

enum AnnotationMode: Int {
    case highlight
    case underline

    static func from(int: Int) -> AnnotationMode {
        return switch int {
        case 0: highlight
        case 1: underline
        default: highlight
        }
    }
}

extension PlatformColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 else { return nil }
        let scanner = Scanner(string: s)
        var hexNum: UInt64 = 0
        guard scanner.scanHexInt64(&hexNum) else { return nil }
        let r = CGFloat((hexNum & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hexNum & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(hexNum & 0x0000FF) / 255.0
        
        #if os(macOS)
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
        #else
        self.init(red: r, green: g, blue: b, alpha: 1.0)
        #endif
    }

    func hexString() -> String {
        let defaultColor = "#FF9300"
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        #if os(macOS)
        guard let rgb = self.usingColorSpace(.deviceRGB) else { return defaultColor }
        r = rgb.redComponent
        g = rgb.greenComponent
        b = rgb.blueComponent
        #else
        if !self.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return defaultColor
        }
        #endif

        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", ri, gi, bi)
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
        manager: AnnotationManager = .shared
    ) -> [Annotation] {
        let exact = manager.loadAnnotations(bkId: bookID, contentId: contentID)
        guard let locator, !text.isEmpty else { return exact }

        var byID = Dictionary(uniqueKeysWithValues: exact.compactMap { annotation in
            annotation.id.map { ($0, annotation) }
        })
        let source = text as NSString
        for annotation in manager.loadAnnotations(bkId: bookID) {
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

