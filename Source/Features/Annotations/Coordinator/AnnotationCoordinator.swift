//
//  AnnotationCoordinator.swift
//  Maktabah
//
//  Created by MacBook on 27/01/26.
//

import Foundation

enum AnnotationCreationError: LocalizedError, Equatable {
    case missingBook
    case invalidRange(location: Int, length: Int, sourceLength: Int)

    var errorDescription: String? {
        switch self {
        case .missingBook:
            String(localized: "No book is open for annotation.")
        case .invalidRange:
            String(localized: "The selected text is no longer available. Select it again and retry.")
        }
    }
}

struct SaveHighlightParams {
    let text: String
    let range: NSRange
    let color: PlatformColor
    let bkId: Int
    let contentId: Int
    let page: Int
    let part: Int
    var diacriticsText: String?
    var showHarakat: Bool = false
    var mode: AnnotationMode = .highlight
    var backendLocator: TextLocator? = nil
}

class AnnotationCoordinator {
    private let store = AnnotationStore.shared

    /// Cari anotasi yang range-nya MATCH EXACTLY atau CONTAIN selection
    /// Prioritas: range yang paling kecil dulu (paling spesifik)
    func findAnnotation(
        at charIndex: Int,
        bkId: Int,
        contentId: Int,
        showHarakat: Bool
    ) -> Annotation? {
        let anns = store.loadAnnotations(bkId: bkId, contentId: contentId)

        for ann in anns.reversed() {
            let range = showHarakat ? ann.rangeDiacritics : ann.range
            if NSLocationInRange(charIndex, range) {
                return ann
            }
        }

        return nil
    }

    func findBestAnnotation(
        overlapping selectionRange: NSRange,
        bkId: Int,
        contentId: Int,
        showHarakat: Bool
    ) -> Annotation? {
        let anns = store.loadAnnotations(bkId: bkId, contentId: contentId)

        // Cari yang fully contain selection (paling spesifik)
        var candidates: [Annotation] = []

        for ann in anns {
            let range = showHarakat ? ann.rangeDiacritics : ann.range
            if range.contains(selectionRange) {
                candidates.append(ann)
            }
        }

        if !candidates.isEmpty {
            return candidates.min { ann1, ann2 in
                let r1 = showHarakat ? ann1.rangeDiacritics : ann1.range
                let r2 = showHarakat ? ann2.rangeDiacritics : ann2.range
                return r1.length < r2.length
            }
        }

        // Fallback: cari yang punya overlap terbesar
        return findLargestOverlap(in: anns, with: selectionRange, showHarakat: showHarakat)
    }

    func findBestAnnotation(
        overlapping selectionRange: NSRange,
        in annotations: [Annotation],
        showHarakat: Bool
    ) -> Annotation? {
        let containing = annotations.filter { annotation in
            let range = showHarakat ? annotation.rangeDiacritics : annotation.range
            return range.contains(selectionRange)
        }
        if let best = containing.min(by: { left, right in
            let leftRange = showHarakat ? left.rangeDiacritics : left.range
            let rightRange = showHarakat ? right.rangeDiacritics : right.range
            return leftRange.length < rightRange.length
        }) {
            return best
        }
        return findLargestOverlap(in: annotations, with: selectionRange, showHarakat: showHarakat)
    }

    @discardableResult
    @discardableResult
    func saveHighlight(
        text: String,
        range: NSRange,
        color: PlatformColor,
        bkId: Int,
        contentId: Int,
        page: Int,
        part: Int,
        diacriticsText: String?,
        showHarakat: Bool,
        mode: AnnotationMode = .highlight,
        backendLocator: TextLocator? = nil
    ) throws -> Annotation {
        let params = SaveHighlightParams(
            text: text,
            range: range,
            color: color,
            bkId: bkId,
            contentId: contentId,
            page: page,
            part: part,
            diacriticsText: diacriticsText,
            showHarakat: showHarakat,
            mode: mode,
            backendLocator: backendLocator
        )
        return try saveHighlight(params)
    }

