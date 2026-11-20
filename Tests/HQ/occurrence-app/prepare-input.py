#!/usr/bin/env python3
"""Make one owned, verified miniTest10-v6 copy; never open the pristine index."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import shutil
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
MINI_MANIFEST_SHA = "ae3bd170dc4650806a9fdda1beefe682eeefb5abde886363d6feac999603f8d4"
DB_SHA = "d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef"
ORACLE_SHA = "d5879e40e597963616499fbc181eedba3c5c09745d460b03b2e57077f41c5be8"
ARTIFACT = "08a5ddf76ae187e3ca29c1b483637f1dc8e2a2dcb7001cdb7fe3327236234e83"

def digest(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--database", type=Path, required=True)
    parser.add_argument("--sql-oracle", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    descriptor_path = output / "fixture-descriptor.json"
    if descriptor_path.exists():
        descriptor = json.loads(descriptor_path.read_text(encoding="utf-8"))
        owned = Path(descriptor["root"])
        assert owned.parent == output and owned.name.startswith("owned-mini-")
        assert (owned / "OWNER").read_text(encoding="utf-8") == descriptor["ownerMarker"]
        assert digest(owned / "seforim.db") == DB_SHA
        receipt = json.loads((owned / "INPUT_VERIFIED.json").read_text(encoding="utf-8"))
        for name, proof in receipt["published_files"].items():
            assert digest(owned / "index" / name) == proof["sha256"]
        print(json.dumps({"status": "REUSED_ONE_VERIFIED_OWNED_COPY", "descriptor": str(descriptor_path)}))
        return
    receipt = json.loads(args.receipt.read_text(encoding="utf-8"))
    assert receipt["immutable_release"] and not receipt["engine_opened"] and not receipt["index_rebuilt"]
    assert receipt["artifact_identity"] == ARTIFACT
    assert receipt["metadata_document_count_before_any_engine_open"] == 18879
    pristine = Path(receipt["pristine"])
    manifest = args.receipt.parent / "otzaria-search-manifest.json"
    assert digest(manifest) == receipt["manifest_sha256"] == MINI_MANIFEST_SHA
    assert args.database.stat().st_size == 15470592 and digest(args.database) == DB_SHA
    assert digest(args.sql_oracle) == ORACLE_SHA
    published = receipt["published_files"]
    assert len(published) == 7 and sum(p["bytes"] for p in published.values()) == 14665801
    assert set(p.name for p in pristine.iterdir()) == set(published)
    for name, proof in published.items():
        path = pristine / name
        assert Path(name).name == name and not path.is_symlink() and path.is_file()
        assert path.stat().st_size == proof["bytes"] and digest(path) == proof["sha256"]
    owned = output / ("owned-mini-" + str(uuid.uuid4()))
    owned.mkdir(exist_ok=False)
    marker = "otzaria-occurrence-app-disposable-v1:" + owned.name + "\n"
    (owned / "OWNER").write_text(marker, encoding="utf-8", newline="\n")
    index = owned / "index"
    index.mkdir()
    for name, proof in published.items():
        shutil.copy2(pristine / name, index / name)
        assert digest(index / name) == proof["sha256"]
    shutil.copy2(args.database, owned / "seforim.db")
    assert digest(owned / "seforim.db") == DB_SHA
    shutil.copy2(manifest, owned / "original-mini-manifest.json")
    shutil.copy2(args.sql_oracle, owned / "SQL_ORACLE.json")
    shutil.copy2(args.receipt, owned / "INPUT_VERIFIED.json")
    # Re-observe both source and copy. This is a captured before/after hash check,
    # not an assertion about any unobserved user data.
    assert digest(args.database) == DB_SHA
    for name, proof in published.items():
        assert digest(pristine / name) == digest(index / name) == proof["sha256"]
    descriptor = {
        "root": str(owned), "ownerMarker": marker,
        "miniManifest": str(owned / "original-mini-manifest.json"),
        "fullManifest": str(ROOT / "docs/hq-integration/occurrence-app-20261120/manifest-authentication/full-v32-typed.json"),
        "sqlOracle": str(owned / "SQL_ORACLE.json"),
        "databaseSHA256": DB_SHA, "miniManifestSHA256": MINI_MANIFEST_SHA, "sqlOracleSHA256": ORACLE_SHA,
    }
    descriptor_path.write_text(json.dumps(descriptor, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    proof = {
        "observedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "status": "VERIFIED_ONE_OWNED_COPY_NO_ENGINE_OPEN",
        "descriptor": str(descriptor_path), "inputReceipt": str(args.receipt),
        "inputReceiptSHA256": digest(args.receipt),
        "databaseSource": str(args.database), "databaseSHA256": DB_SHA,
        "pristineIndex": str(pristine), "publishedFiles": published,
        "sourceAndCopyPayloadHashesBeforeAfterEqual": True,
        "engineOpened": False, "indexRebuilt": False, "userIndexOpened": False,
        "sqlOracleSource": str(args.sql_oracle), "sqlOracleSHA256": ORACLE_SHA,
    }
    (output / "INPUT_COPY_VERIFIED.json").write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": proof["status"], "descriptor": str(descriptor_path),
                      "copiedBytes": 15470592 + 14665801}, ensure_ascii=False))

if __name__ == "__main__":
    main()
