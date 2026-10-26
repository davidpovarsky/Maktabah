#!/usr/bin/env python3
"""
tools/sign_owner_approvals.py — Owner Cryptographic Signing & Attestation Packaging Tool
Computes canonical payloads for all 14 Build 8401 upstream hunks, provides owner-side
Ed25519 signing from a secure private-key file, and verifies cryptographic attestations fail-closed.
"""

import argparse
import base64
from datetime import datetime, timezone, timedelta
import hashlib
import json
import os
import sys
import tempfile

REPO_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(REPO_DIR, "tools"))

import importlib.util
spec = importlib.util.spec_from_file_location("boundary_guard", os.path.join(REPO_DIR, "tools", "verify_upstream_boundary.py"))
bg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bg)

try:
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
except ImportError:
    print("Error: 'cryptography' Python package is required. Install via 'pip install cryptography'.", file=sys.stderr)
    sys.exit(1)

def load_private_key_from_file(file_path):
    """
    Loads Ed25519 private key exclusively from a secure filesystem path.
    Rejects raw strings passed directly to prevent leaking keys in process tables or history.
    Supports 32-byte binary, 64-character hex string, or valid base64.
    """
    clean_path = os.path.abspath(file_path.strip().strip("'\""))
    if not os.path.isfile(clean_path):
        raise ValueError(f"Private key file does not exist or is not a regular file: {clean_path}")

    try:
        with open(clean_path, "rb") as f:
            content = f.read().strip()
    except Exception as e:
        raise ValueError(f"Failed to read private key file '{clean_path}': {e}")

    # 1. 32-byte raw binary
    if len(content) == 32:
        return Ed25519PrivateKey.from_private_bytes(content)

    # 2. Text-encoded: hex or base64
    try:
        text = content.decode("utf-8").strip()
    except UnicodeDecodeError:
        raise ValueError(f"Invalid private key file '{clean_path}': neither 32-byte raw binary nor valid text.")

    if len(text) == 64:
        try:
            raw_bytes = bytes.fromhex(text)
            return Ed25519PrivateKey.from_private_bytes(raw_bytes)
        except Exception as e:
            raise ValueError(f"Hex private key in '{clean_path}' could not be parsed: {e}")

    try:
        b = base64.b64decode(text)
        if len(b) == 32:
            return Ed25519PrivateKey.from_private_bytes(b)
    except Exception:
        pass

    raise ValueError(f"Invalid private key format in '{clean_path}': must contain 32-byte raw binary, 64-char hex, or base64.")

def get_canonical_payloads(manifest_data, base_commit, repo_id, expires_at):
    payloads = []
    for patch in manifest_data.get("patches", []):
        p_id = patch["patch_id"]
        p_path = patch["path"]
        p_blob = patch["head_blob_sha"]
        p_diff_sha = patch["patch_digest_sha256"]
        p_file = patch.get("patch_file", "")

        canonical_bytes = bg.construct_canonical_attestation_payload(
            repo=repo_id,
            path=p_path,
            base_sha=base_commit,
            head_blob_sha=p_blob,
            patch_sha256=p_diff_sha,
            approval_id=p_id,
            expires_at=expires_at
        )
        payloads.append({
            "patch_id": p_id,
            "path": p_path,
            "head_blob_sha": p_blob,
            "patch_digest_sha256": p_diff_sha,
            "expected_patch_file": p_file,
            "canonical_bytes": canonical_bytes,
            "canonical_sha256": hashlib.sha256(canonical_bytes).hexdigest(),
            "canonical_json": canonical_bytes.decode("utf-8")
        })
    return payloads

