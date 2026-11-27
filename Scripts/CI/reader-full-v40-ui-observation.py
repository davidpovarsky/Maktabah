#!/usr/bin/env python3
"""Separate full-v40 Reader/Inspector observations on an explicitly retained install.

The old full-v32 driver remains the strict default. This adapter reuses its
original native UI/trace/source/SQL oracles and legacy IPC field names, never its
corpus identity or installation acceptance. Prior installer receipts keep their
original source; current app/test/SDK images require a new same-checkout build.
"""
import argparse
import contextlib
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import sqlite3
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
INPUTS = Path(__file__).with_suffix(".inputs.json")
CATALOG = "docs/hq-integration/wave2-20261127/reader/FullV40ObservationCatalog.swift"
SELECTED = [
    "FaithfulProductionReleaseTests/testTwentyOriginalFullV40ReaderOpensAndForcedRelaunch",
    "FaithfulProductionReleaseTests/testOriginalFullV40InspectorRelationshipScalesAndReturn",
]
SOURCE = {
    "repository": "Otzaria/SeforimLibrary", "releaseID": 455390662,
    "releaseTag": "v40-20261123094345", "assetID": 782942035,
    "assetName": "seforim-schema7.db.zst.manifest.json",
    "assetBytes": 2129902636,
    "assetSHA256": "39a2b52129323ea53ac3629835c4721e25acff010a8fc971bf076a666a3b9587",
    "manifestAssetBytes": 589,
    "manifestSHA256": "ab51577bad2f457e24ab5f28082ba830597951ab5738a39652dec821e1dff2e3",
    "databaseBytes": 4355063808,
    "databaseSHA256": "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01",
    "counts": {"book": 8259, "line": 7925185, "link": 7001824},
}

def require(value, message):
    if not value:
        raise ValueError(message)

def validate_profile(config, *, require_frozen):
    require(config.get("schema") == "otzaria.full-v40.original-ui-observation/1", "Wrong v40 schema")
    require(config.get("selected_case_ids") == SELECTED, "Only the two separately named v40 cases are admitted")
    require(config.get("source_database") == SOURCE, "Independent official v40 release/database pins changed")
    require(config.get("installation_policy") == "REUSE_EXPLICIT_ROOT_OWNED_VERIFIED_V40_INSTALL",
            "v40 observations cannot manufacture or borrow an unspecified installation")
    if require_frozen:
        targets = config.get("catalog_targets")
        require(isinstance(targets, dict) and set(targets) == {"books", "retainedChapter"}, "Unfinalized v40 target catalog")
        books = targets["books"]
        require(isinstance(books, list) and len(books) == 3
                and all(set(row) == {"bookID", "title", "lineCount"}
                        and type(row["bookID"]) is int and row["bookID"] > 0
                        and isinstance(row["title"], str) and row["title"]
                        and type(row["lineCount"]) is int and row["lineCount"] >= 3 for row in books)
                and [row["bookID"] for row in books] == [103, 28, 3152]
                and [row["lineCount"] for row in books] == [2875, 2678, 528]
                and all(not row["title"].startswith("UNFINALIZED") for row in books),
                "Three independently queried v40 books required")
        chapter = targets["retainedChapter"]
        require(isinstance(chapter, dict) and set(chapter) == {
            "bookID", "focusLineIndex", "unitID", "unitRowCount", "unitStartLineIndex", "unitEndLineIndex",
            "sourceUTF16Length"}, "Retained v40 chapter identity is not frozen")
        require(chapter["bookID"] == 8042 and chapter["unitRowCount"] == 52332
                and chapter["sourceUTF16Length"] == 8307947
                and chapter["bookID"] not in {row["bookID"] for row in books}
                and isinstance(chapter["unitID"], str) and re.fullmatch(r"toc:[0-9]+", chapter["unitID"])
                and all(type(chapter[key]) is int and chapter[key] >= 0 for key in (
                    "focusLineIndex", "unitStartLineIndex", "unitEndLineIndex"))
                and chapter["unitStartLineIndex"] <= chapter["focusLineIndex"] <= chapter["unitEndLineIndex"],
                "Retained actual v40 chapter changed or remains unfinalized")

