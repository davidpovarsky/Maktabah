#!/usr/bin/env python3
"""One real full-v32 AB/BA source-service comparison; no application/UI claim."""
from __future__ import annotations
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import runpy
import shutil
import signal
import sqlite3
import subprocess
import sys
import tempfile
import time
import traceback

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "build/reader-perf-native-evidence"
SERVICE = "Source/Otzaria/Reading/OtzariaReadingUnitService.swift"
BASE = "1969b2065469b55e38e42cbb838a469ffa6a80f7"


def require(value, message):
    if not value:
        raise RuntimeError(message)


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, timeout=60)


def save(name, value):
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / name).write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def command(args, *, cwd=ROOT, timeout=60):
    return subprocess.check_output(args, cwd=cwd, text=True, stderr=subprocess.STDOUT, timeout=timeout).strip()


def bounded(args, log_path, *, cwd, timeout):
    with log_path.open("w") as log:
        process = subprocess.Popen(args, cwd=cwd, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        try:
            return process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
            raise


def namespaced_baseline(original):
    replacements = (
        (b"OtzariaReadingUnitService", b"BaselineOtzariaReadingUnitService"),
        (b"OtzariaReadingUnitError", b"BaselineOtzariaReadingUnitError"),
    )
    modified = original
    for old, new in replacements:
        require(old in original and new not in original, "Unexpected baseline namespace")
        modified = modified.replace(old, new)
    reversed_bytes = modified
    for old, new in reversed(replacements):
        reversed_bytes = reversed_bytes.replace(new, old)
    require(reversed_bytes == original, "Baseline name-only transformation did not reverse exactly")
    return modified


def exact_candidate(original):
    replacements = (
        (b"        var plainSegments: [String] = []\n",
         b"        var plainSegments: [String] = []\n        plainSegments.reserveCapacity(lines.count)\n"),
        (b"        var lineAnchors: [OtzariaLineAnchor] = []\n",
         b"        var lineAnchors: [OtzariaLineAnchor] = []\n        lineAnchors.reserveCapacity(lines.count)\n"),
        (b"            let plain = line.html.otsariaPlainText\n",
         b"            let plain = line.html.otsariaPlainText\n            let plainUTF16Length = plain.utf16.count\n"),
        (b"length: plain.utf16.count)", b"length: plainUTF16Length)"),
        (b"currentOffset += plain.utf16.count + 1", b"currentOffset += plainUTF16Length + 1"),
    )
    modified = original
    for old, new in replacements:
        require(modified.count(old) == 1, "Original small candidate hunk changed")
        modified = modified.replace(old, new)
    return modified


def preflight(expected_sha=None, snapshot="source-before.json"):
    config = json.loads((HERE / "inputs.json").read_text(encoding="utf-8"))
    head = git("rev-parse", "HEAD").decode().strip()
    if expected_sha is not None:
        require(head == expected_sha and len(expected_sha) == 40, "Unexpected immutable workflow checkout")
    require(config["baseline_sha"] == BASE, "Unreviewed source baseline")
    product = config["candidate_source_sha"]
    require(git("rev-parse", f"{product}:Source").decode().strip() == config["source_tree"],
            "Candidate source tree pin changed")
    require(git("rev-parse", "HEAD:Source").decode().strip() == config["source_tree"],
            "Runtime checkout Source tree differs from product")
    for tree, pin in config["unchanged_trees"].items():
        require(git("rev-parse", f"HEAD:{tree}").decode().strip() == pin
                and git("rev-parse", f"{BASE}:{tree}").decode().strip() == pin,
                "Unrelated protected tree changed: " + tree)
    recorded = []
    for relative, pin in config["input_sha256"].items():
        path = ROOT / relative
        require(path.is_file() and not path.is_symlink(), "Missing regular input: " + relative)
        raw = path.read_bytes()
        require(raw == git("show", "HEAD:" + relative), "Input differs from immutable checkout: " + relative)
        require(hashlib.sha256(raw).hexdigest() == pin, "Exact dependency digest changed: " + relative)
        if relative in config["compiled_sources"] and relative != SERVICE:
            require(raw == git("show", BASE + ":" + relative), "Original dependency changed: " + relative)
        recorded.append({"path": relative, "bytes": len(raw), "sha256": pin,
                         "git_blob": git("rev-parse", "HEAD:" + relative).decode().strip()})
    for path in [HERE / "run.py", HERE / "inputs.json", HERE / "PairedReaderTiming.swift",
                 ROOT / ".github/workflows/otzaria-reader-perf.yml"]:
        relative = path.relative_to(ROOT).as_posix()
        require(path.read_bytes() == git("show", "HEAD:" + relative), "Owned driver input drift: " + relative)
        recorded.append({"path": relative, "bytes": path.stat().st_size, "sha256": sha(path),
                         "git_blob": git("rev-parse", "HEAD:" + relative).decode().strip()})
    original = git("show", BASE + ":" + SERVICE)
    candidate = (ROOT / SERVICE).read_bytes()
    require(candidate == exact_candidate(original), "Candidate exceeds exact approved capacity/UTF16 change")
    transformed = namespaced_baseline(original)
    report = {
        "status": "EXACT_SOURCE_ADMISSION_PASS_NOT_EXECUTION",
        "checkout_sha": head, "baseline_sha": BASE, "candidate_source_sha": product,
        "source_tree": config["source_tree"], "inputs": recorded,
        "baseline_service_sha256": hashlib.sha256(original).hexdigest(),
        "candidate_service_sha256": hashlib.sha256(candidate).hexdigest(),
        "namespaced_baseline_sha256": hashlib.sha256(transformed).hexdigest(),
        "baseline_transformation_reversed_exactly": True,
        "native_source_service_executed": False, "ui_executed": 0, "physical_device_executed": 0,
    }
    save(snapshot, report)
    return config, report, transformed


def file_witness(path):
    resolved = Path(path).resolve(strict=True)
    return {"path": str(resolved), "bytes": resolved.stat().st_size, "sha256": sha(resolved)}


def prepare_database(config, work, report, original):
    source = config["source_database"]
    known = [
        Path(os.environ["RUNNER_TEMP"]) / "seforim.db",
        ROOT / "build/hq-v32-prebuilt-native/seforim.db",
    ]
    observations = []
    selected = None
    for path in known:
        exists = path.is_file() and not path.is_symlink()
        row = {"path": str(path), "exists_regular": exists, "reused": False}
        if exists:
            row["bytes"] = path.stat().st_size
            if row["bytes"] == source["databaseBytes"]:
                row["sha256"] = sha(path)
                if row["sha256"] == source["databaseSHA256"]:
                    selected = path.resolve()
                    row["reused"] = True
        observations.append(row)
        if selected is not None:
            break
    report["known_fixture_observations"] = observations
    report["existing_fixture_modified_or_deleted"] = False
    if selected is None:
        require(shutil.disk_usage(work).free >= 7 * 1024**3, "Need 7 GiB for one owned full fixture")
        release = original["api"]("repos/Otzaria/SeforimLibrary/releases/tags/" + source["releaseTag"])
        require(release["id"] == source["releaseID"] and release["tag_name"] == source["releaseTag"],
                "Original official release identity changed")
        asset = next(item for item in release["assets"] if item["id"] == source["assetID"])
        original["authenticate_asset"](asset, source["assetName"], source["assetBytes"], source["assetSHA256"])
        save("official-source-release.json", release)
        save("official-source-asset.json", asset)
        archive = work / source["assetName"]
        report["source_download"] = original["download"](
            asset, archive, source["assetBytes"], source["assetSHA256"])
        selected = work / "seforim.db"
        with (OUT / "fixture-decompression.log").open("w") as log:
            subprocess.run([shutil.which("zstd"), "-d", "--long=31", "--no-progress",
                            "-f", str(archive), "-o", str(selected)],
                           cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=1800)
        report["fixture_origin"] = "NEW_UNIQUE_CI_OWNED_OFFICIAL_FULL_V32"
    else:
        report["fixture_origin"] = "REUSED_AUTHENTICATED_ORIGINAL_CI_FIXTURE_READ_ONLY"
    original["checked_file"](selected, source["databaseBytes"], source["databaseSHA256"])
    uri = selected.as_uri() + "?mode=ro&immutable=1"
    with sqlite3.connect(uri, uri=True) as database:
        require(database.execute("PRAGMA query_only=ON").fetchall() == [], "Unexpected SQLite pragma result")
        counts = (database.execute("SELECT COUNT(*) FROM book").fetchone()[0],
                  database.execute("SELECT COUNT(*) FROM line").fetchone()[0])
        require(counts == (7876, 7080797), "Real full-v32 corpus counts differ")
    report["database"] = {"path": str(selected), "bytes": selected.stat().st_size,
                          "sha256_before": sha(selected), "books": counts[0], "lines": counts[1],
                          "immutable_readonly_uri": uri}
    save("RESULT.json", report)
    return selected, uri


def native_execute(config, report, baseline):
    require(sys.platform == "darwin", "Actual macOS Apple compiler required")
    require(os.environ.get("RUNNER_TEMP"), "An owned CI runner temporary directory is required")
    require(shutil.disk_usage(os.environ["RUNNER_TEMP"]).free >= 7 * 1024**3,
            "Need 7 GiB available before preparation")
    report.update(status="STARTED_NOT_ACCEPTED", started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  host=platform.platform(), native_source_service_executed=False,
                  github_run_id=os.environ.get("GITHUB_RUN_ID"), github_run_attempt=os.environ.get("GITHUB_RUN_ATTEMPT"),
                  boundary="Same-process macOS source service; service-cache cold/warm only. No app, UIKit, p95 or physical-device acceptance.")
    original = runpy.run_path(str(ROOT / "Scripts/CI/hq-v32-prebuilt-native.py"))
    swiftc = Path(command(["xcrun", "--sdk", "macosx", "--find", "swiftc"]))
    sdk = Path(command(["xcrun", "--sdk", "macosx", "--show-sdk-path"]))
    brew_prefix = Path(command(["brew", "--prefix", "zstd"]))
    zstd_library = (brew_prefix / "lib/libzstd.dylib").resolve(strict=True)
    zstd_tool = Path(shutil.which("zstd") or "")
    require(zstd_tool.is_file(), "Existing native zstd is required")
    import ctypes
    library = ctypes.CDLL(str(zstd_library))
    library.ZSTD_versionString.restype = ctypes.c_char_p
    settings = sdk / "SDKSettings.json"
    sqlite_stub = sdk / "usr/lib/libsqlite3.tbd"
    report["toolchain"] = {
        "xcode": command(["xcodebuild", "-version"]),
        "swift": command([str(swiftc), "--version"]),
        "macos_sdk_version": command(["xcrun", "--sdk", "macosx", "--show-sdk-version"]),
        "macos_product_version": command(["sw_vers", "-productVersion"]),
        "macos_build_version": command(["sw_vers", "-buildVersion"]),
        "developer_dir": os.environ.get("DEVELOPER_DIR"),
        "swift_driver": file_witness(swiftc),
        "swift_frontend": file_witness(command(["xcrun", "--find", "swift-frontend"])),
        "sdk_settings": file_witness(settings),
        "sqlite_sdk_link_stub": file_witness(sqlite_stub),
        "zstd_library": file_witness(zstd_library),
        "zstd_cli": file_witness(zstd_tool),
        "zstd_version": library.ZSTD_versionString().decode("ascii"),
    }
    report["toolchain"]["zstd_linkage"] = command(["otool", "-L", str(zstd_library)])
    save("RESULT.json", report)
    database = None
    with tempfile.TemporaryDirectory(prefix="otzaria-reader-perf-" + os.environ.get("GITHUB_RUN_ID", "local") + "-",
                                     dir=os.environ["RUNNER_TEMP"]) as directory:
        work = Path(directory)
        report["unique_owned_work_directory"] = str(work)
        try:
            database, uri = prepare_database(config, work, report, original)
            baseline_file = work / "BaselineReadingUnitService.swift"
            baseline_file.write_bytes(baseline)
            (OUT / "BaselineReadingUnitService.swift").write_bytes(baseline)
            input_file = work / "input.json"
            input_file.write_text(json.dumps({"uri": uri}) + "\n", encoding="utf-8")
            binary = work / "paired-original-reader"
            compile_command = [
                str(swiftc), "-parse-as-library", "-swift-version", "6",
                "-Xfrontend", "-strict-concurrency=complete", "-O", "-sdk", str(sdk),
                "-L", str(zstd_library.parent), "-lzstd", "-Xlinker", "-rpath", "-Xlinker", str(zstd_library.parent),
                *[str(ROOT / path) for path in config["compiled_sources"]],
                str(baseline_file), str(HERE / "PairedReaderTiming.swift"), "-o", str(binary),
            ]
            report["compile_command"] = compile_command
            report["compile_exit"] = bounded(compile_command, OUT / "compile.log", cwd=work, timeout=300)
            require(report["compile_exit"] == 0, "Actual Apple source-service compilation failed")
            report["executable"] = file_witness(binary)
            report["executable_linkage"] = command(["otool", "-L", str(binary)])
            shutil.copy2(binary, OUT / "paired-original-reader")
            execution = [str(binary), str(input_file), str(OUT / "MEASUREMENTS.json")]
            report["execution_command"] = execution
            report["native_source_service_executed"] = True
            report["execute_exit"] = bounded(execution, OUT / "execution.log", cwd=work, timeout=600)
            require(report["execute_exit"] == 0, "Actual original full-v32 comparison failed")
            measured = json.loads((OUT / "MEASUREMENTS.json").read_text(encoding="utf-8"))
            require(measured["status"] == "EXACT_ORIGINAL_FULL_V32_UNIT_PARITY_PASS_PERFORMANCE_OBSERVATION_ONLY",
                    "Original runtime proof absent")
            require(measured["timed_reader_calls"] == 8 and len(measured["records"]) == 4
                    and len(measured["round_proofs"]) == 2, "Original AB/BA call count changed")
            comparisons = []
            for number in range(2):
                rows = {row["version"]: row for row in measured["records"] if row["round"] == number}
                require(set(rows) == {"baseline", "candidate"}, "Both original implementations required")
                comparisons.append({"round": number, **{
                    mode + "_change_percent":
                        (rows["candidate"][mode + "_ms"] / rows["baseline"][mode + "_ms"] - 1) * 100
                    for mode in ["cold", "warm"]}})
            report.update(native_source_service_executed=True,
                          status="EXACT_ORIGINAL_FULL_V32_UNIT_PARITY_PASS_PERFORMANCE_OBSERVATION_ONLY",
                          matched_comparisons=comparisons, performance_acceptance=False,
                          observed_nonregression_in_all_four_pairs=all(
                              row[mode + "_change_percent"] <= 0 for row in comparisons for mode in ["cold", "warm"]),
                          measurement_sha256=sha(OUT / "MEASUREMENTS.json"))
        finally:
            if database is not None and "database" in report:
                report["database"]["sha256_after"] = sha(database)
                require(report["database"]["sha256_after"] == config["source_database"]["databaseSHA256"],
                        "Full source database changed during the owned run")
                report["database"]["wal_present_after"] = Path(str(database) + "-wal").exists()
                report["database"]["shm_present_after"] = Path(str(database) + "-shm").exists()
                require(not report["database"]["wal_present_after"] and not report["database"]["shm_present_after"],
                        "Unexpected write sidecar for original read-only fixture")
            save("RESULT.json", report)
    report["owned_work_directory_cleaned"] = not Path(report["unique_owned_work_directory"]).exists()
    require(report["owned_work_directory_cleaned"], "Owned temporary output was not cleaned")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["prepare", "execute"])
    parser.add_argument("--expected-sha", required=True)
    args = parser.parse_args()
    report = {"status": "NOT_EXECUTED", "ui_executed": 0, "physical_device_executed": 0}
    try:
        config, report, baseline = preflight(args.expected_sha)
        if args.mode == "execute":
            native_execute(config, report, baseline)
            _, after, _ = preflight(args.expected_sha, snapshot="source-after.json")
            require(report["inputs"] == after["inputs"], "Executed source inputs changed")
        report["finished_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        save("RESULT.json", report)
        print(json.dumps({key: report.get(key) for key in
                          ["status", "checkout_sha", "candidate_source_sha", "native_source_service_executed",
                           "observed_nonregression_in_all_four_pairs", "ui_executed", "physical_device_executed"]}))
        return 0
    except BaseException as error:
        report["status"] = "FAILED"
        if "unique_owned_work_directory" in report:
            report["owned_work_directory_cleaned"] = not Path(report["unique_owned_work_directory"]).exists()
        report["failure"] = {"type": type(error).__name__, "message": str(error)}
        report["finished_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        save("RESULT.json", report)
        (OUT / "failure.log").write_text(traceback.format_exc(), encoding="utf-8")
        print(json.dumps({"status": "FAILED", "failure": report["failure"]}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
