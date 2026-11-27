#!/usr/bin/env python3
"""Real-Git source-admission controls; no framework, Metro, app or native acceptance.

The fixture is a private repository with a read-only object alternate to the
explicit caller repository. Its metadata-only commits bind the real 24cd product
snapshot. They are control inputs, never a final application freeze or approval.
Only the Metro command/artifact restoration and post-build platform boundaries
are substituted. All source validators, Git objects, files and input hashes run.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import time
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
SOURCE = "24cd9291dbc87d799c22a41f0bc73a82c6415bfa"
HISTORICAL = "d3da55417a30e9a06b0255e2d0b561955034b260"
INPUTS = "Scripts/CI/hq-stage2-focused-apple.inputs.json"
MANIFEST = "Scripts/CI/final-integration-source.inputs.json"
ADDITIONS = "Scripts/CI/hq-stage2-otzaria-test-additions.json"
CONTRACT = "Scripts/CI/reviewed-vendor-source.inputs.json"
PROJECT = "Maktabah.xcodeproj/project.pbxproj"
LOCK = "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
ROOTS = ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]
RECORDS = []


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2) + "\n").encode()


def git(root, *args, data=None):
    return subprocess.check_output(["git", "-C", str(root), *args], input=data, timeout=180)


def text(root, *args):
    return git(root, *args).decode().strip()


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Fixture:
    def __init__(self, repository, output):
        self.repository, self.output = repository, output
        self.root = output / "control-checkout"
        self.root.mkdir()
        self.source_module = runpy.run_path(str(HERE / "final_integration_source.py"))
        self.contract = json.loads((HERE / "reviewed-vendor-source.inputs.json").read_bytes())
        self.config = json.loads(git(repository, "show", SOURCE + ":" + INPUTS))
        self.manifest = json.loads(git(repository, "show", SOURCE + ":" + MANIFEST))
        self.additions = json.loads(git(repository, "show", SOURCE + ":" + ADDITIONS))
        git(repository, "show", "08f50a5646b7669d15f8c53cb13c84ac504a02bd:" + ADDITIONS)
        self.build_rows()
        self.manifest["application_source_sha"] = SOURCE
        self.manifest["application_trees"] = {p: text(repository, "rev-parse", SOURCE + ":" + p) for p in ROOTS}
        self.manifest["reviewed_vendor_source"] = {"manifest": CONTRACT, "sha256": sha((HERE / "reviewed-vendor-source.inputs.json").read_bytes())}
        binding = self.contract["build_inputs"]
        self.manifest["reviewed_build_input_transition"] = {
            "field": binding["single_reviewed_field"], "before": binding["before"], "after": binding["after"],
            "historical_common_sha256": binding["baseline_canonical_sha256"],
            "current_common_sha256": binding["accepted_canonical_sha256"]}
        self.additions["excluded_build_inputs"][PROJECT] = text(repository, "rev-parse", SOURCE + ":" + PROJECT)
        self.additions["final_integrated_project_review"]["reviewed_project_blob"] = self.additions["excluded_build_inputs"][PROJECT]
        self.config.update(application_source_sha=SOURCE,
            application_trees={p: self.manifest["application_trees"][p] for p in ROOTS if p != "Maktabah-iOSUITests"},
            embedded_js_overlay_paths=binding["after"],
            otzaria_test_additions_sha256=sha(encoded(self.additions)),
            final_product_source={"manifest": MANIFEST, "sha256": sha(encoded(self.manifest))})
        names = {PROJECT, LOCK, ".github/workflows/sefaria-embedded-validation.yml",
                 ".github/workflows/ios-build.yml", *self.manifest["preserved_historical_receipts"],
                 *(row["path"] for row in self.contract["entries"] if row["path"] != "Vendor/HanlinSDK")}
        self.files = {name: git(repository, "show", SOURCE + ":" + name) for name in sorted(names)}
        self.files.update({INPUTS: encoded(self.config), MANIFEST: encoded(self.manifest), ADDITIONS: encoded(self.additions)})
        for name in ("final_integration_source.py", "hq-stage2-focused-apple.py", "prepare-normal-ios-workspace.py",
                     "reviewed-vendor-source.inputs.json"):
            self.files["Scripts/CI/" + name] = (HERE / name).read_bytes()
        # All named blob reads above use the original repository first, so its
        # existing promisor route obtains exact missing objects before the
        # isolated control alternate is used. No moving ref or remote is used.
        git(self.root, "init", "-q")
        objects = Path(text(repository, "rev-parse", "--path-format=absolute", "--git-path", "objects"))
        (self.root / ".git/objects/info/alternates").write_text(str(objects) + "\n")
        git(self.root, "config", "user.name", "Source admission controls")
        git(self.root, "config", "user.email", "source-controls@example.invalid")
        git(self.root, "config", "core.hooksPath", str(output / "empty-hooks"))
        git(self.root, "read-tree", SOURCE)
        for name, raw in self.files.items():
            self.put(name, raw)
        self.pristine = self.commit("CONTROL ONLY: bind real 24cd product and reviewed source contract", parent=SOURCE)
        self.original_files = copy.deepcopy(self.files)
        self.driver = load_module(self.root / "Scripts/CI/hq-stage2-focused-apple.py", "reviewed_vendor_driver")
        self.adapter = load_module(self.root / "Scripts/CI/prepare-normal-ios-workspace.py", "reviewed_vendor_adapter")
        self.validator = runpy.run_path(str(self.root / "Scripts/CI/final_integration_source.py"))
        self.baseline = output / "original-source"
        self.baseline.mkdir()
        for name in ("final_integration_source.py", "hq-stage2-focused-apple.py", "prepare-normal-ios-workspace.py"):
            (self.baseline / name).write_bytes(git(repository, "show", SOURCE + ":Scripts/CI/" + name))
        (output / "CONTROL_FIXTURE.json").write_bytes(encoded({
            "scope": "ISOLATED_SOURCE_IDENTITY_CONTROL_NOT_FINAL_FREEZE", "native_qualified": False,
            "untouched_promised_blobs_are_not_materialized": True,
            "source": SOURCE, "fixture_commit": self.pristine,
            "accepted_component_count": len(self.manifest["accepted_components"]),
            "product_rows": len(self.manifest["product_delta"]),
            "current_path_origins": self.origins,
            "physical_inputs": {p: {"bytes": len(b), "sha256": sha(b)} for p, b in self.files.items()},
            "baseline_inputs": {p.name: {"bytes": p.stat().st_size, "sha256": sha(p.read_bytes())} for p in self.baseline.iterdir()}}))

    def build_rows(self):
        # Retain every historical accepted component. For a changed current
        # object, name its actual last path-changing ancestor, not one invented
        # umbrella "current source" component. This is a control fixture only.
        prior = {row["path"]: row for row in self.manifest["product_delta"]}
        components = self.manifest["accepted_components"]
        paths = text(self.repository, "diff", "--name-only", HISTORICAL, SOURCE, "--", *ROOTS).splitlines()
        result, self.origins = [], {}
        obj = self.source_module["source_object"]
        for path in paths:
            before, after = obj(self.repository, HISTORICAL, path), obj(self.repository, SOURCE, path)
            old = prior.get(path)
            if old is not None and old["after"] == after and old["adoption"] == "UNCHANGED_COMPONENT_OBJECT":
                result.append(old)
                continue
            revision = text(self.repository, "log", "-1", "--format=%H", SOURCE, "--", path)
            assert obj(self.repository, revision, path) == after
            name = "control_actual_path_ancestor_" + revision
            components[name] = revision
            self.origins[path] = revision
            result.append({"path": path, "before": before, "after": after,
                           "adoption": "UNCHANGED_COMPONENT_OBJECT", "component": name})
        self.manifest["product_delta"] = result

    def put(self, name, raw, mode="100644"):
        path = self.root / name
        if path.exists() or path.is_symlink():
            path.unlink()
        path.parent.mkdir(parents=True, exist_ok=True)
        if mode == "160000":
            oid = raw.decode()
        else:
            oid = git(self.root, "hash-object", "-w", "--stdin", data=raw).decode().strip()
            if mode == "120000":
                path.symlink_to(raw.decode())
            else:
                path.write_bytes(raw)
                path.chmod(0o755 if mode == "100755" else 0o644)
        git(self.root, "update-index", "--add", "--cacheinfo", mode + "," + oid + "," + name)
        self.files[name] = raw

    def commit(self, message, parent=None):
        parent = parent or text(self.root, "rev-parse", "HEAD")
        # The private input is a filtered source clone. Keep untouched original
        # index object IDs without fetching unrelated promised blobs. Every
        # object actually consumed by the validators is read from real Git;
        # this control repository is not a complete build checkout.
        tree = text(self.root, "write-tree", "--missing-ok")
        commit = git(self.root, "commit-tree", tree, "-p", parent, data=(message + "\n").encode()).decode().strip()
        git(self.root, "update-ref", "HEAD", commit)
        return commit

    def reset(self):
        for name in set(self.files) - set(self.original_files):
            path = self.root / name
            if path.is_file() or path.is_symlink():
                path.unlink()
        git(self.root, "read-tree", self.pristine)
        git(self.root, "update-ref", "HEAD", self.pristine)
        self.files = copy.deepcopy(self.original_files)
        for name, raw in self.files.items():
            path = self.root / name
            if path.is_file() or path.is_symlink():
                path.unlink()
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
            path.chmod(0o644)
        self.driver = load_module(self.root / "Scripts/CI/hq-stage2-focused-apple.py", "reviewed_vendor_driver")
        self.adapter = load_module(self.root / "Scripts/CI/prepare-normal-ios-workspace.py", "reviewed_vendor_adapter")
        self.validator = runpy.run_path(str(self.root / "Scripts/CI/final_integration_source.py"))

    def metadata(self, config=None, manifest=None):
        config = copy.deepcopy(self.config) if config is None else config
        if manifest is not None:
            self.put(MANIFEST, encoded(manifest))
            config["final_product_source"] = {"manifest": MANIFEST, "sha256": sha(encoded(manifest))}
        self.put(INPUTS, encoded(config))
        self.commit("CONTROL ONLY: mutated source-admission input")
        return config

    def routes(self, config=None):
        config = json.loads((self.root / INPUTS).read_bytes()) if config is None else config
        ref = config["final_product_source"]
        return {
            "final_source": lambda: self.validator["verify"](self.root, MANIFEST, ref["sha256"]),
            "focused_preflight": lambda: self.driver.preflight(config),
            "normal_source_plan": lambda: self.adapter.embedded_source_plan(self.driver, config)}


class AdmissionTests(unittest.TestCase):
    fixture = None

    def setUp(self):
        self.f = self.fixture
        self.f.reset()

    def refused(self, routes=None):
        snapshot = {"checkout_sha": text(self.f.root, "rev-parse", "HEAD"),
                    "input_sha256": sha((self.f.root / INPUTS).read_bytes()),
                    "manifest_sha256": sha((self.f.root / MANIFEST).read_bytes()),
                    "contract_sha256": sha((self.f.root / CONTRACT).read_bytes())}
        for name, call in (routes or self.f.routes()).items():
            with self.subTest(route=name):
                with self.assertRaises((RuntimeError, subprocess.CalledProcessError, KeyError, FileNotFoundError)) as caught:
                    call()
                RECORDS.append({"test": self.id(), "route": name, "outcome": "REFUSED",
                                "error": str(caught.exception), "actual_inputs": snapshot})

    def test_actual_original_three_routes_reject_current_source(self):
        old = runpy.run_path(str(self.f.baseline / "final_integration_source.py"))
        driver = load_module(self.f.baseline / "hq-stage2-focused-apple.py", "original_focused")
        driver.ROOT = self.f.root
        driver.INPUTS = self.f.root / INPUTS
        driver.TEST_ADDITIONS_MANIFEST = self.f.root / ADDITIONS
        adapter = load_module(self.f.baseline / "prepare-normal-ios-workspace.py", "original_normal")
        config = self.f.config
        self.refused({"original_final_source": lambda: old["verify"](self.f.root, MANIFEST, config["final_product_source"]["sha256"]),
                      "original_focused_preflight": lambda: driver.preflight(config),
                      "original_normal_source_plan": lambda: adapter.embedded_source_plan(driver, config)})

    def test_exact_current_real_git_source_passes_all_three_routes(self):
        for name, call in self.f.routes().items():
            result = call()
            RECORDS.append({"test": self.id(), "route": name, "outcome": "SOURCE_ONLY_PASS", "result": result})
        proof = self.f.driver.reviewed_vendor_source_plan(self.f.config)
        self.assertIs(proof["native_qualified"], False)
        self.assertEqual(proof["preserved_historical_vendor_entries"], 195)
        self.assertEqual(proof["reviewed_vendor_changes"], 7)
        self.assertEqual(len(proof["embedded_bundle_build"]["overlay_paths"]), 4)
        self.assertEqual(len(proof["embedded_bundle_build"]["native_source_paths"]), 1)

    def test_missing_contract_cannot_downgrade(self):
        manifest = copy.deepcopy(self.f.manifest)
        del manifest["reviewed_vendor_source"]
        self.f.metadata(manifest=manifest)
        self.refused()

    def test_backdated_declaration_cannot_select_legacy_on_current_checkout(self):
        old = json.loads((HERE / "fixtures/reviewed-vendor-legacy-inputs.json").read_bytes())
        self.assertTrue(self.f.validator["requires_reviewed_vendor"](self.f.root, old["application_source_sha"]))
        self.f.metadata(config=old)
        self.refused()

    def test_contract_byte_tamper(self):
        self.f.put(CONTRACT, self.f.files[CONTRACT] + b" ")
        self.f.commit("CONTROL ONLY: tamper pinned contract bytes")
        self.refused()

    def test_contract_symlink_is_rejected(self):
        target = self.f.root / "contract-copy.json"
        target.write_bytes(self.f.files[CONTRACT])
        (self.f.root / CONTRACT).unlink()
        (self.f.root / CONTRACT).symlink_to(target)
        self.refused()

    def test_uncommitted_allowed_source_hunk(self):
        path = self.f.contract["build_inputs"]["after"][0]
        (self.f.root / path).write_bytes(self.f.files[path] + b"\n// unreviewed control hunk\n")
        self.refused()

    def test_uncommitted_allowed_source_mode(self):
        path = self.f.contract["build_inputs"]["after"][0]
        (self.f.root / path).chmod(0o755)
        self.refused()

    def test_missing_new_source(self):
        (self.f.root / self.f.contract["build_inputs"]["after"][1]).unlink()
        self.refused()

    def test_historical_receipt_remains_immutable(self):
        path = next(iter(self.f.manifest["preserved_historical_receipts"]))
        self.f.put(path, self.f.files[path] + b"\n")
        self.f.commit("CONTROL ONLY: alter retained original receipt")
        self.refused({"final_source": self.f.routes()["final_source"]})

    def test_inner_producer_patch_and_ancestry_checks_use_real_git(self):
        scope = copy.deepcopy(self.f.contract["producer_scopes"]["zayit"])
        scope["changes"][0]["patch"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(RuntimeError, "patch changed"):
            self.f.validator["verify_vendor_scope"](self.f.root, SOURCE, scope)
        self.assertFalse(self.f.validator["source_is_ancestor"](self.f.root, SOURCE, HISTORICAL))
        with self.assertRaisesRegex(RuntimeError, "Unfrozen source ancestry"):
            self.f.validator["source_is_ancestor"](self.f.root, "main", SOURCE)

    def test_original_metro_command_new_bundle_and_before_after_source(self):
        self.bundle_control("new")

    def test_original_metro_rejects_old_bundle_relabel(self):
        self.bundle_control("old")

    def test_original_metro_rejects_source_change_during_command(self):
        self.bundle_control("mutate")

    def bundle_control(self, mode):
        # The original restored artifact is an explicit command boundary: its
        # pinned digest is supplied only for these exact fixture bytes. New
        # bundle and every source digest use real hashlib and actual files.
        bundle = self.f.root / "build/jsbundle/main.jsbundle"
        bundle.parent.mkdir(parents=True, exist_ok=True)
        baseline = b"EXPLICIT ORIGINAL RESOURCE ARTIFACT BOUNDARY\n"
        bundle.write_bytes(baseline)
        plan = self.f.driver.reviewed_vendor_source_plan(self.f.config)
        report = {"embedded_bundle_build": copy.deepcopy(plan["embedded_bundle_build"]),
                  "resource_inputs": {"jsbundle_sha256": self.f.config["resource_bundle_sha256"]}}
        calls = []
        actual_digest = self.f.driver.digest
        def digest(path):
            if path == bundle and path.read_bytes() == baseline:
                return self.f.config["resource_bundle_sha256"]
            return actual_digest(path)
        def logged(command, filename, report, **kwargs):
            calls.append({"argv": command, "filename": filename, "cwd": str(kwargs["cwd"])})
            if mode != "old":
                bundle.write_bytes(b"NEW METRO COMMAND BOUNDARY OUTPUT\n")
            if mode == "mutate":
                path = self.f.contract["build_inputs"]["after"][1]
                (self.f.root / path).write_bytes(self.f.files[path] + b"\n// changed while bundling\n")
        with mock.patch.object(self.f.driver, "digest", side_effect=digest), mock.patch.object(self.f.driver, "logged", side_effect=logged):
            if mode == "new":
                self.f.driver.prepare_matching_embedded_bundle(self.f.config, report)
                self.assertEqual(report["resource_inputs"]["jsbundle_sha256"], sha(bundle.read_bytes()))
                self.assertNotEqual(report["resource_inputs"]["jsbundle_sha256"], self.f.config["resource_bundle_sha256"])
            else:
                with self.assertRaises(RuntimeError) as caught:
                    self.f.driver.prepare_matching_embedded_bundle(self.f.config, report)
                RECORDS.append({"test": self.id(), "outcome": "REFUSED", "error": str(caught.exception)})
        self.assertEqual(calls, [{"argv": ["npx", "--no-install", "react-native", "bundle",
            "--config", "../Integration/metro.config.embedded.js", "--platform", "ios", "--dev", "false",
            "--entry-file", "../Integration/index.embedded.js", "--bundle-output", str(bundle),
            "--assets-dest", str(bundle.parent)], "filename": "matching-embedded-bundle.log",
            "cwd": str(self.f.root / "Vendor/SefariaMobile/Upstream")}])
        RECORDS.append({"test": self.id(), "boundary": "METRO_NOT_EXECUTED", "calls": calls, "report": report})


def add_input_control(name, mutate):
    def control(self):
        config = copy.deepcopy(self.f.config)
        mutate(config)
        self.f.metadata(config=config)
        self.refused()
    setattr(AdmissionTests, "test_input_" + name, control)


def add_vendor_control(name, path, mode="100644", contents=None):
    def control(self):
        raw = contents
        if raw is None:
            try:
                raw = git(self.f.repository, "show", SOURCE + ":" + path)
                if mode != "100755":
                    raw += b"\nCONTROL EXTRA HUNK\n"
            except subprocess.CalledProcessError:
                raw = b"CONTROL UNDECLARED INPUT\n"
        self.f.put(path, raw, mode)
        changed_source = self.f.commit("CONTROL ONLY: unreviewed Vendor " + name)
        # Direct closed-contract call proves refusal even when a caller names
        # the actual new source. All three public entry points must also refuse.
        with self.assertRaises(RuntimeError):
            self.f.validator["verify_reviewed_vendor"](self.f.root, changed_source,
                                                       self.f.manifest["reviewed_vendor_source"])
        self.refused()
    setattr(AdmissionTests, "test_vendor_" + name, control)


for name, mutate in {
    "old_single_overlay": lambda c: c.update(embedded_js_overlay_paths=[c["embedded_js_overlay_paths"][-1]]),
    "drop_js_input": lambda c: c["embedded_js_overlay_paths"].pop(0),
    "native_as_js": lambda c: c["embedded_js_overlay_paths"].append("Vendor/SefariaMobile/Integration/iOS/ChavrusaSefariaBridgeModule.swift"),
    "resource_producer": lambda c: c.update(resource_producer_sha=HISTORICAL),
    "engine_producer": lambda c: c.update(engine_producer_sha=HISTORICAL),
    "resource_baseline_digest": lambda c: c.update(resource_bundle_sha256="0" * 64),
    "artifact_digest": lambda c: c["artifacts"][0].update(sha256="0" * 64),
    "artifact_id": lambda c: c["artifacts"][0].update(id=c["artifacts"][0]["id"] + 1),
    "artifact_producer_run": lambda c: c["artifacts"][0].update(producer_run=c["artifacts"][0]["producer_run"] + 1),
    "artifact_producer_job": lambda c: c["artifacts"][0].update(producer_job=c["artifacts"][0]["producer_job"] + 1),
    "resource_record": lambda c: c["resources"][next(iter(c["resources"]))].update(sha256="0" * 64),
    "unknown_field": lambda c: c.update(unreviewed_input=True),
    "hanlin_binding": lambda c: c.update(hanlin_gitlink="f8cf6ca543c5ceed05a60141644664c93e4565b4"),
    "test_additions_binding": lambda c: c.update(otzaria_test_additions_sha256="0" * 64),
}.items():
    add_input_control(name, mutate)

for args in [
    ("extra_path", "Vendor/SefariaMobile/Integration/JS/unreviewed.js"),
    ("named_extra_hunk", "Vendor/SefariaMobile/Integration/JS/ChavrusaRoot.js"),
    ("swift_extra_hunk", "Vendor/ZayitSearchPort/Swift/ZayitSearchViewModel.swift"),
    ("imported_rust", "Vendor/ZayitSearchPort/Rust/src/magic_dictionary_index.rs"),
    ("dependency_lock", "Vendor/ZayitSearchPort/Rust/Cargo.lock"),
    ("build_script", "Vendor/ZayitSearchPort/Scripts/build-ios-xcframework.sh"),
    ("resource_configuration", "Vendor/SefariaMobile/Integration/metro.config.embedded.js"),
    ("executable_mode", "Vendor/SefariaMobile/Integration/JS/ChavrusaRoot.js", "100755"),
    ("symlink", "Vendor/SefariaMobile/Integration/JS/ChavrusaVisibleSurface.js", "120000", b"ChavrusaRoot.js"),
    ("hanlin_gitlink", "Vendor/HanlinSDK", "160000", b"f8cf6ca543c5ceed05a60141644664c93e4565b4"),
    ("sefaria_gitlink", "Vendor/SefariaMobile/Upstream", "160000", SOURCE.encode()),
]:
    add_vendor_control(*args)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    repository = args.repository.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        raise RuntimeError("Control output must be exclusive and absent")
    output.mkdir(parents=True)
    start = time.time()
    result = {"scope": "ACTUAL_SOURCE_VALIDATORS_AND_REAL_GIT_ONLY", "native_qualified": False,
              "metro_executed": False, "app_sdk_typecheck": "NOT_RUN", "native": "NOT_RUN"}
    try:
        AdmissionTests.fixture = Fixture(repository, output)
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(AdmissionTests)
        run = unittest.TextTestRunner(verbosity=2).run(suite)
        result.update(tests=run.testsRun, failures=len(run.failures), errors=len(run.errors),
                      status="PASS" if run.wasSuccessful() else "FAIL")
        return 0 if run.wasSuccessful() else 1
    except Exception as error:
        result.update(status="SETUP_FAILED", error=repr(error))
        raise
    finally:
        result.update(duration_s=time.time()-start, records=RECORDS)
        (output / "RESULT.json").write_bytes(encoded(result))


if __name__ == "__main__":
    raise SystemExit(main())
