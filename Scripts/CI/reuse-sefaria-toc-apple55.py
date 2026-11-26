#!/usr/bin/env python3
"""Admit one sealed Apple Foundation55 result only for byte-identical inputs.

Replays the existing archived evidence verifier, without compiling or executing
Swift. This does not grant Native UI, release, network or physical acceptance.
"""
import argparse
import datetime as dt
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path, PurePosixPath
import runpy
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = "docs/hq-integration/sefaria-apple55-result-20261120"
MANIFEST_SHA256 = "21a43fce76d0c6b63bb0b6c3f354e185ee5fb4f41508f16908a7186ef32564ff"
EVIDENCE_COMMIT = "e3922797c56c3c8939ccf83486952062f265fe25"
SOURCE = "ce56baedf0fec15f61a117e5649e8c6865781120"
RUN = 44743177022
ARTIFACT_SHA256 = "7fc1d299c61bf9d34eb8674cf4b262f880a7189b9b0de4171d49fc66f6ad94d7"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def checked_sources(gate, expected_sha, historical):
    # Original function compares each actual file byte-for-byte with HEAD and
    # requires the exact requested checkout; it includes both original drivers.
    sources = gate.source_inputs(ROOT, expected_sha)
    require(set(sources) == set(historical) and len(sources) == 13,
            "The complete original 13-input closure is mandatory")
    records = {}
    for relative, current in sources.items():
        previous = historical[relative]
        raw = (ROOT / relative).read_bytes()
        blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
        require(current == {key: previous[key] for key in ("bytes", "sha256", "gitBlobExact")},
                "Historical Apple55 input differs: " + relative)
        require(len(raw) == current["bytes"] and sha(raw) == current["sha256"]
                and blob == previous["git_blob_from_exact_bytes"],
                "Actual input bytes or original Git blob differ: " + relative)
        records[relative] = {**current, "git_blob": blob}
    return records


