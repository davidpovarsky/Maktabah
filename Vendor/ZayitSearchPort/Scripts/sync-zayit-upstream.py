#!/usr/bin/env python3
import argparse, hashlib, json, pathlib, urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/'Upstream/UPSTREAM_MANIFEST.json').read_text())
parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');parser.add_argument('--write',action='store_true');args=parser.parse_args()
out=ROOT/'Upstream/kotlin-reference';out.mkdir(parents=True,exist_ok=True)
changed=[]
for item in manifest['files']:
    path=item['upstream'];url=f"https://raw.githubusercontent.com/{manifest['repository']}/{manifest['commit']}/{path}"
    try:data=urllib.request.urlopen(url,timeout=30).read()
    except Exception as e: print(f"ERROR {path}: {e}"); changed.append(path); continue
    target=out/pathlib.Path(path).name
    old=target.read_bytes() if target.exists() else None
    if old!=data: changed.append(path)
    if args.write: target.write_bytes(data)
for p in changed:print('CHANGED',p)
if args.check and changed:raise SystemExit(1)
print('OK' if not changed else f'{len(changed)} changed')
