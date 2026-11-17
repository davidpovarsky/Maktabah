import Foundation

@main struct RenderTests {
    private struct CorpusBook: Decodable {
        struct Line: Decodable { let id: Int; let index: Int; let heRef: String?; let text: String }
        let bookID: Int
        let title: String
        let lines: [Line]
    }

    static func main() async throws {
        let normalizationCases = [
            ("  plain שָׁלוֹם 😀  ", "plain שָׁלוֹם 😀"),
            ("<BR />א<br>ב", "א\nב"),
            ("&lt;b&gt;literal&lt;/b&gt;", "<b>literal</b>"),
            ("&lt;br&gt;", "<br>"),
            ("&amp;lt;", "<"),
            ("&amp;nbsp;", "&nbsp;"),
            ("{p}a{ס}b", "a\nb"),
            ("{paragraph}", "{paragraph}"),
            ("<b>{p}&amp;</b>", "&")
        ]
        for (input, expected) in normalizationCases {
            precondition(input.readerPlainText == expected, "normalization order and literal escaped markup preserved")
        }
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
            let prepared = try await LibraryReaderRenderModel.prepare(section: section, preferredMode: mode)
            precondition(prepared == rendered, "background preprocessing preserves exact text, metadata and UTF16/RTL mappings")
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
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await LibraryReaderRenderModel.prepare(section: section, preferredMode: .both)
        }
        do {
            _ = try await cancelled.value
            preconditionFailure("cancelled preprocessing must not publish a partial or complete model")
        } catch is CancellationError {
            print("render-async: PASS — exact parity for all modes; already-cancelled request rejected")
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
        if CommandLine.arguments.count > 1 {
            let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
            let books = try JSONDecoder().decode([CorpusBook].self, from: data)
            for book in books {
                let source = book.lines.map { line in
                    LibraryTextSegment(locator: TextLocator(backend: .otzaria, workKey: "book:\(book.bookID)", position: .legacyLine(line.index)),
                        heRef: line.heRef, primaryText: line.text, translation: nil)
                }
                let genuine = LibraryTextSection(locator: source[0].locator, displayRef: book.title, heRef: nil,
                    segments: source, previous: nil, next: nil, versions: section.versions, links: [], origin: .offline)
                let expected = source.filter { !$0.sourceText.readerPlainText.isEmpty }
                var genuineSamples: [Double] = []
                for sample in 0..<5 {
                    let start = Date()
                    let rendered = LibraryReaderRenderModel(section: genuine, preferredMode: .source)
                    genuineSamples.append(Date().timeIntervalSince(start) * 1000)
                    if sample == 0 && CommandLine.arguments.count > 2 {
                        let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
                            .appendingPathComponent("\(book.bookID).txt")
                        try rendered.text.write(to: output, atomically: true, encoding: .utf8)
                    }
                    precondition(rendered.renderedSegments.map(\.locator) == expected.map(\.locator), "all nonempty genuine source locators retained in order")
                    let text = rendered.text as NSString
                    var previousEnd = 0
                    for mapping in rendered.renderedSegments {
                        precondition(mapping.range.location >= previousEnd && NSMaxRange(mapping.range) <= text.length)
                        precondition(text.substring(with: mapping.visualRange) == mapping.segment.sourceText.readerPlainText,
                            "genuine row content and Unicode visual range preserved")
                        previousEnd = NSMaxRange(mapping.range)
                    }
                }
                genuineSamples.sort()
                print("render-corpus: PASS book=\(book.bookID) sourceRows=\(source.count) visibleSegments=\(expected.count) Windows-neutral-model-only p50=\(genuineSamples[2])ms max=\(genuineSamples.last!)ms; no TextKit/iPad/Swift-ZSTD inference")
            }
        }
    }
}
