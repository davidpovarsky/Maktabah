//
//  Annotations.swift
//  annotations
//
//  Created by MacBook on 13/12/25.
//  Granular UI Update
//

import Cocoa

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
    let rangeDiacritics: NSRange
    let colorHex: String      // "#RRGGBB"
    var type: AnnotationMode          // "highlight" atau "underline"
    let note: String?         // catatan opsional
    let createdAt: Int64      // timestamp
    let context: String       // Konteks yang dianotasi
    let page: Int
    let part: Int
    var pageArb: String?
    var partArb: String?
    var tags: [String] = []
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

extension NSColor {
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
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    func hexString() -> String {
        let defaultColor = "#FF9300"
        guard let rgb = self.usingColorSpace(.deviceRGB) else { return defaultColor }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
