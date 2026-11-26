"""Immutable archive cache integrity; never native app or UI qualification."""
import hashlib
import io
import json
import os
from pathlib import Path
import runpy
import tarfile
import tempfile
import unittest
import zipfile


class VerifiedInputCacheTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        namespace = runpy.run_path(str(Path(__file__).with_name("hq-stage2-focused-apple.py")))
        self.restore = namespace["restore"]
        self.glob = self.restore.__globals__
        self.glob.update(ROOT=self.root, OUT=self.root / "evidence")
        self.staged = self.root / "staged"
        self.staged.mkdir()
        self.cache = self.root / "evidence" / "inputs"
        self.cache.mkdir(parents=True)
        tar = io.BytesIO()
        with tarfile.open(fileobj=tar, mode="w") as archive:
            member = tarfile.TarInfo("original.txt")
            member.size = 14
            archive.addfile(member, io.BytesIO(b"original bytes"))
        self.payload = tar.getvalue()
        archive = self.staged / "1.zip"
        with zipfile.ZipFile(archive, "w") as zipped:
            zipped.writestr("source.tar", self.payload)
        self.raw = archive.read_bytes()
        self.sha = hashlib.sha256(self.raw).hexdigest()
        self.config = {
            "artifacts": [{"id": 1, "name": "cache-integrity-control", "tar": "source.tar",
                           "destination": "restored", "sha256": self.sha}],
            "resources": {}, "sefaria_gitlink": "1" * 40, "resource_bundle_sha256": "2" * 64,
        }
        self.manifest()
        previous = os.environ.get("OTZARIA_STAGED_INPUTS")
        os.environ["OTZARIA_STAGED_INPUTS"] = str(self.staged)
        self.addCleanup(lambda: os.environ.pop("OTZARIA_STAGED_INPUTS", None) if previous is None
                        else os.environ.__setitem__("OTZARIA_STAGED_INPUTS", previous))

    def manifest(self):
        path = self.staged / "1.zip"
        (self.staged / "manifest.json").write_text(json.dumps({
            "schema_version": 1, "repository": "davidpovarsky/Maktabah",
            "files": {"1.zip": {"bytes": path.stat().st_size,
                                 "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}}
        }))

    def seeded(self):
        (self.cache / "1.zip").write_bytes(self.raw)
        (self.cache / "source.tar").write_bytes(self.payload)

    def test_absent_cache_keeps_original_restore_and_extraction(self):
        report = {}
        self.restore(self.config, report)
        self.assertEqual((self.root / "restored/original.txt").read_bytes(), b"original bytes")
        self.assertEqual(report["artifact_inputs"][0]["verified_sha256"], self.sha)
        self.assertNotIn("verified_input_cache_reuse", report)

    def test_equal_cache_is_not_rewritten_but_member_is_extracted(self):
        self.seeded()
        before = {p.name: (p.stat().st_ino, p.stat().st_mtime_ns) for p in self.cache.iterdir()}
        report = {}
        self.restore(self.config, report)
        self.assertEqual(before, {p.name: (p.stat().st_ino, p.stat().st_mtime_ns)
                                  for p in self.cache.iterdir()})
        self.assertEqual((self.root / "restored/original.txt").read_bytes(), b"original bytes")
        self.assertEqual(len(report["verified_input_cache_reuse"]), 2)

    def readonly_checkout(self, contents=b"original bytes"):
        self.config["artifacts"][0].update(
            name="ios-build-swift-packages", destination="build")
        tar = io.BytesIO()
        with tarfile.open(fileobj=tar, mode="w") as archive:
            member = tarfile.TarInfo("SourcePackages/checkouts/Original/PROJECT_BOARD.md")
            member.size = 14
            member.mode = 0o644
            archive.addfile(member, io.BytesIO(b"original bytes"))
        self.payload = tar.getvalue()
        with zipfile.ZipFile(self.staged / "1.zip", "w") as zipped:
            zipped.writestr("source.tar", self.payload)
        self.raw = (self.staged / "1.zip").read_bytes()
        self.sha = hashlib.sha256(self.raw).hexdigest()
        self.config["artifacts"][0]["sha256"] = self.sha
        self.manifest()
        target = self.root / "build/SourcePackages/checkouts/Original/PROJECT_BOARD.md"
        target.parent.mkdir(parents=True)
        target.write_bytes(contents)
        target.chmod(0o444)
        return target

    def test_exact_readonly_checkout_keeps_original_extraction(self):
        target = self.readonly_checkout()
        report = {}
        self.restore(self.config, report)
        self.assertEqual(target.read_bytes(), b"original bytes")
        self.assertEqual(target.stat().st_mode & 0o777, 0o644)
        self.assertEqual(report["verified_readonly_package_restoration"][0]["mode_before"], 0o444)
        self.assertEqual(report["artifact_inputs"][0]["verified_sha256"], self.sha)

    def test_changed_readonly_checkout_is_rejected_without_chmod_or_overwrite(self):
        target = self.readonly_checkout(b"modified bytes")
        with self.assertRaisesRegex(RuntimeError, "Read-only checkout differs"):
            self.restore(self.config, {})
        self.assertEqual(target.read_bytes(), b"modified bytes")
        self.assertEqual(target.stat().st_mode & 0o777, 0o444)

    def test_hardlinked_readonly_checkout_is_rejected_without_chmod(self):
        target = self.readonly_checkout()
        os.link(target, self.root / "other-owned-file")
        with self.assertRaisesRegex(RuntimeError, "owned regular file with one link"):
            self.restore(self.config, {})
        self.assertEqual(target.stat().st_mode & 0o777, 0o444)

    def test_symlinked_build_ancestor_is_rejected_without_chmod(self):
        target = self.readonly_checkout()
        outside = self.root / "other-owned-tree"
        (self.root / "build").rename(outside)
        (self.root / "build").symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(RuntimeError, "canonical build path"):
            self.restore(self.config, {})
        self.assertEqual(target.read_bytes(), b"original bytes")
        self.assertEqual(target.stat().st_mode & 0o777, 0o444)

    def test_same_size_wrong_zip_is_rejected_and_preserved(self):
        self.seeded()
        bad = b"x" + self.raw[1:]
        (self.cache / "1.zip").write_bytes(bad)
        with self.assertRaisesRegex(RuntimeError, "Existing staged cache bytes differ"):
            self.restore(self.config, {})
        self.assertEqual((self.cache / "1.zip").read_bytes(), bad)
        self.assertFalse((self.root / "restored").exists())

    def test_same_size_wrong_tar_is_rejected_and_preserved(self):
        self.seeded()
        bad = b"x" + self.payload[1:]
        (self.cache / "source.tar").write_bytes(bad)
        with self.assertRaisesRegex(RuntimeError, "Existing staged cache bytes differ"):
            self.restore(self.config, {})
        self.assertEqual((self.cache / "source.tar").read_bytes(), bad)
        self.assertFalse((self.root / "restored").exists())

    def test_zip_symlink_is_rejected(self):
        (self.cache / "1.zip").symlink_to(self.staged / "1.zip")
        with self.assertRaisesRegex(RuntimeError, "Nonregular staged cache"):
            self.restore(self.config, {})

    def test_tar_symlink_is_rejected(self):
        (self.cache / "1.zip").write_bytes(self.raw)
        target = self.root / "immutable.tar"
        target.write_bytes(self.payload)
        (self.cache / "source.tar").symlink_to(target)
        with self.assertRaisesRegex(RuntimeError, "Nonregular staged cache"):
            self.restore(self.config, {})
        self.assertEqual(target.read_bytes(), self.payload)

    def test_wrong_staged_bytes_fail_even_with_valid_cached_zip(self):
        self.seeded()
        (self.staged / "1.zip").write_bytes(b"x" + self.raw[1:])
        self.manifest()
        with self.assertRaisesRegex(RuntimeError, "Staged artifact differs from the frozen input"):
            self.restore(self.config, {})
        self.assertFalse((self.root / "restored").exists())

    def test_nonregular_cache_is_rejected(self):
        (self.cache / "1.zip").mkdir()
        with self.assertRaisesRegex(RuntimeError, "Nonregular staged cache"):
            self.restore(self.config, {})


if __name__ == "__main__":
    unittest.main()
