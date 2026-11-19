"""Compile the real frozen Hanlin contracts, current ActionCore and thin host adapter.
Includes the original HostDispatcher; no AgentSession/model/provider or native UI claim.
All dependencies are immutable original source bytes copied to a disposable build.
"""
from pathlib import Path
import argparse, subprocess, hashlib, json, shutil, sys, re
p = argparse.ArgumentParser()
p.add_argument("--hanlin-repo", type=Path, required=True)
p.add_argument("--hanlin-sha", default="bff3364d64f43b1d5235ead2b6e8f3756e890eed")
p.add_argument("--artifacts-dir", type=Path, required=True)
a = p.parse_args()
repo = Path(__file__).resolve().parents[1]
out = a.artifacts_dir.resolve(); out.mkdir(parents=True, exist_ok=True)
build = out / "package"; build.mkdir(exist_ok=True)
inputs = {}
def put(relative, raw, provenance):
    path = build / relative; path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_bytes() != raw: path.write_bytes(raw)
    inputs[relative] = dict(sha256=hashlib.sha256(raw).hexdigest(), bytes=len(raw), source=provenance)
for module, source in [
    ("HanlinPlatformContracts", "Packages/HanlinPlatform/Sources/HanlinPlatformContracts"),
    ("HanlinHostContracts", "Packages/HanlinAgentSDK/Sources/HanlinHostContracts")]:
    names = subprocess.check_output(["git", "-C", str(a.hanlin_repo), "ls-tree", "-r", "--name-only", a.hanlin_sha, "--", source], text=True).splitlines()
    assert names, source
    for name in names:
        raw = subprocess.check_output(["git", "-C", str(a.hanlin_repo), "show", a.hanlin_sha + ":" + name])
        put("Sources/" + module + "/" + name[len(source)+1:], raw, a.hanlin_sha + ":" + name)
dispatcher_source = "Packages/HanlinAgentSDK/Sources/HanlinAgentCore/HanlinHostDispatcher.swift"
put("Sources/HanlinAgentCore/HanlinHostDispatcher.swift",
    subprocess.check_output(["git", "-C", str(a.hanlin_repo), "show", a.hanlin_sha + ":" + dispatcher_source]),
    a.hanlin_sha + ":" + dispatcher_source)
for module, source in [
    ("OtzariaActionCore", repo / "Source/Otzaria/Actions/Sources/OtzariaActionCore"),
    ("OtzariaHanlinHostAdapter", repo / "Source/ChavrusaText/HanlinHostAdapter")]:
    for path in sorted(source.rglob("*")):
        # This component target is the actual thin transport. The sibling
        # original ChatUI/store consumers have their own dependency graph/tests.
        if module == "OtzariaHanlinHostAdapter" and path.name != "OtzariaHanlinHostAdapter.swift":
            continue
        if path.is_file() and (path.suffix in [".swift", ".json"]):
            put("Sources/" + module + "/" + path.relative_to(source).as_posix(), path.read_bytes(), str(path.relative_to(repo)))
test = repo / "Tests/HQ/hanlin-host/OtzariaHanlinHostAdapterTests.swift"
put("Tests/OtzariaHanlinHostAdapterTests/AdapterTests.swift", test.read_bytes(), str(test.relative_to(repo)))
manifest = """// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "HanlinHostCheck", platforms: [.iOS("27.0"), .macOS(.v26)], targets: [
    .target(name: "HanlinPlatformContracts", resources: [.process("Resources")]),
    .target(name: "HanlinHostContracts", dependencies: ["HanlinPlatformContracts"]),
    .target(name: "HanlinAgentCore", dependencies: ["HanlinHostContracts", "HanlinPlatformContracts"]),
    .target(name: "OtzariaActionCore", resources: [.process("Resources")]),
    .target(name: "OtzariaHanlinHostAdapter", dependencies: ["HanlinHostContracts", "HanlinPlatformContracts", "OtzariaActionCore"]),
    .testTarget(name: "OtzariaHanlinHostAdapterTests", dependencies: ["HanlinAgentCore", "OtzariaHanlinHostAdapter", "HanlinHostContracts", "HanlinPlatformContracts", "OtzariaActionCore"])
], swiftLanguageModes: [.v6])
"""
if not (build / "Package.swift").exists() or (build / "Package.swift").read_bytes() != manifest.encode():
    (build / "Package.swift").write_bytes(manifest.encode())
(out / "inputs.json").write_text(json.dumps(inputs, indent=2) + "\n", encoding="utf-8")
command = ["swift", "test", "--scratch-path", str(repo / "build/hh"), "-j", "1", "-Xswiftc", "-strict-concurrency=complete"]
with (out / "swift-test.log").open("w", encoding="utf-8") as log:
    process = subprocess.Popen(command, cwd=build, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT)
    try:
        exit_code = process.wait(timeout=240)
    except subprocess.TimeoutExpired:
        if sys.platform == "win32":
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
        else:
            process.kill()
        process.wait()
        exit_code = 124
r = subprocess.CompletedProcess(command, exit_code)
log_text = (out / "swift-test.log").read_text(encoding="utf-8", errors="replace")
expected_tests = sorted(set(re.findall(r"func (test[A-Za-z0-9_]+)\(", (build / "Tests/OtzariaHanlinHostAdapterTests/AdapterTests.swift").read_text(encoding="utf-8"))))
passed_tests = sorted(set(re.findall(r"Test Case 'OtzariaHanlinHostAdapterTests\.(test[A-Za-z0-9_]+)' passed", log_text)))
if r.returncode == 0 and (not expected_tests or passed_tests != expected_tests):
    r = subprocess.CompletedProcess(command, 1)
report = dict(expected_tests=expected_tests, passed_tests=passed_tests, warnings=log_text.count("warning:"),
status="PASS" if r.returncode == 0 else "FAIL", exit_code=r.returncode,
    hanlin_sha=a.hanlin_sha, adapter_sha256=inputs["Sources/OtzariaHanlinHostAdapter/OtzariaHanlinHostAdapter.swift"]["sha256"],
    inputs=len(inputs), command=command, boundary="Actual frozen SDK Contracts + complete original HostDispatcher + actual ActionCore + actual adapter; explicit backend/authority/native-receipt doubles. No AgentSession, app, provider, native UI or device acceptance.")
(out / "result.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report)); print((out / "swift-test.log").read_text(encoding="utf-8", errors="replace")[-14000:])
raise SystemExit(r.returncode)
