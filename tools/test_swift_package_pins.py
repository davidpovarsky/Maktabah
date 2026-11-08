"""Exercise workspace lock staging and checked, non-overwriting binary cache input."""
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("package_pins", root / "Scripts/CI/prepare-swift-package-pins.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
parent = root / "build/integration-verification"
parent.mkdir(parents=True, exist_ok=True)
fixture = Path(tempfile.mkdtemp(prefix="package-pin-fixture-", dir=parent)).resolve()
assert fixture.is_relative_to(parent.resolve())
source = fixture / module.PIN_FILE
source.parent.mkdir(parents=True)
shutil.copyfile(root / module.PIN_FILE, source)
workspace = Path("Generated.xcworkspace")
target = fixture / workspace / "xcshareddata/swiftpm/Package.resolved"
target.parent.mkdir(parents=True)
target.write_text('{"pins": []}')
module.prepare(fixture, workspace=workspace)
assert module.pins(target) == module.pins(source)
module.prepare(fixture, workspace=workspace, verify=True)
passed = ["generated workspace receives committed pins", "unchanged resolution passes"]
changed = json.loads(target.read_text())
next(pin for pin in changed["pins"] if pin["identity"] == "sparkle")["state"]["version"] = "2.10.1"
target.write_text(json.dumps(changed))
try:
    module.prepare(fixture, workspace=workspace, verify=True)
except RuntimeError:
    passed.append("changed resolved version is rejected")
else:
    raise AssertionError("Changed pin was accepted")
try:
    module.prepare(fixture, workspace=Path("../../Outside.xcworkspace"))
except RuntimeError:
    passed.append("workspace outside checkout is rejected")
else:
    raise AssertionError("Foreign workspace was modified")
archive = Path(sys.argv[1])
cache = fixture / "cache"
installed = module.install_verified_archive(archive, cache)
assert module.digest(installed) == module.SPARKLE_SHA
assert module.install_verified_archive(archive, cache) == installed
passed.append("exact official archive is cached and safely reused")
bad = fixture / "corrupt.zip"
bad.write_bytes(b"not the pinned archive")
try:
    module.install_verified_archive(bad, fixture / "bad-cache")
except RuntimeError:
    passed.append("incorrect archive checksum is rejected")
else:
    raise AssertionError("Wrong archive checksum was accepted")
installed.write_bytes(b"existing unexpected cache file")
try:
    module.install_verified_archive(archive, cache)
except RuntimeError:
    assert installed.read_bytes() == b"existing unexpected cache file"
    passed.append("unexpected existing cache bytes are preserved and rejected")
else:
    raise AssertionError("Existing unexpected cache was silently replaced")
report = {"status": "EXECUTED_PASS", "cases": passed, "fixture": str(fixture)}
(parent / "swift-package-pin-tests.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))
