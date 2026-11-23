#!/usr/bin/env python3
"""Inspect the selected actual Apple SDK and compile declarations only.
No Simulator, application, native notification or test case is executed.
"""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/darwin-notify-sdk-probe"
CACHE = ROOT / "build/darwin-notify-sdk-probe-cache"
SELECTOR_SHA256 = "3e6ed97188d50f4f344dbd7f77f142a05f0a0bde1b720a0745df098f49bfcf2f"
EXPECTED_XCODE = "Xcode 27.2\nBuild version 27B52"
EXPECTED_SWIFT = "Apple Swift version 6.4.2 (swiftlang-6.4.2.1.9 clang-2100.4.1.1)\nTarget: arm64-apple-macosx27.0.0"
COMMANDS = []
PROBE_DEADLINE = time.monotonic() + 600
REPORT = {"schema": 1, "status": "STARTED", "native_notifications_executed": 0,
          "native_ui_cases_executed": 0, "product_files_modified": False,
          "commands": COMMANDS}

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def write(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")

def group_alive(pid):
    try:
        os.killpg(pid, 0)
        return True
    except ProcessLookupError:
        return False

def run(label, argv, timeout=90):
    remaining = PROBE_DEADLINE - time.monotonic()
    if remaining <= 25:
        raise RuntimeError("Aggregate diagnostic deadline reached before " + label)
    timeout = min(timeout, remaining - 25)
    stdout_path, stderr_path = OUT / (label + ".stdout"), OUT / (label + ".stderr")
    started = time.monotonic()
    with stdout_path.open("xb") as stdout, stderr_path.open("xb") as stderr:
        process = subprocess.Popen(argv, cwd=ROOT, stdout=stdout, stderr=stderr,
                                   start_new_session=True)
        timed_out = False
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=10)
        for _ in range(20):
            if not group_alive(process.pid):
                break
            time.sleep(0.1)
        drained = not group_alive(process.pid)
        if not drained:
            os.killpg(process.pid, signal.SIGTERM)
            for _ in range(50):
                if not group_alive(process.pid):
                    break
                time.sleep(0.1)
            drained = not group_alive(process.pid)
            if not drained:
                os.killpg(process.pid, signal.SIGKILL)
                for _ in range(50):
                    if not group_alive(process.pid):
                        break
                    time.sleep(0.1)
                drained = not group_alive(process.pid)
    row = {"label": label, "command": argv, "pid": process.pid,
           "returncode": process.returncode, "timed_out": timed_out,
           "child_reaped": process.poll() is not None,
           "owned_group_drained": drained, "elapsed_seconds": time.monotonic() - started,
           "stdout_sha256": sha(stdout_path.read_bytes()),
           "stderr_sha256": sha(stderr_path.read_bytes())}
    COMMANDS.append(row)
    write("commands.json", COMMANDS)
    return row, stdout_path.read_text(errors="replace").strip()

def require_command(label, argv, timeout=90):
    row, output = run(label, argv, timeout)
    if row["returncode"] != 0 or row["timed_out"] or not row["owned_group_drained"]:
        raise RuntimeError("Command did not finish successfully: " + label)
    return output

def source_admission():
    head = require_command("checkout", ["git", "rev-parse", "HEAD"])
    if head != os.environ.get("EXPECTED_CHECKOUT_SHA"):
        raise RuntimeError("Checkout differs from the triggered source")
    paths = ["Scripts/CI/select-runtime27-toolchain.py",
             "Scripts/CI/darwin-notify-sdk-probe.py",
             ".github/workflows/otzaria-darwin-notify-sdk-probe.yml"]
    rows = []
    for index, path in enumerate(paths):
        raw = (ROOT / path).read_bytes()
        original = subprocess.check_output(["git", "show", "HEAD:" + path],
                                           cwd=ROOT, timeout=30)
        if raw != original:
            raise RuntimeError("Changed source input: " + path)
        rows.append({"path": path, "bytes": len(raw), "sha256": sha(raw)})
    if rows[0]["sha256"] != SELECTOR_SHA256:
        raise RuntimeError("Original selector changed")
    REPORT.update(checkout_sha=head, source_inputs=rows,
                  observed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    write("source-admission.json", {"checkout_sha": head, "inputs": rows})

def declared_modules(text):
    # Retain the full original map as evidence; these candidates are derived
    # solely from enclosing explicit module declarations of notify.h.
    clean = re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S)
    tokens = re.findall(r'"(?:\\.|[^"\\])*"|[A-Za-z_][A-Za-z0-9_.]*|[{}*]', clean)
    stack, result, pending = [], [], None
    for index, token in enumerate(tokens):
        if token == "module" and index + 1 < len(tokens):
            name = tokens[index + 1]
            pending = name if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.]*", name) else None
        elif token == "{":
            stack.append(pending)
            pending = None
        elif token == "}":
            if stack:
                stack.pop()
        elif token == "header" and index + 1 < len(tokens):
            name = tokens[index + 1]
            if name.startswith('"') and Path(json.loads(name)).name == "notify.h":
                excluded = index > 0 and tokens[index - 1] == "exclude"
                components = [part for part in stack if part]
                module = ".".join(components)
                result.append({"module": module, "excluded_header": excluded})
    return result

