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
ZAYIT_SCRIPT = Path(__file__).parents[1] / "package-zayit-search-artifact.py"
ZAYIT_SPEC = importlib.util.spec_from_file_location("zayit_packager", ZAYIT_SCRIPT)
assert ZAYIT_SPEC and ZAYIT_SPEC.loader
ZAYIT_PACKAGER = importlib.util.module_from_spec(ZAYIT_SPEC)
ZAYIT_SPEC.loader.exec_module(ZAYIT_PACKAGER)


class PackageableFilesTests(unittest.TestCase):
    def test_original_schema10_metadata_and_book_id_order_survive_packaging(self):
        with tempfile.TemporaryDirectory() as temporary:
            index = Path(temporary)
            original = {"otzaria_index_meta.json", "otzaria_book_numbers.json", "otzaria_book_order.json",
                        "otzaria_future_engine_sidecar.json", "meta.json", "segment.store"}
            local = {"otzaria_search_identity.json", "otzaria_search_checkpoint.json",
                     "otzaria_search_failures.json", "otzaria_lexical_build_metrics.json",
                     "otzaria_prebuilt_installation.json", "otzaria_pdf_freshness.json",
                     "otzaria_semantic_artifact.json"}
            for name in original | local:
                (index / name).write_bytes(b'{"original":true}')
            (index / ".otzaria_index_building").touch()
            (index / "otzaria_book_order.lock").touch()
            files, omitted = PACKAGER.packageable_files(index)
            self.assertEqual({path.name for path in files}, original)
            self.assertEqual({path.name for path in omitted}, {"otzaria_book_order.lock"})

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

    def test_schema10_package_rejects_missing_original_metadata_before_compression(self):
        with tempfile.TemporaryDirectory() as temporary:
            index = Path(temporary)
            (index / "meta.json").write_bytes(b"{}")
            with self.assertRaisesRegex(RuntimeError, "original schema10 engine metadata is missing"):
                PACKAGER.validate_engine_metadata(index, [index / "meta.json"],
                    {"index_schema_version": 10, "engine_package_version": "7.0.1"})

    def test_schema10_package_rejects_foreign_engine_recipe(self):
        with tempfile.TemporaryDirectory() as temporary:
            index = Path(temporary)
            for name in PACKAGER.ENGINE_RUNTIME_FILENAMES:
                (index / name).write_bytes(b"{}")
            metadata = index / "otzaria_index_meta.json"
            metadata.write_text('{"schema_version":10,"engine_version":"7.0.0"}')
            with self.assertRaisesRegex(RuntimeError, "differs from the pinned engine/schema"):
                PACKAGER.validate_engine_metadata(index, list(index.iterdir()),
                    {"index_schema_version": 10, "engine_package_version": "7.0.1"})

    def test_unknown_empty_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            index = Path(temporary)
            (index / "meta.json").write_bytes(b"{}")
            (index / "unexpected.empty").touch()

            with self.assertRaisesRegex(RuntimeError, "unexpected empty package files"):
                PACKAGER.packageable_files(index)

    def test_managed_json_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            index = Path(temporary)
            (index / "meta.json").write_bytes(b"{}")
            (index / ".managed.json").write_bytes(b'{"installed": true}')

            with self.assertRaisesRegex(RuntimeError, "forbidden runtime management file"):
                PACKAGER.packageable_files(index)

    def test_zayit_packager_rejects_managed_json(self):
        with tempfile.TemporaryDirectory() as temporary:
            index = Path(temporary)
            (index / "meta.json").write_bytes(b"{}")
            (index / ".managed.json").write_bytes(b'{"installed": true}')

            with self.assertRaisesRegex(RuntimeError, "forbidden runtime management file"):
                ZAYIT_PACKAGER.packageable_files(index)

    def test_zayit_packager_excludes_dotfiles(self):
        with tempfile.TemporaryDirectory() as temporary:
            index = Path(temporary)
            (index / "meta.json").write_bytes(b"{}")
            (index / "segment.fast").write_bytes(b"data")
            (index / ".DS_Store").write_bytes(b"junk")

            files = ZAYIT_PACKAGER.packageable_files(index)
            self.assertEqual(sorted(p.name for p in files), ["meta.json", "segment.fast"])

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
