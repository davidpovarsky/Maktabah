import Foundation

/// Keeps every raw engine hit paired with its presentation across pagination and regrouping.
struct OtzariaSearchResultIdentityStore<Presentation> {
    struct Record: Identifiable {
        let hit: OtzariaEngineSearchResult
        let item: Presentation
        var id: String { hit.stableIdentity }
    }
    private(set) var records: [Record] = []
    private(set) var consumedCount = 0

    mutating func apply(hits: [OtzariaEngineSearchResult], items: [Presentation], replacing: Bool) throws {
        guard hits.count == items.count, hits.allSatisfy({ !$0.filePath.isEmpty }) else {
            throw OtzariaSearchError.invalidEngineResponse("Search hit/presentation identity mismatch")
        }
        if replacing { records = []; consumedCount = 0 }
        var positions = Dictionary(uniqueKeysWithValues: records.enumerated().map { ($0.element.id, $0.offset) })
        for (hit, item) in zip(hits, items) {
            let record = Record(hit: hit, item: item)
            if let index = positions[record.id] { records[index] = record }
            else { positions[record.id] = records.count; records.append(record) }
        }
        consumedCount += hits.count
    }

    mutating func clear() { records = []; consumedCount = 0 }
}
