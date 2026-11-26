#!/usr/bin/env python3
"""Run the original full v40 installer against the qualified integrated Apple app.

No seeded database, alternate installer, patched product or synthetic acceptance.
The owned simulator is retained after shutdown for subsequent normal UI checks.
"""
from __future__ import annotations
import argparse, datetime, hashlib, json, os, pathlib, plistlib, re, runpy, shutil
import signal, sqlite3, subprocess, sys, urllib.request, uuid

ROOT = pathlib.Path(__file__).resolve().parents[2]
METADATA = ROOT / "docs/hq-integration/library-acceptance-20261125"
RELEASE_ID = 455390662
TAG = "v40-20261123094345"
ARCHIVE = "seforim-schema7.db.zst"
DEFAULT_OS_MARGIN_BYTES = 2_000_000_000
WORK_BYTES = 24_000_000_000
SOURCE_FILES = [
    "Scripts/CI/library-v40-focused-native.py",
    "Scripts/run-otzaria-native-bootstrap-acceptance.sh",
    "Scripts/CI/otzaria_bootstrap_evidence.py",
    "Scripts/CI/original_editor_sdk_routes.py",
    "Scripts/CI/mac-prepared-inputs.py",
    "Scripts/CI/hq-stage2-focused-apple.inputs.json",
    "Scripts/CI/hq-stage2-otzaria-test-additions.json",
    "Scripts/CI/runtime27-original-editor.inputs.json",
    "Scripts/CI/original_editor_mac_projection.py",
    "Scripts/CI/hq-stage2-focused-apple.py",
    "Source/Otzaria/Bootstrap/OtzariaNativeBootstrapAcceptanceRunner.swift",
    "Source/Otzaria/Bootstrap/OtzariaBootstrapAdapter.swift",
    "Source/Otzaria/Bootstrap/OtzariaDatabaseBootstrapService.swift",
    "Source/Otzaria/Bootstrap/OtzariaDatabaseDownloadModels.swift",
    "Source/Otzaria/Bootstrap/OtzariaDatabaseDownloader.swift",
    "Source/Otzaria/Bootstrap/OtzariaDatabaseInstaller.swift",
    "Source/Otzaria/Bootstrap/OtzariaLibraryReleaseClient.swift",
    "Source/Otzaria/Storage/ITorahSharedContainer.swift",
    "Source/Otzaria/DataProfiles/OtzariaArtifactStorage.swift",
    "docs/hq-integration/library-acceptance-20261125/v40_release.raw",
    "docs/hq-integration/library-acceptance-20261125/seforim-schema7.db.zst.manifest.json",
    "docs/hq-integration/library-acceptance-20261125/library_stats.json",
    "docs/hq-integration/library-acceptance-20261125/build_provenance.json",
]

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n")

