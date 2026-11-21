#!/usr/bin/env python3
"""
verify-upstream-boundary.py — Upstream Integrity & Boundary Guard Tool (Pass 4 Hardened)
Enforces read-only upstream boundary, detects unauthorized hunks, protected deletions,
namespace pollution, staged/unstaged/committed modifications, policy bypass attempts,
and validates genuine Ed25519 cryptographic owner attestations against pinned public keys.
"""

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
import re
import subprocess
import sys

DEFAULT_PINNED_UPSTREAM_SHA = os.environ.get("MAKTABAH_PINNED_UPSTREAM_SHA", "a0ed0df908a6cb38bc459d4baaeb400f447b2fc4")
DEFAULT_BASELINE_SHA = os.environ.get("MAKTABAH_BASELINE_SHA", "c8defbf812d34dd22ea1b7b63b1a356c0e96fa8f")

PROTECTED_NAMESPACES = [
    "Source/Core/",
    "Source/Features/",
    "Source/UI/",
    "Source/Extensions/"
]

FORK_ALLOWED_NAMESPACES = [
    "Source/ChavrusaText/",
    "Source/Otzaria/",
    "Source/Zayit/",
    "Source/ZayitSearch/",
    "Source/LibraryBackend/",
    "Source/Sefaria/"
]

POLICY_FILES = [
    "Scripts/CI/verify-upstream-boundary.py",
    "docs/architecture/UPSTREAM_INTEGRITY_POLICY.md",
    "docs/architecture/UPSTREAM_EXCEPTION_REGISTER.md",
    "docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json",
    "docs/architecture/UPSTREAM_LEGACY_DEBT.md"
]

def construct_canonical_attestation_payload(repo, path, base_sha, head_blob_sha, patch_sha256, approval_id, expires_at):
    """
    Constructs deterministic canonical bytes for cryptographic attestation signing and verification.
    Binds repository, relative path, base commit, head blob, patch diff digest, approval ID, and expiration.
    """
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


# BEGIN SELF-CONTAINED PATCH VERIFICATION
# Kept byte-identical in both guards: the PR workflow checks out only its trusted
# guard file, so importing a helper from an untrusted candidate would weaken it.
class PatchVerificationError(ValueError):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


def canonical_patch_bytes(base_ref, head_ref, path, cwd):
    """Render LF-normalized patch bytes with full object IDs and fixed options.

    No Git configuration is written. Binary bytes are never decoded with a
    lossy text codec. WORKTREE includes staged and unstaged file content.
    """
    env = os.environ.copy()
    # Preserve normal Git clean/filter and attributes semantics, especially a
    # global core.autocrlf that materialized Windows working files. Removing it
    # here would disagree with the ordinary hash-object check below.
    for key in ("GIT_EXTERNAL_DIFF", "GIT_DIFF_OPTS"):
        env.pop(key, None)
    cmd = ["git", "--no-pager", "-c", "core.quotePath=true",
           "-c", "diff.suppressBlankEmpty=false",
           "diff", "--full-index", "--binary", "--no-color", "--no-ext-diff",
           "--no-textconv", "--no-renames", "--no-relative",
           "--src-prefix=a/", "--dst-prefix=b/", "--line-prefix=",
           "--unified=3", "--inter-hunk-context=0", "--diff-algorithm=myers",
           "--indent-heuristic", "--ignore-submodules=none", "--submodule=short",
           "--output-indicator-new=+", "--output-indicator-old=-",
           "--output-indicator-context= ", base_ref]
    if head_ref != "WORKTREE":
        cmd.append(head_ref)
    cmd.extend(["--", ":(literal)" + path])
    result = subprocess.run(cmd, cwd=cwd, env=env, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, shell=False)
    if result.returncode != 0:
        raise PatchVerificationError("PATCH_DIFF_READ_ERROR",
                                     "Git could not render the exact patch.")
    return result.stdout.replace(b"\r\n", b"\n")


