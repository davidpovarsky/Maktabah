import Foundation
import Darwin

// DispatchSemaphore.wait is unavailable directly in an async context on Apple
// Swift. Keep this explicit bounded synchronous scheduling boundary; it does
// not change the signal, one-second limit, or assertion used by the case.
private func ownershipSignalArrived(_ signal: DispatchSemaphore, before deadline: DispatchTime) -> Bool {
    signal.wait(timeout: deadline) == .success
}

private func failureTag(_ error: Error) -> String {
    if error is CancellationError { return "cancelled" }
    if let value = error as? OtzariaSearchExecutionPreparationError {
        switch value {
        case .unavailable: return "unavailable"
        case .sourceBusy: return "source_busy"
        case .sourceChanged: return "source_changed"
        case .deadlineExceeded: return "deadline"
        }
    }
    if error is OtzariaSearchError { return "engine_error" }
    return "filesystem_or_boundary_error"
}

@MainActor private func refuses(_ accepted: Set<String>, _ body: @MainActor () async throws -> Void) async throws {
    var observed: String?
    do { try await body() } catch { observed = failureTag(error) }
    OwnershipFixtureEvidence.refusals.update {
        $0.append(["expected": accepted.sorted().joined(separator: ","), "observed": observed ?? "no_error"])
    }
    try require(observed.map { accepted.contains($0) } == true, "wrong_or_missing_refusal")
}

@MainActor private final class OwnershipChecks {
    private var rows: [[String: String]] = []
    private var nativeBoundaryObservations: [[String: String]] = []
    let only = ProcessInfo.processInfo.environment["COLD_OWNERSHIP_ONLY"]
    func run(_ name: String, _ body: @MainActor () async throws -> Void) async {
        if let only, only != name { return }
        do {
            try await body()
            rows.append(["id": name, "outcome": "passed"])
        } catch let error as OwnershipFailure {
            rows.append(["id": name, "outcome": "failed", "code": error.code])
        } catch {
            rows.append(["id": name, "outcome": "failed", "code": failureTag(error)])
        }
        let native = OwnershipNativeDouble.stats()
        nativeBoundaryObservations.append(["id": name, "constructors": String(native.constructors),
            "closes": String(native.closes), "counts": String(native.counts),
            "dictionaries": String(native.dictionaries), "compatibilities": String(native.compatibilities)])
        save()
    }
    private func save() {
        let output = URL(fileURLWithPath: ProcessInfo.processInfo.environment["COLD_OWNERSHIP_REPORT"]!)
        let value: [String: Any] = ["scope": "FOUNDATION_OWNERSHIP_WITH_EXPLICIT_NATIVE_CONSTRUCTOR_DOUBLE",
                                  "actualCOrRustEngineExecuted": 0, "nativeUIExecuted": 0,
                                  "checks": rows,
                                  "fixtureSourceSetup": OwnershipFixtureEvidence.sourceSetup.read(),
                                  "refusalObservations": OwnershipFixtureEvidence.refusals.read(),
                                  "nativeBoundaryObservations": nativeBoundaryObservations]
        do {
            try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: output, options: .atomic)
        } catch { print("OWNERSHIP_REPORT_WRITE_FAILED"); exit(72) }
    }
    func finish() -> Never {
        OtzariaTantivySearchRepository.shared.closeAllEngines()
        let failed = rows.filter { $0["outcome"] != "passed" }.count
        print("OWNERSHIP_EXECUTED \(rows.count) PASSED \(rows.count - failed) FAILED \(failed)")
        exit(failed == 0 && !rows.isEmpty ? 0 : 1)
    }
}

