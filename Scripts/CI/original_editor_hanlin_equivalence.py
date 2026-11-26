"""Exact reviewed Hanlin package equivalence for the original binary SDK.

An immutable producer revision remains the producer revision. A consumer may
use a different monorepo commit only when every shared package tree is identical
and its additional MiniApps Bridge/Picker source is independently complete.
"""
import hashlib
import json
from pathlib import Path
import re
import subprocess

SHARED_ROOTS = ("Packages/HanlinAgentSDK", "Packages/HanlinPlatform", "Packages/HanlinPresentationSDK")
BRIDGE_ROOT = "Packages/HanlinMiniAppsBridge"
MINIAPPS_TREES = (BRIDGE_ROOT, BRIDGE_ROOT + "/Sources/HanlinMiniAppsBridge",
                 BRIDGE_ROOT + "/Sources/HanlinMiniAppsPicker")
SCOPE = "BYTE_IDENTICAL_SHARED_PACKAGES_ONLY_NO_NEW_NATIVE_CREDIT"


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def git(root, *arguments):
    result = subprocess.run(["git", "-C", str(root), *arguments], capture_output=True, timeout=90)
    require(result.returncode == 0, "Cannot verify original Hanlin Git objects: "
            + result.stderr.decode(errors="replace")[-1500:])
    return result.stdout


def read_committed_review(root, pin):
    require(isinstance(pin, dict) and set(pin) == {"path", "sha256"},
            "Hanlin equivalence requires an exact committed review")
    name, expected = pin["path"], pin["sha256"]
    require(isinstance(name, str) and name.startswith("Scripts/CI/") and name.endswith(".json")
            and Path(name).as_posix() == name and not Path(name).is_absolute()
            and ".." not in Path(name).parts and "\n" not in name and "\r" not in name
            and isinstance(expected, str) and re.fullmatch(r"[a-f0-9]{64}", expected),
            "Invalid Hanlin equivalence review path or digest")
    root = Path(root).resolve(strict=True)
    path = root / name
    require(path.is_file() and not path.is_symlink() and path.resolve(strict=True).is_relative_to(root)
            and digest(path) == expected, "Hanlin equivalence review bytes differ")
    raw = git(root, "show", "HEAD:" + name)
    require(raw == path.read_bytes(), "Hanlin equivalence review is not the committed file")
    return json.loads(raw)


def read_review(root, pin, producer_revision):
    review = read_committed_review(root, pin)
    require(review.get("schema") == "otzaria.shared-hanlin-source-equivalence/1"
            and review.get("scope") == SCOPE
            and review.get("sdk_producer_revision") == producer_revision
            and re.fullmatch(r"[a-f0-9]{40}", review.get("consumer_revision", ""))
            and review.get("miniapps_producer_revision") == review["consumer_revision"],
            "Hanlin equivalence review has different producer or consumer identity")
    for key, paths in (("shared_trees", SHARED_ROOTS), ("miniapps_shared_trees", MINIAPPS_TREES)):
        rows = review.get(key)
        require(isinstance(rows, dict) and set(rows) == set(paths)
                and all(isinstance(value, str) and re.fullmatch(r"[a-f0-9]{40}", value) for value in rows.values()),
                "Hanlin equivalence review omits complete shared package/module trees")
    return {"pin": pin, "review": review}


def tree(root, revision, path):
    return git(root, "rev-parse", revision + ":" + path).decode().strip()


def leaves(root, revision, paths):
    result = {}
    for row in git(root, "ls-tree", "-r", "-z", revision, "--", *paths).split(b"\0"):
        if not row:
            continue
        metadata, path = row.split(b"\t", 1)
        mode, kind, blob = metadata.decode().split()
        name = path.decode()
        require(kind == "blob" and mode in ("100644", "100755") and name not in result,
                "Hanlin package contains an unsupported or duplicate source entry")
        result[name] = blob
    return result


