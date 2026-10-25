# Batch B Cryptographic Owner Approval Gate Specification

**Audit Date:** 2026-10-25  
**Baseline Git Commit:** `c8defbf812d34dd22ea1b7b63b1a356c0e96fa8f`  
**Upstream Pinned SHA:** `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`  
**Authority:** `docs/architecture/UPSTREAM_INTEGRITY_POLICY.md`  
**Gate Status:** `TRUST_GATE_BLOCKED_OWNER_CONFIGURATION` (Fail-closed: Owner Ed25519 public key unconfigured in policy/environment)  

---

## 1. Principles of the Cryptographic Owner Gate (Section 3 Implementation)

Under upstream-clean layer policy, autonomous agents and non-owner contributors are **strictly forbidden** from self-approving exceptions that modify protected upstream-owned files.

1. **Local Proposal Manifest Only:**  
   The workspace file `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json` is strictly a **proposal manifest**. All protected exceptions are generated in state:
   - `proposal_state`: `"PATCH_PROPOSED"`
   - `status`: `"OWNER_APPROVAL_REQUIRED"`
   - `owner_attestation`: `null`
2. **Cryptographic Ed25519 Attestation Requirement:**  
   An exception is considered `APPROVED` by CI only when it includes an authentic cryptographic attestation containing:
   - `signer_public_key`: Hex/base64-encoded Ed25519 public key matching the pinned owner key.
   - `signature`: Detached Ed25519 signature over canonical UTF-8 payload.
   - `base_sha`: The exact baseline commit SHA or verified ancestor (`c8defbf812d34dd22ea1b7b63b1a356c0e96fa8f`).
   - `expected_head_blob_sha`: Git object hash (`git hash-object`) of the file resulting from applying the patch.
   - `patch_digest_sha256`: Cryptographic SHA-256 digest of normalized `git diff` output.
   - `expires_at`: ISO 8601 expiration timestamp (must be strictly in the future).
   - `repo`: Canonical repository identifier (`davidpovarsky/Maktabah`).
3. **Canonical Payload Construction:**  
   Constructed deterministically by `construct_canonical_attestation_payload`:
   ```python
   canonical_data = {
       "approval_id": str(approval_id),
       "base_sha": str(base_sha),
       "canonical_patch_sha256": str(patch_sha256),
       "expires_at": str(expires_at),
       "head_blob_sha": str(head_blob_sha),
       "path": str(path).replace("\\", "/"),
       "repo": str(repo)
   }
   return json.dumps(canonical_data, sort_keys=True, separators=(',', ':')).encode('utf-8')
   ```
4. **CI Defense Against Self-Authorization & Blind Spots:**  
   The CI verification script `Scripts/CI/verify-upstream-boundary.py` enforces:
   - **Production CI Mode Protection:** When running under CI (`CI=true` or `GITHUB_ACTIONS=true`), the `--allow-unsafe-register` CLI override is **strictly forbidden** and fails closed immediately (`PROD_CI_FORBIDS_UNSAFE_REGISTER`).
   - **Fail-Closed on Unconfigured Key:** If `MAKTABAH_OWNER_VERIFICATION_KEY` is unset, verification fails closed with `TRUST_GATE_BLOCKED_OWNER_CONFIGURATION`.
   - **No Blind Zero-Range Scans:** Running with `--base == --head` (e.g. `--base HEAD --head HEAD`) is rejected with `SAME_BASE_AND_HEAD_NOT_PROOF`.
   - **Attestation Expiry Check:** Expired attestations fail with `ATTESTATION_EXPIRED`.
   - **Signer Identity Check:** Signatures by unauthorized keys fail with `UNAUTHORIZED_SIGNER_KEY`.
   - **Signature Verification:** Tampered payloads or invalid signatures fail with `INVALID_CRYPTOGRAPHIC_SIGNATURE`.

---

## 2. Complete Exception Proposal Registry

The following 8 entries represent the complete proposal manifest for Batch B in `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json`:

| Patch ID | Protected File | Status | Expected Blob SHA | Patch Digest (SHA-256) |
|:---|:---|:---:|:---:|:---:|
| `BATCH_B_PATCH_01` | `Maktabah.xcodeproj/project.pbxproj` | `OWNER_APPROVAL_REQUIRED` | `8bf340384b857901ab9bfdeec70c46409f4a66c6` | `afbe716a5ae8854ebd02a9decf183fff23af3f372d40e4548d41f9e09aa9db03` |
| `BATCH_B_PATCH_02` | `Source/Features/Reader/iOS/iOSReaderView.swift` | `OWNER_APPROVAL_REQUIRED` | `92816935eaf52d5d2abcd38a1b6a26ac7c2c6f2c` | `97abbfe5d5489c4cc6c59377a9711ff3b14097b96a564e591b1331d22c5e634c` |
| `BATCH_B_PATCH_03` | `Source/UI/iOS/Views/iOSMainView.swift` | `OWNER_APPROVAL_REQUIRED` | `5e80e89683028e50f45ccdebaa91e62412625f4e` | `f9e529a5fcd6a98423b70fd59592d6d73bb42819e57086dce440268b5f99afd6` |
| `BATCH_B_PATCH_04_05` | `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` | `OWNER_APPROVAL_REQUIRED` | `d27343c10b51fc35efe985b1d1f925dd0ac2ac08` | `ce92efaf0554b9d1a57123a88dce11687288bedf941e59dc346e5212526517cc` |
| `BATCH_B_PATCH_06` | `Source/Features/Reader/ViewModel/Extensions/Reader+Annotation.swift` | `OWNER_APPROVAL_REQUIRED` | `fa7fb390fa4931445d785a4b24b8f91da021fb55` | `055c93a7da5763c73a9e368979acccc9666b0994b7bfc41c4a5aa93d92e1f490` |
| `BATCH_B_PATCH_07` | `Source/UI/iOS/Managers/iOSReaderSessionManager.swift` | `OWNER_APPROVAL_REQUIRED` | `217bbb011c09173f292f738375b7b63f0aa5e4b5` | `146473ab6364d55a11353d277047298dc8f399cdce1431eb74116349f8f35a63` |
| `BATCH_B_PATCH_08` | `Source/UI/iOS/Managers/iOSNavigationManager.swift` | `OWNER_APPROVAL_REQUIRED` | `9117460a175136cf5dca71aad3e4d11238b029f6` | `a2a643568ed5e93e12910bc6a86550925bf7b64a9962c6fe0460471e98ead128` |
| `BATCH_B_PATCH_09` | `.github/workflows/upstream-boundary-guard.yml` | `OWNER_APPROVAL_REQUIRED` | `06deea9b2d9fa57b3eed58d01cfdcf1e1ab4cdd5` | `a9a8b33b668a5e81e5a07cf28f37ade8a8779fd84ca5b6e126c562fdc36281e5` |

---

## 3. CI Guard Verification Fixtures

The 28 adversarial fixtures in `tools/test_verify_upstream_boundary.py` comprehensively test this gate (all 28 passed):

- **Fixture 12a:** Valid Ed25519 signature + configured test owner key -> `PASS (APPROVED_UPSTREAM_EXCEPTION)`.
- **Fixture 12b:** Extra hunk on approved file -> `FAIL (UNAPPROVED_HUNK_DIFFERS_FROM_EXCEPTION)`.
- **Fixture 12c:** Owner key unconfigured in environment -> `FAIL (TRUST_GATE_BLOCKED_OWNER_CONFIGURATION)`.
- **Fixture 12d:** Corrupted cryptographic signature -> `FAIL (INVALID_CRYPTOGRAPHIC_SIGNATURE)`.
- **Fixture 12e:** Unauthorized signer key -> `FAIL (UNAUTHORIZED_SIGNER_KEY)`.
- **Fixture 12f:** Expired attestation -> `FAIL (ATTESTATION_EXPIRED)`.
- **Fixture 12g:** Production CI environment with `--allow-unsafe-register` -> `FAIL (PROD_CI_FORBIDS_UNSAFE_REGISTER)`.
- **Fixture 13:** Modified approval register + source in same PR -> `FAIL (Coupled Bypass)`.
- **Fixture 17:** Unapproved proposal in `OWNER_APPROVAL_REQUIRED` -> `FAIL (PENDING_UPSTREAM_APPROVAL)`.
- **Fixture 18:** Agent-created APPROVED without owner attestation -> `FAIL (MISSING_OWNER_ATTESTATION)`.
- **Fixture 19:** Attestation missing signature/signer -> `FAIL (MISSING_OWNER_SIGNATURE)`.
- **Fixture 20:** Stale approval at wrong base -> `FAIL (ATTESTATION_BASE_MISMATCH)`.
- **Fixture 21:** CLI `--exception-register` without unsafe flag -> ignored and `FAIL`.
- **Fixture 22:** Blind `--base HEAD --head HEAD` scan -> `FAIL (SAME_BASE_AND_HEAD_NOT_PROOF)`.
- **Fixture 23:** Patch diff digest mismatch -> `FAIL (PATCH_DIGEST_MISMATCH)`.

---

## 4. Current Gate Status

The gate status is **`TRUST_GATE_BLOCKED_OWNER_CONFIGURATION`** awaiting the repository owner's configuration of `MAKTABAH_OWNER_VERIFICATION_KEY` and explicit cryptographic attestation signing. ZERO protected upstream files are modified on the active branch (`sync/upstream-v42-full-integration`).
