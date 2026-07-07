import Foundation

#if os(iOS)
enum OtzariaTextViewLineSelectionAdapter {
    static func sourceCharacterIndex(
        forDisplayedIndex displayedIndex: Int,
        sourceText: String,
        showHarakat: Bool
    ) -> Int {
        guard !showHarakat else { return displayedIndex }

        var displayedOffset = 0
        var sourceOffset = 0

        for scalar in sourceText.unicodeScalars {
            let scalarLength = String(scalar).utf16.count
            if scalar.isArabicHarakat {
                sourceOffset += scalarLength
                continue
            }

            if displayedOffset >= displayedIndex {
                return sourceOffset
            }

            displayedOffset += scalarLength
            sourceOffset += scalarLength
        }

        return sourceOffset
    }
}
#endif
