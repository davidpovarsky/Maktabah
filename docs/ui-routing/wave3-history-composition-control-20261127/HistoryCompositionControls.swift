import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

@main struct HistoryCompositionControls {
    @MainActor static func main() async {
        var cases: [[String: Any]] = []
        func run(_ name: String, _ body: @MainActor () async throws -> Void) async {
            do { try await body(); cases.append(["name": name, "pass": true]) }
            catch { cases.append(["name": name, "pass": false, "error": String(describing: error)]) }
        }
        func failure(_ result: Result<NativeHistoryReaderIntentService.Execution, any Error>) throws -> any Error {
            if case .failure(let error) = result { return error }
            throw SourceControlFailure(message: "expected explicit failure")
        }
        func retainedFailure(_ result: Result<NativeHistoryReaderIntentService.Execution, any Error>) throws
            -> NativeHistoryReaderIntentService.Failure {
            let error = try failure(result)
            guard let value = error as? NativeHistoryReaderIntentService.Failure else {
                throw SourceControlFailure(message: "actual observed execution was not retained: \(error)")
            }
            return value
        }
        for newTab in [false, true] {
            await run("actual method keeps same captured source/window/request/deadline for \(newTab ? "new" : "current") tab") {
                let h = HistoryCompositionHarness()
                let value = try await h.invoke(newTab: newTab).get()
                try insist(h.activationCount == 1 && h.openCount == 1 && h.effectCount == 1, "single original open boundary")
                try insist(value.coreResult == h.generatedCore && value.nativeReceipt == h.generatedReceipt, "distinct original returns preserved")
                try insist(value.acknowledgement == .acknowledged(h.generatedReceipt!), "actual generic ACK returned")
                try insist(h.genericInput?.content?.focusLocator == h.input?.record.locator ||
                    h.genericInput?.content?.sectionLocator == h.input?.record.locator, "actual original saved locator")
                try insist(h.genericDeadline == h.input?.invocation.deadlineUptimeNanoseconds, "no renewed deadline")
                try insist(h.events.firstIndex(of: "window-captured")! < h.events.firstIndex(of: "activation-start")!, "window captured before activation")
                try insist(h.events.firstIndex(of: "window-revalidated")! < h.events.firstIndex(of: "generic-open")!, "same window revalidated before generic open")
                try insist(h.session.completions == [h.generatedReceipt!], "final original-session witness queried exactly once")
                try sourceRefuses { try h.retainedAtOpen!.validate() }
            }
        }
        await run("a pending native receipt cannot replace the generic returned refusal") {
            let h = HistoryCompositionHarness(); h.mode = .refuseAfterReport
            let value = try await h.invoke().get()
            try insist(value.acknowledgement == .staleState(.init(code: "fixture_generic_refused", message: "Explicit boundary refusal")), "actual refusal preserved")
            try insist(value.coreResult == h.generatedCore && value.nativeReceipt == h.generatedReceipt, "pending actual evidence separately retained")
            try insist(h.session.completions.isEmpty && h.effectCount == 1, "refusal never enters final ACK witness")
        }
        await run("throw after native report retains receipt without manufacturing ACK") {
            let h = HistoryCompositionHarness(); h.mode = .throwAfterReport
            let value = try retainedFailure(await h.invoke())
            try insist(value.execution.acknowledgement == nil, "throw did not become ACK")
            try insist(value.execution.coreResult == h.generatedCore && value.execution.nativeReceipt == h.generatedReceipt, "actual core/native evidence retained")
            try insist(value.code == "fixture_generic_failed_after_report", "original failure code")
            try insist(h.session.completions.isEmpty && h.effectCount == 1, "no synthetic completion")
        }
        await run("late original-session witness failure retains actual core receipt and returned ACK") {
            let h = HistoryCompositionHarness(); h.session.failCompletion = true
            let value = try retainedFailure(await h.invoke())
            try insist(value.code == "fixture_actual_witness_failed", "witness failure retained")
            try insist(value.execution.coreResult == h.generatedCore && value.execution.nativeReceipt == h.generatedReceipt, "actual effect evidence retained")
            try insist(value.execution.acknowledgement == .acknowledged(h.generatedReceipt!), "actual returned ACK retained as evidence inside failure")
            try insist(h.session.completions == [h.generatedReceipt!], "exact session received same actual receipt")
        }
        await run("a core-only report preserves refusal and cannot fabricate native receipt") {
            let h = HistoryCompositionHarness(); h.mode = .coreOnlyRefusal
            let value = try await h.invoke().get()
            try insist(value.coreResult == h.generatedCore && value.nativeReceipt == nil, "only actual observed values")
            try insist(value.acknowledgement == .staleState(.init(code: "fixture_generic_refused", message: "Explicit boundary refusal")), "returned refusal preserved")
        }
        await run("no-report generic refusal stays unacknowledged without effect evidence") {
            let h = HistoryCompositionHarness(); h.mode = .noReportRefusal
            let value = try await h.invoke().get()
            try insist(value.acknowledgement == .requiresForeground && value.coreResult == nil && value.nativeReceipt == nil, "actual refusal only")
            try insist(h.effectCount == 0 && h.session.completions.isEmpty, "no original effect or witness")
        }
        await run("duplicate native reports fail while retaining the first actual report") {
            let h = HistoryCompositionHarness(); h.mode = .duplicateReport
            let value = try retainedFailure(await h.invoke())
            try insist(value.code == "native_effect_uncertain" && value.execution.coreResult == h.generatedCore &&
                value.execution.nativeReceipt == h.generatedReceipt, "duplicate refused with original report retained")
            try insist(h.session.completions.isEmpty, "duplicate never becomes native completion")
        }
        await run("throw before report has no fabricated execution") {
            let h = HistoryCompositionHarness(); h.mode = .throwBeforeReport
            let error = try failure(await h.invoke())
            try insist(!(error is NativeHistoryReaderIntentService.Failure) && h.methodReturned == nil &&
                h.generatedCore == nil && h.generatedReceipt == nil && h.effectCount == 0, "no synthetic evidence")
        }
        await run("source query ABA during activation refuses before generic open") {
            let h = HistoryCompositionHarness()
            h.duringActivation = { HistoryViewModel.shared.searchText = "other"; HistoryViewModel.shared.searchText = "" }
            _ = try failure(await h.invoke())
            try insist(h.activationCount == 1 && h.openCount == 0 && h.effectCount == 0, "captured actual one-shot source refused after await")
        }
        await run("retired actual source before activation never reaches the first await") {
            let h = HistoryCompositionHarness()
            h.beforeMethod = { HistoryViewModel.shared.entriesByBookId[42]?.lastContentId = 99 }
            _ = try failure(await h.invoke())
            try insist(h.activationCount == 0 && h.openCount == 0, "metadata source retained before activation")
        }
        await run("captured window mutation during activation refuses before generic open") {
            let h = HistoryCompositionHarness(); h.duringActivation = { h.session.revision += 1 }
            _ = try failure(await h.invoke())
            try insist(h.session.captures == 1 && h.session.validations == 1 && h.openCount == 0, "original window validator survives await")
        }
        await run("same scene ID with replacement session refuses before generic open") {
            let h = HistoryCompositionHarness()
            h.duringActivation = { h.scenes[h.fixture.window.sceneID] = .init(session: MethodWindow(), manager: h.manager, managerID: ObjectIdentifier(h.manager)) }
            _ = try failure(await h.invoke())
            try insist(h.openCount == 0 && h.effectCount == 0, "replacement cannot inherit original captured scene")
        }
        await run("wrong activated scene refuses before generic open") {
            let h = HistoryCompositionHarness(); h.activatedScene = .init(rawValue: "foreign-window")!
            _ = try failure(await h.invoke())
            try insist(h.openCount == 0 && h.effectCount == 0, "no first-scene fallback")
        }
        await run("background remaining after activation refuses before generic open") {
            let h = HistoryCompositionHarness(); h.duringActivation = { h.session.foreground = false }
            _ = try failure(await h.invoke())
            try insist(h.openCount == 0 && h.effectCount == 0, "no foreground bypass")
        }
        await run("owner replacement after generic effect preserves evidence and refuses completion") {
            let h = HistoryCompositionHarness()
            h.afterReport = { h.scenes[h.fixture.window.sceneID] = .init(session: MethodWindow(), manager: h.manager, managerID: ObjectIdentifier(h.manager)) }
            let value = try retainedFailure(await h.invoke())
            try insist(value.code == "history_reader_completion_owner_changed" && value.execution.coreResult == h.generatedCore &&
                value.execution.nativeReceipt == h.generatedReceipt, "late ownership failure retains real returned values")
            try insist(h.effectCount == 1 && h.session.completions.isEmpty, "no rollback or synthetic witness")
        }
        let failed = cases.filter { $0["pass"] as? Bool != true }.count
        let report: [String: Any] = ["scope": "Verbatim original Composition method and actual History source/service/deadline/resolver over declared app/window/generic-open fixtures. Core execution, UIKit, Apple SDK and native are NOT_RUN.", "cases": cases, "passed":cases.count-failed,"failed":failed,"nativeRuns":0,"AppleSDK":"NOT_RUN","CoreExecution":"EXPLICIT_GENERIC_OPEN_BOUNDARY_NOT_RUN"]
        print(String(decoding: try! JSONSerialization.data(withJSONObject: report, options:[.sortedKeys]),as:UTF8.self))
        if failed > 0 { exit(1) }
    }
}
