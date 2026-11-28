from pathlib import Path
import argparse, hashlib, json, re, subprocess

parser = argparse.ArgumentParser(description="Generate exact current consumer methods and explicit boundary controls; no tests are run here.")
parser.add_argument("--source-root", type=Path, required=True)
parser.add_argument("--artifacts-dir", type=Path, required=True)
args = parser.parse_args()
root = args.source_root.resolve()
base = 'Source/ChavrusaText/Annotations/LocalEditor/'
receive = (root / base / 'AnnotationOriginalEditorReceive.swift').read_text()
revision = (root / base / 'AnnotationOriginalEditorRevision.swift').read_text()
baseline = subprocess.check_output(["git", "-C", str(root), "show",
    "ccad81d5b5256027239c38ce0eaba028f6fb887a:" + base + "AnnotationOriginalEditorReceive.swift"], text=True)

def function(text, name):
    start = text.index('    ' + name)
    brace = text.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        if text[end] == '{': depth += 1
        if text[end] == '}': depth -= 1
        end += 1
    return text[start:end] + '\n'

names = ['func begin()', 'private func requireOpen()', 'private func advance(',
         'func close(', 'func removed()', 'private func fail()', 'private func applyRevisionOutcome(']
methods = {n: function(receive, n) for n in names}
history = '\n'.join(function(revision, n) for n in ['func durableOutcome()', 'func recordedOutcomeIfDrained()'])
drain = function(revision, 'func drainAdmittedOutcome()')
stage = re.search(r'    enum Stage \{[^\n]+\}', receive).group(0)
canclose = re.search(r'    var canClose: Bool \{[^\n]+\}', receive).group(0)

header = r'''import Foundation

enum ProbeError: Error { case originalStop, durableWrite }
enum AnnotationLocalEditorError: Error { case retired }
struct AnnotationOriginalEditorRevisionOutcome: Sendable {
    enum Kind: Sendable { case verified, conflict, unverified }
    let kind: Kind
    let url: URL
}
enum AnnotationOriginalEditorRevisionError: Error { case unobservedDrain }

actor Latch {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        opened = true
        let pending = waiters; waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
}

@MainActor final class Lifetime {
    var retires = 0
    func retire() { retires += 1 }
}
@MainActor final class Presentation {
    var closes = 0
    var retries = 0
    var failFirst = false
    func close() async throws {
        closes += 1
        if failFirst { throw ProbeError.originalStop }
    }
    func retryClose() async throws { retries += 1 }
}
@MainActor final class History {
    var native: Bool?
    var durableWrite: Task<AnnotationOriginalEditorRevisionOutcome, Error>?
    var waiters: [CheckedContinuation<Void, Never>] = []
    let writeGate = Latch()
    let writeStarted = Latch()
    var failWrite = false
    func publishNative() {
        guard native == nil else { return }
        native = true
        let gate = writeGate, started = writeStarted, failure = failWrite
        durableWrite = Task.detached {
            await started.open()
            await gate.wait()
            if failure { throw ProbeError.durableWrite }
            return AnnotationOriginalEditorRevisionOutcome(kind: .unverified,
                url: URL(fileURLWithPath: "/owned/result.json"))
        }
        let pending = waiters; waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
__HISTORY__
}
@MainActor final class Attempt {
    let history = History()
    var nativeInvocationStarted = false
    var cancellations = 0
    var retires = 0
    func requestCancellation() { cancellations += 1 }
    func retire() { retires += 1 }
__DRAIN__
}

@MainActor final class Model {
__STAGE__
    var startupTask: Task<Void, Never>?
    var operation: Task<Void, Never>?
    var closeRequested = false
    var closeError: (any Error)?
    var closeTask: Task<Void, Never>?
    var began = false
    var stage = Stage.opening
    let lifetime = Lifetime()
    let observation: Lifetime? = Lifetime()
    let local: Lifetime? = Lifetime()
    let nativeSource: Lifetime? = Lifetime()
    var revisionAttempt: Attempt?
    var revisionOutcome: AnnotationOriginalEditorRevisionOutcome?
    var presentation: Presentation? = Presentation()
    var account: Int? = 1
    let startupGate = Latch()
    let startupEntered = Latch()
    var startupFinished = false
    var startupCancelled = false
    var startupCount = 0
    let pendingGate = Latch()
    let pendingEntered = Latch()
    var pendingFinished = false
    var pendingCancelled = false
    var retainedCommit = false
__CANCLOSE__
    private func beginOwned() async {
        startupCount += 1
        await startupEntered.open()
        await startupGate.wait()
        startupCancelled = Task.isCancelled
        startupFinished = true
        advance(to: .authenticating)
    }
    func startPending(_ stage: Stage) {
        self.stage = stage
        operation = Task { [self] in
            defer { operation = nil }
            await pendingEntered.open()
            await pendingGate.wait()
            pendingCancelled = Task.isCancelled
            retainedCommit = true
            pendingFinished = true
            advance(to: .saved)
        }
    }
    func finishClose() async { if let closeTask { await closeTask.value } }
    func lateUI() { advance(to: .saved); fail() }
    func checkOpen() -> Bool { (try? requireOpen()) != nil }
__METHODS__
}
'''

