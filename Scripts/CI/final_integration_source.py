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
VENDOR_REVIEW_SOURCE = "24cd9291dbc87d799c22a41f0bc73a82c6415bfa"
VENDOR_REVIEW_PATH = "Scripts/CI/reviewed-vendor-source.inputs.json"
VENDOR_REVIEW_SHA256 = "43e166c8b19e6bd5fdba5395246e31b2a089db4ed9f39c510b91e8188830db32"
VENDOR_REVIEW_TREE = "9e4f188c5bedeef55ce95d97943f5e5046b6f3d6"
VENDOR_JS_PATHS = ["Vendor/SefariaMobile/Integration/JS/" + name for name in
                   ("ChavrusaRoot.js", "ChavrusaVisibleSurface.js",
                    "ChavrusaVisibleSurfaceRegistry.js", "chavrusaRPCFacade.js")]
VENDOR_NATIVE_PATH = "Vendor/SefariaMobile/Integration/iOS/ChavrusaSefariaBridgeModule.swift"
VENDOR_SWIFT_PATH = "Vendor/ZayitSearchPort/Swift/ZayitSearchViewModel.swift"
VENDOR_REVIEW_PATHS = sorted(["Vendor/HanlinSDK", *VENDOR_JS_PATHS,
                              VENDOR_NATIVE_PATH, VENDOR_SWIFT_PATH])


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


def strict_json(raw):
    def unique(pairs):
        result = {}
        for name, value in pairs:
            require(name not in result, "Duplicate source contract key: " + name)
            result[name] = value
        return result
    return json.loads(raw, object_pairs_hook=unique)


def source_is_ancestor(root, before, after):
    require(all(isinstance(value, str) and re.fullmatch(r"[a-f0-9]{40}", value)
                for value in (before, after)), "Unfrozen source ancestry")
    result = subprocess.run(["git", "merge-base", "--is-ancestor", before, after],
                            cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=90)
    require(result.returncode in (0, 1), "Required source ancestry is unavailable")
    return result.returncode == 0


def requires_reviewed_vendor(root, source):
    # A new checkout cannot downgrade its declaration to a historical source
    # and thereby select the legacy one-facade path.
    return (source_is_ancestor(root, VENDOR_REVIEW_SOURCE, source)
            or source_is_ancestor(root, VENDOR_REVIEW_SOURCE, text(root, "rev-parse", "HEAD")))


def vendor_entries(root, revision, path="Vendor"):
    result = {}
    for row in git(root, "ls-tree", "-r", "-z", revision, "--", path).split(b"\0"):
        if not row:
            continue
        metadata, name = row.decode().split("\t", 1)
        mode, kind, identity = metadata.split()
        require(name == Path(name).as_posix() and "\\" not in name
                and ".." not in Path(name).parts and name.startswith(path + "/")
                and name not in result, "Invalid or duplicate Vendor source path")
        require(mode in ("100644", "100755", "120000", "160000")
                and kind in ("blob", "commit") and re.fullmatch(r"[a-f0-9]{40}", identity),
                "Invalid Vendor source identity")
        result[name] = {"mode": mode, "kind": kind, "object": identity}
    return result


def vendor_patch(root, before, after, path):
    raw = git(root, "diff", "--binary", "--full-index", "--no-ext-diff", before, after, "--", path)
    return {"bytes": len(raw), "sha256": sha(raw)}


def regular_source_bytes(root, name):
    path = relative_file(root, name)
    require(all(not parent.is_symlink() for parent in path.parents if parent != root and root in parent.parents),
            "Aliased source parent: " + name)
    before = path.stat()
    raw = path.read_bytes()
    after = path.stat()
    require((before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns)
            == (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns),
            "Source changed while being read: " + name)
    return raw


