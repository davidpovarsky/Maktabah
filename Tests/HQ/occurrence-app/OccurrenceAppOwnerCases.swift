import Foundation

enum OccurrenceAppOwnerCases {
    static func initialAndABA() throws {
        let owner = OtzariaDatabaseAccessController.occurrenceFixtureMake()
        let initial = owner.selectionObservation()
        try requireAppOccurrence(initial.url == nil && initial.source == nil && initial.revision == 0,
                                 "Private original initializer begins without a selection")
        let a = OccurrenceAppEnvironment.shared.root.appendingPathComponent("owner-A.db")
        let b = OccurrenceAppEnvironment.shared.root.appendingPathComponent("owner-B.db")
        owner.occurrenceFixturePublish(url: a, source: .managedInternal)
        let before = owner.selectionObservation()
        owner.occurrenceFixturePublish(url: b, source: .externalBookmark)
        let middle = owner.selectionObservation()
        owner.occurrenceFixturePublish(url: a, source: .managedInternal)
        let after = owner.selectionObservation()
        try requireAppOccurrence(before.url == a && before.source == .managedInternal && before.revision == 1,
                                 "First publication uses the original owner")
        try requireAppOccurrence(middle.url == b && middle.source == .externalBookmark && middle.revision == 2,
                                 "Second publication is a coherent original observation")
        try requireAppOccurrence(after.url == before.url && after.source == before.source &&
                                 after.revision == 3 && after != before,
                                 "A -> B -> A cannot revive old selection authority")
        owner.occurrenceFixturePublish(url: nil, source: nil)
        let cleared = owner.selectionObservation()
        try requireAppOccurrence(cleared.url == nil && cleared.source == nil && cleared.revision == 4 &&
                                 owner.currentURL == nil && owner.source == nil,
                                 "Clear publication and original getters use the same owner")
    }

    static func sameSelectionStillPublishes() throws {
        let owner = OtzariaDatabaseAccessController.occurrenceFixtureMake()
        let a = OccurrenceAppEnvironment.shared.root.appendingPathComponent("owner-A.db")
        owner.occurrenceFixturePublish(url: a, source: .managedInternal)
        let before = owner.selectionObservation()
        owner.occurrenceFixturePublish(url: a, source: .managedInternal)
        let after = owner.selectionObservation()
        try requireAppOccurrence(after.url == before.url && after.source == before.source &&
                                 after.revision == before.revision + 1 && after != before,
                                 "Explicit owner publication revokes prior authority even for the same pair")
    }

    static func concurrentPublication() async throws {
        let owner = OtzariaDatabaseAccessController.occurrenceFixtureMake()
        let a = OccurrenceAppEnvironment.shared.root.appendingPathComponent("owner-A.db")
        let b = OccurrenceAppEnvironment.shared.root.appendingPathComponent("owner-B.db")
        let writerCount = 8
        let publications = 2_000
        let readerCount = 4
        let observations = 6_000
        let failures = await withTaskGroup(of: Int.self, returning: Int.self) { group in
            for writer in 0..<writerCount {
                group.addTask {
                    for value in 0..<publications {
                        switch (value + writer) % 3 {
                        case 0: owner.occurrenceFixturePublish(url: a, source: .managedInternal)
                        case 1: owner.occurrenceFixturePublish(url: b, source: .externalBookmark)
                        default: owner.occurrenceFixturePublish(url: nil, source: nil)
                        }
                    }
                    return 0
                }
            }
            for _ in 0..<readerCount {
                group.addTask {
                    var invalid = 0
                    var previous: UInt64 = 0
                    for _ in 0..<observations {
                        let value = owner.selectionObservation()
                        let coherent = (value.url == a && value.source == .managedInternal) ||
                            (value.url == b && value.source == .externalBookmark) ||
                            (value.url == nil && value.source == nil)
                        if !coherent || value.revision < previous { invalid += 1 }
                        previous = value.revision
                    }
                    return invalid
                }
            }
            var total = 0
            for await invalid in group { total += invalid }
            return total
        }
        try requireAppOccurrence(failures == 0, "24,000 original owner snapshots must contain no torn pair/revision reversal")
        try requireAppOccurrence(owner.selectionObservation().revision == UInt64(writerCount * publications),
                                 "16,000 actual original publications must not lose increments")
    }
}
