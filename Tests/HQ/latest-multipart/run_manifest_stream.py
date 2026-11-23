#!/usr/bin/env python3
"""Execute only the two failed streaming controls; authenticate and retain the original35."""
from __future__ import annotations
import datetime, hashlib, importlib.util, json, os, pathlib, platform, subprocess, sys, traceback, zipfile

ROOT = pathlib.Path(__file__).resolve().parents[3]
HERE = ROOT / "Tests/HQ/latest-multipart"
OUT = ROOT / "build/latest-multipart-stream"
SPEC = importlib.util.spec_from_file_location("original_multipart_driver", HERE / "run_apple.py")
ORIGINAL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ORIGINAL)
ORIGINAL.OUTPUT = OUT
PIN = HERE / "MANIFEST_STREAM_INPUTS.json"

def write(path, obj):
    ORIGINAL.write(path, obj)

def verify_extra(pin):
    for relative, expected in pin["files"].items():
        path = ROOT / relative
        if ORIGINAL.record(path) != expected or path.read_bytes() != ORIGINAL.git("show", "HEAD:" + relative):
            raise RuntimeError("continuation input mismatch: " + relative)
    if PIN.read_bytes() != ORIGINAL.git("show", "HEAD:" + str(PIN.relative_to(ROOT))):
        raise RuntimeError("continuation binding differs from Git")

def authenticate_previous(pin):
    prior = pin["prior"]
    repo = "repos/davidpovarsky/Maktabah"
    run = json.loads(ORIGINAL.command("prior-run", ["gh", "api", repo + "/actions/runs/" + str(prior["run"])]))
    if (run["head_sha"], run["run_attempt"], run["conclusion"], run["status"]) != (
        prior["source"], 1, "failure", "completed"):
        raise RuntimeError("previous actual run identity differs")
    meta = json.loads(ORIGINAL.command("prior-artifact", ["gh", "api", repo + "/actions/artifacts/" + str(prior["artifact"])]))
    if meta["size_in_bytes"] != prior["bytes"] or meta["digest"] != "sha256:" + prior["sha256"] or meta["expired"]:
        raise RuntimeError("previous artifact metadata differs")
    if meta["workflow_run"]["id"] != prior["run"] or meta["workflow_run"]["head_sha"] != prior["source"]:
        raise RuntimeError("previous artifact belongs to a different run/source")
    archive = OUT / "retained-prior.zip"
    with archive.open("wb") as stream:
        result = subprocess.run(["gh", "api", repo + "/actions/artifacts/" + str(prior["artifact"]) + "/zip"],
                                stdout=stream, stderr=subprocess.PIPE, timeout=60)
    if result.returncode or ORIGINAL.record(archive) != {"bytes": prior["bytes"], "sha256": prior["sha256"]}:
        raise RuntimeError("previous archive transfer failed or digest differs")
    with zipfile.ZipFile(archive) as z:
        rows = [item for item in z.infolist() if not item.is_dir()]
        if len(rows) != prior["crc_members"] or sum(row.file_size for row in rows) > 100_000_000:
            raise RuntimeError("previous archive inventory differs")
        identities = {}
        for row in rows:
            path = pathlib.PurePosixPath(row.filename)
            if path.is_absolute() or ".." in path.parts or row.filename in identities:
                raise RuntimeError("unsafe/duplicate previous archive member")
            if ((row.external_attr >> 16) & 0o170000) == 0o120000:
                raise RuntimeError("previous archive symlink refused")
            digest = hashlib.sha256(); count = 0
            with z.open(row) as stream:
                while data := stream.read(1_048_576):
                    digest.update(data); count += len(data)
            identities[row.filename] = {"bytes": count, "sha256": digest.hexdigest()}
        index = json.loads(z.read("ARTIFACT_INDEX.json"))["files"]
        if len(index) != prior["index_rows"] or len({row["path"] for row in index}) != len(index):
            raise RuntimeError("previous full index coverage differs")
        if set(row["path"] for row in index) != set(identities) - {"ARTIFACT_INDEX.json"}:
            raise RuntimeError("previous full index names differ")
        for row in index:
            if identities[row["path"]] != {key: row[key] for key in ["bytes", "sha256"]}:
                raise RuntimeError("previous indexed file differs: " + row["path"])
        previous = json.loads(z.read("RESULT.json"))
        controlled = json.loads(z.read("controlled-state/RESULT.json"))
    if previous.get("source_integrity_error") or previous["source_commit"] != prior["source"]:
        raise RuntimeError("previous actual source integrity not established")
    if previous["inputs_before"] != previous["inputs_after"] or previous["inputs_before"] != pin["original_inputs"]:
        raise RuntimeError("previous complete source closure differs")
    if previous["counts"] != {"PASS": 35, "FAIL": 2, "SKIP": 0, "NOT_RUN": 0}:
        raise RuntimeError("previous35/2 actual count differs")
    old_cases = previous["cases"]
    if len(old_cases) != 37 or len(set(row["name"] for row in old_cases)) != 37:
        raise RuntimeError("previous case inventory differs")
    passed = sorted(row["name"] for row in old_cases if row["status"] == "PASS")
    failed = sorted(row["name"] for row in old_cases if row["status"] == "FAIL")
    if passed != sorted(pin["retained_passes"]) or failed != sorted(pin["selected_controls"]):
        raise RuntimeError("previous per-case result differs")
    if sorted((row["name"], row["status"]) for row in controlled["cases"]) != sorted(
            (row["name"], row["status"]) for row in old_cases):
        raise RuntimeError("previous native output and independently parsed result disagree")
    write(OUT / "RETAINED_PRIOR.json", {"run": prior["run"], "source": prior["source"],
         "artifact": prior["artifact"], "archive": ORIGINAL.record(archive),
         "crc_members": len(rows), "index_rows": len(index), "retained_passes": passed,
         "failed_controls_not_reused": failed, "original_inputs": previous["inputs_before"]})
    return previous

