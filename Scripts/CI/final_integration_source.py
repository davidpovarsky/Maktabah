"""Exact integrated source admission for the real Mac acceptance routes.

This module proves source identity and preservation only. It never confers SDK,
native UI, Release, owner-approval, or TestFlight acceptance.
"""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOTS = ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]
HISTORICAL_SOURCE = "d3da55417a30e9a06b0255e2d0b561955034b260"
INTEGRATION_BASE = "08f50a5646b7669d15f8c53cb13c84ac504a02bd"
INPUTS = "Scripts/CI/hq-stage2-focused-apple.inputs.json"
ADDITIONS = "Scripts/CI/hq-stage2-otzaria-test-additions.json"
PROJECT = "Maktabah.xcodeproj/project.pbxproj"
LOCK = "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
BINDING_FIELDS = {"application_source_sha", "application_trees", "hanlin_gitlink",
                  "otzaria_test_additions_sha256", "final_product_source"}


def require(value, message):
    if not value:
        raise RuntimeError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def canonical(value):
    return sha(json.dumps(value, sort_keys=True, separators=(",", ":")).encode())


def git(root, *args):
    return subprocess.check_output(["git", *args], cwd=root, timeout=90)


def text(root, *args):
    return git(root, *args).decode().strip()


def relative_file(root, name):
    path = Path(name)
    require(isinstance(name, str) and path.as_posix() == name and not path.is_absolute()
            and ".." not in path.parts and path.parts, "Invalid source admission path")
    candidate = root / path
    require(candidate.is_file() and not candidate.is_symlink()
            and candidate.resolve().is_relative_to(root.resolve()), "Missing or aliased source admission file: " + name)
    return candidate


def committed_bytes(root, name):
    raw = relative_file(root, name).read_bytes()
    require(raw == git(root, "show", "HEAD:" + name), "Uncommitted admission input: " + name)
    return raw


def source_object(root, revision, path):
    row = text(root, "ls-tree", revision, "--", path)
    if not row:
        return None
    metadata, actual = row.split("\t")
    require(actual == path, "Source object path differs")
    mode, kind, identity = metadata.split()
    require(mode in ("100644", "100755", "120000", "160000")
            and kind in ("blob", "commit"), "Unsupported source leaf: " + path)
    result = {"mode": mode, "kind": kind, "object": identity}
    if kind == "blob":
        raw = git(root, "show", revision + ":" + path)
        result.update(bytes=len(raw), sha256=sha(raw))
    return result


def verify_shape(value):
    require(value.get("schema") == "otzaria.integrated-product-source/1"
            and value.get("scope") == "SOURCE_IDENTITY_ONLY_REQUIRES_NEW_NATIVE_ACCEPTANCE"
            and value.get("native_qualified") is False
            and value.get("historical_application_source") == HISTORICAL_SOURCE
            and value.get("integration_base") == INTEGRATION_BASE
            and value.get("product_roots") == ROOTS, "Unexpected integrated source contract")
    for key in ("application_source_sha", "hanlin_source", "swift_ai_sdk_source"):
        require(re.fullmatch(r"[a-f0-9]{40}", value.get(key, "")), "Unfrozen source identity: " + key)
    components = value.get("accepted_components")
    require(isinstance(components, dict) and components
            and all(re.fullmatch(r"[a-f0-9]{40}", revision) for revision in components.values()),
            "Component source identities are not frozen")
    rows = value.get("product_delta")
    require(isinstance(rows, list) and rows and all(isinstance(row, dict) for row in rows),
            "Missing complete integrated product delta")
    paths = [row.get("path") for row in rows]
    require(all(isinstance(path, str) and path == Path(path).as_posix()
                and ".." not in Path(path).parts and Path(path).parts[0] in ROOTS for path in paths)
            and paths == sorted(set(paths)), "Invalid, duplicate or unordered product paths")


def verify_rows(root, value):
    source = value["application_source_sha"]
    expected = text(root, "diff", "--name-only", HISTORICAL_SOURCE, source, "--", *ROOTS).splitlines()
    require(expected == [row["path"] for row in value["product_delta"]],
            "An integrated product change is missing or undeclared")
    for row in value["product_delta"]:
        path = row["path"]
        require(row["before"] == source_object(root, HISTORICAL_SOURCE, path)
                and row["after"] == source_object(root, source, path)
                == source_object(root, "HEAD", path), "Exact integrated source object differs: " + path)
        if row["adoption"] == "UNCHANGED_COMPONENT_OBJECT":
            revision = value["accepted_components"].get(row["component"])
            require(revision is not None and row["after"] == source_object(root, revision, path),
                    "Component object was modified during integration: " + path)
        elif row["adoption"] == "EXPLICIT_REVIEWED_MERGE":
            require(isinstance(row.get("reason"), str) and row["reason"].strip(),
                    "Merged product object has no review scope")
            parents = {name: source_object(root, revision, path)
                       for name, revision in value["accepted_components"].items()}
            require(row["component_objects"] == parents, "Merge parent objects differ: " + path)
            patch = git(root, "diff", "--binary", "--full-index", "--no-ext-diff",
                        HISTORICAL_SOURCE, source, "--", path)
            require(row["patch"] == {"bytes": len(patch), "sha256": sha(patch)},
                    "Reviewed merge patch changed: " + path)
        else:
            raise RuntimeError("Unrecognized integrated source adoption")


