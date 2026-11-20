import Foundation

enum OccurrenceNativeCases {
    static func basic(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        let request = try OtzariaExactOccurrenceRequest(query: "משה", bookIds: [1])
        let count = try await fixture.engine.countExactTokenOccurrences(
            request: request, expectedSource: source
        )
        try requireOccurrence(count.occurrences == 2, "Expected two original token positions")
        try requireOccurrence(count.matchingLiveDocuments == 1, "Expected one live document")
        let legacy = try fixture.engine.search(.init(query: "משה", mode: .exact))
        try requireOccurrence(legacy.totalCount == 1 && legacy.results.count == 1,
                              "Unchanged Swift legacy search must count one document")
        let documentCount = try fixture.engine.documentCount()
        try requireOccurrence(documentCount == 1, "Original documentCount")
        let paths = try fixture.engine.indexedFilePaths()
        try requireOccurrence(paths.contains("otzaria-book:1"), "Original indexed-file ownership")
        try fixture.add(id: 2, text: "יהושע", author: "b")
        try fixture.engine.rollback()
        let afterRollback = try fixture.engine.documentCount()
        try requireOccurrence(afterRollback == 1, "Original rollback retained committed content")
    }

    static func normalization(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture(text: "מֹשֶׁה משה משהל")
        let result = try await fixture.engine.countExactTokenOccurrences(
            request: .init(query: "מֹשֶׁה"), expectedSource: source
        )
        try requireOccurrence(result.occurrences == 2 && result.proof.analyzedToken == "משה",
                              "Original Hebrew analyzer and exact prefix exclusion")
    }

    static func scopes(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        try fixture.add(id: 2, text: "משה", author: "b")
        try fixture.add(id: 3, text: "משה משה משה", author: "a")
        try fixture.engine.commit()
        let books = try await fixture.engine.countExactTokenOccurrences(
            request: .init(query: "משה", bookIds: [1, 2]), expectedSource: source
        )
        try requireOccurrence(books.occurrences == 3 && books.matchingLiveDocuments == 2,
                              "Original book dimension OR")
        let scoped = try await fixture.engine.countExactTokenOccurrences(
            request: .init(query: "משה", facets: ["/author/a"], bookIds: [1, 2]),
            expectedSource: source
        )
        try requireOccurrence(scoped.occurrences == 2 && scoped.matchingLiveDocuments == 1,
                              "Original cross-dimension facet AND")
    }

    static func byteExactScopes(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        try fixture.add(id: 2, text: "משה", author: "a\u{0301}")
        try fixture.add(id: 3, text: "משה משה", author: "á")
        try fixture.engine.commit()
        let first = try await fixture.engine.countExactTokenOccurrences(
            request: .init(query: "משה", facets: ["/author/a\u{0301}"]), expectedSource: source
        )
        let second = try await fixture.engine.countExactTokenOccurrences(
            request: .init(query: "משה", facets: ["/author/á"]), expectedSource: source
        )
        let both = try await fixture.engine.countExactTokenOccurrences(
            request: .init(query: "משה", facets: ["/author/a\u{0301}", "/author/á"]),
            expectedSource: source
        )
        try requireOccurrence(first.occurrences == 1 && second.occurrences == 2 &&
                              both.occurrences == 3 && both.proof.requestedFacets.count == 2,
                              "Byte-distinct original scopes must not collapse by Swift Unicode equality")
    }

    static func deletions(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture(text: "משה משה משה")
        try fixture.add(id: 2, text: "משה", author: "b")
        try fixture.engine.commit()
        try fixture.engine.optimize()
        let request = try OtzariaExactOccurrenceRequest(query: "משה")
        let before = try await fixture.engine.countExactTokenOccurrences(request: request, expectedSource: source)
        try fixture.engine.deleteFilePaths(["otzaria-book:1"])
        try fixture.engine.commit()
        let after = try await fixture.engine.countExactTokenOccurrences(request: request, expectedSource: source)
        try requireOccurrence(before.occurrences == 4 && after.occurrences == 1 &&
                              after.matchingLiveDocuments == 1, "Actual deleted postings exclusion")
        try requireOccurrence(before.proof.searcherGeneration != after.proof.searcherGeneration,
                              "Actual held snapshot changes after delete/commit")
        try requireOccurrence(after.proof.searcherGeneration.segments.contains { $0.deleteOpstamp != nil },
                              "Actual delete-opstamp proof retained")
    }