tests = r'''
@MainActor func turns() async { for _ in 0..<32 { await Task.yield() } }
@MainActor final class Checks {
    var failed = 0
    var rows: [[String: String]] = []
    func check(_ value: Bool, _ name: String) {
        rows.append(["name": name, "status": value ? "PASS" : "FAIL"])
        if !value { failed += 1 }
    }
}

@main struct Controls {
    @MainActor static func main() async {
        let checks = Checks()
        let originalOnly = CommandLine.arguments.contains("--original-close")

        do {
            let model = Model(), presentation = Model().presentation!
            model.presentation = presentation
            model.startPending(.reading)
            await model.pendingEntered.wait()
            model.close()
            await turns()
            checks.check(model.stage == .closing && !model.pendingFinished && presentation.closes == 0,
                         "close waits admitted local operation before account release")
            await model.pendingGate.open()
            await model.finishClose()
            checks.check(model.stage == .closed && model.retainedCommit && model.pendingCancelled,
                         "cancelled operation retains actual completion before closed")
        }
        if !originalOnly {
            do {
                let model = Model(), presentation = Model().presentation!
                model.presentation = presentation
                let caller = Task { await model.begin() }
                await model.startupEntered.wait()
                caller.cancel()
                model.removed()
                await turns()
                checks.check(model.stage == .closing && presentation.closes == 0 && !model.startupFinished,
                             "removed SwiftUI startup remains joined")
                await model.startupGate.open()
                await caller.value
                await model.finishClose()
                checks.check(model.stage == .closed && model.startupFinished && model.startupCancelled,
                             "startup cancellation does not drop actual worker")
            }
            do {
                let model = Model()
                model.close()
                checks.check(!model.canClose && !model.checkOpen(), "close fences admission synchronously")
                await model.finishClose()
                await model.begin()
                checks.check(model.startupCount == 0 && model.stage == .closed, "begin cannot reopen a closed owner")
                model.lateUI()
                checks.check(model.stage == .closed, "late UI cannot reopen closed owner")
            }
            do {
                let model = Model(), presentation = Model().presentation!
                model.presentation = presentation
                model.startPending(.saving)
                await model.pendingEntered.wait()
                model.removed()
                await turns()
                checks.check(model.stage == .closing && presentation.closes == 0,
                             "removal during save joins actual persistence")
                await model.pendingGate.open()
                await model.finishClose()
                checks.check(model.stage == .closed && model.retainedCommit,
                             "save completion survives removal without late UI")
            }
            do {
                let model = Model(), attempt = Attempt(), presentation = Model().presentation!
                model.presentation = presentation; model.revisionAttempt = attempt
                attempt.nativeInvocationStarted = true
                model.startPending(.updating)
                await model.pendingEntered.wait()
                model.removed()
                await model.pendingGate.open()
                await turns()
                checks.check(model.stage == .closing && presentation.closes == 0 && attempt.cancellations == 1,
                             "cancelled native waiter waits original drain callback")
                attempt.history.publishNative()
                await attempt.history.writeStarted.wait()
                await turns()
                checks.check(model.stage == .closing && presentation.closes == 0,
                             "native callback alone cannot pass durable history barrier")
                model.lateUI()
                checks.check(model.stage == .closing, "late UI cannot reopen closing owner")
                await attempt.history.writeGate.open()
                await model.finishClose()
                checks.check(model.stage == .closed && presentation.closes == 1
                    && model.revisionOutcome?.kind == .unverified,
                    "unverified native outcome retained before account release")
            }
            do {
                let model = Model(), attempt = Attempt()
                model.revisionAttempt = attempt
                model.close()
                await model.finishClose()
                checks.check(model.stage == .closed && attempt.history.native == nil,
                             "uninvoked preparation does not await nonexistent callback")
            }
            do {
                let model = Model(), attempt = Attempt(), presentation = Model().presentation!
                model.presentation = presentation; model.revisionAttempt = attempt
                attempt.nativeInvocationStarted = true; attempt.history.failWrite = true
                attempt.history.publishNative(); await attempt.history.writeGate.open()
                model.close(); await model.finishClose()
                checks.check(model.stage == .closeFailed && model.closeError != nil
                    && model.presentation === presentation && model.account != nil && presentation.closes == 0,
                    "durable history failure retains owner and actual error")
                model.lateUI(); model.close()
                await model.finishClose()
                checks.check(model.stage == .closeFailed && presentation.closes == 0,
                             "failed history never silently releases account")
            }
            do {
                let model = Model(), presentation = Model().presentation!
                model.presentation = presentation; presentation.failFirst = true
                model.close(); await model.finishClose()
                checks.check(model.stage == .closeFailed && model.closeError != nil
                    && model.presentation === presentation && model.account != nil,
                    "original Stop failure retains presentation account and error")
                model.lateUI(); model.removed(); model.close()
                checks.check(model.stage == .closeFailed && presentation.closes == 1 && presentation.retries == 0,
                             "late completion cannot erase Stop failure or auto retry")
                model.close(retrying: true); await model.finishClose()
                checks.check(model.stage == .closed && presentation.closes == 1 && presentation.retries == 1,
                             "explicit Stop retry preserves single owner chain")
            }
            do {
                let model = Model(), presentation = Model().presentation!
                model.presentation = presentation
                model.startPending(.reading); await model.pendingEntered.wait()
                model.close(); model.close(); model.removed()
                await model.pendingGate.open(); await model.finishClose()
                checks.check(presentation.closes == 1 && model.lifetime.retires == 1,
                             "reentrant close and removal share one captured barrier")
            }
        }
        let result: [String: Any] = ["schema": "otzaria.receive-close-drain.actual-methods.v1",
            "status": checks.failed == 0 ? "PASS" : "FAIL", "passed": checks.rows.count - checks.failed,
            "failed": checks.failed, "cases": checks.rows,
            "scope": "Exact consumer lifecycle and history methods; explicit SDK, local persistence and UI boundary doubles. No native, full App, SDK, SQLite or remote acceptance."]
        let data = try! JSONSerialization.data(withJSONObject: result, options: [.sortedKeys, .prettyPrinted])
        FileHandle.standardOutput.write(data); print("")
        Foundation.exit(checks.failed == 0 ? 0 : 1)
    }
}
'''

