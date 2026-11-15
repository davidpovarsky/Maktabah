# waitForMount strict Swift capture correction

The manager's terminal native43752226209 compile on immutable043/app source174 fails at the two `mountWaiters` references inside `onCancel { [weak self] in Task { @MainActor in ... } }`. Actual Xcode27.1/Swift6.4 diagnostics identify source lines159:33/160:17, compiler log68920/68931. The manager-provided artifact14177879442/SHA `0a3bdd0efc9fb832334dd31cea29d1c5d4bae826e07cd02a85b4461605ab4de9` remains its authority. There were0 UI PASS/0FAIL/18NOT_RUN, not failing UI assertions. N read the supplied local exact compiler excerpt; it did not query/fetch/watch/retry that job or invoke SDK/CI.

## Exact fix and compatibility

Only two production lines change in N-owned `MaktabahNativeRoutingComposition.swift`: `self.mountWaiters` explicitly qualifies the original token lookup and removal/resume after `guard let self`. The closure capture, original token guard, MainActor hop, finite16 capacity, checked continuation and error behavior are otherwise unchanged. No public API, policy, DTO, handler, deadline, registration or activation changes.

The complete original `waitForMount` body and waiter type in frozen043 are identical to N's pre-fix future method. The corrected complete frozen method is identical to the fixed future body. `N_043_MOUNT_WAIT_EXPLICIT_SELF_UNAPPLIED.diff` is generated against exact043, touches only those two lines and introduces no future/v2 dependency. It passes separate `git apply --check` operations against isolated original043 and candidate98 copies. Neither original/frozen/manager tree is edited. `N-mount-wait-backport.json` records the original blob, exact patch/method hashes and checks. Manager applies/reviews this separately; no automatic native rerun is requested.

## Actual discriminating compilation and semantics

The harness compiles the COMPLETE actual method and exact private MountWaiter declaration, not an equivalent rewritten cancellation method. It uses real Foundation Task, MainActor, checked continuations and actual UIStableID/UIRouteError. Native registration/session data, deterministic read events and an independently prepared replacement ledger continuation are explicit shells. The boundary and all tests are byte-identical in final RED/GREEN; only the complete method's two explicit prefixes differ.

Strict portable Windows Swift6.3.3 RED: **two unique source compiler error sites**, both requiring explicit self; zero tests execute. GREEN: **seven distinct XCTest methods / 0 failures / 0 compiler warnings**. Full named results and raw input/log/source hashes are in `N-mount-wait-report.json` and adjacent manifests. This is not an Apple/SwiftUI SDK PASS.

The seven methods cover exact pre-mounted manager with no waiter, already-cancelled invocation even when mounted, cancellation between entry check and continuation creation, queued cancellation and no late double resume, exact manager mount/resume with another waiter still queued, duplicate/ambiguous/full16 rejection with mounted fast path and full cancellation cleanup, and delayed old cancellation against a genuinely different prepared continuation/token. The last case waits for the old cancellation Task's actual ledger read before checking the new waiter; it does not assume Task.yield/scheduler order. Old cleanup cannot remove or resume the replacement token.

Initial test-fixture compile attempts contained async assertions in XCTest autoclosures and missing MainActor annotations in event wait helpers. Those zero-test fixture logs/manifests are retained separately and are not relabeled as the clean two-site product RED or passing methods. The final pair has neither fixture error.

Commands use focused `swift test --filter NMountWaitTests -j1 -Xswiftc -strict-concurrency=complete` with the package's Swift6 language mode. Existing unrelated package suites are not rerun/recounted as seven additional full-suite results. Preparation, exact backport and finalization scripts are included. Raw log/input paths have scoped `-text` attributes; committed bytes are checked against their SHA values.

## Gates

Only N's future composition file receives the two-line source change. The compatible043 proposal remains unapplied outside the isolated check. Prior043/98 commits and their native/source evidence, R reconciliation, lifecycle/lease approvals, protected hooks, project graph and defaultOFF are preserved. No SDK/native/CI query/watch/dispatch/cancel/retry, new release action or feature enablement occurs here. The manager independently reviews/integrates this routine compiler correction; real app/native acceptance stays open.
