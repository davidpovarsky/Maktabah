#!/usr/bin/env python3
"""Qualify original multipart components on Apple; this is not app installation acceptance."""
from __future__ import annotations
import argparse, datetime, hashlib, json, os, pathlib, platform, re, signal, subprocess, sys, traceback

ROOT = pathlib.Path(__file__).resolve().parents[3]
HERE = ROOT / "Tests/HQ/latest-multipart"
OUTPUT = ROOT / "build/latest-multipart"
COMMANDS = []
PRODUCT = [
    "Source/Otzaria/DataProfiles/OtzariaDataProfile.swift",
    "Source/Otzaria/DataProfiles/OtzariaDataProfileRegistry.swift",
    "Source/Otzaria/Bootstrap/OtzariaDatabaseDownloadModels.swift",
    "Source/Otzaria/Bootstrap/OtzariaDownloadPolicy.swift",
    "Source/Otzaria/Bootstrap/OtzariaLibraryReleaseClient.swift",
    "Source/Otzaria/Bootstrap/OtzariaDatabaseDownloader.swift",
]

def sha(data):
    return hashlib.sha256(data).hexdigest()

def record(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": sha(data)}

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")

def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=30)

def command(name, argv, seconds=30, env=None):
    log = OUTPUT / (name + ".log")
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    with log.open("wb") as stream:
        proc = subprocess.Popen(argv, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                                env=env, start_new_session=True)
        timed_out = False
        try:
            rc = proc.wait(timeout=seconds)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(proc.pid, signal.SIGTERM)
            try:
                rc = proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                rc = proc.wait(timeout=10)
    item = {"name": name, "argv": [str(x) for x in argv], "started_at": started,
            "exit_code": rc, "timeout_seconds": seconds, "timed_out": timed_out,
            "log": str(log.relative_to(OUTPUT)), **record(log)}
    COMMANDS.append(item)
    write(OUTPUT / "COMMANDS.json", COMMANDS)
    if rc or timed_out:
        raise RuntimeError(name + " failed: " + json.dumps(item))
    return log.read_text()

def verify_inputs(manifest):
    paths = sorted(manifest["files"])
    for relative in paths:
        path = ROOT / relative
        expected = manifest["files"][relative]
        if record(path) != expected:
            raise RuntimeError("bound input changed: " + relative)
        if path.read_bytes() != git("show", "HEAD:" + relative):
            raise RuntimeError("working input differs from actual Git source: " + relative)
    self_relative = "Tests/HQ/latest-multipart/SOURCE_INPUTS.json"
    if (ROOT / self_relative).read_bytes() != git("show", "HEAD:" + self_relative):
        raise RuntimeError("source input manifest differs from actual Git source")
    return {relative: record(ROOT / relative) for relative in paths}

def capacity_projection():
    relative = "Source/Otzaria/Bootstrap/OtzariaDatabaseInstaller.swift"
    source = (ROOT / relative).read_text()
    prefix = "    static func requiredDownloadCapacity("
    if source.count(prefix) != 1:
        raise RuntimeError("capacity function must exist exactly once")
    start = source.index(prefix)
    opening = source.index("{", start)
    level = 1
    end = opening + 1
    while level:
        if source[end] == "{": level += 1
        if source[end] == "}": level -= 1
        end += 1
    method = source[start:end]
    constants = []
    for name in ("safetyReserve", "unknownOutputMultiplier"):
        matches = re.findall(r"^    static let " + name + r": Int64 = [0-9_]+$", source, re.M)
        if len(matches) != 1:
            raise RuntimeError("capacity constant must exist exactly once: " + name)
        constants.append(matches[0])
    text = "import Foundation\n\nenum DownloadCapacityFixture {\n"
    text += "\n".join(constants) + "\n" + method + "\n}\n"
    path = OUTPUT / "DownloadCapacityFixture.swift"
    path.write_text(text)
    write(OUTPUT / "CAPACITY_PROJECTION.json", {
        "source": relative, "source_identity": record(ROOT / relative),
        "method_sha256": sha(method.encode()), "constants": constants,
        "projection": record(path),
        "scope": "Byte-exact original static method and constants, no algorithm replacement",
        "full_installer_compile": False,
    })
    return path