def load_vendor_review(root, reference):
    require(reference == {"manifest": VENDOR_REVIEW_PATH, "sha256": VENDOR_REVIEW_SHA256},
            "Missing or unreviewed Wave3 Vendor contract")
    raw = regular_source_bytes(root, VENDOR_REVIEW_PATH)
    require(sha(raw) == VENDOR_REVIEW_SHA256 and raw == git(root, "show", "HEAD:" + VENDOR_REVIEW_PATH),
            "Reviewed Vendor contract bytes changed or are uncommitted")
    value = strict_json(raw)
    require(set(value) == {"schema", "scope", "native_qualified", "reviewed_product_source",
                          "historical_source", "integration_base", "vendor_tree", "entries",
                          "preserved_inventory", "producer_scopes", "build_inputs",
                          "legacy_input_fixture", "evidence"}, "Unexpected Vendor review fields")
    require(value["schema"] == "otzaria.reviewed-vendor-source/1"
            and value["scope"] == "EXACT_DOWNSTREAM_SOURCE_IDENTITY_AND_PRODUCER_ATTRIBUTION_ONLY"
            and value["native_qualified"] is False
            and value["reviewed_product_source"] == VENDOR_REVIEW_SOURCE
            and value["historical_source"] == HISTORICAL_SOURCE
            and value["integration_base"] == INTEGRATION_BASE
            and value["vendor_tree"] == VENDOR_REVIEW_TREE,
            "Unexpected reviewed Vendor source contract")
    require([row["path"] for row in value["entries"]] == VENDOR_REVIEW_PATHS,
            "Vendor review is not the exact seven-path contract")
    require(value["build_inputs"]["single_reviewed_field"] == "embedded_js_overlay_paths"
            and value["build_inputs"]["before"] == [VENDOR_JS_PATHS[-1]]
            and value["build_inputs"]["after"] == VENDOR_JS_PATHS,
            "Unreviewed JS input declaration")
    return value


def verify_vendor_scope(root, source, scope):
    before = vendor_entries(root, scope["producer"], scope["root"])
    after = vendor_entries(root, source, scope["root"])
    paths = [row["path"] for row in scope["changes"]]
    changed = sorted(path for path in before.keys() | after.keys() if before.get(path) != after.get(path))
    require(changed == paths, "Unreviewed producer source delta: " + scope["root"])
    require(text(root, "rev-parse", scope["producer"] + ":" + scope["root"]) == scope["producer_tree"]
            and text(root, "rev-parse", source + ":" + scope["root"]) == scope["accepted_tree"],
            "Producer or accepted source tree changed: " + scope["root"])
    preserved = {path: entry for path, entry in before.items() if path not in paths}
    require(len(before) == scope["producer_entries"] and len(after) == scope["accepted_entries"]
            and len(preserved) == scope["preserved_entries"]
            and all(after.get(path) == entry for path, entry in preserved.items())
            and canonical(preserved) == scope["preserved_entries_sha256"],
            "Original producer inputs were changed or removed: " + scope["root"])
    for row in scope["changes"]:
        require(source_object(root, scope["producer"], row["path"]) == row["before"]
                and source_object(root, source, row["path"]) == row["after"]
                and vendor_patch(root, scope["producer"], source, row["path"]) == row["patch"],
                "Exact producer source patch changed: " + row["path"])
    return {"producer_sha": scope["producer"], "producer_tree": scope["producer_tree"],
            "current_tree": scope["accepted_tree"], "preserved_producer_entries": len(preserved),
            "reviewed_changed_paths": paths}


