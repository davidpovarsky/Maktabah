import Foundation

/// Owned by one reader/tab. Editions never become part of a persisted locator.
struct OtzariaVersionSelectionStore {
    private var generation: UInt64?
    private var selections: [String: TextVersionMetadata] = [:]

    func selection(workKey: String, generation: UInt64) -> TextVersionMetadata? {
        self.generation == generation ? selections[workKey] : nil
    }

    mutating func select(_ version: TextVersionMetadata?, workKey: String, generation: UInt64) {
        if self.generation != generation {
            selections.removeAll()
            self.generation = generation
        }
        selections[workKey] = version
    }
}
