"""Audit saved small release metadata/manifests; do not download DB/index assets."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs/hq-search"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


inventory = read(EVIDENCE / "release-inventory.json")
official = read(EVIDENCE / "database-release-v32.json")
upstream = read(ROOT / "Vendor/OtzariaSearchEngine/Upstream/UPSTREAM_MANIFEST.json")
report = {"date": "2026-11-15", "scope": "metadata only; no payload/installation/runtime verification", "checks": []}


def check(condition, description):
    report["checks"].append({"pass": bool(condition), "description": description})


manifests = {}
for component in ("otzaria", "zayit"):
    release = next(x for x in inventory if x["tag_name"].startswith(component + "-search-data-v32-"))
    filename = component + "-search-manifest.json"
    path = EVIDENCE / "manifests" / filename
    manifest = read(path)
    manifests[component] = manifest
    assets = {a["name"]: a for a in release["assets"]}
    metadata = assets[filename]
    check(path.stat().st_size == metadata["size"], component + " manifest byte count")
    check("sha256:" + hashlib.sha256(path.read_bytes()).hexdigest() == metadata["digest"], component + " manifest API SHA256")
    parts = manifest["lexicalArtifact"]["parts"] if component == "otzaria" else manifest["parts"]
    for part in parts:
        asset = assets.get(part["assetName"])
        check(asset is not None and asset["size"] == part["packagedBytes"]
              and asset["digest"] == "sha256:" + part["sha256"], component + " part API identity: " + part["assetName"])
    report[component] = {"release": release["html_url"], "immutable": release["immutable"],
                         "artifactIdentity": manifest["artifactIdentity"], "parts": len(parts)}

otzaria = manifests["otzaria"]
zayit = manifests["zayit"]
source = otzaria["sourceDatabase"]
required = zayit["requiredDatabase"]
asset = next(a for a in official["assets"] if a["name"] == source["assetName"])
check(official["id"] == source["releaseID"] and official["tag_name"] == source["releaseTag"], "official v32 release identity")
check(asset["id"] == source["assetID"] and asset["size"] == source["compressedBytes"]
      and asset["digest"] == source["sourceAssetDigest"], "official v32 compressed asset identity")
check(required["releaseTag"] == source["releaseTag"] and required["bytes"] == source["databaseBytes"]
      and required["canonicalSHA256"] == source["databaseSHA256"]
      and required["compressedAssetSHA256"] == source["sourceAssetDigest"].removeprefix("sha256:"), "Otzaria/Zayit canonical database agreement")
engine = otzaria["lexicalEngine"]
for manifest_key, upstream_key in [("commit", "commit"), ("engineVersion", "engine_package_version"),
                                  ("indexSchemaVersion", "index_schema_version"), ("defaultGenerationOrder", "default_generation_order")]:
    check(engine[manifest_key] == upstream[upstream_key], "Otzaria engine pin: " + manifest_key)
for resource in read(ROOT / "Vendor/OtzariaSearchEngine/Upstream/RESOURCE_MANIFEST.json")["resources"]:
    if resource["sha256"]:
        actual = hashlib.sha256((ROOT / resource["destination"]).read_bytes()).hexdigest()
        check(otzaria["resources"][resource["destination"]]["sha256"] == actual == resource["sha256"], "bundled resource: " + resource["destination"])
report["passed"] = sum(x["pass"] for x in report["checks"])
report["failed"] = len(report["checks"]) - report["passed"]
(EVIDENCE / "v32-metadata-audit.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"v32 metadata audit: {report['passed']} PASS, {report['failed']} FAIL; payload/runtime/device gates OPEN")
raise SystemExit(1 if report["failed"] else 0)
