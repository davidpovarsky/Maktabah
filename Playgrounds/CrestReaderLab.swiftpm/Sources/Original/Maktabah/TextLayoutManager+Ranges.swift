import UIKit

extension NSTextLayoutManager {
    func ensureFullDocumentLayout() {
        enumerateTextLayoutFragments(
            from: documentRange.location,
            options: [.ensuresLayout]
        ) { _ in true }
    }

    /// Memastikan layout TextKit 2 telah dikomputasi untuk rentang NSRange tertentu tanpa memblokir seluruh dokumen.
    func ensureLayout(for range: NSRange) {
        guard range.location >= 0, range.length > 0,
              let start = location(documentRange.location, offsetBy: range.location),
              let end = location(start, offsetBy: range.length),
              let textRange = NSTextRange(location: start, end: end)
        else { return }
        ensureLayout(for: textRange)
    }

    /// Memastikan layout TextKit 2 telah dikomputasi untuk sekumpulan rentang NSRange.
    func ensureLayout(for ranges: [NSRange]) {
        for range in ranges {
            ensureLayout(for: range)
        }
    }
}