def attested_record_fields(entry, attestation):
    """Bind all aliases to the same values used in the seven signed fields.

    Legacy records without an explicit attestation approval_id retain their
    original approval_ref payload. An unsigned conflicting alias is never
    silently preferred, repaired, or accepted.
    """
    approval_id = attestation.get("approval_id") or entry.get("approval_ref") or "REF-APPROVED"
    for name in ("approval_ref", "patch_id"):
        if entry.get(name) and str(entry[name]) != str(approval_id):
            raise PatchVerificationError("ATTESTATION_IDENTITY_CONFLICT",
                                         "Unsigned " + name + " conflicts with the signed approval ID.")

    def bound_value(values, code, field):
        present = [str(value) for value in values if value]
        if len(set(present)) > 1:
            raise PatchVerificationError(code, "Conflicting " + field + " aliases.")
        if not present:
            raise PatchVerificationError("MISSING_ATTESTATION_BINDING",
                                         "Owner attestation lacks " + field + ".")
        return present[0]

    expected_blob = bound_value(
        [attestation.get("expected_head_blob_sha"), entry.get("expected_head_blob_sha")],
        "ATTESTATION_BLOB_CONFLICT", "head blob")
    expected_digest = bound_value(
        [attestation.get("canonical_patch_sha256"), attestation.get("patch_digest_sha256"),
         attestation.get("canonical_diff_sha256"), entry.get("patch_digest_sha256")],
        "ATTESTATION_DIGEST_CONFLICT", "patch digest")
    if not re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", expected_blob):
        raise PatchVerificationError("MISSING_ATTESTATION_BINDING", "Head blob must be a full object ID.")
    if not re.fullmatch(r"[0-9a-f]{64}", expected_digest):
        raise PatchVerificationError("MISSING_ATTESTATION_BINDING", "Patch digest must be a SHA-256 hex value.")
    return expected_blob, expected_digest, str(approval_id)


def read_archived_patch(cwd, filename):
    """Read only an in-repository archive; its bytes still require authentication."""
    repository = os.path.realpath(cwd)
    root = os.path.realpath(os.path.join(repository, "docs", "architecture"))
    try:
        contained = os.path.commonpath([repository, root]) == repository
    except ValueError:
        contained = False
    if not contained:
        raise PatchVerificationError("PATCH_FILE_OUTSIDE_REPOSITORY",
                                     "The archive directory resolves outside the repository.")
    if not isinstance(filename, str) or not filename:
        raise PatchVerificationError("PATCH_FILE_NOT_FOUND", "Invalid archive filename.")
    candidates = [os.path.join(root, "build-8401-patches", filename),
                  os.path.join(root, filename)]
    for candidate in candidates:
        candidate = os.path.realpath(candidate)
        try:
            if os.path.commonpath([root, candidate]) != root:
                continue
        except ValueError:
            continue
        if os.path.isfile(candidate):
            try:
                with open(candidate, "rb") as archive:
                    return archive.read().replace(b"\r\n", b"\n")
            except OSError as exc:
                raise PatchVerificationError("PATCH_FILE_READ_ERROR", str(exc)) from exc
    raise PatchVerificationError("PATCH_FILE_NOT_FOUND",
                                 "Packaged patch file is missing or outside the archive directory.")


def expand_authenticated_legacy_index(archive, current_patch):
    """Adapt only abbreviated index tokens, preserving every other patch byte.

    The caller must first verify the owner signature AND archive SHA-256. This
    is not a normalization of hunks, modes, paths, or arbitrary index lines.
    Unsupported/multi-file archives remain fail-closed.
    """
    old_lines = archive.splitlines(keepends=True)
    new_lines = current_patch.splitlines(keepends=True)
    if sum(line.startswith(b"diff --git ") for line in old_lines) != 1:
        return None
    if sum(line.startswith(b"diff --git ") for line in new_lines) != 1:
        return None
    old_indexes = [i for i, line in enumerate(old_lines) if line.startswith(b"index ")]
    new_indexes = [i for i, line in enumerate(new_lines) if line.startswith(b"index ")]
    if len(old_indexes) != 1 or old_indexes != new_indexes:
        return None
    index = old_indexes[0]
    old = re.fullmatch(rb"index ([0-9a-f]{4,64})\.\.([0-9a-f]{4,64})( [0-7]{6})?\n", old_lines[index])
    new = re.fullmatch(rb"index ([0-9a-f]{40}|[0-9a-f]{64})\.\.([0-9a-f]{40}|[0-9a-f]{64})( [0-7]{6})?\n", new_lines[index])
    if not old or not new or old.group(3) != new.group(3):
        return None
    if not all(new.group(n).startswith(old.group(n)) for n in (1, 2)):
        return None
    old_lines[index] = new_lines[index]
    return b"".join(old_lines)


