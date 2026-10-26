#!/usr/bin/env python3
"""
tools/test_upstream_boundary_security.py — Cryptographic Boundary Guard Security Test Suite
Exercises all 15 negative security conditions and 1 positive verification test,
verifying fail-closed enforcement of owner Ed25519 cryptographic attestations.
"""

import base64
from datetime import datetime, timezone, timedelta
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

REPO_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(REPO_DIR, "Scripts", "CI"))

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
import importlib.util

spec = importlib.util.spec_from_file_location("boundary_guard", os.path.join(REPO_DIR, "Scripts", "CI", "verify-upstream-boundary.py"))
bg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bg)

def run_security_tests():
    print("=" * 70)
    print("CHAVRUSATEXT BUILD 8401: UPSTREAM BOUNDARY SECURITY VERIFICATION SUITE")
    print("=" * 70)

    # Save original CI environment variables to allow fixture testing
    orig_ci = os.environ.get("CI")
    orig_gh = os.environ.get("GITHUB_ACTIONS")
    os.environ["CI"] = "false"
    os.environ["GITHUB_ACTIONS"] = "false"

    try:
        # Generate a dedicated NON-PRODUCTION test fixture Ed25519 key pair
        fixture_priv = Ed25519PrivateKey.generate()
        fixture_pub = fixture_priv.public_key()
        fixture_pub_bytes = fixture_pub.public_bytes_raw()
        fixture_pub_hex = fixture_pub_bytes.hex()

        # Generate an unauthorized attacker key pair
        attacker_priv = Ed25519PrivateKey.generate()
        attacker_pub = attacker_priv.public_key()
        attacker_pub_bytes = attacker_pub.public_bytes_raw()
        attacker_pub_hex = attacker_pub_bytes.hex()

        target_path = "Source/Features/Reader/ViewModel/ReaderViewModel.swift"
        base_commit = "031df35710ab2c6015efb1acd1e65154dbcd3f24"
        approval_id = "BUILD_8401_PATCH_05"
        future_expiry = (datetime.now(timezone.utc) + timedelta(days=90)).isoformat()
        past_expiry = (datetime.now(timezone.utc) - timedelta(days=5)).isoformat()

        # Resolve actual blob and diff for the target path
        code, head_blob, _ = bg.run_cmd(["git", "rev-parse", f"HEAD:{target_path}"], cwd=REPO_DIR)
        head_blob = head_blob.strip()
        assert code == 0 and head_blob

        code, diff_out, _ = bg.run_cmd(["git", "diff", base_commit, "HEAD", "--", target_path], cwd=REPO_DIR)
        diff_norm = diff_out.replace("\r\n", "\n")
        actual_diff_sha256 = hashlib.sha256(diff_norm.encode("utf-8")).hexdigest()

        # Canonical payload helper
        def sign_payload(priv_key, repo, path, base_sha, head_blob_sha, patch_sha256, app_id, exp_at):
            payload = bg.construct_canonical_attestation_payload(
                repo=repo,
                path=path,
                base_sha=base_sha,
                head_blob_sha=head_blob_sha,
                patch_sha256=patch_sha256,
                approval_id=app_id,
                expires_at=exp_at
            )
            sig = priv_key.sign(payload)
            return sig.hex(), payload

        valid_sig_hex, _ = sign_payload(
            fixture_priv, "davidpovarsky/Maktabah", target_path, base_commit,
            head_blob, actual_diff_sha256, approval_id, future_expiry
        )

        test_results = []

        def assert_test(name, expected_violation_type, run_fn):
            try:
                exit_code, report = run_fn()
                violations = report.get("violations", [])
                violation_types = [v.get("type") for v in violations]
                if expected_violation_type is None:
                    # Expect PASS
                    if exit_code == 0 and len(violations) == 0:
                        test_results.append((name, True, "PASS (Clean approval verified)"))
                        print(f"  [PASS] {name}")
                    else:
                        test_results.append((name, False, f"Expected PASS, got violations: {violation_types}"))
                        print(f"  [FAIL] {name}: Expected PASS, got {violation_types}")
                else:
                    if expected_violation_type in violation_types and exit_code != 0:
                        test_results.append((name, True, f"PASS (Correctly rejected with {expected_violation_type})"))
                        print(f"  [PASS] {name} -> {expected_violation_type}")
                    else:
                        test_results.append((name, False, f"Expected violation '{expected_violation_type}', got {violation_types} (exit={exit_code})"))
                        print(f"  [FAIL] {name}: Expected '{expected_violation_type}', got {violation_types}")
            except Exception as e:
                test_results.append((name, False, f"Exception: {str(e)}"))
                print(f"  [FAIL] {name}: Exception: {str(e)}")

        print("\n--- Running 15 Negative Security Tests ---")

        # Negative Test 1: Unsigned APPROVED status without attestation
        def test_unsigned_approved():
            custom_reg = {
                "exceptions": [{
                    "path": target_path,
                    "status": "APPROVED",
                    "owner_attestation": None
                }]
            }
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump(custom_reg, f)
                tname = f.name
            try:
                return bg.verify_boundaries(
                    base_ref=base_commit, head_ref="HEAD", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                    cwd=REPO_DIR, exception_register=tname, allow_unsafe_register=True, owner_public_key=fixture_pub_hex
                )
            finally:
                os.remove(tname)
        assert_test("Test 1: Unsigned APPROVED entry without attestation", "MISSING_OWNER_ATTESTATION", test_unsigned_approved)

        # Negative Test 2: Attestation signed by unauthorized key
        def test_unauthorized_key():
            sig_hex, _ = sign_payload(attacker_priv, "davidpovarsky/Maktabah", target_path, base_commit, head_blob, actual_diff_sha256, approval_id, future_expiry)
            custom_reg = {
                "exceptions": [{
                    "path": target_path,
                    "status": "APPROVED",
                    "expected_head_blob_sha": head_blob,
                    "patch_digest_sha256": actual_diff_sha256,
                    "owner_attestation": {
                        "signer_public_key": attacker_pub_hex,
                        "signature": sig_hex,
                        "base_sha": base_commit,
                        "expires_at": future_expiry
                    }
                }]
            }
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump(custom_reg, f)
                tname = f.name
            try:
                return bg.verify_boundaries(
                    base_ref=base_commit, head_ref="HEAD", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                    cwd=REPO_DIR, exception_register=tname, allow_unsafe_register=True, owner_public_key=fixture_pub_hex
                )
            finally:
                os.remove(tname)
        assert_test("Test 2: Attestation signed by unauthorized key", "UNAUTHORIZED_SIGNER_KEY", test_unauthorized_key)

        # Negative Test 3: Missing owner verification key configuration
        def test_missing_owner_key():
            custom_reg = {
                "exceptions": [{
                    "path": target_path,
                    "status": "APPROVED",
                    "expected_head_blob_sha": head_blob,
                    "patch_digest_sha256": actual_diff_sha256,
                    "owner_attestation": {
                        "signer_public_key": fixture_pub_hex,
                        "signature": valid_sig_hex,
                        "base_sha": base_commit,
                        "expires_at": future_expiry
                    }
                }]
            }
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump(custom_reg, f)
                tname = f.name
            try:
                old_env = os.environ.pop("MAKTABAH_OWNER_VERIFICATION_KEY", None)
                try:
                    return bg.verify_boundaries(
                        base_ref=base_commit, head_ref="HEAD", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                        cwd=REPO_DIR, exception_register=tname, allow_unsafe_register=True, owner_public_key=None
                    )
                finally:
                    if old_env: os.environ["MAKTABAH_OWNER_VERIFICATION_KEY"] = old_env
            finally:
                os.remove(tname)
        assert_test("Test 3: Missing owner key in policy configuration", "TRUST_GATE_BLOCKED_OWNER_CONFIGURATION", test_missing_owner_key)

        # Negative Test 4: Modified head blob SHA
        def test_modified_blob():
            wrong_blob = "0000000000000000000000000000000000000000"
            sig_hex, _ = sign_payload(fixture_priv, "davidpovarsky/Maktabah", target_path, base_commit, wrong_blob, actual_diff_sha256, approval_id, future_expiry)
            custom_reg = {
                "exceptions": [{
                    "path": target_path,
                    "status": "APPROVED",
                    "expected_head_blob_sha": wrong_blob,
                    "patch_digest_sha256": actual_diff_sha256,
                    "owner_attestation": {
                        "signer_public_key": fixture_pub_hex,
                        "signature": sig_hex,
                        "base_sha": base_commit,
                        "expected_head_blob_sha": wrong_blob,
                        "expires_at": future_expiry
                    }
                }]
            }
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump(custom_reg, f)
                tname = f.name
            try:
                return bg.verify_boundaries(
                    base_ref=base_commit, head_ref="HEAD", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                    cwd=REPO_DIR, exception_register=tname, allow_unsafe_register=True, owner_public_key=fixture_pub_hex
                )
            finally:
                os.remove(tname)
        assert_test("Test 4: Modified head blob SHA differs from actual", "UNAPPROVED_HUNK_DIFFERS_FROM_EXCEPTION", test_modified_blob)

        # Negative Test 5: Modified diff / hunk digest
        def test_modified_diff():
            wrong_digest = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
            sig_hex, _ = sign_payload(fixture_priv, "davidpovarsky/Maktabah", target_path, base_commit, head_blob, wrong_digest, approval_id, future_expiry)
            custom_reg = {
                "exceptions": [{
                    "path": target_path,
                    "status": "APPROVED",
                    "expected_head_blob_sha": head_blob,
                    "patch_digest_sha256": wrong_digest,
                    "owner_attestation": {
                        "signer_public_key": fixture_pub_hex,
                        "signature": sig_hex,
                        "base_sha": base_commit,
                        "patch_digest_sha256": wrong_digest,
                        "expires_at": future_expiry
                    }
                }]
            }
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump(custom_reg, f)
                tname = f.name
            try:
                return bg.verify_boundaries(
                    base_ref=base_commit, head_ref="HEAD", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                    cwd=REPO_DIR, exception_register=tname, allow_unsafe_register=True, owner_public_key=fixture_pub_hex
                )
            finally:
                os.remove(tname)
        assert_test("Test 5: Modified diff digest mismatch", "PATCH_DIGEST_MISMATCH", test_modified_diff)

        # Negative Test 6: Missing packaged patch file on disk
        def test_missing_patch_file():
            custom_reg = {
                "exceptions": [{
                    "path": target_path,
                    "status": "APPROVED",
                    "expected_head_blob_sha": head_blob,
                    "patch_digest_sha256": actual_diff_sha256,
                    "expected_patch_file": "nonexistent-patch-file.patch",
                    "owner_attestation": {
                        "signer_public_key": fixture_pub_hex,
                        "signature": valid_sig_hex,
                        "base_sha": base_commit,
                        "patch_digest_sha256": actual_diff_sha256,
                        "expires_at": future_expiry
                    }
                }]
            }
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump(custom_reg, f)
                tname = f.name
            try:
                return bg.verify_boundaries(
                    base_ref=base_commit, head_ref="HEAD", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                    cwd=REPO_DIR, exception_register=tname, allow_unsafe_register=True, owner_public_key=fixture_pub_hex
                )
            finally:
                os.remove(tname)
        assert_test("Test 6: Missing packaged patch file on disk", "PATCH_FILE_NOT_FOUND", test_missing_patch_file)

        # Negative Test 7: Expired attestation timestamp
        def test_expired_attestation():
            sig_hex, _ = sign_payload(fixture_priv, "davidpovarsky/Maktabah", target_path, base_commit, head_blob, actual_diff_sha256, approval_id, past_expiry)
            custom_reg = {
                "exceptions": [{
                    "path": target_path,
                    "status": "APPROVED",
                    "expected_head_blob_sha": head_blob,
                    "patch_digest_sha256": actual_diff_sha256,
                    "owner_attestation": {
                        "signer_public_key": fixture_pub_hex,
                        "signature": sig_hex,
                        "base_sha": base_commit,
                        "expires_at": past_expiry
                    }
                }]
            }
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump(custom_reg, f)
                tname = f.name
            try:
                return bg.verify_boundaries(
                    base_ref=base_commit, head_ref="HEAD", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                    cwd=REPO_DIR, exception_register=tname, allow_unsafe_register=True, owner_public_key=fixture_pub_hex
                )
            finally:
                os.remove(tname)
        assert_test("Test 7: Expired attestation timestamp", "ATTESTATION_EXPIRED", test_expired_attestation)

        # Negative Test 8: Swapped path / signature payload
        def test_swapped_path_sig():
            other_path = "Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift"
            sig_hex, _ = sign_payload(fixture_priv, "davidpovarsky/Maktabah", other_path, base_commit, head_blob, actual_diff_sha256, approval_id, future_expiry)
            custom_reg = {
                "exceptions": [{
                    "path": target_path,
                    "status": "APPROVED",
                    "expected_head_blob_sha": head_blob,
                    "patch_digest_sha256": actual_diff_sha256,
                    "owner_attestation": {
                        "signer_public_key": fixture_pub_hex,
                        "signature": sig_hex,
                        "base_sha": base_commit,
                        "expires_at": future_expiry
                    }
                }]
            }
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump(custom_reg, f)
                tname = f.name
            try:
                return bg.verify_boundaries(
                    base_ref=base_commit, head_ref="HEAD", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                    cwd=REPO_DIR, exception_register=tname, allow_unsafe_register=True, owner_public_key=fixture_pub_hex
                )
            finally:
                os.remove(tname)
        assert_test("Test 8: Swapped path in signature payload", "INVALID_CRYPTOGRAPHIC_SIGNATURE", test_swapped_path_sig)

        # Negative Test 9: Baseline commit mismatch
        def test_base_mismatch():
            wrong_base = "1111111111111111111111111111111111111111"
            sig_hex, _ = sign_payload(fixture_priv, "davidpovarsky/Maktabah", target_path, wrong_base, head_blob, actual_diff_sha256, approval_id, future_expiry)
            custom_reg = {
                "exceptions": [{
                    "path": target_path,
                    "status": "APPROVED",
                    "expected_head_blob_sha": head_blob,
                    "patch_digest_sha256": actual_diff_sha256,
                    "owner_attestation": {
                        "signer_public_key": fixture_pub_hex,
                        "signature": sig_hex,
                        "base_sha": wrong_base,
                        "expires_at": future_expiry
                    }
                }]
            }
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump(custom_reg, f)
                tname = f.name
            try:
                return bg.verify_boundaries(
                    base_ref=base_commit, head_ref="HEAD", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                    cwd=REPO_DIR, exception_register=tname, allow_unsafe_register=True, owner_public_key=fixture_pub_hex
                )
            finally:
                os.remove(tname)
        assert_test("Test 9: Baseline commit mismatch", "ATTESTATION_BASE_MISMATCH", test_base_mismatch)

        # Negative Test 10: Corrupted signature bytes
        def test_corrupted_signature():
            bad_sig = "ff" * 64
            custom_reg = {
                "exceptions": [{
                    "path": target_path,
                    "status": "APPROVED",
                    "expected_head_blob_sha": head_blob,
                    "patch_digest_sha256": actual_diff_sha256,
                    "owner_attestation": {
                        "signer_public_key": fixture_pub_hex,
                        "signature": bad_sig,
                        "base_sha": base_commit,
                        "expires_at": future_expiry
                    }
                }]
            }
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump(custom_reg, f)
                tname = f.name
            try:
                return bg.verify_boundaries(
                    base_ref=base_commit, head_ref="HEAD", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                    cwd=REPO_DIR, exception_register=tname, allow_unsafe_register=True, owner_public_key=fixture_pub_hex
                )
            finally:
                os.remove(tname)
        assert_test("Test 10: Corrupted signature bytes", "INVALID_CRYPTOGRAPHIC_SIGNATURE", test_corrupted_signature)

        # Negative Test 11: Production CI forbids --allow-unsafe-register
        def test_prod_ci_forbids_unsafe():
            os.environ["CI"] = "true"
            try:
                return bg.verify_boundaries(
                    base_ref=base_commit, head_ref="HEAD", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                    cwd=REPO_DIR, allow_unsafe_register=True, owner_public_key=fixture_pub_hex
                )
            finally:
                os.environ["CI"] = "false"
        assert_test("Test 11: Production CI strictly forbids --allow-unsafe-register", "PROD_CI_FORBIDS_UNSAFE_REGISTER", test_prod_ci_forbids_unsafe)

        # Negative Test 12: Zero-commit scan (base == head) does not prove boundary integrity
        def test_same_base_head():
            return bg.verify_boundaries(
                base_ref="HEAD", head_ref="HEAD", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                cwd=REPO_DIR, owner_public_key=fixture_pub_hex
            )
        assert_test("Test 12: Zero-commit scan base == head rejected", "SAME_BASE_AND_HEAD_NOT_PROOF", test_same_base_head)

        # Negative Test 13: Protected upstream modification without exception entry
        def test_unapproved_modification():
            custom_reg = {"exceptions": []}
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump(custom_reg, f)
                tname = f.name
            try:
                return bg.verify_boundaries(
                    base_ref=base_commit, head_ref="HEAD", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                    cwd=REPO_DIR, exception_register=tname, allow_unsafe_register=True, owner_public_key=fixture_pub_hex
                )
            finally:
                os.remove(tname)
        assert_test("Test 13: Protected upstream modification without exception entry", "UNAUTHORIZED_UPSTREAM_MODIFICATION", test_unapproved_modification)

        # Negative Test 14: Protected namespace pollution (new unapproved file in protected namespace)
        def test_namespace_pollution():
            polluting_path = "Source/Features/UnapprovedPollution.swift"
            full_path = os.path.join(REPO_DIR, polluting_path)
            with open(full_path, "w", encoding="utf-8") as f:
                f.write("// unapproved namespace pollution\n")
            try:
                return bg.verify_boundaries(
                    base_ref=base_commit, head_ref="WORKTREE", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                    cwd=REPO_DIR, owner_public_key=fixture_pub_hex
                )
            finally:
                if os.path.exists(full_path):
                    os.remove(full_path)
        assert_test("Test 14: Protected namespace pollution rejected", "PROTECTED_NAMESPACE_POLLUTION", test_namespace_pollution)

        # Negative Test 15: Unauthorized policy bypass attempt
        def test_policy_bypass():
            # Modify a policy enforcement file in worktree
            policy_path = os.path.join(REPO_DIR, "docs/architecture/UPSTREAM_INTEGRITY_POLICY.md")
            with open(policy_path, "r", encoding="utf-8") as f:
                orig_content = f.read()
            try:
                with open(policy_path, "a", encoding="utf-8") as f:
                    f.write("\n<!-- unauthorized bypass edit -->\n")
                return bg.verify_boundaries(
                    base_ref=base_commit, head_ref="WORKTREE", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                    cwd=REPO_DIR, owner_public_key=fixture_pub_hex
                )
            finally:
                with open(policy_path, "w", encoding="utf-8") as f:
                    f.write(orig_content)
        assert_test("Test 15: Policy bypass via coupled policy file modification", "UNAUTHORIZED_POLICY_BYPASS_ATTEMPT", test_policy_bypass)

        print("\n--- Running 1 Positive Verification Test ---")

        # Positive Test 16: Complete 14-hunk validly signed fixture passes verification
        def test_positive_14_hunk_approval():
            manifest_path = os.path.join(REPO_DIR, "docs", "architecture", "BUILD_8401_REPRODUCIBLE_PAYLOAD_MANIFEST.json")
            with open(manifest_path, "r", encoding="utf-8") as f:
                manifest = json.load(f)

            signed_exceptions = []
            for patch in manifest["patches"]:
                p_path = patch["path"]
                p_blob = patch["head_blob_sha"]
                p_diff_sha = patch["patch_digest_sha256"]
                p_id = patch["patch_id"]
                p_file = patch["patch_file"]

                sig, _ = sign_payload(fixture_priv, "davidpovarsky/Maktabah", p_path, base_commit, p_blob, p_diff_sha, p_id, future_expiry)
                signed_exceptions.append({
                    "patch_id": p_id,
                    "path": p_path,
                    "status": "APPROVED",
                    "approval_ref": f"BUILD_8401_APPROVAL_PACKAGE.md#{p_id.lower()}",
                    "expected_patch_file": p_file,
                    "expected_head_blob_sha": p_blob,
                    "patch_digest_sha256": p_diff_sha,
                    "owner_attestation": {
                        "signer_public_key": fixture_pub_hex,
                        "signature": sig,
                        "base_sha": base_commit,
                        "expected_head_blob_sha": p_blob,
                        "patch_digest_sha256": p_diff_sha,
                        "expires_at": future_expiry,
                        "repo": "davidpovarsky/Maktabah",
                        "approval_id": p_id
                    }
                })

            positive_reg = {
                "schema_version": "1.2.0",
                "baseline_commit": base_commit,
                "upstream_pinned_sha": "a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                "exceptions": signed_exceptions
            }

            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump(positive_reg, f)
                tname = f.name
            try:
                return bg.verify_boundaries(
                    base_ref=base_commit, head_ref="HEAD", upstream_ref="a0ed0df908a6cb38bc459d4baaeb400f447b2fc4",
                    cwd=REPO_DIR, exception_register=tname, allow_unsafe_register=True, owner_public_key=fixture_pub_hex
                )
            finally:
                os.remove(tname)
        assert_test("Test 16: Complete 14-hunk genuine fixture verification", None, test_positive_14_hunk_approval)

        print("\n" + "=" * 70)
        print("SUMMARY OF BOUNDARY SECURITY VERIFICATION")
        print("=" * 70)
        all_passed = all(passed for _, passed, _ in test_results)
        print(f"Total Security Tests Executed: {len(test_results)}")
        print(f"Passed: {sum(1 for _, p, _ in test_results if p)}")
        print(f"Failed: {sum(1 for _, p, _ in test_results if not p)}")

        if not all_passed:
            print("\n[CRITICAL FAILURE] Some security tests failed!")
            sys.exit(1)
        else:
            print("\n[VERIFIED] All 15 negative conditions and 1 positive test passed fail-closed requirements!")

    finally:
        # Restore environment variables
        if orig_ci is not None:
            os.environ["CI"] = orig_ci
        else:
            os.environ.pop("CI", None)
        if orig_gh is not None:
            os.environ["GITHUB_ACTIONS"] = orig_gh
        else:
            os.environ.pop("GITHUB_ACTIONS", None)

if __name__ == "__main__":
    run_security_tests()
