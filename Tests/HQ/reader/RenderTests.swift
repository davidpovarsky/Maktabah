import Foundation

@main struct RenderTests {
    static func main() {
        let texts = ["שָׁלוֹם 😀", "English e\u{301}", "مرحبا 👨‍👩‍👧‍👦", "<b>עברית</b><br>line", ""]
        let segments = texts.enumerated().map { index, text in
            LibraryTextSegment(locator: TextLocator(backend: .otzaria, workKey: "book:103", position: .legacyLine(100 + index)),
                heRef: nil, primaryText: text, translation: index == 0 ? "Hello 😀" : nil)
        }
        let section = LibraryTextSection(locator: segments[0].locator, displayRef: "fixture", heRef: nil, segments: segments,
            previous: nil, next: nil, versions: [
                TextVersionMetadata(title: "source", language: "he", actualLanguage: nil, sourceURL: nil, license: nil, notes: nil, isPrimary: true),
                TextVersionMetadata(title: "translation", language: "en", actualLanguage: nil, sourceURL: nil, license: nil, notes: nil, isPrimary: false)
            ], links: [], origin: .offline)
        for mode in [LibraryReaderTextMode.source, .translation, .both] {
            let rendered = LibraryReaderRenderModel(section: section, preferredMode: mode)
            let ns = rendered.text as NSString
            for mapping in rendered.renderedSegments {
                precondition(NSMaxRange(mapping.range) <= ns.length)
                precondition(NSMaxRange(mapping.visualRange) <= NSMaxRange(mapping.range))
                precondition(mapping.visualRange.location >= mapping.range.location)
                precondition(rendered.renderedSegment(at: mapping.rangeLocation)?.locator == mapping.locator)
                let selected = ns.substring(with: mapping.visualRange)
                switch mode {
                case .source: precondition(selected == mapping.segment.sourceText.readerPlainText)
                case .translation: precondition(selected == mapping.segment.translation!.readerPlainText)
                case .both:
                    precondition(selected.contains(mapping.segment.sourceText.readerPlainText))
                    if let translation = mapping.segment.translation { precondition(selected.contains(translation.readerPlainText)) }
                }
            }
        }
        // Fixed synthetic workload, cheap local timing only; no iPad/UI claim.
        var samples: [Double] = []
        for _ in 0..<5 {
            let big = LibraryTextSection(locator: section.locator, displayRef: "synthetic", heRef: nil,
                segments: (0..<200).map { segments[$0 % 4] }, previous: nil, next: nil, versions: section.versions, links: [], origin: .offline)
            let start = Date()
            let rendered = LibraryReaderRenderModel(section: big, preferredMode: .both)
            precondition(rendered.renderedSegments.count == 200)
            samples.append(Date().timeIntervalSince(start) * 1000)
        }
        samples.sort()
        print("render: PASS — actual UTF16 ranges, RTL/Arabic/combining/emoji, source/translation/both; 200-segment synthetic Windows p50=\(samples[2])ms max=\(samples.last!)ms")
    }
}
