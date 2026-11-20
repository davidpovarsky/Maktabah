"""Actual DEBUG observer and exact Native evidence-reader controls; never app/UI acceptance."""
from pathlib import Path
import argparse, datetime, hashlib, json, os, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--artifacts-dir", required=True, type=Path)
parser.add_argument("--module-cache", type=Path)
args = parser.parse_args()
OUT = args.artifacts_dir.resolve()
OUT.mkdir(parents=True, exist_ok=True)
sources = [
    "Source/ChavrusaText/StudyWorkspace/StudyGroupSwitchPerformanceObservation.swift",
    "Source/Otzaria/Search/OtzariaIndexFileLogger.swift",
    "Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift",
    "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift",
    "Maktabah.xcodeproj/project.pbxproj",
    "tools/test_groups100_performance.swift",
    "tools/hq-groups100-performance-checks.py",
]
source_bytes = {p: (ROOT / p).read_bytes().replace(b"\r\n", b"\n") for p in sources}
for path, data in source_bytes.items():
    destination = OUT / "source" / path
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
native = source_bytes[sources[2]].decode("utf-8")
start = native.index("// MARK: Actual app process observations")
end = native.index("// END Actual app process observations", start)
exact_reader = native[start:end]
generated = OUT / "MetricReaderAndFixture.swift"
generated.write_text("import Foundation\n" + exact_reader + source_bytes[sources[5]].decode("utf-8"),
                     encoding="utf-8", newline="\n")
exe = OUT / ("groups100-performance.exe" if os.name == "nt" else "groups100-performance")
swift = os.environ.get("SWIFTC", "swiftc")
summary = {
    "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "scope": "Real Foundation probe/evidence-reader controls; explicit registry/writer and metric-record doubles. Not UI/Apple or performance measurements.",
    "source_sha256": {p: hashlib.sha256(b).hexdigest() for p, b in source_bytes.items()},
    "exact_native_reader_sha256": hashlib.sha256(exact_reader.encode()).hexdigest(),
    "source_ref": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
    "swift_version": subprocess.check_output([swift, "--version"], cwd=ROOT, text=True).strip(),
}
command = [swift, "-swift-version", "6", "-strict-concurrency=complete", "-D", "DEBUG",
           "-parse-as-library", str(ROOT / sources[0]), str(ROOT / sources[1]),
           str(generated), "-o", str(exe)]
if args.module_cache:
    command.extend(["-module-cache-path", str(args.module_cache.resolve())])
commands = [("compile", command), ("controls", [str(exe), "-StudyGroupPerformanceEnabled", "YES"])]
(OUT / "COMMANDS.json").write_text(json.dumps(commands, indent=2) + "\n", encoding="utf-8")
status = 1
for name, command in commands:
    environment = dict(os.environ)
    environment["OTZARIA_DATA_PROFILE"] = "miniTest10"
    start = datetime.datetime.now(datetime.timezone.utc).isoformat()
    result = subprocess.run(command, cwd=ROOT, env=environment, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=180 if name == "compile" else 45)
    log = result.stdout + result.stderr
    (OUT / (name + ".log")).write_text(log, encoding="utf-8", newline="\n")
    summary[name] = {"started_at": start, "finished_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                     "returncode": result.returncode, "warnings": log.count("warning:")}
    print(name + ": " + str(result.returncode), flush=True)
    if result.returncode != 0:
        print(log[-12000:], flush=True)
        status = result.returncode
        break
    if name == "controls":
        results = [json.loads(line) for line in result.stdout.splitlines() if line.startswith('{"checks":')]
        assert len(results) == 1, "missing unique actual fixture result"
        summary["results"] = results[0]
        assert results[0]["executed"] == results[0]["passed"] + results[0]["failed"]
        assert results[0]["failed"] == 0
        status = 0
summary["status"] = "PASS_PORTABLE_ONLY" if status == 0 else "FAILED"
summary["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
(OUT / "RESULT.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"status": summary["status"], "results": summary.get("results"),
                  "finished_at": summary["finished_at"]}, ensure_ascii=False), flush=True)
raise SystemExit(status)
