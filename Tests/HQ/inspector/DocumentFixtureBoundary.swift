// Only the document/bridge boundary is substituted. The entire production
// mapOtzariaDocument method, unit models and neutral section mapper are compiled.
// Text is deliberately plain; this does not test native rendering or ZSTD.
extension OtzariaReadingUnit {
    init(bookId: Int, sourceLineIndices: [Int], mode: OtzariaUnitMode = .chapter) {
        self.init(id: "fixture-unit", bookId: bookId, mode: mode, tocEntryId: nil,
                  title: "fixture", level: nil,
                  startLineIndex: sourceLineIndices.min() ?? 0,
                  endLineIndex: sourceLineIndices.max() ?? 0,
                  sourceLineIndices: sourceLineIndices,
                  lineAnchors: sourceLineIndices.map {
                      OtzariaLineAnchor(id: $0, bookId: bookId, lineIndex: $0, heRef: "fixture \($0)", text: "text \($0)", range: .init(location: 0, length: 4))
                  }, html: "", plainText: "fixture", heRef: "fixture")
    }
}

enum TorahError: Error { case invalidReference, noText, missingProvider }
struct TorahTextSegment: Sendable {
    let canonicalRef: String; let hebrewRef: String?; let text: String; let ordinal: Int
}
struct TorahTextVersionMetadata: Sendable {
    let language: String; let actualLanguage: String?; let versionTitle: String
    let license: String?; let direction: String
}
struct TorahTextDocument: Sendable {
    let providerID: String; let requestedRef: String; let canonicalRef: String
    let hebrewRef: String?; let sectionRef: String; let hebrewSectionRef: String?
    let segments: [TorahTextSegment]; let previousSectionRef: String?; let nextSectionRef: String?
    let version: TorahTextVersionMetadata; let rawProviderPayload: String?
}
struct FixtureBookMetadata { let title: String }
final class FixtureDocumentState: @unchecked Sendable {
    let lock = NSLock()
    private var calls: [(String, OtzariaUnitMode)] = []
    var onUnit: @Sendable () -> Void = {}
    func record(_ name: String, _ mode: OtzariaUnitMode) { lock.withLock { calls.append((name, mode)) } }
    var modes: [(String, OtzariaUnitMode)] { lock.withLock { calls } }
}
extension OtzariaMaktabahBridge {
    func bookMetadata(for bookID: Int) -> FixtureBookMetadata? { FixtureBookMetadata(title: "fixture") }
    func getReadingUnit(bookId: Int, containingLineIndex line: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        documentState.record("unit", mode)
        documentState.onUnit()
        return OtzariaReadingUnit(bookId: bookId, sourceLineIndices: [line, line + 2], mode: mode)
    }
    func getPreviousReadingUnitDescriptor(bookId: Int, beforeLineIndex line: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnitDescriptor? {
        documentState.record("previous", mode)
        return descriptor(bookId, line - documentAdjacentStep(mode), mode)
    }
    func getNextReadingUnitDescriptor(bookId: Int, afterLineIndex line: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnitDescriptor? {
        documentState.record("next", mode)
        return descriptor(bookId, line + documentAdjacentStep(mode), mode)
    }
    private func documentAdjacentStep(_ mode: OtzariaUnitMode) -> Int {
        switch mode { case .line: 1; case .paragraph: 10; case .chapter: 100 }
    }
    private func descriptor(_ bookID: Int, _ line: Int, _ mode: OtzariaUnitMode) -> OtzariaReadingUnitDescriptor {
        .init(id: "fixture-\(line)", bookId: bookID, mode: mode, tocEntryId: nil, title: nil, level: nil,
              startLineIndex: line, endLineIndex: line, sourceLineIndices: [line], heRef: nil)
    }
}
