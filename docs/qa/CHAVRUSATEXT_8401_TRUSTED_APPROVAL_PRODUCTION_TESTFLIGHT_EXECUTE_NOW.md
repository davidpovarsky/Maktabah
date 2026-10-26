# ChavrusaText — EXECUTE NOW: Trusted 14-Hunk Approval, Real Otzaria Production Acceptance, Xcode 27 and Internal TestFlight

**Execution instruction for ONE main coding agent — 26 October 2026**  
**Owner's explicit release instruction:** Finish the remaining engineering and verification, then **automatically upload a NEW signed internal TestFlight build using the FULL/REGULAR Otzaria `production` profile**, so the owner can test it on a physical iPad on **27 October 2026**. **Do not seek another generic release-dispatch approval** after all valid gates pass. This is **not** approval of any specific protected upstream hunk or permission to fabricate an Ed25519 signature.

**Do the work, not just a plan.** Keep going through diagnosis, targeted fixes, genuine tests, commits, CI, signing, upload, Apple processing and internal-beta availability in the current execution. If a genuine owner-controlled cryptographic approval is indispensable and unavailable, complete all independently permitted stages, prepare a one-action approval handoff and STOP at that real gate. Never bypass it or promise an upload that has not happened.

## 0. Exact, independently verified starting point

Repository: `davidpovarsky/Maktabah`  
Isolated candidate worktree: `C:\Users\DAVID\Code\Maktabah-build-8401-candidate`  
Candidate branch: `validation/maktabah-build-8401-repair-production-20261025`  
Local/remote HEAD verified: **`41ff4b7425863ea648abecd6427f70acfc82a1f6`** (documentation-only successor)  
Latest successfully compiled and tested **code** SHA: **`b7541e6caaa4cdc98e0b6ccf33b9754ab0cdf8ff`**  
CI: https://github.com/davidpovarsky/Maktabah/actions/runs/40250952113 — completed `success` on Xcode 27. Six jobs succeeded, **212/212 portable assertions passed**, **22 iPad Simulator XCUITest cases executed: 21 passed, 1 skipped, zero failed**.  
**SKIPPED** case: `BackendTransitionAcceptanceTests.testBackendSwitchViaSettingsPickerUI` at line 77: `BLOCKED: Otzaria database prerequisite is not configured on simulator`. This is **not** a backend-switch acceptance PASS.  
Base commit for candidate/patches: `031df35710ab2c6015efb1acd1e65154dbcd3f24`.  
Pinned original upstream: `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`.  
Historical old TestFlight Build 8401: https://github.com/davidpovarsky/Maktabah/actions/runs/40179808443 — NOT the repaired candidate.  
Current required final release state: **NOT YET SIGNED OR UPLOADED**; 14 protected upstream path changes are pending trusted owner approval.

**Production corpus confirmed against the real Otzaria/SeforimLibrary latest-release API (2026-10-26):**
- Release `v32-20261010190601`.
- `seforim-schema6.db.zst`, compressed size **1,850,679,582 bytes**.
- Official SHA-256 **`6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44`**.
- Separate `seforim.db.buildstate.zst` is **not** the application production corpus. Resolve the latest release again before downloading and pin exact tag/asset/size/digest in evidence.
- On this Windows machine the former `C:\Users\DAVID\Downloads\seforim.db` was NOT present when checked. Do not assume a real full database is available locally.
- Runtime production DB is installed/reused in the application App Group via `ITorahSharedContainer` + `OtzariaProfileStorage`, and **must not be embedded in the IPA**.

**Existing positive facts:** `ios-testflight.yml` already handles Xcode 27 signed archive, Apple Distribution entitlements, IPA verification, ASC upload and Apple processing `VALID`; signing/ASC GitHub secret **names** exist. This does not prove values are valid. Bundle ID `com.davidpovarsky.chavrusatext`, display name `ChavrusaText`; keep the established bundle ID to support in-place update. Production build setting `OTZARIA_DEFAULT_DATA_PROFILE=production` already exists. Do not recreate signing infrastructure gratuitously.

## 1. Hard safety and ownership rules — do not touch unrelated work