def verify_record_patch(base_ref, head_ref, path, cwd, expected_digest, expected_patch_file=None):
    """Verify a digest already bound to an authentic owner signature."""
    current_patch = canonical_patch_bytes(base_ref, head_ref, path, cwd)
    actual_digest = hashlib.sha256(current_patch).hexdigest()
    if expected_patch_file:
        archive = read_archived_patch(cwd, expected_patch_file)
        if hashlib.sha256(archive).hexdigest() != expected_digest:
            raise PatchVerificationError("PATCH_FILE_DIGEST_MISMATCH",
                                         "Packaged patch bytes differ from the signed digest.")
        if archive == current_patch and actual_digest == expected_digest:
            return "full-index-v1"
        if expand_authenticated_legacy_index(archive, current_patch) == current_patch:
            return "authenticated-legacy-index-width"
    elif actual_digest == expected_digest:
        return "full-index-v1"
    raise PatchVerificationError("PATCH_DIGEST_MISMATCH",
                                 "Exact patch mismatch; legacy compatibility requires its authentic archive.")
# END SELF-CONTAINED PATCH VERIFICATION


def verify_ed25519_signature(public_key_raw, signature_raw, payload_bytes):
    """
    Cryptographically verifies an Ed25519 signature over payload bytes.
    Accepts hex string, base64 string, or raw bytes for both key and signature.
    """
    try:
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
        from cryptography.exceptions import InvalidSignature
    except ImportError:
        return False, "CRYPTOGRAPHY_MODULE_UNAVAILABLE"

    # Convert public key to 32 bytes
    try:
        if isinstance(public_key_raw, str):
            clean_key = public_key_raw.strip()
            if len(clean_key) == 64:
                pub_bytes = bytes.fromhex(clean_key)
            else:
                pub_bytes = base64.b64decode(clean_key)
        else:
            pub_bytes = bytes(public_key_raw)

        if len(pub_bytes) != 32:
            return False, f"PUBLIC_KEY_LENGTH_INVALID: expected 32 bytes, got {len(pub_bytes)}"
        pub_key = Ed25519PublicKey.from_public_bytes(pub_bytes)
    except Exception as e:
        return False, f"INVALID_PUBLIC_KEY_FORMAT: {str(e)}"

    # Convert signature to 64 bytes
    try:
        if isinstance(signature_raw, str):
            clean_sig = signature_raw.strip()
            if len(clean_sig) == 128:
                sig_bytes = bytes.fromhex(clean_sig)
            else:
                sig_bytes = base64.b64decode(clean_sig)
        else:
            sig_bytes = bytes(signature_raw)

        if len(sig_bytes) != 64:
            return False, f"SIGNATURE_LENGTH_INVALID: expected 64 bytes, got {len(sig_bytes)}"
    except Exception as e:
        return False, f"INVALID_SIGNATURE_ENCODING: {str(e)}"

    try:
        pub_key.verify(sig_bytes, payload_bytes)
        return True, "VALID"
    except InvalidSignature:
        return False, "INVALID_SIGNATURE"
    except Exception as e:
        return False, str(e)

def is_attestation_expired(expires_at_str):
    """
    Validates expiration timestamp against current UTC time.
    Fails closed if missing, malformed, or past.
    """
    if not expires_at_str:
        return True, "Expiration date missing from attestation"
    try:
        s = str(expires_at_str).strip()
        if s.endswith("Z"):
            exp_dt = datetime.fromisoformat(s[:-1] + "+00:00")
        elif "+" in s or ("-" in s[10:]):
            exp_dt = datetime.fromisoformat(s)
        else:
            exp_dt = datetime.fromisoformat(s).replace(tzinfo=timezone.utc)
        now_dt = datetime.now(timezone.utc)
        if now_dt > exp_dt:
            return True, f"Attestation expired on {s} (current UTC time: {now_dt.isoformat()})"
        return False, None
    except Exception as e:
        return True, f"Invalid expiration format '{expires_at_str}': {str(e)}"

