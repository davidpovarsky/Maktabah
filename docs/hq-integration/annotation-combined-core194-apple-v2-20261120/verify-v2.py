#!/usr/bin/env python3
"""Read-only v2 delta and authentic failed Mac evidence; no tests or execution."""
from pathlib import Path
import ast
import gzip
import hashlib
import io
import json
import runpy
import tarfile
import zipfile

DOCS = Path(__file__).resolve().parent
ROOT = DOCS.parents[2]


def require(value, message):
    if not value: raise ValueError(message)


def js(data):
    return json.loads(data)


def pin(data):
    return {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
            'git_blob': hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()}


def api_json(data):
    result = js(data)
    if isinstance(result.get('structuredContent', {}).get('content'), str):
        return js(result['structuredContent']['content'])
    return result


def tests(data):
    return sorted(node.name for node in ast.walk(ast.parse(data))
                  if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name.startswith('test_'))


def main():
    # The complete unchanged source/Merkle/original-validator verifier runs
    # first. Its scope remains source and receipt verification, not execution.
    runpy.run_path(str(DOCS / 'verify-prepared-base.py'), run_name='__main__')
    proof = js((DOCS / 'V2_INVERSE_PROOF.json').read_bytes())
    failure = js((DOCS / 'PRIOR_COMPONENT_FAILURE.json').read_bytes())
    raw = (DOCS / 'raw/ORIGINAL_COMPONENT_ARTIFACT.zip').read_bytes()
    require(pin(raw)['bytes'] == 2133690 and pin(raw)['sha256'] ==
            '92ef4039475120edb20b4e5d6d09ad23f2aa59e9c5ac7f6a5fe24cfeffd7bf07', 'Prior full artifact differs')
    metadata = api_json(gzip.decompress((DOCS / 'raw/prior-ARTIFACTS.json.gz').read_bytes()))
    artifact = next(row for row in metadata['artifacts'] if row['id'] == 14671777929)
    require(artifact['size_in_bytes'] == len(raw) and artifact['digest'] == 'sha256:' + pin(raw)['sha256']
            and artifact['workflow_run']['id'] == 44821378113
            and artifact['workflow_run']['head_sha'] == 'b511249f5a75337b328325e8c5e83c2b78030a7a', 'Prior API identity differs')
    commit = js(gzip.decompress((DOCS / 'raw/PRIOR_F_COMMIT.json.gz').read_bytes()))
    tree = js(gzip.decompress((DOCS / 'raw/PRIOR_F_TREE.json.gz').read_bytes()))
    require(commit['sha'] == artifact['workflow_run']['head_sha'] and tree['sha'] == commit['tree']['sha']
            and tree['truncated'] is False and [row['sha'] for row in commit['parents']] ==
            ['bd855c02fcef94a732f584c5992aeacec6b1b21d'], 'Prior exact F tree/parent differs')
    entries = {row['path']: row for row in tree['tree']}
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        require(len(archive.infolist()) == 9 and archive.testzip() is None, 'Prior artifact CRC/count differs')
        before = js(archive.read('RESULT_BEFORE.json'))
        after = js(archive.read('RESULT_AFTER.json'))
        observed = before['source']['files']
        require(before['source'] == after['source'] and len(observed) == 118, 'Prior source before/after differs')
        require(after['status'] == 'FAILED' and after['outcomes'] == {
            'toolchain': 'success', 'controls': 'failure', 'core': 'skipped', 'local': 'skipped',
            'exchange': 'skipped', 'race': 'skipped'}, 'Prior failure/gate outcomes changed')
        require(before['source']['identity']['head_sha'] == commit['sha']
                and before['source']['identity']['run_id'] == 44821378113
                and before['source']['identity']['run_attempt'] == 1, 'Prior receipt run identity differs')
        controls = js(archive.read('python-controls/RESULT.json'))
        require(controls['executed'] == 40 and controls['failures'] == 1 and controls['errors'] == controls['skips'] == 0,
                'Actual Mac controls changed')
        failed = [row['name'] for row in controls['cases'] if row['status'] != 'PASS']
        require(failed == ['test_main_produced_uppercase_receipts_are_read_by_actual_aggregate_consumer'], 'Different failure')
        require(sum(row['status'] == 'PASS' for row in controls['cases']) == 39, 'Mac39 passes changed')
        sources = []
        for name in ('source-before.tar.gz', 'source-after.tar.gz'):
            with tarfile.open(fileobj=io.BytesIO(archive.read(name)), mode='r:gz') as source:
                members = source.getmembers()
                require(len(members) == 119 and all(row.isfile() for row in members), 'Prior source archive shape differs')
                content = {row.name: source.extractfile(row).read() for row in members}
                require(len(content) == 119 and set(content) == set(observed) | {'original-baseline/AnnotationRepository.swift'},
                        'Prior source archive membership differs')
                require(pin(content['original-baseline/AnnotationRepository.swift']) == before['source']['original_repository'],
                        'Original baseline Repository bytes differ')
                for path, expected in observed.items():
                    require(pin(content[path]) == expected and expected['git_blob'] == entries[path]['sha']
                            and len(content[path]) == entries[path]['size'], 'Prior compiled input differs: ' + path)
                sources.append(content)
        require(sources[0] == sources[1], 'Prior exact source copies changed across Mac run')
        prior = sources[0]
    for path, change in proof['changes'].items():
        current = (ROOT / path).read_bytes()
        require(pin(current) == change['after'] and pin(prior[path]) == change['before'], 'Delta pin differs')
        inverse = current
        for edit in reversed(change['edits']):
            require(inverse.count(edit['after'].encode()) == 1, 'Nonunique narrow inverse')
            inverse = inverse.replace(edit['after'].encode(), edit['before'].encode(), 1)
        require(inverse == prior[path], 'Whole driver/test inverse differs')
    test_path = 'Scripts/CI/test-annotation-combined-core194-apple.py'
    require(tests(prior[test_path]) == tests((ROOT / test_path).read_bytes()) == proof['original_control_ids']
            and len(tests(prior[test_path])) == 40, 'Original40 IDs changed')
    workflow = (ROOT / proof['workflow']).read_bytes()
    for edit in reversed(proof['workflow_replacements']):
        require(workflow.count(edit['after'].encode()) == edit['count'], 'Workflow pin occurrence differs')
        workflow = workflow.replace(edit['after'].encode(), edit['before'].encode())
    require(workflow == prior['.github/workflows/otzaria-annotation-core194-combined-apple.yml'], 'Original workflow body changed')
    outcome = js(gzip.decompress((DOCS / 'raw/current-RESULT.json.gz').read_bytes()))
    command = js(gzip.decompress((DOCS / 'raw/current-COMMAND.json.gz').read_bytes()))
    require(outcome['status'] == 'PASS_PYTHON_ROUTE_CONTROLS' and outcome['executed'] == 40
            and all(outcome[key] == 0 for key in ('failures', 'errors', 'skips', 'Swift_executed', 'Native_executed'))
            and outcome['names'] == proof['original_control_ids'], 'Current40 local result differs')
    require(command['returncode'] == 0 and command['source_before'] == command['source_after'] and command['source_unchanged'],
            'Current control sources changed')
    require(failure['actual_Mac_controls'] == {'executed': 40, 'passed': 39, 'failures': 1, 'errors': 0, 'skips': 0}
            and failure['component_Swift_execution'] == 'NOT_RUN', 'Failure scope differs')
    print(json.dumps({'status': 'PASS_READONLY_V2_DELTA_AND_ACTUAL_FAILED_MAC_EVIDENCE',
                      'prior_zip_crc_members': 9, 'prior_exact_Git_inputs': 118, 'prior_source_tar_members_each': 119,
                      'prior_Mac_passed': 39, 'prior_Mac_failed': 1, 'current_local_controls': 40,
                      'new_Swift_or_Native_executed': 0}, sort_keys=True))


if __name__ == '__main__': main()
