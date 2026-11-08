"""Integrity/fault tests; zstd transport is stubbed here, never native acceptance."""
import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("retained", Path(__file__).parents[1] / "CI/verify-retained-otzaria-package.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class RetainedPackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.package, self.reports = self.root / "package", self.root / "reports"
        self.package.mkdir()
        (self.reports / "logs").mkdir(parents=True)
        (self.reports / "otzaria-artifact").mkdir()
        self.builder, self.identity = "a" * 40, "b" * 64
        self.run = {"id": 1, "head_sha": self.builder, "status": "completed", "conclusion": "success", "path": ".github/workflows/otzaria-search-artifacts.yml"}
        self.manifest = {"artifactIdentity": self.identity, "sourceDatabase": {
            "repository": "Otzaria/SeforimLibrary", "releaseTag": "v36-20261101064231", "databaseSHA256": "c60fbd02b4cf7bda00dc5af16aa48b8bfe193b1121d29c9a048dc348ff42e9d6",
            "databaseBytes": 4178067456, "documentCount": 7660127, "bookCount": 8148, "sourceAssetDigest": "sha256:9b1623035853f6d67f8553a953cf48de60643ece1bc6658e6a3fb80f379c47ba"},
            "lexicalEngine": {"engineVersion": "7.0.1", "indexSchemaVersion": 10, "commit": "225a6d5d7265c478a64d3a609a536d0deed433e7"}, "lexicalArtifact": {"parts": []}}
        for i, name in enumerate(("otzaria_index_meta.json", "otzaria_book_numbers.json", "otzaria_book_order.json")):
            # Only the decompression process is stubbed. File/digest checks use real bytes.
            raw = json.dumps({"engine_version": "7.0.1", "schema_version": 10} if i == 0 else {}).encode()
            asset = f"otzaria-lexical-{i:04}.zst"
            (self.package / asset).write_bytes(raw)
            self.manifest["lexicalArtifact"]["parts"].append({"assetName": asset, "compression": "zstd", "destinationPath": name, "destinationOffset": 0, "uncompressedBytes": len(raw), "packagedBytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()})
        self.manifest["lexicalArtifact"]["packagedBytes"] = sum(p["packagedBytes"] for p in self.manifest["lexicalArtifact"]["parts"])
        self.write(self.package / "otzaria-search-build-metrics.json", {})
        self.write(self.reports / "logs/otzaria-corpus-acceptance.json", {"passed": True, "indexedDocuments": 7660127, "reopenedDocuments": 7660127, "committedBooks": 8148, "quarantinedBooks": 0})
        for phase in ("install", "reopen"):
            self.write(self.reports / f"logs/otzaria-prebuilt-{phase}.json", {"passed": True, "artifactIdentity": self.identity, "documentCount": 7660127, "productionValidatorRan": True, "localIndexingRan": False})
        self.codec = patch.object(helper.subprocess, "check_output", side_effect=lambda cmd: Path(cmd[-1]).read_bytes())
        self.codec.start()
        self.addCleanup(self.codec.stop)

    def write(self, path, value): path.write_text(json.dumps(value), encoding="utf-8")

    def verify(self):
        self.write(self.root / "run.json", self.run)
        self.write(self.package / "otzaria-search-manifest.json", self.manifest)
        self.write(self.reports / "otzaria-artifact/otzaria-search-manifest.json", self.manifest)
        return helper.verify(self.package, self.reports, self.root / "run.json", self.builder)

    def test_valid_receipts_and_every_byte_match(self): self.assertEqual(self.verify()["assetCount"], 5)

    def test_wrong_builder_is_rejected(self):
        self.run["head_sha"] = "c" * 40
        with self.assertRaises(AssertionError): self.verify()

    def test_failed_source_is_rejected(self):
        self.run["conclusion"] = "failure"
        with self.assertRaises(AssertionError): self.verify()

    def test_native_reopen_for_other_artifact_is_rejected(self):
        path = self.reports / "logs/otzaria-prebuilt-reopen.json"
        value = helper.read(path); value["artifactIdentity"] = "c" * 64; self.write(path, value)
        with self.assertRaises(AssertionError): self.verify()

    def test_corrupt_part_is_rejected(self):
        (self.package / "otzaria-lexical-0000.zst").write_bytes(b"corrupt")
        with self.assertRaises(AssertionError): self.verify()

    def test_destination_traversal_is_rejected(self):
        self.manifest["lexicalArtifact"]["parts"][0]["destinationPath"] = "../outside"
        with self.assertRaises(AssertionError): self.verify()

    def test_unexpected_assets_are_rejected(self):
        (self.package / "unexpected.txt").touch()
        with self.assertRaises(AssertionError): self.verify()

    def test_server_must_publish_identical_immutable_assets(self):
        result = self.verify()
        release = {"tag_name": result["tag"], "draft": False, "immutable": True, "assets": [dict(name=n, state="uploaded", size=a["bytes"], digest="sha256:" + a["sha256"]) for n, a in result["assets"].items()]}
        helper.verify_publication(result, release)
        release["assets"][0]["digest"] = "sha256:" + "0" * 64
        with self.assertRaises(AssertionError): helper.verify_publication(result, release)


if __name__ == "__main__": unittest.main()
