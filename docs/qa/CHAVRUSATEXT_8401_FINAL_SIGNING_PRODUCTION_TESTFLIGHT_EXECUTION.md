# ChavrusaText Build 8401 — FINAL BLOCKER REPAIR, OWNER ATTESTATION & PRODUCTION TESTFLIGHT

**Execution prompt for ONE coding agent | 26 October 2026 | Owner's target: internal TestFlight beta for iPad validation on 27 October**

## EXECUTION CONTRACT — READ FIRST

Execute the work, not merely a plan. Investigate the existing implementation, make the precise fixes, commit and push the candidate, run genuine Xcode 27 CI, prepare a safe **single owner-signing handoff**, then, once an authentic owner-controlled attestation is supplied and all mandatory gates are green, **automatically build, sign, upload and confirm the new INTERNAL production TestFlight build without requesting a second generic release authorization**.

**Do not self-approve** upstream changes, invent/use a self-generated 'owner' key, lower security checks, force a skipped mandatory UI test to green, merge branches, publish to App Store, add external testers, delete iPad/user data, or touch unrelated worktrees. There is **one main agent only**, no subagents. Asana is read-only; do not update it without a separate explicit owner request.

**If the genuine owner signature/trust anchor is not available**, finish all independent fixes and checks, place the signing instructions and full review dossier where the owner can access them, and STOP **only** at `BLOCKED_OWNER_SIGNATURE` (or another real failing gate). Never falsely claim Apple upload. Continue directly to TestFlight after authentic authorization is supplied and revalidated.

## 0. Exact inspected starting point — recheck before touching anything

- Repo: `davidpovarsky/Maktabah`.
- Candidate worktree ONLY: `C:\Users\DAVID\Code\Maktabah-build-8401-candidate`.
- Candidate branch: `validation/maktabah-build-8401-repair-production-20261025`.
- Inspected local and remote HEAD: `a947504d6f791581ddce97c2a70d48369877a6d8` (documentation-only successor to tested code).
- Last CI-tested code: `efd82ca2621db4848c9ee45fe07a3cf1f84913e6`.
- Baseline: `031df35710ab2c6015efb1acd1e65154dbcd3f24`.
- Pinned upstream: `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`.
- Last Xcode 27 CI: https://github.com/davidpovarsky/Maktabah/actions/runs/40260027756 — **eight jobs SUCCESS**; 212/212 component assertions; normal simulator suite 21 passed / 3 skipped; separate production UI job **7 executed / 4 passed / 3 skipped**, zero failures. SUCCESS on a job with skipped mandatory tests is **not production UI acceptance**.
- Existing production asset `Otzaria/SeforimLibrary` tag `v32-20261010190601`; `seforim-schema6.db.zst`; compressed bytes `1850679582`; published SHA256 `6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44`; extracted SQLite ~`3821240320` bytes, 7,876 books, 1,423 categories, `PRAGMA quick_check=ok` from runner verification. Recheck official current release before any download; record the exact pinned source actually tested.
- Current production upload history: last observed `ios-testflight.yml` run `40179808443` uploaded **old Build 8401**, from baseline; **NO new repair TestFlight** yet.
- Existing signing-related GitHub secret names are configured for Apple credentials. No `MAKTABAH_OWNER_VERIFICATION_KEY` variable/secret was found at inspection. **Do not display credentials or print any private key**.
- `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json`: 14 candidate exceptions, **0 approved**. Original baseline register: 8 older exceptions, **0 approved**. Reconcile overlapping older entries explicitly; don't assume that 14 replaces every older approval requirement without proof.
- Critical, **independently reproduced**: `python Scripts/CI/verify-upstream-boundary.py --base 031df35710ab2c6015efb1acd1e65154dbcd3f24 --head HEAD --upstream-ref a0ed0df908a6cb38bc459d4baaeb400f447b2fc4` returns `FAIL`, **15 violations**: 14 `PENDING_UPSTREAM_APPROVAL` plus `UNAUTHORIZED_POLICY_BYPASS_ATTEMPT`. The 15th occurs because `Scripts/CI/verify-upstream-boundary.py` was modified in the same base-to-HEAD change set as protected application source; in the verifier, `POLICY_FILES = POLICY_ENFORCEMENT_FILES` and the coupled-change condition fails regardless of whether the 14 hunks have been signed. **Do not overlook the 15th violation.**
- Existing `tools/sign_owner_approvals.py` writes the signed register to the working tree and then incorrectly checks `head_ref="HEAD"`, which reads the **old committed register**. Also, `--private-key` currently accepts raw hex/base64 in the command line. Repair this before asking the owner to run anything.