def partial_rows(names):
    rows = {}
    path = OUTPUT / "controls.log"
    if path.exists():
        for line in path.read_text(errors="replace").splitlines():
            match = re.fullmatch(r"(PASS|FAIL) ([A-Za-z0-9_]+)(?:: (.*))?", line)
            if match and match.group(2) in names:
                name = match.group(2)
                if name in rows:
                    raise RuntimeError("duplicate emitted control: " + name)
                rows[name] = {"name": name, "status": match.group(1)}
                if match.group(3):
                    rows[name]["error"] = match.group(3)
    return [rows.get(name, {"name": name, "status": "NOT_RUN"}) for name in names]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    if OUTPUT.exists():
        raise RuntimeError("owned output must be absent; no overwriting earlier evidence")
    OUTPUT.mkdir(parents=True)
    manifest = json.loads((HERE / "SOURCE_INPUTS.json").read_text())
    names = json.loads((HERE / "CASES.json").read_text())["logical_controls"]
    if len(names) != 37 or len(set(names)) != 37:
        raise RuntimeError("exact 37-control inventory required")
    report = {"schema": 1, "status": "NOT_RUN", "scope": "Apple component controls",
              "native_app_acceptance": False, "sqlite_installation_acceptance": False,
              "production_archive_payload_downloaded": False,
              "compile_products": PRODUCT, "expected_controls": names,
              "github": {key: os.environ.get(key) for key in [
                  "GITHUB_REPOSITORY", "GITHUB_SHA", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT",
                  "GITHUB_REF", "RUNNER_NAME", "RUNNER_OS", "RUNNER_ARCH"]}}
    failure = None
    try:
        head = git("rev-parse", "HEAD").decode().strip()
        report["source_commit"] = head
        report["source_tree"] = git("rev-parse", "HEAD^{tree}").decode().strip()
        if os.environ.get("GITHUB_SHA") != head:
            raise RuntimeError("actual checkout differs from workflow source")
        if os.environ.get("GITHUB_REPOSITORY") != "davidpovarsky/Maktabah":
            raise RuntimeError("repository admission failed")
        if os.environ.get("GITHUB_REF") != "refs/heads/codex/otzaria-latest-multipart-20261123":
            raise RuntimeError("branch admission failed")
        if os.environ.get("GITHUB_RUN_ATTEMPT") != "1":
            raise RuntimeError("rerun admission refused; source-bound new activation required")
        report["inputs_before"] = verify_inputs(manifest)
        if git("status", "--porcelain", "--untracked-files=no").strip():
            raise RuntimeError("tracked source must be clean")
        projection = capacity_projection()
        if args.prepare_only:
            report["status"] = "SOURCE_PREPARED_NOT_COMPILED"
            return 0
        if sys.platform != "darwin":
            raise RuntimeError("authentic Apple platform required")
        report["platform"] = platform.platform()
        report["xcode"] = command("xcode", ["xcodebuild", "-version"])
        report["swift"] = command("swift", ["xcrun", "swiftc", "--version"])
        sdk = command("sdk", ["xcrun", "--sdk", "macosx", "--show-sdk-path"]).strip()
        compiler = command("compiler", ["xcrun", "--find", "swiftc"]).strip()
        report["compiler_binary"] = {"path": compiler, **record(pathlib.Path(compiler))}
        report["sdk"] = sdk
        binary = OUTPUT / "MultipartArchiveControls"
        module_cache = pathlib.Path(os.environ["RUNNER_TEMP"]) / ("multipart-modules-" + os.environ["GITHUB_RUN_ID"])
        argv = ["xcrun", "swiftc", "-sdk", sdk, "-swift-version", "5",
                "-parse-as-library", "-Onone", "-module-cache-path", str(module_cache)]
        argv += [str(ROOT / p) for p in PRODUCT]
        argv += [str(projection), str(HERE / "MultipartArchiveControls.swift"), "-o", str(binary)]
        command("compile", argv, 300)
        report["compiled_binary"] = record(binary)
        state = OUTPUT / "controlled-state"
        state.mkdir()
        env = dict(os.environ)
        env.pop("OTZARIA_BOOTSTRAP_RELEASE_ID", None)
        env["OTZARIA_DATA_PROFILE"] = "production"
        command("controls", [str(binary), str(HERE), str(state)], 180, env)
        result = json.loads((state / "RESULT.json").read_text())
        rows = result["cases"]
        if len(rows) != len(names) or sorted(row["name"] for row in rows) != sorted(names):
            raise RuntimeError("control result inventory differs")
        if any(row["status"] != "PASS" for row in rows):
            raise RuntimeError("actual component control failed")
        if result["counts"] != {"PASS": 37, "FAIL": 0, "SKIP": 0}:
            raise RuntimeError("actual result counts differ")
        if result["status"] != "APPLE_COMPONENT_PASS":
            raise RuntimeError("component result is not PASS")
        if result["native_app_or_sqlite_installation_acceptance"] is not False:
            raise RuntimeError("component scope incorrectly expanded")
        report["actual_component_result"] = result
        report["status"] = "APPLE_COMPONENT_PASS"
        return 0
    except Exception as exc:
        failure = str(exc)
        report["status"] = "APPLE_COMPONENT_FAIL"
        report["error"] = failure
        (OUTPUT / "failure.log").write_text(traceback.format_exc())
        return 1
    finally:
        try:
            report["inputs_after"] = verify_inputs(manifest)
            if report.get("inputs_before") != report["inputs_after"]:
                raise RuntimeError("source changed during execution")
        except Exception as exc:
            report["status"] = "APPLE_COMPONENT_FAIL"
            report["source_integrity_error"] = str(exc)
        report["commands"] = COMMANDS
        report["cases"] = partial_rows(names)
        report["counts"] = {status: sum(row["status"] == status for row in report["cases"])
                            for status in ("PASS", "FAIL", "SKIP", "NOT_RUN")}
        report["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        write(OUTPUT / "RESULT.json", report)
        index = []
        for path in sorted(OUTPUT.rglob("*")):
            if path.is_file() and path.name != "ARTIFACT_INDEX.json":
                index.append({"path": str(path.relative_to(OUTPUT)), **record(path)})
        write(OUTPUT / "ARTIFACT_INDEX.json", {"schema": 1, "files": index})
        print(json.dumps({"status": report["status"], "counts": report["counts"],
                          "error": failure, "output": str(OUTPUT)}), flush=True)

if __name__ == "__main__":
    result = main()
    final = json.loads((OUTPUT / "RESULT.json").read_text())
    sys.exit(0 if result == 0 and final["status"] in ("APPLE_COMPONENT_PASS", "SOURCE_PREPARED_NOT_COMPILED") else 1)
