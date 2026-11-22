# Mandatory owner approval before signing

Code: 5255c96ae9cdd02fb661ec2fc8801e33125b09b8. Four CI files changed;
Source, Vendor, Xcode project and original UI-test trees are unchanged.

TestFlight now requires a separate owner approval job before the whole signing
and upload job. Both check out the same immutable github.sha. The gate loads
tools/verify_upstream_boundary.py from reviewed commit
978db8b37256d4dd2d58e91a0ea8d531798221c0 and checks SHA-256
9733798a242382f59da99cb999a169e2c69c59010b336742e9a8fa151e837676
before loading it from a private temporary directory under isolated Python.
It uses the existing cryptography 43.0.3 dependency and external
MAKTABAH_OWNER_VERIFICATION_KEY. Candidate configuration cannot supply its
verifier or verification key. Existing signature/schema/archive checks remain.

The consumer requires actual candidate/event SHA and four source trees,
authentic-report PASS with exit zero, exact protected-path coverage, correct
repository, and future expiry. Raw verifier results and failure receipts are
retained. The PR boundary workflow includes dev and fails when trusted-target
fetch, merge-base or guard checkout fails. Trusted-base registry admission
remains unchanged; no unsafe override was introduced.

## Actual checks

19 new controls passed: 18 initially, then the one added source-stability
success/failure control alone. Synthetic PASS reports are mocked wrapper
fixtures, not owner signatures. Both YAML documents were parsed and their
dependency/branch structure verified. Existing cryptographic/application suites
were not rerun.

The committed real wrapper on 5255c96a returned exit1/FAILED as required:
external owner verification key absent, pinned guard FAIL, 49 protected paths,
zero verified approvals, and its existing coupled-policy-change diagnostic.
This is refusal evidence, not owner approval, Native acceptance, IPA or
TestFlight submission.

Snapshot9c66b4ccc06340a04de53a4c3370182873ed18bc had24 registry records,
zero owner_attestation/signatures/APPROVED. Policy baseline031df357 had8
unsigned proposals. Repository key metadata collection reads succeeded and
found no MAKTABAH_OWNER_VERIFICATION_KEY. Only public-key metadata was examined;
no private-key search/read/generation/signing occurred.

The old unsigned2818019 manifest still lists the same49 protected paths, with
three stale blobs: iOSReaderWorkspaceView, iPadLayout and iOSIbarotTextView.
The coordinator has since integrated the editor consumer and has another hook
pending. These snapshot facts are not the final application closure.

## Procedure after the final source is frozen

1. Freeze actual candidate A after remaining Native/editor work. Use
   tools/generate_owner_patch_manifest.py with --base
   031df35710ab2c6015efb1acd1e65154dbcd3f24, --head A, --upstream-ref
   a0ed0df908a6cb38bc459d4baaeb400f447b2fc4 and a NEW --out-dir.
   The existing generator emits unsigned full-index schema1.3.0 and refuses
   existing output directories or protected additions/deletions.
2. Preserve historical evidence. Prepare one effective final proposal per
   protected path with exact generated ID/blob/digest. A signing proposal's
   approval_ref must equal patch_id; historical BUILD_8401 documentation
   anchors are not those IDs. Keep proposals unsigned until actual owner signing.
3. Archive bytes referenced by expected_patch_file must live under
   docs/architecture, the existing verifier's allowed archive root. For a folder
   docs/architecture/owner-review-A, finalize manifest patch_file and proposal
   expected_patch_file as owner-review-A/NNN-protected.patch and pass
   --patches-dir docs/architecture to the signer. Do this before owner review;
   patch bytes/digests do not change. Default basenames alone cannot reference
   nested archives. Alternatively the existing full-index verifier supports
   exact direct-digest records without an archive-file reference.
4. Obtain authentic signing output and the existing independently verified
   owner's public key through the owner's established secure process. Use the
   same lowercase64hex public-key representation externally and in records;
   literal key identity is checked before cryptography. No new identity.
   tools/sign_owner_approvals.py accepts explicit --manifest and --patches-dir.
   Its --generate-payloads is unsigned; --sign is owner-side with the owner's
   secure key-file path. Expiry is calculated per invocation, so a separate
   preview's payload digest is not automatically the later signed payload digest.
5. Verify the signed candidate through the unchanged pinned verifier and new
   release consumer. Every protected path needs authentic approval, exact source,
   correct repository, future expiry and zero violations.
6. Keep the full-policy031-to-A scope distinct from a PR's actual merge-base
   diff. The original PR guard admits its registry from the trusted base.
   Candidate-only approval data will not satisfy that route. When protected
   baseline trees differ, review the proper diff rather than changing a base to
   hide hunks or assuming one signature covers both scopes.
7. Keep all Native/Release/production/freshness/data/SDK/binary and Apple
   acceptance requirements. Owner approval does not substitute for any of them.

No final manifest was generated, registry/status changed, key configured or
signature created. The trust task remains open for genuine owner material and
final-source acceptance.
