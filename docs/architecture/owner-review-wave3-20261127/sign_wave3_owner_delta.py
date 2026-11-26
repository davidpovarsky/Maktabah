#!/usr/bin/env python3
"""Check or sign the exact two-file Wave 3 owner delta using the existing identity.

The check mode reads public material only. The explicit sign mode is
Windows-only and decrypts the existing DPAPI key in memory after every frozen
source, manifest, prior-signature and two-path scope check succeeds. It writes
only a new output directory, never the checkout or the historical wrappers.
"""
import argparse
import copy
from datetime import datetime, timedelta, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys

sys.dont_write_bytecode = True

CANDIDATE = "0db0ab78cfde4845bfe3a7e2621ca31d630acd56"
PRODUCT_SOURCE = "22fd689971ebe6506087cd85d740f54d5d9f36e5"
BASE = "157729471b649a023a81f923be33fb7bfa6e41c9"
UPSTREAM = "a0ed0df908a6cb38bc459d4baaeb400f447b2fc4"
REPOSITORY = "davidpovarsky/Maktabah"
TRUSTED_VERIFIER_COMMIT = "978db8b37256d4dd2d58e91a0ea8d531798221c0"
VERIFIER_SHA256 = "9733798a242382f59da99cb999a169e2c69c59010b336742e9a8fa151e837676"
SIGNER_SHA256 = "07e94cbb190d28d1a0f086f77d47bd8d921cea69bc87a130bd36829cfc0d0006"
MANIFEST_SHA256 = "ed750de696a80d908d7cce2d61a8785075d68d57d8ab5f69aa14679b420a79da"
REGISTRY_PATH = "docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json"
REGISTRY_BLOB = "bc4f30808a2e7fa0ad48e406891bed5399583fc3"
REGISTRY_SHA256 = "5bd809034fa0c97cc05655ae216af4201543a6754ea3408013ed48d4eab85a1a"
SUPERSEDED_SHA256 = "f24f4c15fbda7aeeac9e67d4a715ef522c928898e8ae2aaf7bf53a0f5b575672"
PUBLIC_KEY_SHA256 = "b0f0fa39ad1b59595699cd7eaef340a17567c9ff8dbe1408c2372c2a5866818b"
INFORMATIONAL_RECORDS = {
    "GLOBAL_SEARCH_1220546245946205_20261115": "AUTHORIZED_SCOPED_IMPLEMENTATION_NATIVE_ACCEPTANCE_OPEN",
    "CONTINUATION_20261117_READER_OFFMAIN": "IMPLEMENTED_NATIVE_VALIDATION_PENDING",
    "CONTINUATION_20261117_PHONE_GLOBAL_ROUTING": "IMPLEMENTED_NATIVE_VALIDATION_PENDING",
    "CONTINUATION_20261118_NATIVE_READER_TEXT_WITNESS": "IMPLEMENTED_NATIVE_VALIDATION_PENDING",
    "CONTINUATION_20261118_NATIVE_READER_CORE_FENCE": "IMPLEMENTED_NATIVE_VALIDATION_PENDING",
}
EXPECTED = {
    "Source/Features/Reader/ViewModel/BookTOCViewModel.swift": {
        "patch_id": "OWNER_PATCH_017",
        "head_blob_sha": "cefdba7518894946196c7678a8f108e9e3bc19ae",
        "patch_digest_sha256": "56ce55811f160d8712d37fa6adcca0cd8ced8c04f3851d13fbb7d8ef49493f84",
    },
    "Source/Localizable.xcstrings": {
        "patch_id": "OWNER_PATCH_040",
        "head_blob_sha": "a60bff78654244052bf0d213c34a90bef502694c",
        "patch_digest_sha256": "48372a55dcf21df42ac8cbb0b6f471a034aea1c42bfa728b17704462f027c398",
    },
}
POLICY_BLOBS = {
    "Scripts/CI/verify-upstream-boundary.py": "1b40d104b261c2b86821d9681cc4b08b79fb2f9a",
    "docs/architecture/UPSTREAM_INTEGRITY_POLICY.md": "8999f5329b0045f56f280c903f40a91e500fd36b",
}


class ReviewError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ReviewError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def git(repo, *args):
    return subprocess.check_output(["git", *args], cwd=repo, timeout=90)


def text(repo, *args):
    return git(repo, *args).decode("utf-8").strip()


