#!/usr/bin/env python3
"""Require existing authentic upstream approval before signing an application.

The verifier is read from a fixed reviewed Git object, hash-checked, and loaded
from a private temporary directory. Candidate source cannot supply its verifier
or its verification key. This wrapper does not sign or modify a registry.
"""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

REPOSITORY = "davidpovarsky/Maktabah"
BASELINE = "031df35710ab2c6015efb1acd1e65154dbcd3f24"
UPSTREAM = "a0ed0df908a6cb38bc459d4baaeb400f447b2fc4"
VERIFIER_COMMIT = "978db8b37256d4dd2d58e91a0ea8d531798221c0"
VERIFIER_PATH = "tools/verify_upstream_boundary.py"
VERIFIER_SHA256 = "9733798a242382f59da99cb999a169e2c69c59010b336742e9a8fa151e837676"
APPLICATION_TREES = ("Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests")


class ApprovalError(ValueError):
    pass


def git(repo, *args):
    return subprocess.check_output(["git", *args], cwd=repo, timeout=90)


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def checkout_identity(repo, candidate, repository, event_sha=None):
    if repository != REPOSITORY:
        raise ApprovalError("Unexpected repository")
    if not re.fullmatch(r"[0-9a-f]{40}", candidate):
        raise ApprovalError("Expected candidate must be a full immutable commit SHA")
    actual = git(repo, "rev-parse", "HEAD").decode().strip()
    if actual != candidate or (event_sha is not None and event_sha != candidate):
        raise ApprovalError("Checkout, requested candidate, and GitHub event SHA must agree")
    subprocess.run(["git", "diff", "--quiet", "HEAD", "--", *APPLICATION_TREES],
                   cwd=repo, timeout=90, check=True)
    return {name: git(repo, "rev-parse", candidate + ":" + name).decode().strip()
            for name in APPLICATION_TREES}


def trusted_verifier_bytes(repo):
    raw = git(repo, "show", VERIFIER_COMMIT + ":" + VERIFIER_PATH)
    if hashlib.sha256(raw).hexdigest() != VERIFIER_SHA256:
        raise ApprovalError("Trusted immutable verifier SHA-256 mismatch")
    return raw


def public_key_fingerprint(key):
    if not key:
        raise ApprovalError("External MAKTABAH_OWNER_VERIFICATION_KEY is not configured")
    try:
        raw = bytes.fromhex(key) if len(key) == 64 else base64.b64decode(key, validate=True)
    except (ValueError, TypeError) as error:
        raise ApprovalError("External owner verification key has invalid encoding") from error
    if len(raw) != 32:
        raise ApprovalError("External owner verification key must contain 32 public bytes")
    return hashlib.sha256(raw).hexdigest()


def validate_report(code, report, candidate, scope, now=None):
    if code != 0 or report.get("status") != "PASS":
        raise ApprovalError("Pinned verifier did not return exit 0 and PASS")
    for name, expected in (("base_ref", BASELINE), ("head_ref", candidate), ("upstream_ref", UPSTREAM)):
        if report.get(name) != expected:
            raise ApprovalError("Pinned verifier report source mismatch: " + name)
    if report.get("violations") or report.get("total_violations") != 0:
        raise ApprovalError("Pinned verifier report contains violations")
    warnings = report.get("warnings")
    if not isinstance(warnings, list) or report.get("total_warnings") != len(warnings):
        raise ApprovalError("Pinned verifier approval count is inconsistent")
    paths = [row.get("path") for row in warnings if row.get("type") == "APPROVED_UPSTREAM_EXCEPTION"]
    if (len(paths) != len(warnings) or len(set(paths)) != len(paths)
            or set(paths) != set(scope)):
        raise ApprovalError("Verified approvals do not exactly cover the protected source changes")
    now = now or datetime.now(timezone.utc)
    for row in warnings:
        attestation = row.get("attestation")
        if not isinstance(attestation, dict) or attestation.get("repo") != REPOSITORY:
            raise ApprovalError("Verified attestation is not bound to the release repository")
        try:
            expires = datetime.fromisoformat(attestation["expires_at"].replace("Z", "+00:00"))
        except (KeyError, TypeError, ValueError) as error:
            raise ApprovalError("Release attestation has no valid expiration") from error
        if expires.tzinfo is None or expires <= now:
            raise ApprovalError("Release attestation is expired or has no timezone")
    return len(paths)