@main private struct OwnershipAcceptance {
    @MainActor static func main() async throws {
        let checks = OwnershipChecks()
        await checks.run("old_storage_owner_excludes_new_try") {
            _ = try OwnershipSource.make("storage-old")
            let held = try OwnershipHeldLock(storage: "same-owner")
            let entered = OwnershipBox(false)
            let result: Bool? = try ITorahStorageLock.tryWithLock(name: "same-owner") { entered.update { $0 = true }; return true }
            try held.finish()
            try require(result == nil && !entered.read(), "new_try_bypassed_original_owner")
            try require(try ITorahStorageLock.tryWithLock(name: "same-owner") { true } == true, "owner_not_released")
        }
        await checks.run("throw_releases_original_storage_owner") {
            _ = try OwnershipSource.make("storage-throw")
            do { let _: Bool? = try ITorahStorageLock.tryWithLock(name: "throw") { throw OwnershipFailure("intentional") } }
            catch let error as OwnershipFailure { try require(error.code == "intentional", "wrong_throw") }
            try require(try ITorahStorageLock.tryWithLock(name: "throw") { true } == true, "lock_leaked_after_throw")
        }
        await checks.run("nonrecursive_storage_try_does_not_deadlock") {
            _ = try OwnershipSource.make("storage-recursive")
            let inner: Bool?? = try ITorahStorageLock.tryWithLock(name: "recursive") {
                try ITorahStorageLock.tryWithLock(name: "recursive") { true }
            }
            try require(inner != nil && inner! == nil, "storage_recursion_unexpected")
        }
        await checks.run("unavailable_file_lock_fails_closed_and_releases_thread_owner") {
            _ = try OwnershipSource.make("storage-fd")
            let directory = ITorahSharedContainer.otzariaRootURL
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let blocked = directory.appendingPathComponent(".locks")
            try Data("owned-fixture-blocker".utf8).write(to: blocked)
            let invoked = OwnershipBox(false)
            var rejected = false
            do { let _: Bool? = try ITorahStorageLock.tryWithLock(name: "failed-open") { invoked.update { $0 = true }; return true } }
            catch { rejected = true }
            try require(rejected && !invoked.read(), "file_lock_failure_entered_body")
            try FileManager.default.removeItem(at: blocked)
            try require(try ITorahStorageLock.tryWithLock(name: "failed-open") { true } == true, "thread_owner_leaked")
        }
        await checks.run("actual_darwin_cross_process_flock_excludes_try") {
            _ = try OwnershipSource.make("storage-process")
            let _: Bool? = try ITorahStorageLock.tryWithLock(name: "process") { true }
            let directory = OwnershipEnvironment.current.read().directory
            let ready = directory.appendingPathComponent("child-ready")
            let release = directory.appendingPathComponent("child-release")
            let lock = ITorahSharedContainer.otzariaRootURL.appendingPathComponent(".locks/process.lock")
            let child = Process(); child.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            child.arguments = ["python3", "-c", "import fcntl,pathlib,sys,time\nf=open(sys.argv[1],'a+b')\nfcntl.flock(f,fcntl.LOCK_EX)\npathlib.Path(sys.argv[2]).write_text('held')\nd=time.monotonic()+5\nwhile not pathlib.Path(sys.argv[3]).exists() and time.monotonic()<d: time.sleep(.005)\nfcntl.flock(f,fcntl.LOCK_UN)\n", lock.path, ready.path, release.path]
            try child.run()
            let end = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
            while !FileManager.default.fileExists(atPath: ready.path) && DispatchTime.now().uptimeNanoseconds < end {
                try await Task<Never, Never>.sleep(nanoseconds: 2_000_000)
            }
            let childHeld = FileManager.default.fileExists(atPath: ready.path)
            let entered: Bool? = try ITorahStorageLock.tryWithLock(name: "process") { true }
            try Data("release".utf8).write(to: release)
            child.waitUntilExit()
            try require(childHeld && entered == nil && child.terminationStatus == 0, "cross_process_lock_not_observed")
            try require(try ITorahStorageLock.tryWithLock(name: "process") { true } == true, "flock_not_released")
        }
        await checks.run("bridge_try_recursive_acquisition_is_balanced") {
            let source = try OwnershipSource.make("bridge-recursive")
            let value = OwnershipBox<UInt64?>(nil)
            source.bridge.withOwner { value.update { $0 = source.bridge.tryGenerationSnapshot() } }
            try require(value.read() == source.generation, "recursive_bridge_observation_failed")
            let held = try OwnershipHeldLock(owner: source.bridge)
            try require(source.bridge.tryGenerationSnapshot() == nil, "recursive_observation_leaked_owner_level")
            try held.finish()
        }
        await checks.run("foreign_bridge_owner_returns_busy") {
            let source = try OwnershipSource.make("bridge-busy")
            let held = try OwnershipHeldLock(owner: source.bridge)
            try require(source.bridge.tryGenerationSnapshot() == nil, "foreign_bridge_owner_waited_or_bypassed")
            try held.finish()
            try require(source.bridge.tryGenerationSnapshot() == source.generation, "bridge_not_released")
        }
        await checks.run("migration_contention_cancellation_has_no_native_open") {
            let source = try OwnershipSource.make("migration-cancel")
            let held = try OwnershipHeldLock(storage: "migration-fixture")
            let attempts = OwnershipBox(0)
            let task = Task.detached { try await source.prepare(validate: {
                attempts.update { $0 += 1 }; try source.validate()
            }) }
            try await Task<Never, Never>.sleep(nanoseconds: 20_000_000)
            task.cancel()
            try await refuses(["cancelled"]) { try await task.value }
            try held.finish()
            try require(attempts.read() > 0, "cancel_did_not_overlap_admitted_attempt")
            try source.requireNoOpenOrPublication()
        }
        await checks.run("database_contention_deadline_has_no_native_open") {
            let source = try OwnershipSource.make("database-deadline")
            let held = try OwnershipHeldLock(storage: "database-mutation-fixture")
            try await refuses(["deadline"]) { try await source.prepare(milliseconds: 30) }
            try held.finish(); try source.requireNoOpenOrPublication()
        }
        await checks.run("search_contention_deadline_has_no_native_open") {
            let source = try OwnershipSource.make("search-deadline")
            let held = try OwnershipHeldLock(storage: "otzaria-search-mutation-fixture")
            try await refuses(["deadline"]) { try await source.prepare(milliseconds: 30) }
            try held.finish(); try source.requireNoOpenOrPublication()
        }
        await checks.run("cache_contention_releases_all_outer_storage_owners") {
            let source = try OwnershipSource.make("cache-deadline")
            let held = try OwnershipHeldLock(repository: .shared)
            let attempts = OwnershipBox(0)
            let atSecondAttempt = DispatchSemaphore(value: 0)
            let resumeSecondAttempt = DispatchSemaphore(value: 0)
            defer { held.release.signal(); resumeSecondAttempt.signal() }
            let task = Task.detached { try await source.prepare(validate: {
                attempts.update { $0 += 1 }
                if attempts.read() == 2 {
                    // With the real cache lock held, the inner source callback
                    // cannot run. This is the next original outer-loop callback,
                    // before acquisition: all previous storage owners must be free.
                    atSecondAttempt.signal()
                    try require(ownershipSignalArrived(resumeSecondAttempt, before: .now() + 1),
                                "fixture_second_attempt_not_released")
                }
                try source.validate()
            }) }
            defer { task.cancel() }
            let reachedSecondAttempt = ownershipSignalArrived(atSecondAttempt, before: .now() + 1)
            var observed = Set<String>()
            for name in ["migration-fixture", "database-mutation-fixture", "otzaria-search-mutation-fixture"] {
                if try ITorahStorageLock.tryWithLock(name: name, block: { true }) == true { observed.insert(name) }
            }
            OwnershipFixtureEvidence.sourceSetup.update {
                $0.append(["caseSetup": "cache-deadline-barrier", "reachedSecondAttempt": String(reachedSecondAttempt),
                           "observedAttempt": String(attempts.read()), "freeOuterOwners": observed.sorted().joined(separator: ",")])
            }
            task.cancel()
            resumeSecondAttempt.signal()
            try held.finish()
            try await refuses(["cancelled"]) { try await task.value }
            try require(reachedSecondAttempt, "fixture_second_attempt_not_observed")
            try require(attempts.read() > 1, "no_actual_repeated_cache_attempt")
            try require(observed.count == 3, "outer_storage_owner_retained_across_wait")
            try source.requireNoOpenOrPublication()
        }
        await checks.run("bridge_busy_cancellation_never_opens_native_engine") {
            let source = try OwnershipSource.make("bridge-cancel")
            let held = try OwnershipHeldLock(owner: source.bridge)
            let task = Task.detached { try await source.prepare() }
            try await Task<Never, Never>.sleep(nanoseconds: 20_000_000); task.cancel()
            try await refuses(["cancelled"]) { try await task.value }
            try held.finish(); try source.requireNoOpenOrPublication()
        }
        await checks.run("bridge_to_migration_cycle_unwinds_before_retry") {
            let source = try OwnershipSource.make("bridge-migration-cycle")
            let validations = OwnershipBox(0), completed = OwnershipBox(false)
            let held = DispatchSemaphore(value: 0), done = DispatchSemaphore(value: 0)
            try await source.prepare(validate: {
                validations.update { $0 += 1 }
                if validations.read() == 2 {
                    DispatchQueue.global().async {
                        source.bridge.withOwner {
                            held.signal()
                            ITorahStorageLock.withLock(name: "migration-fixture") { completed.update { $0 = true } }
                        }
                        done.signal()
                    }
                    try require(held.wait(timeout: .now() + 1) == .success, "legacy_bridge_owner_not_started")
                }
                try source.validate()
            })
            try require(ownershipSignalArrived(done, before: .now() + 1) && completed.read(), "bridge_migration_cycle_did_not_release")
            try require(validations.read() > 2 && OwnershipNativeDouble.stats().constructors == 1, "retry_did_not_use_original_cache_once")
        }
        await checks.run("generation_mismatch_precedes_native_open") {
            let source = try OwnershipSource.make("generation-stale"); source.bridge.advance()
            try await refuses(["source_changed"]) { try await source.prepare() }
            try source.requireNoOpenOrPublication()
        }
        await checks.run("repository_invalidation_aba_rejects_same_fingerprint") {
            let source = try OwnershipSource.make("repository-aba")
            OtzariaTantivySearchRepository.shared.invalidate(databasePath: source.database)
            try await refuses(["source_changed"]) { try await source.prepare() }
            try source.requireNoOpenOrPublication()
        }
        await checks.run("profile_change_cannot_borrow_original_index") {
            let source = try OwnershipSource.make("profile-change")
            OwnershipEnvironment.current.update { $0.profile = "other" }
            try await refuses(["source_changed"]) { try await source.prepare() }
            try source.requireNoOpenOrPublication()
        }
        await checks.run("missing_index_is_not_created") {
            let source = try OwnershipSource.make("missing-index")
            try FileManager.default.removeItem(at: source.index)
            // Capture the actual missing-path URL before this invocation. The
            // previous existing-directory URL instead tests a source change on
            // Darwin; retain that observation without weakening the real guard.
            let missingIndex = OtzariaSearchIndexManager.shared.indexURL(for: source.database)
            try require(!FileManager.default.fileExists(atPath: missingIndex.path)
                && missingIndex.standardizedFileURL.path == source.index.standardizedFileURL.path,
                "fixture_missing_index_path_not_absent")
            OwnershipFixtureEvidence.sourceSetup.update {
                $0.append(["caseSetup": "missing-index-invocation",
                           "previousExistingURL": source.index.absoluteString,
                           "currentMissingURL": missingIndex.absoluteString,
                           "currentMissingHasDirectoryPath": String(missingIndex.hasDirectoryPath),
                           "originalExactURLEquality": String(source.index == missingIndex)])
            }
            let missing = OwnershipSource(database: source.database, index: missingIndex,
                profile: source.profile, revision: source.revision, fingerprint: source.fingerprint,
                sidecar: source.sidecar, hashes: source.hashes,
                bridge: source.bridge, generation: source.generation)
            try await refuses(["filesystem_or_boundary_error", "unavailable"]) { try await missing.prepare() }
            try require(!FileManager.default.fileExists(atPath: source.index.path), "missing_index_created")
            try source.requireNoOpenOrPublication()
        }
        await checks.run("legacy_compatible_index_is_not_repaired") {
            let source = try OwnershipSource.make("legacy-compatible")
            OwnershipNativeDouble.compatibility(1)
            try await refuses(["unavailable"]) { try await source.prepare() }
            try source.requireNoOpenOrPublication()
            try require(try Data(contentsOf: source.index.appendingPathComponent("otzaria_index_meta.json")) == source.sidecar,
                        "legacy_metadata_changed")
        }
        await checks.run("incompatible_index_never_opens") {
            let source = try OwnershipSource.make("incompatible")
            OwnershipNativeDouble.compatibility(2)
            try await refuses(["unavailable"]) { try await source.prepare() }
            try source.requireNoOpenOrPublication()
        }
        await checks.run("recovery_building_installing_markers_all_refuse") {
            for ext in ["sentinel", "building", "installing"] {
                let source = try OwnershipSource.make("marker-" + ext)
                try Data("marker".utf8).write(to: source.index.appendingPathExtension(ext))
                try await refuses(["unavailable"]) { try await source.prepare() }
                try source.requireNoOpenOrPublication()
            }
        }
        await checks.run("dictionary_digest_mismatch_never_opens") {
            let source = try OwnershipSource.make("dictionary-digest")
            var wrong = source.hashes; wrong["Vendor/OtzariaSearchEngine/Resources/dictionary.json"] = String(repeating: "0", count: 64)
            try await refuses(["unavailable"]) { try await source.prepare(hashes: wrong) }
            try source.requireNoOpenOrPublication()
        }
        await checks.run("constructor_generation_switch_stops_further_native_work") {
            let source = try OwnershipSource.make("constructor-generation")
            OwnershipNativeDouble.afterConstructor.update { $0 = { source.bridge.advance() } }
            try await refuses(["source_changed"]) { try await source.prepare() }
            let stats = OwnershipNativeDouble.stats()
            try require(stats.constructors == 1 && stats.closes == 1, "candidate_handle_not_closed")
            try require(stats.dictionaries == 0 && stats.counts == 0, "stale_constructor_performed_more_native_work")
            try require(OtzariaTantivySearchRepository.shared.observedOpenIndexDocumentCount(databasePath: source.database) == nil,
                        "stale_constructor_published")
        }
        await checks.run("failed_constructor_never_publishes") {
            let source = try OwnershipSource.make("constructor-failure")
            OwnershipNativeDouble.constructorFailure(true)
            try await refuses(["engine_error"]) { try await source.prepare() }
            let stats = OwnershipNativeDouble.stats()
            try require(stats.constructors == 1 && stats.closes == 0 && stats.dictionaries == 0 && stats.counts == 0,
                        "failed_constructor_advanced")
            try require(OtzariaTantivySearchRepository.shared.observedOpenIndexDocumentCount(databasePath: source.database) == nil,
                        "failed_constructor_published")
        }
        await checks.run("configuration_failure_closes_unpublished_handle") {
            let source = try OwnershipSource.make("configuration-failure")
            OwnershipNativeDouble.configuration(false)
            try await refuses(["engine_error"]) { try await source.prepare() }
            let stats = OwnershipNativeDouble.stats()
            try require(stats.constructors == 1 && stats.closes == 1 && stats.counts == 0, "configuration_failure_retained_handle")
            try require(OtzariaTantivySearchRepository.shared.observedOpenIndexDocumentCount(databasePath: source.database) == nil,
                        "configuration_failure_published")
        }
        await checks.run("wrong_manifest_count_closes_unpublished_handle") {
            let source = try OwnershipSource.make("count-mismatch")
            OwnershipNativeDouble.count(16)
            try await refuses(["unavailable"]) { try await source.prepare() }
            let stats = OwnershipNativeDouble.stats()
            try require(stats.constructors == 1 && stats.closes == 1 && stats.counts == 1, "count_mismatch_retained_handle")
            try require(OtzariaTantivySearchRepository.shared.observedOpenIndexDocumentCount(databasePath: source.database) == nil,
                        "count_mismatch_published")
        }
        await checks.run("valid_cold_open_uses_original_cache_once") {
            let source = try OwnershipSource.make("valid-cache")
            try await source.prepare()
            try require(OtzariaTantivySearchRepository.shared.observedOpenIndexDocumentCount(databasePath: source.database) == 17,
                        "original_cache_not_populated")
            try await source.prepare()
            let stats = OwnershipNativeDouble.stats()
            try require(stats.constructors == 1 && stats.closes == 0 && stats.dictionaries == 1,
                        "second_preparation_replaced_original_owner")
        }
        await checks.run("original_legacy_constructor_keeps_existing_directory_behavior") {
            let source = try OwnershipSource.make("legacy-constructor")
            let absent = source.index.appendingPathComponent("legacy-owned-new-directory")
            let engine = try OtzariaSearchEngineBridge(indexURL: absent)
            try require(FileManager.default.fileExists(atPath: absent.path), "legacy_constructor_changed")
            engine.close()
            try require(OwnershipNativeDouble.stats().constructors == 1, "legacy_constructor_not_used")
        }
        await checks.run("pre_cancelled_execution_has_no_native_open") {
            let source = try OwnershipSource.make("pre-cancelled")
            let task = Task.detached {
                withUnsafeCurrentTask { $0?.cancel() }
                try await source.prepare()
            }
            try await refuses(["cancelled"]) { try await task.value }
            try source.requireNoOpenOrPublication()
        }
        await checks.run("expired_deadline_has_no_native_open") {
            let source = try OwnershipSource.make("expired")
            try await refuses(["deadline"]) { try await source.prepare(milliseconds: 0) }
            try source.requireNoOpenOrPublication()
        }
        await checks.run("constructor_metadata_change_is_closed_before_configuration") {
            let source = try OwnershipSource.make("constructor-metadata")
            OwnershipNativeDouble.afterConstructor.update { $0 = {
                try? Data("changed-owned-fixture".utf8).write(to: source.index.appendingPathComponent("identity.json"))
            } }
            try await refuses(["source_changed"]) { try await source.prepare() }
            let stats = OwnershipNativeDouble.stats()
            try require(stats.closes == 1 && stats.dictionaries == 0 && stats.counts == 0,
                        "changed_metadata_allowed_more_native_work")
        }
        await checks.run("cancellation_during_constructor_closes_without_configuration") {
            let source = try OwnershipSource.make("constructor-cancel")
            OwnershipNativeDouble.afterConstructor.update { $0 = { withUnsafeCurrentTask { $0?.cancel() } } }
            let task = Task.detached { try await source.prepare() }
            try await refuses(["cancelled"]) { try await task.value }
            let stats = OwnershipNativeDouble.stats()
            try require(stats.constructors == 1 && stats.closes == 1 && stats.dictionaries == 0 && stats.counts == 0,
                        "cancelled_constructor_advanced")
        }
        await checks.run("deadline_during_constructor_rejects_late_publication") {
            let source = try OwnershipSource.make("constructor-deadline")
            OwnershipNativeDouble.afterConstructor.update { $0 = { Thread.sleep(forTimeInterval: 1.6) } }
            try await refuses(["deadline"]) { try await source.prepare(milliseconds: 1500) }
            let stats = OwnershipNativeDouble.stats()
            try require(stats.constructors == 1 && stats.closes == 1 && stats.dictionaries == 0 && stats.counts == 0,
                        "late_constructor_advanced")
        }
        checks.finish()
    }
}
