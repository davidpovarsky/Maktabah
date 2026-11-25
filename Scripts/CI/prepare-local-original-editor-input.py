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


def exact_producer_path(root, relative, *, build=False):
    path = root / relative
    require(path.is_relative_to(root / 'build' if build else root)
            and path.resolve() == path and path.is_file() and not path.is_symlink(),
            'Original donor receipt escaped its retained producer: ' + str(relative))
    return path


def collect_donor_receipts(producer_root, abi_path, source_before, qualification):
    """Reverify the real installed ABI; retain every historical identity verbatim."""
    reference = read_json(abi_path)
    if reference.get('schema') != LOCAL['DONOR_SCHEMA']:
        return {}
    policy_path = exact_producer_path(producer_root, LOCAL['DONOR_POLICY'])
    policy = read_json(policy_path)
    require(digest(policy_path) == reference.get('policy_sha256'),
            'Donor policy changed before packaging')
    donor_root = Path(reference['donor_root'])
    require(donor_root.is_absolute() and donor_root.resolve() == donor_root
            and donor_root != producer_root
            and subprocess.check_output(['git', '-C', str(donor_root), 'rev-parse', 'HEAD'],
                                        text=True).strip() == LOCAL['DONOR_SOURCE'],
            'Original donor checkout identity differs')
    paths = {'abi_donor_policy': policy_path}
    for role, row in policy['receipts'].items():
        path = exact_producer_path(donor_root, row['path'], build=True)
        require(digest(path) == row['sha256'], 'Original donor receipt changed: ' + role)
        paths['abi_donor_' + role] = path
    donor_abi = read_json(paths['abi_donor_abi'])
    wrapper = donor_abi['pinned_wrapper']
    wrapper_path = exact_producer_path(
        donor_root, (Path(policy['receipts']['abi']['path']).parent / wrapper['path']).as_posix(),
        build=True)
    require(wrapper_path.stat().st_size == wrapper['bytes']
            and digest(wrapper_path) == wrapper['sha256'],
            'Original pinned-wrapper receipt changed before packaging')
    paths['abi_donor_pinned_wrapper'] = wrapper_path
    require(set(paths) == LOCAL['DONOR_ROLES'], 'Incomplete original donor transport closure')

    # The frozen producer's existing verifier checks original receipts/source,
    # all 733 generated files, and all 17 actual installed Lib members. It does
    # not run a generator, build or native/editor test.
    verify_code = (
        "import json,sys;from pathlib import Path;"
        "root=Path(sys.argv[1]);sys.path.insert(0,str(root/'Tools/OriginalEditor'));"
        "from donor_abi_input import verify;"
        "source=json.loads(Path(sys.argv[3]).read_text());"
        "print(json.dumps(verify(root,Path(sys.argv[2]),sys.argv[4],source)))"
    )
    observed = json.loads(subprocess.check_output(
        [sys.executable, '-I', '-B', '-c', verify_code, str(producer_root), str(abi_path),
         str(source_before), digest(abi_path)], text=True, timeout=600))
    require(observed == qualification.get('heart'),
            'Actual current native donor verification differs from the qualified SDK')
    return paths



