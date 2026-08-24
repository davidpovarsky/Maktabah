import importlib.util
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).parents[1] / "package-otzaria-search-artifact.py"
SPEC = importlib.util.spec_from_file_location("otzaria_packager", SCRIPT)
assert SPEC and SPEC.loader
PACKAGER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PACKAGER)
REPAIR_SCRIPT = Path(__file__).parents[1] / "repair-otzaria-search-artifact-manifest.py"
REPAIR_SPEC = importlib.util.spec_from_file_location("otzaria_manifest_repair", REPAIR_SCRIPT)
assert REPAIR_SPEC and REPAIR_SPEC.loader
REPAIR = importlib.util.module_from_spec(REPAIR_SPEC)
REPAIR_SPEC.loader.exec_module(REPAIR)


class PackageableFilesTests(unittest.TestCase):
    def test_runtime_locks_are_not_counted_as_extracted_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            index = Path(temporary)
            (index / "meta.json").write_bytes(b"{}")
            for name in sorted(PACKAGER.RUNTIME_LOCK_FILENAMES):
                (index / name).touch()

            files, omitted = PACKAGER.packageable_files(index)

            self.assertEqual([path.name for path in files], ["meta.json"])
            self.assertEqual(
                {path.name for path in omitted},
                PACKAGER.RUNTIME_LOCK_FILENAMES,
            )

    def test_unknown_empty_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            index = Path(temporary)
            (index / "meta.json").write_bytes(b"{}")
            (index / "unexpected.empty").touch()

            with self.assertRaisesRegex(RuntimeError, "unexpected empty package files"):
                PACKAGER.packageable_files(index)

    def test_published_manifest_layout_is_repaired_without_changing_parts(self):
        fixture = Path(__file__).parents[2] / "Vendor" / "OtzariaSearchEngine" / "Tests" / "ArtifactPolicyHarness" / "Fixtures" / "otzaria-search-manifest-v22-fixed.json"
        corrected = __import__("json").loads(fixture.read_text(encoding="utf-8"))
        broken = __import__("json").loads(fixture.read_text(encoding="utf-8"))
        broken["artifactIdentity"] = "38472bbf000c9e670286bedb66d68a3914dfafde55d038cb8b9d0e4851e05577"
        broken["lexicalArtifact"]["fileCount"] = 10

        repaired, original_identity = REPAIR.repaired_manifest(broken)

        self.assertEqual(original_identity, broken["artifactIdentity"])
        self.assertEqual(repaired, corrected)


if __name__ == "__main__":
    unittest.main()
