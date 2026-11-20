import Foundation
import OtzariaActionCore

enum OccurrenceAppCounterCases {
    static func unopened(_ fixture: OccurrenceAppFixture, qualified: Bool) async throws {
        try fixture.restoreMetadata()
        let pathsBefore = Set(try FileManager.default.contentsOfDirectory(atPath: fixture.indexURL.path))
        try requireAppOccurrence(fixture.repository.observedOpenIndexDocumentCount(databasePath: fixture.databaseURL.path) == nil,
                                 "No engine is cached before app discovery")
        let readiness = await ActionLiveOccurrenceCounter.readiness(fixture.snapshot)
        try requireAppOccurrence(readiness == (qualified ? .ready : .unavailable),
                                 "Coverage-only readiness must reflect the real registry; facade separately requires a cached engine")
        try await requireNoScalarOrFail(fixture, expected: .incompleteCoverage)
        try requireAppOccurrence(fixture.repository.observedOpenIndexDocumentCount(databasePath: fixture.databaseURL.path) == nil,
                                 "Coverage discovery/count must not construct an original engine")
        try requireAppOccurrence(Set(try FileManager.default.contentsOfDirectory(atPath: fixture.indexURL.path)) == pathsBefore,
                                 "Unopened discovery/count must not create engine lock/metadata files")
    }

    private static func requireNoScalarOrFail(_ fixture: OccurrenceAppFixture,
                                              expected: ActionOccurrenceFailure) async throws {
        try await requireAppAsyncFailure(expected) {
            try await ActionLiveOccurrenceCounter.count(fixture.query(), invocation: fixture.invocation())
        }
    }

    static func selectionGuards(_ fixture: OccurrenceAppFixture) async throws {
        defer { try? fixture.restoreMetadata() }
        let selections: [(URL?, OtzariaDatabaseAccessController.Source?)] = [
            (nil, nil), (fixture.databaseURL, .externalBookmark),
            (fixture.directory.appendingPathComponent("custom.db"), .managedInternal)
        ]
        for (url, source) in selections {
            OtzariaDatabaseAccessController.shared.occurrenceFixturePublish(url: url, source: source)
            try await requireAppAsyncFailure(.incompleteCoverage) {
                try await ActionLiveOccurrenceCounter.count(fixture.query(), invocation: fixture.invocation())
            }
            try requireAppOccurrence(await ActionLiveOccurrenceCounter.readiness(fixture.snapshot) == .unavailable,
                                     "Unknown/external/noncanonical source cannot advertise complete coverage")
        }
    }

    static func backendGuards(_ fixture: OccurrenceAppFixture) async throws {
        for backend in [ActionBackendID.sefaria, .sefariaEmbedded] {
            let snapshot = ActionBackendSnapshot(backend: backend, generation: 1)
            try requireAppOccurrence(await ActionLiveOccurrenceCounter.readiness(snapshot) == .unavailable,
                                     "Foreign backend readiness unavailable")
            let invocation = ActionPortInvocation(requestId: UUID(), snapshot: snapshot,
                deadlineUptimeNanoseconds: (DispatchTime.now() + .seconds(2)).uptimeNanoseconds)
            try await requireAppAsyncFailure(.unsupportedQuery) {
                try await ActionLiveOccurrenceCounter.count(.init(backend: backend, text: "משה"),
                                                             invocation: invocation)
            }
        }
    }

    static func expired(_ fixture: OccurrenceAppFixture) async throws {
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: fixture.snapshot,
            deadlineUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds - 1)
        try await requireAppAsyncFailure(.deadlineExceeded) {
            try await ActionLiveOccurrenceCounter.count(fixture.query(), invocation: invocation)
        }
    }

    static func cancelled(_ fixture: OccurrenceAppFixture) async throws {
        let entered = DispatchSemaphore(value: 0)
        let resume = DispatchSemaphore(value: 0)
        let task = Task {
            entered.signal()
            let resumed = await appOccurrenceWait(resume, deadline: .now() + .seconds(3))
            try requireAppOccurrence(resumed, "Pre-cancel fixture barrier")
            try await requireAppAsyncFailure(.cancelled) {
                try await ActionLiveOccurrenceCounter.count(fixture.query(), invocation: fixture.invocation())
            }
        }
        guard await appOccurrenceWait(entered, deadline: .now() + .seconds(3)) else {
            resume.signal(); task.cancel()
            _ = try? await task.value
            throw OccurrenceAppFailure(description: "Pre-cancel task did not start")
        }
        task.cancel()
        resume.signal()
        try await task.value
    }

    static func metadata(_ fixture: OccurrenceAppFixture, kind: String) async throws {
        try fixture.restoreMetadata()
        defer { try? fixture.restoreMetadata() }
        let targets = [fixture.indexManifestURL, fixture.databaseManifestURL, fixture.identityURL]
        for target in targets {
            try fixture.restoreMetadata()
            switch kind {
            case "empty": try Data().write(to: target, options: .atomic)
            case "oversized": try Data(repeating: 0x20, count: 1_048_577).write(to: target, options: .atomic)
            case "malformed": try Data("{invalid-json".utf8).write(to: target, options: .atomic)
            case "directory":
                try FileManager.default.removeItem(at: target)
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
            case "missing": try FileManager.default.removeItem(at: target)
            default: throw OccurrenceAppFailure(description: "Unknown metadata case")
            }
            let observed = fixture.repository.resourceObservation(databasePath: fixture.databaseURL.path)
            if kind == "directory" || kind == "oversized" {
                try requireAppOccurrence(observed.fingerprint == nil,
                                         "Nonregular/oversized metadata must not yield a repository witness")
            }
            try requireAppOccurrence(await ActionLiveOccurrenceCounter.readiness(fixture.snapshot) == .unavailable,
                                     "Incomplete metadata must not advertise readiness")
            try await requireAppNoScalar {
                try await ActionLiveOccurrenceCounter.count(fixture.query(), invocation: fixture.invocation())
            }
        }
    }

    static func unqualifiedCachedEngineNotNeeded(_ fixture: OccurrenceAppFixture) async throws {
        try fixture.restoreMetadata()
        try requireAppOccurrence(OtzariaLexicalIndexReadCompatibility.qualifiedContract(
            manifest: fixture.mini, consumer: fixture.build) == nil, "This is the original OFF registry gate")
        try await requireAppAsyncFailure(.incompleteCoverage) {
            try await ActionLiveOccurrenceCounter.count(fixture.query(), invocation: fixture.invocation())
        }
    }
}
