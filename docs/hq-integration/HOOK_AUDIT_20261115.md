# Minimal Xcode source-registration hook audit — 2026-11-15

[תומר | INT] [MAIN_SESSION]
Desktop UUID: 01a1dc86-0c7b-7ee3-a098-2b4004ed686d

Status: PRE_EDIT_AUDIT / awaiting all lane new-source contracts before one registration patch.

- Repository: davidpovarsky/Maktabah; integration branch codex/otzaria-integration-20261115, base df2a21941afa46da716387fce9de620865d2a151.
- Actual upstream main: d46af139b3a265399c16d87f5923acd8e3444024 (read-only ls-remote and nontruncated Git Trees API); current upstream project blob cfd72d9129dfc1b7a3120991ac97df653d351412.
- Fork baseline project blob: e362c40f6842ec3b2530ab0e919b52888b4f6196. This project already diverges; this patch does not claim an upstream sync or repair historical project debt.
- Ownership: Maktabah.xcodeproj/project.pbxproj is UPSTREAM_OWNED / SHARED_INTEGRATION_SEAM. Exclusive lease granted by Lead; source writers do not edit it.
- Concrete delivered source path: Source/ChavrusaText/BookUpdates/MaktabahBookUpdateSafety.swift, confirmed by Dana in her updates worktree; registration-only tree will not copy or merge it. Final source commit/hash remains a handoff dependency.
- Intended target scope: mirror the existing shared updater's Maktabah, Maktabah-Direct and Maktabah-iOS source phases. No widget or tests registration. Dana requested all app targets compiling the shared updater. Foundation/SQLite3 imports are already supported by these targets.
- Necessity: ChavrusaText is an explicit PBXGroup (CFEE00000000000000000001), not an app-target synchronized folder. A standalone Swift source cannot link into callers without PBXFileReference, PBXBuildFile and Sources entries. Directory creation alone does not establish membership.
- Rejected alternatives: no new synchronized root/group, package, dependency, build rule or duplicate source; those broaden the project change. Do not move helper logic into upstream updater files to avoid registration; downstream isolation is the authorized architecture.
- Exact planned connection: one PBXFileReference path BookUpdates/MaktabahBookUpdateSafety.swift under existing ChavrusaText group, three target-specific PBXBuildFile objects, one child entry and one entry in each of the three existing Sources lists. No existing record removed/reordered or build setting changed. Additional real new sources, if handed off before freeze, require their own explicit row/audit.
- Sources phase IDs: Maktabah 4B3202242EDAFE85003B95D1; Maktabah-Direct 4B7C90A52F83494200454BE1; Maktabah-iOS F30576E22FA46222005732C6.
- Focused validation: read-only stdlib OpenStep token/structure parser; compare all existing object payloads and order against base, allow only additive source/group wiring; require each new source exactly once in intended targets, none in widget/tests; confirm actual source exists in writer tree; run existing iOS project membership verifier and git diff --check. No claim of Xcode parser/compiler/link/runtime acceptance.
- Baseline debt discovered while preparing check: identical duplicate object keys 240682637A5169A63619E577, FB254BD29A50C530E907662A, FDB5242B5960EB1507BD74A6, 3373C7B02164CDBB77BFFF48, C2CCE35AFE445BF8BEF37C5F. They are unchanged existing debt; checker reports/compares them and refuses introduced/changed duplicates. No unrelated cleanup here. Historical duplicate compile-source warnings also require separate review.
- Tests/build/device gates: target graph only in this tranche. No app build, CI, release, TestFlight, source merge or user-data operation authorized/performed.
- Rollback: after future controlled integration, revert only the registration patch's added object/child/phase lines. Do not reset project settings, remove occupied worktrees or roll back caller changes independently of their helper. Before integration, discard/revise only this integrator's own patch if the delivered path/target contract changes.
- Reviewer: Lead for batch contract, Roni for consolidated acceptance. No functional DONE from source registration.

## QA guard contract acknowledged

Read QA evidence-qa-20261115.md: Q01-Q09 remain current-wave NOT_RUN / physical BLOCKED_DEVICE. Roni's 5/5 AST mutation checks characterize the historical exact-source guard, not the repaired UI. Historical guard pins dot-strip-only drag and Nov10 blob/approval records; it may truthfully reject a newly authorized Nov15 necessary hook. Keep that historical result distinct from current-policy manual hunk review. Do not edit source/guard/manifests to manufacture green, forge an approval or treat a legacy failure as an automatic approval rejection. No extra permission loop is created. No guards, workflows, lockfiles or shared exception registers are writable in this integrator lease.

Inspector also confirmed NONE new app Swift sources; new fixtures are Tests/HQ/inspector only. Reader asked once for any additional actual source-registration need. Search contract pending. Registration remains a single pending source-wiring patch, not a build/functional acceptance claim.

## Applied registration patch

Status: REGISTRATION_PATCH_READY_FOR_REVIEW (source integration and app/device acceptance still pending).

All production source contracts received: Search NONE, Reader NONE, Inspector NONE, Sidebar NONE. Their Tests/HQ fixtures are excluded from app targets. Sidebar UI-test source is prepared NOT_RUN and is not registered by this app-source patch; its eventual test-target registration belongs to a separately authorized runtime stage.

The only new app source is Dana's confirmed MaktabahBookUpdateSafety.swift. Applied exactly 8 additive project lines: one PBXFileReference + three PBXBuildFile objects + one existing-group child + three existing Sources entries. Four new objects; four existing objects change only their children/files lists. Existing object payloads/order, phases, target membership, settings, dependency pins, resources and signing remain as before.

- Final project blob: 1a47e35e87136170b34f4ace98ddbb3cc328f0d6.
- FileRef 93BC6D6F42379C09C6C58650; build IDs Maktabah 12625FDCCD291F169D6788B2, Direct 36A587F9D67487F899E8D564, iOS CC37848F7DE08819914E0505.
- Source snapshot SHA256 at structural check: BDA23849D247607E44E4286DEBF9372C3901C2E365E8CD14A3D76E358BBCFBFD. Producer source is still uncommitted at this checkpoint; its final coherent source SHA must be recorded at batch handoff. Registration depends on the path/target contract, not this implementation snapshot.
- Executed PASS: stdlib project token/graph/diff verifier, expected source exists in Updates tree, exactly-once three app-target membership, widget/test exclusion, unchanged inherited duplicates; existing iOS membership verifier (91 Otzaria sources, engines/dictionaries); git diff --check.
- Source is intentionally ABSENT in this registration-only integration tree: no copy/merge/cherry-pick was permitted. This branch alone is not a buildable repaired application. Combine only through an authorized coherent batch integration with the matching Updates source/caller commits.
- No Xcode parsing/compiler/linkage/runtime/device/CI/release was run. Legacy exact-source guard was not rerun by the integrator and is not claimed green. QA reported historical stale-pin behavior separately.
