#!/usr/bin/env python3
"""Windows external-C ABI smoke; owns its only index in TemporaryDirectory.

Build the staticlib with cargo rustc --locked --no-default-features --lib --
--print native-static-libs first. The build record must contain the actual
artifact path/hash and the exact native-static-libs line emitted by rustc.
This driver changes neither app/index policy nor any existing engine index.
"""
from __future__ import annotations
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent
ENGINE = HERE.parents[1]
ROOT = ENGINE.parents[1]
OWNER = "otzaria-occurrence-c-smoke-disposable-v1\n"


def sha256(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def run(command: list[str], timeout: int) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command, cwd=ROOT, capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=timeout,
    )


def git(*arguments: str) -> str:
    result = run(["git", "-C", str(ENGINE / "Checkout/otzaria_search_engine"), *arguments], 20)
    if result.returncode:
        raise RuntimeError(result.stderr)
    return result.stdout.strip()


def validate(records: list[dict], manifest: dict) -> list[str]:
    stages = {entry["stage"]: entry["result"] for entry in records}
    expected = {
        "buildInfo", "add", "commit", "legacySearch", "requestToken",
        "exactCount", "duplicateExecution", "releaseCompleted", "cancel",
        "cancelledCount", "releaseCancelled", "releaseTwice", "expiredCount",
        "releaseExpired", "malformedRequest",
    }
    assert len(stages) == len(records) and set(stages) == expected, stages
    for stage in ("buildInfo", "add", "commit", "legacySearch", "exactCount"):
        assert stages[stage]["ok"] is True, (stage, stages[stage])
    build = stages["buildInfo"]["value"]
    count = stages["exactCount"]["value"]
    proof = count["proof"]
    assert count["occurrences"] == 2, count
    assert count["matchingLiveDocuments"] == 1, count
    assert stages["legacySearch"]["value"]["totalCount"] == 1, stages["legacySearch"]
    assert proof["countKind"] == "distinctTokenPositions" and proof["exact"] is True, proof
    assert proof["analyzedToken"] == "\u05de\u05e9\u05d4", proof
    assert proof["requestToken"] == stages["requestToken"] > 0, proof
    assert "/book/1" in proof["requestedFacets"], proof
    assert proof["liveIndexDocuments"] == 1 and proof["indexSchemaVersion"] == 4, proof
    assert isinstance(proof["searcherGeneration"]["generationId"], int), proof
    assert len(proof["searcherGeneration"]["segments"]) > 0, proof
    assert proof["engineCommit"] == build["upstreamCommit"] == manifest["commit"], proof
    assert proof["engineRepository"] == build["upstreamRepository"] == manifest["repository"], proof
    assert proof["engineBranch"] == build["upstreamBranch"] == manifest["branch"], proof
    assert proof["originalUpstreamBase"] == manifest["original_upstream_base"], proof
    for stage in ("releaseCompleted", "cancel", "releaseCancelled", "releaseExpired"):
        assert stages[stage] is True, (stage, stages[stage])
    assert stages["releaseTwice"] is False, stages
    for stage, code in (
        ("duplicateExecution", "request_already_executed"),
        ("cancelledCount", "cancelled"),
        ("expiredCount", "deadline_exceeded"),
        ("malformedRequest", "invalid_request"),
    ):
        value = stages[stage]
        assert value["ok"] is False and value["value"] is None, (stage, value)
        assert value["error"]["code"] == code, (stage, value)
        assert "occurrences" not in value, (stage, value)
    return [
        "actual external C header, link and runtime",
        "two original token positions differ from one matching document",
        "genuine snapshot, scope, request and source identity",
        "one-use execution and released token lifetime",
        "typed cancellation and zero-deadline without numeric result",
        "malformed input and duplicate release",
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-record", type=Path, required=True)
    parser.add_argument("--native-library-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("this recorded consumer is Windows/MSVC; Apple validation is separate")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    result: dict = {
        "startedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "status": "FAILED", "AppleSDK": "NOT_RUN", "Native": "NOT_RUN",
        "appIntegration": "NOT_CONNECTED", "unsafeOriginalDiagnostics": "NOT_RUN",
    }
    started = time.monotonic()
    try:
        manifest = json.loads((ENGINE / "Upstream/UPSTREAM_MANIFEST.json").read_text(encoding="utf-8"))
        assert git("rev-parse", "HEAD") == manifest["commit"]
        assert git("status", "--porcelain") == ""
        record = json.loads(args.build_record.read_text(encoding="utf-8"))
        library = Path(record["artifact"]).resolve()
        assert record["exit"] == 0 and record["engineSource"] == manifest["commit"]
        assert sha256(library) == record["artifactSHA256"]
        assert record["engineCheckoutPristineAfter"] is True
        assert len(record["nativeLibraries"]) == 1
        native = record["nativeLibraries"][0].split("native-static-libs:", 1)[1].strip().split()
        clang = shutil.which("clang")
        assert clang, "clang not available"
        source = HERE / "occurrence_ffi_smoke.c"
        executable = output / "occurrence_ffi_smoke.exe"
        command = [
            # Match rustc/MSVC's emitted dynamic CRT; do not mix libucrt with msvcrt.
            clang, "-std=c11", "-Wall", "-Wextra", "-Werror", "-fms-runtime-lib=dll",
            "-Wno-deprecated-declarations", "-I", str(ENGINE / "include"),
            str(source), str(library), "-o", str(executable),
            "-Xlinker", "/LIBPATH:" + str(args.native_library_dir.resolve()),
            # This Clang driver still adds libcmt even with -fms-runtime-lib=dll.
            # Its inspected object directives and rustc both require MSVCRT.
            "-Xlinker", "/NODEFAULTLIB:libcmt",
        ]
        for value in native:
            command.extend(["-Xlinker", value])
        compiled = run(command, 120)
        (output / "c-compile.log").write_text(compiled.stdout + compiled.stderr, encoding="utf-8")
        result.update({
            "compileCommand": command, "compileExit": compiled.returncode,
            "engineCommit": manifest["commit"], "engineRepository": manifest["repository"],
            "originalUpstreamBase": manifest["original_upstream_base"],
            "staticLibrary": str(library), "staticLibrarySHA256": record["artifactSHA256"],
            "sourceSHA256": sha256(source),
            "headerSHA256": sha256(ENGINE / "include/otzaria_search_engine.h"),
            "driverSHA256": sha256(Path(__file__)),
        })
        assert compiled.returncode == 0, compiled.stderr[-6000:]
        # Only this driver creates the disposable root; there is no user index argument.
        with tempfile.TemporaryDirectory(prefix="otzaria-occurrence-c-smoke-") as owned:
            directory = Path(owned)
            (directory / "OWNER").write_text(OWNER, encoding="ascii", newline="")
            (directory / "index").mkdir()
            assert list((directory / "index").iterdir()) == []
            executed = run([str(executable), str(directory)], 30)
            (output / "c-runtime.stdout.log").write_text(executed.stdout, encoding="utf-8")
            (output / "c-runtime.stderr.log").write_text(executed.stderr, encoding="utf-8")
            result.update({"runtimeExit": executed.returncode, "fixture": str(directory)})
            assert executed.returncode == 0, executed.stderr[-4000:]
            records = [json.loads(line) for line in executed.stdout.splitlines() if line.strip()]
            result["checks"] = validate(records, manifest)
            assert (directory / "index/meta.json").is_file()
        result["fixtureRemovedAfterRun"] = not Path(owned).exists()
        assert result["fixtureRemovedAfterRun"]
        assert git("status", "--porcelain") == ""
        result["engineCheckoutPristineAfter"] = True
        result["status"] = "PASS"
    except Exception as error:
        result["error"] = repr(error)
    finally:
        result["seconds"] = round(time.monotonic() - started, 3)
        (output / "c-smoke-result.json").write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
        )
        print(json.dumps(result, ensure_ascii=False))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