def validate_manifest_preconditions(manifest_data, patches_dir, cwd):
    """
    Enforces strict 14/14 patch file and blob parity before any signing operation.
    """
    patches = manifest_data.get("patches", [])
    if len(patches) != 14:
        raise ValueError(f"Manifest must contain exactly 14 patches, found {len(patches)}")

    seen_ids = set()
    seen_paths = set()
    for idx, p in enumerate(patches, 1):
        p_id = p.get("patch_id")
        p_path = p.get("path")
        p_file = p.get("patch_file")
        p_digest = p.get("patch_digest_sha256")
        p_blob = p.get("head_blob_sha")

        if not p_id or not p_path or not p_file or not p_digest or not p_blob:
            raise ValueError(f"Patch entry #{idx} is missing required fields in manifest")
        if p_id in seen_ids:
            raise ValueError(f"Duplicate patch_id '{p_id}' in manifest")
        if p_path in seen_paths:
            raise ValueError(f"Duplicate path '{p_path}' in manifest")
        seen_ids.add(p_id)
        seen_paths.add(p_path)

        patch_full_path = os.path.join(patches_dir, p_file)
        if not os.path.exists(patch_full_path):
            raise ValueError(f"Packaged patch file not found on disk: {patch_full_path}")

        with open(patch_full_path, "rb") as pf:
            pf_norm = pf.read().replace(b"\r\n", b"\n")
        actual_digest = hashlib.sha256(pf_norm).hexdigest()
        if actual_digest != p_digest:
            raise ValueError(f"Patch file digest mismatch for '{p_file}': actual {actual_digest} != expected {p_digest}")