def verify_hanlin_sources(root, shared, source):
    root = Path(root)
    sdk = root / "Vendor/HanlinSDK"
    owner = shared["ownership"]
    all_files = source["git_blobs"]
    producer = shared["hanlin_revision"]
    equivalence = shared.get("host_source_equivalence")
    proof = {"producer_hanlin_revision": producer, "host_hanlin_revision": source["sha"],
             "source_equivalence": None, "additional_miniapps_files": 0}
    if equivalence is None:
        require(source["sha"] == producer, "Host Hanlin revision differs")
        require(all_files and all(p.startswith(tuple(x + "/" for x in SHARED_ROOTS)) for p in all_files),
                "Host and producer package/resource/manifest/lock memberships differ")
        shared_files = all_files
    else:
        pinned = read_review(root, equivalence["pin"], producer)
        require(pinned == equivalence, "Admitted Hanlin equivalence review changed")
        review = pinned["review"]
        consumer = review["consumer_revision"]
        require(source["sha"] == consumer
                and git(root, "rev-parse", "HEAD:Vendor/HanlinSDK").decode().strip() == consumer
                and git(sdk, "rev-parse", "HEAD").decode().strip() == consumer,
                "Actual consumer Hanlin checkout differs from its reviewed revision")
        require(source.get("layout") == [*SHARED_ROOTS, BRIDGE_ROOT]
                and source.get("verified_files") == len(all_files),
                "Consumer Hanlin source inventory does not cover exactly the four original packages")
        for path, expected in review["shared_trees"].items():
            require(tree(sdk, producer, path) == tree(sdk, consumer, path) == expected,
                    "SDK and consumer Hanlin package trees differ: " + path)
        for path, expected in review["miniapps_shared_trees"].items():
            require(tree(sdk, consumer, path) == tree(sdk, review["miniapps_producer_revision"], path) == expected,
                    "Consumer Bridge/Picker tree differs from the actual MiniApps producer: " + path)
        expected = leaves(sdk, consumer, [*SHARED_ROOTS, BRIDGE_ROOT])
        require(all_files == expected, "Consumer Hanlin inventory omits or adds package source")
        working_files = {str(p.relative_to(sdk))
                         for directory in (*SHARED_ROOTS, BRIDGE_ROOT)
                         for p in (sdk / directory).rglob("*")
                         if p.is_file() or p.is_symlink()}
        require(working_files == set(expected),
                "Actual consumer Hanlin packages contain missing or additional source files")
        shared_files = {p: value for p, value in all_files.items()
                        if p.startswith(tuple(x + "/" for x in SHARED_ROOTS))}
        bridge_files = {p: value for p, value in all_files.items() if p.startswith(BRIDGE_ROOT + "/")}
        require(bridge_files, "Original shared MiniApps package is absent")
        for name, expected_blob in bridge_files.items():
            path = sdk / name
            require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(sdk.resolve()),
                    "MiniApps Bridge/Picker source is missing or aliased")
            raw = path.read_bytes()
            actual = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
            require(actual == expected_blob, "Actual MiniApps Bridge/Picker source bytes differ: " + name)
        proof.update(source_equivalence=pinned, additional_miniapps_files=len(bridge_files))
    require(shared_files and shared_files.keys() == owner["hanlin_package_files"].keys(),
            "Host and producer package/resource/manifest/lock memberships differ")
    for name, expected in owner["hanlin_package_files"].items():
        path = sdk / name
        require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(sdk.resolve())
                and digest(path) == expected, "Host and producer share different Hanlin package bytes: " + name)
    proof["shared_hanlin_files"] = len(shared_files)
    return all_files, proof


MINIAPPS_SCOPE = "EXACT_BRIDGE_WITH_REVIEWED_PICKER_HIT_AREA_ONLY_NO_NEW_NATIVE_CREDIT"
PICKER_PATH = BRIDGE_ROOT + "/Sources/HanlinMiniAppsPicker/MiniAppPicker.swift"


def build_miniapps_review(sdk, producer_revision, consumer_revision):
    """Describe the two real source roles; allow only the reviewed picker hit area."""
    require(all(isinstance(value, str) and re.fullmatch(r"[a-f0-9]{40}", value)
                for value in (producer_revision, consumer_revision)), "Invalid MiniApps source revision")
    inventories = {}
    contents = {}
    for role, revision in (("producer", producer_revision), ("consumer", consumer_revision)):
        blobs = leaves(sdk, revision, [BRIDGE_ROOT])
        require(blobs and PICKER_PATH in blobs, "Original MiniApps shared package is incomplete")
        inventories[role], contents[role] = {}, {}
        for name, blob in sorted(blobs.items()):
            raw = git(sdk, "cat-file", "blob", blob)
            contents[role][name] = raw
            inventories[role][name] = {
                "blob": blob, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}
    producer_files, consumer_files = inventories["producer"], inventories["consumer"]
    require(producer_files.keys() == consumer_files.keys(),
            "Producer and consumer MiniApps package memberships differ")
    require(not git(sdk, "diff", "--summary", producer_revision, consumer_revision, "--", BRIDGE_ROOT),
            "MiniApps compatibility cannot admit source mode changes or renames")
    producer_trees = {name: tree(sdk, producer_revision, name) for name in MINIAPPS_TREES}
    consumer_trees = {name: tree(sdk, consumer_revision, name) for name in MINIAPPS_TREES}
    bridge = BRIDGE_ROOT + "/Sources/HanlinMiniAppsBridge"
    require(producer_trees[bridge] == consumer_trees[bridge],
            "Actual MiniApps transport and contract source trees differ")
    changed = [name for name in producer_files if producer_files[name] != consumer_files[name]]
    require(changed in ([], [PICKER_PATH]),
            "Only the reviewed original picker hit area may differ")
    picker_change = None
    if changed:
        before, after = contents["producer"][PICKER_PATH], contents["consumer"][PICKER_PATH]
        anchor = (b"        .frame(maxWidth: .infinity, alignment: .leading)\n"
                  b"    }\n    private func update")
        replacement = (b"        .frame(maxWidth: .infinity, alignment: .leading)\n"
                       b"        .contentShape(Rectangle())\n"
                       b"    }\n    private func update")
        require(before.count(anchor) == 1 and after == before.replace(anchor, replacement, 1),
                "Picker source differs beyond the single original row hit-area insertion")
        picker_change = {"path": PICKER_PATH, "operation": "ADD_NATIVE_ROW_CONTENT_SHAPE",
                         "producer_blob": producer_files[PICKER_PATH]["blob"],
                         "consumer_blob": consumer_files[PICKER_PATH]["blob"]}
    return {
        "schema": "otzaria.miniapps-source-equivalence/1",
        "scope": MINIAPPS_SCOPE,
        "producer": {"repository": "davidpovarsky/hanlin-ai",
                     "revision": producer_revision, "target": "HanlinMiniApps"},
        "consumer": {"repository": "davidpovarsky/hanlin-ai",
                     "revision": consumer_revision, "target": "Maktabah-iOS",
                     "modules": ["HanlinMiniAppsBridge", "HanlinMiniAppsPicker"]},
        "producer_trees": producer_trees, "consumer_trees": consumer_trees,
        "producer_files": producer_files, "consumer_files": consumer_files,
        "reviewed_picker_change": picker_change,
    }


