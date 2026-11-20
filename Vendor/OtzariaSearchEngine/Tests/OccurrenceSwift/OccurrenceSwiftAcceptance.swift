import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(ucrt)
import ucrt
#endif

@main
struct OccurrenceSwiftAcceptance {
    private struct Manifest: Decodable {
        let commit: String
        let repository: String
        let branch: String
        let original_upstream_base: String
        let index_schema_version: UInt32
        let engine_package_version: String
    }

    private struct Report: Encodable {
        let sourceCommit: String
        let wholeOriginalBridge: Bool
        let passed: Int
        let failed: Int
        let cases: [OccurrenceCaseRecord]
        let platform: String
        let AppleSDK: String
        let NativeUI: String
        let originalUserPathDiagnostics: String
    }

    static func main() async {
        guard CommandLine.arguments.count == 3 else {
            print("requires upstream manifest and owned report output; accepts no index path")
            exit(2)
        }
        var runner = OccurrenceTestRunner()
        var commit = "UNKNOWN"
        do {
            let manifest = try JSONDecoder().decode(
                Manifest.self,
                from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
            )
            let source = try OtzariaExactOccurrenceSource(
                engineCommit: manifest.commit, engineRepository: manifest.repository,
                engineBranch: manifest.branch, originalUpstreamBase: manifest.original_upstream_base,
                indexSchemaVersion: manifest.index_schema_version,
                enginePackageVersion: manifest.engine_package_version
            )
            try source.validate(buildInfo: OtzariaSearchEngineBridge.buildInfo())
            commit = manifest.commit
            await runner.run("official_crypto_known_SHA256", category: "dependency") {
                let hash = SHA256.hash(data: Data("abc".utf8)).map { String(format: "%02x", $0) }.joined()
                try requireOccurrence(hash == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
                                      "Official dependency must provide the actual SHA256 implementation")
            }
            await runner.run("whole_bridge_legacy_and_two_positions_one_document", category: "original_engine") {
                try await OccurrenceNativeCases.basic(source)
            }
            await runner.run("original_hebrew_analyzer_and_prefix_exclusion", category: "original_engine") {
                try await OccurrenceNativeCases.normalization(source)
            }
            await runner.run("original_book_and_facet_dimensions", category: "original_engine") {
                try await OccurrenceNativeCases.scopes(source)
            }
            await runner.run("byte_exact_unicode_scope_identity", category: "original_engine") {
                try await OccurrenceNativeCases.byteExactScopes(source)
            }
            await runner.run("actual_deleted_postings_and_snapshot", category: "original_engine") {
                try await OccurrenceNativeCases.deletions(source)
            }
            await runner.run("authoritative_zero_matches", category: "original_engine") {
                try await OccurrenceNativeCases.zero(source)
            }
            await runner.run("empty_and_multiple_tokens_are_unsupported", category: "original_engine") {
                try await OccurrenceNativeCases.unsupported(source)
            }
            await runner.run("all_original_work_budgets_return_no_scalar", category: "original_engine") {
                try await OccurrenceNativeCases.budget(source)
            }
            await runner.run("already_elapsed_deadline_returns_no_scalar", category: "lifetime") {
                try await OccurrenceNativeCases.expired(source)
            }
            await runner.run("compiled_source_mismatch_cannot_enqueue", category: "source_validation") {
                try await OccurrenceNativeCases.sourceMismatch(source)
            }
            await runner.run("oversized_json_envelope_cannot_enqueue", category: "input_validation") {
                try await OccurrenceNativeCases.oversizedEnvelope(source)
            }
            await runner.run("cancel_before_continuation_registration", category: "lifetime") {
                try await OccurrenceLifetimeCases.cancelBeforeContinuation(source)
            }
            await runner.run("precancelled_task_cannot_enqueue", category: "lifetime") {
                try await OccurrenceLifetimeCases.precancelledTask(source)
            }
            await runner.run("queued_cancellation_returns_before_queue_release", category: "lifetime") {
                try await OccurrenceLifetimeCases.queuedCancellation(source)
            }
            await runner.run("queued_deadline_returns_before_queue_release", category: "lifetime") {
                try await OccurrenceLifetimeCases.queuedDeadline(source)
            }
            await runner.run("cancellation_isolated_from_other_queued_request", category: "lifetime") {
                try await OccurrenceLifetimeCases.cancellationIsolation(source)
            }
            await runner.run("cancelled_queued_capacity_retained_then_recovers", category: "lifetime") {
                try await OccurrenceLifetimeCases.retainedCapacity(source)
            }
            await runner.run("close_cancels_before_queue_sync", category: "lifetime") {
                try await OccurrenceLifetimeCases.closeBeforeQueueSync(source)
            }
            await runner.run("concurrent_close_revokes_completed_native_count", category: "lifetime") {
                try await OccurrenceLifetimeCases.concurrentCloseAfterRealCount(source)
            }
            await runner.run("own_queue_close_does_not_self_sync", category: "lifetime") {
                try await OccurrenceLifetimeCases.ownQueueClose()
            }
            await runner.run("final_engine_retain_released_on_original_queue", category: "lifetime") {
                try await OccurrenceLifetimeCases.finalRetainOnOwnQueue(source)
            }
            await runner.run("deadline_timer_has_no_owner_retain_cycle", category: "lifetime") {
                try await OccurrenceLifetimeCases.timerDoesNotRetainOwner(source)
            }
            await runner.run("repository_unopened_never_constructs_engine", category: "repository") {
                try await OccurrenceRepositoryCases.unopened(source)
            }
            await runner.run("repository_uses_original_cached_engine_and_real_count", category: "repository") {
                try await OccurrenceRepositoryCases.originalCachedEngine(source)
            }
            await runner.run("repository_rejects_stale_revision_and_fingerprint_before_enqueue", category: "repository") {
                try await OccurrenceRepositoryCases.staleExpectations(source)
            }
            await runner.run("repository_optional_manifests_preserve_custom_readiness", category: "repository") {
                try await OccurrenceRepositoryCases.missingManifests(source)
            }
            await runner.run("repository_both_manifests_revoke_old_cached_stamp", category: "repository") {
                try await OccurrenceRepositoryCases.manifestsEnterWitness(source)
            }
            await runner.run("repository_oversized_manifest_has_no_fingerprint", category: "repository") {
                try await OccurrenceRepositoryCases.oversizedManifest(source)
            }
            await runner.run("repository_four_source_mutations_after_real_native_count", category: "repository") {
                try await OccurrenceRepositoryCases.postCountSourceMutation(source)
            }
            await runner.run("repository_invalidation_cancels_original_engine_lease", category: "repository") {
                try await OccurrenceRepositoryCases.invalidationCancelsLease(source)
            }
            await runner.run("repository_capture_lock_wait_is_cancellable", category: "repository") {
                try await OccurrenceRepositoryCases.cacheLockCancellation(source)
            }
            await runner.run("repository_capture_lock_wait_obeys_deadline", category: "repository") {
                try await OccurrenceRepositoryCases.cacheLockDeadline(source)
            }
            await runner.run("repository_lock_wait_consumes_original_native_deadline", category: "repository") {
                try await OccurrenceRepositoryCases.cacheWaitConsumesDeadline(source)
            }
            await runner.run("repository_post_count_lock_wait_is_cancellable", category: "repository") {
                try await OccurrenceRepositoryCases.postCountLock(source, cancel: true)
            }
            await runner.run("repository_post_count_lock_wait_obeys_deadline", category: "repository") {
                try await OccurrenceRepositoryCases.postCountLock(source, cancel: false)
            }
            await runner.run("repository_supported_ABA_revision_rejects_old_authority", category: "repository") {
                try await OccurrenceRepositoryCases.publicationABA(source)
            }
            await runner.run("forged_response_proofs_are_rejected", category: "decoder_adversarial") {
                try await OccurrenceDecoderCases.tamperedProof(source)
            }
            await runner.run("UInt64_identifiers_do_not_round_through_double", category: "decoder_adversarial") {
                try await OccurrenceDecoderCases.integerPrecision(source)
            }
            await runner.run("native_error_messages_are_not_exposed", category: "decoder_adversarial") {
                try OccurrenceDecoderCases.errorRedaction()
            }
            await runner.run("typed_request_bounds", category: "input_validation") {
                try OccurrenceDecoderCases.requestBounds()
            }
        } catch {
            runner.records.append(.init(name: "bootstrap", category: "environment", passed: false,
                                        seconds: 0, detail: String(describing: error)))
        }
        await runner.run("owned_fixture_cleanup", category: "fixture") {
            let failures = OccurrenceFixtureRegistry.shared.removeAll()
            try requireOccurrence(failures.isEmpty, "Owned fixture cleanup: \(failures)")
        }
        let passed = runner.records.filter(\.passed).count
        let failed = runner.records.count - passed
        let report = Report(
            sourceCommit: commit, wholeOriginalBridge: true,
            passed: passed, failed: failed, cases: runner.records,
            platform: "Windows Swift 6.3.3 + real C + original Rust",
            AppleSDK: "NOT_RUN", NativeUI: "NOT_RUN", originalUserPathDiagnostics: "NOT_RUN"
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(
                to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic
            )
        } catch {
            print("Cannot persist runtime evidence: \(error)")
            exit(2)
        }
        print("RESULT \(passed) PASS \(failed) FAIL")
        exit(failed == 0 ? 0 : 1)
    }
}
