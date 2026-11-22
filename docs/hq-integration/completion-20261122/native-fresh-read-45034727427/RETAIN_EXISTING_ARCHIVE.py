import base64, datetime, hashlib, json, subprocess, zipfile
from pathlib import Path
ROOT = Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-continuation-root-20261122\native450347")
OUT = ROOT.parent / "native450347-publication"
OUT.mkdir(exist_ok=False)
REPO = "davidpovarsky/Maktabah"
entries = [("original-evidence.zip", ROOT / "evidence.zip"), ("INTAKE.json", ROOT / "INTAKE.json"), ("RUN.json", ROOT / "RUN.json"), ("evidence.inventory.json", ROOT / "evidence.zip.inventory.json"), ("captures.inventory.json", ROOT / "captures.zip.inventory.json"), ("captures/manifest.json", ROOT / "selected-captures/manifest.json")]
selected = ["BD3887AE-1379-4B12-8E44-504B7EFF34EA.txt", "B1F44DD3-678D-4E7A-8D93-8F4AFC6EF496.png", "343121AD-918C-439E-9238-CB99207053FA.txt", "8333B8C3-43F0-49B1-962B-98222CFDA84E.png", "7AD49B7F-9783-4B88-A0B0-BC8B69FB7FD2.txt", "7E6CE380-4047-42DA-B15B-D0EC514B5648.png"]
assert hashlib.sha256((ROOT / "evidence.zip").read_bytes()).hexdigest() == "25c24bcdf22efb89313fca1e0824f78d650071b8f55314739e6f440ca3f791c2"
assert hashlib.sha256((ROOT / "captures.zip").read_bytes()).hexdigest() == "dc2aa8d14000c55be8b0a4e12c3b6e40bdcc5b4bc3faa5ef80a6caaf8648f936"
with zipfile.ZipFile(ROOT / "captures.zip") as archive:
    for filename in selected:
        matches = list((ROOT / "selected-captures").rglob(filename))
        original = [n for n in archive.namelist() if n.endswith("/" + filename)]
        assert len(matches) == len(original) == 1, filename
        assert matches[0].read_bytes() == archive.read(original[0]), filename
        entries.append(("captures/" + filename, matches[0]))
watch = ROOT.parent / "native450347-watch"
entries += [("observer-initial.json", watch / "WATCH.json"), ("observer-continuation.json", watch / "continuation-1/WATCH.json")]
receipt = {"schema": "otzaria.existing-native-evidence-git-retention/1", "run_id": 45034727427, "run_attempt": 1, "source_head": "81039998e66bba1d7310455d80a3c50e59785699", "repository": REPO, "new_github_artifact_downloads": 0, "archive_bytes_preserved": True, "selected_capture_bytes_match_original_archive": True, "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "files": []}
def save(): (OUT / "PUBLISHED_BLOBS.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
save()
for name, path in entries:
    b = path.read_bytes()
    expected = hashlib.sha1(b"blob " + str(len(b)).encode() + b"\0" + b).hexdigest()
    request = OUT / "blob-request.json"
    request.write_text(json.dumps({"content": base64.b64encode(b).decode(), "encoding": "base64"}), encoding="utf-8")
    try:
        r = subprocess.run(["gh", "api", "--method", "POST", f"repos/{REPO}/git/blobs", "--input", str(request)], capture_output=True, timeout=100)
        if r.returncode: raise RuntimeError(r.stderr.decode(errors="replace")[:2000])
        result = json.loads(r.stdout)
        assert result["sha"] == expected
        receipt["files"].append({"path": name, "source_path": str(path), "bytes": len(b), "sha256": hashlib.sha256(b).hexdigest(), "git_blob": expected})
        save()
    finally:
        request.unlink(missing_ok=True)
receipt["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
receipt["status"] = "ALL_BLOBS_PUBLISHED_WITH_EXACT_CONTENT_IDENTITIES"
save()
print(json.dumps(receipt))
