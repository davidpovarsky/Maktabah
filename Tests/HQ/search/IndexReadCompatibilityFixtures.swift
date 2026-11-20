import Foundation

@main @MainActor struct IndexReadCompatibilityFixtures {
    static var results: [[String: String]] = []
    static var stateRoot: URL!
    static var mini: OtzariaSearchArtifactManifest!
    static var producer: OtzariaSearchEngineBuildInfo!
    static var consumer: OtzariaSearchEngineBuildInfo!
    static let manager = OtzariaSearchIndexManager.shared

    static func require(_ condition: Bool, _ detail: String) throws {
        if !condition { throw FixtureFailure.failed(detail) }
    }
    static func rejects(_ body: () throws -> Void) -> Bool {
        do { try body(); return false } catch { return true }
    }
    static func run(_ name: String, _ body: () async throws -> Void) async {
        do {
            try await body()
            results.append(["name": name, "outcome": "PASS"])
        } catch {
            results.append(["name": name, "outcome": "FAIL", "detail": String(describing: error)])
        }
    }
    static func mutate<T: Codable>(_ value: T, _ path: [String], _ replacement: Any) throws -> T {
        func set(_ input: Any, _ keys: ArraySlice<String>) throws -> Any {
            guard let key = keys.first else { return replacement }
            if var dictionary = input as? [String: Any] {
                dictionary[key] = try set(dictionary[key] ?? NSNull(), keys.dropFirst())
                return dictionary
            }
            if var array = input as? [Any], let index = Int(key), array.indices.contains(index) {
                array[index] = try set(array[index], keys.dropFirst())
                return array
            }
            throw FixtureFailure.failed("invalid fixture mutation path")
        }
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
        let changed = try set(object, path[...])
        return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: changed))
    }
    static func withoutResource(_ manifest: OtzariaSearchArtifactManifest, _ name: String) throws -> OtzariaSearchArtifactManifest {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(manifest)) as! [String: Any]
        var resources = object["resources"] as! [String: Any]
        resources.removeValue(forKey: name)
        object["resources"] = resources
        return try JSONDecoder().decode(OtzariaSearchArtifactManifest.self, from: JSONSerialization.data(withJSONObject: object))
    }
    static func database(_ manifest: OtzariaSearchArtifactManifest) throws -> OtzariaDatabaseInstallationManifest {
        let source = manifest.sourceDatabase
        var object: [String: Any] = ["repository": source.repository, "releaseID": source.releaseID,
            "releaseTag": source.releaseTag, "assetID": source.assetID, "assetName": source.assetName,
            "compressedSize": source.compressedBytes, "digest": source.sourceAssetDigest,
            "databaseFileSize": source.databaseBytes, "installedAt": "2026-11-20T00:00:00Z"]
        if let id = manifest.profileID { object["profileID"] = id }
        if let version = manifest.profileVersion { object["profileVersion"] = version }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OtzariaDatabaseInstallationManifest.self,
            from: JSONSerialization.data(withJSONObject: object))
    }
    static func build(_ manifest: OtzariaSearchArtifactManifest) -> OtzariaSearchEngineBuildInfo {
        let engine = manifest.lexicalEngine
        return .init(upstreamRepository: engine.repository, upstreamBranch: "main", upstreamCommit: engine.commit,
            engineVersion: engine.engineVersion, indexSchemaVersion: engine.indexSchemaVersion,
            defaultGenerationOrder: engine.defaultGenerationOrder, semanticEnabled: false,
            semanticSidecarRevision: engine.semanticSidecarRevision, syncedAt: "fixture",
            adapterVersion: engine.adapterVersion, resourceHashes: manifest.resources.mapValues(\.sha256))
    }
    static func activate(_ manifest: OtzariaSearchArtifactManifest) {
        OtzariaDataProfileRegistry.activeProfileID = manifest.effectiveProfileID
        OtzariaDataProfileRegistry.activeVersion = manifest.effectiveProfileVersion
    }
    static func probe(_ manifest: OtzariaSearchArtifactManifest, database db: OtzariaDatabaseInstallationManifest? = nil,
                      bytes: Int64? = nil, build runtime: OtzariaSearchEngineBuildInfo? = nil) throws {
        _ = try SubjectArtifactPolicy.validateReadCompatibilityCandidate(manifest,
            database: db ?? database(mini), databaseBytes: bytes ?? mini.sourceDatabase.databaseBytes,
            build: runtime ?? consumer)
    }
    static func policyCases(root: URL) async throws {
        activate(mini)
        await run("original_policy_accepts_original265_manifest") {
            try BaselineArtifactPolicy.validate(mini, database: database(mini),
                databaseBytes: mini.sourceDatabase.databaseBytes, build: producer)
        }
        await run("current_policy_preserves_original265_exact_build") {
            try SubjectArtifactPolicy.validate(mini, database: database(mini),
                databaseBytes: mini.sourceDatabase.databaseBytes, build: producer)
        }
        await run("baseline_RED_cross_revision_candidate_is_rejected") {
            try require(rejects {
                try BaselineArtifactPolicy.validate(mini, database: database(mini),
                    databaseBytes: mini.sourceDatabase.databaseBytes, build: consumer)
            }, "baseline unexpectedly admitted the unimplemented read candidate")
        }
        await run("candidate_GREEN_exact_265_to_d5_full_policy_probe") { try probe(mini) }
        await run("production_candidate_remains_unqualified_and_rejected") {
            try require(OtzariaLexicalIndexReadCompatibility.qualifiedContract(manifest: mini, consumer: consumer) == nil,
                "qualification must be empty")
            try require(rejects {
                try SubjectArtifactPolicy.validate(mini, database: database(mini),
                    databaseBytes: mini.sourceDatabase.databaseBytes, build: consumer)
            }, "candidate probe must not enable production")
        }
        let full = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self,
            from: Data(contentsOf: root.appendingPathComponent("docs/hq-search/manifests/otzaria-search-manifest.json")))
        await run("actual_v32_manifest_candidate_metadata_probe_only") {
            activate(full); defer { activate(mini) }
            try probe(full, database: database(full), bytes: full.sourceDatabase.databaseBytes)
            try require(rejects {
                try SubjectArtifactPolicy.validate(full, database: database(full),
                    databaseBytes: full.sourceDatabase.databaseBytes, build: consumer)
            }, "v32 runtime admission must remain disabled")
        }
        let manifestNegatives: [(String, [String], Any)] = [
            ("format", ["formatVersion"], 2),
            ("profile", ["profileID"], "other"),
            ("profile_version", ["profileVersion"], 7),
            ("database_repository", ["sourceDatabase", "repository"], "other/repository"),
            ("database_release", ["sourceDatabase", "releaseID"], Int64(1)),
            ("database_tag", ["sourceDatabase", "releaseTag"], "other-tag"),
            ("database_asset", ["sourceDatabase", "assetID"], Int64(1)),
            ("database_asset_name", ["sourceDatabase", "assetName"], "different.db.zst"),
            ("database_asset_digest", ["sourceDatabase", "sourceAssetDigest"], String(repeating: "0", count: 64)),
            ("database_compressed_size", ["sourceDatabase", "compressedBytes"], Int64(1)),
            ("database_size", ["sourceDatabase", "databaseBytes"], Int64(1)),
            ("producer_repository", ["lexicalEngine", "repository"], "davidpovarsky/otzaria_search_engine"),
            ("producer_commit", ["lexicalEngine", "commit"], consumer.upstreamCommit),
            ("producer_version", ["lexicalEngine", "engineVersion"], "0.1.1"),
            ("producer_schema", ["lexicalEngine", "indexSchemaVersion"], 5),
            ("producer_generation", ["lexicalEngine", "defaultGenerationOrder"], 6),
            ("producer_adapter", ["lexicalEngine", "adapterVersion"], "0.1.1"),
            ("producer_tantivy", ["lexicalEngine", "tantivyVersion"], "0.26.2"),
            ("producer_semantic_revision", ["lexicalEngine", "semanticSidecarRevision"], "different"),
            ("document_total", ["lexicalArtifact", "documentCount"], 1),
            ("source_total", ["lexicalArtifact", "sourceCount"], 1),
            ("extracted_total", ["lexicalArtifact", "extractedBytes"], 1),
            ("packaged_total", ["lexicalArtifact", "packagedBytes"], 1),
            ("file_total", ["lexicalArtifact", "fileCount"], 1),
            ("part_compression", ["lexicalArtifact", "parts", "0", "compression"], "zip"),
            ("part_digest", ["lexicalArtifact", "parts", "0", "sha256"], "bad"),
            ("part_digest_nonhex", ["lexicalArtifact", "parts", "0", "sha256"], String(repeating: "z", count: 64)),
            ("part_path", ["lexicalArtifact", "parts", "0", "destinationPath"], "../escaped"),
            ("part_offset", ["lexicalArtifact", "parts", "0", "destinationOffset"], 1),
            ("part_packaged_bytes", ["lexicalArtifact", "parts", "0", "packagedBytes"], 0),
            ("part_output_bytes", ["lexicalArtifact", "parts", "0", "uncompressedBytes"], 0),
        ]
        for (name, path, replacement) in manifestNegatives {
            await run("candidate_rejects_" + name) {
                let changed = try mutate(mini!, path, replacement)
                try require(rejects { try probe(changed) }, "candidate accepted " + name)
            }
        }
        let runtimeNegatives: [(String, String, Any)] = [
            ("repository", "upstreamRepository", producer.upstreamRepository),
            ("commit", "upstreamCommit", producer.upstreamCommit),
            ("future_descendant", "upstreamCommit", String(repeating: "f", count: 40)),
            ("branch", "upstreamBranch", "main"), ("version", "engineVersion", "0.1.1"),
            ("schema", "indexSchemaVersion", 5), ("generation", "defaultGenerationOrder", 6),
            ("adapter", "adapterVersion", "0.1.1"), ("semantic_revision", "semanticSidecarRevision", "other"),
        ]
        for (name, field, replacement) in runtimeNegatives {
            await run("candidate_rejects_consumer_" + name) {
                let changed = try mutate(consumer!, [field], replacement)
                try require(rejects { try probe(mini, build: changed) }, "candidate accepted consumer " + name)
            }
        }
        for name in mini.resources.keys.sorted() {
            await run("candidate_rejects_producer_resource_hash_" + name) {
                try require(rejects { try probe(mutate(mini!, ["resources", name, "sha256"], String(repeating: "0", count: 64))) },
                    "candidate accepted changed producer resource")
            }
            await run("candidate_rejects_consumer_resource_hash_" + name) {
                try require(rejects { try probe(mini, build: mutate(consumer!, ["resourceHashes", name], String(repeating: "0", count: 64))) },
                    "candidate accepted changed consumer resource")
            }
            await run("candidate_rejects_missing_resource_" + name) {
                try require(rejects { try probe(withoutResource(mini, name)) }, "candidate accepted missing resource")
            }
        }
        await run("candidate_rejects_extra_resource") {
            let changed = try mutate(mini!, ["resources", "extra"], ["bytes": 1, "sha256": String(repeating: "0", count: 64)])
            try require(rejects { try probe(changed) }, "candidate accepted unreviewed resource")
        }
        await run("candidate_rejects_wrong_active_profile") {
            OtzariaDataProfileRegistry.activeProfileID = "other"; defer { activate(mini) }
            try require(rejects { try probe(mini) }, "candidate bypassed active profile")
        }
        await run("candidate_rejects_wrong_actual_database_bytes") {
            try require(rejects { try probe(mini, bytes: mini.sourceDatabase.databaseBytes + 1) }, "candidate bypassed current size")
        }
        await run("producer_identity_uses_manifest_fields_and_keeps_consumer_honest") {
            let fingerprint = OtzariaIndexFingerprint(databasePath: "new-path", fileSize: 123, modificationTime: 7)
            let identity = try SubjectArtifactPolicy.artifactProducerIdentity(manifest: mini, database: fingerprint,
                requiredResourceNames: Set(consumer.resourceHashes.keys))
            try require(identity.upstreamCommit == producer.upstreamCommit && consumer.upstreamCommit != identity.upstreamCommit,
                "producer identity was restamped")
            try require(identity.database == fingerprint && identity.catalogueHash == mini.lexicalArtifact.catalogueHash
                && identity.resourceHashes == mini.resources.mapValues(\.sha256), "producer fields changed")
            try require(BaselineArtifactPolicy.managedIdentityMatchesCanonicalData(identity, currentDatabase: fingerprint, build: producer),
                "old runtime metadata rollback rejected original producer")
            try require(!SubjectArtifactPolicy.managedIdentityMatchesCanonicalData(identity, currentDatabase: fingerprint,
                build: consumer, trustedManifest: mini), "candidate identity became runtime-qualified")
        }
        await run("untrusted_bare_commit_cannot_authorize_cross_revision_read") {
            let fp = OtzariaIndexFingerprint(databasePath: "old-path", fileSize: 123, modificationTime: 7)
            let identity = try SubjectArtifactPolicy.artifactProducerIdentity(manifest: mini, database: fp,
                requiredResourceNames: Set(consumer.resourceHashes.keys))
            try require(!SubjectArtifactPolicy.managedIdentityMatchesCanonicalData(identity, currentDatabase: fp, build: consumer),
                "identity without trusted manifest admitted")
        }
        await run("producer_identity_missing_required_resource_throws") {
            let fp = OtzariaIndexFingerprint(databasePath: "path", fileSize: 1, modificationTime: 0)
            try require(rejects {
                _ = try SubjectArtifactPolicy.artifactProducerIdentity(manifest: mini, database: fp,
                    requiredResourceNames: ["missing"])
            }, "missing producer resource was fabricated")
        }
        let fp = OtzariaIndexFingerprint(databasePath: "path", fileSize: 123, modificationTime: 7)
        let originalIdentity = try SubjectArtifactPolicy.artifactProducerIdentity(manifest: mini, database: fp,
            requiredResourceNames: Set(consumer.resourceHashes.keys))
        await run("producer_metadata_binding_accepts_only_its_original_fields") {
            try require(SubjectArtifactPolicy.identityMatchesArtifactProducer(originalIdentity, manifest: mini),
                "original producer fields were not bound")
        }
        let identityNegatives: [(String, Any)] = [("upstreamCommit", consumer.upstreamCommit),
            ("engineVersion", "0.1.1"), ("indexSchemaVersion", 5), ("defaultGenerationOrder", 6),
            ("adapterVersion", "0.1.1"), ("catalogueHash", "different"), ("resourceHashes", [String: String]())]
        for (field, replacement) in identityNegatives {
            await run("producer_metadata_binding_rejects_" + field) {
                let changed = try mutate(originalIdentity, [field], replacement)
                try require(!SubjectArtifactPolicy.identityMatchesArtifactProducer(changed, manifest: mini),
                    "producer metadata accepted mismatched " + field)
            }
        }
    }

    static func reset(_ name: String) throws -> (OtzariaResolvedSearchArtifact, String) {
        FixtureWorld.root = stateRoot.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: manager.indexRootURL, withIntermediateDirectories: true)
        FixtureWorld.build = consumer; FixtureWorld.admitCandidate = true
        FixtureWorld.compatible = true; FixtureWorld.count = mini.lexicalArtifact.documentCount
        FixtureWorld.openFails = false; FixtureWorld.finalOpenFails = false; FixtureWorld.countFails = false
        FixtureWorld.writes = 0; FixtureWorld.opens = 0; FixtureWorld.closes = 0
        OtzariaDatabaseAccessController.shared.source = .managedInternal; activate(mini)
        let path = FixtureWorld.root.appendingPathComponent("database.db")
        let bytes = Data("controlled-canonical-database".utf8); try bytes.write(to: path)
        var manifest = try mutate(mini!, ["sourceDatabase", "databaseBytes"], bytes.count)
        let part: [String: Any] = ["assetName": "fixture.zst", "packagedBytes": FixtureWorld.rawPart.count,
            "sha256": String(repeating: "1", count: 64), "destinationPath": "meta.json", "destinationOffset": 0,
            "uncompressedBytes": FixtureWorld.rawPart.count, "compression": "zstd"]
        manifest = try mutate(manifest, ["lexicalArtifact", "parts"], [part])
        manifest = try mutate(manifest, ["lexicalArtifact", "fileCount"], 1)
        manifest = try mutate(manifest, ["lexicalArtifact", "extractedBytes"], FixtureWorld.rawPart.count)
        manifest = try mutate(manifest, ["lexicalArtifact", "packagedBytes"], FixtureWorld.rawPart.count)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(database(manifest)).write(to: try OtzariaDatabaseStorage().installationManifestURL)
        let artifact = OtzariaResolvedSearchArtifact(releaseID: 1, releaseTag: "controlled-flow-fixture", manifest: manifest,
            partURLs: ["fixture.zst": URL(string: "https://fixture.invalid/fixture.zst")!])
        return (artifact, path.path)
    }
    static func finalSnapshot(_ url: URL) throws -> [String: Data] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        return try Dictionary(uniqueKeysWithValues: FileManager.default.contentsOfDirectory(at: url,
            includingPropertiesForKeys: nil).map { ($0.lastPathComponent, try Data(contentsOf: $0)) })
    }
    static func install(_ artifact: OtzariaResolvedSearchArtifact, path: String, streaming: Bool) async throws -> UInt64 {
        let part = FixtureWorld.root.appendingPathComponent("download.zst")
        try FixtureWorld.rawPart.write(to: part)
        let installer = OtzariaSearchArtifactInstaller()
        if streaming {
            return try await installer.installStreaming(artifact: artifact, databasePath: path,
                storage: .init(), downloadPart: { _ in part }, progress: { _, _ in })
        }
        return try installer.install(artifact: artifact, downloadedParts: ["fixture.zst": part], databasePath: path,
            storage: .init(), progress: { _, _ in })
    }
    static func trustedIndex(_ artifact: OtzariaResolvedSearchArtifact, path: String, url: URL? = nil,
                             identityRuntime: OtzariaSearchEngineBuildInfo? = nil) throws -> URL {
        let target = url ?? manager.indexURL(for: path)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FixtureWorld.rawPart.write(to: target.appendingPathComponent("meta.json"))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(artifact.manifest).write(to: target.appendingPathComponent("otzaria_prebuilt_installation.json"))
        var identity = try SubjectArtifactPolicy.artifactProducerIdentity(manifest: artifact.manifest,
            database: manager.currentFingerprint(databasePath: path), requiredResourceNames: Set(consumer.resourceHashes.keys))
        if let identityRuntime { identity = try mutate(identity, ["upstreamCommit"], identityRuntime.upstreamCommit) }
        try manager.writeIdentity(identity, indexURL: target)
        return target
    }
    static func assertProducer(_ url: URL, artifact: OtzariaResolvedSearchArtifact, path: String) throws {
        guard let identity = manager.storedIdentity(indexURL: url) else { throw FixtureFailure.failed("missing identity") }
        try require(identity.upstreamCommit == producer.upstreamCommit, "original producer265 replaced by consumerd5")
        try require(identity.resourceHashes == artifact.manifest.resources.mapValues(\.sha256), "resource provenance changed")
        let fp = try manager.currentFingerprint(databasePath: path)
        try require(BaselineArtifactPolicy.managedIdentityMatchesCanonicalData(identity, currentDatabase: fp, build: producer),
            "metadata cannot roll back to original runtime")
        let saved = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self,
            from: Data(contentsOf: url.appendingPathComponent("otzaria_prebuilt_installation.json")))
        try require(saved == artifact.manifest, "trusted original manifest was restamped")
        try require(try Data(contentsOf: url.appendingPathComponent("meta.json")) == FixtureWorld.rawPart,
            "original fixture index payload changed")
        try require(FixtureWorld.opens == FixtureWorld.closes, "engine ownership leaked")
    }
    static func flowCases() async throws {
        for streaming in [false, true] {
            await run("install_\(streaming ? "stream" : "bulk")_preserves_producer_and_old_reader_rollback") {
                let (artifact, path) = try reset(streaming ? "stream" : "bulk")
                let count = try await install(artifact, path: path, streaming: streaming)
                try require(count == artifact.manifest.lexicalArtifact.documentCount, "count changed")
                try assertProducer(manager.indexURL(for: path), artifact: artifact, path: path)
            }
        }
        await run("recovery_preserves_original_producer_across_path_change") {
            let (artifact, path) = try reset("recover-path")
            let old = try trustedIndex(artifact, path: path, url: manager.indexRootURL.appendingPathComponent("old-container"))
            let manifestBytes = try Data(contentsOf: old.appendingPathComponent("otzaria_prebuilt_installation.json"))
            let count = try manager.recoverTrustedManagedIndex(databasePath: path)
            try require(count == artifact.manifest.lexicalArtifact.documentCount && !FileManager.default.fileExists(atPath: old.path),
                "trusted old container did not recover")
            let final = manager.indexURL(for: path)
            try assertProducer(final, artifact: artifact, path: path)
            try require(try Data(contentsOf: final.appendingPathComponent("otzaria_prebuilt_installation.json")) == manifestBytes,
                "recovery rewrote original trusted manifest bytes")
        }
        await run("recovery_existing_correct_producer_does_not_rewrite_identity") {
            let (artifact, path) = try reset("recover-stable")
            let final = try trustedIndex(artifact, path: path)
            let before = try finalSnapshot(final); FixtureWorld.writes = 0
            _ = try manager.recoverTrustedManagedIndex(databasePath: path)
            try require(FixtureWorld.writes == 0 && finalSnapshot(final) == before, "stable producer metadata rewritten")
        }
        await run("recovery_repairs_consumer_restamp_from_original_manifest") {
            let (artifact, path) = try reset("recover-restamp")
            let final = try trustedIndex(artifact, path: path, identityRuntime: consumer)
            _ = try manager.recoverTrustedManagedIndex(databasePath: path)
            try assertProducer(final, artifact: artifact, path: path)
        }
        for failure in ["production_disabled", "incompatible_engine", "wrong_count", "count_error", "wrong_resource", "wrong_source", "wrong_profile"] {
            await run("recovery_\(failure)_preserves_existing_index") {
                var (artifact, path) = try reset("recover-" + failure)
                if failure == "wrong_resource" {
                    let changed = try mutate(artifact.manifest,
                        ["resources", "Application Support/Otzaria/lexical.db", "sha256"], String(repeating: "0", count: 64))
                    artifact = .init(releaseID: artifact.releaseID, releaseTag: artifact.releaseTag,
                        manifest: changed, partURLs: artifact.partURLs)
                }
                let final = try trustedIndex(artifact, path: path)
                if failure == "production_disabled" { FixtureWorld.admitCandidate = false }
                if failure == "incompatible_engine" { FixtureWorld.compatible = false }
                if failure == "wrong_count" { FixtureWorld.count += 1 }
                if failure == "count_error" { FixtureWorld.countFails = true }
                if failure == "wrong_profile" { OtzariaDataProfileRegistry.activeProfileID = "other" }
                if failure == "wrong_source" {
                    let storage = try OtzariaDatabaseStorage()
                    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
                    let db = try decoder.decode(OtzariaDatabaseInstallationManifest.self, from: Data(contentsOf: storage.installationManifestURL))
                    let changed = try mutate(db, ["assetID"], Int64(999))
                    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
                    try encoder.encode(changed).write(to: storage.installationManifestURL)
                }
                let before = try finalSnapshot(final)
                let result = try manager.recoverTrustedManagedIndex(databasePath: path)
                try require(result == nil && finalSnapshot(final) == before, "invalid recovery changed committed index")
                try require(FixtureWorld.opens == FixtureWorld.closes, "recovery leaked engine on failure")
            }
        }
        for failure in ["incompatible_engine", "wrong_count", "count_error", "open_error", "promotion_open_error"] {
            await run("installer_\(failure)_preserves_original_final") {
                let (artifact, path) = try reset("install-" + failure)
                let final = try trustedIndex(artifact, path: path)
                let before = try finalSnapshot(final)
                if failure == "incompatible_engine" { FixtureWorld.compatible = false }
                if failure == "wrong_count" { FixtureWorld.count += 1 }
                if failure == "count_error" { FixtureWorld.countFails = true }
                if failure == "open_error" { FixtureWorld.openFails = true }
                if failure == "promotion_open_error" { FixtureWorld.finalOpenFails = true }
                var failed = false
                do { _ = try await install(artifact, path: path, streaming: true) } catch { failed = true }
                try require(failed && finalSnapshot(final) == before, "failed installer replaced original index")
                try require(FixtureWorld.opens == FixtureWorld.closes, "failed installer leaked engine")
            }
        }
        await run("streaming_cancellation_keeps_original_final") {
            let (artifact, path) = try reset("install-cancel")
            let final = try trustedIndex(artifact, path: path); let before = try finalSnapshot(final)
            do {
                _ = try await OtzariaSearchArtifactInstaller().installStreaming(artifact: artifact, databasePath: path,
                    storage: .init(), downloadPart: { _ in throw CancellationError() }, progress: { _, _ in })
                throw FixtureFailure.failed("cancelled transfer returned success")
            } catch OtzariaSearchArtifactError.cancelled {}
            try require(try finalSnapshot(final) == before, "cancelled transfer changed original final")
        }
        await run("production_readiness_rejects_unqualified_producer_without_mutation") {
            let (artifact, path) = try reset("readiness-disabled")
            let final = try trustedIndex(artifact, path: path); let before = try finalSnapshot(final)
            FixtureWorld.admitCandidate = false
            try require(rejects { _ = try manager.validateCurrentIndex(databasePath: path) }, "unqualified read admitted")
            try require(try finalSnapshot(final) == before, "readiness changed original index")
        }
        await run("new_writer_identity_keeps_real_consumer_revision") {
            let (_, path) = try reset("new-writer")
            let identity = try manager.makeIdentity(databasePath: path, catalogueHash: "actual-writer-catalogue")
            try require(identity.upstreamCommit == consumer.upstreamCommit && identity.upstreamCommit != producer.upstreamCommit,
                "read contract incorrectly changed writer identity")
        }
        await run("cross_writer_seed_stays_denied_without_deleting_final") {
            let (artifact, path) = try reset("cross-seed")
            let final = try trustedIndex(artifact, path: path); let before = try finalSnapshot(final)
            let identity = try manager.makeIdentity(databasePath: path, catalogueHash: artifact.manifest.lexicalArtifact.catalogueHash)
            try require(!manager.fixtureCanSeed(from: final, identity: identity), "old producer seeded a different writer")
            try require(try finalSnapshot(final) == before, "seed eligibility mutated final")
        }
        for sameWriter in [false, true] {
            await run("checkpoint_\(sameWriter ? "same_writer_resumes" : "cross_writer_does_not_resume_or_seed")") {
                let (artifact, path) = try reset(sameWriter ? "resume-exact" : "resume-cross")
                let final = try trustedIndex(artifact, path: path); let before = try finalSnapshot(final)
                let building = manager.buildingIndexURL(for: path)
                try FileManager.default.createDirectory(at: building, withIntermediateDirectories: true)
                let current = try manager.makeIdentity(databasePath: path, catalogueHash: artifact.manifest.lexicalArtifact.catalogueHash)
                let previous = sameWriter ? current : try SubjectArtifactPolicy.artifactProducerIdentity(manifest: artifact.manifest,
                    database: manager.currentFingerprint(databasePath: path), requiredResourceNames: Set(consumer.resourceHashes.keys))
                try manager.writeIdentity(previous, indexURL: building)
                let checkpoint = OtzariaIndexCheckpoint(identity: previous, lastCatalogueOrdinal: 2, lastSourceKey: "book:2",
                    committedBooks: 2, totalBooks: 10, committedDocuments: 5, committedBytes: 100, timestamp: Date(),
                    upstreamCommit: previous.upstreamCommit, batchSequence: 1, quarantinedBooks: [])
                try manager.writeCheckpoint(checkpoint, indexURL: building)
                let marker = building.appendingPathComponent("committed-pages"); try Data("old-partial".utf8).write(to: marker)
                let resumed = try manager.prepareOrResumeBuildingIndex(databasePath: path, identity: current)
                try require((resumed.checkpoint != nil) == sameWriter, "checkpoint exact-writer comparison changed")
                try require(FileManager.default.fileExists(atPath: marker.path) == sameWriter, "partial generation ownership changed")
                try require(try finalSnapshot(final) == before, "resume touched committed final")
            }
        }
    }
    static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        stateRoot = URL(fileURLWithPath: CommandLine.arguments[2])
        mini = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self,
            from: Data(contentsOf: root.appendingPathComponent("Tests/HQ/search/Fixtures/otzaria-miniTest10-v6-manifest.json")))
        producer = build(mini)
        consumer = try mutate(producer!, ["upstreamRepository"], "davidpovarsky/otzaria_search_engine")
        consumer = try mutate(consumer!, ["upstreamCommit"], "d5d59d1269bdf87fb0a6901cf31941726a0c699b")
        consumer = try mutate(consumer!, ["upstreamBranch"], "codex/otzaria-exact-occurrences-20261120")
        try await policyCases(root: root)
        try await flowCases()
        let failures = results.filter { $0["outcome"] == "FAIL" }
        let report: [String: Any] = ["counts": ["total": results.count, "passed": results.count - failures.count,
            "failed": failures.count, "skipped": 0], "cases": results,
            "runtime_qualification": "NOT_RUN; production registry empty", "real_engine_or_index": false]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
        for result in failures { print("FAIL \(result["name"]!): \(result["detail"]!)") }
        print("Portable policy/flow cases: \(results.count - failures.count)/\(results.count) PASS; \(failures.count) FAIL; 0 SKIP")
        if !failures.isEmpty { exit(1) }
    }
}