### Immutable worktree safety

Never modify `C:\Users\DAVID\Code\Maktabah`, `C:\Users\DAVID\Code\Maktabah-v42-integration`, `Maktabah-signing`, or `maktabah-torah-photo-study`. Preserve branches and dirty states exactly. Work only in the isolated candidate (or a newly isolated disposable CI/security-tooling worktree). Capture `git status --porcelain`, HEAD, remote HEAD, and worktree inventory before and after. Never reset/clean/stash an owner's tree; stage exact file paths, not `git add -A`.

## 1. Mandatory diagnosis: explain the three real production skips

**Read the complete native log and `.xcresult`** of the `Real Otzaria Production Corpus (1.85 GB) Acceptance` job in run `40260027756` before writing fixes. The official 3.82 GB SQLite exists in the macOS runner but not demonstrably in the **app's active sandbox**. The job's three skipped tests are:

1. `ProductionOtzariaAcceptanceTests.testProductionCorpusSQLiteIntegrityIfInstalled` — `BLOCKED_FULL_PRODUCTION: Production database not provisioned in this test runner`.
2. `ProductionOtzariaAcceptanceTests.testProductionProfileLaunchResolution` — `BLOCKED_FULL_PRODUCTION: Library categories not loaded (production corpus unprovisioned in this runner)`.
3. `BackendTransitionAcceptanceTests.testBackendSwitchViaSettingsPickerUI` — `BLOCKED: Otzaria database prerequisite is not configured on simulator; configuration prompt presented`.

The negative-path `testBackendSwitchWhenCorpusUnavailablePresentsConfigurationPrompt` passing does **not** prove a successful Otzaria activation when data is available.

**Inspect / modify as indicated by actual root cause:**

- `.github/workflows/maktabah-batch-b-validation.yml`, job `production-database-acceptance`, especially `Build Maktabah-iOS with Production Profile for Simulator Testing` and `Provision Production Database and Run Production Acceptance Tests`.
- `Source/Otzaria/Storage/ITorahSharedContainer.swift`: `appGroupIdentifier = group.com.davidpovarsky.itorah`; `resolveSharedRootURL`; diagnostic/test-only override.
- `Source/Otzaria/DataProfiles/OtzariaArtifactStorage.swift`: `OtzariaProfileStorage.applicationSupportRoot`, production database root = **`<resolved-shared-root>/Otzaria`**.
- `Source/Otzaria/Bootstrap/OtzariaDatabaseInstaller.swift`: `OtzariaDatabaseStorage.finalDatabaseURL = <resolved-shared-root>/Otzaria/seforim.db`; preflight, promotion, manifests, recovery.
- `Source/Otzaria/Bootstrap/OtzariaBootstrapAdapter.swift`: `restoreForAppLaunch` and `downloadAndInstallManagedDatabase`.
- `Source/Otzaria/Core/OtzariaDatabaseAccessController.swift`: managed restore, validation, external bookmarks.
- `Source/Otzaria/App/OtzariaAppContainer.swift`: `OtzariaMaktabahBridge.restoreDatabaseIfPossible`, `openIfNeeded`, book loading.
- `Source/Otzaria/DataProfiles/OtzariaDataProfileRegistry.swift`: profile priority arguments/environment/embedded plist; production must not resolve `miniTest10`.
- `Maktabah-iOSUITests/MaktabahUITestBase.swift`: `.production` launch environment and arguments.
- `Maktabah-iOSUITests/ProductionOtzariaAcceptanceTests.swift`, `BackendTransitionAcceptanceTests.swift`.
- Entitlements and App Group membership in `Maktabah.xcodeproj/project.pbxproj`, simulator app code-signing / ad hoc credentials, app ID `com.davidpovarsky.chavrusatext`.

### 1A. Correct database provisioning into the APP'S actual root

The current job copies the extracted DB to **multiple guessed folders**: `build/shared-root/Otzaria/seforim.db`, app data Application Support, and optional group paths, while setting `OTZARIA_SHARED_ROOT_OVERRIDE` and `OTZARIA_PRODUCTION_DB_PATH` to **macOS runner absolute paths**. These environment values in the test-runner process do **not prove** that a sandboxed simulated app can use those paths. Mixing three locations also masks incorrect entitlement/storage resolution.

