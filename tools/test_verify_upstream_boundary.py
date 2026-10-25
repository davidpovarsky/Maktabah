#!/usr/bin/env python3
"""
test_verify_upstream_boundary.py — Hardened Fixture Tests for Upstream Boundary Guard (PASS 4)
Validates failure-mode resistance across all adversarial scenarios, including committed edits
with clean worktree, staged/unstaged, rename tricks, non-ASCII Unicode, invalid references,
Ed25519 cryptographic identity verification, unconfigured owner key fail-closed state,
tampered signatures, unauthorized keys, expired attestations, and CI unsafe-flag blocking.
"""

import base64
import datetime
import json
import os
import subprocess
import sys
import tempfile

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

def run_cmd(cmd, cwd, env=None):
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    res = subprocess.run(
        cmd,
        cwd=cwd,
        env=merged_env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace"
    )
    return res.returncode, res.stdout, res.stderr

def main():
    print("=== Running Upstream Boundary Guard Fixture Tests (Pass 4 Hardened) ===")
    checker_path = os.path.abspath(r"C:\Users\DAVID\Code\Maktabah-v42-integration\Scripts\CI\verify-upstream-boundary.py")

    test_results = []

    # Generate test Ed25519 keypair for cryptographic fixtures
    test_private_key = Ed25519PrivateKey.generate()
    test_pub_bytes = test_private_key.public_key().public_bytes_raw()
    test_pub_hex = test_pub_bytes.hex()

    # Generate second keypair for unauthorized signer tests
    unauthorized_private_key = Ed25519PrivateKey.generate()
    unauthorized_pub_hex = unauthorized_private_key.public_key().public_bytes_raw().hex()

    with tempfile.TemporaryDirectory() as tmpdir:
        def git(*args):
            c, o, e = run_cmd(["git"] + list(args), cwd=tmpdir)
            if c != 0:
                raise RuntimeError(f"Git failed: {e}")
            return o.strip()

        git("init", "-b", "main")
        git("config", "user.name", "Test Agent")
        git("config", "user.email", "agent@test.local")
        git("config", "core.quotePath", "false")

        # 0. Upstream Baseline Commit
        os.makedirs(os.path.join(tmpdir, "Source", "Core"), exist_ok=True)
        os.makedirs(os.path.join(tmpdir, "Source", "Features", "Reader", "iOS"), exist_ok=True)
        os.makedirs(os.path.join(tmpdir, "Source", "ChavrusaText", "ReaderHost"), exist_ok=True)
        os.makedirs(os.path.join(tmpdir, "Scripts", "CI"), exist_ok=True)
        os.makedirs(os.path.join(tmpdir, "docs", "architecture"), exist_ok=True)

        with open(os.path.join(tmpdir, "Source", "Core", "UpstreamFile.swift"), "w", encoding="utf-8") as f:
            f.write("// Original upstream file\n")
        with open(os.path.join(tmpdir, "Source", "Features", "Reader", "iOS", "iOSReaderView.swift"), "w", encoding="utf-8") as f:
            f.write("// Original reader view\n")
        with open(os.path.join(tmpdir, "Scripts", "CI", "verify-upstream-boundary.py"), "w", encoding="utf-8") as f:
            with open(checker_path, "r", encoding="utf-8") as src_f:
                f.write(src_f.read())
        with open(os.path.join(tmpdir, "docs", "architecture", "UPSTREAM_INTEGRITY_POLICY.md"), "w", encoding="utf-8") as f:
            f.write("# Upstream policy\n")

        git("add", ".")
        git("commit", "-m", "Initial upstream commit")
        upstream_sha = git("rev-parse", "HEAD")

        # Fork Baseline with pre-existing legacy difference
        with open(os.path.join(tmpdir, "Source", "Core", "UpstreamFile.swift"), "a", encoding="utf-8") as f:
            f.write("// Legacy edit prior to audit\n")
        git("add", ".")
        git("commit", "-m", "Fork baseline with legacy debt")
        baseline_sha = git("rev-parse", "HEAD")

        # --- P3-1 REGRESSION TEST: Committed upstream edit with CLEAN worktree ---
        with open(os.path.join(tmpdir, "Source", "Core", "UpstreamFile.swift"), "a", encoding="utf-8") as f:
            f.write("// Unauthorized committed upstream modification\n")
        git("add", ".")
        git("commit", "-m", "Unauthorized committed upstream change")
        committed_bad_head = git("rev-parse", "HEAD")

        # Subtest A: Using default WORKTREE mode with clean working tree
        report_json_path = os.path.join(tmpdir, "report_p3_1.json")
        c, o, e = run_cmd(["python", checker_path, "--base", baseline_sha, "--upstream-ref", upstream_sha, "--report-json", report_json_path], cwd=tmpdir)
        has_committed_violation = False
        if os.path.exists(report_json_path):
            with open(report_json_path, "r", encoding="utf-8") as jf:
                rep = json.load(jf)
                has_committed_violation = any(v.get("type") == "UNAUTHORIZED_UPSTREAM_MODIFICATION" and v.get("provenance") == "COMMITTED" for v in rep.get("violations", []))
        test_results.append(("P3-1. Committed upstream modification with clean worktree -> FAIL (COMMITTED)", c == 1 and has_committed_violation))

        # Subtest B: Using explicit --head HEAD
        c, o, e = run_cmd(["python", checker_path, "--base", baseline_sha, "--head", committed_bad_head, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("P3-1. Committed upstream modification with --head HEAD -> FAIL", c == 1 and "UNAUTHORIZED_UPSTREAM_MODIFICATION" in o))

        # Reset back to clean baseline for subsequent fixture tests
        git("reset", "--hard", baseline_sha)
        git("clean", "-fd")

        # Test 1: Untracked nested protected Swift file -> FAIL
        nested_file = os.path.join(tmpdir, "Source", "Core", "UntrackedInCore.swift")
        with open(nested_file, "w", encoding="utf-8") as f:
            f.write("// Unauthorized untracked file\n")
        c, o, e = run_cmd(["python", checker_path, "--base", baseline_sha, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("1. Untracked nested protected file -> FAIL", c == 1 and "PROTECTED_NAMESPACE_POLLUTION" in o))
        os.remove(nested_file)

        # Test 2: Untracked fork-only file -> PASS
        fork_file = os.path.join(tmpdir, "Source", "ChavrusaText", "ReaderHost", "NewHost.swift")
        os.makedirs(os.path.dirname(fork_file), exist_ok=True)
        with open(fork_file, "w", encoding="utf-8") as f:
            f.write("// Authorized fork-owned file\n")
        c, o, e = run_cmd(["python", checker_path, "--base", baseline_sha, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("2. Untracked fork-only file -> PASS", c == 0))
        os.remove(fork_file)

        # Test 3: Tracked protected modification -> FAIL
        with open(os.path.join(tmpdir, "Source", "Core", "UpstreamFile.swift"), "a", encoding="utf-8") as f:
            f.write("// New unauthorized modification\n")
        c, o, e = run_cmd(["python", checker_path, "--base", baseline_sha, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("3. Tracked protected modification -> FAIL", c == 1 and "UNAUTHORIZED_UPSTREAM_MODIFICATION" in o))
        git("checkout", "--", "Source/Core/UpstreamFile.swift")

        # Test 4: Index-only staged edit -> FAIL
        with open(os.path.join(tmpdir, "Source", "Core", "UpstreamFile.swift"), "a", encoding="utf-8") as f:
            f.write("// Staged modification\n")
        git("add", "Source/Core/UpstreamFile.swift")
        c, o, e = run_cmd(["python", checker_path, "--base", baseline_sha, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("4. Index-only staged edit -> FAIL", c == 1 and "UNAUTHORIZED_UPSTREAM_MODIFICATION" in o))
        git("reset", "--hard", baseline_sha)

        # Test 5: Unstaged edit -> FAIL
        with open(os.path.join(tmpdir, "Source", "Features", "Reader", "iOS", "iOSReaderView.swift"), "a", encoding="utf-8") as f:
            f.write("// Unstaged modification\n")
        c, o, e = run_cmd(["python", checker_path, "--base", baseline_sha, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("5. Unstaged edit -> FAIL", c == 1 and "UNAUTHORIZED_UPSTREAM_MODIFICATION" in o))
        git("checkout", "--", "Source/Features/Reader/iOS/iOSReaderView.swift")

        # Test 6: Protected deletion / rename trick -> FAIL
        git("rm", "Source/Features/Reader/iOS/iOSReaderView.swift")
        os.makedirs(os.path.join(tmpdir, "Source", "Features", "Reader", "iOS"), exist_ok=True)
        with open(os.path.join(tmpdir, "Source", "Features", "Reader", "iOS", "RenamedReaderView.swift"), "w", encoding="utf-8") as f:
            f.write("// Disguised rename\n")
        c, o, e = run_cmd(["python", checker_path, "--base", baseline_sha, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("6. Protected deletion / rename trick -> FAIL", c == 1 and "UPSTREAM_FILE_DELETED" in o))
        git("reset", "--hard", baseline_sha)
        git("clean", "-fd")

        # Test 7: Paths with spaces and non-ASCII Hebrew characters -> Handles cleanly without crash
        hebrew_dir = os.path.join(tmpdir, "Source", "ChavrusaText", "בדיקה רווחים")
        os.makedirs(hebrew_dir, exist_ok=True)
        hebrew_file = os.path.join(hebrew_dir, "קובץ בדיקה.swift")
        with open(hebrew_file, "w", encoding="utf-8") as f:
            f.write("// Unicode test\n")
        c, o, e = run_cmd(["python", checker_path, "--base", baseline_sha, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("7. Non-ASCII Hebrew and spaces in fork path -> PASS without crash", c == 0))
        os.remove(hebrew_file)
        os.rmdir(hebrew_dir)

        # Test 8: Historical divergence unchanged -> PASS
        c, o, e = run_cmd(["python", checker_path, "--base", baseline_sha, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("8. Historical divergence unchanged -> PASS", c == 0))

        # Test 9: Modified guard + protected code (bypass attempt) -> FAIL
        with open(os.path.join(tmpdir, "Scripts", "CI", "verify-upstream-boundary.py"), "a", encoding="utf-8") as f:
            f.write("\n# Bypass modification\n")
        with open(os.path.join(tmpdir, "Source", "Core", "UpstreamFile.swift"), "a", encoding="utf-8") as f:
            f.write("// Coupled modification\n")
        c, o, e = run_cmd(["python", checker_path, "--base", baseline_sha, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("9. Guard file modified together with protected code -> FAIL (Bypass detected)", c == 1 and "UNAUTHORIZED_POLICY_BYPASS_ATTEMPT" in o))
        git("reset", "--hard", baseline_sha)

        # Test 10: Nonexistent refs -> FAIL with exit code 2
        c, o, e = run_cmd(["python", checker_path, "--base", "nonexistent_ref_12345", "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("10. Nonexistent base ref -> exit code 2", c == 2))

        c2, o2, e2 = run_cmd(["python", checker_path, "--base", baseline_sha, "--upstream-ref", "nonexistent_upstream_54321"], cwd=tmpdir)
        test_results.append(("11. Nonexistent upstream ref -> exit code 2", c2 == 2))

        # --- BATCH B CRYPTOGRAPHIC FIXTURES (Ed25519 & Trust Gates) ---

        good_content = "// Original upstream file\n// Approved hunk\n"
        with open(os.path.join(tmpdir, "Source", "Core", "UpstreamFile.swift"), "w", encoding="utf-8") as f:
            f.write(good_content)
        good_blob = git("hash-object", "Source/Core/UpstreamFile.swift")
        diff_cmd = ["git", "diff", baseline_sha, "HEAD", "--", "Source/Core/UpstreamFile.swift"]
        _, d_out, _ = run_cmd(diff_cmd, cwd=tmpdir)
        import hashlib
        diff_sha = hashlib.sha256(d_out.replace("\r\n", "\n").encode("utf-8")).hexdigest()

        # Import helper from checker
        import sys
        sys.path.insert(0, os.path.dirname(checker_path))
        from importlib.machinery import SourceFileLoader
        checker_mod = SourceFileLoader("checker", checker_path).load_module()

        valid_expiry = "2030-12-31T23:59:59Z"
        canonical_payload = checker_mod.construct_canonical_attestation_payload(
            repo="davidpovarsky/Maktabah",
            path="Source/Core/UpstreamFile.swift",
            base_sha=baseline_sha,
            head_blob_sha=good_blob,
            patch_sha256=diff_sha,
            approval_id="REF-TEST-01",
            expires_at=valid_expiry
        )
        valid_signature = test_private_key.sign(canonical_payload).hex()

        reg_data_crypto = {
            "version": 1,
            "baseline_sha": baseline_sha,
            "exceptions": [
                {
                    "path": "Source/Core/UpstreamFile.swift",
                    "status": "APPROVED",
                    "approval_ref": "REF-TEST-01",
                    "expected_head_blob_sha": good_blob,
                    "owner_attestation": {
                        "repo": "davidpovarsky/Maktabah",
                        "base_sha": baseline_sha,
                        "signer_public_key": test_pub_hex,
                        "signature": valid_signature,
                        "expires_at": valid_expiry,
                        "expected_head_blob_sha": good_blob,
                        "patch_digest_sha256": diff_sha
                    }
                }
            ]
        }
        with open(os.path.join(tmpdir, "docs", "architecture", "UPSTREAM_EXCEPTION_REGISTER.json"), "w", encoding="utf-8") as f:
            json.dump(reg_data_crypto, f, indent=2)
        git("add", "docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json")
        git("commit", "-m", "Add cryptographically approved register to base")
        base_with_crypto_reg = git("rev-parse", "HEAD")

        # Test 12a: Valid Ed25519 signature + configured test owner key -> PASS
        c, o, e = run_cmd(["python", checker_path, "--base", base_with_crypto_reg, "--upstream-ref", upstream_sha, "--owner-public-key", test_pub_hex], cwd=tmpdir)
        test_results.append(("12a. Valid Ed25519 signature with configured test key -> PASS (APPROVED_UPSTREAM_EXCEPTION)", c == 0 and "APPROVED_UPSTREAM_EXCEPTION" in o))

        # Test 12b: Approved file with unexpected extra hunk -> FAIL
        with open(os.path.join(tmpdir, "Source", "Core", "UpstreamFile.swift"), "a", encoding="utf-8") as f:
            f.write("// Unexpected extra hunk\n")
        c, o, e = run_cmd(["python", checker_path, "--base", base_with_crypto_reg, "--upstream-ref", upstream_sha, "--owner-public-key", test_pub_hex], cwd=tmpdir)
        test_results.append(("12b. Unexpected extra hunk on approved file -> FAIL (UNAPPROVED_HUNK_DIFFERS_FROM_EXCEPTION)", c == 1 and "UNAPPROVED_HUNK_DIFFERS_FROM_EXCEPTION" in o))
        git("reset", "--hard", base_with_crypto_reg)

        # Test 12c: Owner key unconfigured in policy/env -> FAIL (TRUST_GATE_BLOCKED_OWNER_CONFIGURATION)
        with open(os.path.join(tmpdir, "Source", "Core", "UpstreamFile.swift"), "w", encoding="utf-8") as f:
            f.write(good_content)
        env_no_key = os.environ.copy()
        env_no_key.pop("MAKTABAH_OWNER_VERIFICATION_KEY", None)
        c, o, e = run_cmd(["python", checker_path, "--base", base_with_crypto_reg, "--upstream-ref", upstream_sha], cwd=tmpdir, env=env_no_key)
        test_results.append(("12c. Owner key unconfigured in environment -> FAIL (TRUST_GATE_BLOCKED_OWNER_CONFIGURATION)", c == 1 and "TRUST_GATE_BLOCKED_OWNER_CONFIGURATION" in o))

        # Test 12d: Corrupted / invalid Ed25519 signature -> FAIL (INVALID_CRYPTOGRAPHIC_SIGNATURE)
        bad_sig = "ff" * 64
        corrupted_reg = json.loads(json.dumps(reg_data_crypto))
        corrupted_reg["exceptions"][0]["owner_attestation"]["signature"] = bad_sig
        with open(os.path.join(tmpdir, "docs", "architecture", "UPSTREAM_EXCEPTION_REGISTER.json"), "w", encoding="utf-8") as f:
            json.dump(corrupted_reg, f, indent=2)
        git("add", "docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json")
        git("commit", "-m", "Register with corrupted signature")
        base_corrupted_sig = git("rev-parse", "HEAD")

        c, o, e = run_cmd(["python", checker_path, "--base", base_corrupted_sig, "--upstream-ref", upstream_sha, "--owner-public-key", test_pub_hex], cwd=tmpdir)
        test_results.append(("12d. Corrupted cryptographic signature -> FAIL (INVALID_CRYPTOGRAPHIC_SIGNATURE)", c == 1 and "INVALID_CRYPTOGRAPHIC_SIGNATURE" in o))
        git("reset", "--hard", base_with_crypto_reg)

        # Test 12e: Signature from unauthorized signer key -> FAIL (UNAUTHORIZED_SIGNER_KEY)
        unauth_sig = unauthorized_private_key.sign(canonical_payload).hex()
        unauth_reg = json.loads(json.dumps(reg_data_crypto))
        unauth_reg["exceptions"][0]["owner_attestation"]["signer_public_key"] = unauthorized_pub_hex
        unauth_reg["exceptions"][0]["owner_attestation"]["signature"] = unauth_sig
        with open(os.path.join(tmpdir, "docs", "architecture", "UPSTREAM_EXCEPTION_REGISTER.json"), "w", encoding="utf-8") as f:
            json.dump(unauth_reg, f, indent=2)
        git("add", "docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json")
        git("commit", "-m", "Register with unauthorized signer")
        base_unauth_reg = git("rev-parse", "HEAD")

        with open(os.path.join(tmpdir, "Source", "Core", "UpstreamFile.swift"), "w", encoding="utf-8") as f:
            f.write(good_content)
        c, o, e = run_cmd(["python", checker_path, "--base", base_unauth_reg, "--upstream-ref", upstream_sha, "--owner-public-key", test_pub_hex], cwd=tmpdir)
        test_results.append(("12e. Unauthorized signer key -> FAIL (UNAUTHORIZED_SIGNER_KEY)", c == 1 and "UNAUTHORIZED_SIGNER_KEY" in o))
        git("reset", "--hard", base_with_crypto_reg)

        # Test 12f: Expired attestation -> FAIL (ATTESTATION_EXPIRED)
        expired_reg = json.loads(json.dumps(reg_data_crypto))
        expired_date = "2020-01-01T00:00:00Z"
        expired_payload = checker_mod.construct_canonical_attestation_payload(
            repo="davidpovarsky/Maktabah",
            path="Source/Core/UpstreamFile.swift",
            base_sha=baseline_sha,
            head_blob_sha=good_blob,
            patch_sha256=diff_sha,
            approval_id="REF-TEST-01",
            expires_at=expired_date
        )
        expired_sig = test_private_key.sign(expired_payload).hex()
        expired_reg["exceptions"][0]["owner_attestation"]["expires_at"] = expired_date
        expired_reg["exceptions"][0]["owner_attestation"]["signature"] = expired_sig
        with open(os.path.join(tmpdir, "docs", "architecture", "UPSTREAM_EXCEPTION_REGISTER.json"), "w", encoding="utf-8") as f:
            json.dump(expired_reg, f, indent=2)
        git("add", "docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json")
        git("commit", "-m", "Register with expired attestation")
        base_expired_reg = git("rev-parse", "HEAD")

        with open(os.path.join(tmpdir, "Source", "Core", "UpstreamFile.swift"), "w", encoding="utf-8") as f:
            f.write(good_content)
        c, o, e = run_cmd(["python", checker_path, "--base", base_expired_reg, "--upstream-ref", upstream_sha, "--owner-public-key", test_pub_hex], cwd=tmpdir)
        test_results.append(("12f. Expired attestation -> FAIL (ATTESTATION_EXPIRED)", c == 1 and "ATTESTATION_EXPIRED" in o))
        git("reset", "--hard", base_with_crypto_reg)

        # Test 12g: Production CI environment strictly forbids --allow-unsafe-register -> FAIL (PROD_CI_FORBIDS_UNSAFE_REGISTER)
        ci_env = os.environ.copy()
        ci_env["CI"] = "true"
        c, o, e = run_cmd(["python", checker_path, "--base", base_with_crypto_reg, "--upstream-ref", upstream_sha, "--allow-unsafe-register"], cwd=tmpdir, env=ci_env)
        test_results.append(("12g. Production CI forbids --allow-unsafe-register -> FAIL (PROD_CI_FORBIDS_UNSAFE_REGISTER)", c == 1 and "PROD_CI_FORBIDS_UNSAFE_REGISTER" in o))

        # Test 13: Untrusted branch modifies exception register and protected code together -> FAIL (Coupled Bypass)
        with open(os.path.join(tmpdir, "docs", "architecture", "UPSTREAM_EXCEPTION_REGISTER.json"), "a", encoding="utf-8") as f:
            f.write("\n// bypass comment\n")
        with open(os.path.join(tmpdir, "Source", "Features", "Reader", "iOS", "iOSReaderView.swift"), "a", encoding="utf-8") as f:
            f.write("// Unauthorized modification\n")
        c, o, e = run_cmd(["python", checker_path, "--base", base_with_crypto_reg, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("13. Modified approval register + source in same untrusted PR -> FAIL (Coupled Bypass)", c == 1 and "UNAUTHORIZED_POLICY_BYPASS_ATTEMPT" in o))
        git("reset", "--hard", base_with_crypto_reg)
        git("clean", "-fd")

        # Test 14: Pushed branch with zero before SHA -> fallback to configured baseline
        os.environ["MAKTABAH_BASELINE_SHA"] = base_with_crypto_reg
        c, o, e = run_cmd(["python", checker_path, "--base", "0000000000000000000000000000000000000000", "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("14. Pushed branch with zero before SHA -> fallback to baseline and PASS", c == 0))
        del os.environ["MAKTABAH_BASELINE_SHA"]

        # Test 15: PR with trusted base SHA and clean fork additions -> PASS
        git("checkout", "-b", "feature-branch")
        fork_feat_file = os.path.join(tmpdir, "Source", "ChavrusaText", "Feature.swift")
        os.makedirs(os.path.dirname(fork_feat_file), exist_ok=True)
        with open(fork_feat_file, "w", encoding="utf-8") as f:
            f.write("// Feature in fork namespace\n")
        git("add", ".")
        git("commit", "-m", "Clean fork feature")
        pr_head_sha = git("rev-parse", "HEAD")
        c, o, e = run_cmd(["python", checker_path, "--base", base_with_crypto_reg, "--head", pr_head_sha, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("15. PR with trusted base SHA -> PASS", c == 0))

        # Test 16: workflow_dispatch with custom approved base -> PASS
        c, o, e = run_cmd(["python", checker_path, "--base", baseline_sha, "--head", pr_head_sha, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("16. workflow_dispatch with custom approved base -> PASS", c == 0))

        # Test 17: Unapproved proposal in OWNER_APPROVAL_REQUIRED state fails closed
        unapproved_reg = {
            "version": 1,
            "baseline_sha": base_with_crypto_reg,
            "exceptions": [
                {
                    "path": "Source/Features/Reader/iOS/iOSReaderView.swift",
                    "status": "OWNER_APPROVAL_REQUIRED",
                    "approval_ref": "REF-PENDING-01",
                    "description": "Proposal pending owner approval"
                }
            ]
        }
        with open(os.path.join(tmpdir, "docs", "architecture", "UPSTREAM_EXCEPTION_REGISTER.json"), "w", encoding="utf-8") as f:
            json.dump(unapproved_reg, f, indent=2)
        git("add", "docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json")
        git("commit", "-m", "Register with OWNER_APPROVAL_REQUIRED")
        base_pending_reg = git("rev-parse", "HEAD")

        with open(os.path.join(tmpdir, "Source", "Features", "Reader", "iOS", "iOSReaderView.swift"), "a", encoding="utf-8") as f:
            f.write("// Edit pending owner approval\n")
        c, o, e = run_cmd(["python", checker_path, "--base", base_pending_reg, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("17. Unapproved proposal in OWNER_APPROVAL_REQUIRED state -> FAIL (PENDING_UPSTREAM_APPROVAL)", c == 1 and "PENDING_UPSTREAM_APPROVAL" in o))
        git("reset", "--hard", base_pending_reg)
        git("clean", "-fd")

        # Test 18: Agent-created JSON APPROVED with matching blob but NO owner_attestation -> FAIL (MISSING_OWNER_ATTESTATION)
        agent_fake_reg = {
            "version": 1,
            "baseline_sha": base_pending_reg,
            "exceptions": [
                {
                    "path": "Source/Features/Reader/iOS/iOSReaderView.swift",
                    "status": "APPROVED",
                    "approval_ref": "SELF_APPROVAL_BYPASS",
                    "expected_head_blob_sha": good_blob
                }
            ]
        }
        with open(os.path.join(tmpdir, "docs", "architecture", "UPSTREAM_EXCEPTION_REGISTER.json"), "w", encoding="utf-8") as f:
            json.dump(agent_fake_reg, f, indent=2)
        git("add", "docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json")
        git("commit", "-m", "Register with unverified APPROVED status")
        base_fake_approved = git("rev-parse", "HEAD")

        with open(os.path.join(tmpdir, "Source", "Features", "Reader", "iOS", "iOSReaderView.swift"), "w", encoding="utf-8") as f:
            f.write(good_content)
        c, o, e = run_cmd(["python", checker_path, "--base", base_fake_approved, "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("18. Agent-created APPROVED without owner attestation -> FAIL (MISSING_OWNER_ATTESTATION)", c == 1 and "MISSING_OWNER_ATTESTATION" in o))
        git("reset", "--hard", base_fake_approved)

        # Test 19: Forged approval with owner_attestation missing signature/signer -> FAIL (MISSING_OWNER_SIGNATURE)
        unsigned_reg = {
            "version": 1,
            "baseline_sha": base_fake_approved,
            "exceptions": [
                {
                    "path": "Source/Features/Reader/iOS/iOSReaderView.swift",
                    "status": "APPROVED",
                    "approval_ref": "FORGED_NO_SIGNATURE",
                    "expected_head_blob_sha": good_blob,
                    "owner_attestation": {
                        "base_sha": base_fake_approved,
                        "expected_head_blob_sha": good_blob
                    }
                }
            ]
        }
        with open(os.path.join(tmpdir, "docs", "architecture", "UPSTREAM_EXCEPTION_REGISTER.json"), "w", encoding="utf-8") as f:
            json.dump(unsigned_reg, f, indent=2)
        git("add", "docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json")
        git("commit", "-m", "Register with unsigned attestation")
        base_unsigned_reg = git("rev-parse", "HEAD")

        with open(os.path.join(tmpdir, "Source", "Features", "Reader", "iOS", "iOSReaderView.swift"), "w", encoding="utf-8") as f:
            f.write(good_content)
        c, o, e = run_cmd(["python", checker_path, "--base", base_unsigned_reg, "--upstream-ref", upstream_sha, "--owner-public-key", test_pub_hex], cwd=tmpdir)
        test_results.append(("19. Forged attestation missing signature/signer -> FAIL (MISSING_OWNER_SIGNATURE)", c == 1 and "MISSING_OWNER_SIGNATURE" in o))
        git("reset", "--hard", base_unsigned_reg)

        # Test 20: Old approved artifact at wrong base (stale attestation base_sha mismatch) -> FAIL (ATTESTATION_BASE_MISMATCH)
        stale_base_reg = {
            "version": 1,
            "baseline_sha": "old_base_commit_sha_12345",
            "exceptions": [
                {
                    "path": "Source/Features/Reader/iOS/iOSReaderView.swift",
                    "status": "APPROVED",
                    "approval_ref": "STALE_BASE",
                    "expected_head_blob_sha": good_blob,
                    "owner_attestation": {
                        "base_sha": "old_base_commit_sha_12345",
                        "signer_public_key": test_pub_hex,
                        "signature": valid_signature,
                        "expected_head_blob_sha": good_blob
                    }
                }
            ]
        }
        with open(os.path.join(tmpdir, "docs", "architecture", "UPSTREAM_EXCEPTION_REGISTER.json"), "w", encoding="utf-8") as f:
            json.dump(stale_base_reg, f, indent=2)
        git("add", "docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json")
        git("commit", "-m", "Register with stale base attestation")
        base_stale_reg = git("rev-parse", "HEAD")

        with open(os.path.join(tmpdir, "Source", "Features", "Reader", "iOS", "iOSReaderView.swift"), "w", encoding="utf-8") as f:
            f.write(good_content)
        c, o, e = run_cmd(["python", checker_path, "--base", base_stale_reg, "--upstream-ref", upstream_sha, "--owner-public-key", test_pub_hex], cwd=tmpdir)
        test_results.append(("20. Stale approval at wrong base -> FAIL (ATTESTATION_BASE_MISMATCH)", c == 1 and "ATTESTATION_BASE_MISMATCH" in o))
        git("reset", "--hard", base_stale_reg)

        # Test 21: CLI --exception-register in untrusted workspace without --allow-unsafe-register -> ignored in production
        untrusted_local_json = os.path.join(tmpdir, "untrusted_register.json")
        with open(untrusted_local_json, "w", encoding="utf-8") as f:
            json.dump(reg_data_crypto, f, indent=2)
        with open(os.path.join(tmpdir, "Source", "Core", "UpstreamFile.swift"), "w", encoding="utf-8") as f:
            f.write("// Unauthorized modification trying to use CLI register flag\n")
        c, o, e = run_cmd(["python", checker_path, "--base", baseline_sha, "--upstream-ref", upstream_sha, "--exception-register", untrusted_local_json], cwd=tmpdir)
        test_results.append(("21. CLI --exception-register without unsafe flag -> ignored and FAIL", c == 1 and "UNAUTHORIZED_UPSTREAM_MODIFICATION" in o))
        git("reset", "--hard", base_stale_reg)

        # Test 22: Misleading same base and head scan (--base HEAD --head HEAD) -> FAIL (SAME_BASE_AND_HEAD_NOT_PROOF)
        c, o, e = run_cmd(["python", checker_path, "--base", "HEAD", "--head", "HEAD", "--upstream-ref", upstream_sha], cwd=tmpdir)
        test_results.append(("22. Misleading scan (--base HEAD --head HEAD) -> FAIL (SAME_BASE_AND_HEAD_NOT_PROOF)", c == 1 and "SAME_BASE_AND_HEAD_NOT_PROOF" in o))

        # Test 23: Patch digest mismatch when hunk differs from attested patch digest -> FAIL (PATCH_DIGEST_MISMATCH)
        bad_digest_reg = {
            "version": 1,
            "baseline_sha": base_stale_reg,
            "exceptions": [
                {
                    "path": "Source/Features/Reader/iOS/iOSReaderView.swift",
                    "status": "APPROVED",
                    "approval_ref": "BAD_DIFF_DIGEST",
                    "expected_head_blob_sha": good_blob,
                    "owner_attestation": {
                        "base_sha": base_stale_reg,
                        "signer_public_key": test_pub_hex,
                        "signature": valid_signature,
                        "expected_head_blob_sha": good_blob,
                        "patch_digest_sha256": "0000000000000000000000000000000000000000000000000000000000000000"
                    }
                }
            ]
        }
        with open(os.path.join(tmpdir, "docs", "architecture", "UPSTREAM_EXCEPTION_REGISTER.json"), "w", encoding="utf-8") as f:
            json.dump(bad_digest_reg, f, indent=2)
        git("add", "docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json")
        git("commit", "-m", "Register with bad patch digest")
        base_bad_digest = git("rev-parse", "HEAD")

        with open(os.path.join(tmpdir, "Source", "Features", "Reader", "iOS", "iOSReaderView.swift"), "w", encoding="utf-8") as f:
            f.write(good_content)
        c, o, e = run_cmd(["python", checker_path, "--base", base_bad_digest, "--upstream-ref", upstream_sha, "--owner-public-key", test_pub_hex], cwd=tmpdir)
        test_results.append(("23. Patch diff digest mismatch -> FAIL (PATCH_DIGEST_MISMATCH)", c == 1 and "PATCH_DIGEST_MISMATCH" in o))

    print("\nFixture Test Results:")
    all_passed = True
    for name, passed in test_results:
        status = "PASS" if passed else "FAIL"
        print(f"  [{status}] {name}")
        if not passed:
            all_passed = False

    print(f"\nOverall Result: {'ALL FIXTURES PASSED' if all_passed else 'SOME FIXTURES FAILED'}")
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())
