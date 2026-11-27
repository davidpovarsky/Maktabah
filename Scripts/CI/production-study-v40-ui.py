#!/usr/bin/env python3
"""Run exact registered study UI cases on an owned, genuinely installed v40.

This extends the retained-v40 source/build/SDK admission. It never installs a
database/index itself, supplies provider responses, or changes the v32 suite.
Each selector gets a separate invocation so dependency order is real rather
than inferred from XCTest's class/method ordering.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import runpy
import shutil
import sys
import time
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[2]
GIB = 1024 ** 3
V41_ARCHIVE_BYTES = 2_124_305_356
V40_DATABASE_BYTES = 4_355_063_808
V40_SHA256 = "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01"
STUDY_PASS = "EXACT_REGISTERED_FULL_V40_STUDY_PHASE_UI_PASS"
POST_UPDATE_PASS = "EXACT_REGISTERED_POST_SETTINGS_V41_SEARCH_UI_AND_HOST_LOG_PASS"
POST_UPDATE_CASE = "PublishedProductionSearchAfterBooksUpdateTests/testOriginalBooksUpdateRetainsV40PackagesButRejectsTheirReadinessAndQueries"
POST_UPDATE_ATTACHMENT = "production-search-after-books-update-original-ui-and-trace-boundary"
PREVIEW_KEYS = {
    "PRODUCTION_SEARCH_PREVIEW_ORACLE",
    "PRODUCTION_SEARCH_PREVIEW_ORACLE_SHA256",
    "PRODUCTION_SEARCH_PREVIEW_SERVICE_SHA256",
    "PRODUCTION_SEARCH_PREVIEW_PRESENTATION_SHA256",
    "PRODUCTION_SEARCH_PREVIEW_COMPILE_SHA256",
}
PHASES = {
    "packages": {
        "cases": ["PublishedProductionSearchDataTests/testPublishedV40PackagesInstallThroughOriginalSearchDataAndColdReopen"],
        "allowance": 6000, "payload_peak": 10_241_792_951, "inputs": set(),
    },
    "pages": {
        "cases": ["PublishedProductionSearchDataTests/testPublishedV40ZayitPages50_100_150RetainSQLIdentity",
                  "PublishedProductionSearchDataTests/testPublishedV40OtzariaPagesRetainCumulativeSQLMetadata"],
        "allowance": 1800, "payload_peak": 0, "inputs": set(),
    },
    "preview-hit": {
        "cases": ["PublishedProductionSearchDataTests/testPublishedV40NafshiFirstPageForIndependentFullContextOracle"],
        "allowance": 1800, "payload_peak": 0, "inputs": set(),
    },
    "preview-reader": {
        "cases": ["PublishedProductionSearchDataTests/testPublishedV40NafshiFullParagraphAndChapterMatchEveryOriginalSourceSegment",
                  "FullV40ReaderModeAcceptanceTests/testOriginalSearchOpensLineParagraphAndChapterAtExactSourceFocus"],
        "allowance": 3600, "payload_peak": 0, "inputs": PREVIEW_KEYS,
    },
    "reader-selection-navigation": {
        "cases": ["FullV40ReaderModeAcceptanceTests/testOriginalUIKitSelectionPersistsExactUTF16AndRestoresAcrossThreeBackends",
                  "FullV40ReaderModeAcceptanceTests/testOriginalParagraphAndChapterPullCancellationAndCanonicalTOCStaySynchronized"],
        "allowance": 3600, "payload_peak": 0, "inputs": PREVIEW_KEYS,
    },
    "reader-continuous-pull": {
        "cases": ["FullV40ReaderModeAcceptanceTests/testOriginalContinuousTouchArmedRetreatPreservesParagraphAndChapterReader"],
        "allowance": 1800, "payload_peak": 0, "inputs": PREVIEW_KEYS,
    },
    "sefaria-contexts": {
        "cases": ["SefariaFullSearchContextAcceptanceTests/testThreeActualSefariaEditionsAcrossTwoPagesKeepDistinctCompleteBodies",
                  "SefariaFullSearchContextAcceptanceTests/testHebrewUIEnglishResultHonorsOriginalSourceTranslationAndBothControls"],
        "allowance": 1800, "payload_peak": 0, "inputs": set(),
    },
    "inspector": {
        "cases": ["FullV40InspectorSemanticAcceptanceTests/testFullV40InspectorSemanticGroupsAndLinkedContent"],
        "allowance": 3600, "payload_peak": 0, "inputs": set(),
    },
    "inspector-text-modes": {
        "cases": ["SefariaInspectorModeAcceptanceTests/testSameTabInspectorHonorsSourceTranslationAndBothAcrossCloseAndReopen"],
        "allowance": 1800, "payload_peak": 0, "inputs": set(),
    },
    "settings-update-last": {
        "cases": ["ManagedLibraryUpdateAcceptanceTests/testOrdinarySettingsUpdatePreservesProductionLibraryAndUserState"],
        # Preserve the 24,000,000,000-byte original work budget. It also
        # exceeds 8*C + old database + 1 GiB, the unchanged extraction
        # preflight's conservative no-frame-size path after two archive copies.
        "allowance": 7200, "payload_peak": max(24_000_000_000,
            8 * V41_ARCHIVE_BYTES + V40_DATABASE_BYTES + GIB), "inputs": set(),
    },
    "search-after-settings": {
        "cases": [POST_UPDATE_CASE], "allowance": 1800,
        "payload_peak": 0, "inputs": set(),
    },
}
PRE_UPDATE_PHASES = {key: value["cases"] for key, value in PHASES.items()
                     if key not in {"settings-update-last", "search-after-settings"}}
FILES = [
    "Maktabah-iOSUITests/GlobalSearchNativeAcceptanceTests.swift",
    "Maktabah-iOSUITests/ProductionOtzariaAcceptanceTests.swift",
    "Maktabah-iOSUITests/Build8401SevenDefectsAcceptanceTests.swift",
    "Maktabah-iOSUITests/DeepLinkedCommentaryAcceptanceTests.swift",
    "Maktabah-iOSUITests/MaktabahUITestBase.swift",
    "Scripts/CI/prepare-managed-library-update-context.py",
    "Scripts/CI/prepare-production-search-preview-oracle.py",
    "Scripts/CI/study-ui-settings-receipts.py",
    "Scripts/CI/study-ui-prerequisites.py",
    "Scripts/CI/study-ui-search-log.py",
    "Scripts/CI/reader-continuous-pull-host.py",
    "docs/hq-integration/wave2-20261127/search/production-ui-contract.json",
    "docs/hq-integration/wave2-20261127/search/native-context/TEST_CONTRACT.md",
    "docs/hq-integration/wave2-20261127/search/native-context/sefaria-native-source-oracle.json",
    "docs/hq-integration/wave2-20261127/library/inspector-v40/ORACLE.json",
    "docs/hq-integration/wave2-20261127/library/settings-receipts/POST_UPDATE_RECEIPT.schema.json",
    "docs/hq-integration/wave2-20261127/reader/continuous-pull/TEST_CONTRACT.md",
    "docs/hq-integration/wave2-20261127/search/post-update-ui/TEST_CONTRACT.md",
    "docs/hq-integration/wave2-20261127/library/inspector-mode-ui/sefaria-inspector-default-mode-oracle.json",
    "docs/hq-integration/wave2-20261127/library/inspector-mode-ui/psalms35-default-response.json",
    "docs/hq-integration/wave2-20261127/library/inspector-mode-ui/psalms35-default-response-receipt.json",
]
FORBIDDEN = {"OTZARIA_SHARED_ROOT_OVERRIDE", "OTZARIA_PRODUCTION_DB_PATH"}


def require(value, message):
    if not value:
        raise ValueError(message)


def load_core():
    path = ROOT / "Scripts/CI/reader-full-v40-ui-observation.py"
    spec = importlib.util.spec_from_file_location("study_ui_retained_v40", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module, module.load_core()


def load_support(filename):
    path = ROOT / "Scripts/CI" / filename
    name = "study_ui_" + filename.replace("-", "_").replace(".", "_")
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def input_values(phase, supplied):
    require(isinstance(supplied, dict), "Runner inputs must be a JSON object")
    require(set(supplied) == PHASES[phase]["inputs"], "Unexpected or missing original runner inputs")
    for key, value in supplied.items():
        require(isinstance(value, str) and value and "\x00" not in value, "Invalid runner input: " + key)
        if key.endswith("SHA256"):
            require(re.fullmatch(r"[a-f0-9]{64}", value), "Malformed independent digest: " + key)
        else:
            require(Path(value).is_absolute(), "Observed input path must be absolute: " + key)
    return dict(supplied)


def source_context(core, phase, frozen):
    context = core.source_context(require_frozen=frozen)
    paths = [Path(__file__).resolve().relative_to(ROOT).as_posix(), *FILES]
    observed = {}
    for name in paths:
        path = ROOT / name
        require(path.is_file() and not path.is_symlink(), "Missing registered study execution source: " + name)
        if frozen:
            require(core.command(["git", "hash-object", str(path)]).stdout.strip()
                    == core.git("rev-parse", "HEAD:" + name), "Dirty study execution source: " + name)
        observed[name] = core.witness(path)
    selected = PHASES[phase]["cases"]
    declarations = "\n".join((ROOT / p).read_text() for p in FILES if p.endswith(".swift"))
    for case in selected:
        klass, method = case.split("/")
        require(re.search(r"\bclass\s+" + re.escape(klass) + r"\b", declarations)
                and re.search(r"\bfunc\s+" + re.escape(method) + r"\s*\(", declarations),
                "Registered native selector declaration missing: " + case)
    context["study_ui_execution_sources"] = observed
    context["study_ui_phase"] = phase
    context["executed_case_ids"] = selected
    context["shared_profile_scope"] = "Full-v40 ownership/source admission only; original two Reader/Inspector observation cases are not executed by this controller"
    return context


def observe_inputs(core, values):
    records = {}
    for key, value in values.items():
        if key.endswith("SHA256"):
            continue
        path = Path(value)
        require(path.resolve(strict=True) == path and path.is_file() and not path.is_symlink(),
                "Observed source input is redirected: " + key)
        require(path.stat().st_size <= 2_000_000, "Observed source input exceeds its complete-file bound")
        records[key] = core.witness(path)
    if "PRODUCTION_SEARCH_PREVIEW_ORACLE" in values:
        require(records["PRODUCTION_SEARCH_PREVIEW_ORACLE"]["sha256"]
                == values["PRODUCTION_SEARCH_PREVIEW_ORACLE_SHA256"], "Preview source receipt digest changed")
    return records


def run_original_case(core, test_run, udid, case, allowance, output, environment, private_values=()):
    output.mkdir()
    bundle, log = output / "original.xcresult", output / "original-ui.log"
    command = ["xcodebuild", "test-without-building", "-xctestrun", str(test_run),
               "-destination", "platform=iOS Simulator,id=" + udid,
               "-parallel-testing-enabled", "NO", "-maximum-concurrent-test-simulator-destinations", "1",
               "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", str(allowance),
               "-maximum-test-execution-time-allowance", str(allowance),
               "-resultBundlePath", str(bundle), "-only-testing:Maktabah-iOSUITests/" + case]
    result = {"case": case, "case_directory": str(output), "command": command,
              "allowance_seconds": allowance, "started_at_unix": time.time()}
    try:
        result["xcodebuild_exit"] = core.bounded(command, log, allowance + 600, environment)
    finally:
        result["finished_at_unix"] = time.time()
        if log.exists() and private_values:
            require(log.stat().st_size <= 64 * 1024 * 1024, "Original UI log exceeds its retained bound")
            content = log.read_text(errors="replace")
            for value in private_values:
                require(isinstance(value, str) and value, "Missing explicit private token for log redaction")
                content = content.replace(value, "<redacted-owned-host-token>")
            log.write_text(content)
        core.write(output / "RUN_ATTEMPT.json", result)
    strict = [sys.executable, "tools/verify_xcresult_zero_skips.py", "--xcresult", str(bundle),
              "--log", str(log), "--scope", "focused-ui", "--expected-device", udid,
              "--expected-os-major", "27", "--min-tests", "1", "--out", str(output / "zero-skip.json"),
              "--required-case", case]
    result["zero_skip_exit"] = core.command(strict, timeout=180, check=False).returncode
    verifier = runpy.run_path(str(ROOT / "Scripts/CI/verify-faithful-xctest.py"))
    declaration = verifier["verify"](log.read_text(errors="replace"), [case], ROOT / "Maktabah-iOSUITests")
    core.write(output / "actual-test-cases.json", declaration)
    result["declaration_status"] = declaration["status"]
    if bundle.is_dir():
        result["attachment_export_exit"] = core.command(
            ["xcrun", "xcresulttool", "export", "attachments", "--path", str(bundle),
             "--output-path", str(output / "captures")], timeout=300, check=False).returncode
    result["passed"] = (result["xcodebuild_exit"] == result["zero_skip_exit"] == 0
                        and declaration["status"] == "EXECUTED_PASS"
                        and result.get("attachment_export_exit") == 0)
    core.write(output / "RESULT.json", result)
    return result


def actual_owner(core, settings, udid):
    container = Path(core.command(["xcrun", "simctl", "get_app_container", udid,
                                   core.BUNDLE, "data"], timeout=8).stdout.strip())
    require(container.resolve(strict=True) == container, "Actual app data path is redirected")
    result = settings.discover_owner(udid, container.parent)
    require(result["dataContainer"] == str(container), "simctl and actual MCM app owner differ")
    return result


def install_images(core, owner, udid, products, build):
    """Reuse identical installed images, avoiding an unnecessary container move."""
    owner.require_test_runner = True
    try:
        return {"action": "REUSED_VERIFIED_CURRENT_IMAGES",
                "images": owner.verify_installed_images(udid, build)}
    except (ValueError, FileNotFoundError):
        for name in ("Maktabah.app", "Maktabah-iOSUITests-Runner.app"):
            core.command(["xcrun", "simctl", "install", udid, str(products / name)], timeout=600)
        return {"action": "INSTALLED_CURRENT_QUALIFIED_APP_AND_RUNNER",
                "images": owner.verify_installed_images(udid, build)}


def prepare_context(core, settings, udid, database, output, annotations_path=None):
    before = actual_owner(core, settings, udid)
    require(str(database) == str(Path(before["storageRoot"]) / "Otzaria/seforim.db"),
            "Managed context and original full-v40 admission have different owners")
    path = output / "managed-context.json"
    command = [sys.executable, str(ROOT / "Scripts/CI/prepare-managed-library-update-context.py"),
               "--udid", udid, "--database", str(database),
               "--expected-target-id", str(settings.V41_ID), "--expected-target-tag", settings.V41_TAG,
               "--output", str(path)]
    if annotations_path is not None:
        command.extend(["--annotations-path", str(annotations_path)])
    core.command(command, timeout=120)
    record = settings.witness(path)
    binding = {"input": record, "effective": record, "relocations": []}
    require(actual_owner(core, settings, udid) == before,
            "Owner moved while preparing context; preserve this attempt and prepare a new actual context")
    settings.verify_context_binding(binding, before, before)
    return before, binding


def official_metadata(core, settings, output):
    """Retain complete current official metadata; no corpus response replacement."""
    directory = output / "official-target"
    directory.mkdir()
    paths, transport = {}, {}
    def fetch(key, url, filename):
        request = urllib.request.Request(url, headers={"User-Agent": "Maktabah-Original-Settings-Acceptance",
                                                      "Accept-Encoding": "identity"})
        with urllib.request.urlopen(request, timeout=45) as response:
            final = urllib.parse.urlsplit(response.geturl())
            require(response.status == 200 and final.scheme == "https" and final.hostname in {
                "api.github.com", "github.com", "release-assets.githubusercontent.com",
                "objects.githubusercontent.com", "github-releases.githubusercontent.com"},
                "Official metadata transport did not reach an admitted origin")
            raw = response.read(settings.MAX_METADATA + 1)
            require(0 < len(raw) <= settings.MAX_METADATA, "Complete official metadata exceeds its bound")
            transport[key] = {"requestedURL": url, "status": response.status,
                              "redirectHost": final.hostname, "observedAtUnix": time.time()}
        path = directory / filename
        with path.open("xb") as stream:
            stream.write(raw)
        paths[key] = str(path)
        return settings.decode_json(raw)
    release = fetch("release", "https://api.github.com/repos/" + settings.REPOSITORY + "/releases/latest", "release.json")
    require(release.get("id") == settings.V41_ID and release.get("tag_name") == settings.V41_TAG,
            "Official latest changed; rebind the observed release contract before updating")
    for key, name in (("fullManifest", "seforim-schema7.db.zst.manifest.json"), ("statistics", "library_stats.json")):
        assets = [row for row in release.get("assets", []) if row.get("name") == name]
        require(len(assets) == 1, "Original official metadata asset is ambiguous")
        expected = "https://github.com/" + settings.REPOSITORY + "/releases/download/" + settings.V41_TAG + "/" + name
        require(assets[0].get("browser_download_url") == expected, "Unexpected official metadata URL")
        fetch(key, expected, name)
    official, archive = settings.official_target(paths, settings.V41_ID, settings.V41_TAG)
    require(archive.get("size") == V41_ARCHIVE_BYTES, "Observed archive changed the capacity calculation")
    core.write(directory / "transport.json", transport)
    return paths, official


def verified_phase(core, settings, path, phase, udid, build, original_installation):
    file = settings.witness(path)
    report = settings.decode_json(settings.verify_witness(file))
    require(report.get("study_phase") == phase and report.get("status") == STUDY_PASS
            and report.get("reused_external_owned_simulator") == udid,
            "Require an actual passed phase on this retained full-v40 owner: " + phase)
    require(report.get("source_before") == report.get("source_after") == source_context(core, phase, True)
            and report.get("build_before") == report.get("build_after") == build
            and report.get("original_installation", {}).get("result") == original_installation
            and report.get("post_verification_failures") == [], "Prior phase attribution or postchecks differ")
    require(report.get("selected_case_ids") == PHASES[phase]["cases"]
            and [row.get("case") for row in report.get("case_results", [])] == PHASES[phase]["cases"],
            "The prior phase did not execute exactly its declared selectors")
    for row in report["case_results"]:
        executed = settings.verified_execution(row["case_directory"], "Maktabah-iOSUITests/" + row["case"],
                                               udid, repository_root=ROOT)
        require(executed["caseResult"] == row.get("case_result"), "Prior case receipt changed")
    return file, report


def positive_trace(core, settings, pages_path, udid, build, owner_record, original_installation, manifest_sha):
    phase_file, phase = verified_phase(core, settings, pages_path, "pages", udid, build, original_installation)
    case = "Maktabah-iOSUITests/PublishedProductionSearchDataTests/testPublishedV40OtzariaPagesRetainCumulativeSQLMetadata"
    row = next(row for row in phase["case_results"] if "Maktabah-iOSUITests/" + row["case"] == case)
    execution = settings.verified_execution(row["case_directory"], case, udid, repository_root=ROOT)
    attachment = settings.selected_attachment(Path(row["case_directory"]) / "captures", case, udid,
                                               "published-v40-otzaria-original-pages-and-independent-sql")
    events = attachment["contents"].get("events")
    require(isinstance(events, list) and events, "Actual v40 pages trace has no events")
    namespaces = {event.get("namespace") for event in events}
    processes = {event.get("processID") for event in events}
    require(len(namespaces) == len(processes) == 1, "Pages trace has ambiguous process/namespace")
    namespace = settings.canonical_uuid(next(iter(namespaces)))
    relative = "Documents/OtzariaLogs/search-native-" + namespace + ".jsonl"
    path = Path(owner_record["dataContainer"]) / relative
    identity = settings.file_identity(path)
    raw = settings.read_bytes(path)
    result = {"namespace": namespace, "relativePath": relative,
              **{key: identity[key] for key in ("bytes", "inode", "mtimeNs", "ctimeNs")},
              "sha256": settings.sha256(raw), "processID": next(iter(processes)), "caseID": case,
              "caseStatus": "Passed", "xcresultPath": execution["xcresultPath"],
              "caseResult": execution["caseResult"], "sourceAttachment": attachment["file"],
              "sourceDatabaseManifestSHA256": manifest_sha}
    settings.verified_trace_baseline(result, owner_record, manifest_sha, repository_root=ROOT)
    return result, phase_file


def updated_snapshot(settings, envelope, owner_record):
    require(owner_record == envelope["ownershipAfter"], "Post-update MCM owner changed without resealing")
    database = Path(owner_record["storageRoot"]) / "Otzaria/seforim.db"
    require(settings.file_identity(database) == envelope["finalIntegrity"]["fileIdentity"],
            "The actually hashed v41 file changed since its Settings seal")
    require(settings.raw_manifest(database.parent / "seforim-installation.json")
            == envelope["after"]["installationManifest"], "Actual v41 installation manifest changed")
    indexes = settings.capture_indexes(owner_record["storageRoot"])
    require(indexes == envelope["after"]["indexes"], "Retained v40 indexes changed after Settings")
    settings.require_retained_indexes(envelope["before"]["indexes"], indexes)
    settings.cleanup_observation(database, database.parent / "Downloads/Maktabah/Otzaria/Downloads")
    settings.verified_trace_baseline(envelope["traceBaseline"], owner_record,
                                     envelope["before"]["installationManifest"]["sha256"], repository_root=ROOT)
    return {"database": envelope["after"]["database"], "file_identity": settings.file_identity(database),
            "manifest": envelope["after"]["installationManifest"], "indexes": indexes,
            "scope": "Reused actual Settings full hash and SQL receipt with unchanged current file identity; no fresh full-hash claim"}


def admit_updated(core, settings, args, owner, udid, build, output):
    phase_file, phase = verified_phase(core, settings, args.settings_phase_result, "settings-update-last", udid, build, owner.prior["result"])
    record = phase.get("settings_success")
    envelope = settings.decode_json(settings.verify_witness(record))
    require(envelope.get("status") == "ORIGINAL_SETTINGS_UPDATE_VERIFIED" and envelope.get("schemaVersion") == 1
            and envelope.get("simulatorUDID") == udid and envelope.get("checkoutSHA") == core.git("rev-parse", "HEAD")
            and envelope.get("originalInstallationResult") == owner.prior["result"]
            and envelope.get("currentBuildReceipt") == build["build_receipt"], "Settings seal belongs to another owner/source/build")
    current = actual_owner(core, settings, udid)
    if current != envelope["ownershipAfter"]:
        # Retain the original seal. A real later app installation may move its
        # container. Re-run the original seal's actual DB/hash/index/SQL checks
        # against the observed new owner; never edit the original receipt.
        binding = json.loads(json.dumps(envelope["context"]))
        binding["relocations"].append({"before": envelope["ownershipAfter"], "after": current})
        record = settings.seal_success(
            before_receipt=envelope["beforeReceipt"]["path"], before_sha256=envelope["beforeReceipt"]["sha256"],
            owner_after=current, context_binding=binding,
            case_directory=Path(envelope["settingsExecution"]["caseResult"]["path"]).parent,
            original_installation_result=args.installation_result, checkout_sha=core.git("rev-parse", "HEAD"),
            official_metadata_paths={key: value["path"] for key, value in envelope["officialTarget"]["metadataReceipts"].items()},
            trace_baseline=envelope["traceBaseline"], output=output / "settings-success-relocated.json", repository_root=ROOT)
        envelope = settings.decode_json(settings.verify_witness(record))
    return record, envelope, updated_snapshot(settings, envelope, current), phase_file


def image_resolver(core, udid, products, build):
    verified = {}
    def resolve():
        bundle = Path(core.command(["xcrun", "simctl", "get_app_container", udid, core.BUNDLE, "app"], timeout=3).stdout.strip())
        require(bundle.resolve(strict=True) == bundle, "Actual executable bundle is redirected")
        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        name = info.get("CFBundleExecutable")
        require(info.get("CFBundleIdentifier") == core.BUNDLE and isinstance(name, str)
                and Path(name).name == name, "Wrong actual app executable identity")
        path = bundle / name
        require(path.resolve(strict=True) == path and path.is_file(), "Actual Mach-O file is redirected")
        stat = path.stat()
        key = (str(path), stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns)
        if key not in verified:
            expected = build["complete_native_images"][(products / "Maktabah.app" / name).relative_to(ROOT).as_posix()]
            require({"bytes": stat.st_size, "sha256": core.digest(path)} == expected,
                    "Observed process image differs from the qualified build")
            verified[key] = True
        return str(path)
    return resolve


def execute(args):
    require(sys.platform == "darwin", "Original native study UI requires Apple macOS/Xcode")
    require(type(args.reserved_other_bytes) is int and args.reserved_other_bytes >= 0,
            "Declare the current concurrent storage reservation")
    retained, core = load_core()
    settings = load_support("study-ui-settings-receipts.py")
    phase, plan = args.study_phase, PHASES[args.study_phase]
    is_update, is_post = phase == "settings-update-last", phase == "search-after-settings"
    require(not is_update or (args.prerequisites and args.pages_phase_result),
            "Settings requires the completed pre-update gates and actual pages phase")
    require(not is_post or args.settings_phase_result, "Post-update search requires the actual passed Settings phase")
    require(phase != "reader-continuous-pull" or args.pinned_hid_tools,
            "Continuous touch requires the integration owner's exact retained pinned idb tools")
    context = source_context(core, phase, True)
    values = input_values(phase, core.bounded_json(args.runner_inputs, 65_536) if args.runner_inputs else {})
    input_records = observe_inputs(core, values)
    for prefix in ("", "TEST_RUNNER_", "SIMCTL_CHILD_"):
        require(not any(prefix + key in os.environ for key in FORBIDDEN),
                "A corpus override is present in the execution environment")
    out = args.output.absolute()
    require(not out.exists() and out.is_relative_to(ROOT / "build/artifacts")
            and ".." not in out.parts, "Choose a fresh owned evidence directory under build/artifacts")
    out.mkdir(parents=True)
    require(out.resolve(strict=True) == out, "Evidence output traverses a symbolic link")
    core.OUT = out
    config = json.loads(core.INPUTS.read_text())
    products, test_run, build = core.build_identity(context)
    sdk = core.command(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]).stdout.strip()
    wanted = os.environ.get("FAITHFUL_RUNTIME27_IDENTIFIER")
    runtimes = core.json_command(["xcrun", "simctl", "list", "runtimes", "available", "-j"])["runtimes"]
    runtimes = [r for r in runtimes if r.get("isAvailable") and r["identifier"] == wanted
                and r["version"].split(".")[:2] == sdk.split(".")[:2] and r["version"].split(".")[0] == "27"]
    require(len(runtimes) == 1, "Explicit SDK-matched iPadOS27 runtime required")
    runtime = runtimes[0]
    types = [t for t in runtime["supportedDeviceTypes"] if "iPad Pro" in t["name"] and "13-inch" in t["name"]]
    owner = retained.RetainedV40Installation(core, args.owned_simulator, args.installation_result)
    udid, device_type, ownership = owner.admit_owner(config, runtime, types)
    image_bytes = sum(p.stat().st_size for name in ("Maktabah.app", "Maktabah-iOSUITests-Runner.app")
                      for p in (products / name).rglob("*") if p.is_file())
    required = image_bytes + plan["payload_peak"] + GIB + 2_000_000_000 + args.reserved_other_bytes
    budget = {"possible_app_runner_copy_bytes": image_bytes, "phase_work_budget_bytes": plan["payload_peak"],
              "evidence_budget_bytes": GIB, "os_margin_bytes": 2_000_000_000,
              "other_reserved_bytes": args.reserved_other_bytes, "required_free_bytes": required,
              "free_bytes": shutil.disk_usage(ROOT).free}
    report = {"status": "STARTED_NOT_ACCEPTED", "study_phase": phase, "source_before": context,
              "build_before": build, "runtime": runtime, "device_type": device_type,
              "capacity_before": budget, "input_receipts": input_records, **ownership,
              "selected_case_ids": plan["cases"], "case_results": [], "configuration": "Debug",
              "started_at_unix": time.time(), "native116_acceptance": False, "release114_acceptance": False,
              "full_performance_acceptance": False, "physical_device_acceptance": False,
              "network_scope": "Ordinary network; no denied-network or offline acceptance"}
    database = installation = managed_owner = binding = before_settings = trace_baseline = None
    target_paths = updated_record = updated_envelope = active_host = None
    failure, post_failures = None, []
    active_kind = None
    cleanup_verified = True
    lifecycle_started = False
    try:
        require(budget["free_bytes"] >= required,
                "The phase's actual images, work budget, evidence and reservations do not fit")
        if is_update:
            prerequisites = load_support("study-ui-prerequisites.py")
            report["prerequisites"] = prerequisites.admit_before_settings(
                args.prerequisites, core=core, settings=settings, udid=udid, source=context, build=build,
                installation_result=owner.prior["result"], required_study_phases=PRE_UPDATE_PHASES)
        lifecycle_started = True
        core.command(["xcrun", "simctl", "boot", udid], timeout=90)
        core.command(["xcrun", "simctl", "bootstatus", udid, "-b"], timeout=900)
        report["image_installation"] = install_images(core, owner, udid, products, build)
        require(source_context(core, phase, True) == context, "Source changed during image admission")
        if is_post:
            updated_record, updated_envelope, installation, settings_phase_file = admit_updated(
                core, settings, args, owner, udid, build, out)
            report["settings_phase_result"] = settings_phase_file
            report["settings_success_input"] = updated_record
            database = Path(updated_envelope["after"]["database"]["path"])
        else:
            database, installation = owner.admit_current_installation(config, udid, build)
        report["installation_before"] = installation
        current_owner = actual_owner(core, settings, udid)
        container = Path(current_owner["dataContainer"])
        environment = os.environ.copy()
        runner = {"SIMULATOR_UDID": udid, "PRODUCTION_SEARCH_CONTAINER_PARENT": str(container.parent),
                  "RUNTIME27_RECORD_CONFIGURATION": "1", **values}
        if phase == "sefaria-contexts":
            oracle = ROOT / "docs/hq-integration/wave2-20261127/search/native-context/sefaria-native-source-oracle.json"
            runner.update(SEFARIA_SEARCH_CONTEXT_ORACLE=str(oracle), SEFARIA_SEARCH_CONTEXT_ORACLE_SHA256=core.digest(oracle))
        if phase == "inspector-text-modes":
            oracle = ROOT / "docs/hq-integration/wave2-20261127/library/inspector-mode-ui/sefaria-inspector-default-mode-oracle.json"
            runner.update(SEFARIA_INSPECTOR_MODE_ORACLE=str(oracle),
                          SEFARIA_INSPECTOR_MODE_ORACLE_SHA256=core.digest(oracle),
                          SEFARIA_INSPECTOR_CONTAINER_PARENT=str(container.parent))
        if phase in {"inspector", "settings-update-last"}:
            managed_owner, binding = prepare_context(core, settings, udid, database, out, args.annotations_path)
            runner["OTZARIA_LIBRARY_UPDATE_CONTEXT"] = binding["effective"]["path"]
            report["context_binding"] = binding
            if phase == "inspector":
                runner["OTZARIA_INSPECTOR_SEMANTIC_ORACLE"] = str(ROOT / "docs/hq-integration/wave2-20261127/library/inspector-v40/ORACLE.json")
        if is_update:
            before_settings = settings.capture_before(
                owner=managed_owner, actual_installation_receipt=out / "actual-full-v40-installation.json",
                output=out / "settings-before.json", repository_root=ROOT)
            before_value = settings.decode_json(settings.verify_witness(before_settings))
            trace_baseline, pages_file = positive_trace(core, settings, args.pages_phase_result, udid, build,
                managed_owner, owner.prior["result"], before_value["snapshot"]["installationManifest"]["sha256"])
            require(report["prerequisites"]["proof"]["receipts"]["study:pages"] == pages_file,
                    "Settings trace pages differ from the admitted ordering prerequisite")
            target_paths, report["official_target"] = official_metadata(core, settings, out)
            report.update(settings_before=before_settings, trace_baseline=trace_baseline, pages_phase_result=pages_file)
            # This is the unchanged product gate at its actual pre-download
            # point, in addition to the conservative outer work budget.
            require(shutil.disk_usage(ROOT).free >= 8 * V41_ARCHIVE_BYTES + GIB
                    + 2_000_000_000 + args.reserved_other_bytes,
                    "Original v41 download preflight and concurrent reserve do not fit")
        if is_post:
            runner.update(PRODUCTION_SEARCH_POST_UPDATE_RECEIPT=updated_record["path"],
                          PRODUCTION_SEARCH_POST_UPDATE_RECEIPT_SHA256=updated_record["sha256"])
        environment.update({"TEST_RUNNER_" + key: value for key, value in runner.items()})
        report["runner_inputs"] = runner
        if binding:
            require(runner["OTZARIA_LIBRARY_UPDATE_CONTEXT"] == binding["effective"]["path"],
                    "Effective Settings context is not the actual runner input")
            settings.verify_witness(binding["effective"])
            require(actual_owner(core, settings, udid) == managed_owner,
                    "Owner moved before XCTest could consume the prepared context")
        for index, case in enumerate(plan["cases"], 1):
            require(source_context(core, phase, True) == context, "Source changed between original UI cases")
            case_dir = out / (str(index).zfill(2) + "-" + case.split("/")[1])
            private_values = ()
            if phase == "reader-continuous-pull":
                def resolve_owned_installation():
                    actual = Path(core.command(["xcrun", "simctl", "get_app_container", udid, core.BUNDLE, "data"], timeout=8).stdout.strip())
                    current, _ = owner.current_database(udid)
                    return {"container": str(actual), "database": str(current),
                            "manifest": core.witness(current.parent / "seforim-installation.json")}
                active_kind = "continuous-pull"
                active_host = load_support("reader-continuous-pull-host.py").ContinuousPullHost(
                    udid=udid, app_container=container, artifacts=out / "continuous-pull-host",
                    tools_root=args.pinned_hid_tools, container_resolver=resolve_owned_installation)
                extra = active_host.start()
                environment.update(extra)
                private_values = tuple(extra.values())
            elif is_post:
                active_kind = "search-log"
                active_host = load_support("study-ui-search-log.py").SearchLogCapture(
                    udid=udid, output_dir=out / "post-update-search-log",
                    namespace=updated_envelope["traceBaseline"]["namespace"],
                    image_path_resolver=image_resolver(core, udid, products, build), repository_root=ROOT)
                active_host.start()
            result = run_original_case(core, test_run, udid, case, plan["allowance"],
                                       case_dir, environment, private_values)
            result["case_result"] = settings.witness(case_dir / "RESULT.json")
            report["case_results"].append(result)
            core.write(out / "PROGRESS.json", report)
            require(result["passed"], "Original native case failed or was incomplete: " + case)
            settings.verified_execution(case_dir, "Maktabah-iOSUITests/" + case, udid, repository_root=ROOT)
            if active_kind == "continuous-pull":
                report["continuous_pull_host"] = active_host.stop()
                active_host = active_kind = None
            elif active_kind == "search-log":
                attachment = settings.selected_attachment(case_dir / "captures", "Maktabah-iOSUITests/" + case,
                                                          udid, POST_UPDATE_ATTACHMENT)
                report["post_update_host_log"] = active_host.stop_and_verify(
                    attachment["file"]["path"], expected_attachment_sha256=attachment["file"]["sha256"])
                active_host = active_kind = None
        report["native_cases_completed"] = True
    except BaseException as error:
        failure = error
        message = str(error)
        if active_host is not None and hasattr(active_host, "token"):
            message = message.replace(active_host.token, "<redacted-owned-host-token>")
        report.update(status="FAILED_OR_INCOMPLETE", error_type=type(error).__name__, error=message)
        if hasattr(error, "witness"):
            report["failed_prerequisites"] = error.witness
    finally:
        # Stop all owned background work before app termination or Simulator
        # shutdown, even when XCTest/export or a host acceptance condition fails.
        if active_host is not None:
            try:
                if active_kind == "search-log":
                    report["host_abort_cleanup"] = active_host.abort()
                    cleanup_verified = (report["host_abort_cleanup"].get("verified") is True
                                        and all(not t.is_alive() for t in active_host.threads)
                                        and (not hasattr(active_host, "monitor") or not active_host.monitor.is_alive()))
                else:
                    try:
                        report["continuous_pull_host"] = active_host.stop()
                    finally:
                        cleanup_verified = (all(p.poll() is not None for p in active_host.processes)
                            and (active_host.resolver_thread is None or not active_host.resolver_thread.is_alive()))
                require(cleanup_verified, "Owned host cleanup remains unverified")
            except Exception as error:
                post_failures.append("owned_host: " + type(error).__name__)
                if active_kind == "search-log":
                    cleanup_verified = False
        if database is not None and lifecycle_started:
            try:
                if is_post:
                    report["database_after"] = updated_snapshot(settings, updated_envelope, actual_owner(core, settings, udid))
                elif not is_update:
                    database, relocation = owner.current_database(udid)
                    report["database_after"] = core.witness(database)
                    report["data_container_relocation"] = relocation
                    require(report["database_after"]["sha256"] == installation["database"]["sha256"]
                            and report["database_after"]["bytes"] == installation["database"]["bytes"],
                            "Managed v40 corpus changed")
                report["installed_images_after"] = owner.verify_installed_images(udid, build)
                report["original_installation_receipts_after"] = owner.verify_prior_receipts()
            except Exception as error:
                post_failures.append("installation: " + type(error).__name__ + ": " + str(error))
        try:
            report["source_after"] = source_context(core, phase, True)
            require(report["source_after"] == context, "Source changed during the study phase")
            report["build_after"] = core.build_identity(context)[2]
            require(report["build_after"] == build, "Current app, test or SDK image closure changed")
            require(observe_inputs(core, values) == input_records, "Independent original source input changed")
            if binding:
                settings.verify_witness(binding["input"])
                settings.verify_witness(binding["effective"])
                require(report["runner_inputs"]["OTZARIA_LIBRARY_UPDATE_CONTEXT"] == binding["effective"]["path"],
                        "Actual runner context differs from its sealed effective input")
        except Exception as error:
            post_failures.append("source_build: " + type(error).__name__ + ": " + str(error))
        if is_update and failure is None and not post_failures:
            try:
                after_owner = actual_owner(core, settings, udid)
                if after_owner != managed_owner:
                    binding["relocations"].append({"before": managed_owner, "after": after_owner})
                report["settings_success"] = settings.seal_success(
                    before_receipt=before_settings["path"], before_sha256=before_settings["sha256"],
                    owner_after=after_owner, context_binding=binding,
                    case_directory=report["case_results"][0]["case_directory"],
                    original_installation_result=args.installation_result, checkout_sha=context["checkout_sha"],
                    official_metadata_paths=target_paths, trace_baseline=trace_baseline,
                    output=out / "settings-update-success.json", repository_root=ROOT)
            except Exception as error:
                post_failures.append("settings_seal: " + type(error).__name__ + ": " + str(error))
        if lifecycle_started and cleanup_verified:
            try:
                report["owned_cleanup"] = owner.retain_simulator(udid)
            except Exception as error:
                post_failures.append("retained_simulator: " + type(error).__name__ + ": " + str(error))
        elif lifecycle_started:
            post_failures.append("simulator_retention_deferred_until_owned_host_exit")
            report["owned_cleanup"] = {"status": "NOT_SHUT_DOWN_HOST_CLEANUP_UNVERIFIED", "udid": udid}
        report["post_verification_failures"] = post_failures
        report["free_bytes_after"] = shutil.disk_usage(ROOT).free
        report["finished_at_unix"] = time.time()
        if failure is None and not post_failures and report.get("native_cases_completed"):
            report["status"] = POST_UPDATE_PASS if is_post else STUDY_PASS
        else:
            report["status"] = "FAILED_OR_INCOMPLETE"
        core.write(out / "RESULT.json", report)
    if failure is not None:
        raise failure
    require(not post_failures, "Post-execution identity, source, host or owned retention failed")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["source-check", "execute"])
    parser.add_argument("study_phase", choices=sorted(PHASES))
    parser.add_argument("--owned-simulator")
    parser.add_argument("--installation-result", type=Path)
    parser.add_argument("--runner-inputs", type=Path)
    parser.add_argument("--annotations-path", type=Path)
    parser.add_argument("--pinned-hid-tools", type=Path)
    parser.add_argument("--prerequisites", type=Path)
    parser.add_argument("--pages-phase-result", type=Path)
    parser.add_argument("--settings-phase-result", type=Path)
    parser.add_argument("--reserved-other-bytes", type=int)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.operation == "source-check":
        _, core = load_core()
        context = source_context(core, args.study_phase, False)
        print(json.dumps({"status": "SOURCE_ONLY_NOT_UI", "source": context}, indent=2))
        return
    require(args.owned_simulator and args.installation_result and args.output,
            "Exact owned installation, original RESULT and new evidence directory required")
    require(str(uuid.UUID(args.owned_simulator)).upper() == args.owned_simulator, "Canonical owned Simulator UUID required")
    execute(args)


if __name__ == "__main__":
    main()
