#!/usr/bin/env python3
"""Measure a reproducible schema7 subset before pinning any generated digest."""
import argparse
import hashlib
import json
from pathlib import Path
import sqlite3
import subprocess
import sys


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        while chunk := stream.read(8 * 1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--release', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    release = json.loads(args.release.read_text())
    assert release['tag_name'] == 'v36-20261101064231' and release['id'] == 430840632
    asset = next(item for item in release['assets'] if item['id'] == 699514342)
    assert asset['name'] == 'seforim-schema7.db.zst'
    assert asset['digest'] == 'sha256:9b1623035853f6d67f8553a953cf48de60643ece1bc6658e6a3fb80f379c47ba'
    with sqlite3.connect(f'file:{args.source.as_posix()}?mode=ro', uri=True) as database:
        metadata = dict(database.execute('SELECT key,value FROM schema_meta'))
    assert metadata['db_schema_version'] == '7' and metadata['db_version'] == '36'
    # The authenticated official v36 file stamps release/schema only.
    # Do not invent a schema_meta content_hash from a separate delta manifest.
    if 'content_hash' in metadata:
        assert metadata['content_hash'] == '704560e8c73480b7926b8e8b16f4bc93f13dfdcfaf8122fef8d31ac3cbe6f452'
    (args.output / 'official-schema-metadata.json').write_text(json.dumps(metadata, indent=2))
    seed = json.loads(Path('Scripts/DataProfiles/miniTest10.seed.json').read_text())
    seed['profileVersion'] = 8
    seed['source'] = dict(repository='Otzaria/SeforimLibrary', releaseTag=release['tag_name'], releaseID=release['id'],
        assetID=asset['id'], assetName=asset['name'], assetBytes=asset['size'], assetSHA256=asset['digest'][7:],
        databaseBytes=args.source.stat().st_size, databaseSHA256=sha(args.source))
    seed_path = args.output / 'miniTest10.seed.json'
    seed_path.write_text(json.dumps(seed, indent=2, ensure_ascii=False) + '\n')
    database = args.output / 'miniTest10-seforim.db'
    replica = args.output / 'repro.db'
    for output in [database, replica]:
        subprocess.run([sys.executable, 'Scripts/build-otzaria-data-profile.py', '--source', str(args.source),
            '--seed', str(seed_path), '--output', str(output), '--compress'], check=True)
    assert sha(database) == sha(replica) and sha(database.with_suffix('.db.zst')) == sha(replica.with_suffix('.db.zst'))
    parity = subprocess.check_output([sys.executable, 'Scripts/verify-otzaria-mini-parity.py', '--source', str(args.source),
        '--mini', str(database), '--seed', str(seed_path)], text=True)
    (args.output / 'database-parity.json').write_text(parity)
    facts = json.loads(database.with_suffix('.provenance.json').read_text())
    profile = json.loads(Path('Source/Otzaria/DataProfiles/miniTest10.profile.json').read_text())
    profile.update(profileVersion=8, releaseBaseURL='https://github.com/davidpovarsky/Maktabah/releases/download/otzaria-miniTest10-v8',
        databaseCompressedBytes=facts['compressedBytes'], databaseCompressedSHA256=facts['compressedSHA256'])
    profile['sourceDatabase'] = {key: value for key, value in seed['source'].items() if key not in ['assetBytes', 'assetSHA256']}
    profile['sourceDatabase'].update(sourceAssetBytes=asset['size'], sourceAssetSHA256=asset['digest'][7:],
        databaseBytes=facts['databaseBytes'], databaseSHA256=facts['databaseSHA256'])
    (args.output / 'miniTest10.profile.json').write_text(json.dumps(profile, indent=2, ensure_ascii=False) + '\n')
    # Only our freshly generated replica is removed; the official source stays intact.
    replica.unlink()
    replica.with_suffix('.db.zst').unlink()
    replica.with_suffix('.provenance.json').unlink()
    print(json.dumps(dict(status='REPRODUCIBLE_DATABASE_CANDIDATE', source=seed['source'], counts=facts['counts']), indent=2))


if __name__ == '__main__':
    main()
