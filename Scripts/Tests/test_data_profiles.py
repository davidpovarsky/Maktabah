import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).parents[2]


class DataProfileTests(unittest.TestCase):
    def test_bundled_profile_matches_seed(self):
        profile = json.loads((ROOT / "Source/Otzaria/DataProfiles/miniTest10.profile.json").read_text(encoding="utf-8"))
        seed = json.loads((ROOT / "Scripts/DataProfiles/miniTest10.seed.json").read_text(encoding="utf-8"))
        self.assertEqual(profile["profileID"], seed["profileID"])
        self.assertEqual(profile["profileVersion"], seed["profileVersion"])
        self.assertEqual(profile["bookIDs"], seed["bookIDs"])
        self.assertEqual(profile["goldenQueries"], seed["goldenQueries"])
        self.assertEqual(profile["sourceDatabase"]["releaseID"], seed["source"]["releaseID"])
        self.assertEqual(profile["sourceDatabase"]["sourceAssetSHA256"], seed["source"]["assetSHA256"])

    def test_synthetic_release_uses_profile_archive_identity(self):
        path = ROOT / "Scripts/make-mini-test10-release-json.py"
        spec = importlib.util.spec_from_file_location("mini_release", path)
        self.assertIsNotNone(spec)
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "mini.zst"
            archive.write_bytes(b"deterministic-mini")
            module = importlib.util.module_from_spec(spec)
            assert spec and spec.loader
            spec.loader.exec_module(module)
            self.assertEqual(len(module.digest(archive)), 64)


if __name__ == "__main__":
    unittest.main()