def json_bytes(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def regular_file(path, label):
    require(path.is_file() and not path.is_symlink(), label + " must be a regular non-symlink file")
    return path.read_bytes()


def import_signer(repo):
    for relative, digest in (
        ("tools/verify_upstream_boundary.py", VERIFIER_SHA256),
        ("tools/sign_owner_approvals.py", SIGNER_SHA256),
    ):
        committed = git(repo, "show", CANDIDATE + ":" + relative)
        actual = regular_file(repo / relative, relative).replace(b"\r\n", b"\n")
        require(sha(committed) == digest and actual == committed,
                "Canonical signing code differs: " + relative)
    trusted = git(repo, "show", TRUSTED_VERIFIER_COMMIT + ":tools/verify_upstream_boundary.py")
    require(sha(trusted) == VERIFIER_SHA256, "Trusted verifier object differs")
    spec = importlib.util.spec_from_file_location("wave3_canonical_owner_signer", repo / "tools/sign_owner_approvals.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def verify_old_record(entry, public_hex, public_key, guard, now):
    attestation = entry.get("owner_attestation", {})
    expected = {
        "repo": REPOSITORY, "approval_id": entry["patch_id"], "base_sha": BASE,
        "expected_head_blob_sha": entry["expected_head_blob_sha"],
        "patch_digest_sha256": entry["patch_digest_sha256"], "signer_public_key": public_hex,
    }
    require(entry.get("status") == "APPROVED" and entry.get("approval_ref") == entry["patch_id"],
            "Existing record has conflicting identity/status")
    require(all(attestation.get(k) == v for k, v in expected.items()), "Existing attestation aliases differ")
    expiry = datetime.fromisoformat(attestation["expires_at"].replace("Z", "+00:00"))
    require(expiry.tzinfo is not None and expiry > now, "Existing approval has expired")
    message = guard.construct_canonical_attestation_payload(
        REPOSITORY, entry["path"], BASE, entry["expected_head_blob_sha"],
        entry["patch_digest_sha256"], entry["patch_id"], attestation["expires_at"])
    public_key.verify(bytes.fromhex(attestation["signature"]), message)


def preflight(repo, manifest_path, external_public_key_file):
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

    repo = repo.resolve(strict=True)
    require(text(repo, "rev-parse", "HEAD") == CANDIDATE, "Checkout must equal the frozen candidate")
    require(not git(repo, "status", "--porcelain", "--untracked-files=no"),
            "Tracked checkout must be clean")
    for ancestor in (BASE, PRODUCT_SOURCE):
        subprocess.run(["git", "merge-base", "--is-ancestor", ancestor, CANDIDATE],
                       cwd=repo, check=True, timeout=90)
    for relative, blob in POLICY_BLOBS.items():
        require(text(repo, "rev-parse", CANDIDATE + ":" + relative) == blob,
                "Owner-approved policy differs")
    external = regular_file(external_public_key_file, "External public key").decode("ascii").strip()
    require(re.fullmatch(r"[0-9a-f]{64}", external) is not None,
            "External owner public key must be lowercase 64-hex")
    require(sha(bytes.fromhex(external)) == PUBLIC_KEY_SHA256,
            "External owner public-key fingerprint differs")
    public_key = Ed25519PublicKey.from_public_bytes(bytes.fromhex(external))
    signer = import_signer(repo)
    guard = signer.bg
    manifest_raw = regular_file(manifest_path, "Reviewed manifest")
    require(sha(manifest_raw) == MANIFEST_SHA256, "Reviewed manifest bytes differ")
    manifest = json.loads(manifest_raw)
    require(manifest.get("base_commit") == BASE and manifest.get("head_commit") == CANDIDATE
            and manifest.get("pinned_upstream_sha") == UPSTREAM
            and manifest.get("total_patches") == 55
            and manifest.get("patch_format") == "git-full-index-v1", "Reviewed manifest contract differs")
    signer.validate_manifest_preconditions(manifest, str(manifest_path.parent), str(repo))
    upstream_files = guard.get_tree_files(UPSTREAM, str(repo))
    changes = guard.parse_raw_diff(
        ["git", "diff", "--raw", "--no-renames", "-z", BASE, CANDIDATE], str(repo))
    protected = {row["path"] for row in changes if guard.is_protected_path(row["path"], upstream_files)}
    rows = manifest["patches"]
    require(len(rows) == 55 and {row["path"] for row in rows} == protected,
            "Manifest does not exactly cover the actual 55 protected paths")
    registry_raw = git(repo, "show", CANDIDATE + ":" + REGISTRY_PATH)
    require(sha(registry_raw) == REGISTRY_SHA256
            and text(repo, "rev-parse", CANDIDATE + ":" + REGISTRY_PATH) == REGISTRY_BLOB,
            "Existing registry differs from the reviewed before-image")
    registry = json.loads(registry_raw)
    require(registry.get("owner_verification_public_key") == external,
            "Registry and external owner key differ")
    active_list = [entry for entry in registry["exceptions"] if entry.get("status") == "APPROVED"]
    active = {entry["path"]: entry for entry in active_list}
    require(len(active_list) == len(active) == 55 and set(active) == protected,
            "Existing approved inventory differs")
    informational = [entry for entry in registry["exceptions"] if entry.get("status") != "APPROVED"]
    require(len(informational) == 5
            and {entry.get("patch_id"): entry.get("status") for entry in informational} == INFORMATIONAL_RECORDS
            and all(entry.get("path") is None and not entry.get("owner_attestation") for entry in informational),
            "The five unrelated informational records differ")
    require(len({entry["patch_id"] for entry in active_list}) == 55, "Existing IDs are not unique")
    now = datetime.now(timezone.utc)
    changed = set()
    for row in rows:
        old = active[row["path"]]
        require(row["patch_id"] == old["patch_id"] == old.get("approval_ref"),
                "Historical approval ID was renumbered")
        require(text(repo, "rev-parse", CANDIDATE + ":" + row["path"]) == row["head_blob_sha"],
                "Reviewed protected blob differs")
        verify_old_record(old, external, public_key, guard, now)
        if (old["expected_head_blob_sha"], old["patch_digest_sha256"]) != (
                row["head_blob_sha"], row["patch_digest_sha256"]):
            changed.add(row["path"])
    require(changed == set(EXPECTED), "Protected change set is not exactly the two reviewed files")
    for row in rows:
        if row["path"] in EXPECTED:
            require(all(row.get(k) == v for k, v in EXPECTED[row["path"]].items()),
                    "Reviewed two-file blob/digest/ID differs")
            require(not active[row["path"]].get("expected_patch_file"),
                    "Changed record has an archive reference requiring separate review")
    superseded_raw = regular_file(manifest_path.parent / "superseded-owner-records.json",
                                 "Superseded record capture")
    require(sha(superseded_raw) == SUPERSEDED_SHA256, "Superseded record capture differs")
    superseded = json.loads(superseded_raw)
    require(superseded == {
        "schema": "otzaria.owner-review-superseded/1", "candidate": CANDIDATE,
        "registry_blob": REGISTRY_BLOB, "registry_sha256": REGISTRY_SHA256,
        "records": [active[path] for path in sorted(EXPECTED)],
    }, "The two original records were not preserved exactly")
    report = {
        "schema": "otzaria.wave3-owner-delta-check/1",
        "status": "REVIEW_PACKET_CHECK_PASS_SIGNING_NOT_RUN",
        "candidate": CANDIDATE, "product_source": PRODUCT_SOURCE, "repository": REPOSITORY,
        "manifest_sha256": MANIFEST_SHA256, "registry_before_sha256": REGISTRY_SHA256,
        "external_public_key_sha256": PUBLIC_KEY_SHA256,
        "verifier_sha256": VERIFIER_SHA256, "canonical_signer_sha256": SIGNER_SHA256,
        "protected_paths": 55, "old_authentic_signatures_verified": 55,
        "reusable_current_signatures": 53, "new_signatures_required": 2,
        "unrelated_informational_records_preserved": 5,
        "changed_paths": sorted(changed), "observed_at": now.isoformat(),
        "private_key_accessed": False, "signing_performed": False,
        "final_owner_release_gate": "NOT_RUN", "native_acceptance": "NOT_CLAIMED",
    }
    return {"repo": repo, "signer": signer, "manifest": manifest, "registry": registry,
            "active": active, "external": external, "public_key": public_key,
            "superseded_raw": superseded_raw, "report": report}


def sign_to_new_output(context, output):
    require(sys.platform == "win32", "Signing requires the existing owner's Windows DPAPI context")
    require(text(context["repo"], "rev-parse", "HEAD") == CANDIDATE
            and not git(context["repo"], "status", "--porcelain", "--untracked-files=no"),
            "Checkout changed after public preflight")
    output = output.resolve()
    require(not output.exists() and output.parent.is_dir() and not output.parent.is_symlink(),
            "Output directory must be new under an existing non-symlink parent")
    require(not output.is_relative_to(context["repo"]), "Signing output must be outside the checkout")
    identity = Path(os.environ["LOCALAPPDATA"]) / "Maktabah" / "OwnerVerification"
    pin = regular_file(identity / "owner-signing.public.hex", "Local public pin").decode("ascii").strip()
    require(pin == context["external"] and sha(bytes.fromhex(pin)) == PUBLIC_KEY_SHA256,
            "Existing local and external owner identities differ")
    # Deliberately imported and read only after all public preflight checks.
    import win32crypt
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives.serialization import load_der_private_key, load_pem_private_key

    encrypted = regular_file(identity / "owner-signing.dpapi", "Existing protected identity")
    _, private_bytes = win32crypt.CryptUnprotectData(encrypted, None, None, None, 1)
    del encrypted
    try:
        if len(private_bytes) == 32:
            private_key = Ed25519PrivateKey.from_private_bytes(private_bytes)
        elif private_bytes.startswith(b"-----BEGIN PRIVATE KEY-----"):
            private_key = load_pem_private_key(private_bytes, password=None)
        else:
            private_key = load_der_private_key(private_bytes, password=None)
    finally:
        del private_bytes
    try:
        require(isinstance(private_key, Ed25519PrivateKey)
                and private_key.public_key().public_bytes_raw().hex() == pin,
                "Recovered key is not the registered existing Ed25519 identity")
        now = datetime.now(timezone.utc)
        signed_at = now.strftime("%Y-%m-%dT%H:%M:%SZ")
        expiry = (now + timedelta(days=365)).strftime("%Y-%m-%dT%H:%M:%SZ")
        signer = context["signer"]
        payloads = signer.get_canonical_payloads(context["manifest"], BASE, REPOSITORY, expiry)
        registry = copy.deepcopy(context["registry"])
        entries = {entry["path"]: entry for entry in registry["exceptions"] if entry.get("status") == "APPROVED"}
        signed = 0
        for payload in payloads:
            if payload["path"] not in EXPECTED:
                continue
            signature = private_key.sign(payload["canonical_bytes"])
            context["public_key"].verify(signature, payload["canonical_bytes"])
            entry = entries[payload["path"]]
            entry["expected_head_blob_sha"] = payload["head_blob_sha"]
            entry["patch_digest_sha256"] = payload["patch_digest_sha256"]
            entry["owner_attestation"] = {
                "repo": REPOSITORY, "approval_id": payload["patch_id"], "base_sha": BASE,
                "expected_head_blob_sha": payload["head_blob_sha"],
                "patch_digest_sha256": payload["patch_digest_sha256"],
                "signer_public_key": pin, "signature": signature.hex(),
                "signed_at": signed_at, "expires_at": expiry,
            }
            signed += 1
        require(signed == 2, "Exactly two signatures are required")
        for path, old in context["active"].items():
            if path not in EXPECTED:
                require(entries[path] == old, "An unchanged approval record was modified")
        for old, current in zip(context["registry"]["exceptions"], registry["exceptions"], strict=True):
            if old.get("path") not in EXPECTED:
                require(current == old, "An unrelated registry record was modified")
        for entry in entries.values():
            verify_old_record(entry, pin, context["public_key"], signer.bg, now)
        require(text(context["repo"], "rev-parse", "HEAD") == CANDIDATE
                and not git(context["repo"], "status", "--porcelain", "--untracked-files=no"),
                "Checkout changed during signing")
        registry.update(
            approval_gate_status="GATE_CLOSED_OWNER_APPROVED", status="APPROVED_OWNER_SIGNED",
            last_signed=signed_at, baseline_commit=BASE,
            owner_review={"source_sha": CANDIDATE, "manifest_sha256": MANIFEST_SHA256})
        registry_raw = json_bytes(registry)
    finally:
        del private_key
    receipt = dict(context["report"])
    receipt.update(
        status="TWO_AUTHENTIC_SIGNATURES_CREATED_FINAL_RELEASE_GATE_PENDING",
        signing_performed=True, private_key_accessed=True, new_signatures_created=2,
        preserved_current_records=53, registry_after_sha256=sha(registry_raw),
        superseded_records_sha256=SUPERSEDED_SHA256, signed_at=signed_at,
        bridge_sha256=sha(Path(__file__).read_bytes().replace(b"\r\n", b"\n")))
    output.mkdir(exist_ok=False)
    values = {
        "UPSTREAM_EXCEPTION_REGISTER.json": registry_raw,
        "superseded-owner-records.json": context["superseded_raw"],
        "signing-receipt.json": json_bytes(receipt),
    }
    for name, raw in values.items():
        with (output / name).open("xb") as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
    sums = "".join(sha(values[name]) + "  " + name + "\n" for name in sorted(values))
    with (output / "SHA256SUMS").open("x", encoding="ascii", newline="\n") as stream:
        stream.write(sums)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("check", "sign"))
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, default=Path(__file__).with_name("manifest.json"))
    parser.add_argument("--external-public-key-file", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path)
    args = parser.parse_args()
    try:
        require((args.mode == "sign") == (args.out_dir is not None),
                "Only explicit sign mode accepts and requires a new output directory")
        context = preflight(args.repo, args.manifest.resolve(strict=True),
                            args.external_public_key_file.resolve(strict=True))
        result = (context["report"] if args.mode == "check"
                  else sign_to_new_output(context, args.out_dir))
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0
    except Exception as error:
        print(json.dumps({"status": "REFUSED", "error_type": type(error).__name__,
                          "error": str(error)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
