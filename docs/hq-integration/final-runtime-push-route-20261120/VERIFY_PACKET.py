#!/usr/bin/env python3
"""Verify retained bytes and the executed source closure; does not rerun tests."""
import gzip
import hashlib
import json
import io
import tarfile
from pathlib import Path

DOCS = Path(__file__).resolve().parent
ROOT = DOCS.parents[2]
index = json.loads((DOCS / "PACKET_INDEX.json").read_bytes())
seen = set()
for row in index["payloads"]:
    name = row["path"]
    assert name not in seen and not Path(name).is_absolute() and ".." not in Path(name).parts
    seen.add(name)
    data = (ROOT / name).read_bytes()
    assert len(data) == row["bytes"] and hashlib.sha256(data).hexdigest() == row["sha256"], name
    assert hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest() == row["git_blob"], name
    if name.endswith(".gz"):
        raw = gzip.decompress(data)
        assert len(raw) == row["uncompressed_bytes"] and hashlib.sha256(raw).hexdigest() == row["uncompressed_sha256"], name
before = json.loads(gzip.decompress((DOCS / "raw/validation/focused-schema-v2/INPUTS_BEFORE.json.gz").read_bytes()))
after = json.loads(gzip.decompress((DOCS / "raw/validation/focused-schema-v2/INPUTS_AFTER.json.gz").read_bytes()))
assert before == after
for row in before:
    if row["path"].startswith("candidate/"):
        data = (ROOT / row["path"].removeprefix("candidate/")).read_bytes()
        assert hashlib.sha256(data).hexdigest() == row["sha256"], row["path"]
result = json.loads(gzip.decompress((DOCS / "raw/validation/focused-schema-v2/RESULT.json.gz").read_bytes()))
assert result["status"] == "LOCAL_CONTROLS_PASS" and result["inputs_unchanged"]
assert [len(r["observed_passed_cases"]) for r in result["runs"]] == [41, 29]
assert all(r["qualified"] and r["returncode"] == 0 and sorted(r["observed_passed_cases"]) == r["expected_cases"] for r in result["runs"])
previous = json.loads((DOCS / "PREVIOUS_PACKET.json").read_bytes())
with tarfile.open(fileobj=io.BytesIO(gzip.decompress((DOCS / "raw/PREVIOUS_V1_PACKET.tar.gz").read_bytes())), mode="r:") as archive:
    entries = archive.getmembers()
    assert all(member.isfile() and not member.name.startswith("/") and ".." not in Path(member.name).parts for member in entries)
    assert len(entries) == len({member.name for member in entries})
    old = {member.name: archive.extractfile(member).read() for member in entries}
old_index_name = "docs/hq-integration/final-runtime-push-route-20261120/PACKET_INDEX.json"
old_index_bytes = old[old_index_name]
assert hashlib.sha256(old_index_bytes).hexdigest() == previous["index_sha256"]
old_rows = json.loads(old_index_bytes)["payloads"]
assert set(old) == {row["path"] for row in old_rows} | {old_index_name}
for row in old_rows:
    data = old[row["path"]]
    assert len(data) == row["bytes"] and hashlib.sha256(data).hexdigest() == row["sha256"]
assert len(old_rows) == 51
binding = json.loads((ROOT / "Scripts/CI/runtime27-final-push.inputs.json").read_bytes())
assert binding["state"] == "UNFINALIZED" and binding["application_source_sha"] is None and binding["reviewed_r27_sha256"] is None
print(json.dumps({"payloads_verified": len(seen), "new_controls": 41, "original_controls": 29,
                  "source_inputs_unchanged": True, "M_F_selected": False, "Apple_Native": "NOT_RUN"}))
