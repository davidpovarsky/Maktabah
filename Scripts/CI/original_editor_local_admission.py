"""Transport and provenance for a genuinely qualified dedicated-Mac SDK.

This is the local producer variant of the complete shared-runtime contract.
The original binary, API, English/Hebrew, resource and ownership gates remain in
hq-original-editor-distribution.py. No GitHub run/artifact ID is manufactured.
"""
import json
from pathlib import Path
import re
import shutil
import stat
import uuid
import zipfile

REPOSITORY = 'davidpovarsky/anytype-swift'
QUALIFIED = 'ACTUAL_ORIGINAL_FRAMEWORK_EXTERNAL_IMPORT_LINK_RESOURCES_PASS'
ROLES = {'execution', 'source_before', 'source_after', 'abi'}


def require(value, reason):
    if not value:
        raise RuntimeError(reason)


def validate_configuration(config):
    require(config.get('schema') == 3 and config.get('producer_kind') == 'local-mac'
            and config.get('repository') == REPOSITORY,
            'Local SDK requires the complete shared-runtime contract')
    execution = config.get('run_id', '')
    require(isinstance(execution, str) and execution.startswith('local-')
            and str(uuid.UUID(execution[6:])) == execution[6:]
            and type(config.get('run_attempt')) is int and config['run_attempt'] == 1,
            'Local SDK execution must have its own canonical UUID')
    require(not ({'artifact_id', 'job_id', 'repository_id', 'workflow_path',
                  'framework_artifact', 'evidence_artifact', 'runtime_qualification_producer'} & set(config)),
            'Local provenance must not borrow GitHub run or artifact identities')
    require(re.fullmatch(r'[0-9a-f]{40}', config.get('source_sha', ''))
            and type(config.get('archive_bytes')) is int and config['archive_bytes'] > 0,
            'Local SDK source/archive identity is incomplete')
    for name in ('archive_sha256', 'distribution_manifest_sha256', 'qualification_sha256',
                 'original_source_sha256', 'hanlin_source_sha256', 'local_execution_sha256'):
        require(re.fullmatch(r'[0-9a-f]{64}', config.get(name, '')), 'Missing local SDK digest: ' + name)
    rows = config.get('local_receipts', {})
    require(set(rows) == ROLES, 'Local SDK source/ABI evidence closure is incomplete')
    for role, row in rows.items():
        require(set(row) == {'path', 'bytes', 'sha256'} and type(row['bytes']) is int and row['bytes'] > 0
                and re.fullmatch(r'[0-9a-f]{64}', row['sha256'])
                and isinstance(row['path'], str) and row['path'].startswith('build/'),
                'Malformed local source/ABI receipt: ' + role)
    require(rows['execution']['sha256'] == config['local_execution_sha256'],
            'Local execution descriptor aliases disagree')


def read_receipts(root, config, api):
    validate_configuration(config)
    values = {}
    for role, row in config['local_receipts'].items():
        path = api['owned_path'](root, row['path'], build=True)
        require(path.is_file() and not path.is_symlink() and path.stat().st_size == row['bytes']
                and api['digest'](path) == row['sha256'], 'Local SDK receipt bytes differ: ' + role)
        values[role] = api['read_json'](path)
    return values


def validate_abi_adapter(abi, heart, source_sha):
    """Keep the new audited compiler adapter explicit in downstream provenance."""
    schema = abi.get('schema')
    if schema == 'otzaria.original-import-local-sdk-input/1':
        require('pinned_wrapper' not in abi and 'pinned_wrapper' not in heart,
                'Historical ABI provenance cannot silently admit a wrapper adapter')
        return
    require(schema == 'otzaria.original-import-local-sdk-input/2'
            and heart.get('schema') == schema, 'Unsupported original Import ABI schema')
    reference, proof = abi.get('pinned_wrapper', {}), heart.get('pinned_wrapper', {})
    require(set(reference) == {'path', 'bytes', 'sha256'}
            and reference['path'] == 'pinned-wrapper/RESULT.json'
            and type(reference['bytes']) is int and reference['bytes'] > 0
            and re.fullmatch(r'[a-f0-9]{64}', reference['sha256'])
            and proof.get('schema') == 'otzaria.gomobile-pinned-wrapper-observation/1'
            and proof.get('status') == 'THREE_ACTUAL_PINNED_WRAPPERS_PASS'
            and proof.get('control_sha') == source_sha
            and proof.get('receipt_sha256') == reference['sha256']
            and proof.get('targets') == ['ios-arm64', 'iossimulator-arm64', 'iossimulator-amd64']
            and proof.get('original_go_sum_preserved') is True
            and proof.get('all_targets_admitted_before_compile') is True
            and proof.get('original_gomobile_modified') is False
            and proof.get('rejected_archives_reused') is False,
            'Qualified SDK omits the exact complete pinned-wrapper ABI proof')


