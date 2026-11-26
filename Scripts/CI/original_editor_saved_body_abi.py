"""Reverify the reviewed saved-body continuation on its actual original Mac."""

import hashlib
import json
from pathlib import Path
import socket
import subprocess
import sys

SCHEMA = 'otzaria.original-saved-body-retained-abi/1'
BRANCH = 'codex/anytype-original-miniapps-facade-20261125'
SOURCE = '75a98ba98d6455eefc2c98113fa744b0f3c2e7bf'
SOURCE_TREE = '7fdea6131187fefd979d0eb1d2f094c3a4f87449'
EXECUTION_SHA256 = '2faaf4ee4b4c503048061932555911c564011c9efe49e96524d01e36e352d06e'
SOURCE_OBSERVATION_SHA256 = '80522628253e9d7fdf82c15c70cbc7b1d64a2eaedd31c04f43313040ddf6c2c3'
ABI_SHA256 = '36968bdc4dd8340908af203f6f8c377fe9b4a00c0aaba6ccc23329b5385f01b3'
DONOR_SOURCE = 'e973cc7432419778f0342624a3b7052055fd270d'
DONOR_ABI_SHA256 = 'f8c7cf6013d25adade460a2084ae2c7460d3dc968b1327ccebd17204856c1e67'
NATIVE_TREE = '94805c1b5ac644d3ef4e12f554b9326d54286aeb'
VERIFIER_SOURCES = {
    'Tools/OriginalEditor/import_abi_input.py':
        'b5d7dd5be1bc23de1b43cb82770d45cb260501c07c777d7e460e4174c5281aef',
    'Tools/OriginalEditor/saved_body_abi_input.py':
        '1981f92ecb26dc3670c6f4e1dc3e96bc1923aecf5b02f8a09cdc705e8ab30c20',
}


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


def validate_identity(source, native_tree, reference, reference_digest, before, execution):
    require(source == SOURCE and native_tree == NATIVE_TREE and reference_digest == ABI_SHA256,
            'Unknown saved-body ABI continuation, native tree or receipt')
    require(execution.get('schema') == 'otzaria.original-editor.local-execution/1'
            and execution.get('repository') == 'davidpovarsky/anytype-swift'
            and execution.get('head_branch') == BRANCH and execution.get('source_sha') == SOURCE
            and execution.get('source_tree') == SOURCE_TREE
            and execution.get('acceptance') == 'PROVENANCE_ONLY_NOT_ACCEPTANCE'
            and execution.get('host', {}).get('system') == 'Darwin'
            and execution['host'].get('architecture') == 'arm64'
            and before.get('head_sha') == SOURCE,
            'Saved-body ABI has a different exact original producer')
    identity = before.get('execution_identity', {})
    require(identity.get('local_execution') == execution
            and identity.get('local_execution_sha256') == EXECUTION_SHA256
            and identity.get('run_id') == execution.get('execution_id')
            and identity.get('source_sha') == SOURCE and identity.get('producer_kind') == 'local-mac',
            'Saved-body ABI execution does not match the source observation')
    require(set(reference) == {'schema', 'consumer_source_sha', 'consumer_execution_sha256',
                               'donor_source_sha', 'donor_abi_sha256', 'donor_root'}
            and reference.get('schema') == SCHEMA
            and reference.get('consumer_source_sha') == SOURCE
            and reference.get('consumer_execution_sha256') == EXECUTION_SHA256
            and reference.get('donor_source_sha') == DONOR_SOURCE
            and reference.get('donor_abi_sha256') == DONOR_ABI_SHA256,
            'Saved-body ABI receipt changed its consumer or original ABI producer')


def validate(source, native_tree, reference, reference_digest, before, execution, heart):
    validate_identity(source, native_tree, reference, reference_digest, before, execution)
    require(sys.platform == 'darwin' and socket.gethostname() == execution['host'].get('hostname'),
            'Saved-body ABI must be reverified on its actual original Mac')
    root = Path(execution['root'])
    evidence = Path(execution['evidence_root'])
    require(root.is_absolute() and root.resolve(strict=True) == root
            and evidence.resolve(strict=True) == evidence and evidence.is_relative_to(root / 'build'),
            'Saved-body ABI owner paths are not canonical')
    files = {'local-execution.json': (EXECUTION_SHA256, execution),
             'source-before.json': (SOURCE_OBSERVATION_SHA256, before),
             'RETAINED_ABI_INPUT.json': (ABI_SHA256, reference)}
    for name, (expected, value) in files.items():
        path = evidence / name
        require(path.resolve(strict=True) == path and path.is_file()
                and digest(path) == expected and json.loads(path.read_bytes()) == value,
                'The actual saved-body producer receipt differs: ' + name)
    def git(*arguments):
        return subprocess.check_output(['git', '-C', str(root), *arguments], timeout=60)
    require(git('rev-parse', 'HEAD').decode().strip() == SOURCE
            and git('rev-parse', 'HEAD^{tree}').decode().strip() == SOURCE_TREE
            and not git('diff', '--name-only', 'HEAD')
            and not git('ls-files', '--others', '--exclude-standard', '--', 'Tools/OriginalEditor'),
            'The actual reviewed saved-body verifier checkout differs')
    for name, expected in VERIFIER_SOURCES.items():
        path = root / name
        require(path.resolve(strict=True) == path and digest(path) == expected
                and hashlib.sha256(git('show', f'HEAD:{name}')).hexdigest() == expected
                and before.get('source_inputs', {}).get(name, {}).get('sha256') == expected,
                'Saved-body verifier code differs: ' + name)
    invoke = (
        'import json,sys;from pathlib import Path;'
        'root=Path(sys.argv[1]);p=Path(sys.argv[2]);'
        "sys.path.insert(0,str(root/'Tools/OriginalEditor'));"
        'from import_abi_input import verify;'
        "before=json.loads((p/'source-before.json').read_bytes());"
        "print(json.dumps(verify(root,p/'RETAINED_ABI_INPUT.json',sys.argv[3],before)))"
    )
    observed = json.loads(subprocess.check_output(
        [sys.executable, '-I', '-B', '-c', invoke, str(root), str(evidence), ABI_SHA256],
        cwd=root, timeout=600))
    require(observed == heart and observed.get('schema') == SCHEMA
            and observed.get('status') == 'PASS' and observed.get('receipt_sha256') == ABI_SHA256
            and observed.get('retained_abi_source_sha') == DONOR_SOURCE
            and observed.get('retained_abi_receipt_sha256') == DONOR_ABI_SHA256
            and observed.get('native_qualification', {}).get('native_source_tree') == NATIVE_TREE,
            'The original saved-body verifier returned a different ABI qualification')
    return {'schema': SCHEMA, 'source_sha': SOURCE, 'native_source_tree': NATIVE_TREE,
            'retained_abi_source_sha': DONOR_SOURCE, 'retained_abi_receipt_sha256': DONOR_ABI_SHA256,
            'new_sdk_or_ui_credit': False}