Do the following instead:

1. Determine the app's **actual** resolved root at runtime, with a narrowly scoped `#if DEBUG`/test-only app diagnostic (profile, backend, storage-source enum, booleans for readable and opened, schema result, catalog counts; disclose NO arbitrary user paths in release). If a tiny UI bridge is required, keep it in downstream code and introduce a clearly identified minimal upstream hook only if unavoidable (updates protected-hunk approval inventory).
2. Boot the iPadOS 27 simulator, install the simulator `.app`, and resolve its **canonical iTorah App Group container** using verified `xcrun simctl get_app_container` syntax or a known native API. Assert that the group exists, is writable, and matches the app's `ITorahSharedContainer.resolveSharedRootURL()`; never treat an empty group path as successful. If group access is missing in Debug simulator, **fix the actual entitlement/signing configuration** or use a clearly isolated genuine app-compatible managed installer. Do NOT silently fall back to a host path or install into three different roots.
3. Copy the verified decompressed `seforim.db` into the one correct `<shared-root>/Otzaria/seforim.db` location (or install with the real atomic managed installer). Handle SQLite readers, directory permissions, available storage, and any required manifest/recovery validation. Re-verify target file size/schema and SHA/identity where appropriate. No symlink to a runner-only location, no fake metadata, no mini corpus. Confirm the **app process** opens the same database, not only that the host can query it.
4. Stop using `|| true`, empty-path fallbacks and `XCTSkip` to mask **positive-path provisioning failure**. Do not rely on `SIMCTL_CHILD_` variables when launched by `xcodebuild test-without-building` unless an actual test demonstrates they reach the target process. Prefer real App Group access. Ensure no test-only override is compiled/active for Release/TestFlight.
5. If restore fails because `OtzariaDatabaseAccessController` expects managed selection/schema/manifest, reproduce on clean simulator and fix actual restore semantics while preserving valid existing user databases. Do not merely set `isEnabled = true` or stage fake book records.
6. Perform positive path under `OTZARIA_DEFAULT_DATA_PROFILE=production`, with no `miniTest10` arguments and **no `-smokeBypassBootstrap`**. Interact with the actual library and actual settings Picker. The simulator must show valid real categories, open a **specific genuine book absent from miniTest10**, render nonempty text in the reader, navigate next/previous with expected locator changes, then switch Sefaria → Otzaria → Sefaria through Settings, preserving tab/session information.
7. In isolated fresh simulator/test configuration **without** production DB, retain a separate **negative-path** test asserting real setup/download prompt and no silent fallback. Do not run both positive and negative tests on a shared mutable installed corpus with ambiguous state.

### 1B. Replace misleading production assertions with real assertions

- `testProductionCorpusSQLiteIntegrityIfInstalled`: remove `IfInstalled`/positive-path `XCTSkip`; prove the **target app's active DB** is the fully validated schema6 SQLite. Checking `fileSize > 1.5 GB` in the UITest runner, or checking a host absolute path via environment variables, is not sufficient. Expose read-only app-side diagnostics and assert canonical profile, open handle, real category/book counts, and actual rendering; use independent host `sqlite3` and checksum proof as a second layer.
- `testProductionProfileLaunchResolution`: must assert true native production startup, active Otzaria backend, nonempty real catalog and reader, not merely a Library tab or alert-free launch. Any missing prerequisite in positive Tier P is a test **FAIL**, with captured screenshot/hierarchy/diagnostic.
- `testBackendSwitchViaSettingsPickerUI`: must tap the Picker/menu option, wait for real backend identity to change, validate existing book tabs and selected locations after roundtrip; on the already provisioned Tier P positive suite, no `XCTSkip` is allowed. Retain missing DB as separately named negative suite.
- `testProductionDatabaseAssetManifestIntegrity`: do not allow URLSession/network failure to turn comparisons of hardcoded values against themselves into PASS; rely on CI's validated remote asset digest and a test-visible receipt/fingerprint, with explicit evidence of the bytes and schema that the app actually opened.
- Assert the exact Tier P positive test list appears in `.xcresult`, every required test **ran and passed** (zero `skipped`, `notRun`, `disabled`, or success via catch/early-return). Enforce a **machine-readable fail-closed xcresult postprocessor** in CI that independently rejects any missing/skip, not merely trusting `xcodebuild` exit 0. Emit explicit `REAL_PRODUCTION_APP_OPENED_DATABASE=PASS` and source/locator evidence.
- Supply full production database **inside simulator acceptance only**, never bundle the giant SQLite into the signed IPA.

