#!/usr/bin/env python3
"""Exercise the original shell seed against compiled production profile storage.

Uses controlled bytes and the actual Swift path resolver, without a simulator,
network download, or claim that native resume acceptance has run.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SEED_BYTES = 1_048_576


class SeedWorkspaceParity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="v32-seed-parity-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.directory = Path(cls.temporary.name)
        cls.swiftc = os.environ.get("OTZARIA_TEST_SWIFTC") or shutil.which("swiftc")
        cls.bash = os.environ.get("OTZARIA_TEST_BASH") or shutil.which("bash")
        if not cls.swiftc or not cls.bash:
            raise RuntimeError("Swift compiler and bash are required; source parity was NOT_RUN")
        cls.sources = [
            ROOT / "Source/Otzaria/DataProfiles/OtzariaArtifactStorage.swift",
            ROOT / "Source/Otzaria/DataProfiles/OtzariaDataProfile.swift",
            ROOT / "Source/Otzaria/DataProfiles/OtzariaDataProfileRegistry.swift",
        ]
        # The real resolver always receives an explicit base, as the actual
        # OtzariaSearchArtifactStorage initializer does. Its unused default
        # container dependency must never be evaluated by this portable probe.
        shim = cls.directory / "UnusedContainerDefaults.swift"
        shim.write_text('''import Foundation
enum ITorahSharedContainer {
    static var sharedRootURL: URL { preconditionFailure("explicit base required") }
    static var downloadsRootURL: URL { preconditionFailure("explicit base required") }
}
''', encoding="utf-8")
        main = cls.directory / "main.swift"
        main.write_text('''import Foundation
let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let identity = CommandLine.arguments[2], digest = CommandLine.arguments[3]
func workspace(_ profile: String) -> URL {
    OtzariaProfileStorage.downloadsRoot(base: base, component: .otzariaSearch, profileID: profile)
        .appendingPathComponent(identity, isDirectory: true)
}
func bytes(_ folder: URL) -> Int64 {
    let file = folder.appendingPathComponent(digest + ".part")
    let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
    return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
}
let production = workspace(OtzariaDataProfileRegistry.productionID)
let mini = workspace(OtzariaDataProfileRegistry.miniTest10ID)
let output: [String: Any] = ["productionWorkspace": production.path,
    "productionSeedBytes": bytes(production), "miniWorkspace": mini.path,
    "miniSeedBytes": bytes(mini)]
print(String(decoding: try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys]), as: UTF8.self))
''', encoding="utf-8")
        cls.executable = cls.directory / ("profile-path.exe" if os.name == "nt" else "profile-path")
        compiled = subprocess.run([cls.swiftc, *map(str, cls.sources), str(shim), str(main),
                                   "-o", str(cls.executable)], text=True, encoding="utf-8",
                                  capture_output=True, timeout=120)
        if compiled.returncode:
            raise RuntimeError("Actual profile source compilation failed:\n" + compiled.stdout + compiled.stderr)
        launcher = (ROOT / "Scripts/run-otzaria-prebuilt-acceptance.sh").read_text(encoding="utf-8")
        match = re.search(r'(?m)^  WORKSPACE=.*\n  mkdir .*\n  dd .*\n', launcher)
        if not match:
            raise RuntimeError("Original launcher seed block could not be identified")
        cls.seed_block = match.group(0)
        print(json.dumps({"actual_swift_sources_sha256": {
            str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in cls.sources
        }, "scope": "portable original-path parity only; native HTTP resume NOT_RUN"}))

    def seed_and_observe(self, block=None):
        folder = self.directory / self._testMethodName
        container = folder / "app container"
        package = folder / "package"
        package.mkdir(parents=True)
        payload = bytes(range(256)) * (2 * SEED_BYTES // 256)
        asset = package / "controlled-part.zst"
        asset.write_bytes(payload)
        digest = hashlib.sha256(payload).hexdigest()
        identity = "1" * 64
        environment = dict(os.environ, CONTAINER=container.as_posix(), PACKAGE=package.as_posix(),
                           SEED_SHA=digest, SEED_ASSET=asset.name, SEED_IDENTITY=identity)
        script = "set -euo pipefail\n" + (block or self.seed_block) + 'printf "%s\\n" "$WORKSPACE"\n'
        seeded = subprocess.run([self.bash, "-c", script], env=environment, capture_output=True,
                                text=True, encoding="utf-8", timeout=30)
        self.assertEqual(seeded.returncode, 0, seeded.stderr)
        seeded_path = Path(seeded.stdout.strip())
        self.assertEqual((seeded_path / (digest + ".part")).stat().st_size, SEED_BYTES)
        probe = subprocess.run([str(self.executable), str(container / "Library/Caches"), identity, digest],
                               capture_output=True, text=True, encoding="utf-8", timeout=30)
        self.assertEqual(probe.returncode, 0, probe.stderr)
        return seeded_path, json.loads(probe.stdout)

    def test_original_launcher_seed_is_visible_to_production_storage(self):
        seeded, actual = self.seed_and_observe()
        self.assertEqual(seeded.resolve(), Path(actual["productionWorkspace"]).resolve())
        self.assertEqual(actual["productionSeedBytes"], SEED_BYTES)

    def test_legacy_searchdownloads_path_reproduces_zero_resumable_bytes(self):
        legacy = self.seed_block.replace("/Otzaria/Downloads/", "/Otzaria/SearchDownloads/")
        seeded, actual = self.seed_and_observe(legacy)
        self.assertNotEqual(seeded.resolve(), Path(actual["productionWorkspace"]).resolve())
        self.assertEqual(actual["productionSeedBytes"], 0)

    def test_production_seed_does_not_enter_mini_profile(self):
        seeded, actual = self.seed_and_observe()
        self.assertNotEqual(seeded.resolve(), Path(actual["miniWorkspace"]).resolve())
        self.assertEqual(actual["miniSeedBytes"], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
