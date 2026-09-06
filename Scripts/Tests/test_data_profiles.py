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
        self.assertEqual(profile["sourceDatabase"]["assetID"], seed["source"]["assetID"])
        self.assertEqual(profile["sourceDatabase"]["sourceAssetSHA256"], seed["source"]["assetSHA256"])
        self.assertEqual(profile["profileVersion"], 2)
        self.assertTrue(profile["releaseBaseURL"].endswith("/otzaria-miniTest10-v2"))
        self.assertEqual(profile["sharedLexicalDatabase"]["releaseTag"], "v0.3.0")
        self.assertEqual(profile["sharedLexicalDatabase"]["bytes"], 57122816)

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
            profile = {
                "profileVersion": 2,
                "databaseAssetName": "miniTest10-seforim.db.zst",
                "releaseBaseURL": "https://example.invalid/releases/otzaria-miniTest10-v2",
            }
            payload = module.build_payload({"id": 42, "tag_name": "source-v1"}, profile, archive)
            self.assertEqual(payload["assets"][0]["id"], profile["profileVersion"])
            self.assertEqual(payload["assets"][0]["name"], profile["databaseAssetName"])
            self.assertEqual(
                payload["assets"][0]["browser_download_url"],
                f"{profile['releaseBaseURL']}/{profile['databaseAssetName']}",
            )


if __name__ == "__main__":
    unittest.main()