    func makeAnnotation(
        text: String,
        range: NSRange,
        color: PlatformColor,
        bkId: Int,
        contentId: Int,
        page: Int,
        part: Int,
        diacriticsText: String?,
        showHarakat: Bool,
        mode: AnnotationMode = .highlight,
        backendLocator: TextLocator? = nil
    ) throws -> Annotation {
        let sourceLength = (text as NSString).length
        guard range.location != NSNotFound,
              range.length > 0,
              range.location <= sourceLength,
              range.length <= sourceLength - range.location else {
            throw AnnotationCreationError.invalidRange(
                location: range.location,
                length: range.length,
                sourceLength: sourceLength
            )
        }
        let calculator = ArabicRangeCalculator()
        let ranges = calculator.calculateRanges(
            for: range,
            in: text,
            selectedText: (text as NSString).substring(with: range),
            diacriticsText: diacriticsText,
            showHarakat: showHarakat
        )
        return Annotation(
            id: nil,
            bkId: bkId,
            contentId: contentId,
            range: ranges.withoutDiacritics,
            rangeDiacritics: ranges.withDiacritics,
            colorHex: color.hexString(),
            type: mode,
            note: nil,
            createdAt: Int64(Date().timeIntervalSince1970),
            context: (text as NSString).substring(with: range),
            page: page,
            part: part,
            pageArb: String(page).convertToArabicDigits(),
            partArb: String(part).convertToArabicDigits(),
            backendLocator: backendLocator
        )
    }

    func saveHighlight(_ params: SaveHighlightParams) throws -> Annotation {
        let nsText = params.text as NSString
        let safeRange: NSRange
        if params.range.location != NSNotFound,
           params.range.location >= 0,
           params.range.location + params.range.length <= nsText.length
        {
            safeRange = params.range
        } else {
            safeRange = NSRange(location: 0, length: 0)
        }
        let selectedSnippet = safeRange.length > 0 ? nsText.substring(with: safeRange) : ""
        let calculator = ArabicRangeCalculator()
        let ranges = calculator.calculateRanges(
            for: safeRange,
            in: params.text,
            selectedText: selectedSnippet,
            diacriticsText: params.diacriticsText,
            showHarakat: params.showHarakat
        )

        let hex = params.color.hexString()

        var ann = Annotation(
            id: nil,
            bkId: params.bkId,
            contentId: params.contentId,
            range: ranges.withoutDiacritics,
            rangeDiacritics: ranges.withDiacritics,
            colorHex: hex,
            type: params.mode,
            note: nil,
            createdAt: Int64(Date().timeIntervalSince1970),
            context: selectedSnippet,
            page: params.page,
            part: params.part,
            pageArb: String(params.page).convertToArabicDigits(),
            partArb: String(params.part).convertToArabicDigits(),
            backendLocator: params.backendLocator
        )

        let id = try store.addAnnotation(ann)
        ann.id = id
        return ann
    }

    // Similar methods for underline, note, delete...

    private func findLargestOverlap(
        in annotations: [Annotation],
        with range: NSRange,
        showHarakat: Bool
    ) -> Annotation? {
        var bestAnnotation: Annotation? = nil
        var bestOverlapLength = 0

        for ann in annotations {
            let annRange = showHarakat ? ann.rangeDiacritics : ann.range
            let intersection = NSIntersectionRange(annRange, range)

            guard intersection.length > 0 else { continue }

            if intersection.length > bestOverlapLength ||
                (intersection.length == bestOverlapLength && annRange.length < (bestAnnotation.flatMap { showHarakat ? $0.rangeDiacritics.length : $0.range.length } ?? Int.max))
            {
                bestOverlapLength = intersection.length
                bestAnnotation = ann
            }
        }

        return bestAnnotation
    }
}

/// ArabicRangeCalculator.swift - NEW FILE
struct ArabicRangeCalculator {
    func calculateRanges(
        for selection: NSRange,
        in text: String,
        selectedText: String,
        diacriticsText: String?,
        showHarakat: Bool
    ) -> (withDiacritics: NSRange, withoutDiacritics: NSRange) {
        if showHarakat {
            // Saat ini tampil dengan harakat
            let rangeWithDiacritics = selection
            let textNoDiac = text.normalizedForMatching()
            let rangeWithoutDiacritics = textNoDiac.calculateRangeWithoutHarakat(from: selection, in: text)

            return (rangeWithDiacritics, rangeWithoutDiacritics)
        } else {
            // Saat ini tampil tanpa harakat
            let rangeWithoutDiacritics = selection

            if let diacText = diacriticsText?
                .convertToArabicDigits()
                .stripSpanTags()
                .cleanedText()
            {
                let rangeWithDiacritics = diacText.findRangeInOriginal(
                    selectedText: selectedText,
                    approximateRange: selection
                )
                return (rangeWithDiacritics, rangeWithoutDiacritics)
            } else {
                return (selection, selection)
            }
        }
    }
}

/// Helper extension
extension NSRange {
    func contains(_ other: NSRange) -> Bool {
        location <= other.location &&
            location + length >= other.location + other.length
    }
}