def sdk_evidence(sdk):
    headers = sorted({path.resolve() for path in sdk.rglob("notify.h") if path.is_file()})
    maps = sorted({path.resolve() for path in sdk.rglob("*.modulemap") if path.is_file()})
    maps += sorted({path.resolve() for path in sdk.rglob("module.map") if path.is_file()} - set(maps))
    if len(headers) > 32 or len(maps) > 2000:
        raise RuntimeError("Unexpected SDK header/module inventory")
    rows, candidates = [], set()
    retained = OUT / "sdk"
    retained.mkdir()
    for index, path in enumerate(headers):
        raw = path.read_bytes()
        if len(raw) > 2 * 1024 * 1024:
            raise RuntimeError("Oversized notify header")
        dest = retained / ("notify-%02d.h" % index)
        dest.write_bytes(raw)
        rows.append({"kind": "header", "path": str(path), "retained": str(dest.relative_to(OUT)),
                     "bytes": len(raw), "sha256": sha(raw)})
    map_inventory = []
    scanned_bytes = 0
    for index, path in enumerate(maps):
        size = path.stat().st_size
        if size > 2 * 1024 * 1024:
            raise RuntimeError("Oversized SDK module map")
        raw = path.read_bytes()
        scanned_bytes += len(raw)
        if scanned_bytes > 64 * 1024 * 1024:
            raise RuntimeError("SDK module map byte budget exceeded")
        map_inventory.append({"path": str(path), "bytes": len(raw), "sha256": sha(raw)})
        if b"notify.h" not in raw and b"DarwinNotify" not in raw:
            continue
        declarations = declared_modules(raw.decode())
        dest = retained / ("module-%04d.modulemap" % index)
        dest.write_bytes(raw)
        rows.append({"kind": "modulemap", "path": str(path), "retained": str(dest.relative_to(OUT)),
                     "bytes": len(raw), "sha256": sha(raw), "notify_declarations": declarations})
        for row in declarations:
            name = row["module"]
            if not row["excluded_header"] and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.]*", name):
                parts = name.split(".")
                for length in range(1, len(parts) + 1):
                    candidates.add(".".join(parts[:length]))
    if len(candidates) > 8:
        raise RuntimeError("Unexpected declared module candidate count")
    write("sdk-map-inventory.json", map_inventory)
    write("sdk-evidence.json", rows)
    REPORT.update(sdk_evidence=rows, examined_module_maps=len(maps),
                  module_candidates=sorted(candidates))
    return headers, sorted(candidates)