Read first: `AGENTS.md`, `PROJECT_AGENT_GUIDANCE.md`, `docs/architecture/UPSTREAM_INTEGRITY_POLICY.md`, `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.{md,json}`, `docs/architecture/UPSTREAM_LEGACY_DEBT.md`, `docs/architecture/BUILD_8401_PROTECTED_HUNK_APPROVAL_PACKAGE.md`, `docs/architecture/BUILD_8401_REPRODUCIBLE_PAYLOAD_MANIFEST.json`, `docs/qa/BUILD_8401_FINAL_PRODUCTION_TESTFLIGHT_ACCEPTANCE.md`, `docs/qa/BUILD_8401_REGRESSION_TEST_MATRIX.md`, plus the three user's Maktabah–Otzaria rules documents, if available locally.

- Work **only** in the isolated candidate worktree or another specifically named isolated child worktree. Before editing: record branch, HEAD, remote HEAD, `git status --porcelain`, full upstream provenance and a rollback snapshot. Never reset/stash/clean another user's changes.
- Do **not** touch `C:\Users\DAVID\Code\Maktabah`, `C:\Users\DAVID\Code\Maktabah-v42-integration` (`sync/upstream-v42-full-integration`), `Maktabah-signing`, or `maktabah-torah-photo-study`.
- Do not merge/rebase into `main`, `dev`, or integration; do not update Asana; do not invoke subagents; do not replace the original Maktabah reader/UI with alternative UI.
- Classify every changed file as upstream-owned, downstream-owned, third-party/upstream, or shared seam. Favor downstream `Source/ChavrusaText`, `Source/Otzaria`, `Source/Sefaria`, `Source/LibraryBackend` adapters. An original upstream file or `Maktabah.xcodeproj/project.pbxproj` requires **exact file/hunk-specific owner permission**, including changes made earlier on the disposable validation branch.
- Do not expose Apple private keys, ASC tokens, SSH private keys, signing identities or user data in reports or CI. GitHub Actions secret/variable name enumeration is fine; avoid printing their values.
- Keep TestFlight **internal-only**; no external tester invitations, App Store publication or default `main` merge. Preserve existing App Groups, CloudKit container, entitlements and CFBundleIdentifier.

## 2. Confirm the two real blockers and eliminate misleading green signals

Inspect actual current code before assuming the last report is fully accurate:

1. `Maktabah-iOSUITests/ProductionOtzariaAcceptanceTests.swift::testProductionProfileLaunchResolution` launches production but only requires that a Library tab exists. **It does not confirm real DB installation, book content, search, TOC or full dataset.**
2. `::testProductionDatabaseAssetManifestIntegrity` merely compares **hard-coded constants to themselves**. Replace these self-equality checks with actual independent release metadata, downloaded-file integrity and SQLite/library runtime checks.
3. `Maktabah-iOSUITests/BackendTransitionAcceptanceTests.swift::testBackendSwitchViaSettingsPickerUI` uses `XCTSkip` when the Otzaria prerequisite is absent. The skip is legitimate reporting but **not acceptance**. The eventual production suite must provision a real corpus, actually select Otzaria, verify committed backend identity, switch back to Sefaria, and verify persistence.
4. `Maktabah-iOSUITests/MaktabahUITestBase.swift` has Tier S `.smoke`, Tier R `.realUI`, Tier P `.production`. `launchWithScenario(...)` always runs Tier S with mini+smoke bypass. Tier R still supplies miniTest10, although no smoke bypass. Only Tier P is production. Be explicit about evidence per tier.
5. `Scripts/CI/verify-upstream-boundary.py::load_exception_register(base_ref, ...)` reads the register from **the trusted baseline Git object**, not the updated candidate HEAD. Baseline `031df357...` has **8 unapproved Batch B entries**; candidate register has **14 unapproved Build 8401 entries**. **Changing/attesting only the candidate JSON will not make the current guard recognize those 14 entries**.
6. `.github/workflows/maktabah-batch-b-validation.yml` step `Verify Upstream Boundary Guard` ends in **`|| true`**, so the job can be green with a failed security check. `.github/workflows/ios-testflight.yml` has a fail-closed guard before signing but its checkout currently lacks `fetch-depth: 0` and its guard does not explicitly receive the pinned owner verification public key. Check the latest branch again before applying edits.
7. Confirm whether the existing 14 `.patch` files exactly match 14 modified upstream-owned paths and exact `git diff` hunks; check the original eight Batch B pending exceptions for overlap/legacy provenance. They must not be silently renamed approved.