def verify_reviewed_vendor(root, source, reference):
    root = Path(root).resolve(strict=True)
    if requires_semantic_vendor(root, source) or reference == {"manifest": SEMANTIC_REVIEW_PATH, "sha256": SEMANTIC_REVIEW_SHA256}:
        return verify_semantic_vendor(root, source, reference)
    head = text(root, "rev-parse", "HEAD")
    review = load_vendor_review(root, reference)
    require(source_is_ancestor(root, VENDOR_REVIEW_SOURCE, source)
            and source_is_ancestor(root, source, head), "Reviewed Vendor source ancestry differs")
    require(text(root, "rev-parse", source + ":Vendor") == VENDOR_REVIEW_TREE
            and text(root, "rev-parse", head + ":Vendor") == VENDOR_REVIEW_TREE,
            "Current Vendor tree differs from the exact reviewed source")
    before, after = vendor_entries(root, HISTORICAL_SOURCE), vendor_entries(root, source)
    changed = sorted(path for path in before.keys() | after.keys() if before.get(path) != after.get(path))
    require(changed == VENDOR_REVIEW_PATHS, "Unexpected or missing reviewed Vendor path")
    preserved = {path: entry for path, entry in before.items() if path not in VENDOR_REVIEW_PATHS}
    require(review["preserved_inventory"] == {"historical_entries": len(before),
                "accepted_entries": len(after), "unchanged_entries": len(preserved), "sha256": canonical(preserved)}
            and len(preserved) == 195 and all(after.get(path) == entry for path, entry in preserved.items()),
            "An imported Vendor input changed outside the exact reviewed hooks")
    physical = {}
    for row in review["entries"]:
        path = row["path"]
        require(source_object(root, HISTORICAL_SOURCE, path) == row["historical"]
                and source_object(root, source, path) == row["accepted"]
                and source_object(root, head, path) == row["accepted"]
                and source_object(root, row["component"], path) == row["accepted"]
                and source_is_ancestor(root, row["component"], source),
                "Exact reviewed Vendor component changed: " + path)
        require(vendor_patch(root, HISTORICAL_SOURCE, source, path) == row["historical_patch"],
                "Reviewed Vendor historical patch changed: " + path)
        for step in row["component_steps"]:
            require(text(root, "rev-parse", step["source"] + "^") == step["parent"]
                    and source_is_ancestor(root, step["source"], source)
                    and source_object(root, step["parent"], path) == step["before"]
                    and source_object(root, step["source"], path) == step["after"]
                    and vendor_patch(root, step["parent"], step["source"], path) == step["patch"],
                    "Actual Vendor intake lineage changed: " + path)
        if path != "Vendor/HanlinSDK":
            require(row["accepted"]["mode"] == "100644" and row["accepted"]["kind"] == "blob",
                    "Reviewed integration is not a regular source file")
            raw = regular_source_bytes(root, path)
            require(len(raw) == row["accepted"]["bytes"] and sha(raw) == row["accepted"]["sha256"]
                    and raw == git(root, "show", head + ":" + path),
                    "Working Vendor source differs: " + path)
            physical[path] = sha(raw)
    require(not text(root, "diff", "--name-only", "HEAD", "--", *physical),
            "Reviewed working source content or executable mode changed")
    scopes = {name: verify_vendor_scope(root, source, scope)
              for name, scope in review["producer_scopes"].items()}
    require(set(scopes) == {"zayit", "sefaria"}
            and scopes["zayit"]["reviewed_changed_paths"] == [VENDOR_SWIFT_PATH]
            and scopes["sefaria"]["reviewed_changed_paths"] == sorted([*VENDOR_JS_PATHS, VENDOR_NATIVE_PATH]),
            "Wrong native/JS/Swift consumer source separation")
    for item in review["evidence"]:
        require(source_object(root, item["source"], item["path"]) == item["object"]
                and source_is_ancestor(root, item["source"], source),
                "Historical Vendor provenance was changed or relabelled")
    require(text(root, "rev-parse", "HEAD") == head, "Checkout changed during Vendor admission")
    return {"scope": review["scope"], "manifest": VENDOR_REVIEW_PATH, "manifest_sha256": VENDOR_REVIEW_SHA256,
            "reviewed_product_source": VENDOR_REVIEW_SOURCE, "application_source_sha": source,
            "vendor_tree": VENDOR_REVIEW_TREE, "reviewed_vendor_changes": len(changed),
            "preserved_historical_vendor_entries": len(preserved), "physical_source_sha256": physical,
            "producer_scopes": scopes, "build_inputs": review["build_inputs"],
            "native_qualified": False, "new_app_build_required": True, "new_metro_bundle_required": True}


