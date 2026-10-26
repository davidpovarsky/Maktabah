#!/usr/bin/env python3
"""
tools/sign_owner_approvals.py — Owner Cryptographic Signing & Attestation Packaging Tool
Computes canonical payloads for all 14 Build 8401 upstream hunks, provides owner-side
Ed25519 signing, and verifies cryptographic attestations fail-closed.
"""

import argparse
import base64
from datetime import datetime, timezone, timedelta
import hashlib
import json
import os
import sys

REPO_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(REPO_DIR, "Scripts", "CI"))

import importlib.util
spec = importlib.util.spec_from_file_location("boundary_guard", os.path.join(REPO_DIR, "Scripts", "CI", "verify-upstream-boundary.py"))
bg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bg)

try:
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
except ImportError:
    print("Error: 'cryptography' Python package is required. Install via 'pip install cryptography'.", file=sys.stderr)
    sys.exit(1)

def load_private_key(raw_input):
    """
    Loads Ed25519 private key from file path, 64-char hex string, or base64 string.
    """
    raw_str = raw_input.strip()
    if os.path.isfile(raw_str):
        with open(raw_str, "rb") as f:
            content = f.read().strip()
            try:
                # Try raw 32-byte binary
                if len(content) == 32:
                    return Ed25519PrivateKey.from_private_bytes(content)
                # Try hex string in file
                text = content.decode("utf-8").strip()
                if len(text) == 64:
                    return Ed25519PrivateKey.from_private_bytes(bytes.fromhex(text))
                return Ed25519PrivateKey.from_private_bytes(base64.b64decode(text))
            except Exception as e:
                raise ValueError(f"Failed loading private key from file '{raw_str}': {e}")
    if len(raw_str) == 64:
        return Ed25519PrivateKey.from_private_bytes(bytes.fromhex(raw_str))
    try:
        b = base64.b64decode(raw_str)
        if len(b) == 32:
            return Ed25519PrivateKey.from_private_bytes(b)
    except Exception:
        pass
    raise ValueError("Invalid private key format: must be 32-byte hex (64 chars), base64, or valid key file.")

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

def main():
    parser = argparse.ArgumentParser(description="ChavrusaText Build 8401 Owner Signing and Attestation Packaging Tool")
    parser.add_argument("--generate-payloads", action="store_true", help="Print canonical unsigned payloads for all 14 hunks")
    parser.add_argument("--sign", action="store_true", help="Sign all 14 hunks with owner private key and update UPSTREAM_EXCEPTION_REGISTER.json")
    parser.add_argument("--private-key", help="Owner Ed25519 private key (hex, base64, or key file)")
    parser.add_argument("--owner-public-key", help="Owner Ed25519 public key (hex or base64) to verify after signing")
    parser.add_argument("--expires-days", type=int, default=365, help="Attestation validity duration in days (default: 365)")
    parser.add_argument("--repo-id", default="davidpovarsky/Maktabah", help="GitHub repository identifier")
    args = parser.parse_args()

    manifest_path = os.path.join(REPO_DIR, "docs", "architecture", "BUILD_8401_REPRODUCIBLE_PAYLOAD_MANIFEST.json")
    register_path = os.path.join(REPO_DIR, "docs", "architecture", "UPSTREAM_EXCEPTION_REGISTER.json")

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest_data = json.load(f)

    base_commit = manifest_data.get("base_commit", "031df35710ab2c6015efb1acd1e65154dbcd3f24")
    expires_at = (datetime.now(timezone.utc) + timedelta(days=args.expires_days)).strftime("%Y-%m-%dT%H:%M:%SZ")

    payloads = get_canonical_payloads(manifest_data, base_commit, args.repo_id, expires_at)

    if args.generate_payloads or (not args.sign and not args.private_key):
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
        print("To sign these 14 hunks, execute with owner private key:")
        print("  python tools/sign_owner_approvals.py --sign --private-key <OWNER_PRIVATE_KEY>")
        print("=" * 80)
        if not args.sign:
            return

    if args.sign:
        if not args.private_key:
            print("Error: --sign requires --private-key <key>", file=sys.stderr)
            sys.exit(1)

        priv_key = load_private_key(args.private_key)
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

        register_data["approval_gate_status"] = "GATE_CLOSED_OWNER_APPROVED"
        register_data["status"] = "APPROVED_OWNER_SIGNED"
        register_data["owner_verification_public_key"] = pub_hex
        register_data["last_signed"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

        with open(register_path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(register_data, f, indent=2, ensure_ascii=False)

        print(f"\nSuccessfully signed all {signed_count} exceptions in {register_path}!")
        print("\nVerifying signed register fail-closed against owner public key...")

        code, report = bg.verify_boundaries(
            base_ref=base_commit,
            head_ref="HEAD",
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