def validate_native_installation(native):
    require(native.get("passed") is True and native.get("phase") == "install"
            and native.get("profileID") == "production" and native.get("quickCheck", "").lower() == "ok",
            "Prior original native production installation did not pass")
    for key in ("releaseID", "releaseTag", "assetID", "assetName"):
        require(native.get(key) == SOURCE[key], "Original v40 installer source identity differs: " + key)
    require(native.get("actualSHA256") == SOURCE["assetSHA256"]
            and native.get("expectedSHA256") in (None, SOURCE["assetSHA256"])
            and native.get("expectedCompressedBytes") == SOURCE["assetBytes"]
            and native.get("extractedBytes") == SOURCE["databaseBytes"]
            and native.get("bookCount") == SOURCE["counts"]["book"]
            and native.get("lineCount") == SOURCE["counts"]["line"],
            "Prior native v40 archive/database integrity differs")

def relocated_database(original_path, udid, container):
    """Use the original relative DB path under this same device's actual app container."""
    original = Path(original_path)
    parts = original.parts
    require(original.is_absolute() and ".." not in parts, "Prior database path must be an absolute nonescaping path")
    candidates = [i for i, value in enumerate(parts) if value == "Devices" and i + 7 < len(parts)
                  and parts[i + 1].upper() == udid and parts[i + 2:i + 6] == ("data", "Containers", "Data", "Application")]
    require(len(candidates) == 1, "Prior database is not in the explicitly owned simulator's application container")
    index = candidates[0]
    require(str(uuid.UUID(parts[index + 6])).upper() == parts[index + 6].upper(), "Prior app container identity is invalid")
    relative = Path(*parts[index + 7:])
    require(not relative.is_absolute() and ".." not in relative.parts
            and relative.name == "seforim.db" and relative.parent.name == "Otzaria",
            "Prior database relative location is invalid")
    current = Path(container) / relative
    return current, {"original_path": str(original), "current_path": str(current),
        "relative_path": relative.as_posix(), "changed": str(original) != str(current),
        "reason": "Query current same-UDID app data container after installing the current qualified build; require identical v40 bytes and installation manifest"}