def verify_build_binding(before, after, value, manifest_path, expected_sha256, additions_sha256):
    common = lambda data: {key: item for key, item in data.items() if key not in BINDING_FIELDS}
    require(common(before) == common(after)
            and canonical(common(after)) == value["preserved_build_inputs_canonical_sha256"],
            "Retained engine, resource, artifact or build input changed")
    require(set(after) == set(before) | {"final_product_source"}, "Undeclared build input field")
    require(after["application_source_sha"] == value["application_source_sha"]
            and after["application_trees"] == {key: value["application_trees"][key]
                                               for key in ROOTS if key != "Maktabah-iOSUITests"}
            and after["hanlin_gitlink"] == value["hanlin_source"]
            and after["otzaria_test_additions_sha256"] == additions_sha256
            and after["final_product_source"] == {"manifest": manifest_path, "sha256": expected_sha256},
            "Integrated build is not bound to the exact reviewed source")


def verify_additions(before, after, project_blob):
    original = {key: item for key, item in before.items() if key != "excluded_build_inputs"}
    require(all(after.get(key) == item for key, item in original.items()),
            "Original engine test additions or historical review changed")
    require(set(after) == set(before) | {"miniapps_project_review", "miniapps_integrated_project_review",
                                        "final_integrated_project_review"},
            "Undeclared engine test-exclusion metadata")
    expected = dict(before["excluded_build_inputs"])
    expected[PROJECT] = project_blob
    require(after["excluded_build_inputs"] == expected,
            "Engine build input changed outside the reviewed app project")
    review = after["final_integrated_project_review"]
    require(review["reviewed_project_blob"] == project_blob
            and review["native_acceptance"] == "NOT_CLAIMED"
            and review["standalone_engine_tests_not_in_app_target"] is True,
            "Integrated project exclusion is not explicitly reviewed")


def verify(root, manifest, expected_sha256):
    root = Path(root).resolve(strict=True)
    manifest = Path(manifest)
    name = manifest.relative_to(root).as_posix() if manifest.is_absolute() else manifest.as_posix()
    require(re.fullmatch(r"[a-f0-9]{64}", expected_sha256 or ""), "Unfrozen source manifest digest")
    raw = committed_bytes(root, name)
    require(sha(raw) == expected_sha256, "Reviewed integrated manifest bytes changed")
    value = json.loads(raw)
    verify_shape(value)
    source = value["application_source_sha"]
    for before, after in [(HISTORICAL_SOURCE, INTEGRATION_BASE), (INTEGRATION_BASE, source), (source, "HEAD")]:
        subprocess.run(["git", "merge-base", "--is-ancestor", before, after], cwd=root, check=True, timeout=90)
    for revision in value["accepted_components"].values():
        subprocess.run(["git", "merge-base", "--is-ancestor", revision, source], cwd=root, check=True, timeout=90)
    trees = {path: text(root, "rev-parse", source + ":" + path) for path in ROOTS}
    require(value["application_trees"] == trees
            and trees == {path: text(root, "rev-parse", "HEAD:" + path) for path in ROOTS},
            "Current product or XCTest trees differ from the reviewed integrated source")
    verify_rows(root, value)
    require(text(root, "rev-parse", source + ":Vendor/HanlinSDK") == value["hanlin_source"],
            "Shared Hanlin source differs")
    lock = json.loads(git(root, "show", source + ":" + LOCK))
    pins = {row["identity"]: row["state"]["revision"] for row in lock["pins"]}
    require(pins.get("swift-ai-sdk") == value["swift_ai_sdk_source"], "Shared Swift AI SDK source differs")
    vendor_delta = text(root, "diff", "--name-only", HISTORICAL_SOURCE, source, "--", "Vendor").splitlines()
    require(vendor_delta == ["Vendor/HanlinSDK"], "An original engine or shared vendor changed without review")
    for path, expected in value["preserved_historical_receipts"].items():
        current = committed_bytes(root, path)
        require(sha(current) == expected and current == git(root, "show", INTEGRATION_BASE + ":" + path),
                "Historical receipt was edited or relabelled: " + path)
    additions_raw = committed_bytes(root, ADDITIONS)
    additions = json.loads(additions_raw)
    prior_additions = json.loads(git(root, "show", INTEGRATION_BASE + ":" + ADDITIONS))
    verify_additions(prior_additions, additions, text(root, "rev-parse", source + ":" + PROJECT))
    project = git(root, "show", source + ":" + PROJECT)
    require(b"Tests/OccurrenceSwift" not in project,
            "Standalone original engine tests entered the application project")
    before = json.loads(git(root, "show", INTEGRATION_BASE + ":" + INPUTS))
    after_raw = committed_bytes(root, INPUTS)
    verify_build_binding(before, json.loads(after_raw), value, name, expected_sha256, sha(additions_raw))
    return {"manifest_sha256": expected_sha256, "historical_control_source": value["historical_control_source"],
            "previous_application_source": HISTORICAL_SOURCE, "application_source_sha": source,
            "application_trees": trees, "hanlin_source": value["hanlin_source"],
            "swift_ai_sdk_source": value["swift_ai_sdk_source"],
            "additional_product_objects_verified": len(value["product_delta"]),
            "product_paths": [row["path"] for row in value["product_delta"]],
            "build_input_sha256": sha(after_raw),
            "preserved_build_inputs_sha256": value["preserved_build_inputs_canonical_sha256"],
            "new_native_build_required": True, "new_runtime_acceptance_required": True,
            "native_stageb_qualified": False}