Write a brief, machine-readable baseline evidence file BEFORE modification, preserving code SHA, CI run/test totals, current guard FAIL, skip reason and real official production asset identity.

## 3. Repair the Ed25519 owner-approval architecture, without any self-approval

**Affected existing paths:**
- `Scripts/CI/verify-upstream-boundary.py` (`load_exception_register`, `verify_boundaries`, attestation canonicalization, CLI).
- `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json`, `.md`.
- `docs/architecture/BUILD_8401_PROTECTED_HUNK_APPROVAL_PACKAGE.md` and `build-8401-patches/*.patch`.
- `docs/architecture/BUILD_8401_REPRODUCIBLE_PAYLOAD_MANIFEST.json`.
- `.github/workflows/maktabah-batch-b-validation.yml` and `.github/workflows/ios-testflight.yml`.
- Add narrowly scoped **downstream** verifier/signing-helper tests/tools if needed; do not move the actual trust authority into a candidate-controlled file.

### 3A. Signed approval source of truth

Build an approval retrieval mechanism that can recognize *the latest genuinely owner-approved 14 hunks* without relying on an obsolete unapproved eight-entry baseline register and without trusting an unsigned JSON replacement from the candidate branch.

Recommended implementation: **use signed approval attestations, cryptographically verified against a separately pinned owner Ed25519 public key**. Store the signed register/approval artifact in a protected owner-controlled ref/release/artifact, identified by immutable commit or digest, OR accept an untrusted candidate copy only after a verifier loaded from an owner-trusted immutable code ref checks **every signature and every binding**. Do not simply change `load_exception_register` to trust `HEAD` as authoritative. Do not use `--allow-unsafe-register` in CI. Do not accept self-asserted `APPROVED` fields as evidence.

If using a protected ref, fetch it explicitly, verify the expected SHA/identity and return a hard error for missing/unreachable/modified trust material. If using signed-candidate JSON with independent trust anchor, ensure the **verification implementation and CI gate itself cannot be replaced by an unreviewed candidate diff** (owner-protected workflow/reusable action/pinned verifier; document exactly how it is pinned). A release is blocked if the trust root has not been securely provisioned.

### 3B. Cryptographic verification must bind EXACTLY

For **every** protected changed path, require:
- repository identity (`davidpovarsky/Maktabah`), normalized relative path, exact baseline SHA;
- exact `git rev-parse <candidate>:<path>` head **Git blob SHA**, and verified canonical diff digest from **`git diff <base> <head> -- <path>`**;
- separate checksum for the packaged `.patch` file, with proof that the patch matches the exact diff (do not confuse `.patch` file SHA with Git diff SHA);
- owner approval reference/ID, signer public key ID, signature, expiration/revocation status and safe report provenance;
- expected canonical JSON/byte order identical in signer and verifier. Use existing `construct_canonical_attestation_payload` semantics only after independent review, and reject omitted `expected_head_blob_sha`, missing digest, missing expiry if policy requires one, mismatched baselines or extraneous unapproved protected paths;
- an Ed25519 signature authenticated by the **independently provisioned owner public key**, NEVER a newly generated agent-controlled key, repo-committed untrusted key or a public key supplied only by the candidate.

Recompute all current 14 patches, including:
- `13-iosmainview-settings-and-search-navigation.patch` -> `Source/UI/iOS/Views/iOSMainView.swift`.
- `14-tocnoderow-accessibility-selection.patch` -> `Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift`.

Also reconcile patches 01–12 with any code introduced after initial manifest and the trusted Batch B exception register; remove false/stale entries only if review confirms they are absent, without silently erasing legitimate audit history.

### 3C. Owner interaction — ONE concise checkpoint if required

**The user's present instruction explicitly authorizes the internal TestFlight release after legitimate engineering/security gates pass. It is NOT an Ed25519 signature or automatically an exact-hunk approval.**