def verify_reviewed_build_inputs(before, after, review):
    if review.get("manifest") == SEMANTIC_REVIEW_PATH:
        return verify_semantic_build_inputs(before, after, review)
    common = lambda value: {key: item for key, item in value.items() if key not in BINDING_FIELDS}
    binding = review["build_inputs"]
    baseline = common(before)
    expected = dict(baseline)
    expected["embedded_js_overlay_paths"] = VENDOR_JS_PATHS
    require(baseline == binding["baseline_common"]
            and canonical(baseline) == binding["baseline_canonical_sha256"]
            and baseline["embedded_js_overlay_paths"] == binding["before"]
            and binding["after"] == VENDOR_JS_PATHS
            and common(after) == expected
            and canonical(common(after)) == binding["accepted_canonical_sha256"],
            "Unreviewed engine, resource, artifact or build input transition")
    return {"field": "embedded_js_overlay_paths", "before": binding["before"], "after": VENDOR_JS_PATHS,
            "historical_common_sha256": binding["baseline_canonical_sha256"],
            "current_common_sha256": binding["accepted_canonical_sha256"]}


def reviewed_vendor_source_plan(root, config):
    """One strict source plan used by both original preparation routes."""
    root = Path(root).resolve(strict=True)
    source = config.get("application_source_sha")
    if not requires_reviewed_vendor(root, source):
        return None
    require(config == strict_json(committed_bytes(root, INPUTS)), "Preparation inputs differ from committed source")
    reference = config.get("final_product_source")
    require(isinstance(reference, dict) and set(reference) == {"manifest", "sha256"}
            and reference["manifest"] == "Scripts/CI/final-integration-source.inputs.json"
            and re.fullmatch(r"[a-f0-9]{64}", reference["sha256"]), "Missing exact final source profile")
    raw = committed_bytes(root, reference["manifest"])
    require(sha(raw) == reference["sha256"], "Final source profile digest differs")
    value = strict_json(raw)
    verify_shape(value)
    require(value["application_source_sha"] == source
            and config["application_trees"] == {path: text(root, "rev-parse", source + ":" + path)
                                                for path in ROOTS if path != "Maktabah-iOSUITests"}
            and all(text(root, "rev-parse", "HEAD:" + path) == identity
                    for path, identity in config["application_trees"].items()),
            "Preparation is not bound to the actual application source trees")
    review = verify_reviewed_vendor(root, source, value.get("reviewed_vendor_source"))
    before = strict_json(git(root, "show", INTEGRATION_BASE + ":" + INPUTS))
    transition = verify_build_binding(before, config, value, reference["manifest"], reference["sha256"],
                                      sha(committed_bytes(root, ADDITIONS)), review)
    review["input_transition"] = transition
    js_paths, native_paths = reviewed_vendor_consumer_paths(review)
    review["embedded_bundle_build"] = {
        "mode": "REBUILD_EXACT_REVIEWED_JS", "overlay_paths": js_paths,
        "native_source_paths": native_paths,
        "source_tree": review["producer_scopes"]["sefaria"]["current_tree"],
        "review_contract_sha256": review["manifest_sha256"],
        "historical_bundle_role": "VERIFIED_BASELINE_ONLY_REBUILD_REQUIRED",
        "native_bridge_build_required": True,
        "source_sha256": {path: review["physical_source_sha256"][path]
                          for path in [*js_paths, *native_paths]}}
    return review


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