class RetainedV40Installation:
    def __init__(self, core, udid, result):
        self.core, self.udid, self.result_path = core, udid, Path(result).resolve(strict=True)
        self.receipts = {}

    def read_receipt(self, name, limit=2_000_000):
        path = self.result_path.parent / name
        data = self.core.bounded_json(path, limit)
        self.receipts[name] = self.core.witness(path)
        return data

    def admit_owner(self, config, runtime, supported_types):
        require(self.result_path.name == "RESULT.json", "Pass the original installation controller RESULT.json")
        require(str(uuid.UUID(self.udid)).upper() == self.udid, "Explicit canonical simulator UUID required")
        report = self.read_receipt("RESULT.json")
        require(report.get("status") == "ORIGINAL_INTEGRATED_V40_NATIVE_PASS"
                and report.get("created_owned_simulator") == self.udid
                and report.get("owned_simulator_cleanup") == "SHUTDOWN_RETAINED_FOR_ADDITIONAL_ACCEPTANCE"
                and report.get("native_exit") == report.get("evidence_admission_exit") == 0,
                "An explicitly retained successful original v40 install on this exact UDID is required")
        require(re.fullmatch(r"[0-9a-f]{40}", report.get("checkout_sha", ""))
                and isinstance(report.get("inputs_before"), dict) and report["inputs_before"]
                and isinstance(report.get("build_before"), dict) and report["build_before"]
                and isinstance(report.get("app_binary_before"), dict) and report["app_binary_before"]
                and report.get("inputs_before") == report.get("inputs_after")
                and report.get("build_before") == report.get("build_after")
                and report.get("app_binary_before") == report.get("app_binary_after")
                and isinstance(report.get("build_before", {}).get("complete_native_images"), dict),
                "Prior installer source/build attribution is incomplete")
        require(report["runtime"]["identifier"] == runtime["identifier"], "Retained installation uses another runtime")
        device_type = report["device_type"]
        require(device_type in supported_types, "Retained original iPad type differs from the supported qualified type")
        devices = self.core.json_command(["xcrun", "simctl", "list", "devices", "-j"])["devices"]
        actual = [d for rows in devices.values() for d in rows if d.get("udid") == self.udid]
        require(len(actual) == 1 and actual[0].get("state") == "Shutdown"
                and actual[0].get("deviceTypeIdentifier") == device_type["identifier"],
                "Explicit retained simulator is absent, changed, or currently active")
        self.native = self.read_receipt("otzaria-native-bootstrap-acceptance.json")
        validate_native_installation(self.native)
        archive = self.read_receipt(SOURCE["assetName"], limit=4096)
        manifest_record = self.receipts[SOURCE["assetName"]]
        require(manifest_record["bytes"] == SOURCE["manifestAssetBytes"]
                and manifest_record["sha256"] == SOURCE["manifestSHA256"]
                and archive.get("size") == SOURCE["assetBytes"]
                and archive.get("sha256") == SOURCE["assetSHA256"],
                "Retained official multipart manifest differs from its independent GitHub digest")
        self.corpus = self.read_receipt("actual-installed-corpus.json")
        require(self.corpus.get("read_only") is True and self.corpus.get("counts") == SOURCE["counts"]
                and self.corpus["database"]["path"] == self.native["finalPath"]
                and self.corpus["database"]["bytes"] == SOURCE["databaseBytes"]
                and self.corpus["database"]["sha256"] == SOURCE["databaseSHA256"], "Prior actual v40 corpus differs")
        self.cleanup = self.read_receipt("actual-filesystem-cleanup.json")
        absence = self.cleanup.get("all_temporary_paths_absent", {})
        require(set(absence) == {"seforim.db.zst.part", "seforim.db.zst.part.json", "seforim.db.zst.parts", "seforim.db.zst.assembling"}
                and all(value is True for value in absence.values())
                and self.cleanup.get("staging_glob_leftovers") == [], "Prior safe cleanup was not verified")
        index = self.read_receipt("ARTIFACT_INDEX.json", limit=8_000_000)
        indexed = {row["path"]: row for row in index["files"]}
        for name, record in self.receipts.items():
            if name != "ARTIFACT_INDEX.json":
                require(indexed.get(record["path"]) == record, "Original installation receipt was changed: " + name)
        self.prior = {"result": self.receipts["RESULT.json"], "installer_checkout_sha": report["checkout_sha"],
            "installer_build": report["build_before"], "installer_inputs": report["inputs_before"],
            "scope": "Historical successful installation on the explicit retained UDID; not installation acceptance of the current observation build"}
        return self.udid, device_type, {"reused_external_owned_simulator": self.udid,
            "original_installation": self.prior, "external_simulator_will_be_retained": True}

    def verify_prior_receipts(self):
        require(all(self.core.witness(record["path"]) == record for record in self.receipts.values()),
                "An original installation receipt changed during observation")
        return dict(self.receipts)

    def verify_installed_images(self, udid, build):
        records = {}
        products = self.core.ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator"
        for product in ("Maktabah.app", "Maktabah-iOSUITests-Runner.app"):
            # Before XCTest, only the main app has necessarily been installed.
            if product != "Maktabah.app" and not getattr(self, "require_test_runner", False):
                continue
            info = plistlib.loads((products / product / "Info.plist").read_bytes())
            container = Path(self.core.command(["xcrun", "simctl", "get_app_container", udid,
                info["CFBundleIdentifier"], "app"], timeout=45).stdout.strip()).resolve(strict=True)
            prefix = (products / product).relative_to(self.core.ROOT).as_posix() + "/"
            expected = {name[len(prefix):]: value for name, value in build["complete_native_images"].items() if name.startswith(prefix)}
            require(expected and info["CFBundleExecutable"] in expected, "Current built native image closure is absent")
            actual = {}
            magic = {b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xce", b"\xfe\xed\xfa\xcf",
                     b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca", b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca"}
            for path in sorted(container.rglob("*")):
                require(not path.is_symlink(), "Installed native bundle has an unexpected alias")
                if path.is_file():
                    with path.open("rb") as stream:
                        header = stream.read(8)
                    if header[:4] in magic or header == b"!<arch>\n":
                        actual[path.relative_to(container).as_posix()] = {"bytes": path.stat().st_size, "sha256": self.core.digest(path)}
            require(actual == expected, "Current installed app/SDK/test image bytes differ from the current qualified build: " + product)
            records[product] = {"installed_app_container": str(container), "images": actual}
        return records

    def current_database(self, udid):
        container = Path(self.core.command(["xcrun", "simctl", "get_app_container", udid, self.core.BUNDLE, "data"], timeout=45).stdout.strip()).resolve(strict=True)
        require("/devices/" + udid.lower() + "/data/" in container.as_posix().lower(), "Actual app container belongs to another device")
        path, relocation = relocated_database(self.native["finalPath"], udid, container)
        require(not path.is_symlink() and path.resolve(strict=True).is_relative_to(container), "Current database escaped its actual app container")
        database = path.resolve(strict=True)
        manifest = database.parent / "seforim-installation.json"
        installed = self.core.bounded_json(manifest, 131072)
        record = self.core.witness(manifest)
        require(all(record[key] == self.cleanup["installation_manifest"][key] for key in ("bytes", "sha256"))
                and installed.get("releaseID") == SOURCE["releaseID"]
                and installed.get("assetID") == SOURCE["assetID"] and installed.get("repository") == SOURCE["repository"],
                "Actual installation manifest is not the original successfully installed v40 manifest")
        return database, relocation

    def admit_current_installation(self, config, udid, build):
        database, relocation = self.current_database(udid)
        require(database.stat().st_size == SOURCE["databaseBytes"] and self.core.digest(database) == SOURCE["databaseSHA256"],
                "Current installed database bytes differ from the independently pinned full v40 corpus")
        record = self.core.witness(database.parent / "seforim-installation.json")
        with contextlib.closing(sqlite3.connect(database.as_uri() + "?mode=ro&immutable=1", uri=True)) as sql:
            sql.execute("PRAGMA query_only=ON")
            counts = {table: sql.execute("SELECT COUNT(*) FROM " + table).fetchone()[0] for table in ("book", "line", "link")}
            require(counts == SOURCE["counts"], "Actual immutable SQL full-v40 corpus counts differ")
            schema = sql.execute("SELECT type,name,tbl_name,sql FROM sqlite_master ORDER BY type,name").fetchall()
            user_version = sql.execute("PRAGMA user_version").fetchone()[0]
            indexes = {table: sql.execute("PRAGMA index_list(" + table + ")").fetchall()
                       for table in ("book", "line", "link", "link_coverage", "link_suppressed_side")}
        current_images = self.verify_installed_images(udid, build)
        self.require_test_runner = True
        result = {"native_report": self.receipts["otzaria-native-bootstrap-acceptance.json"],
            "database": self.core.witness(database), "installation_manifest": record, "counts": counts,
            "original_installation": self.prior, "original_receipts": self.verify_prior_receipts(),
            "data_container_relocation": relocation, "current_installed_images_before_ui": current_images,
            "current_build_receipt": build["build_receipt"],
            "native_report_expected_sha_present": self.native.get("expectedSHA256") is not None,
            "independent_compressed_digest_required": SOURCE["assetSHA256"],
            "schema_sha256": hashlib.sha256(json.dumps(schema, ensure_ascii=False).encode()).hexdigest(),
            "sqlite_user_version": user_version, "sqlite_version": sqlite3.sqlite_version, "actual_indexes": indexes,
            "uri": database.as_uri() + "?mode=ro&immutable=1"}
        self.core.write(self.core.OUT / "actual-full-v40-installation.json", result)
        return database, result

    def retain_simulator(self, udid):
        # Ownership stays with the original installer/integration controller.
        # End our exact app session and restore the observed shutdown state.
        self.core.command(["xcrun", "simctl", "terminate", udid, self.core.BUNDLE], check=False)
        shutdown = self.core.command([sys.executable, "Scripts/CI/shutdown-faithful-simulator.py", udid], timeout=240, check=False)
        devices = self.core.json_command(["xcrun", "simctl", "list", "devices", "-j"])["devices"]
        actual = [d for rows in devices.values() for d in rows if d.get("udid") == udid]
        require(shutdown.returncode == 0 and len(actual) == 1 and actual[0].get("state") == "Shutdown",
                "External simulator retention/shutdown is unverified")
        return {"status": "SHUTDOWN_RETAINED_FOR_INTEGRATION_OWNER", "udid": udid, "actual_device": actual[0]}