def audit(repo, candidate, repository, output, event_sha=None, key=None):
    output.mkdir(parents=True, exist_ok=True)
    report_path = output / "boundary-guard-report.json"
    receipt = {
        "schema": "otzaria-owner-release-approval-v1", "status": "FAILED",
        "repository": repository, "candidate_sha": candidate, "baseline_sha": BASELINE,
        "upstream_sha": UPSTREAM, "verifier_commit": VERIFIER_COMMIT,
        "verifier_path": VERIFIER_PATH, "verifier_sha256": VERIFIER_SHA256,
        "observed_at": datetime.now(timezone.utc).isoformat(),
        "signing_performed": False, "registry_modified": False,
    }
    raw_report = {"status": "NOT_EXECUTED", "reason": "Verifier has not executed"}
    try:
        before = checkout_identity(repo, candidate, repository, event_sha)
        receipt["application_trees"] = before
        key = (os.environ.get("MAKTABAH_OWNER_VERIFICATION_KEY", "") if key is None else key).strip()
        receipt["external_public_key_configured"] = bool(key)
        key_problem = None
        try:
            receipt["external_public_key_sha256"] = public_key_fingerprint(key)
        except ApprovalError as error:
            key_problem = str(error)
        raw = trusted_verifier_bytes(repo)
        with tempfile.TemporaryDirectory(prefix="otzaria-trusted-owner-verifier-") as scratch:
            verifier_path = Path(scratch) / "verify_upstream_boundary.py"
            verifier_path.write_bytes(raw)
            spec = importlib.util.spec_from_file_location("otzaria_trusted_owner_verifier", verifier_path)
            guard = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(guard)
            upstream_files = guard.get_tree_files(UPSTREAM, str(repo))
            changes = guard.parse_raw_diff(
                ["git", "diff", "--raw", "--no-renames", "-z", BASELINE, candidate], str(repo))
            scope = sorted({row["path"] for row in changes
                            if guard.is_protected_path(row["path"], upstream_files)})
            receipt["protected_paths"] = scope
            receipt["protected_path_count"] = len(scope)
            code, raw_report = guard.verify_boundaries(
                base_ref=BASELINE, head_ref=candidate, upstream_ref=UPSTREAM,
                cwd=str(repo), owner_public_key=key)
        receipt["verifier_exit_code"] = code
        # Retain the actual diagnostic even when external key provisioning is absent.
        write_json(report_path, raw_report)
        if key_problem:
            raise ApprovalError(key_problem)
        count = validate_report(code, raw_report, candidate, scope)
        if checkout_identity(repo, candidate, repository, event_sha) != before:
            raise ApprovalError("Application source changed during approval verification")
        receipt.update(status="OWNER_APPROVAL_VERIFIED", verified_protected_paths=count)
        return 0
    except Exception as error:
        receipt["error"] = type(error).__name__ + ": " + str(error)
        return 1
    finally:
        write_json(report_path, raw_report)
        receipt["boundary_report_sha256"] = hashlib.sha256(report_path.read_bytes()).hexdigest()
        write_json(output / "owner-approval-gate.json", receipt)
        print(json.dumps(receipt, indent=2, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--expected-sha", required=True)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    return audit(args.repo.resolve(), args.expected_sha, args.repository,
                 args.out_dir.resolve(), event_sha=os.environ.get("GITHUB_SHA"))


if __name__ == "__main__":
    raise SystemExit(main())