def verify_build_binding(before, after, value, manifest_path, expected_sha256, additions_sha256,
                         vendor_review=None):
    common = lambda data: {key: item for key, item in data.items() if key not in BINDING_FIELDS}
    transition = None
    if vendor_review is None:
        require(common(before) == common(after)
                and canonical(common(after)) == value["preserved_build_inputs_canonical_sha256"],
                "Retained engine, resource, artifact or build input changed")
    else:
        transition = verify_reviewed_build_inputs(before, after, vendor_review)
        require(value.get("reviewed_build_input_transition") == transition
                and value["preserved_build_inputs_canonical_sha256"] == canonical(common(before)),
                "Reviewed source-input transition or historical input identity changed")
    require(set(after) == set(before) | {"final_product_source"}, "Undeclared build input field")
    require(after["application_source_sha"] == value["application_source_sha"]
            and after["application_trees"] == {key: value["application_trees"][key]
                                               for key in ROOTS if key != "Maktabah-iOSUITests"}
            and after["hanlin_gitlink"] == value["hanlin_source"]
            and after["otzaria_test_additions_sha256"] == additions_sha256
            and after["final_product_source"] == {"manifest": manifest_path, "sha256": expected_sha256},
            "Integrated build is not bound to the exact reviewed source")
    return transition


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
    vendor_review = None
    if requires_reviewed_vendor(root, source) or "reviewed_vendor_source" in value:
        vendor_review = verify_reviewed_vendor(root, source, value.get("reviewed_vendor_source"))
    else:
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
    transition = verify_build_binding(before, json.loads(after_raw), value, name, expected_sha256,
                                      sha(additions_raw), vendor_review)
    result = {"manifest_sha256": expected_sha256, "historical_control_source": value["historical_control_source"],
            "previous_application_source": HISTORICAL_SOURCE, "application_source_sha": source,
            "application_trees": trees, "hanlin_source": value["hanlin_source"],
            "swift_ai_sdk_source": value["swift_ai_sdk_source"],
            "additional_product_objects_verified": len(value["product_delta"]),
            "product_paths": [row["path"] for row in value["product_delta"]],
            "build_input_sha256": sha(after_raw),
            "preserved_build_inputs_sha256": value["preserved_build_inputs_canonical_sha256"],
            "new_native_build_required": True, "new_runtime_acceptance_required": True,
            "native_stageb_qualified": False}
    if vendor_review is not None:
        result.update(reviewed_vendor_source=vendor_review, reviewed_build_input_transition=transition)
    return result


# A separately reviewed closed transition. The prior contract remains immutable.
SEMANTIC_REVIEW_SOURCE = "a0e3b05df9d914cc886b843524915c509f70a852"
SEMANTIC_REVIEW_PATH = "Scripts/CI/reviewed-vendor-semantics.inputs.json"
SEMANTIC_REVIEW_SHA256 = "8423dae0002cce697d48a1a11d43fdae0a2a06f5c143420a56247fae8ed4e208"
SEMANTIC_REVIEW_TREE = "2fb868bdbe5d2d52735e857a24933918ff658cef"
SEMANTIC_HELPER = "Vendor/SefariaMobile/Integration/JS/ChavrusaVisibleSemanticTargets.js"
SEMANTIC_OBJC_PATH = "Vendor/SefariaMobile/Integration/iOS/ChavrusaSefariaBridgeModule.m"
SEMANTIC_JS_PATHS = sorted([*VENDOR_JS_PATHS, SEMANTIC_HELPER])
SEMANTIC_NATIVE_PATHS = sorted([VENDOR_NATIVE_PATH, SEMANTIC_OBJC_PATH])
SEMANTIC_VENDOR_DELTA = sorted([path for path in VENDOR_JS_PATHS if not path.endswith("/ChavrusaRoot.js")]
                              + [SEMANTIC_HELPER, *SEMANTIC_NATIVE_PATHS])
SEMANTIC_REVIEW_PATHS = sorted(set(VENDOR_REVIEW_PATHS) | set(SEMANTIC_VENDOR_DELTA))


def requires_semantic_vendor(root, source):
    # Both declarations and the actual checkout are fenced. An old declaration
    # cannot choose an old gate after this exact source entered the ancestry.
    return (source_is_ancestor(root, SEMANTIC_REVIEW_SOURCE, source)
            or source_is_ancestor(root, SEMANTIC_REVIEW_SOURCE, text(root, "rev-parse", "HEAD")))


