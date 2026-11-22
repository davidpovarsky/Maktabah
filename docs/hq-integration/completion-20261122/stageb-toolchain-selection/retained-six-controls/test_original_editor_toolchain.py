"""New selector controls only; no Apple toolchain, SDK or native acceptance."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

PATH = Path(__file__).parent / "candidate/Scripts/CI/select-runtime27-toolchain.py"
spec = importlib.util.spec_from_file_location("owned_selector", PATH)
selector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selector)

PRODUCER = {"xcode": "Xcode 27.0\nBuild version 27A266a",
            "swift": "Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)\nTarget: arm64-apple-macosx27.0.0",
            "sdk_version": "27.0"}

def candidate(version, *, swift=None, build=None, status="MATCHED_MATRIX_PAIR"):
    return {"status": status, "developer_dir": "/Applications/Xcode_" + version + ".app/Contents/Developer",
            "xcode_version": version, "sdk_version": version,
            "xcode": "Xcode " + version + "\nBuild version " + (build or "27A266a"),
            "swift": swift or PRODUCER["swift"]}

def fixture_config():
    # Synthetic source-bound input. No artifact is downloaded or admitted.
    return {"schema": 1, "repository": "davidpovarsky/anytype-swift", "source_sha": "a" * 40,
            "run_id": 1, "run_attempt": 1, "artifact_id": 1, "qualification_sha256": "b" * 64,
            "toolchain": dict(PRODUCER)}

class OriginalEditorToolchainControls(unittest.TestCase):
    def source_fixture(self, config):
        temporary = tempfile.TemporaryDirectory(prefix="otzaria-toolchain-source-control-")
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        path = root / "Scripts/CI/fixture.json"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps(config), encoding="utf-8")
        def git(*args):
            subprocess.run(["git", "-c", "user.name=Otzaria isolated control",
                            "-c", "user.email=isolated-control@example.invalid", *args],
                           cwd=root, check=True, capture_output=True, timeout=20)
        git("init", "--quiet")
        git("add", "Scripts/CI/fixture.json")
        git("commit", "--quiet", "-m", "Synthetic isolated selector input")
        return root, path

    def test_default_selection_preserves_newest_matching_pair(self):
        values = [candidate("27.0"), candidate("27.2"), candidate("27.3", status="NO_MATCHED_MATRIX_PAIR")]
        before = copy.deepcopy(values)
        selected = selector.eligible_candidates(values)
        self.assertEqual([row["sdk_version"] for row in selected], ["27.2", "27.0"])
        self.assertEqual(values, before)

    def test_exact_producer_selects_matching_older_installed_pair(self):
        exact = candidate("27.0")
        values = [candidate("27.2"), candidate("27.0", swift=PRODUCER["swift"].replace("34.1", "34.2")), exact]
        self.assertEqual(selector.eligible_candidates(values, PRODUCER), [exact])

    def test_no_matching_producer_never_falls_back(self):
        self.assertEqual(selector.eligible_candidates([candidate("27.2")], PRODUCER), [])
        unavailable = candidate("27.0", status="NO_MATCHED_MATRIX_PAIR")
        self.assertEqual(selector.eligible_candidates([unavailable], PRODUCER), [])

    def test_same_major_version_does_not_hide_build_compiler_or_sdk_drift(self):
        for field in PRODUCER:
            with self.subTest(field=field):
                changed = candidate("27.0")
                changed[field] = PRODUCER[field] + "-changed"
                self.assertEqual(selector.eligible_candidates([changed], PRODUCER), [])

    def test_committed_admission_binds_tuple_and_rejects_dirty_working_file(self):
        root, path = self.source_fixture(fixture_config())
        bound = selector.original_editor_toolchain(Path("Scripts/CI/fixture.json"), root)
        self.assertEqual(bound["toolchain"], PRODUCER)
        self.assertEqual(bound["source_sha"], "a" * 40)
        changed = fixture_config()
        changed["toolchain"]["sdk_version"] = "27.2"
        path.write_text(json.dumps(changed), encoding="utf-8")
        with self.assertRaisesRegex(RuntimeError, "differs from the reviewed checkout"):
            selector.original_editor_toolchain(Path("Scripts/CI/fixture.json"), root)

    def test_unfinalized_admission_cannot_supply_a_toolchain(self):
        value = fixture_config()
        value["run_id"] = 0
        root, _ = self.source_fixture(value)
        with self.assertRaisesRegex(RuntimeError, "not finalized"):
            selector.original_editor_toolchain(Path("Scripts/CI/fixture.json"), root)

if __name__ == "__main__":
    unittest.main(verbosity=2)