def main():
    if OUT.exists():
        raise RuntimeError("owned continuation output must be absent")
    OUT.mkdir(parents=True)
    pin = json.loads(PIN.read_text())
    names = pin["selected_controls"]
    report = {"schema": 1, "status": "NOT_RUN", "scope": "Two original failed Apple streaming controls",
              "selected_controls": names, "replayed_previous35": 0,
              "native_app_acceptance": False, "sqlite_installation_acceptance": False,
              "run_id": os.environ.get("GITHUB_RUN_ID"), "attempt": os.environ.get("GITHUB_RUN_ATTEMPT")}
    result_code = 1
    retained = False
    try:
        head = ORIGINAL.git("rev-parse", "HEAD").decode().strip()
        report["source_commit"] = head
        if os.environ.get("GITHUB_SHA") != head or os.environ.get("GITHUB_RUN_ATTEMPT") != "1":
            raise RuntimeError("exact source / first-attempt admission failed")
        if os.environ.get("GITHUB_REPOSITORY") != "davidpovarsky/Maktabah" or os.environ.get("GITHUB_REF") != (
                "refs/heads/codex/otzaria-multipart-manifest-stream-20261123"):
            raise RuntimeError("exact repository/branch admission failed")
        if sys.platform != "darwin":
            raise RuntimeError("actual Apple platform required")
        verify_extra(pin)
        original_manifest = json.loads((HERE / "SOURCE_INPUTS.json").read_text())
        report["inputs_before"] = ORIGINAL.verify_inputs(original_manifest)
        if report["inputs_before"] != pin["original_inputs"]:
            raise RuntimeError("old complete18-file source closure changed")
        if ORIGINAL.git("status", "--porcelain", "--untracked-files=no").strip():
            raise RuntimeError("tracked source must remain clean")
        previous = authenticate_previous(pin)
        report["platform"] = platform.platform()
        report["xcode"] = ORIGINAL.command("xcode", ["xcodebuild", "-version"])
        report["swift"] = ORIGINAL.command("swift", ["xcrun", "swiftc", "--version"])
        sdk = ORIGINAL.command("sdk", ["xcrun", "--sdk", "macosx", "--show-sdk-path"]).strip()
        compiler = ORIGINAL.command("compiler", ["xcrun", "--find", "swiftc"]).strip()
        compiler_id = ORIGINAL.record(pathlib.Path(compiler))
        report["compiler_binary"] = {"path": compiler, **compiler_id}
        report["sdk"] = sdk
        for key in ["platform", "xcode", "swift", "sdk"]:
            if report[key] != previous[key]:
                raise RuntimeError("prior actual Apple environment differs: " + key)
        if compiler_id != {key: previous["compiler_binary"][key] for key in ["bytes", "sha256"]}:
            raise RuntimeError("prior actual compiler bytes differ")
        retained = True
        text = (HERE / "MultipartArchiveControls.swift").read_text()
        marker = "@main\nprivate struct MultipartArchiveControls {"
        if text.count(marker) != 1:
            raise RuntimeError("original helper boundary differs")
        prefix = text[:text.index(marker)]
        if ORIGINAL.sha(prefix.encode()) != pin["helper_prefix_sha256"]:
            raise RuntimeError("original helpers changed")
        suffix = (HERE / "ManifestStreamMain.swift").read_text()
        generated = OUT / "ManifestStreamControls.swift"
        generated.write_text(prefix + suffix)
        report["generated_harness"] = {"original_prefix_sha256": pin["helper_prefix_sha256"],
                                      "main": ORIGINAL.record(HERE / "ManifestStreamMain.swift"),
                                      "compiled_source": ORIGINAL.record(generated)}
        projection = ORIGINAL.capacity_projection()
        binary = OUT / "ManifestStreamControls"
        cache = pathlib.Path(os.environ["RUNNER_TEMP"]) / ("multipart-stream-modules-" + os.environ["GITHUB_RUN_ID"])
        argv = ["xcrun", "swiftc", "-sdk", sdk, "-swift-version", "5", "-parse-as-library",
                "-Onone", "-module-cache-path", str(cache)]
        argv += [str(ROOT / path) for path in ORIGINAL.PRODUCT]
        argv += [str(projection), str(generated), "-o", str(binary)]
        ORIGINAL.command("compile", argv, 300)
        report["binary"] = ORIGINAL.record(binary)
        state = OUT / "controlled-state"; state.mkdir()
        env = dict(os.environ); env["OTZARIA_DATA_PROFILE"] = "production"
        env.pop("OTZARIA_BOOTSTRAP_RELEASE_ID", None)
        ORIGINAL.command("controls", [str(binary), str(state)], 120, env)
        actual = json.loads((state / "RESULT.json").read_text())
        if len(actual["cases"]) != 2 or sorted(row["name"] for row in actual["cases"]) != sorted(names):
            raise RuntimeError("continuation case inventory differs")
        if actual["counts"] != {"PASS": 2, "FAIL": 0, "SKIP": 0} or any(row["status"] != "PASS" for row in actual["cases"]):
            raise RuntimeError("two actual streaming controls did not pass")
        if actual["native_app_or_sqlite_installation_acceptance"] is not False:
            raise RuntimeError("component scope expanded")
        report["actual_component_result"] = actual
        report["status"] = "APPLE_MULTIPART37_QUALIFIED_35_RETAINED_2_EXECUTED"
        result_code = 0
    except Exception as error:
        report["status"] = "APPLE_STREAM_CONTINUATION_FAIL"
        report["error"] = str(error)
        (OUT / "failure.log").write_text(traceback.format_exc())
    finally:
        try:
            verify_extra(pin)
            report["inputs_after"] = ORIGINAL.verify_inputs(json.loads((HERE / "SOURCE_INPUTS.json").read_text()))
            if report.get("inputs_before") != report["inputs_after"]:
                raise RuntimeError("source changed during continuation")
        except Exception as error:
            report["status"] = "APPLE_STREAM_CONTINUATION_FAIL"
            report["source_integrity_error"] = str(error)
            result_code = 1
        report["actual_cases"] = ORIGINAL.partial_rows(names)
        report["actual_counts"] = {status: sum(row["status"] == status for row in report["actual_cases"])
                                  for status in ["PASS", "FAIL", "SKIP", "NOT_RUN"]}
        report["retained_pass_count"] = 35 if retained else 0
        report["retained_pass_source"] = pin["prior"]["source"] if retained else None
        report["commands"] = ORIGINAL.COMMANDS
        report["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        write(OUT / "RESULT.json", report)
        files = [{"path": str(path.relative_to(OUT)), **ORIGINAL.record(path)}
                 for path in sorted(OUT.rglob("*")) if path.is_file() and path.name != "ARTIFACT_INDEX.json"]
        write(OUT / "ARTIFACT_INDEX.json", {"schema": 1, "files": files})
        print(json.dumps({key: report.get(key) for key in ["status", "actual_counts", "retained_pass_count", "error"]}), flush=True)
    return result_code

if __name__ == "__main__":
    sys.exit(main())