def load_exception_register(base_ref, register_arg, allow_unsafe, cwd):
    """
    Loads approved exceptions from the trusted base ref.
    Enforces that untrusted PR / worktree heads cannot inject unreviewed approvals.
    register_arg is ONLY allowed if allow_unsafe is True (for isolated test fixtures).
    In production / CI, exceptions MUST come from base_ref:docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json.
    """
    data = None
    if register_arg:
        if not allow_unsafe:
            print("Security Notice: CLI --exception-register is ignored in production mode without --allow-unsafe-register.", file=sys.stderr)
        else:
            reg_full = os.path.join(cwd, register_arg) if not os.path.isabs(register_arg) else register_arg
            if os.path.exists(reg_full):
                try:
                    with open(reg_full, "r", encoding="utf-8") as f:
                        data = json.load(f)
                except Exception as e:
                    print(f"Warning: Failed reading exception register '{register_arg}': {e}", file=sys.stderr)
    if not data and base_ref and base_ref != "WORKTREE":
        code, out, _ = run_cmd(["git", "show", f"{base_ref}:docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json"], cwd=cwd)
        if code == 0 and out.strip():
            try:
                data = json.loads(out)
            except Exception:
                pass

    if not data or "exceptions" not in data:
        return {}

    exceptions_by_path = {}
    reg_baseline = data.get("baseline_commit") or data.get("baseline_sha")
    for entry in data.get("exceptions", []):
        path = entry.get("path", "").replace("\\", "/")
        if path:
            if reg_baseline and "register_baseline" not in entry:
                entry["register_baseline"] = reg_baseline
            exceptions_by_path[path] = entry
    return exceptions_by_path

def run_cmd(cmd, cwd=None):
    res = subprocess.run(
        cmd,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        shell=False
    )
    return res.returncode, res.stdout, res.stderr

def verify_ref_exists(ref, cwd):
    code, _, _ = run_cmd(["git", "rev-parse", "--verify", ref], cwd=cwd)
    return code == 0

def resolve_ref(ref, cwd):
    code, out, _ = run_cmd(["git", "rev-parse", ref], cwd=cwd)
    if code != 0:
        return None
    return out.strip()

def get_tree_files(ref, cwd):
    code, out, err = run_cmd(["git", "ls-tree", "-r", "--name-only", "-z", ref], cwd=cwd)
    if code != 0:
        raise RuntimeError(f"Failed to get ls-tree for {ref}: {err.strip()}")
    return set(f for f in out.split("\0") if f)

def parse_porcelain_untracked(cwd):
    """
    Parses untracked files from git status --porcelain=v1 -z -uall.
    """
    code, out, err = run_cmd(["git", "status", "--porcelain=v1", "-z", "-uall"], cwd=cwd)
    if code != 0:
        raise RuntimeError(f"Failed to get git status: {err.strip()}")

    untracked = []
    tokens = out.split("\0")
    idx = 0
    while idx < len(tokens):
        token = tokens[idx]
        if not token:
            idx += 1
            continue
        status = token[:2]
        path = token[3:]
        if status == "??" or status == " A":
            untracked.append(path)
        idx += 1
    return untracked

def parse_raw_diff(cmd, cwd):
    code, out, err = run_cmd(cmd, cwd=cwd)
    if code != 0:
        raise RuntimeError(f"Diff failed ({cmd}): {err.strip()}")

    diff_entries = []
    tokens = out.split("\0")
    idx = 0
    while idx < len(tokens):
        meta = tokens[idx].strip()
        if not meta:
            idx += 1
            continue
        parts = meta.split()
        if len(parts) >= 5:
            status = parts[4]
            idx += 1
            path = tokens[idx] if idx < len(tokens) else ""
            if status.startswith("R") or status.startswith("C"):
                idx += 1
                new_path = tokens[idx] if idx < len(tokens) else ""
                diff_entries.append({"status": status, "path": new_path, "orig_path": path})
            else:
                diff_entries.append({"status": status, "path": path, "orig_path": None})
        idx += 1
    return diff_entries