def load_core():
    spec = importlib.util.spec_from_file_location("original_full_corpus_observation", ROOT / "Scripts/CI/reader-full-v32-ui-observation.py")
    core = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(core)
    core.INPUTS, core.CORPUS_NAME = INPUTS, "full-v40"
    core.OBSERVATION_SCHEMA = "otzaria.full-v40.original-ui-observation/1"
    core.OUT = ROOT / "build/artifacts/reader-full-v40-ui-observation"
    core.CATALOG_SOURCE, core.SELECTED = ROOT / CATALOG, SELECTED
    original = core.source_context
    def source_context(require_frozen):
        validate_profile(json.loads(INPUTS.read_text()), require_frozen=require_frozen)
        return original(require_frozen)
    core.source_context = source_context
    return core

def require_exact_inspector_scales(core):
    """Keep authentic at-least observations; separately gate exact v40 sizes.

    Called only by this wrapper's native execute entry point. The shared v32
    host, its historical results, and other load_core consumers are unchanged.
    Exact cardinality does not qualify row bodies or any performance metric.
    """
    receipt = {
        "schema": "otzaria.full-v40.exact-inspector-final-gate/1",
        "status": "NOT_MET",
        "requested_counts": [100, 500, 2000],
        "full_performance_acceptance": False,
        "full_row_rendering_acceptance": False,
        "scope": "Exact natural cached cardinality of three original native UI observations only",
    }
    destination = core.OUT / "v40-exact-inspector-final-gate.json"
    require(not destination.exists(), "Never overwrite a prior final-gate receipt")
    failure = None
    try:
        report_path = core.OUT / "result.json"
        scales_path = core.OUT / "original-inspector-scales.json"
        report = core.bounded_json(report_path, 8_000_000)
        completion = core.bounded_json(scales_path, 2_000_000)
        receipt["native_result"] = core.witness(report_path)
        receipt["original_scales"] = core.witness(scales_path)
        require(report.get("corpus_profile") == "full-v40"
                and report.get("status") == "ORIGINAL_UI_OBSERVATIONS_COMPLETE_METRICS_REVIEW_REQUIRED"
                and report.get("database_bytes_unchanged") is True
                and report.get("source_and_built_binary_bytes_unchanged") is True
                and isinstance(report.get("source"), dict) and report["source"]
                and report.get("cleanup_or_post_verification_failures") == [],
                "Original full-v40 UI completion and immutable postchecks are required")
        udid = report.get("reused_external_owned_simulator")
        require(isinstance(udid, str) and str(uuid.UUID(udid)).upper() == udid,
                "The native result must bind the explicit retained simulator")
        scales = completion.get("scales")
        ids = completion.get("observationIDs")
        require(isinstance(scales, list) and len(scales) == 3
                and isinstance(ids, list) and ids and len(ids) == len(set(ids)),
                "Retain the original complete unique observation set")
        selected = [row.get("observationID") for row in scales]
        require(all(isinstance(value, str) and value in ids for value in selected)
                and len(set(selected)) == 3,
                "Each exact scale needs its own original native observation")
        actual = [row.get("actualCount") for row in scales]
        requested = [row.get("requestedCount") for row in scales]
        receipt.update(actual_counts=actual, observed_requested_counts=requested,
                       observation_ids=selected, simulator_udid=udid,
                       observed_source=report.get("source"))
        require(all(type(value) is int for value in actual + requested)
                and requested == actual == [100, 500, 2000]
                and all(row.get("exactRequestedCount") is True for row in scales)
                and completion.get("exact_size_criterion_met") is True
                and completion.get("natural_at_least_workloads_met") is True,
                "Original at-least workloads do not satisfy exact 100/500/2000 cardinalities")
        receipt["status"] = "MET"
    except Exception as error:
        failure = error
        receipt.update(error_type=type(error).__name__, error=str(error))
    core.write(destination, receipt)
    if failure is not None:
        raise failure


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=["source-check", "execute"])
    parser.add_argument("--owned-simulator")
    parser.add_argument("--installation-result", type=Path)
    parser.add_argument("--inspector-core-source", type=Path)
    args = parser.parse_args()
    core = load_core()
    if args.phase == "execute":
        require(args.owned_simulator and args.installation_result,
                "Explicit root-owned simulator and its original successful installation RESULT.json are required")
        if core.OUT.exists():
            require(not core.OUT.is_symlink()
                    and {p.name for p in core.OUT.iterdir()} <= {"source-only-admission.json"},
                    "Never overwrite prior v40 native observation evidence")
        core.REUSED_INSTALLATION = RetainedV40Installation(core, args.owned_simulator, args.installation_result)
        require(args.inspector_core_source is not None,
                "The existing pinned TorahInspectorCore source directory is required for complete natural-workload validation")
        path = ROOT / "Scripts/CI/reader-v40-natural-inspector-catalog.py"
        spec = importlib.util.spec_from_file_location("full_v40_natural_inspector_catalog", path)
        require(spec is not None and spec.loader is not None, "Natural Inspector host helper is unavailable")
        natural = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(natural)
        # Execute-only: other study/Groups controllers keep the strict original
        # load_core()/ten-target catalog even while a natural scale is missing.
        natural.install(core, core_source=args.inspector_core_source)
    sys.argv = [sys.argv[0], args.phase]
    core.main()
    if args.phase == "execute":
        require_exact_inspector_scales(core)

if __name__ == "__main__":
    main()