def verify_vendor_snapshot(root, source, review, paths, preserved_count):
    """Recheck frozen Git bytes/lineage; no worktree or acceptance substitution."""
    before, after = vendor_entries(root, HISTORICAL_SOURCE), vendor_entries(root, source)
    changed = sorted(path for path in before.keys() | after.keys() if before.get(path) != after.get(path))
    require(changed == paths and [row["path"] for row in review["entries"]] == paths,
            "Unexpected reviewed snapshot path")
    preserved = {path: entry for path, entry in before.items() if path not in paths}
    require(review["preserved_inventory"] == {"historical_entries": len(before),
                "accepted_entries": len(after), "unchanged_entries": len(preserved), "sha256": canonical(preserved)}
            and len(preserved) == preserved_count
            and all(after.get(path) == entry for path, entry in preserved.items()),
            "Original imported Vendor leaves changed")
    require(text(root, "rev-parse", source + ":Vendor") == review["vendor_tree"],
            "Reviewed snapshot tree changed")
    for row in review["entries"]:
        path = row["path"]
        require(source_object(root, HISTORICAL_SOURCE, path) == row["historical"]
                and source_object(root, source, path) == row["accepted"]
                and source_object(root, row["component"], path) == row["accepted"]
                and source_is_ancestor(root, row["component"], source)
                and vendor_patch(root, HISTORICAL_SOURCE, source, path) == row["historical_patch"],
                "Reviewed component source or patch changed: " + path)
        for step in row["component_steps"]:
            require(text(root, "rev-parse", step["source"] + "^") == step["parent"]
                    and source_is_ancestor(root, step["source"], source)
                    and source_object(root, step["parent"], path) == step["before"]
                    and source_object(root, step["source"], path) == step["after"]
                    and vendor_patch(root, step["parent"], step["source"], path) == step["patch"],
                    "Reviewed snapshot intake step changed: " + path)
    return after


def load_semantic_vendor_review(root, reference):
    require(reference == {"manifest": SEMANTIC_REVIEW_PATH, "sha256": SEMANTIC_REVIEW_SHA256},
            "Missing exact semantic Vendor transition; old contract cannot qualify new source")
    raw = regular_source_bytes(root, SEMANTIC_REVIEW_PATH)
    require(sha(raw) == SEMANTIC_REVIEW_SHA256
            and raw == git(root, "show", "HEAD:" + SEMANTIC_REVIEW_PATH),
            "Semantic Vendor contract changed or is uncommitted")
    value = strict_json(raw)
    require(set(value) == {"schema", "scope", "native_qualified", "reviewed_product_source",
        "historical_source", "integration_base", "vendor_tree", "previous_review", "transition",
        "entries", "preserved_inventory", "producer_scopes", "build_inputs", "legacy_input_fixture", "evidence"},
        "Unexpected semantic Vendor contract field")
    require(value["schema"] == "otzaria.reviewed-vendor-semantic-source/1"
            and value["scope"] == "EXACT_DOWNSTREAM_SOURCE_IDENTITY_AND_PRODUCER_ATTRIBUTION_ONLY"
            and value["native_qualified"] is False
            and value["reviewed_product_source"] == SEMANTIC_REVIEW_SOURCE
            and value["historical_source"] == HISTORICAL_SOURCE
            and value["integration_base"] == INTEGRATION_BASE
            and value["vendor_tree"] == SEMANTIC_REVIEW_TREE,
            "Unexpected semantic Vendor snapshot")
    return value


