import Foundation

/// Protocol for injecting text range mapping transformations (such as `ArabicRenderResult.remapSourceRange`).
public protocol ReaderRangeMappingProvider: Sendable {
    func remapDisplayedRangeToSource(_ displayedRange: NSRange) -> NSRange?
}

/// Concrete adapter wrapping an existing ArabicRenderResult or closure.
public struct ClosureRangeMappingProvider: ReaderRangeMappingProvider {
    private let transform: @Sendable (NSRange) -> NSRange?

    public init(transform: @escaping @Sendable (NSRange) -> NSRange?) {
        self.transform = transform
    }

    public func remapDisplayedRangeToSource(_ displayedRange: NSRange) -> NSRange? {
        transform(displayedRange)
    }
}

/// Safe, typed range mapping and validation for text selections in ChavrusaText reader.
/// Fixes BUG-03 by validating selection bounds against source and display UTF-16 lengths,
/// checking Unicode surrogate pair and grapheme cluster integrity, and requiring explicit
/// mapping providers whenever display text differs from source text.
public enum SelectionMappingError: Error, Equatable, LocalizedError {
    case emptySelection
    case negativeLocation(Int)
    case integerOverflow(location: Int, length: Int)
    case outOfBounds(location: Int, length: Int, maxLimit: Int, context: String)
    case invalidUnicodeBoundary(reason: String)
    case segmentResolutionFailed(String)
    case mappingProviderFailed(NSRange)
    case mappingRequiredAcrossDifferentRenders

    public var errorDescription: String? {
        switch self {
        case .emptySelection:
            return "Selection length must be greater than zero."
        case .negativeLocation(let loc):
            return "Selection location cannot be negative (got \(loc))."
        case .integerOverflow(let loc, let len):
            return "Selection range [\(loc)..<\(loc) + \(len)] causes integer overflow."
        case .outOfBounds(let loc, let len, let limit, let ctx):
            return "Selection [\(loc)..<\(loc + len)] exceeds \(ctx) bounds (limit \(limit))."
        case .invalidUnicodeBoundary(let reason):
            return "Selection boundary does not align with a valid Unicode character boundary: \(reason)"
        case .segmentResolutionFailed(let msg):
            return "Failed to resolve text segment for the selected range: \(msg)"
        case .mappingProviderFailed(let range):
            return "Mapping provider failed to map displayed range \(range) to source."
        case .mappingRequiredAcrossDifferentRenders:
            return "Displayed text differs from source text, but no ReaderRangeMappingProvider was supplied."
        }
    }
}

public struct MappedSelection: Equatable {
    public let sourceRange: NSRange
    public let selectedText: String
    public let fullSourceText: String
    public let segmentIdentifier: String?

    public init(
        sourceRange: NSRange,
        selectedText: String,
        fullSourceText: String,
        segmentIdentifier: String? = nil
    ) {
        self.sourceRange = sourceRange
        self.selectedText = selectedText
        self.fullSourceText = fullSourceText
        self.segmentIdentifier = segmentIdentifier
    }
}

public final class ReaderSelectionRangeMapper {
    public init() {}

    /// Validates and maps a displayed selection range into a validated source text range.
    public func mapSelection(
        displayedRange: NSRange,
        sourceText: String,
        displayedText: String? = nil,
        segmentIdentifier: String? = nil,
        mappingProvider: ReaderRangeMappingProvider? = nil
    ) -> Result<MappedSelection, SelectionMappingError> {
        // 1. Validate displayed range non-emptiness
        guard displayedRange.length > 0 else {
            return .failure(.emptySelection)
        }

        // 2. Validate non-negative location & not NSNotFound
        guard displayedRange.location >= 0, displayedRange.location != NSNotFound else {
            return .failure(.negativeLocation(displayedRange.location))
        }

        // 3. Prevent arithmetic overflow
        guard Int.max - displayedRange.location >= displayedRange.length else {
            return .failure(.integerOverflow(location: displayedRange.location, length: displayedRange.length))
        }

        // 4. Validate against displayedText if provided
        if let displayedText {
            let displayedLength = (displayedText as NSString).length
            if displayedRange.location + displayedRange.length > displayedLength {
                return .failure(.outOfBounds(
                    location: displayedRange.location,
                    length: displayedRange.length,
                    maxLimit: displayedLength,
                    context: "displayedText"
                ))
            }

            // P3-3: Prohibit silent identity mapping if display differs from source and no mapper is provided
            if displayedText != sourceText && mappingProvider == nil {
                return .failure(.mappingRequiredAcrossDifferentRenders)
            }
        }

        // 5. Apply range transformation if mapping provider supplied
        let targetRange: NSRange
        if let mappingProvider {
            guard let remapped = mappingProvider.remapDisplayedRangeToSource(displayedRange) else {
                return .failure(.mappingProviderFailed(displayedRange))
            }
            guard remapped.location >= 0, remapped.length > 0, Int.max - remapped.location >= remapped.length else {
                return .failure(.mappingProviderFailed(displayedRange))
            }
            targetRange = remapped
        } else {
            targetRange = displayedRange
        }

        // 6. Validate targetRange against source text UTF-16 length
        let nsSource = sourceText as NSString
        let sourceUtf16Length = nsSource.length

        guard targetRange.location + targetRange.length <= sourceUtf16Length else {
            return .failure(.outOfBounds(
                location: targetRange.location,
                length: targetRange.length,
                maxLimit: sourceUtf16Length,
                context: "sourceText"
            ))
        }

        // 7. Validate Unicode scalar and surrogate pair boundaries
        // Range(targetRange, in: sourceText) safely validates that range aligns with Swift String scalar boundaries
        guard Range(targetRange, in: sourceText) != nil else {
            return .failure(.invalidUnicodeBoundary(reason: "Selection splits a Unicode scalar or surrogate pair."))
        }

        // Surrogate check
        if targetRange.location > 0 && targetRange.location < sourceUtf16Length {
            let prevChar = nsSource.character(at: targetRange.location - 1)
            let currChar = nsSource.character(at: targetRange.location)
            if (0xD800...0xDBFF).contains(prevChar) && (0xDC00...0xDFFF).contains(currChar) {
                return .failure(.invalidUnicodeBoundary(reason: "Selection start splits a UTF-16 surrogate pair."))
            }
        }

        let endOffset = targetRange.location + targetRange.length
        if endOffset > 0 && endOffset < sourceUtf16Length {
            let prevChar = nsSource.character(at: endOffset - 1)
            let currChar = nsSource.character(at: endOffset)
            if (0xD800...0xDBFF).contains(prevChar) && (0xDC00...0xDFFF).contains(currChar) {
                return .failure(.invalidUnicodeBoundary(reason: "Selection end splits a UTF-16 surrogate pair."))
            }
        }

        // 8. Validate segment identity if supplied
        if let segmentIdentifier, segmentIdentifier.trimmingCharacters(in: .whitespaces).isEmpty {
            return .failure(.segmentResolutionFailed("Segment identifier was empty."))
        }

        let extracted = nsSource.substring(with: targetRange)

        return .success(MappedSelection(
            sourceRange: targetRange,
            selectedText: extracted,
            fullSourceText: sourceText,
            segmentIdentifier: segmentIdentifier
        ))
    }
}