def validate_provenance(root, config, qualification, api):
    values = read_receipts(root, config, api)
    execution = values['execution']
    require(execution.get('schema') == 'otzaria.original-editor.local-execution/1'
            and execution.get('repository') == REPOSITORY
            and execution.get('execution_id') == config['run_id']
            and execution.get('source_sha') == config['source_sha']
            and re.fullmatch(r'[0-9a-f]{40}', execution.get('source_tree', ''))
            and execution.get('head_branch') == 'codex/otzaria-sdk-mac-20261124'
            and execution.get('host', {}).get('system') == 'Darwin'
            and execution.get('host', {}).get('architecture') == 'arm64'
            and execution['host'].get('hostname')
            and execution.get('acceptance') == 'PROVENANCE_ONLY_NOT_ACCEPTANCE',
            'The actual dedicated-Mac producer identity differs')
    identity = qualification.get('execution_identity', {})
    require(identity.get('producer_kind') == 'local-mac'
            and identity.get('source_sha') == config['source_sha']
            and identity.get('run_id') == config['run_id'] and identity.get('run_attempt') == '1'
            and identity.get('local_execution_sha256') == config['local_execution_sha256']
            and identity.get('local_execution') == execution,
            'SDK qualification does not bind the real local producer')
    before, after, abi = values['source_before'], values['source_after'], values['abi']
    require(before == after and before.get('head_sha') == config['source_sha']
            and before.get('execution_identity') == identity
            and before.get('status') == 'SOURCE_BOUND_FRAMEWORK_RUNTIME_NOT_RUN',
            'Actual SDK source closure was not preserved through execution')
    validate_abi_adapter(abi, qualification.get('heart', {}), config['source_sha'])
    require(abi.get('status') == 'PASS' and abi.get('producer_kind') == 'local-mac'
            and abi.get('sdk_source_sha') == config['source_sha']
            and abi.get('local_execution_sha256') == config['local_execution_sha256']
            and abi.get('full_sdk_accepted') is False and abi.get('editor_ui_accepted') is False
            and abi.get('owned_command_groups_drained') is True
            and qualification.get('heart', {}).get('receipt_sha256') == config['local_receipts']['abi']['sha256']
            and qualification['heart'].get('native_qualification') == abi.get('native_qualification')
            and abi.get('native_qualification', {}).get('status') == 'PASS',
            'SDK does not consume the qualified original Import ABI')
    require(qualification.get('status') == QUALIFIED and qualification.get('phase') == 'COMPLETE'
            and qualification.get('original_framework_build') == 'PASS'
            and qualification.get('external_consumer_build') == 'PASS'
            and qualification.get('native_editor_ui_tests') == 0,
            'Local transport cannot qualify an unfinished framework or award editor UI credit')
    return {'producer_kind': 'local-mac', 'local_execution_sha256': config['local_execution_sha256'],
            'local_receipts': config['local_receipts'], 'native_stageb_qualified': False,
            'scope': 'EXACT_LOCAL_PRODUCER_SOURCE_AND_ABI_PROVENANCE_ONLY'}


def restore_archive(root, config, api, zip_members):
    """Transport exact archived bytes; callers retain their own qualification gates."""
    root = Path(root)
    archive = api['owned_path'](root, config['archive_path'], build=True)
    require(archive.is_file() and archive.stat().st_size == config['archive_bytes']
            and api['digest'](archive) == config['archive_sha256'], 'Local SDK archive bytes differ')
    manifest = api['owned_path'](root, config['distribution_manifest_path'], build=True)
    hanlin = api['owned_path'](root, config['hanlin_source_path'], build=True)
    require(api['digest'](manifest) == config['distribution_manifest_sha256']
            and api['digest'](hanlin) == config['hanlin_source_sha256'], 'Local SDK sidecars differ')
    exported = api['read_json'](manifest)
    expected = dict(exported['files'])
    require(expected and 'QUALIFICATION.json' not in expected, 'Circular local SDK inventory')
    destination = api['owned_path'](root, config['distribution_root'], build=True)
    with zipfile.ZipFile(archive) as zipped:
        members = zip_members(zipped)
        require(set(members) == set(expected) | {'QUALIFICATION.json'}, 'Local SDK ZIP membership differs')
        qualification = members['QUALIFICATION.json']
        require(0 < qualification.file_size <= 16 * 1024 * 1024, 'Oversized local qualification')
        expected['QUALIFICATION.json'] = {'bytes': qualification.file_size, 'sha256': config['qualification_sha256']}
        if destination.exists():
            require(api['inventory'](destination) == expected, 'Existing local SDK distribution differs')
        else:
            destination.mkdir(parents=True)
            for name, item in members.items():
                require(item.file_size == expected[name]['bytes'], 'Local SDK ZIP member size differs')
                target = destination / name
                target.parent.mkdir(parents=True, exist_ok=True)
                with zipped.open(item) as source, target.open('xb') as output:
                    shutil.copyfileobj(source, output)
                require(api['digest'](target) == expected[name]['sha256'], 'Local SDK member digest differs')
                mode = stat.S_IMODE((item.external_attr >> 16) & 0xFFFF) or 0o644
                require(mode & ~0o777 == 0, 'Special local SDK permission bits')
                target.chmod(mode)
            require(api['inventory'](destination) == expected, 'Restored local SDK inventory differs')
    return destination, expected


def restore(root, config, evidence, api, zip_members):
    """Restore an already staged exact local archive using the original ZIP rules."""
    read_receipts(root, config, api)
    evidence = Path(evidence)
    destination, expected = restore_archive(root, config, api, zip_members)
    qualification = api['read_json'](destination / 'QUALIFICATION.json')
    proof = validate_provenance(root, config, qualification, api)
    api['write'](evidence / 'restoration.json', {
        'status': 'EXACT_LOCAL_ORIGINAL_SDK_ARCHIVE_RESTORED', 'producer': proof,
        'files': len(expected), 'source_sha': config['source_sha'], 'run_id': config['run_id'],
        'native_editor_ui_tests': 0, 'overwritten_inputs': 0})