out = args.artifacts_dir.resolve()
out.mkdir(parents=True, exist_ok=False)
source = header.replace('__HISTORY__', history).replace('__DRAIN__', drain).replace('__STAGE__', stage)
source = source.replace('__CANCLOSE__', canclose)
for mode in ['candidate', 'original-close']:
    selected = dict(methods)
    if mode == 'original-close':
        selected['func close('] = function(baseline, 'func close(')
    content = source.replace('__METHODS__', '\n'.join(selected.values())) + tests
    (out / (mode + '.swift')).write_text(content)
manifest = {'schema': 'otzaria.receive-close-drain.controls-source.v1',
    'method_extractions': {n: hashlib.sha256(v.encode()).hexdigest() for n, v in methods.items()},
    'history_sha256': hashlib.sha256(history.encode()).hexdigest(),
    'drain_sha256': hashlib.sha256(drain.encode()).hexdigest(),
    'baseline_close_sha256': hashlib.sha256(function(baseline, 'func close(').encode()).hexdigest(),
    'source_files': {str(p.relative_to(root)): {'bytes': p.stat().st_size,
        'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
        for p in sorted([root / base / 'AnnotationOriginalEditorReceive.swift', root / base / 'AnnotationOriginalEditorRevision.swift'])},
    'scope': 'Unmodified extracted consumer methods in explicit boundary shells. The original-close variant changes only close() to the exact historical function; it is not a whole old application.'}
(out / 'INPUTS.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps({'created': [p.name for p in out.iterdir()], 'method_count': len(methods) + 3}))