def verify_boundaries(base_ref, head_ref, upstream_ref, cwd, exception_register=None, allow_unsafe_register=False, owner_public_key=None):
    # Enforce CI prohibition against --allow-unsafe-register
    is_prod_ci = os.environ.get("CI") == "true" or os.environ.get("GITHUB_ACTIONS") == "true"
    if is_prod_ci and allow_unsafe_register:
        return 1, {
            "status": "FAIL",
            "base_ref": base_ref,
            "head_ref": head_ref,
            "upstream_ref": upstream_ref,
            "total_changes_detected": 0,
            "total_violations": 1,
            "total_warnings": 0,
            "violations": [{
                "type": "PROD_CI_FORBIDS_UNSAFE_REGISTER",
                "path": "N/A",
                "status": "FORBIDDEN",
                "provenance": "CLI",
                "message": "--allow-unsafe-register is strictly forbidden in production CI environment."
            }],
            "warnings": [],
            "policy_files_changed": [],
            "protected_files_changed": []
        }

    # Handle zero SHA fallback for newly pushed branches without previous commit
    if not base_ref or base_ref == "0000000000000000000000000000000000000000":
        base_ref = DEFAULT_BASELINE_SHA

    # 0. Check for invalid same base and head scan (zero-commit scan is NOT proof of boundary integrity)
    base_commit = resolve_ref(base_ref, cwd)
    if head_ref != "WORKTREE":
        head_commit = resolve_ref(head_ref, cwd)
        if base_commit and head_commit and base_commit == head_commit:
            return 1, {
                "status": "FAIL",
                "base_ref": base_ref,
                "head_ref": head_ref,
                "upstream_ref": upstream_ref,
                "total_changes_detected": 0,
                "total_violations": 1,
                "total_warnings": 0,
                "violations": [{
                    "type": "SAME_BASE_AND_HEAD_NOT_PROOF",
                    "path": "N/A",
                    "status": "INVALID_SCAN",
                    "provenance": "CLI",
                    "message": f"Base and head both resolve to identical commit ({base_commit}). Zero commits inspected; cannot prove boundary integrity."
                }],
                "warnings": [],
                "policy_files_changed": [],
                "protected_files_changed": []
            }

    # 1. Verify existence of refs; exit 2 on invalid reference
    if not verify_ref_exists(upstream_ref, cwd):
        return 2, {"status": "ERROR", "message": f"Upstream ref '{upstream_ref}' does not exist"}
    if not verify_ref_exists(base_ref, cwd):
        return 2, {"status": "ERROR", "message": f"Base ref '{base_ref}' does not exist"}
    if head_ref != "WORKTREE" and not verify_ref_exists(head_ref, cwd):
        return 2, {"status": "ERROR", "message": f"Head ref '{head_ref}' does not exist"}

    try:
        upstream_files = get_tree_files(upstream_ref, cwd)
        base_files = get_tree_files(base_ref, cwd)
    except Exception as e:
        return 2, {"status": "ERROR", "message": f"Failed reading Git tree: {str(e)}"}

    exceptions_by_path = load_exception_register(base_ref, exception_register, allow_unsafe_register, cwd)

    changes_by_path = {}

    if head_ref == "WORKTREE":
        # In WORKTREE mode, inspect the UNION of:
        # a) base..HEAD (committed changes between base and current commit)
        # b) HEAD..index (staged changes)
        # c) index..worktree (unstaged changes in tracked files)
        # d) untracked paths (-uall)
        head_commit = resolve_ref("HEAD", cwd)
        base_commit = resolve_ref(base_ref, cwd)

        # 1. Committed changes between base and HEAD
        if head_commit != base_commit:
            committed_diff = parse_raw_diff(["git", "diff", "--raw", "--no-renames", "-z", base_ref, "HEAD"], cwd)
            for d in committed_diff:
                norm_path = d["path"].replace("\\", "/")
                changes_by_path[norm_path] = {"status": d["status"], "provenance": "COMMITTED", "orig_path": d.get("orig_path")}

        # 2. Staged changes (HEAD vs index)
        staged_diff = parse_raw_diff(["git", "diff", "--cached", "--raw", "--no-renames", "-z", "HEAD"], cwd)
        for d in staged_diff:
            norm_path = d["path"].replace("\\", "/")
            changes_by_path[norm_path] = {"status": d["status"], "provenance": "STAGED", "orig_path": d.get("orig_path")}

        # 3. Unstaged changes in tracked files (index vs worktree)
        unstaged_diff = parse_raw_diff(["git", "diff", "--raw", "--no-renames", "-z"], cwd)
        for d in unstaged_diff:
            norm_path = d["path"].replace("\\", "/")
            changes_by_path[norm_path] = {"status": d["status"], "provenance": "UNSTAGED", "orig_path": d.get("orig_path")}

        # 4. Untracked files
        untracked = parse_porcelain_untracked(cwd)
        for u in untracked:
            norm_path = u.replace("\\", "/")
            if norm_path not in changes_by_path:
                changes_by_path[norm_path] = {"status": "??", "provenance": "UNTRACKED", "orig_path": None}

    else:
        # Explicit head_ref: inspect base_ref..head_ref directly
        commit_diff = parse_raw_diff(["git", "diff", "--raw", "--no-renames", "-z", base_ref, head_ref], cwd)
        for d in commit_diff:
            norm_path = d["path"].replace("\\", "/")
            changes_by_path[norm_path] = {"status": d["status"], "provenance": "COMMITTED", "orig_path": d.get("orig_path")}

    violations = []
    warnings = []
    policy_files_changed = []
    protected_files_changed = []

    # Resolve configured owner public verification key
    pinned_owner_key = owner_public_key or os.environ.get("MAKTABAH_OWNER_VERIFICATION_KEY")

    for path, info in sorted(changes_by_path.items()):
        status = info["status"]
        provenance = info["provenance"]
        orig_path = info.get("orig_path")

        if path in POLICY_FILES:
            policy_files_changed.append(path)

        is_upstream_owned = path in upstream_files
        is_orig_upstream_owned = orig_path in upstream_files if orig_path else False

        # Deletion of upstream file (or rename away from upstream)
        if (is_upstream_owned and "D" in status) or is_orig_upstream_owned:
            target_desc = f" (renamed to {path})" if orig_path else ""
            del_path = orig_path if is_orig_upstream_owned else path
            violations.append({
                "type": "UPSTREAM_FILE_DELETED",
                "path": del_path,
                "status": status,
                "provenance": provenance,
                "message": f"Original upstream-owned file was deleted or renamed{target_desc}: {del_path}"
            })
            protected_files_changed.append(del_path)
            continue

        # Modification of upstream file
        if is_upstream_owned and any(c in status for c in ["M", "T", "A"]):
            approved_entry = exceptions_by_path.get(path)
            if approved_entry:
                entry_status = approved_entry.get("status", "PATCH_PROPOSED")
                if entry_status != "APPROVED":
                    violations.append({
                        "type": "PENDING_UPSTREAM_APPROVAL",
                        "path": path,
                        "status": status,
                        "provenance": provenance,
                        "message": f"Protected upstream-owned file has unapproved proposal (status={entry_status}): {path}"
                    })
                    protected_files_changed.append(path)
                    continue

                # Owner attestation verification
                attestation = approved_entry.get("owner_attestation")
                if not attestation or not isinstance(attestation, dict):
                    violations.append({
                        "type": "MISSING_OWNER_ATTESTATION",
                        "path": path,
                        "status": status,
                        "provenance": provenance,
                        "message": f"Approved exception for {path} lacks cryptographic owner attestation proof."
                    })
                    protected_files_changed.append(path)
                    continue

                attestation_base = attestation.get("base_sha")
                register_baseline = approved_entry.get("register_baseline")
                is_valid_base = False
                if attestation_base:
                    if attestation_base == base_commit:
                        is_valid_base = True
                    elif register_baseline and attestation_base == register_baseline:
                        anc_code, _, _ = run_cmd(["git", "merge-base", "--is-ancestor", attestation_base, base_commit], cwd=cwd)
                        if anc_code == 0:
                            is_valid_base = True

                if not is_valid_base:
                    violations.append({
                        "type": "ATTESTATION_BASE_MISMATCH",
                        "path": path,
                        "status": status,
                        "provenance": provenance,
                        "message": f"Owner attestation for {path} specifies base {attestation_base}, which does not match base {base_commit}."
                    })
                    protected_files_changed.append(path)
                    continue

                # Verify expiration timestamp (fail-closed if expired or malformed)
                expires_at = attestation.get("expires_at")
                if expires_at:
                    is_expired, exp_msg = is_attestation_expired(expires_at)
                    if is_expired:
                        violations.append({
                            "type": "ATTESTATION_EXPIRED",
                            "path": path,
                            "status": status,
                            "provenance": provenance,
                            "message": f"Owner attestation for {path} is expired: {exp_msg}"
                        })
                        protected_files_changed.append(path)
                        continue

                # Fail-closed trust gate check: is the owner verification key configured?
                if not pinned_owner_key:
                    violations.append({
                        "type": "TRUST_GATE_BLOCKED_OWNER_CONFIGURATION",
                        "path": path,
                        "status": status,
                        "provenance": provenance,
                        "message": f"Owner Ed25519 verification public key is not configured in policy or environment. Cryptographic identity proof cannot be validated for {path}."
                    })
                    protected_files_changed.append(path)
                    continue

                # Validate signer public key against pinned owner public key
                signer_key = attestation.get("signer_public_key") or attestation.get("signed_by")
                if not signer_key:
                    violations.append({
                        "type": "MISSING_OWNER_SIGNATURE",
                        "path": path,
                        "status": status,
                        "provenance": provenance,
                        "message": f"Owner attestation for {path} lacks authorized signer public key or signature."
                    })
                    protected_files_changed.append(path)
                    continue

                if signer_key.strip() != pinned_owner_key.strip():
                    violations.append({
                        "type": "UNAUTHORIZED_SIGNER_KEY",
                        "path": path,
                        "status": status,
                        "provenance": provenance,
                        "message": f"Attestation signer key ({signer_key}) does not match pinned owner verification key ({pinned_owner_key[:16]}...)."
                    })
                    protected_files_changed.append(path)
                    continue

                signature = attestation.get("signature")
                if not signature:
                    violations.append({
                        "type": "MISSING_OWNER_SIGNATURE",
                        "path": path,
                        "status": status,
                        "provenance": provenance,
                        "message": f"Owner attestation for {path} lacks cryptographic signature."
                    })
                    protected_files_changed.append(path)
                    continue

                # Resolve the exact values authenticated by the unchanged seven-field payload.
                try:
                    expected_blob, expected_digest, approval_id = attested_record_fields(approved_entry, attestation)
                except PatchVerificationError as exc:
                    violations.append({"type": exc.code, "path": path, "status": status,
                                       "provenance": provenance, "message": str(exc)})
                    protected_files_changed.append(path)
                    continue

                if head_ref == "WORKTREE":
                    b_code, b_out, _ = run_cmd(["git", "hash-object", path], cwd=cwd)
                else:
                    b_code, b_out, _ = run_cmd(["git", "rev-parse", f"{head_ref}:{path}"], cwd=cwd)
                actual_blob = b_out.strip() if b_code == 0 else None
                if actual_blob != expected_blob:
                    violations.append({
                        "type": "UNAPPROVED_HUNK_DIFFERS_FROM_EXCEPTION", "path": path,
                        "status": status, "provenance": provenance,
                        "message": f"Modified upstream file differs from approved exception blob (actual {actual_blob} != expected {expected_blob}): {path}"
                    })
                    protected_files_changed.append(path)
                    continue

                payload_bytes = construct_canonical_attestation_payload(
                    repo=attestation.get("repo", "davidpovarsky/Maktabah"),
                    path=path, base_sha=attestation_base, head_blob_sha=expected_blob,
                    patch_sha256=expected_digest, approval_id=approval_id,
                    expires_at=expires_at or "NEVER"
                )
                sig_valid, sig_msg = verify_ed25519_signature(pinned_owner_key, signature, payload_bytes)
                if not sig_valid:
                    violations.append({
                        "type": "INVALID_CRYPTOGRAPHIC_SIGNATURE", "path": path,
                        "status": status, "provenance": provenance,
                        "message": f"Ed25519 cryptographic signature verification failed: {sig_msg}"
                    })
                    protected_files_changed.append(path)
                    continue

                # Legacy archive adaptation is reachable only after authentic owner verification.
                try:
                    patch_format = verify_record_patch(
                        base_ref, head_ref, path, cwd, expected_digest,
                        approved_entry.get("expected_patch_file"))
                except PatchVerificationError as exc:
                    violations.append({"type": exc.code, "path": path, "status": status,
                                       "provenance": provenance, "message": str(exc)})
                    protected_files_changed.append(path)
                    continue

                warnings.append({
                    "type": "APPROVED_UPSTREAM_EXCEPTION",
                    "path": path,
                    "approval_ref": approved_entry.get("approval_ref"),
                    "attestation": attestation,
                    "patch_format": patch_format,
                    "message": f"Cryptographically verified upstream exception: {path} (approval={approval_id}, signer={pinned_owner_key[:12]}...)"
                })
                continue

            violations.append({
                "type": "UNAUTHORIZED_UPSTREAM_MODIFICATION",
                "path": path,
                "status": status,
                "provenance": provenance,
                "message": f"Protected upstream-owned file modified without owner approval ({provenance}): {path}"
            })
            protected_files_changed.append(path)
            continue

        # Untracked or added file in protected upstream namespaces
        if ("?" in status or "A" in status) and not is_upstream_owned:
            in_protected_ns = any(path.startswith(ns) for ns in PROTECTED_NAMESPACES)
            in_allowed_fork_ns = any(path.startswith(ns) for ns in FORK_ALLOWED_NAMESPACES)
            if in_protected_ns and not in_allowed_fork_ns:
                violations.append({
                    "type": "PROTECTED_NAMESPACE_POLLUTION",
                    "path": path,
                    "status": status,
                    "provenance": provenance,
                    "message": f"New file created inside protected namespace without fork prefix ({provenance}): {path}. Use Source/ChavrusaText/ instead."
                })
                protected_files_changed.append(path)

    # Detect bypass attempt: policy files changed together with protected sources
    if policy_files_changed and protected_files_changed:
        violations.append({
            "type": "UNAUTHORIZED_POLICY_BYPASS_ATTEMPT",
            "path": ", ".join(policy_files_changed),
            "status": "BYPASS",
            "provenance": "COUPLED_CHANGE",
            "message": "Policy enforcement or exception files were modified in the same change as protected source code!"
        })

    is_clean = len(violations) == 0
    report = {
        "status": "PASS" if is_clean else "FAIL",
        "base_ref": base_ref,
        "head_ref": head_ref,
        "upstream_ref": upstream_ref,
        "total_changes_detected": len(changes_by_path),
        "total_violations": len(violations),
        "total_warnings": len(warnings),
        "violations": violations,
        "warnings": warnings,
        "policy_files_changed": policy_files_changed,
        "protected_files_changed": protected_files_changed
    }
    return (0 if is_clean else 1), report