def witness(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return {"path": str(path), "bytes": path.stat().st_size, "sha256": digest.hexdigest()}

def command(args, timeout=90, check=True):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
    if check and result.returncode:
        raise RuntimeError("Command failed: " + repr(args) + "\n" + result.stderr[-4000:])
    return result

def source_context(expected, *, allow_build_projection=False):
    require(re.fullmatch(r"[0-9a-f]{40}", expected), "Canonical selected source SHA required")
    require(command(["git", "rev-parse", "HEAD"]).stdout.strip() == expected, "Checkout changed")
    changed = command(["git", "diff", "--name-only", "--ignore-submodules=none", "HEAD", "--"]).stdout.splitlines()
    allowed = {"Maktabah.xcodeproj/project.pbxproj", "Source/PrivacyInfo.xcprivacy"} if allow_build_projection else set()
    require(set(changed) <= allowed, "Tracked source differs outside exact generated build projections")
    names = list(SOURCE_FILES)
    for name in ("Scripts/CI/final_integration_source.py", "Scripts/CI/final-integration-source.inputs.json"):
        if (ROOT / name).exists():
            names.append(name)
        else:
            require(not allow_build_projection, "Final integrated source admission is required: " + name)
    result = {}
    for name in names:
        path = ROOT / name
        committed = subprocess.check_output(["git", "-C", str(ROOT), "show", "HEAD:" + name], timeout=30)
        require(path.read_bytes() == committed, "Input differs from committed source: " + name)
        result[name] = witness(path)
    return result

def metadata_context():
    release = json.loads((METADATA / "v40_release.raw").read_bytes())
    require(release["id"] == RELEASE_ID and release["tag_name"] == TAG, "Frozen official release differs")
    require(not release.get("draft") and not release.get("prerelease"), "Production release required")
    assets = release["assets"]
    def verified(name):
        matches = [asset for asset in assets if asset["name"] == name]
        require(len(matches) == 1, "Official asset must be unique: " + name)
        asset = matches[0]
        require(asset["browser_download_url"] == "https://github.com/Otzaria/SeforimLibrary/releases/download/" + TAG + "/" + name,
                "Foreign asset URL")
        path = METADATA / name
        actual = witness(path)
        require(actual["bytes"] == asset["size"] and "sha256:" + actual["sha256"] == asset["digest"],
                "Official asset bytes or digest changed: " + name)
        return json.loads(path.read_bytes())
    manifest = verified(ARCHIVE + ".manifest.json")
    stats = verified("library_stats.json")
    provenance = verified("build_provenance.json")
    require(manifest["schemaVersion"] == 1 and manifest["archive"] == ARCHIVE, "Multipart contract differs")
    require(manifest["size"] == 2_129_902_636 and len(manifest["parts"]) == 2, "Full archive size/parts differ")
    require(manifest["sha256"] == "39a2b52129323ea53ac3629835c4721e25acff010a8fc971bf076a666a3b9587",
            "Full archive digest differs")
    total = 0
    for index, part in enumerate(manifest["parts"]):
        require(part["name"] == ARCHIVE + ".part-" + str(index).zfill(3), "Part ordering differs")
        matches = [asset for asset in assets if asset["name"] == part["name"]]
        require(len(matches) == 1, "Same-release part missing/ambiguous")
        asset = matches[0]
        require(asset["size"] == part["size"] and asset["digest"] == "sha256:" + part["sha256"],
                "Part metadata differs")
        require(asset["browser_download_url"] == "https://github.com/Otzaria/SeforimLibrary/releases/download/" + TAG + "/" + part["name"],
                "Foreign part URL")
        total += part["size"]
    require(total == manifest["size"], "Aggregate size differs")
    require(stats["db_version"] == 40 and stats["books"] == 8259 and stats["lines"] == 7_925_185,
            "Official corpus statistics differ")
    require(provenance["db_schema"]["db_schema_version"] == 7, "Original schema provenance differs")
    return release, manifest, stats, provenance

def qualified_build_context(app):
    path = ROOT / "build/hq-stage2/result.json"
    build = json.loads(path.read_bytes())
    require(build.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
            and build.get("checkout_sha") == command(["git", "rev-parse", "HEAD"]).stdout.strip(),
            "No authentic same-checkout integrated app build")
    source_binding = json.loads((ROOT / "Scripts/CI/hq-stage2-focused-apple.inputs.json").read_bytes()).get("final_product_source")
    require(isinstance(source_binding, dict)
            and set(source_binding) == {"manifest", "sha256"}
            and source_binding["manifest"] == "Scripts/CI/final-integration-source.inputs.json",
            "Explicit final integrated source profile required")
    source = runpy.run_path(str(ROOT / "Scripts/CI/final_integration_source.py"))["verify"](
        ROOT, ROOT / source_binding["manifest"], source_binding["sha256"])
    projection = runpy.run_path(str(ROOT / "Scripts/CI/original_editor_mac_projection.py"))["verify"](
        ROOT, source, ROOT / "Scripts/CI/runtime27-original-editor.inputs.json", require_current_build=True)
    require(projection.get("current_product_build_verified") is True,
            "Generated source requires the current final successful app build")
    routes = build.get("original_editor_routes")
    require(isinstance(routes, dict), "Final original SDK route receipt required")
    verified = runpy.run_path(str(ROOT / "Scripts/CI/original_editor_sdk_routes.py"))["verify"](
        ROOT, routes["path"], "Debug", "iphonesimulator", app,
        route_sha256=routes["sha256"], after_ui=True)
    images = runpy.run_path(str(ROOT / "Scripts/CI/mac-prepared-inputs.py"))["code_images"](ROOT)
    return {"build_receipt": witness(path), "final_source": source, "generated_projection": projection,
            "qualified_sdk_route": verified, "complete_native_images": images}

def bounded(args, log, timeout, env, report, out):
    with log.open("w") as stream:
        process = subprocess.Popen(args, cwd=ROOT, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        report.setdefault("owned_processes", []).append({"pid": process.pid, "command": args})
        write(out / "RUN.json", report)
        try:
            return process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=20)
            raise RuntimeError("Owned native process reached its absolute deadline")

def inspect_database(final, stats, provenance):
    require(final.name == "seforim.db" and final.parent.name == "Otzaria", "Unexpected production database path")
    with final.open("rb") as stream:
        require(stream.read(16) == b"SQLite format 3\x00", "Installed database is not SQLite")
    with sqlite3.connect(final.as_uri() + "?mode=ro&immutable=1", uri=True) as database:
        counts = {name: database.execute('SELECT COUNT(*) FROM "' + name + '"').fetchone()[0]
                  for name in ("book", "line", "link")}
        require(counts == {"book": stats["books"], "line": stats["lines"], "link": stats["links"]},
                "Installed full corpus row counts differ from official statistics")
        checked = {}
        for table, expected_columns in provenance["db_schema"]["tables"].items():
            require(re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", table), "Unexpected schema identifier")
            actual = sorted(row[1] for row in database.execute('PRAGMA table_info("' + table + '")'))
            require(actual == sorted(expected_columns), "Installed schema differs: " + table)
            checked[table] = actual
        schema_meta = dict(database.execute("SELECT key, value FROM schema_meta"))
    return {"counts": counts, "schema_tables": checked, "schema_meta": schema_meta,
            "database": witness(final), "read_only": True, "original_native_quick_check_required": True}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--expected-sha", required=True)
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--reserved-other-bytes", type=int)
    parser.add_argument("--os-margin-bytes", type=int, default=DEFAULT_OS_MARGIN_BYTES)
    parser.add_argument("--delete-owned-simulator-on-success", action="store_true")
    args = parser.parse_args()
    require(args.os_margin_bytes > 0, "A measured positive OS margin is required")
    if not args.prepare_only:
        require(args.reserved_other_bytes is not None and args.reserved_other_bytes >= 0,
                "Explicit estimate of concurrent growth is required; zero means none")
    run_id = str(uuid.uuid4())
    out = ROOT / "build/artifacts" / ("native-v40-integrated-" + run_id)
    out.mkdir(parents=True, exist_ok=False)
    report = {"status": "STARTED_NOT_ACCEPTED", "run_kind": "real-local-mac",
              "local_run_id": run_id, "checkout_sha": args.expected_sha,
              "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "native116_acceptance": False, "release114_acceptance": False,
              "normal_settings_update_acceptance": False, "physical_ipad_acceptance": False,
              "scope": "Original full v40 cancel/resume/install/relaunch and real corpus integrity",
              "output": str(out)}
    udid = None
    success = False
    bundle_id = None
    before_source = None
    try:
        before_source = source_context(args.expected_sha, allow_build_projection=not args.prepare_only)
        report["inputs_before"] = before_source
        release, manifest, stats, provenance = metadata_context()
        report["official_metadata"] = {"release_id": release["id"], "archive": manifest,
                                       "statistics": stats, "schema_version": provenance["db_schema"]["db_schema_version"]}
        if args.prepare_only:
            report["status"] = "SOURCE_PREPARED_NOT_EXECUTED"
            success = True
        else:
            require(sys.platform == "darwin", "Real Apple host required")
            free = shutil.disk_usage(ROOT).free
            minimum = args.os_margin_bytes + WORK_BYTES + args.reserved_other_bytes
            report["disk_admission"] = {"free_bytes": free, "required_bytes": minimum,
                                       "os_margin_bytes": args.os_margin_bytes,
                                       "storage_policy": "mac-storage-lifecycle-v2",
                                       "lane_budget_bytes": WORK_BYTES,
                                       "reserved_other_bytes": args.reserved_other_bytes}
            require(free >= minimum, "Insufficient disk reserve for authentic full v40 acceptance")
            # The explicitly selected official v40 is shared by cancel/install/restore.
            # A newer public release must not change this frozen acceptance corpus.
            request = urllib.request.Request(
                f"https://api.github.com/repos/Otzaria/SeforimLibrary/releases/{RELEASE_ID}",
                headers={"Accept": "application/vnd.github+json", "User-Agent": "Maktabah-native-acceptance"})
            with urllib.request.urlopen(request, timeout=30) as response:
                raw = response.read(2_000_001)
            require(len(raw) <= 2_000_000, "Selected release metadata exceeds bound")
            observed = json.loads(raw)
            require(observed["id"] == RELEASE_ID and observed["tag_name"] == TAG
                    and not observed.get("draft") and not observed.get("prerelease"),
                    "Selected official release identity changed")
            frozen_assets = {asset["id"]: asset for asset in release["assets"]}
            observed_assets = {asset["id"]: asset for asset in observed["assets"]}
            required_names = {ARCHIVE + ".manifest.json", "library_stats.json", "build_provenance.json"}
            required_names.update(part["name"] for part in manifest["parts"])
            required_assets = [asset for asset in frozen_assets.values() if asset["name"] in required_names]
            require(len(required_assets) == len(required_names), "Frozen required assets are ambiguous")
            for asset in required_assets:
                live = observed_assets.get(asset["id"])
                require(live is not None and all(live.get(key) == asset.get(key)
                        for key in ("id", "name", "size", "digest", "browser_download_url")),
                        "Selected release asset identity changed: " + asset["name"])
            (out / "observed-selected-release.json").write_bytes(raw)
            app = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app"
            report["build_before"] = qualified_build_context(app)
            info = plistlib.loads((app / "Info.plist").read_bytes())
            bundle_id = info["CFBundleIdentifier"]
            binary = app / info["CFBundleExecutable"]
            report["app_binary_before"] = witness(binary)
            sdk = command(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]).stdout.strip()
            selected = os.environ.get("FAITHFUL_RUNTIME27_IDENTIFIER")
            runtimes = json.loads(command(["xcrun", "simctl", "list", "runtimes", "available", "-j"]).stdout)["runtimes"]
            matching = [r for r in runtimes if r.get("isAvailable") and r["identifier"] == selected
                        and r["version"].split(".")[:2] == sdk.split(".")[:2]
                        and r["version"].split(".")[0] == "27"]
            require(len(matching) == 1, "Explicit SDK-matched iPadOS27 runtime required")
            runtime = matching[0]
            types = [t for t in runtime["supportedDeviceTypes"] if "iPad Pro" in t["name"] and "13-inch" in t["name"]]
            require(types, "Original supported 13-inch iPad required")
            device = sorted(types, key=lambda t: t["identifier"])[-1]
            udid = command(["xcrun", "simctl", "create", "Otzaria-v40-" + run_id[:8],
                            device["identifier"], runtime["identifier"]]).stdout.strip()
            require(str(uuid.UUID(udid)).upper() == udid, "Invalid owned simulator UUID")
            report.update(created_owned_simulator=udid, runtime=runtime, device_type=device)
            env = dict(os.environ)
            env.update(OTZARIA_NATIVE_BOOTSTRAP_OWNED_UDID=udid,
                       OTZARIA_NATIVE_BOOTSTRAP_REPORT_DIR=str(out),
                       OTZARIA_NATIVE_BOOTSTRAP_DATA_PROFILE="production",
                       SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_RELEASE_ID=str(RELEASE_ID))
            report["native_exit"] = bounded(
                ["bash", "Scripts/run-otzaria-native-bootstrap-acceptance.sh", str(app)],
                out / "original-native.log", 14_500, env, report, out)
            require(report["native_exit"] == 0, "Original native installer acceptance failed")
            for name in ("v40_release.raw", ARCHIVE + ".manifest.json", "library_stats.json", "build_provenance.json"):
                (out / name).write_bytes((METADATA / name).read_bytes())
            argv = [sys.executable, "Scripts/CI/otzaria_bootstrap_evidence.py",
                    "--report", str(out / "otzaria-native-bootstrap-acceptance.json"),
                    "--release", str(out / "v40_release.raw"),
                    "--manifest", str(out / (ARCHIVE + ".manifest.json")),
                    "--phases-dir", str(out), "--require-resume", "--expected-release", str(RELEASE_ID),
                    "--output", str(out / "native-evidence-admission.json")]
            report["evidence_admission_exit"] = bounded(argv, out / "evidence-admission.log", 120, env, report, out)
            require(report["evidence_admission_exit"] == 0, "Original native evidence admission failed")
            launches = re.findall(r"^" + re.escape(bundle_id) + r":\s*(\d+)\s*$",
                                  (out / "original-native.log").read_text(), re.MULTILINE)
            require(len(launches) == 3 and len(set(launches)) == 3, "Three distinct original app processes required")
            report["cancel_install_restore_process_ids"] = list(map(int, launches))
            native = json.loads((out / "otzaria-native-bootstrap-acceptance.json").read_bytes())
            final = pathlib.Path(native["finalPath"]).resolve(strict=True)
            require("/Devices/" + udid + "/data/" in str(final), "Database is outside owned simulator")
            corpus = inspect_database(final, stats, provenance)
            write(out / "actual-installed-corpus.json", corpus)
            downloads = final.parent / "Downloads/Maktabah/Otzaria/Downloads"
            require(downloads.is_dir(), "Original production downloads root absent")
            names = ["seforim.db.zst.part", "seforim.db.zst.part.json",
                     "seforim.db.zst.parts", "seforim.db.zst.assembling"]
            absent = {name: not (downloads / name).exists() for name in names}
            leftovers = sorted(p.name for p in final.parent.glob("seforim.db.installing*"))
            require(all(absent.values()) and not leftovers, "Multipart/staging temporary files remain")
            installed = json.loads((final.parent / "seforim-installation.json").read_bytes())
            require(installed["releaseID"] == RELEASE_ID and installed["repository"] == "Otzaria/SeforimLibrary"
                    and installed["assetID"] == 782942035, "Installed manifest identity differs")
            write(out / "actual-filesystem-cleanup.json",
                  {"all_temporary_paths_absent": absent, "staging_glob_leftovers": leftovers,
                   "downloads_root": str(downloads), "entries": sorted(p.name for p in downloads.iterdir()),
                   "installation_manifest": witness(final.parent / "seforim-installation.json")})
            report["app_binary_after"] = witness(binary)
            require(report["app_binary_before"] == report["app_binary_after"], "App changed during acceptance")
            report["build_after"] = qualified_build_context(app)
            require(report["build_before"] == report["build_after"], "Original SDK/image qualification changed")
            report["status"] = "ORIGINAL_INTEGRATED_V40_NATIVE_PASS"
            success = True
    except BaseException as error:
        report["status"] = "FAILED"
        report["error"] = type(error).__name__ + ": " + str(error)
        success = False
    finally:
        if udid:
            cleanup = []
            for argv in (["xcrun", "simctl", "terminate", udid, bundle_id],
                         ["xcrun", "simctl", "shutdown", udid]):
                try:
                    result = command(argv, check=False)
                    cleanup.append({"command": argv, "exit": result.returncode, "stderr": result.stderr[-1000:]})
                except Exception as error:
                    cleanup.append({"command": argv, "error": str(error)})
            report["cleanup"] = cleanup
            try:
                observed = json.loads(command(["xcrun", "simctl", "list", "devices", "-j"]).stdout)
                devices = [device for rows in observed["devices"].values() for device in rows
                           if device.get("udid") == udid]
                require(len(devices) == 1 and devices[0].get("state") == "Shutdown",
                        "Owned simulator shutdown was not observed")
                report["owned_simulator_state_after_shutdown"] = devices[0]
                report["owned_simulator_cleanup"] = (
                    "SHUTDOWN_RETAINED_FOR_ADDITIONAL_ACCEPTANCE" if success
                    else "SHUTDOWN_RETAINED_FOR_FAILURE_DIAGNOSIS")
                if success and args.delete_owned_simulator_on_success:
                    command(["xcrun", "simctl", "delete", udid], timeout=120)
                    observed = json.loads(command(["xcrun", "simctl", "list", "devices", "-j"]).stdout)
                    require(not any(device.get("udid") == udid
                                    for rows in observed["devices"].values() for device in rows),
                            "Owned simulator deletion was not observed")
                    report["owned_simulator_cleanup"] = "DELETED_VERIFIED_ABSENT"
            except Exception as error:
                report["status"] = "FAILED"
                report["owned_simulator_cleanup"] = "NOT_CONFIRMED"
                report["cleanup_error"] = str(error)
                success = False
        if before_source is not None:
            try:
                report["inputs_after"] = source_context(args.expected_sha, allow_build_projection=not args.prepare_only)
                require(before_source == report["inputs_after"], "Source changed during acceptance")
            except Exception as error:
                report["status"] = "FAILED"
                report["final_source_error"] = str(error)
                success = False
        report["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        write(out / "RESULT.json", report)
        index = [witness(p) for p in sorted(out.rglob("*")) if p.is_file()]
        write(out / "ARTIFACT_INDEX.json", {"files": index})
        print(json.dumps({key: report.get(key) for key in ("status", "output", "error", "owned_simulator_cleanup")}))
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