def collect_fresh_receipts(producer_root, abi_path, source_before, qualification):
    """Run the frozen original verifier before transporting its fresh origins."""
    abi = read_json(abi_path)
    if abi.get('schema') != LOCAL['FRESH_SCHEMA']:
        return {}, None
    before = read_json(source_before)
    for name, expected in LOCAL['FRESH_VERIFIERS'].items():
        path = exact_producer_path(producer_root, name)
        committed = subprocess.check_output(
            ['git', '-C', str(producer_root), 'show', 'HEAD:' + name])
        require(digest(path) == hashlib.sha256(committed).hexdigest() == expected
                and before.get('source_inputs', {}).get(name, {}).get('sha256') == expected,
                'Current original ABI verifier source differs: ' + name)
    paths = {}
    for name, row in abi['qualification_receipts'].items():
        path = exact_producer_path(
            producer_root, (abi_path.parent.relative_to(producer_root) / row['path']).as_posix(),
            build=True)
        require(path.stat().st_size == row['bytes'] and digest(path) == row['sha256'],
                'Fresh original qualification bytes differ: ' + name)
        paths['abi_' + name] = path
    wrapper = abi['pinned_wrapper']
    path = exact_producer_path(producer_root,
        (abi_path.parent.relative_to(producer_root) / wrapper['path']).as_posix(), build=True)
    require(path.stat().st_size == wrapper['bytes'] and digest(path) == wrapper['sha256'],
            'Fresh original wrapper proof differs')
    paths['abi_pinned_wrapper'] = path
    source_sha = qualification['source_sha']
    verify_code = (
        "import json,sys;from pathlib import Path;"
        "root=Path(sys.argv[1]);sys.path.insert(0,str(root/'Tools/OriginalEditor'));"
        "from import_abi_input import verify;"
        "source=json.loads(Path(sys.argv[3]).read_text());"
        "print(json.dumps(verify(root,Path(sys.argv[2]),sys.argv[4],source)))"
    )
    observed = json.loads(subprocess.check_output(
        [sys.executable, '-I', '-B', '-c', verify_code, str(producer_root), str(abi_path),
         str(source_before), digest(abi_path)], text=True, timeout=600))
    require(observed == qualification.get('heart')
            and subprocess.check_output(['git', '-C', str(producer_root), 'rev-parse', 'HEAD'],
                                        text=True).strip() == source_sha
            and not subprocess.check_output(['git', '-C', str(producer_root), 'diff', '--name-only', 'HEAD']),
            'Fresh original ABI verification or producer source changed')
    return paths, {
        'schema': 'otzaria.current-original-abi-verification/1',
        'status': 'CURRENT_ORIGINAL_ABI_VERIFIER_PASS', 'returncode': 0,
        'producer_source_sha': source_sha, 'source_observation_sha256': digest(source_before),
        'abi_sha256': digest(abi_path), 'verifier_sources': LOCAL['FRESH_VERIFIERS'],
        'observed_heart': observed, 'source_unchanged': True,
        'new_native_tests': 0, 'new_sdk_or_ui_credit': False,
    }


def local_execution_receipt(producer_root, evidence, identity, *, donor=False):
    path = evidence / 'local-execution.json'
    if not path.exists() and donor:
        # A bounded genuine continuation keeps the original execution descriptor;
        # it does not create a second UUID or pretend to be another producer.
        path = Path(identity['local_execution']['evidence_root']) / 'local-execution.json'
    require(path.is_relative_to(producer_root / 'build') and path.resolve() == path
            and path.is_file() and not path.is_symlink()
            and digest(path) == identity['local_execution_sha256']
            and read_json(path) == identity['local_execution'],
            'Exact original local execution descriptor is unavailable')
    return path


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
    source_before = read_json(evidence / 'source-before.json')
    contract = source_before.get('public_host_contract_sha256')
    contract = contract if contract in API['REVIEWED_PUBLIC_HOST_CONTRACTS'] else None
    API['require_compiled_host_api'](qualification, admission_schema=3,
                                     public_contract_sha256=contract)
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
    donor_paths = collect_donor_receipts(producer_root, abi_path, evidence / 'source-before.json', qualification)
    fresh_paths, fresh_verification = collect_fresh_receipts(
        producer_root, abi_path, evidence / 'source-before.json', qualification)
    require(not (donor_paths and fresh_paths), 'Fresh ABI and historical donor routes cannot be combined')
    local_execution_path = local_execution_receipt(producer_root, evidence, identity, donor=bool(donor_paths))
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
        'execution': copy(local_execution_path, 'local-execution.json'),
        'source_before': copy(evidence / 'source-before.json', 'source-before.json'),
        'source_after': copy(evidence / 'source-after.json', 'source-after.json'),
        'abi': copy(abi_path, 'qualified-import-abi.json'),
    }
    receipts.update({role: copy(path, role + '.json') for role, path in {**donor_paths, **fresh_paths}.items()})
    if fresh_verification is not None:
        target = destination / 'abi_fresh_verification.json'
        API['write'](target, fresh_verification)
        receipts['abi_fresh_verification'] = {'path': target.relative_to(ROOT).as_posix(),
            'bytes': target.stat().st_size, 'sha256': digest(target)}
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
    if donor_paths:
        config['abi_provenance'] = LOCAL['DONOR_SCHEMA']
    if fresh_verification is not None:
        config['abi_provenance'] = LOCAL['FRESH_SCHEMA']
    if contract:
        config['public_host_contract_sha256'] = contract
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