def main():
    parser = argparse.ArgumentParser(description="Verify upstream boundary integrity and downstream layer separation.")
    parser.add_argument("--base", default=DEFAULT_BASELINE_SHA, help="Baseline commit SHA before changes")
    parser.add_argument("--head", default="WORKTREE", help="Commit SHA or WORKTREE to check")
    parser.add_argument("--upstream-ref", default=DEFAULT_PINNED_UPSTREAM_SHA, help="Pinned upstream ref/SHA")
    parser.add_argument("--repo", default=None, help="Path to Git repository root (defaults to current directory)")
    parser.add_argument("--exception-register", default=None, help="Path to UPSTREAM_EXCEPTION_REGISTER.json")
    parser.add_argument("--allow-unsafe-register", action="store_true", help="Allow loading exception register from local path (fixture test mode only)")
    parser.add_argument("--owner-public-key", default=None, help="Ed25519 verification public key (hex or base64)")
    parser.add_argument("--report-json", help="Path to write JSON report")

    args = parser.parse_args()
    cwd = os.path.abspath(args.repo) if args.repo else os.getcwd()

    exit_code, report = verify_boundaries(
        base_ref=args.base,
        head_ref=args.head,
        upstream_ref=args.upstream_ref,
        cwd=cwd,
        exception_register=args.exception_register,
        allow_unsafe_register=args.allow_unsafe_register,
        owner_public_key=args.owner_public_key
    )

    if args.report_json:
        os.makedirs(os.path.dirname(os.path.abspath(args.report_json)), exist_ok=True)
        with open(args.report_json, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        print(f"Report written to {args.report_json}")

    print(f"\nBoundary Verification Result: {report['status']}")
    print(f"Base: {args.base} | Head: {args.head} | Upstream: {args.upstream_ref}")
    print(f"Changes detected: {report.get('total_changes_detected', 0)}, Violations: {report.get('total_violations', 0)}, Warnings: {report.get('total_warnings', 0)}")

    if report.get("warnings"):
        print("\nAPPROVED EXCEPTIONS / WARNINGS:")
        for w in report["warnings"]:
            print(f"  - [{w['type']}] {w.get('path', '')}: {w.get('message', '')}")

    if report.get("violations"):
        print("\nVIOLATIONS DETECTED:")
        for v in report["violations"]:
            print(f"  - [{v['type']}] ({v.get('status', '')} / {v.get('provenance', '')}) {v['path']}: {v['message']}")

    sys.exit(exit_code)

if __name__ == "__main__":
    main()
