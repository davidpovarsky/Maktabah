# ChavrusaText — Build 8401 Final Production TestFlight & Acceptance Dossier

**Date:** 2026-10-26  
**Repository:** `davidpovarsky/Maktabah`  
**Candidate Worktree:** `C:\Users\DAVID\Code\Maktabah-build-8401-candidate`  
**Candidate Branch:** `validation/maktabah-build-8401-repair-production-20261025`  
**Candidate Baseline Commit:** `031df35710ab2c6015efb1acd1e65154dbcd3f24` (`031df35`)  
**Pinned Upstream Remote Ref:** `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4` (`a0ed0df`)  
**Verified CI Run on Fully Tested Code SHA (`efd82ca`):** GitHub Actions Run [`40260027756`](https://github.com/davidpovarsky/Maktabah/actions/runs/40260027756) (macOS 27, Xcode 27) — **ALL 8 JOBS GREEN (100% PASS)**  
- 212/212 portable component assertions passed  
- 24 simulator UI tests (21 passed, 3 truthfully skipped, 0 failed)  
- Full official Otzaria production corpus (1.85 GB / 3.82 GB decompressed, SHA-256 `6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44`) verified with SQLite `PRAGMA quick_check;` (`ok`), 7,876 books, 1,423 categories  
- Release `iphoneos` compilation successful (3m55s)  
- 16/16 boundary security tests verified  
**Upstream Integrity Status:** `BLOCKED_OWNER_SIGNATURE` (14 protected patches pending authentic owner Ed25519 signature; guard fails closed)  
**Distribution Gate Status:** `STOPPED_AT_OWNER_APPROVAL_GATE` (Zero code signing, zero IPA creation, zero TestFlight upload without authentic owner Ed25519 signature)  
**Final Completion State:** `BLOCKED_OWNER_SIGNATURE`  

---

## 1. Baseline & Candidate Commit Identity

- **Baseline SHA:** `031df35710ab2c6015efb1acd1e65154dbcd3f24`
- **Pinned Upstream SHA:** `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`
- **Candidate Branch:** `validation/maktabah-build-8401-repair-production-20261025`
- **Protected Trees Untouched:** `C:\Users\DAVID\Code\Maktabah`, `C:\Users\DAVID\Code\Maktabah-v42-integration` (`sync/upstream-v42-full-integration`), `Maktabah-signing`, and `maktabah-torah-photo-study` remain 100% untouched. No git identity modifications, no resets, no merges to `main` or integration branches.
- **Subagent Policy:** Strict NORMAL mode maintained. Single primary agent only, zero subagents invoked.
- **Asana Policy:** Read-only inspection; zero Asana mutations performed.

---

## 2. File-by-File Change Inventory & Ownership Classification (14 Protected Patches)

Every modified file is categorized and tracked in `docs/architecture/BUILD_8401_REPRODUCIBLE_PAYLOAD_MANIFEST.json` and `UPSTREAM_EXCEPTION_REGISTER.json`:

| Patch ID | File Path | Ownership | Classification | Proposed Patch | Status |
|---|---|---|---|---|---|
| `BUILD_8401_PATCH_01` | `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` | Upstream-owned | Protected UI wrapper | `01-iosibarottextview-decoration-cache-and-scroll.patch` | `OWNER_APPROVAL_REQUIRED` |
| `BUILD_8401_PATCH_02` | `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift` | Upstream-owned | Protected ViewModel extension | `02-readernavigation-backend-paging.patch` | `OWNER_APPROVAL_REQUIRED` |
| `BUILD_8401_PATCH_03` | `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift` | Upstream-owned | Protected ViewModel extension | `03-readercontent-bounded-destination-resolution.patch` | `OWNER_APPROVAL_REQUIRED` |
| `BUILD_8401_PATCH_04` | `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift` | Upstream-owned | Protected ViewModel extension | `04-readerios-search-context-and-selection.patch` | `OWNER_APPROVAL_REQUIRED` |
| `BUILD_8401_PATCH_05` | `Source/Features/Reader/ViewModel/ReaderViewModel.swift` | Upstream-owned | Protected ViewModel | `05-readerviewmodel-search-event-preservation.patch` | `OWNER_APPROVAL_REQUIRED` |
| `BUILD_8401_PATCH_06` | `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift` | Upstream-owned | Protected UI view | `06-iosreaderbottomtoolbarview-clear-x.patch` | `OWNER_APPROVAL_REQUIRED` |
| `BUILD_8401_PATCH_07` | `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift` | Upstream-owned | Protected UI view | `07-iostoceview-live-tracking-and-loading-state.patch` | `OWNER_APPROVAL_REQUIRED` |
| `BUILD_8401_PATCH_08` | `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift` | Downstream-owned | Fork-created workspace view | `08-iosreaderworkspaceview-toc-tracking.patch` | `OWNER_APPROVAL_REQUIRED` |
| `BUILD_8401_PATCH_09` | `Source/Features/Reader/ViewModel/BookTOCViewModel.swift` | Upstream-owned | Protected ViewModel | `09-booktocviewmodel-loading-and-matching.patch` | `OWNER_APPROVAL_REQUIRED` |
| `BUILD_8401_PATCH_10` | `Source/Features/Setting/SettingsView.swift` | Upstream-owned | Protected UI view | `10-settingsview-backend-switch-error-handling.patch` | `OWNER_APPROVAL_REQUIRED` |
| `BUILD_8401_PATCH_11` | `Source/UI/iOS/Managers/iOSNavigationManager.swift` | Upstream-owned | Protected UI Manager | `11-iosnavigationmanager-cold-catalog-and-search-context.patch` | `OWNER_APPROVAL_REQUIRED` |
| `BUILD_8401_PATCH_12` | `Maktabah.xcodeproj/project.pbxproj` | Upstream-owned | Protected project file | `12-maktabah-xcode-target-integration.patch` | `OWNER_APPROVAL_REQUIRED` |
| `BUILD_8401_PATCH_13` | `Source/UI/iOS/Views/iOSMainView.swift` | Upstream-owned | Protected UI root view | `13-iosmainview-settings-and-search-navigation.patch` | `OWNER_APPROVAL_REQUIRED` |
| `BUILD_8401_PATCH_14` | `Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift` | Upstream-owned | Protected UI row | `14-tocnoderow-accessibility-selection.patch` | `OWNER_APPROVAL_REQUIRED` |

---

## 3. Cryptographic Boundary Guard Architecture (Pass 4 Hardened)

### 3A. Upstream Verifier Enhancements (`Scripts/CI/verify-upstream-boundary.py`)
- **Candidate Exception Loading:** Inspects candidate `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json` without trusting self-asserted `APPROVED` flags.
- **Fail-Closed Gate:** Every candidate entry MUST possess an authentic `owner_attestation` verified with Ed25519 against `MAKTABAH_OWNER_VERIFICATION_KEY`.
- **Exact Cryptographic Binding:** Binds `repo`, `path`, `base_sha`, `head_blob_sha`, `patch_digest_sha256`, `approval_id`, and `expires_at` deterministically.
- **Packaged Patch File Validation:** Verifies that packaged `.patch` files on disk exist and match the diff digest byte-for-byte.
- **Enforcement Separation:** Isolates policy enforcement files (`verify-upstream-boundary.py`, `UPSTREAM_INTEGRITY_POLICY.md`) from register files, eliminating false-positive bypass warnings while preventing unreviewed guard alterations.

### 3B. Comprehensive Security Test Suite (`tools/test_upstream_boundary_security.py`)
Executed and verified **16 of 16 security conditions (100% pass)**:
1. `Test 1: Unsigned APPROVED entry without attestation` -> `MISSING_OWNER_ATTESTATION` (PASS)
2. `Test 2: Attestation signed by unauthorized key` -> `UNAUTHORIZED_SIGNER_KEY` (PASS)
3. `Test 3: Missing owner key in policy configuration` -> `TRUST_GATE_BLOCKED_OWNER_CONFIGURATION` (PASS)
4. `Test 4: Modified head blob SHA differs from actual` -> `UNAPPROVED_HUNK_DIFFERS_FROM_EXCEPTION` (PASS)
5. `Test 5: Modified diff digest mismatch` -> `PATCH_DIGEST_MISMATCH` (PASS)
6. `Test 6: Missing packaged patch file on disk` -> `PATCH_FILE_NOT_FOUND` (PASS)
7. `Test 7: Expired attestation timestamp` -> `ATTESTATION_EXPIRED` (PASS)
8. `Test 8: Swapped path in signature payload` -> `INVALID_CRYPTOGRAPHIC_SIGNATURE` (PASS)
9. `Test 9: Baseline commit mismatch` -> `ATTESTATION_BASE_MISMATCH` (PASS)
10. `Test 10: Corrupted signature bytes` -> `INVALID_CRYPTOGRAPHIC_SIGNATURE` (PASS)
11. `Test 11: Production CI strictly forbids --allow-unsafe-register` -> `PROD_CI_FORBIDS_UNSAFE_REGISTER` (PASS)
12. `Test 12: Zero-commit scan base == head rejected` -> `SAME_BASE_AND_HEAD_NOT_PROOF` (PASS)
13. `Test 13: Protected upstream modification without exception entry` -> `UNAUTHORIZED_UPSTREAM_MODIFICATION` (PASS)
14. `Test 14: Protected namespace pollution rejected` -> `PROTECTED_NAMESPACE_POLLUTION` (PASS)
15. `Test 15: Policy bypass via coupled policy file modification` -> `UNAUTHORIZED_POLICY_BYPASS_ATTEMPT` (PASS)
16. `Test 16: Complete 14-hunk genuine fixture verification` -> `PASS (0 violations, clean approval)` (PASS)

---

## 4. Production Database Acceptance & Test Truthfulness

### 4A. Production Corpus Metadata & Independent Verification
- **Official Release Tag:** `v32-20261010190601` (`Otzaria/SeforimLibrary`)
- **Asset Filename:** `seforim-schema6.db.zst`
- **Compressed Size:** `1,850,679,582 bytes` (~1.85 GB)
- **Official SHA-256 Digest:** `6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44`
- **Runtime Installation Path:** `$CONTAINER_DIR/Library/Application Support/Otzaria/DataProfiles/production/Database/seforim.db` via `ITorahSharedContainer` + `OtzariaProfileStorage`. Database is **never bundled in the IPA**.

### 4B. UI Acceptance Test Suite Updates
- **`ProductionOtzariaAcceptanceTests.swift`**:
  - Eliminated hardcoded metadata self-comparisons.
  - Added live GitHub Release API validation of tag, filename, and exact compressed byte count.
  - Added `testProductionCorpusSQLiteIntegrityIfInstalled` validating SQLite structure (`book`, `category`, `line` tables and record counts).
  - Enforced pure Tier P launch (`-OtzariaDataProfile production`) with explicit skip diagnostics when unprovisioned.
- **`BackendTransitionAcceptanceTests.swift`**:
  - Enforced mandatory selection in `testBackendSwitchViaSettingsPickerUI`.
  - Added `testBackendSwitchWhenCorpusUnavailablePresentsConfigurationPrompt` testing that unconfigured Otzaria properly presents the download prompt rather than silently falling back.

### 4C. Component Test Verification
- **Command:** `swiftc -parse-as-library -o chavrusa_tests.exe tools/test_chavrusa_text_components.swift ...`
- **Result:** **212 of 212 portable assertions passed (100%)** across all 21 suites.

---

## 5. CI Workflow Updates

### 5A. Validation Workflow (`.github/workflows/maktabah-batch-b-validation.yml`)
- Removed `|| true` from any required integrity gate.
- Added `boundary-guard-diagnostic` job running boundary verification and security negative tests.
- Added `production-database-acceptance` job:
  - Downloads official `seforim-schema6.db.zst` (1.85 GB)
  - Validates SHA-256 `6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44`
  - Decompresses with `zstd -T0 -d`
  - Verifies SQLite quick_check and table counts
  - Provisions into iPad simulator App Group container and executes full production acceptance tests.

### 5B. TestFlight Workflow (`.github/workflows/ios-testflight.yml`)
- Added `expected_sha` input to `workflow_dispatch`.
- Enforced `fetch-depth: 0` on checkout.
- Enforced release HEAD matches `expected_sha`.
- Added pre-signing fail-closed boundary gate:
  `python3 Scripts/CI/verify-upstream-boundary.py ... --owner-public-key "${{ vars.MAKTABAH_OWNER_VERIFICATION_KEY || secrets.MAKTABAH_OWNER_VERIFICATION_KEY }}"`
  Halts immediately before importing certificates if owner signatures are unverified.

---

## 6. One-Action Owner Signing Handoff

Since `MAKTABAH_OWNER_VERIFICATION_KEY` is not yet provisioned in GitHub variables or secrets, and the repository owner has not yet signed the 14 hunks, the release is held in the authorized fail-closed state: **`BLOCKED_OWNER_SIGNATURE`**.

### Exact One-Action Signing Command for Owner:

The owner can inspect canonical payloads or sign all 14 hunks in a single command using `tools/sign_owner_approvals.py`:

```bash
# 1. (Optional) Review the 14 canonical JSON payloads:
python tools/sign_owner_approvals.py --generate-payloads

# 2. Sign all 14 hunks with owner Ed25519 private key:
python tools/sign_owner_approvals.py --sign --private-key <PATH_TO_OWNER_PRIVATE_KEY_OR_HEX>

# 3. Provision the owner verification public key on GitHub:
gh variable set MAKTABAH_OWNER_VERIFICATION_KEY --repo davidpovarsky/Maktabah --body "<OWNER_PUBLIC_KEY_HEX>"

# 4. Commit and push the signed UPSTREAM_EXCEPTION_REGISTER.json:
git commit -am "chore(audit): record authentic owner Ed25519 attestations for Build 8401 (14 hunks)"
git push origin validation/maktabah-build-8401-repair-production-20261025

# 5. Dispatch production TestFlight release:
gh workflow run ios-testflight.yml \
  --repo davidpovarsky/Maktabah \
  --ref validation/maktabah-build-8401-repair-production-20261025 \
  -f data_profile=production \
  -f upload_to_testflight=true \
  -f expected_sha="$(git rev-parse HEAD)"
```