    static func zero(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        let result = try await fixture.engine.countExactTokenOccurrences(
            request: .init(query: "זרובבל"), expectedSource: source
        )
        try requireOccurrence(result.occurrences == 0 && result.matchingLiveDocuments == 0 &&
                              result.proof.exact, "Authoritative zero from complete original execution")
    }

    static func unsupported(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        for query in ["משה יהושע", ""] {
            let request = try OtzariaExactOccurrenceRequest(query: query)
            try await expectOccurrenceFailure(.unsupportedQuery) {
                try await fixture.engine.countExactTokenOccurrences(request: request, expectedSource: source)
            }
        }
    }

    static func budget(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        for limits in [
            OtzariaExactOccurrenceLimits(maxCandidateDocuments: 0),
            OtzariaExactOccurrenceLimits(maxPositions: 1),
            OtzariaExactOccurrenceLimits(maxPositionsPerDocument: 1),
            OtzariaExactOccurrenceLimits(maxSegments: 0),
        ] {
            let request = try OtzariaExactOccurrenceRequest(query: "משה", limits: limits)
            try await expectOccurrenceFailure(.budgetExceeded) {
                try await fixture.engine.countExactTokenOccurrences(request: request, expectedSource: source)
            }
        }
    }

    static func expired(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        try await expectOccurrenceFailure(.deadlineExceeded) {
            try await fixture.engine.countExactTokenOccurrences(
                request: .init(query: "משה", timeoutMs: 0), expectedSource: source
            )
        }
    }

    static func sourceMismatch(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        let wrong = try OtzariaExactOccurrenceSource(
            engineCommit: String(repeating: "0", count: 40),
            engineRepository: source.engineRepository, engineBranch: source.engineBranch,
            originalUpstreamBase: source.originalUpstreamBase,
            indexSchemaVersion: source.indexSchemaVersion,
            enginePackageVersion: source.enginePackageVersion
        )
        try await expectOccurrenceFailure(.sourceMismatch) {
            try await fixture.engine.countExactTokenOccurrences(
                request: .init(query: "משה"), expectedSource: wrong
            )
        }
        try requireOccurrence(fixture.engine.occurrenceTestPendingCount == 0,
                              "Wrong source cannot enqueue engine work")
    }

    static func oversizedEnvelope(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        // Valid scalar-count bounds, but JSON escaping exceeds the byte envelope.
        let request = try OtzariaExactOccurrenceRequest(
            query: "משה", facets: Array(repeating: String(repeating: "\0", count: 512), count: 200)
        )
        try await expectOccurrenceFailure(.requestTooLarge) {
            try await fixture.engine.countExactTokenOccurrences(request: request, expectedSource: source)
        }
        try requireOccurrence(fixture.engine.occurrenceTestPendingCount == 0,
                              "Oversized envelope cannot enqueue or retain a C request")
    }
}

enum OccurrenceDecoderCases {
    private static func object(_ result: OtzariaExactOccurrenceResult) -> [String: Any] {
        let proof = result.proof
        let segments: [[String: Any]] = proof.searcherGeneration.segments.map {
            ["segmentId": $0.segmentId, "deleteOpstamp": $0.deleteOpstamp.map { $0 as Any } ?? NSNull()]
        }
        return [
            "ok": true, "error": NSNull(), "value": [
                "occurrences": result.occurrences,
                "matchingLiveDocuments": result.matchingLiveDocuments,
                "proof": [
                    "requestToken": proof.requestToken, "countKind": proof.countKind, "exact": proof.exact,
                    "analyzedToken": proof.analyzedToken, "requestedFacets": proof.requestedFacets,
                    "searcherGeneration": ["generationId": proof.searcherGeneration.generationId, "segments": segments],
                    "liveIndexDocuments": proof.liveIndexDocuments, "indexSchemaVersion": proof.indexSchemaVersion,
                    "enginePackageVersion": proof.enginePackageVersion, "engineCommit": proof.engineCommit,
                    "engineRepository": proof.engineRepository, "engineBranch": proof.engineBranch,
                    "originalUpstreamBase": proof.originalUpstreamBase,
                ],
                "work": [
                    "visitedCandidateDocuments": result.work.visitedCandidateDocuments,
                    "inspectedPositions": result.work.inspectedPositions,
                    "visitedSegments": result.work.visitedSegments,
                ],
            ],
        ]
    }