def compile_declarations(sdk, headers, candidates):
    common = ["xcrun", "swiftc", "-c", "-whole-module-optimization",
              "-module-name", "OtzariaDarwinSDKProbe", "-swift-version", "6",
              "-enable-testing", "-D", "DEBUG", "-target", "arm64-apple-ios27.0-simulator",
              "-sdk", str(sdk), "-module-cache-path", str(CACHE / "swift"),
              "-enable-upcoming-feature", "MemberImportVisibility",
              "-enable-upcoming-feature", "InferIsolatedConformances",
              "-enable-upcoming-feature", "NonisolatedNonsendingByDefault"]
    body = """public func probeOriginalNotifyDeclarations(_ name: String) {
    var token: Int32 = 0
    let posted = name.withCString { notify_post($0) }
    let matched = posted == NOTIFY_STATUS_OK
    let registered = name.withCString {
        notify_register_dispatch($0, &token, DispatchQueue.main) { _ in }
    }
    let cancelled = notify_cancel(token)
    _ = (matched, registered, cancelled)
}
"""
    probes = [("darwin-original", "Darwin", None)]
    probes.extend(("declared-%02d" % n, name, None)
                  for n, name in enumerate(candidates) if name != "Darwin")
    if len(headers) == 1:
        probes.append(("actual-header-bridge", "Darwin", headers[0]))
    compiled = []
    REPORT["swift_declaration_compiles"] = compiled
    for label, module, header in probes:
        source = OUT / (label + ".swift")
        source.write_text("import Foundation\nimport Dispatch\nimport " + module + "\n" + body)
        argv = common + ["-o", str(OUT / (label + ".o"))]
        if header:
            argv += ["-import-objc-header", str(header)]
        row, _ = run(label, argv + [str(source)], timeout=120)
        compiled.append({"label": label, "import": module,
                         "header": str(header) if header else None,
                         "source_sha256": sha(source.read_bytes()),
                         "returncode": row["returncode"],
                         "completed": not row["timed_out"] and row["owned_group_drained"]})
    if len(headers) == 1:
        source = OUT / "actual-notify-header.c"
        source.write_text('#include <notify.h>\nvoid declarations(void) {\n'
                          '  int token = 0;\n'
                          '  unsigned posted = notify_post("org.otzaria.probe.not.executed");\n'
                          '  unsigned registered = notify_register_dispatch("org.otzaria.probe.not.executed", &token, dispatch_get_main_queue(), ^(int t) {});\n'
                          '  unsigned cancelled = notify_cancel(token);\n'
                          '  (void)posted; (void)registered; (void)cancelled; (void)NOTIFY_STATUS_OK;\n}\n')
        row, _ = run("actual-clang-header",
                     ["xcrun", "clang", "-fsyntax-only", "-fblocks", "-fmodules",
                      "-Rmodule-import", "-fmodules-cache-path=" + str(CACHE / "clang"),
                      "-target", "arm64-apple-ios27.0-simulator", "-isysroot", str(sdk),
                      str(source)], timeout=120)
        REPORT["clang_header"] = {"returncode": row["returncode"], "completed": not row["timed_out"] and row["owned_group_drained"]}
    REPORT["swift_declaration_compiles"] = compiled

def main():
    if sys.platform != "darwin":
        raise RuntimeError("Actual Apple SDK required")
    OUT.mkdir(parents=True, exist_ok=True)
    if set(p.name for p in OUT.iterdir()) != {"toolchain-selection.json"}:
        raise RuntimeError("Probe output is not the fresh selected-toolchain folder")
    CACHE.mkdir(parents=True, exist_ok=False)
    source_admission()
    selected = json.loads((OUT / "toolchain-selection.json").read_text())["selected"]
    if selected["developer_dir"] != os.environ.get("DEVELOPER_DIR"):
        raise RuntimeError("Selected developer directory was not applied")
    xcode = require_command("xcode-version", ["xcodebuild", "-version"])
    swift = require_command("swift-version", ["xcrun", "swiftc", "--version"])
    sdk_version = require_command("sdk-version", ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"])
    sdk = Path(require_command("sdk-path", ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"])).resolve()
    REPORT.update(xcode=xcode, swift=swift, sdk=str(sdk), sdk_version=sdk_version,
                  target="arm64-apple-ios27.0-simulator", developer_dir=os.environ["DEVELOPER_DIR"])
    if xcode != EXPECTED_XCODE or swift != EXPECTED_SWIFT or sdk_version != "27.2":
        raise RuntimeError("Actual toolchain differs from the observed failed run")
    headers, candidates = sdk_evidence(sdk)
    compile_declarations(sdk, headers, candidates)
    REPORT["status"] = "ACTUAL_SDK_EVIDENCE_CAPTURED_NOT_APP_OR_RUNTIME_ACCEPTANCE"
    if any(row["timed_out"] or not row["owned_group_drained"] for row in COMMANDS):
        raise RuntimeError("A diagnostic command did not drain")
    return 0

if __name__ == "__main__":
    result = 1
    try:
        result = main()
    except Exception as error:
        REPORT["status"] = "DIAGNOSTIC_FAILED"
        REPORT["error"] = type(error).__name__ + ": " + str(error)
    finally:
        OUT.mkdir(parents=True, exist_ok=True)
        write("result.json", REPORT)
        rows = []
        for path in sorted(OUT.rglob("*")):
            if path.is_file() and path.name != "INDEX.json":
                raw = path.read_bytes()
                rows.append({"path": str(path.relative_to(OUT)), "bytes": len(raw), "sha256": sha(raw)})
        write("INDEX.json", {"schema": 1, "files": rows})
        print(json.dumps({"status": REPORT["status"], "source": REPORT.get("checkout_sha"),
                          "native_notifications_executed": 0, "native_ui_cases_executed": 0}))
    raise SystemExit(result)
