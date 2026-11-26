#!/usr/bin/env python3
"""Create the installable source package; this does not qualify native execution."""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parent
source = root / "source"
paths = sorted(path for path in source.rglob("*") if path.is_file())
assert len(paths) == 3 and all(not path.is_symlink() for path in paths)
output = root / "FileWorkshop.hanlinNativeScript"
with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in paths:
        entry = zipfile.ZipInfo(path.relative_to(source).as_posix(), (2026, 11, 25, 0, 0, 0))
        entry.create_system = 3
        entry.external_attr = 0o100644 << 16
        entry.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(entry, path.read_bytes())
receipt = {
    "schema": 1, "app_id": "org.itorah.miniapps.fileworkshop", "version": "1.0.0",
    "archive": output.name, "bytes": output.stat().st_size,
    "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
    "files": {p.relative_to(source).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
    "bundled_runtime": False, "native_acceptance": "NOT_RUN",
}
(root / "PACKAGE.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
print(json.dumps(receipt, sort_keys=True))
