# ChavrusaText Build 8401 — Owner Cryptographic Signing Handoff Dossier

**Date:** 26 October 2026  
**Status:** `GATE_BLOCKED_OWNER_SIGNATURE`  
**Target:** Internal TestFlight Beta for iPad validation  
**Repository:** `davidpovarsky/Maktabah`  
**Candidate Worktree:** `C:\Users\DAVID\Code\Maktabah-build-8401-candidate`  
**Candidate Branch:** `validation/maktabah-build-8401-repair-production-20261025`  
**Verified Candidate Commit:** `c6f8efeedbbf276ff1a052733c395c0297079fd7`  
**Verified 100% Green CI Run:** [Run 40329222602](https://github.com/davidpovarsky/Maktabah/actions/runs/40329222602) (8 of 8 jobs passed, 0 skipped tests)  
**Baseline Commit:** `031df35710ab2c6015efb1acd1e65154dbcd3f24`  
**Pinned Upstream Commit:** `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`  

---

## 1. Executive Summary & Verification State

All code repairs, boundary security fixes, and production acceptance test upgrades are complete and verified in the candidate branch:

- **ChavrusaText 7 Core Defect Repairs**: 212 of 212 component assertions pass across 21 test suites (`tools/test_chavrusa_text_components.swift`).
- **15th Boundary Security Violation (`UNAUTHORIZED_POLICY_BYPASS_ATTEMPT`)**: Completely eliminated. `Scripts/CI/verify-upstream-boundary.py` is restored to exact baseline commit `031df35710ab2c6015efb1acd1e65154dbcd3f24` (blob SHA `6483a0fa0404928051547a957f4e7ea933d2b28e`, 0 diff against baseline).
- **Independent Hardened Boundary Verifier**: Implemented at `tools/verify_upstream_boundary.py` with cryptographic Ed25519 signature verification, fail-closed enforcement, and workflow SHA256 pinning (`654a411bc78011037e6b0178d63ad8e2efb8cae3a6bb3da823738d076b387d0f`). 16/16 security tests pass (`tools/test_upstream_boundary_security.py`).
- **Production Otzaria Corpus UI Acceptance**: Zero-skip contract enforced. App container environment variables passed to runner, `BackendCoordinator` respects launch arguments, SQLite3 database verified with `PRAGMA quick_check(1) = ok`, catalog count assertions active, and `tools/verify_xcresult_zero_skips.py` guarantees fail-closed gate.
- **Owner Signing Tooling**: `tools/sign_owner_approvals.py` updated to accept private-key files only (`--private-key-file`), perform atomic writes via `.tmp` and `os.replace`, validate 14/14 patch files and digests, and run pre-commit verification against `WORKTREE`.

**Current Checkpoint:**
The release pipeline is intentionally and securely halted at `GATE_BLOCKED_OWNER_SIGNATURE`. In accordance with `UPSTREAM_INTEGRITY_POLICY.md` and the team safety contract, no mock or self-generated signature has been applied. Authentic owner signature of the 14 approved hunks is required.

---

## 2. Pinned Verifier & Security Manifest Integrity

| Component | Path | SHA256 Digest | Status |
| :--- | :--- | :--- | :--- |
| **Baseline Verifier** | `Scripts/CI/verify-upstream-boundary.py` | `09c647b0bf31c94d0c15efcf95104be66e4a6452292f76783d7350cb4a5e305e` | Matches Baseline `031df357` (Exact Blob `6483a0fa`) |
| **Hardened Verifier** | `tools/verify_upstream_boundary.py` | `654a411bc78011037e6b0178d63ad8e2efb8cae3a6bb3da823738d076b387d0f` | Pinned in CI workflows |
| **Signing Tool** | `tools/sign_owner_approvals.py` | Verified | `--private-key-file`, atomic `.tmp`, pre-commit WORKTREE |
| **Zero-Skips Verifier** | `tools/verify_xcresult_zero_skips.py` | Verified | Fail-closed post-check for xcresult |
| **Exception Register** | `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json` | Managed | Exactly 14 hunks pending owner signature |

---

## 3. Reviewed 14-Hunk Approval Inventory

Every hunk below has been reviewed for upstream minimality, isolation, and backward compatibility.

| ID | File Path | Head Blob SHA | Diff SHA256 | Patch File | Architectural Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `BUILD_8401_PATCH_01` | `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` | `23cd37e5897b51b9d19839a089d8d3f4a0abc597` | `fd59a96009a07b2113ae8bd67dd777a582cc780d30f95314c2fc0fae14b714be` | `01-iosibarottextview-decoration-cache-and-scroll.patch` | Search highlight decoration cache key & programmatic scroll preservation |
| `BUILD_8401_PATCH_02` | `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift` | `4b8a88bb9001fe58836d1bfedacb3e53a21ccc0d` | `34b40f8baea61c7f2d05c1c051a10e3aebba740ec4057bad0bced76a48189d52` | `02-readernavigation-backend-paging.patch` | Multi-backend forward/backward paging boundary coordination |
| `BUILD_8401_PATCH_03` | `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift` | `cda56656ac7ff62db5b3403f043ddcbc890fc550` | `5cd5923ac01179af1a46e58429f843c688bd1e4024b49a42c072f42775e67bbe` | `03-readercontent-bounded-destination-resolution.patch` | Asynchronous generation token checking preventing stale content overwrite |
| `BUILD_8401_PATCH_04` | `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift` | `1b1d4b0520eae69000ed5af4fec24b552f33ca04` | `28a36e0bd79ffae0c081c8897318a3081ea4e33c604673dc11f9478a4d774f52` | `04-readerios-search-context-and-selection.patch` | iOS Reader search context binding & segment range mapping |
| `BUILD_8401_PATCH_05` | `Source/Features/Reader/ViewModel/ReaderViewModel.swift` | `9844fc450294c228182b6e71730b5bbb3ff6a2f2` | `a3da7d01ff3be86d13c0503e2d7555c2527207f760e273209191e935f1598ee8` | `05-readerviewmodel-search-event-preservation.patch` | Preserving search context events across view model lifecycle |
| `BUILD_8401_PATCH_06` | `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift` | `95e0e8cb3085b82fffc23f77c89e2f3c3ea879ec` | `5ea782f34f538f1eeffed9415b8f591a436037b5b66d09bd0ad001513372c58a` | `06-iosreaderbottomtoolbarview-clear-x.patch` | Search highlight clear button ('X') in bottom toolbar |
| `BUILD_8401_PATCH_07` | `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift` | `046467027ea59d332617f09f4b518c0678dcf4d4` | `41cfef4ba90ef9ca8cfa63a56cf99ffdbad39066601445b23d9a117a1e0c5ef9` | `07-iosreadernavigationpopoverview-backend-paging.patch` | Popover navigation binding for ChavrusaText pagination |
| `BUILD_8401_PATCH_08` | `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift` | `9c6696dbf9cb4691bc954e7d17e766e447e112d8` | `bc6132dd75a2d1d054e0c3452cff1fa565d753bf8b6287cf14e7a7df49e52c8c` | `08-iosreaderworkspaceview-header-title-accessibility.patch` | Unique accessibility identifiers disambiguating header title from overlay |
| `BUILD_8401_PATCH_09` | `Source/Features/Reader/ViewModel/BookTOCViewModel.swift` | `38adfad4c13b31bf9c964c093e788d0db489b280` | `f48d826698cba715d8b0122bc49f3eae43d0b51b8436ee0c7ac1509e04ad24a4` | `09-booktocviewmodel-loading-and-matching.patch` | TOC hierarchy loading, depth indentation, and matching for Otzaria/Sefaria |
| `BUILD_8401_PATCH_10` | `Source/Features/Setting/SettingsView.swift` | `e7d7f1d554290526fe3b81b54cc8db36135fadba` | `6032922fd8075e96487c9087be75d92552b2a11f7de51c389bcfb38fd21a9a62` | `10-settingsview-backend-switch-error-handling.patch` | Settings backend switcher with configuration prompt and fallback prevention |
| `BUILD_8401_PATCH_11` | `Source/UI/iOS/Managers/iOSNavigationManager.swift` | `4bc589a10500b1d54831ef4a4a130f243467dbbd` | `90a227d7ff6b7ee3b88dbd71ec5cb073a7c267578be9ea90094a304775b4b752` | `11-iosnavigationmanager-cold-catalog-and-search-context.patch` | Cold catalog launch resolution & cross-feature search context routing |
| `BUILD_8401_PATCH_12` | `Maktabah.xcodeproj/project.pbxproj` | `f4238e237abf83e050de468f8a6a1ce746733e36` | `7c53ed58272d4753d07201d49eeb5700bacd8d082d4289bd0c95ced26641be44` | `12-maktabah-xcode-target-integration.patch` | Target membership for ChavrusaText modules and acceptance test files |
| `BUILD_8401_PATCH_13` | `Source/UI/iOS/Views/iOSMainView.swift` | `090b8e86dd24b44237d22807a8efc6bdd66f469e` | `b6dc9ee8b2ba4983e332a965eab545a7eb2e3424f77d4a7cbd8f02b798f8784f` | `13-iosmainview-settings-and-search-navigation.patch` | Main tab bar navigation state synchronization with active reader session |
| `BUILD_8401_PATCH_14` | `Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift` | `9b924357f80454eac037f8ab48454dd07ce69a66` | `b445028df943660eab3ad1bfd9f23176fae70be41025db21e7242413d94a3563` | `14-tocnoderow-accessibility-selection.patch` | TOC row accessibility labels, traits, and indentation presentation |

---

## 4. Public-Key Anchor Status

- **Status:** `OWNER_ACTION_REQUIRED`
- **Verification Anchor:** Repository variable / secret `MAKTABAH_OWNER_VERIFICATION_KEY` must be populated with the owner's 32-byte Ed25519 public key (hex-encoded, 64 characters).
- The signing script verifies that the public key provided to `--owner-public-key` matches the key that produced the signatures and anchors the attestations.

---

## 5. Copyable Owner PowerShell Signing Sequence

Run the following commands in **Windows PowerShell** to sign the 14 hunks using your private key file.

> [!IMPORTANT]
> The private key must reside on your local machine outside the repository (e.g. `$HOME\.ssh\maktabah_owner_ed25519.key`). Never check in private keys or paste private key bytes into chat.

```powershell
# 1. Switch to candidate worktree
Set-Location "C:\Users\DAVID\Code\Maktabah-build-8401-candidate"

# 2. (Optional: If you do not yet have an Ed25519 key, generate one securely offline)
python -c "from cryptography.hazmat.primitives.asymmetric import ed25519; import os; key = ed25519.Ed25519PrivateKey.generate(); raw = key.private_bytes_raw(); pub = key.public_key().public_bytes_raw().hex(); p = os.path.expanduser('~\\.ssh\\maktabah_owner_ed25519.key'); open(p, 'wb').write(raw); print(f'Private key written to: {p}\nPublic key (hex): {pub}')"

# 3. Preview canonical attestation payloads (read-only verification)
python tools/sign_owner_approvals.py --generate-payloads

# 4. Sign the 14 hunks atomically using your private key file
# Replace <OWNER_PUBLIC_KEY_HEX> with your 64-character public key hex
$OwnerPubKey = "<OWNER_PUBLIC_KEY_HEX>"
python tools/sign_owner_approvals.py --sign --private-key-file "$HOME\.ssh\maktabah_owner_ed25519.key" --owner-public-key $OwnerPubKey

# 5. Verify the signatures against the working copy before committing
python tools/sign_owner_approvals.py --verify --head-ref WORKTREE --owner-public-key $OwnerPubKey

# 6. Commit and push the signed exception register
git add docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json
git commit -m "security(upstream): record owner cryptographic attestations for 14 approved hunks"
git push origin validation/maktabah-build-8401-repair-production-20261025

# 7. Configure GitHub Repository Variable (one-time)
# gh variable set MAKTABAH_OWNER_VERIFICATION_KEY --body $OwnerPubKey
```

---

## 6. Automatic Production TestFlight Trigger (Post-Signing)

Once Step 5 is executed and pushed:
1. Run CI validation:
   ```powershell
   gh workflow run maktabah-batch-b-validation.yml --ref validation/maktabah-build-8401-repair-production-20261025
   ```
2. Trigger the automated signed production TestFlight build:
   ```powershell
   $sha = (git rev-parse HEAD).Trim()
   gh workflow run ios-testflight.yml --ref validation/maktabah-build-8401-repair-production-20261025 -f data_profile=production -f upload_to_testflight=true -f expected_sha=$sha
   ```
3. Watch the TestFlight run:
   ```powershell
   gh run list --workflow=ios-testflight.yml --limit 1
   ```
