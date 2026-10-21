//
//  ProcessedArabicContent.swift
//  Maktabah
//

#if canImport(AppKit)
import AppKit
#endif
import Foundation

final class ProcessedArabicContent {
    let sourceText: String
    let displayText: String
    let coloredRanges: [NSRange]
    let footnoteRanges: [NSRange]
    let replacementEvents: [HonorificReplacementEvent]
    let importedHeaderRanges: [NSRange]
    let ligatureRanges: [NSRange]
    let harakatEvents: [TextDeltaEvent]
    let cleaningEvents: [TextDeltaEvent]

    init(
        sourceText: String,
        displayText: String,
        coloredRanges: [NSRange],
        footnoteRanges: [NSRange],
        replacementEvents: [HonorificReplacementEvent],
        importedHeaderRanges: [NSRange],
        ligatureRanges: [NSRange],
        harakatEvents: [TextDeltaEvent] = [],
        cleaningEvents: [TextDeltaEvent] = []
    ) {
        self.sourceText = sourceText
        self.displayText = displayText
        self.coloredRanges = coloredRanges
        self.footnoteRanges = footnoteRanges
        self.replacementEvents = replacementEvents
        self.importedHeaderRanges = importedHeaderRanges
        self.ligatureRanges = ligatureRanges
        self.harakatEvents = harakatEvents
        self.cleaningEvents = cleaningEvents
    }
}