def main():
    parser = argparse.ArgumentParser(description="ChavrusaText Build 8401 Owner Signing and Attestation Packaging Tool")
    parser.add_argument("--generate-payloads", action="store_true", help="Print canonical unsigned payloads for all 14 hunks")
    parser.add_argument("--sign", action="store_true", help="Sign all 14 hunks with owner private key and update UPSTREAM_EXCEPTION_REGISTER.json")
    parser.add_argument("--verify", action="store_true", help="Verify current exception register against owner verification key")
    parser.add_argument("--private-key-file", help="Path to secure file containing owner Ed25519 private key (never raw key)")
    parser.add_argument("--owner-public-key", help="Owner Ed25519 public key (hex or base64) to verify after signing")
    parser.add_argument("--head-ref", default="WORKTREE", help="Git ref or WORKTREE to check during verification (default: WORKTREE)")
    parser.add_argument("--expires-days", type=int, default=365, help="Attestation validity duration in days (default: 365)")
    parser.add_argument("--repo-id", default="davidpovarsky/Maktabah", help="GitHub repository identifier")
    args = parser.parse_args()

    manifest_path = os.path.join(REPO_DIR, "docs", "architecture", "BUILD_8401_REPRODUCIBLE_PAYLOAD_MANIFEST.json")
    patches_dir = os.path.join(REPO_DIR, "docs", "architecture", "build-8401-patches")
    register_path = os.path.join(REPO_DIR, "docs", "architecture", "UPSTREAM_EXCEPTION_REGISTER.json")

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest_data = json.load(f)

    base_commit = manifest_data.get("base_commit", "031df35710ab2c6015efb1acd1e65154dbcd3f24")
    expires_at = (datetime.now(timezone.utc) + timedelta(days=args.expires_days)).strftime("%Y-%m-%dT%H:%M:%SZ")

    validate_manifest_preconditions(manifest_data, patches_dir, REPO_DIR)
    payloads = get_canonical_payloads(manifest_data, base_commit, args.repo_id, expires_at)

    if args.generate_payloads or (not args.sign and not args.verify and not args.private_key_file):
        print("=" * 80)
        print(f"CANONICAL ATTESTATION PAYLOADS FOR OWNER REVIEW ({len(payloads)} HUNKS)")
        print(f"Repository: {args.repo_id} | Base Commit: {base_commit} | Expires: {expires_at}")
        print("=" * 80)
        for idx, p in enumerate(payloads, 1):
            print(f"\n[{idx:02d}/14] {p['patch_id']}: {p['path']}")
            print(f"     Blob SHA:       {p['head_blob_sha']}")
            print(f"     Diff SHA256:    {p['patch_digest_sha256']}")
            print(f"     Patch File:     {p['expected_patch_file']}")
            print(f"     Payload Digest: {p['canonical_sha256']}")
            print(f"     Canonical JSON: {p['canonical_json']}")
        print("\n" + "=" * 80)
        print("To sign these 14 hunks, execute with owner private-key file:")
        print("  python tools/sign_owner_approvals.py --sign --private-key-file <PATH_TO_PRIVATE_KEY_FILE>")
        print("=" * 80)
        if not args.sign and not args.verify:
            return

    if args.verify:
        pub_key = args.owner_public_key or os.environ.get("MAKTABAH_OWNER_VERIFICATION_KEY")
        print(f"\nVerifying register boundary integrity (head_ref={args.head_ref}, owner_key={pub_key[:12] if pub_key else 'NONE'}...)...")
        code, report = bg.verify_boundaries(
            base_ref=base_commit,
            head_ref=args.head_ref,
            upstream_ref=manifest_data.get("pinned_upstream_sha", "a0ed0df908a6cb38bc459d4baaeb400f447b2fc4"),
            cwd=REPO_DIR,
            owner_public_key=pub_key
        )
        if code == 0:
            print(f"[VERIFIED PASS] All {len(report.get('warnings', []))} protected upstream hunks are cryptographically verified!")
        else:
            print(f"[VERIFICATION FAILED] Total violations: {report.get('total_violations')}", file=sys.stderr)
            for v in report.get("violations", []):
                print(f"  - [{v.get('type')}] {v.get('path')}: {v.get('message')}", file=sys.stderr)
            sys.exit(code)
        return

    if args.sign:
        if not args.private_key_file:
            print("Error: --sign requires --private-key-file <path>", file=sys.stderr)
            sys.exit(1)

        priv_key = load_private_key_from_file(args.private_key_file)
        pub_key = priv_key.public_key()
        pub_bytes = pub_key.public_bytes_raw()
        pub_hex = pub_bytes.hex()

        print(f"\nSigner public key (Ed25519 hex): {pub_hex}")
        if args.owner_public_key:
            expected_clean = args.owner_public_key.strip()
            if len(expected_clean) != 64:
                try:
                    expected_clean = base64.b64decode(expected_clean).hex()
                except Exception:
                    pass
            if pub_hex.lower() != expected_clean.lower():
                print(f"Error: Derived public key ({pub_hex}) does NOT match specified owner public key ({args.owner_public_key})!", file=sys.stderr)
                sys.exit(1)
            print("Verified: Private key matches specified owner verification public key.")

        with open(register_path, "r", encoding="utf-8") as f:
            register_data = json.load(f)

        signed_count = 0
        exceptions = register_data.get("exceptions", [])
        for ex in exceptions:
            p_id = ex.get("patch_id")
            match = next((p for p in payloads if p["patch_id"] == p_id), None)
            if not match:
                continue

            sig_bytes = priv_key.sign(match["canonical_bytes"])
            sig_hex = sig_bytes.hex()

            ex["status"] = "APPROVED"
            ex["owner_attestation"] = {
                "repo": args.repo_id,
                "approval_id": p_id,
                "base_sha": base_commit,
                "expected_head_blob_sha": match["head_blob_sha"],
                "patch_digest_sha256": match["patch_digest_sha256"],
                "signer_public_key": pub_hex,
                "signature": sig_hex,
                "signed_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "expires_at": expires_at
            }
            signed_count += 1

        if signed_count != 14:
            print(f"Error: Expected to sign exactly 14 exceptions, but signed {signed_count}!", file=sys.stderr)
            sys.exit(1)

        register_data["approval_gate_status"] = "GATE_CLOSED_OWNER_APPROVED"
        register_data["status"] = "APPROVED_OWNER_SIGNED"
        register_data["owner_verification_public_key"] = pub_hex
        register_data["last_signed"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

        # Atomic file write to avoid corrupting register on interrupted execution
        tmp_register = register_path + ".tmp"
        with open(tmp_register, "w", encoding="utf-8", newline="\n") as f:
            json.dump(register_data, f, indent=2, ensure_ascii=False)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp_register, register_path)

        print(f"\nSuccessfully signed all {signed_count} exceptions in {register_path}!")
        print("\nVerifying signed register fail-closed against owner public key (pre-commit head_ref=WORKTREE)...")

        code, report = bg.verify_boundaries(
            base_ref=base_commit,
            head_ref="WORKTREE",
            upstream_ref=manifest_data.get("pinned_upstream_sha", "a0ed0df908a6cb38bc459d4baaeb400f447b2fc4"),
            cwd=REPO_DIR,
            owner_public_key=pub_hex
        )

        if code == 0:
            print(f"\n[VERIFIED PASS] All {len(report.get('warnings', []))} protected upstream hunks are cryptographically verified!")
        else:
            print(f"\n[VERIFICATION FAILED] Report: {json.dumps(report, indent=2)}", file=sys.stderr)
            sys.exit(code)

if __name__ == "__main__":
    main()