Check for an existing **owner-provisioned** Ed25519 signer and pinned public verification key (inspect existence/configuration only; don't read private key bytes). If absent, prepare a single owner-ready approval package with all 14 exact hunk diffs, SHA-256 hashes, candidate SHA, reason/impact, rollback and a safe, reproducible **owner-side signing workflow**. Ask the owner once to review/approve the exact hunks and execute the signer using a private key under their sole control. A helper may generate *unsigned* payloads; it may not create/use an owner private key and sign as the owner. Never repurpose the Apple Distribution certificate or arbitrary SSH key without explicit owner-controlled setup.

Use a public GitHub Actions **repository variable or secret** such as `MAKTABAH_OWNER_VERIFICATION_KEY` as an independently owner-controlled trust anchor; pass it explicitly to the validation and release gates (`vars...` or `secrets...` as actually provisioned). Presence is not proof of authorization: the signatures must verify. Do not print key values/secrets. If the owner has not provided trustworthy approval and cannot interact, **STOP at this checkpoint; do not defeat the guard or label it approved.** After genuine approval is in place, proceed all the way to TestFlight automatically with no second generic release-permission question.

### 3D. Security negative tests (must FAIL the guard)

Implement and run tests that each flip exactly one condition: unsigned `APPROVED`; wrong key; self-generated key; modified protected blob; modified diff; modified packaged patch; missing protected path; newly added 15th path; expired/revoked approval; swapped path/signature; different base; changed HEAD after signing; truncated Git history; candidate-controlled edited verifier/workflow; untrusted `--exception-register` / `--allow-unsafe-register` in CI. Positive test must accept ONLY a genuine owner-signed exact-hunk fixture anchored to a pre-trusted public key. Keep the test fixture signing identity explicitly NON-PRODUCTION and unusable by the release workflow.

## 4. Make CI integrity reporting honest and mandatory for release

### 4A. Validation workflow — no disguised PASS

In `.github/workflows/maktabah-batch-b-validation.yml`, remove `|| true` from any step **called a required integrity gate**. Before owner approval, validation may still compile and exercise tests: isolate the guard in an explicitly named `Protected hunk approval DIAGNOSTIC (pending owner signature)` non-release job, capture its nonzero exit code and machine-readable report, mark result **BLOCKED/NOT_APPROVED** in summary (no 'all gates green' claim). Do **not** relabel diagnostic failure as a trusted PASS. A separate required **release-integrity** job must run the trusted verifier without suppressing its exit code and fail closed.

Ensure `fetch-depth: 0` or equivalent sufficient pinned history for every checkout that runs git-diff guards, including the exact pinned upstream commit. Use explicit `set -Eeuo pipefail` for required gates. Preserve existing Otzaria/Zayit XCFramework and SwiftPM caching; do not destabilize unrelated jobs. CI must upload guard JSON, build logs, `.xcresult` and test accounting, including skipped case names.

### 4B. Signed TestFlight workflow — trust and exact-SHA chain

In `.github/workflows/ios-testflight.yml`:
1. Make checkout use `fetch-depth: 0` and ensure required pinned refs available.
2. Before importing any Apple signing material, run the **trusted**, owner-key-pinned Ed25519 guard, fail closed (NO `|| true`, `continue-on-error`, default-to-approved or unsafe register). Bind final SHA, all 14 protected file blobs, canonical diff digests and owner approvals.
3. Require `data_profile=production`, never miniTest10 on this internal beta. Validate release HEAD is EXACTLY the SHA whose required CI jobs and production integration passed. Prefer adding a `workflow_dispatch` input `expected_sha` (and optional `validated_run_id`) then verify `github.sha` / `git rev-parse HEAD` and GitHub API job results. Never trust only a user-provided "CI passed" string, or a CI run from another SHA.
4. Require the **full production acceptance job** not to be skipped or substituted with hardcoded metadata self-comparisons. Require zero skipped required scenarios and independent release asset verification.
5. Keep existing signing, provisioning, Apple capabilities, IPA validation, upload, Apple processing and cleanup logic unchanged unless a proven defect requires a small fix. Do not expose Apple secrets in logs.
6. Reject runtime `miniTest10` launch-argument/environment overrides in release. Check effective `Info.plist` key `OtzariaDefaultDataProfile=production`, app bundle/name/version, CodeSign `Apple Distribution`, App Groups and iCloud/CloudKit entitlements, absence of huge seforim/lexical/index files in IPA. Keep signing ID and app ID identical to existing TestFlight app to preserve user data during upgrade.

Do not dispatch a release if the trusted guard is FAIL/NOT_CONFIGURED or the production gate is SKIPPED/BLOCKED. This user authorizes dispatch **as soon as all real gates PASS**.

## 5. PROVE full, regular Otzaria production data — not constants, not miniTest10

**Relevant sources:**
- `Maktabah-iOSUITests/ProductionOtzariaAcceptanceTests.swift` — currently only Library-tab existence + self-comparing hardcoded metadata; **replace** with meaningful acceptance.
- `Maktabah-iOSUITests/BackendTransitionAcceptanceTests.swift` — current genuine Picker test still skips when no Otzaria DB.
- `Maktabah-iOSUITests/MaktabahUITestBase.swift` — Tier S smoke/mini, Tier R normal-bootstrap/mini, Tier P production. Keep labels truthful.
- `Source/Otzaria/DataProfiles/OtzariaDataProfileRegistry.swift`: profile precedence is launch arg, environment, embedded default, production fallback.
- `Source/Otzaria/Bootstrap/OtzariaBootstrapAdapter.swift` `restoreForAppLaunch()` and `downloadAndInstallManagedDatabase(...)`.
- `Source/Otzaria/Bootstrap/OtzariaDatabaseBootstrapService.swift`, `OtzariaDatabaseInstaller.swift` (the `OtzariaDatabaseStorage` struct is **declared inside `OtzariaDatabaseInstaller.swift`**, not in a separate `OtzariaDatabaseStorage.swift`).
- `Source/Otzaria/Core/OtzariaDatabaseAccessController.swift::restoreIfNeeded()` and `Source/Otzaria/App/OtzariaAppContainer.swift::OtzariaMaktabahBridge` (`activateManagedDatabase`, `restoreDatabaseIfPossible`, `openIfNeeded`).
- `Source/Otzaria/Storage/ITorahSharedContainer.swift` (`sharedRootURL`, `downloadsRootURL`), `OtzariaProfileStorage`.
- `Source/UI/iOS/Managers/BootstrapManager.swift::prepareIfNeeded()`; Otzaria startup must actually run real restore instead of the `DEBUG -smokeBypassBootstrap` early path.
- `Source/Features/Setting/SettingsView.swift::librarySourceSection` (`settings-library-source-picker`, `settings-active-backend-id`, `settings-transition-state`).
- `Source/Sefaria/Reading`, `Source/Otzaria/Reading`, search engine indexes as relevant; do not conflate missing search index with missing library database.

### 5A. Prepare one real, verified production corpus for the Apple runner

Find and use an already verified full production DB if one exists in an authorized test cache/storage. Otherwise, in an isolated Xcode-27 job (not a user-data directory), obtain the **official latest** `seforim-schema6.db.zst` release asset, validate GitHub release asset identity, exact compressed byte length and SHA-256, then decompress safely and validate the actual **SQLite** database.

- Check free disk before download/extraction. `OtzariaDatabaseStorage` reserves 1 GiB and conservatively estimates unknown decompressed output at **6×** compressed size. Full corpus is large; plan sufficient capacity for compressed+staging+rollback, not a 10-book fixture.
- Verify the real SQLite DB is openable read-only: `PRAGMA quick_check`, targeted `PRAGMA integrity_check` if feasible, actual required tables/columns (`book`, `category`, `author`, `line`, relevant TOC/FTS), live schema version and nontrivial book/line counts. Compare with measured official data, not a hard-coded expected list that equals itself. Detect damaged ZIP/zstd, partial download and schema mismatch.
- Do NOT substitute `miniTest10`, `seforim.db.buildstate.zst`, a 10-book subset or dummy fixture while labeling the test FULL_PRODUCTION.
- Do NOT commit or embed the large DB into Git/IPA; avoid uploading sensitive app data. Cache only safe verified test artifacts by official digest if useful, under appropriate retention/storage limits. If full data cannot be provisioned, report **FULL_PRODUCTION_BLOCKED** and provide exact disk/download/source error; this is NOT a release-pass.

### 5B. Exercise the real runtime and real UI

Use an iPadOS 27 simulator with a real installed corpus in the app's **correct App Group and production profile path**, not the simulator's private Documents folder. Resolve the container using `ITorahSharedContainer` rather than guessing. The app must use `OtzariaDatabaseBootstrapAdapter.restoreForAppLaunch` and `OtzariaDatabaseAccessController.restoreIfNeeded` without `-smokeBypassBootstrap`. **Do not bypass validation by injecting a fake `OtzariaMaktabahBridge.isEnabled=true`.**

Required hard assertions in `ProductionOtzariaAcceptanceTests.swift` (split into separate cases with clear labels):
1. Effective runtime profile is **production**, with no mini override; data source identity and full schema/corpus readiness are real.
2. Normal bootstrap recognizes the existing verified full DB and enters Otzaria without asking to download it again. Validate no duplicate download, no reinstallation, no lost data, and no lingering spinner.
3. Library UI shows real Otzaria categories/books beyond a mini dataset; search for/open at least one known full-corpus book and confirm a real section with nonempty actual content and a concrete locator; navigate forward/back and confirm content/locator move and return.
4. TOC presents genuine nodes and live selection; verify real book identity and locator.
5. Full production search performs an actual query and displays real results if the separate search index is installed; if search index is legitimately missing, verify the UI explicitly reports its separate installation state **without misidentifying the book corpus as missing**. Do not mark search PASS unless a real query returns expected data.
6. Open an existing saved user note/annotation fixture, edit/add a new unique note, relaunch and verify persistence. Use synthetic test-user data only, never modify the owner's physical notes.
7. Exercise Sefaria -> Otzaria -> Sefaria through the actual Settings Picker; require both successful committed `settings-active-backend-id` changes and restored 3 open tabs, exact locators, highlights and notes. Verify preflight rollback on invalid/missing target corpus; no silently optional Picker action.
8. In-place upgrade: preferably install a simulator build of previous source Build 8401 with compatible bundle/App Group, populate test DB and note fixture, then install the new candidate **without uninstalling**, verifying same stored DB identity/metadata, saved data and no redownload. Never claim the signed App Store `.ipa` was installed in a simulator unless it actually was; a Debug simulator reproduction must be labeled as such. Final physical TestFlight upgrade remains owner's next-morning QA.
9. Simulate offline restart, cancel/resume interrupted download, corrupted/invalid DB, insufficient space and interrupted promotion/rollback using isolated safe test locations. Do not delete any real-user library, notes, or iCloud container to make a test pass.

If the XCUITest runner cannot introspect needed data, add **DEBUG-only read-only instrumentation** in a downstream service with a minimum separately approved upstream hook if unavoidable. The test must inspect real current storage/database/result, not an injected `PASS` flag. No sensitive user content in diagnostics. Use stable accessibility identifiers, explicit waits and fail-closed predicates. Skip is allowed for unrelated platform targets but never for a required production test in its designated production job.

### 5C. Fix the currently skipped Settings Picker test precisely

`Maktabah-iOSUITests/BackendTransitionAcceptanceTests.swift::testBackendSwitchViaSettingsPickerUI`:
- Prepare the actual Otzaria corpus before test, launch the **real** settings UI (not `-smokeBackend` boot override), identify and tap `settings-library-source-picker`, require the Otzaria menu option to exist and be tapped. No optional `if` falling through.
- Wait for `settings-transition-state` to become `idle` and `settings-active-backend-id` to change from `sefaria` to **`otzaria`**. Do not treat a missing Done button as an acceptable PASS/skip after provisioning.
- Return to reader, check real Otzaria content/locators, then reverse via Settings to **`sefaria`**, verify previous session/tabs persist; repeat with 3 tabs and note fixture.
- Assert the error/configuration flow accurately when DB is unavailable in a **separate negative-case test**; this may pass by correctly displaying setup, but cannot be counted as a successful backend switch.

## 6. Run real Xcode 27 CI and bind release to the exact tested SHA

Before CI: run `git diff --check`, Swift formatting/lint if project rules require, all 212+ portable assertions, boundary fixtures, cryptographic positive/negative verifier tests, guard integrity test and full test compile. Never hide errors or use `sleep` as a substitute for a proper state predicate.

Candidate workflow should run all required jobs on Xcode 27/macOS 27; keep existing SwiftPM, Otzaria and Zayit XCFramework reuse. Prefer a clearly named dedicated `production-database-acceptance` job for heavy official full-dataset coverage instead of making every mini smoke test download 1.85 GB. Record disk used and cache provenance. Require:
- Release `iphoneos` compile (no signing needed for this CI build) and real simulator Debug build.
- 212+ component assertions, all existing 21 successfully exercised UI tests plus corrected Settings Picker test and actual Tier P corpus cases.
- No `XCTSkip` of required scenarios, no `continue-on-error` / `|| true` for release-required gates, no missing xcresult.
- Genuine protected-boundary release-integrity **PASS** against signed owner approval.
- Test reports with exact counts PASS/FAIL/SKIP/BLOCKED, expected vs actual, `xcresult` download/artifact, production profile, real DB path/type/size/schema/asset digest, no-redownload evidence, CI HEAD SHA.
- Run at least one representative clean full-corpus startup + real backend-switch integration check twice to detect a flaky pass.

Commit all necessary app/test/workflow changes **only to candidate** (with review and required protected-file approvals), push branch, resolve exact `git ls-remote` SHA, dispatch/check GitHub Actions, inspect actual required job steps and artifacts, fix failures at root cause then create NEW SHA and rerun. **Approval JSON, trust model or release workflow changes after testing require another final full CI run.** No old green run or documentation-only SHA substituted for final release provenance.

## 7. Immediately build/sign/upload production TestFlight once ALL gates truly pass

This user message **authorizes the candidate internal TestFlight upload in this execution**, with zero need for a further generic release confirmation after valid exact-hunk approval. Run the existing `.github/workflows/ios-testflight.yml` on the **same exact approved and tested SHA**; do not run on `main` or `miniTest10`.

Pre-dispatch checklist (script this as a machine-verifiable fail-closed checklist):
1. Isolated worktree clean, remote branch HEAD equals final candidate SHA; immutable expected SHA pinned.
2. Upstream protected change inventory exactly equals 14 (or accurately updated) approved, cryptographically signed blobs and diffs; trusted verifier/owner public key pins authentic; **guard PASS**.
3. All required Xcode 27 compile, unit, UI and **full production DB** tests successful on the exact SHA, zero required skipped scenarios. No unresolved broken-feature blocker; user-device validation can remain pending until tomorrow.
4. GitHub Actions distribution secrets/ASC capabilities available without exposing their values; bundle ID unchanged, production profile selected.

After adding `expected_sha` input to the workflow, use a command equivalent to:

```bash
CANDIDATE_BRANCH=validation/maktabah-build-8401-repair-production-20261025
EXPECTED_SHA=$(git rev-parse HEAD)
test "$(git ls-remote origin "refs/heads/$CANDIDATE_BRANCH" | cut -f1)" = "$EXPECTED_SHA"
gh workflow run ios-testflight.yml \
  --repo davidpovarsky/Maktabah \
  --ref "$CANDIDATE_BRANCH" \
  -f data_profile=production \
  -f upload_to_testflight=true \
  -f expected_sha="$EXPECTED_SHA"
```

(If `expected_sha` is not added, use only documented supported inputs, but still enforce immutable source SHA inside release workflow.) Identify **the newly created run ID**, watch its actual result to completion, and verify `headSha=EXPECTED_SHA`. The signed workflow must:
- Perform the trusted boundary check and CI-SHA gate BEFORE signing/importing certificates.
- Archive/export using existing Apple Distribution signing workflow; validate codesign, provisioning profile, Team ID, App Group, CloudKit, push entitlements and IPA checksum.
- Check exact Info.plist: `OtzariaDefaultDataProfile=production`, `CFBundleIdentifier=com.davidpovarsky.chavrusatext`, display name `ChavrusaText`, unique current CFBundleVersion/version, no `miniTest10` runtime overrides, no bundled production SQLite/index or search corpus.
- Validate/upload using current App Store Connect API key tooling; run the existing `Scripts/CI/wait-for-testflight-build.py` until **the newly uploaded build** reports Apple `processingState=VALID` (not merely successful `altool` transfer).
- Confirm the resulting build is available in **the existing INTERNAL TestFlight group** used by the owner (assign it through ASC if needed and permitted; no external testers/publication). Record exact app/build ID, bundle/version/build, artifact checksum, ASC processing status and tester group linkage. Never confuse an older valid Build 8401 with the new beta.

If Apple rejects processing, signing fails, a required gate is blocked, or owner signature cannot be authenticated, stop with **exact evidence and the one necessary owner action**. Do not claim successful upload and do not force-dispatch via an unsafe workflow. Do not schedule background execution and do not promise a clock time.

## 8. Final deliverables — actionable for owner's next-morning iPad QA

Update `docs/qa/BUILD_8401_FINAL_PRODUCTION_TESTFLIGHT_ACCEPTANCE.md` and the regression matrix, with:

- Current candidate branch + baseline/upstream SHA, exact FINAL CI-tested HEAD and remote matching SHA, full release commit, CI run URL and release run URL.
- All 14 (or corrected count) protected paths, exact signed approval refs, owner key trust anchor, current guard verdict, negative test results, remaining Batch B legacy debt and zero unapproved changed paths.
- Production release tag, downloaded official filename/compressed byte count/digest, decompressed DB SQLite integrity/schema/record counts, actual app App Group production storage/reuse, runtime backend state, no-redownload test and search index status.
- Real UI test names with counts and tiers; one previously skipped backend test must be demonstrably executed and pass with real Otzaria. Record screenshots/xcresult and expected/actual for highlight, clear X, paging, TOC, Rashi/Genesis, language and annotations.
- Release IPA SHA256, signed entitlements/profile, exact `production` Info.plist, App Store Connect app/build/version, `VALID` confirmation, internal tester group readiness. Physical iPad-only checks must be tagged **`OWNER_IPAD_QA_PENDING`**, never PASS.
- Zero merge to main/integration; zero changes to owner worktrees; zero Asana mutation.

Then provide a concise **Hebrew** completion report, including the **new beta's actual build number and TestFlight availability** (only if verified), with a tiny owner test plan for 27 October:
1. In TestFlight select the new build and tap **Update** over the existing app — **do not delete the app**, which risks DB/notes loss.
2. Check installed full Otzaria database is detected without unnecessary redownload; open an Otzaria book not in miniTest10; verify search, next/previous, TOC, Rashi deep link, and highlighting/X.
3. Switch Sefaria <-> Otzaria from Settings; check tabs, exact reading positions, notes/annotations, offline relaunch and Hebrew TOC.
4. If a defect occurs, record screen, steps, exact book/ref, expected/actual, build number, approximate time and any available TestFlight/device logs.

### Completion states — use exactly one truthful final status

- `INTERNAL_TESTFLIGHT_PRODUCTION_VALID` — genuine trusted approval + real full-data acceptance + final CI + signed IPA + Apple VALID + available internal testers. Owner hardware QA pending.
- `BLOCKED_OWNER_SIGNATURE` — valid exact-hunk signature/key or owner setup absent; candidate fully prepared, release NOT uploaded.
- `BLOCKED_FULL_PRODUCTION` — actual regular Otzaria DB could not be exercised, regardless of green mini/metadata tests; release NOT uploaded.
- `BLOCKED_CI_OR_CODE` — actual required tests or build failed; release NOT uploaded.
- `BLOCKED_APPLE_DISTRIBUTION` — CI/security passed but signing, ASC upload/processing or internal availability did not complete.

**Do not stop after creating another nice dossier or another green mini CI run. The authorized end state is a NEW, signed `production` TestFlight beta for the owner's iPad, reached only through authentic approval and genuine required tests.**