#!/usr/bin/env python3
"""Package a finished real Mac SDK for the reviewed Maktabah admission commit.

The generated admission is a candidate in build output. The owner must commit
those exact pins to Scripts/CI before the original restore/build route accepts
them. This command builds or executes no product and manufactures no run IDs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Scripts/CI'))
API = runpy.run_path(str(ROOT / 'Scripts/CI/hq-original-editor-distribution.py'))
LOCAL = runpy.run_path(str(ROOT / 'Scripts/CI/original_editor_local_admission.py'))
SHARED = runpy.run_path(str(ROOT / 'Scripts/CI/original_editor_shared_runtime.py'))
require, digest, read_json = (API[name] for name in ('require', 'digest', 'read_json'))


def prepare(producer_root, evidence, abi_path, destination):
    producer_root, evidence, abi_path = map(lambda value: Path(value).resolve(),
                                           (producer_root, evidence, abi_path))
    destination = API['owned_path'](ROOT, destination, build=True)
    require(not destination.exists() and evidence.is_relative_to(producer_root / 'build')
            and abi_path.is_relative_to(producer_root / 'build'), 'Fresh owned packet and actual producer evidence required')
    execution = read_json(evidence / 'execution.json')
    distribution = Path(execution['distribution'])
    require(distribution.is_absolute() and distribution.resolve() == distribution
            and distribution.is_relative_to(producer_root / 'build'), 'Original distribution escaped the producer')
    qualification_path = distribution / 'QUALIFICATION.json'
    qualification = read_json(qualification_path)
    require(execution.get('status') == qualification.get('status') == API['QUALIFIED']
            and qualification.get('phase') == 'COMPLETE'
            and qualification.get('strict_dependency_resolution') == 'PASS_EXACT_COMMITTED_LOCK_UNCHANGED'
            and qualification.get('same_toolchain_only') is True,
            'Only a finished exact original SDK consumer may be packaged')
    owner = qualification.get('shared_runtime_ownership', {})
    require(owner.get('status') == 'PASS_OBSERVED_SINGLE_SHARED_IMPLEMENTATIONS'
            and owner.get('stageb_qualified') is False, 'Actual shared implementation qualification is incomplete')
    API['require_compiled_host_api'](qualification, admission_schema=3)
    observations = qualification.get('verified_runtime_observations', [])
    require(len(observations) == 2 and {row.get('language') for row in observations} == {'en', 'he'}
            and all(row.get('status') == 'ACTUAL_IMPORT_LINK_RESOURCE_RUNTIME_PASS' for row in observations),
            'Actual English/Hebrew external SDK consumer observations are incomplete')
    identity = qualification.get('execution_identity', {})
    require(identity.get('producer_kind') == 'local-mac', 'This packet requires genuine local execution')
    native_tree = qualification.get('heart', {}).get('native_qualification', {}).get('native_source_tree', '')
    require(re.fullmatch(r'[a-f0-9]{40}', native_tree), 'Qualified original Native source tree is absent')
    source_sha = subprocess.check_output(['git', '-C', str(producer_root), 'rev-parse', 'HEAD'], text=True).strip()
    require(source_sha == qualification['source_sha'] == identity['source_sha']
            and not subprocess.check_output(['git', '-C', str(producer_root), 'diff', '--name-only', 'HEAD']),
            'Producer source changed after SDK qualification')
    exported = read_json(evidence / 'framework-distribution.json')
    expected = {**exported['files'], 'QUALIFICATION.json': {
        'bytes': qualification_path.stat().st_size, 'sha256': digest(qualification_path)}}
    require(API['inventory'](distribution) == expected, 'Actual qualified SDK differs from the exported closure')
    destination.mkdir(parents=True)

    def copy(source, name):
        target = destination / name
        before = {'bytes': source.stat().st_size, 'sha256': digest(source)}
        require(source.is_file() and not source.is_symlink(), 'Expected regular producer receipt')
        shutil.copyfile(source, target)
        require(target.stat().st_size == before['bytes'] and digest(target) == before['sha256']
                and digest(source) == before['sha256'], 'Producer receipt changed while packaging')
        return {'path': target.relative_to(ROOT).as_posix(), **before}

    receipts = {
        'execution': copy(evidence / 'local-execution.json', 'local-execution.json'),
        'source_before': copy(evidence / 'source-before.json', 'source-before.json'),
        'source_after': copy(evidence / 'source-after.json', 'source-after.json'),
        'abi': copy(abi_path, 'qualified-import-abi.json'),
    }
    manifest = copy(evidence / 'framework-distribution.json', 'framework-distribution.json')
    hanlin = copy(evidence / 'original-hanlin-snapshot.json', 'original-hanlin-snapshot.json')
    archive = destination / 'framework.zip'
    with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as zipped:
        for name in sorted(expected):
            zipped.write(distribution / name, arcname=name)
    require(API['inventory'](distribution) == expected, 'Qualified SDK changed while archiving')
    clang_path = distribution / 'SourceProvenance/ClangImportContext.json'
    clang = read_json(clang_path)
    config = {
        'schema': 3, 'producer_kind': 'local-mac', 'repository': LOCAL['REPOSITORY'],
        'source_sha': source_sha, 'run_id': identity['run_id'], 'run_attempt': 1,
        'native_source_tree': native_tree, 'configuration': 'Debug', 'platform': 'iphonesimulator',
        'local_execution_sha256': identity['local_execution_sha256'], 'local_receipts': receipts,
        'archive_path': archive.relative_to(ROOT).as_posix(), 'archive_bytes': archive.stat().st_size,
        'archive_sha256': digest(archive),
        'distribution_root': (destination / 'distribution').relative_to(ROOT).as_posix(),
        'distribution_manifest_path': manifest['path'], 'distribution_manifest_sha256': manifest['sha256'],
        'hanlin_source_path': hanlin['path'], 'hanlin_source_sha256': hanlin['sha256'],
        'qualification_sha256': digest(qualification_path),
        'original_source_sha256': digest(distribution / 'SourceProvenance/OriginalSource.json'),
        'toolchain': {'xcode': qualification['preflight']['xcode'], 'swift': qualification['swift'],
                      'sdk_version': qualification['sdk']},
        'shared_runtime': {
            'kind': 'original-shared-implementations/1', 'host_products': SHARED['PRODUCTS'],
            'host_pod_versions': {name: row[1] for name, row in SHARED['PODS'].items()},
            'hanlin_revision': owner['hanlin_source_revision'],
            'swift_ai_revision': owner['shared_swift_ai_sdk_revision'],
            'clang_manifest_sha256': digest(clang_path),
            'clang_roots': {name: clang[name] for name in ('module_maps', 'header_search_paths')},
        },
        'status': 'QUALIFIED_LOCAL_SDK_SIMULATOR_INPUT_REQUIRES_COMMITTED_ADMISSION',
        'native_stageb_qualified': False, 'device_framework_qualified': False,
    }
    LOCAL['validate_provenance'](ROOT, config, qualification, API)
    output = destination / 'admission-candidate.json'
    API['write'](output, config)
    return {'candidate': str(output), 'candidate_sha256': digest(output),
            'source_sha': source_sha, 'execution_id': identity['run_id'],
            'archive_bytes': archive.stat().st_size, 'archive_sha256': config['archive_sha256'],
            'native_stageb_qualified': False, 'device_framework_qualified': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(__doc__)
    for name in ('producer-root', 'producer-evidence', 'abi-receipt', 'destination'):
        parser.add_argument('--' + name, required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(args.producer_root, args.producer_evidence, args.abi_receipt, args.destination), indent=2))