## 2. Fix owner signing script so the signing handoff actually works

**File:** `tools/sign_owner_approvals.py`; supporting read-only truth source `docs/architecture/BUILD_8401_REPRODUCIBLE_PAYLOAD_MANIFEST.json`, `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json`, `Scripts/CI/verify-upstream-boundary.py`.

Current defect: `--sign` writes register on disk but immediately calls `verify_boundaries(head_ref="HEAD")`, which reads the old Git commit's register and will fail. Fix the transaction:

1. Support **private-key file path only** (e.g. `--private-key-file`) with protected owner-controlled filesystem permissions, no raw hex/base64 key accepted as a command-line argument. The private key must not be created, read, copied, stored or pushed by the agent, must never be passed in chat or GitHub Secrets, and must not appear in command history/logs. If owner already has a securely retained identity, use that identity; **never invent a new key and call it owner-approved**.
2. `--generate-payloads` must produce deterministic canonical JSON and full 14-item review dossier; do not silently use a new timestamp on preview vs signing. Provide an owner-visible immutable digest/fingerprint and an explicitly chosen expiration for owner review. Do not leak private material.
3. Before signing, assert **exactly 14 unique patch IDs/paths** and one-to-one parity among manifest, actual baseline-to-current protected blobs/diff bytes, 14 patch files and register. Reject stale manifest, duplicate/missing approvals, changed protected blob, unexpected 15th protected path, malformed patch file or signer-key mismatch.
4. Sign each canonical payload using the **owner's genuine private key only after review**, and write attestations atomically: write temp file in secure location, validate, replace register only on success; on failure preserve original and explain why. Guarantee 14/14 signed, nothing null, no silent partial successes.
5. For **pre-commit** validation use `head_ref="WORKTREE"` so the verifier reads the newly written working-copy register, subject to its full safe state/diff checks; or verify a hermetic temporary staged Git commit in a disposable checkout against the genuine **same** trusted verifier and real public key. Do **not** weaken the verifier or use unsafe register override to claim production success.
6. Commit only the signed register (and separately committed/well-tested signer fixes), then **post-commit** re-run `verify_boundaries(base_ref=031df..., head_ref=<exact_new_HEAD>, upstream_ref=a0ed..., owner_public_key=<owner-controlled pinned key>)` on a clean worktree. Capture JSON and require exact `PASS`, 14 valid attestations, no policy bypass, unexpected protected paths, or missing independent trust.
7. Don't conflate signing success with secure trust **configuration**. The genuine owner controls the verification public key anchored in protected GitHub org/repo configuration. Compare fingerprint with the actual owner's public key; the agent must not overwrite an existing owner key or install a self-generated key. A new trust anchor requires an explicit owner action/independent trusted confirmation.
8. Add unit/integration tests proving the original broken HEAD-before-commit scenario fails; worktree preview and committed verification succeed only with authentic registered signatures; wrong key, expired, wrong path, changed byte/diff, 13/14 signed, policy-bypass mutation and stale signed commit all fail. Use only test fixture keys; **never** treat fixture tests as owner signatures.

## 3. Fix the 15th security violation — WITHOUT weakening upstream integrity

The current verifier reports **14 unapproved protected changes + 1 `UNAUTHORIZED_POLICY_BYPASS_ATTEMPT`** because `Scripts/CI/verify-upstream-boundary.py` was itself modified in candidate alongside protected source. Merely adding the 14 Ed25519 signatures will **still fail**.

The agent MUST:

1. Inspect actual baseline-to-candidate diff of `Scripts/CI/verify-upstream-boundary.py`; build a separate exact-file review dossier (before/after hash, actual additions/deletions, rationale, negative fixtures). Preserve the explicit invariant: a candidate cannot alter its own authorization gate to authorize the same protected application changes.
2. Establish the verifier's trust **independently of candidate-controlled code**. Preferred architecture: owner-reviewed, immutable security-tooling ref/artifact (pin commit and SHA256 **from an owner-controlled location**), invoked by production release CI and independent of candidate's editable verification script; restore candidate's verifier file to the reviewed baseline if required to remove coupled-change violation. Another safe, explicitly owner-approved architecture is acceptable if independently pinned and at least as strict. **Do not** simply remove `POLICY_FILES`, delete the coupled-change condition, add `|| true`, or exempt the candidate's verifier without independent owner-authenticated authorization.
3. Verify negative cases with actual trusted release validator: altered verifier, altered workflow, candidate-supplied public key, fake signer, changed registration, forged approval status, missing 1 of 14, signed different blob, mismatching selected release SHA. Ensure GitHub Actions cannot pass a candidate-supplied arbitrary trust anchor. If branch/workflow protection or a protected GitHub Environment with required owner approval is necessary to anchor the validator, set up/seek explicit owner confirmation rather than assuming it exists.
4. Separate diagnostic from release gating. The candidate CI may report `OWNER_APPROVAL_REQUIRED` honestly, but the **release job must fail CLOSED** before Apple certificates are imported unless an independently trusted guard says PASS. Do not mark a candidate change to the guard as inherently trusted merely because its internal fixture suite says 16/16.
5. Record all protected application hunks precisely. `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift` may be fork-owned by history but falls inside protected namespace according to policy; follow actual verifier output rather than hand-waving away count. If fixes change any protected blob/digest after owner signs, invalidate old signature and obtain a new one.
6. Generate owner-ready instructions for the **single genuine trust-anchor setup and 14-hunk signature**; do not force the owner to manually patch source code. If owner trust approval cannot be authenticated under the existing policy, **STOP** at that exact checkpoint. Don't bypass to meet a deadline.

## 4. Re-run native CI, production UI and confirm no required SKIP

After any source/test/policy change:

- Run `tools/test_chavrusa_text_components.swift` (currently 212 assertions/21 suites; preserve and extend as needed).
- Run `tools/test_upstream_boundary_security.py` against both candidate diagnostics and the independently trusted release verifier (current 16 security fixtures). Add regressions for the signing transaction and coupled policy change.
- Run `.github/workflows/maktabah-batch-b-validation.yml` on a new immutable candidate SHA, record run ID and actual checked-out SHA, Xcode 27 environment, Debug simulator tests, Release iphoneos compile, all artifacts/xcresult.
- Run Production job with actual **1.85 GB official compressed / 3.82 GB extracted** SQLite, full `quick_check`, known real catalog, real app handle, real book/locator. Mandatory positive Tier P **no skips**; distinguish intentional negative tests on separate clean installation.
- Do NOT call the CI green as `ALL_REQUIRED_ACCEPTANCE_PASSED` if the production job shows `7 executed, 3 skipped`, or if an assertion is conditional/optional. Mark blockers honestly. Fix real environment/app integration rather than suppressing tests.
- Test real app without `-smokeBypassBootstrap`, without `miniTest10`, without host-only file override, with actual Settings picker transition. Test one install and one same-bundle-ID update preserving existing full DB/bookmarks/notes where safe; if full signed 8401 upgrade cannot be simulated, record `OWNER_IPAD_UPGRADE_QA_PENDING`, not fake PASS. Physical iPad QA is AFTER internal beta delivery.
- Preserve .xcresult/logs/simulator screenshots. Exact test-name/expected-count contract must match actual test inventory; enforce with generated post-run JSON, machine check required 0 skips for positive Tier P.

## 5. Owner handoff — minimum friction, real authority

After all non-owner work and production acceptance pass, produce `docs/qa/BUILD_8401_OWNER_SIGNING_HANDOFF.md` containing:

