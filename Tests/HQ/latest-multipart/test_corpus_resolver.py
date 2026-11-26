import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SPEC = importlib.util.spec_from_file_location("corpus_resolver", ROOT / "Scripts/resolve-official-library-asset.py")
resolver = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(resolver)


class CorpusReleaseTests(unittest.TestCase):
    def test_v32_accepts_the_original_monolithic_production_asset(self):
        release = json.loads((HERE / "official-v32-release.json").read_bytes())
        plan = resolver.resolve_asset(release)
        self.assertEqual(plan["asset_id"], 629048655)
        self.assertEqual(plan["compressed_bytes"], 1850679582)
        self.assertEqual(plan["parts"], [])

    def test_v40_uses_assembled_identity_and_ordered_official_parts(self):
        release = json.loads((HERE / "official-v40-release.json").read_bytes())
        manifest = (HERE / "official-v40-manifest.json").read_bytes()

        def write_manifest(url, path, maximum):
            self.assertTrue(url.endswith("/seforim-schema7.db.zst.manifest.json"))
            self.assertEqual(maximum, len(manifest))
            path.write_bytes(manifest)

        with patch.object(resolver, "download", write_manifest):
            plan = resolver.resolve_asset(release)
        self.assertEqual(plan["compressed_bytes"], 2129902636)
        self.assertEqual(plan["compressed_sha256"], "39a2b52129323ea53ac3629835c4721e25acff010a8fc971bf076a666a3b9587")
        self.assertEqual([part["size"] for part in plan["parts"]], [1992294400, 137608236])

        release["assets"][2]["digest"] = "sha256:" + ("0" * 64)
        with patch.object(resolver, "download", write_manifest), self.assertRaisesRegex(ValueError, "part differs"):
            resolver.resolve_asset(release)

    def test_partial_or_corrupted_payload_is_never_published(self):
        data = {"first": b"abc", "second": b"def"}
        plan = {
            "asset_name": "seforim-schema7.db.zst", "compressed_bytes": 6,
            "compressed_sha256": hashlib.sha256(b"abcdef").hexdigest(),
            "parts": [{"browser_download_url": url, "size": len(raw), "digest": "sha256:" + hashlib.sha256(raw).hexdigest()}
                      for url, raw in data.items()],
        }

        def write_part(url, path, maximum):
            path.write_bytes(data[url])

        with tempfile.TemporaryDirectory() as directory, patch.object(resolver, "download", write_part):
            output = Path(directory)
            data["second"] = b"bad"
            with self.assertRaisesRegex(ValueError, "integrity check failed"):
                resolver.materialize(plan, output)
            self.assertEqual(list(output.iterdir()), [])
            data["second"] = b"def"
            resolver.materialize(plan, output)
            self.assertEqual((output / plan["asset_name"]).read_bytes(), b"abcdef")


if __name__ == "__main__":
    unittest.main()