def read_miniapps_review(root, pin, producer_revision, consumer_revision):
    """Admit an immutable review before the normal original SDK preparation."""
    review = read_committed_review(root, pin)
    require(review.get("schema") == "otzaria.miniapps-source-equivalence/1"
            and review.get("scope") == MINIAPPS_SCOPE
            and review.get("producer") == {"repository": "davidpovarsky/hanlin-ai",
                "revision": producer_revision, "target": "HanlinMiniApps"}
            and review.get("consumer") == {"repository": "davidpovarsky/hanlin-ai",
                "revision": consumer_revision, "target": "Maktabah-iOS",
                "modules": ["HanlinMiniAppsBridge", "HanlinMiniAppsPicker"]},
            "MiniApps review names different producer or consumer targets")
    for role in ("producer", "consumer"):
        trees = review.get(role + "_trees")
        files = review.get(role + "_files")
        require(isinstance(trees, dict) and set(trees) == set(MINIAPPS_TREES)
                and all(isinstance(value, str) and re.fullmatch(r"[a-f0-9]{40}", value)
                        for value in trees.values()),
                "MiniApps review omits complete shared package/module trees")
        require(isinstance(files, dict) and files and all(
            isinstance(name, str) and name.startswith(BRIDGE_ROOT + "/")
            and isinstance(row, dict) and set(row) == {"blob", "sha256", "bytes"}
            and isinstance(row["blob"], str) and re.fullmatch(r"[a-f0-9]{40}", row["blob"])
            and isinstance(row["sha256"], str) and re.fullmatch(r"[a-f0-9]{64}", row["sha256"])
            and type(row["bytes"]) is int and row["bytes"] >= 0
            for name, row in files.items()), "MiniApps review has invalid package file hashes")
    return {"pin": pin, "review": review}


def verify_miniapps_sources(root, producer_revision, consumer_revision, pinned=None):
    """Check the installed host source and both complete immutable package trees."""
    root = Path(root)
    sdk = root / "Vendor/HanlinSDK"
    require(git(root, "rev-parse", "HEAD:Vendor/HanlinSDK").decode().strip() == consumer_revision
            and git(sdk, "rev-parse", "HEAD").decode().strip() == consumer_revision,
            "Actual consumer Hanlin gitlink or checkout differs")
    review = build_miniapps_review(sdk, producer_revision, consumer_revision)
    if pinned is None:
        require(producer_revision == consumer_revision,
                "Different MiniApps producer and consumer need an exact committed review")
    else:
        require(read_miniapps_review(root, pinned["pin"], producer_revision, consumer_revision) == pinned
                and pinned["review"] == review,
                "MiniApps compatibility review differs from complete original Git source")
    expected = review["consumer_files"]
    working = {str(path.relative_to(sdk)) for path in (sdk / BRIDGE_ROOT).rglob("*")
               if path.is_file() or path.is_symlink()}
    require(working == set(expected), "Actual MiniApps package has missing or additional files")
    for name, row in expected.items():
        path = sdk / name
        require(path.is_file() and not path.is_symlink()
                and path.resolve(strict=True).is_relative_to(sdk.resolve(strict=True))
                and path.stat().st_size == row["bytes"] and digest(path) == row["sha256"],
                "Actual MiniApps shared package bytes differ: " + name)
    return {"status": "EXACT_MINIAPPS_SOURCE_COMPATIBILITY_VERIFIED", "scope": MINIAPPS_SCOPE,
            "source_review": review, "review_pin": None if pinned is None else pinned["pin"],
            "verified_files": len(expected), "new_native_acceptance": False}