- Exact candidate commit SHA and unchanged protected-source tree/blob hashes.
- Full 14-file reviewed patch table (path, exact hunk, why needed, diff SHA, blob SHA, rollback, remaining risk), plus independently reviewed verifier/security-tooling hash/reference and protection mechanism.
- Current public-key anchor status: `OWNER_KEY_ALREADY_TRUSTED` or `OWNER_ACTION_REQUIRED`; never claim a key is owner-controlled merely because an agent wrote a GitHub variable. Avoid showing secret values; public key fingerprint is okay.
- **One safe, copyable, Windows PowerShell command sequence for owner** using a private-key **path** outside the repo and secure ACLs, never the private key itself as CLI text. Commands must match the corrected signing script exactly; no Bash `$(...)` or `\` continuations inside a PowerShell-only instruction.
- Instruct the owner to review and explicitly authorize the **exact** 14 hunks and independent verifier upgrade, then execute the signing handoff locally. If no owner-held Ed25519 key exists, provide a secure offline initialization process requiring owner action, store safely outside repository and do not expose it to chat/CI.
- Ensure owner signs only after code fixes are frozen, and that any subsequent changes to protected files force a new review/signature. The owner has already authorized **internal TestFlight dispatch after legitimate gates pass**, so do not request a second general upload confirmation.

## 6. AUTOMATIC new signed production TestFlight — after actual gate PASS

When (and only when) the owner genuinely supplies authenticated signatures, the independently trusted verifier accepts all protected hunks and production UI gates have **zero mandatory skips**, continue execution immediately:

1. Commit signed register; push only candidate branch. Verify `git ls-remote` matches immutable new SHA and clean worktree. Before release validate signed SHA and code tree provenance, detect any code change since approved CI, and rerun required gates as appropriate on the **signed final SHA**. Do not release merely because pre-signing `efd82ca` was green.
2. In `.github/workflows/ios-testflight.yml` require `expected_sha` (it is currently optional), `data_profile=production`, `upload_to_testflight=true`, true `fetch-depth: 0`, independent trusted guard PASS, SHA match before importing Apple signing certificate; verify no unreviewed workflow edits and no secrets exposed.
3. Once preflight is green, dispatch the **existing** `ios-testflight.yml` with `--ref validation/maktabah-build-8401-repair-production-20261025`, `-f data_profile=production`, `-f upload_to_testflight=true`, `-f expected_sha=<EXACT_FINAL_SIGNED_SHA>` (on **Windows PowerShell**, use `$sha = (git rev-parse HEAD).Trim()`; no Bash substitution).
4. Confirm GitHub run ID, `headSha == expected_sha`, Xcode 27, Release archive, appropriate Team/entitlements/App Group, App Store distribution signing, correct bundle ID `com.davidpovarsky.chavrusatext`, display name `ChavrusaText`, embedded `OtzariaDefaultDataProfile=production`, unique monotonically increasing CFBundleVersion, preservation of same bundle ID for in-place upgrade, and no 3.82 GB corpus or huge search indexes embedded into IPA.
5. Confirm IPA export SHA256, App Store Connect upload succeeded, Apple processing reached `VALID` for the **new** build, and the new build is available to **existing INTERNAL testers**. If upload succeeds but Apple's processing is pending, say `UPLOAD_RECEIVED_PROCESSING` and keep checking within actual tool/session capabilities; don't promise background delivery. If Apple's API doesn't confirm tester availability, mark it unverified rather than inventing success. Never add external testers or submit for App Store review.
6. Do not merge branch to main/dev/integration. Do not delete historical Build 8401, old DB, notes, or test artifacts. Do not modify Asana without separate explicit request.

## 7. End report — factual, not marketing language

Always produce a short Hebrew executive summary with verified statuses and hyperlinks:

- `GATE_BLOCKED_OWNER_SIGNATURE` / `GATE_BLOCKED_VERIFIER_TRUST` / `GATE_BLOCKED_PRODUCTION_UI` as applicable, or `PRODUCTION_INTERNAL_TESTFLIGHT_VALID` only with complete independent evidence.
- Exact source SHA, signed SHA, verified trust anchor fingerprint, approved protected-hunk count, `Boundary Verification Result: PASS`, all required Xcode CI results, exact Tier P test numbers with **0 skips**, production DB version/digest/catalog counts, XCUITest `xcresult` links, app/IPA identifiers.
- TestFlight run URL, `CFBundleVersion`, App Store Connect build ID, `processingState=VALID`, internal tester availability and whether the physical iPad upgrade test is still pending.
- If blocked, show the **single specific next owner action** and a tested copyable command; preserve the candidate. Do not claim the app has been uploaded if not.

## 8. Owner's iPad acceptance checklist (27 October 2026)

After the new build is genuinely `VALID` and visible in TestFlight: **Update** the existing ChavrusaText beta **without uninstalling**. Confirm the regular full Otzaria corpus is reused without forced re-download; open a book absent from miniTest10; verify real text and search; next/prev/TOC tracking; Sefaria ↔ Otzaria settings transition with tabs; search highlight and Clear X; deep Rashi reference; Hebrew TOC; annotation persists across relaunch. Collect screenshots/crash/diagnostic artifacts for any failure. Physical owner acceptance is separate from automated CI success.

**This is an execute-and-verify instruction. Real safeguards and genuine owner identity take precedence over making the status light green.**