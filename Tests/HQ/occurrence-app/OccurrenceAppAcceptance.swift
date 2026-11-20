import Foundation
import OtzariaActionCore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(ucrt)
import ucrt
#endif

@main
struct OccurrenceAppAcceptance {
    struct Report: Encodable {
        let sourceCommit: String
        let qualificationExpected: Bool
        let wholeProductionFiles: Bool
        let actualOriginalOwner: Bool
        let passed: Int
        let failed: Int
        let cases: [OccurrenceAppCaseRecord]
        let positiveManagedNativeCounting: String
        let CorePermissionAdmission: String
        let AppleSDK: String
        let NativeUI: String
        let unsafeUserPathDiagnostics: String
    }
    static func main() async {
        guard CommandLine.arguments.count == 5,
              ["unqualified", "qualified"].contains(CommandLine.arguments[3]) else {
            print("requires owned descriptor, report path, expected registry state, source commit")
            exit(2)
        }
        let qualified = CommandLine.arguments[3] == "qualified"
        var runner = OccurrenceAppRunner()
        var positives = "NOT_RUN: original qualification registry is OFF"
        do {
            let fixture = try OccurrenceAppFixture(descriptorURL: URL(fileURLWithPath: CommandLine.arguments[1]))
            await runner.run("actual_original_C_source_and_producer_identity", category: "provenance") {
                try OccurrenceAppPolicyCases.source(fixture)
            }
            await runner.run("original_profile_and_installation_model", category: "provenance") {
                try OccurrenceAppPolicyCases.originalProfile(fixture)
            }
            await runner.run("actual_SHA256_known_vector", category: "authentication") {
                try requireAppOccurrence(ActionOccurrenceCoveragePolicy.sha256(Data("abc".utf8)) ==
                    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "Actual official SHA256")
            }
            await runner.run("complete_original_mini_and_full_manifests", category: "authentication") {
                try OccurrenceAppPolicyCases.authenticate(fixture)
            }
            await runner.run("legitimate_original_Codable_reencoding", category: "authentication") {
                try OccurrenceAppPolicyCases.reencoding(fixture)
            }
            await runner.run("twenty_nested_complete_manifest_tamper_rejections", category: "authentication") {
                try OccurrenceAppPolicyCases.tampering(fixture)
            }
            await runner.run("canonical_scope_UInt64_and_200_work_bound", category: "scope") {
                try OccurrenceAppPolicyCases.canonicalScopes()
            }
            await runner.run("noncanonical_duplicate_and_foreign_scopes_rejected", category: "scope") {
                try OccurrenceAppPolicyCases.noncanonicalScopes()
            }
            await runner.run("unsupported_modes_units_backends_and_text", category: "scope") {
                try OccurrenceAppPolicyCases.unsupportedQueries()
            }
            await runner.run("actual_production_registry_controls_coverage", category: "admission") {
                try OccurrenceAppPolicyCases.actualAdmission(fixture, qualified: qualified)
            }
            await runner.run("original_owner_initial_publish_clear_and_ABA", category: "owner") {
                try OccurrenceAppOwnerCases.initialAndABA()
            }
            await runner.run("original_owner_same_pair_revokes_old_revision", category: "owner") {
                try OccurrenceAppOwnerCases.sameSelectionStillPublishes()
            }
            await runner.run("original_owner_16000_publications_24000_coherent_snapshots", category: "owner") {
                try await OccurrenceAppOwnerCases.concurrentPublication()
            }
            await runner.run("unopened_app_discovery_and_count_never_construct_engine", category: "counter") {
                try await OccurrenceAppCounterCases.unopened(fixture, qualified: qualified)
            }
            await runner.run("unknown_external_and_noncanonical_managed_sources_fail_closed", category: "counter") {
                try await OccurrenceAppCounterCases.selectionGuards(fixture)
            }
            await runner.run("foreign_backend_readiness_and_count_rejected", category: "counter") {
                try await OccurrenceAppCounterCases.backendGuards(fixture)
            }
            await runner.run("already_elapsed_absolute_deadline_has_no_scalar", category: "counter") {
                try await OccurrenceAppCounterCases.expired(fixture)
            }
            await runner.run("already_cancelled_task_has_no_scalar", category: "counter") {
                try await OccurrenceAppCounterCases.cancelled(fixture)
            }
            for kind in ["empty", "oversized", "malformed", "directory", "missing"] {
                await runner.run("three_original_metadata_files_\(kind)_fail_closed", category: "metadata") {
                    try await OccurrenceAppCounterCases.metadata(fixture, kind: kind)
                }
            }
            if !qualified {
                await runner.run("valid_original_metadata_cannot_override_OFF_registry", category: "admission") {
                    try await OccurrenceAppCounterCases.unqualifiedCachedEngineNotNeeded(fixture)
                }
            } else {
                await runner.run("qualified_coverage_changed_installation_identity_rejected", category: "coverage") {
                    try OccurrenceAppQualifiedCases.coverageRejections(fixture)
                }
                await runner.run("whole_app_original_global_counts_match_independent_SQL", category: "original_engine") {
                    try await OccurrenceAppQualifiedCases.originalCounts(fixture, scoped: false)
                }
                await runner.run("whole_app_original_book_scopes_match_independent_SQL", category: "original_engine") {
                    try await OccurrenceAppQualifiedCases.originalCounts(fixture, scoped: true)
                }
                await runner.run("original_analyzer_rejects_multiple_tokens", category: "original_engine") {
                    try await OccurrenceAppQualifiedCases.originalAnalyzerRejectsMultipleTokens(fixture)
                }
                for kind in ["selectionABA", "generation", "manifest"] {
                    let suffix = kind == "selectionABA" ? "selection_ABA" : kind
                    await runner.run("actual_post_count_\(suffix)_revokes_result", category: "source_lifetime") {
                        try await OccurrenceAppQualifiedCases.postCountMutation(fixture, kind: kind)
                    }
                }
                await runner.run("app_queued_cancellation_returns_before_engine_queue_release", category: "source_lifetime") {
                    try await OccurrenceAppQualifiedCases.queuedRevocation(fixture, cancel: true)
                }
                await runner.run("app_queued_deadline_returns_before_engine_queue_release", category: "source_lifetime") {
                    try await OccurrenceAppQualifiedCases.queuedRevocation(fixture, cancel: false)
                }
                positives = "EXECUTED: actual original mini C counts; each case result is recorded separately; no Native UI claim"
            }
            fixture.repository.closeAllEngines()
        } catch {
            runner.records.append(.init(name: "bootstrap", category: "environment", passed: false,
                                        seconds: 0, detail: String(describing: error)))
            print("FAIL bootstrap: \(error)")
        }
        let passed = runner.records.filter(\.passed).count
        let failed = runner.records.count - passed
        let report = Report(sourceCommit: CommandLine.arguments[4], qualificationExpected: qualified,
            wholeProductionFiles: true, actualOriginalOwner: true, passed: passed, failed: failed,
            cases: runner.records, positiveManagedNativeCounting: positives,
            CorePermissionAdmission: "NOT_RUN: direct trusted app-port fixture; whole original Core DTOs compiled",
            AppleSDK: "NOT_RUN", NativeUI: "NOT_RUN", unsafeUserPathDiagnostics: "NOT_RUN")
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic)
        } catch { print("Cannot persist evidence: \(error)"); exit(2) }
        print("RESULT \(passed) PASS \(failed) FAIL")
        exit(failed == 0 ? 0 : 1)
    }
}