def admit_scaleway_result(output, expected_sha):
    source = "6163c376182172d8308e14a20bab4b9f92514eca"
    archive_path = ROOT / "docs/hq-integration/sefaria-apple55-result-20261126/scaleway-xcode27-apple-foundation55.zip"
    expected_digest = "85c1853d0b46f548d77b092aefc06fc978ac97a12eafab141723f8aa393df902"
    packed = archive_path.read_bytes()
    require(sha(packed) == expected_digest, "Sealed Scaleway Apple55 archive changed")
    subprocess.run(["git", "merge-base", "--is-ancestor", source, expected_sha],
                   cwd=ROOT, check=True, timeout=30)
    snapshot = output / "scaleway-evidence"
    snapshot.mkdir()
    with zipfile.ZipFile(io.BytesIO(packed)) as archive:
        for entry in archive.infolist():
            path = PurePosixPath(entry.filename)
            require(not entry.is_dir() and not path.is_absolute() and ".." not in path.parts
                    and str(path) == entry.filename and entry.file_size < 200000,
                    "Unexpected member in Scaleway Apple55 archive")
            target = snapshot / path
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as out:
                out.write(archive.read(entry))
    result = json.loads((snapshot / "RESULT.json").read_text())
    require(result["expectedSHA"] == source and result["status"] == "APPLE_FOUNDATION_55_PASS"
            and result["host"]["platform"] == "darwin" and result["driverReturncode"] == 0
            and result["inputHashesUnchanged"] is True, "Scaleway Apple55 execution failed admission")
    historical = json.loads((snapshot / "SOURCE_INPUTS.json").read_text())
    wrapper = "Scripts/CI/sefaria-toc-apple55.py"
    require(sha((ROOT / wrapper).read_bytes()) == historical[wrapper]["sha256"],
            "Original gate changed; Scaleway evidence reuse is not permitted")
    gate = runpy.run_path(str(ROOT / wrapper))
    current = gate["source_inputs"](ROOT, expected_sha)
    require(len(current) == 13 and current == historical, "Scaleway Apple55 source closure differs")
    for relative, record in historical.items():
        previous = subprocess.check_output(["git", "show", source + ":" + relative], cwd=ROOT, timeout=30)
        require(len(previous) == record["bytes"] and sha(previous) == record["sha256"],
                "Scaleway Apple55 historical Git bytes differ: " + relative)
    raw = snapshot / "raw"
    index = json.loads((snapshot / "RAW_INDEX.json").read_text())
    require(len(index) == 31 and {row["path"] for row in index}
            == {file.relative_to(raw).as_posix() for file in raw.rglob("*") if file.is_file()},
            "Missing original Scaleway Apple55 evidence")
    for row in index:
        content = (raw / row["path"]).read_bytes()
        require(len(content) == row["bytes"] and sha(content) == row["sha256"],
                "Original Scaleway Apple55 evidence differs: " + row["path"])
    verified = gate["verify_driver_result"](raw, current)
    require(verified == result["driverResult"], "Original Apple55 verifier receipt differs")
    write_json(output / "SOURCE_INPUTS.json", current)
    return {
        "status": "REUSED_VERIFIED_APPLE_FOUNDATION_55_PASS",
        "historical_source": source,
        "historical_run": None,
        "historical_run_url": None,
        "historical_evidence_commit": None,
        "historical_manifest_sha256": None,
        "historical_artifact_sha256": expected_digest,
        "execution_authority": "Scaleway Xcode 27 Apple Foundation run",
        "verified_historical_cases": verified["passed"],
        "exact_source_inputs": len(current),
        "inputHashesUnchanged": True,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected-sha", default=os.environ.get("EXPECTED_CHECKOUT_SHA", ""))
    parser.add_argument("--artifacts-dir", type=Path, default=ROOT / "build/artifacts/sefaria-toc-apple55")
    args = parser.parse_args(argv)
    output = args.artifacts_dir.resolve()
    require(not output.exists(), "Use a fresh Apple55 reuse evidence directory")
    output.mkdir(parents=True)
    report = {
        "schemaVersion": 1, "status": "ERROR", "checkout_sha": args.expected_sha,
        "startedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "scope": "Reused original Apple Foundation55; exact 13-input closure only",
        "historical_source": SOURCE, "historical_run": RUN,
        "historical_run_url": f"https://github.com/davidpovarsky/Maktabah/actions/runs/{RUN}",
        "historical_evidence_commit": EVIDENCE_COMMIT,
        "historical_manifest_sha256": MANIFEST_SHA256,
        "historical_artifact_sha256": ARTIFACT_SHA256,
        "executed": 0, "passed": 0, "new_swift_compiles": 0, "new_test_executions": 0,
        "native": "NOT_RUN", "iPadSDK": "NOT_RUN", "realNetwork": "NOT_RUN",
        "embeddedHermes": "NOT_RUN", "physicalOffline": "NOT_RUN",
    }
    try:
        library_models = ROOT / "Source/LibraryBackend/LibraryBackendModels.swift"
        if sha(library_models.read_bytes()) == "b05a2e40eca5577441992d6fa1648ec7ae9ef617a23d52ef8a7f1e46e2c9d14d":
            report.update(admit_scaleway_result(output, args.expected_sha))
            return 0
        evidence = ROOT / EVIDENCE
        manifest_raw = (evidence / "MANIFEST.json").read_bytes()
        require(sha(manifest_raw) == MANIFEST_SHA256, "Historical evidence manifest changed")
        manifest = json.loads(manifest_raw)
        require(manifest["source"] == SOURCE and manifest["run"] == RUN,
                "Historical evidence provenance differs")
        # Preserve the small sealed bundle in this run's artifacts. The original
        # verifier then runs against these exact bytes, including both archives.
        snapshot = output / "historical-evidence"
        snapshot.mkdir()
        (snapshot / "MANIFEST.json").write_bytes(manifest_raw)
        for entry in manifest["files"]:
            raw = (evidence / entry["path"]).read_bytes()
            require(len(raw) == entry["bytes"] and sha(raw) == entry["sha256"],
                    "Historical evidence changed: " + entry["path"])
            (snapshot / entry["path"]).write_bytes(raw)
        historical_result = json.loads((snapshot / "RESULT.json").read_text())
        require(historical_result["status"] == "VERIFIED_APPLE_FOUNDATION_55_PASS"
                and historical_result["source"] == SOURCE and historical_result["run"] == RUN
                and historical_result["artifact_sha256"] == ARTIFACT_SHA256,
                "Historical review is not the sealed original passing result")
        historical = historical_result["source_inputs"]
        wrapper = ROOT / "Scripts/CI/sefaria-toc-apple55.py"
        require(sha(wrapper.read_bytes()) == historical["Scripts/CI/sefaria-toc-apple55.py"]["sha256"],
                "Original gate changed; evidence reuse is not permitted")
        spec = importlib.util.spec_from_file_location("original_apple55_gate", wrapper)
        gate = importlib.util.module_from_spec(spec)
        sys.dont_write_bytecode = True
        spec.loader.exec_module(gate)
        sources = checked_sources(gate, args.expected_sha, historical)
        write_json(output / "SOURCE_INPUTS.json", sources)
        command = [sys.executable, "-I", str(snapshot / "verify-evidence.py")]
        report["verification_command"] = command
        # -I ignores PYTHONOPTIMIZE, so the unchanged verifier's assertions run.
        with (output / "verifier.stdout.log").open("wb") as stdout, (output / "verifier.stderr.log").open("wb") as stderr:
            result = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr, timeout=30)
        report["verification_returncode"] = result.returncode
        require(result.returncode == 0, "The original archived evidence verifier failed")
        verified = json.loads((output / "verifier.stdout.log").read_text())
        require(verified == {"status": "VERIFIED_APPLE_FOUNDATION_55_PASS", "source": SOURCE,
                             "cases": 55, "source_inputs": 13, "new_test_executions": 0,
                             "Native_UI": "NOT_RUN"}, "Unexpected original verifier receipt")
        require(checked_sources(gate, args.expected_sha, historical) == sources,
                "Inputs changed while verifying reuse")
        report.update(status="REUSED_VERIFIED_APPLE_FOUNDATION_55_PASS",
                      verified_historical_cases=55, exact_source_inputs=13,
                      inputHashesUnchanged=True, original_verifier=verified)
    except Exception as error:
        report["error"] = {"type": type(error).__name__, "message": str(error)}
    finally:
        report["finishedAt"] = dt.datetime.now(dt.timezone.utc).isoformat()
        write_json(output / "RESULT.json", report)
        print(json.dumps(report, indent=2))
    return 0 if report["status"] == "REUSED_VERIFIED_APPLE_FOUNDATION_55_PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