def verify_semantic_vendor(root, source, reference):
    root = Path(root).resolve(strict=True)
    head = text(root, "rev-parse", "HEAD")
    old = load_vendor_review(root, {"manifest": VENDOR_REVIEW_PATH, "sha256": VENDOR_REVIEW_SHA256})
    review = load_semantic_vendor_review(root, reference)
    require(source_is_ancestor(root, VENDOR_REVIEW_SOURCE, SEMANTIC_REVIEW_SOURCE)
            and source_is_ancestor(root, SEMANTIC_REVIEW_SOURCE, source)
            and source_is_ancestor(root, source, head), "Semantic source intake ancestry differs")
    require(text(root, "rev-parse", source + ":Vendor") == SEMANTIC_REVIEW_TREE
            and text(root, "rev-parse", head + ":Vendor") == SEMANTIC_REVIEW_TREE,
            "Current Vendor tree differs from the exact semantic source")
    require(review["previous_review"] == {"manifest": VENDOR_REVIEW_PATH, "sha256": VENDOR_REVIEW_SHA256,
        "source": VENDOR_REVIEW_SOURCE, "vendor_tree": VENDOR_REVIEW_TREE,
        "object": source_object(root, head, VENDOR_REVIEW_PATH)}, "Previous reviewed contract was replaced")
    previous = verify_vendor_snapshot(root, VENDOR_REVIEW_SOURCE, old, VENDOR_REVIEW_PATHS, 195)
    after = verify_vendor_snapshot(root, source, review, SEMANTIC_REVIEW_PATHS, 194)
    delta = sorted(path for path in previous.keys() | after.keys() if previous.get(path) != after.get(path))
    transition = review["transition"]
    require(set(transition) == {"entries", "unchanged_previous_entries", "unchanged_previous_entries_sha256",
        "single_reviewed_field", "before", "after", "before_common_sha256", "after_common_sha256"}
        and delta == SEMANTIC_VENDOR_DELTA
        and [row["path"] for row in transition["entries"]] == SEMANTIC_VENDOR_DELTA,
        "Unreviewed semantic path addition, removal or mode")
    preserved = {path: entry for path, entry in previous.items() if path not in SEMANTIC_VENDOR_DELTA}
    require(len(preserved) == transition["unchanged_previous_entries"]
            and canonical(preserved) == transition["unchanged_previous_entries_sha256"]
            and all(after.get(path) == entry for path, entry in preserved.items()),
            "A previous reviewed Vendor input changed outside the six semantic hooks")
    old_rows = {row["path"]: row for row in old["entries"]}
    current_rows = {row["path"]: row for row in review["entries"]}
    for path, row in old_rows.items():
        if path not in SEMANTIC_VENDOR_DELTA:
            require(current_rows[path] == row, "Unchanged previous component metadata was relabelled")
    for row in transition["entries"]:
        path, step = row["path"], row["component_step"]
        require(set(row) == {"path", "before", "after", "patch", "component_step"}
                and row["before"] == source_object(root, VENDOR_REVIEW_SOURCE, path)
                and row["after"] == source_object(root, source, path)
                and row["patch"] == vendor_patch(root, VENDOR_REVIEW_SOURCE, source, path)
                and step["before"] == row["before"] and step["after"] == row["after"]
                and current_rows[path]["component"] == step["source"]
                and current_rows[path]["component_steps"] == old_rows.get(path, {}).get("component_steps", []) + [step],
                "Exact six-path semantic intake step changed: " + path)
    require(review["producer_scopes"]["zayit"] == old["producer_scopes"]["zayit"],
            "Semantic transition relabelled an engine producer")
    for scope in old["producer_scopes"].values():
        verify_vendor_scope(root, VENDOR_REVIEW_SOURCE, scope)
    scopes = {name: verify_vendor_scope(root, source, scope)
              for name, scope in review["producer_scopes"].items()}
    require(set(scopes) == {"zayit", "sefaria"}
            and scopes["zayit"]["reviewed_changed_paths"] == [VENDOR_SWIFT_PATH]
            and scopes["sefaria"]["reviewed_changed_paths"] == sorted([*SEMANTIC_JS_PATHS, *SEMANTIC_NATIVE_PATHS])
            and review["producer_scopes"]["sefaria"]["producer"] == old["producer_scopes"]["sefaria"]["producer"],
            "Wrong native/JS/compiled-engine source separation")
    old_inputs, inputs = old["build_inputs"], review["build_inputs"]
    old_common = dict(old_inputs["baseline_common"], embedded_js_overlay_paths=VENDOR_JS_PATHS)
    current_common = dict(old_common, embedded_js_overlay_paths=SEMANTIC_JS_PATHS)
    require(inputs == dict(old_inputs, after=SEMANTIC_JS_PATHS,
                           accepted_canonical_sha256=canonical(current_common))
            and transition["single_reviewed_field"] == "embedded_js_overlay_paths"
            and transition["before"] == VENDOR_JS_PATHS and transition["after"] == SEMANTIC_JS_PATHS
            and transition["before_common_sha256"] == canonical(old_common) == old_inputs["accepted_canonical_sha256"]
            and transition["after_common_sha256"] == canonical(current_common),
            "Semantic transition changed more than the exact fifth JS input")
    require(review["legacy_input_fixture"] == old["legacy_input_fixture"] and review["evidence"] == old["evidence"],
            "Historical fixture or provenance was relabelled")
    for item in review["evidence"]:
        require(source_object(root, item["source"], item["path"]) == item["object"]
                and source_is_ancestor(root, item["source"], source), "Historical Vendor evidence changed")
    physical = {}
    for row in review["entries"]:
        path = row["path"]
        if path == "Vendor/HanlinSDK":
            continue
        require(row["accepted"]["mode"] == "100644" and row["accepted"]["kind"] == "blob"
                and source_object(root, head, path) == row["accepted"], "Semantic source mode or object differs")
        raw = regular_source_bytes(root, path)
        require(len(raw) == row["accepted"]["bytes"] and sha(raw) == row["accepted"]["sha256"]
                and raw == git(root, "show", head + ":" + path), "Working semantic source differs: " + path)
        physical[path] = sha(raw)
    require(not text(root, "diff", "--name-only", "HEAD", "--", *physical),
            "Semantic source content or executable mode changed")
    require(text(root, "rev-parse", "HEAD") == head, "Checkout changed during semantic admission")
    return {"scope": review["scope"], "manifest": SEMANTIC_REVIEW_PATH,
        "manifest_sha256": SEMANTIC_REVIEW_SHA256, "reviewed_product_source": SEMANTIC_REVIEW_SOURCE,
        "application_source_sha": source, "vendor_tree": SEMANTIC_REVIEW_TREE,
        "reviewed_vendor_changes": len(SEMANTIC_REVIEW_PATHS), "preserved_historical_vendor_entries": 194,
        "physical_source_sha256": physical, "producer_scopes": scopes, "build_inputs": inputs,
        "previous_review": review["previous_review"], "source_transition": transition,
        "native_qualified": False, "new_app_build_required": True, "new_metro_bundle_required": True}