    static func tamperedProof(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        let request = try OtzariaExactOccurrenceRequest(query: "משה")
        let genuine = try await fixture.engine.countExactTokenOccurrences(request: request, expectedSource: source)
        for mutation in 0..<7 {
            var envelope = object(genuine)
            var value = envelope["value"] as! [String: Any]
            var proof = value["proof"] as! [String: Any]
            switch mutation {
            case 0: proof["requestToken"] = genuine.proof.requestToken + 1
            case 1: proof["countKind"] = "matchingDocuments"
            case 2: proof["exact"] = false
            case 3: proof["requestedFacets"] = ["/book/unknown"]
            case 4: value["occurrences"] = UInt64(0)
            case 5: proof["engineCommit"] = String(repeating: "f", count: 40)
            default:
                var snapshot = proof["searcherGeneration"] as! [String: Any]
                snapshot["segments"] = [["segmentId": "not-an-original-segment", "deleteOpstamp": NSNull()]]
                proof["searcherGeneration"] = snapshot
            }
            value["proof"] = proof
            envelope["value"] = value
            let data = try JSONSerialization.data(withJSONObject: envelope)
            do {
                _ = try OtzariaExactOccurrenceWire.decode(
                    data, request: request, token: genuine.proof.requestToken, source: source
                )
                throw OccurrenceTestFailure(description: "Forged proof mutation \(mutation) was accepted")
            } catch let failure as OtzariaExactOccurrenceError {
                try requireOccurrence(failure == (mutation == 5 ? .sourceMismatch : .invalidResponse),
                                      "Unexpected forged-proof failure \(failure)")
            }
        }
    }

    static func integerPrecision(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        let request = try OtzariaExactOccurrenceRequest(query: "משה")
        let genuine = try await fixture.engine.countExactTokenOccurrences(request: request, expectedSource: source)
        var envelope = object(genuine)
        var value = envelope["value"] as! [String: Any]
        var proof = value["proof"] as! [String: Any]
        proof["requestToken"] = UInt64.max
        proof["searcherGeneration"] = [
            "generationId": UInt64.max,
            "segments": [["segmentId": genuine.proof.searcherGeneration.segments[0].segmentId,
                          "deleteOpstamp": UInt64.max]],
        ]
        value["proof"] = proof; envelope["value"] = value
        let decoded = try OtzariaExactOccurrenceWire.decode(
            JSONSerialization.data(withJSONObject: envelope), request: request, token: .max, source: source
        )
        try requireOccurrence(decoded.proof.requestToken == .max &&
                              decoded.proof.searcherGeneration.generationId == .max &&
                              decoded.proof.searcherGeneration.segments[0].deleteOpstamp == .max,
                              "UInt64 proof identifiers must never round through Double")
    }

    static func errorRedaction() throws {
        let data = Data(#"{"ok":false,"value":null,"error":{"code":"engine_error","message":"private/path/secret-query"}}"#.utf8)
        let error = OtzariaExactOccurrenceWire.creationFailure(data)
        try requireOccurrence(error == .engineFailure &&
                              !error.localizedDescription.contains("private") &&
                              !error.localizedDescription.contains("secret"),
                              "Native diagnostic strings must not become API error messages")
        let unknown = Data(#"{"ok":false,"value":null,"error":{"code":"private-arbitrary-error","message":"secret"}}"#.utf8)
        try requireOccurrence(OtzariaExactOccurrenceWire.creationFailure(unknown) == .invalidResponse,
                              "Unknown native code must not become an arbitrary API error")
    }

    static func requestBounds() throws {
        let attempts: [@Sendable () throws -> OtzariaExactOccurrenceRequest] = [
            { try .init(query: String(repeating: "א", count: 1_001)) },
            { try .init(query: "משה", facets: [""]) },
            { try .init(query: "משה", bookIds: Array(repeating: 1, count: 201)) },
            { try .init(query: "משה", timeoutMs: 60_001) },
            { try .init(query: "משה", limits: .init(maxPositions: 10_000_001)) },
        ]
        for attempt in attempts {
            do {
                _ = try attempt()
                throw OccurrenceTestFailure(description: "Invalid typed request accepted")
            } catch let failure as OtzariaExactOccurrenceError {
                try requireOccurrence(failure == .invalidRequest || failure == .invalidLimits,
                                      "Expected fixed input bound error")
            }
        }
    }
}
