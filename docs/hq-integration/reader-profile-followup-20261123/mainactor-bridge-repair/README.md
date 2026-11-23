# Explicit main-queue entry for the four-case Reader follow-up

Run 45116660011 at 99b71a011fa5a060f0334a5312d498830eaeda77 failed the real Apple Swift 6 SDK compile before any app build or native case. Its counts are 0 PASS, 0 runtime FAIL, 0 SKIP and 4 NOT_RUN. The three compiler diagnostics and all 285 execution inputs plus 11 compiler-source hashes are bound in the adjacent intake.

The existing synchronous capture helper has both MainActor-isolated and legacy nonisolated XCTest callers. The new entry checks the actual main thread before using MainActor.assumeIsolated; otherwise it synchronously enters DispatchQueue.main before assuming the actor. Observation construction, each predicate evaluation and extraction of the final diagnostic String use that same boundary. Value: Sendable prevents a mutable non-Sendable native snapshot from crossing it. Native snapshots remain within the actor-owned observer.

The original capture signature, exact predicates and assertions, 20-second settlement budget, screenshot semantics, 600-second case timeout, all 100 group transitions, and application Source/Vendor/project bytes are unchanged. The reviewed diff reverses exactly to the prior full source. No selector or acceptance condition is relaxed.

The portable Swift 6.4.3 strict-concurrency control actually executes both direct-main and background-to-main.sync paths. It verifies real Thread.isMainThread and actor-owned state. This control does not import UIKit and is not an Apple typecheck or UI result. The next gate remains the same four original failures only; the six previous passes remain attributed to their old source.