def verify_semantic_build_inputs(before, after, review):
    require(review.get("manifest") == SEMANTIC_REVIEW_PATH
            and review.get("manifest_sha256") == SEMANTIC_REVIEW_SHA256,
            "Unpinned semantic build-input contract")
    common = lambda value: {key: item for key, item in value.items() if key not in BINDING_FIELDS}
    baseline = common(before)
    binding = review["build_inputs"]
    expected = dict(baseline, embedded_js_overlay_paths=SEMANTIC_JS_PATHS)
    require(baseline == binding["baseline_common"]
            and canonical(baseline) == binding["baseline_canonical_sha256"]
            and baseline["embedded_js_overlay_paths"] == binding["before"] == [VENDOR_JS_PATHS[-1]]
            and binding["after"] == SEMANTIC_JS_PATHS
            and common(after) == expected
            and canonical(expected) == binding["accepted_canonical_sha256"],
            "Unreviewed semantic engine, resource, artifact or build input")
    return {"field": "embedded_js_overlay_paths", "before": binding["before"], "after": SEMANTIC_JS_PATHS,
        "historical_common_sha256": binding["baseline_canonical_sha256"],
        "current_common_sha256": binding["accepted_canonical_sha256"]}


def reviewed_vendor_consumer_paths(review):
    if review["manifest"] == SEMANTIC_REVIEW_PATH and review["manifest_sha256"] == SEMANTIC_REVIEW_SHA256:
        return SEMANTIC_JS_PATHS, SEMANTIC_NATIVE_PATHS
    require(review["manifest"] == VENDOR_REVIEW_PATH and review["manifest_sha256"] == VENDOR_REVIEW_SHA256,
            "Unknown reviewed Vendor consumer source plan")
    return VENDOR_JS_PATHS, [VENDOR_NATIVE_PATH]
