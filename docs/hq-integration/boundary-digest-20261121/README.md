# Deterministic protected-patch verification — 2026-11-21

Asana work item: `1219848552180462`.

This isolated change repairs patch-digest reproducibility and signed-record compatibility. It does not approve protected source, sign an owner record, configure a trust key, change the exception register, or qualify the application for release.

Base: `da8558321a38d3c2c18850b084583f35a812dca8`.

## Defect and rendering contract

Both boundary guards previously hashed ordinary `git diff` output. Its `index` line abbreviates object IDs according to Git configuration and the object database. The same base/head blobs can therefore acquire a different SHA-256 patch digest when a prefix length grows.

Both guards now render LF-normalized bytes with full object IDs, binary patch support, no external diff/textconv, fixed path prefixes, quoting, context, algorithm, indentation heuristic, blank-context rendering and submodule display. They do not decode arbitrary patch bytes through a replacement-character codec. Rendering-only environment overrides are removed. Ordinary Git clean/filter and attributes semantics remain intact, including a global `core.autocrlf` used to materialize Windows files.

WORKTREE rendering includes actual staged and unstaged bytes via the net baseline-to-worktree diff. It does not substitute the committed HEAD patch for an uncommitted file.

## Authentic legacy compatibility

The existing canonical seven-field Ed25519 payload is unchanged:

`repo`, `path`, `base_sha`, `head_blob_sha`, `canonical_patch_sha256`, `approval_id`, `expires_at`.

The verifier first checks the external pinned signer identity, full blob binding and authentic signature over exactly those values. A legacy digest is accepted only when its packaged archive has that exact authenticated SHA-256 and expanding only the archive's abbreviated `index` object tokens produces the exact current full-index patch. The object prefixes must match the current full IDs. Every hunk, path, mode and other byte remains significant.

No archive, malformed/multi-file archive, changed hunk/path/mode/object, corrupt archive, or invalid signature remains a failure. Archive reads are constrained to the real repository: both the architecture directory and the selected archive must remain inside their allowed real paths, including through symbolic links or NTFS junctions.

The verifier reports whether a successful record used `full-index-v1` or `authenticated-legacy-index-width`. It does not trust an unsigned format selector.

## Approval identity and signer preflight

The signed `owner_attestation.approval_id` is authoritative. A legacy record without that field can still reconstruct and verify its exact signed `approval_ref` payload. A conflicting unsigned `approval_ref` or `patch_id` is rejected. Conflicting blob or digest aliases are also rejected, so a different digest cannot be compared than the one authenticated by the signature.

The signing tool preserves the same payload and key-loading mechanism. Its preflight now rejects conflicting proposal identity/blob/digest/archive fields before loading a private key or mutating a record. New full-index manifests must name full immutable source commit IDs, exact blobs and the exact generated patch bytes. The manifest count must match its declared total; the historical Build 8401 manifest remains the default.

`tools/generate_owner_patch_manifest.py` creates only unsigned patches and a manifest in a new output directory. It never overwrites an existing directory or writes a register. Example, after the final source is frozen:

```text
python tools/generate_owner_patch_manifest.py --base 031df35710ab2c6015efb1acd1e65154dbcd3f24 --head <FROZEN_SOURCE_COMMIT> --upstream-ref a0ed0df908a6cb38bc459d4baaeb400f447b2fc4 --out-dir <NEW_REVIEW_DIRECTORY>
```

No production manifest generation or signing was performed during this repair. All test signatures use in-memory, explicitly non-production fixture keys and synthetic temporary repositories.

## Existing admission routes remain distinct

- `tools/verify_upstream_boundary.py` can inspect authentic signed candidate records from HEAD/WORKTREE, but still requires the independently supplied pinned owner verification key.
- `Scripts/CI/verify-upstream-boundary.py` continues to load the register from the trusted base. Its supported admission route is a reviewed register/archive-only base commit, followed by the exact source whose signed baseline is a valid ancestor. The protected base blobs must still produce the exact signed diff. No unsafe-register override is needed or introduced.

Current unsigned records are not normalized or promoted. In particular, a historical document-anchor `approval_ref` that differs from the signed patch ID must be resolved in a reviewed proposal before signing; the tool will not silently rewrite it.

Existing genuine legacy signatures require no key rotation or signature rewrite when their exact authenticated archives prove the width-only difference. A genuinely changed protected patch, incompatible archive or contradictory identity still requires an authentic owner decision and signature. The implementation cannot supply that authority.

## Caller and integrity-pin impact

The helpers are intentionally self-contained and byte-identical in both guards. The ordinary PR guard checks out only its trusted base guard file; importing a new helper from untrusted HEAD would weaken that trust boundary. A fixture asserts parity of the two helper blocks.

The existing `.github/workflows/upstream-boundary-guard.yml` remains unchanged. Its PR path continues to execute the guard from the trusted target branch; the new implementation only becomes that trusted implementation after normal review and admission.

The diagnostic job in `.github/workflows/maktabah-batch-b-validation.yml` now runs all three disposable fixture suites and retains its exact verifier SHA-256 check. The final LF Git-source pins are:

| Guard | SHA-256 |
| --- | --- |
| `tools/verify_upstream_boundary.py` | `9733798a242382f59da99cb999a169e2c69c59010b336742e9a8fa151e837676` |
| `Scripts/CI/verify-upstream-boundary.py` | `70cf39a26e0010122467c9775d9290a93da2a82dcc792c48b679251a4e93baca` |

The actual staged Git blob is checked against the diagnostic pin before commit. No app-source or Native CI rerun is required for this infrastructure-only change.

## Validation evidence

The existing guard suite now resolves the checker in its own checkout and uses its current interpreter. It preserves all 31 scenarios. Its bad-digest case now signs the deliberately wrong fixture digest correctly, so it reaches the digest gate after signature verification.

The 16-case security suite now creates its own disposable repository with 14 synthetic protected files. It no longer writes or temporarily edits real product/policy files in the source checkout.

Windows Python 3.12.5 with the already installed `cryptography 46.0.7` ran all three suites successfully before the final clean/filter-environment refinement:

| Suite | Result | Evidence |
| --- | --- | --- |
| Existing boundary scenarios | 31 passed | `test_verify_upstream_boundary.py.log` |
| Security conditions | 15 negative + 1 positive passed | `test_upstream_boundary_security.py.log` |
| New deterministic/compatibility suite | 18 methods passed, exercising both guards | `test_upstream_patch_digest.py.log` |

`windows-tests.json` records all three zero exit codes. The new suite includes a real four-digit object-prefix collision, `core.abbrev` 7/8/12/40, repo-local `diff.suppressBlankEmpty`, an escaping archive symlink/junction, archive tampering, changed hunk/path/mode/index, invalid signature, identity/digest/blob conflicts, unsigned generator parity and unchanged seven-field payload bytes.

After the final environment refinement, the added 19th method was run directly on Windows against both final guard files. It materializes a real CRLF checkout using an isolated global `core.autocrlf=true` configuration and proves that the WORKTREE patch and `hash-object` result match their committed equivalents. `windows-worktree-filter-parity.log` and `.json` record the pass and the exact final guard source hashes above. No user's global Git configuration was changed.

The same fixture suites and the new targeted filter case also passed on Linux. Completed suites were not repeated after the narrow environment correction; the targeted parity test verifies that specific remaining risk. These are boundary-tool results, not owner approval or Native application acceptance.
