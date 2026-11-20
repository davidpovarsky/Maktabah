import Foundation
import OtzariaActionCore

enum OccurrenceAppPolicyCases {
    static func source(_ fixture: OccurrenceAppFixture) throws {
        let build = fixture.build
        try requireAppOccurrence(build.upstreamCommit == ActionOccurrenceEvidence.requiredEngineRevision &&
                                 build.upstreamRepository == "davidpovarsky/otzaria_search_engine" &&
                                 build.upstreamBranch == "codex/otzaria-exact-occurrences-20261120",
                                 "Actual linked C build must report the owned fork revision truthfully")
        let source = try OtzariaExactOccurrenceSource(buildInfo: build,
            originalUpstreamBase: "265a14ea54f959a3e266d6e8acfa3a3b98101d68")
        try source.validate(buildInfo: OtzariaSearchEngineBridge.buildInfo())
        try requireAppOccurrence(fixture.mini.lexicalEngine.commit == "265a14ea54f959a3e266d6e8acfa3a3b98101d68" &&
                                 fixture.identity.upstreamCommit == fixture.mini.lexicalEngine.commit,
                                 "Installer identity must retain the original producer, not relabel the consumer")
    }
    static func originalProfile(_ fixture: OccurrenceAppFixture) throws {
        let profile = try OtzariaDataProfileRegistry.requireActiveProfile()
        try requireAppOccurrence(profile.profileID == "miniTest10" && profile.profileVersion == 6 &&
                                 Set(profile.bookIDs.map(UInt64.init)) == Set(fixture.oracle.bookIds) &&
                                 profile.sourceDatabase.databaseSHA256 == fixture.descriptor.databaseSHA256,
                                 "Complete original bundled profile must bind the independently verified corpus")
        try requireAppOccurrence(fixture.database.effectiveProfileID == "miniTest10" &&
                                 fixture.database.effectiveProfileVersion == 6,
                                 "The original installation model must receive the real original profile version")
    }
    static func authenticate(_ fixture: OccurrenceAppFixture) throws {
        try requireAppOccurrence(try ActionOccurrenceCoveragePolicy.authenticatedManifest(fixture.mini) ==
            "63fdf6750863292061ec1a4f73072355cf8f92c2a64ec7029b1ca895bb3135de", "Mini complete typed digest")
        try requireAppOccurrence(try ActionOccurrenceCoveragePolicy.authenticatedManifest(fixture.full) ==
            "c8c2a35a86bae5bf9012c71ac027078a25a5ff8ef584547965ad6ef41cd4db9f", "Full complete typed digest")
    }
    static func reencoding(_ fixture: OccurrenceAppFixture) throws {
        for manifest in [fixture.mini, fixture.full] {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let bytes = try encoder.encode(manifest)
            let decoded = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self, from: bytes)
            try requireAppOccurrence(decoded == manifest, "Original full Codable re-encoding must retain all modeled fields")
            let reencoded = try ActionOccurrenceCoveragePolicy.authenticatedManifest(decoded)
            try requireAppOccurrence(reencoded == ActionOccurrenceCoveragePolicy.digest(manifest),
                                     "Whitespace/key formatting is not a different typed artifact")
        }
    }
    static func tampering(_ fixture: OccurrenceAppFixture) throws {
        let mutations: [([String], OccurrenceJSONValue)] = [
            (["artifactIdentity"], .string(String(repeating: "0", count: 64))),
            (["formatVersion"], .integer(2)),
            (["profileID"], .string("production")),
            (["profileVersion"], .integer(7)),
            (["sourceDatabase", "databaseSHA256"], .string(String(repeating: "a", count: 64))),
            (["sourceDatabase", "databaseBytes"], .integer(15_470_593)),
            (["sourceDatabase", "documentCount"], .integer(18_878)),
            (["sourceDatabase", "releaseID"], .integer(409_213_894)),
            (["sourceDatabase", "sourceAssetDigest"], .string("sha256:" + String(repeating: "b", count: 64))),
            (["lexicalEngine", "commit"], .string(ActionOccurrenceEvidence.requiredEngineRevision)),
            (["lexicalEngine", "repository"], .string("davidpovarsky/otzaria_search_engine")),
            (["resources", "Vendor/OtzariaSearchEngine/Resources/dictionary.json", "bytes"], .integer(451_577)),
            (["resources", "Application Support/Otzaria/lexical.db", "version"], .string("v0.3.1")),
            (["lexicalArtifact", "catalogueHash"], .string("bcd31120e27e4588")),
            (["lexicalArtifact", "parts", "0", "destinationPath"], .string("../index")),
            (["lexicalArtifact", "parts", "0", "destinationOffset"], .integer(1)),
            (["lexicalArtifact", "parts", "0", "sha256"], .string(String(repeating: "c", count: 64))),
            (["lexicalArtifact", "segmentsAfterOptimize"], .integer(2)),
            (["lexicalArtifact", "sourceCount"], .integer(9)),
        ]
        for (path, value) in mutations {
            let changed: OtzariaSearchArtifactManifest = try occurrenceMutated(fixture.mini, path: path, value: value)
            try requireAppFailure(.incompleteCoverage) {
                try ActionOccurrenceCoveragePolicy.authenticatedManifest(changed)
            }
        }
        let semantic = #"{"sidecarRevision":"changed","modelRepository":"fixture","modelFilename":"model","modelSHA256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","modelBytes":1,"embeddingDimension":1,"recipeIdentity":"changed","storeFormatVersion":"1","vectorCount":1,"requiredLexicalArtifactIdentity":"08a5ddf76ae187e3ca29c1b483637f1dc8e2a2dcb7001cdb7fe3327236234e83","parts":[]}"#
        let added: OtzariaSearchArtifactManifest = try occurrenceMutated(fixture.mini, path: ["semantic"], value: .json(semantic))
        try requireAppFailure(.incompleteCoverage) { try ActionOccurrenceCoveragePolicy.authenticatedManifest(added) }
    }
    static func canonicalScopes() throws {
        let ids: [UInt64] = [1, 103, UInt64.max]
        let query = ActionOccurrenceQuery(backend: .otzaria, text: "משה",
            scopeWorkRefs: ids.map { .init(backend: .otzaria, workKey: "book:\($0)") })
        try requireAppOccurrence(try ActionOccurrenceCoveragePolicy.bookIDs(for: query) == ids,
                                 "Exact positive UInt64 identities and caller order survive unchanged")
        let twoHundred = ActionOccurrenceQuery(backend: .otzaria, text: "משה",
            scopeWorkRefs: (1...200).map { .init(backend: .otzaria, workKey: "book:\($0)") })
        try requireAppOccurrence(try ActionOccurrenceCoveragePolicy.bookIDs(for: twoHundred).count == 200,
                                 "The original 200-work boundary is accepted exactly")
        let tooMany = ActionOccurrenceQuery(backend: .otzaria, text: "משה",
            scopeWorkRefs: (1...201).map { .init(backend: .otzaria, workKey: "book:\($0)") })
        try requireAppFailure(.unsupportedQuery) { try ActionOccurrenceCoveragePolicy.bookIDs(for: tooMany) }
    }
    static func noncanonicalScopes() throws {
        for key in ["book:0", "book:01", "book:+1", "book:-1", "book:1 ", "book: 1",
                    "book:1.0", "book:18446744073709551616", "Book:1", "1", "", "book:١", "book:1/"] {
            let query = ActionOccurrenceQuery(backend: .otzaria, text: "משה",
                scopeWorkRefs: [.init(backend: .otzaria, workKey: key)])
            try requireAppFailure(.unsupportedQuery) { try ActionOccurrenceCoveragePolicy.bookIDs(for: query) }
        }
        let invalidReferenceSets: [[ActionWorkRef]] = [
            [.init(backend: .otzaria, workKey: "book:1"), .init(backend: .otzaria, workKey: "book:1")],
            [.init(backend: .sefaria, workKey: "book:1")],
            [.init(backend: .sefariaEmbedded, workKey: "book:1")]
        ]
        for refs in invalidReferenceSets {
            let query = ActionOccurrenceQuery(backend: .otzaria, text: "משה", scopeWorkRefs: refs)
            try requireAppFailure(.unsupportedQuery) { try ActionOccurrenceCoveragePolicy.bookIDs(for: query) }
        }
    }
    static func unsupportedQueries() throws {
        let queries: [ActionOccurrenceQuery] = [
            .init(backend: .sefaria, text: "משה"),
            .init(backend: .sefariaEmbedded, text: "משה"),
            .init(backend: .otzaria, text: "משה", matchMode: .hebrewLemmatized),
            .init(backend: .otzaria, text: "משה", countUnit: .matchingDocuments),
            .init(backend: .otzaria, text: "משה", countUnit: .matchingSegments),
            .init(backend: .otzaria, text: ""),
            .init(backend: .otzaria, text: " \n\t "),
            .init(backend: .otzaria, text: String(repeating: "א", count: 1_001))
        ]
        for query in queries {
            try requireAppFailure(.unsupportedQuery) { try ActionOccurrenceCoveragePolicy.bookIDs(for: query) }
        }
    }
    static func actualAdmission(_ fixture: OccurrenceAppFixture, qualified: Bool) throws {
        // This uses actual C build-info. Neither the test nor a manifest can add
        // a production registry entry or invent the third optional resource.
        try requireAppOccurrence(
            OtzariaLexicalIndexReadCompatibility.candidateContract(manifest: fixture.mini, consumer: fixture.build)
                == .original265ToExactOccurrencesD5,
            "The actual producer/consumer/resource projection must satisfy the reviewed candidate contract")
        try requireAppOccurrence(
            (OtzariaLexicalIndexReadCompatibility.qualifiedContract(manifest: fixture.mini, consumer: fixture.build) != nil)
                == qualified,
            "Expected qualification must match the actual compiled production registry")
        if qualified {
            let coverage = try fixture.validateCoverage()
            try requireAppOccurrence(coverage.expectedDocuments == 18_879 &&
                                     coverage.databaseSHA256 == fixture.descriptor.databaseSHA256 &&
                                     coverage.artifactIdentity == fixture.mini.artifactIdentity,
                                     "Actual admitted coverage retains the independent complete-source identity")
        } else {
            try requireAppFailure(.incompleteCoverage) { try fixture.validateCoverage() }
        }
    }
}
