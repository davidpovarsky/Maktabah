#!/usr/bin/env python3
"""Read-only source/receipt/inverse replay; no Swift or Native execution."""
from pathlib import Path
from collections import defaultdict
import ast
import gzip
import hashlib
import io
import json
import re
import runpy
import zipfile

DOCS = Path(__file__).resolve().parent
ROOT = DOCS.parents[2]


def require(value, message):
    if not value: raise ValueError(message)


def js(data): return json.loads(data)


def pin(data):
    return {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
            'git_blob': hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()}


def compressed_json(name):
    return js(gzip.decompress((DOCS / 'raw' / (name + '.gz')).read_bytes()))


def tree_entries(tree):
    require(tree['truncated'] is False, 'Truncated canonical tree')
    entries = {row['path']: row for row in tree['tree']}
    require(len(entries) == len(tree['tree']), 'Duplicate canonical path')
    children = defaultdict(list)
    for path, row in entries.items():
        parent, _, name = path.rpartition('/')
        order = name.encode() + (b'/' if row['type'] == 'tree' else b'')
        mode = '40000' if row['mode'] == '040000' else row['mode']
        children[parent].append((order, mode.encode() + b' ' + name.encode() + b'\0' + bytes.fromhex(row['sha'])))
    expected = {'': tree['sha'], **{path: row['sha'] for path, row in entries.items() if row['type'] == 'tree'}}
    for directory, object_id in expected.items():
        raw = b''.join(item for _, item in sorted(children[directory]))
        require(hashlib.sha1(b'tree ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == object_id,
                'Tree Merkle identity changed: ' + directory)
    return entries


def source_zip(name, expected, entries):
    with zipfile.ZipFile(io.BytesIO((DOCS / 'raw' / name).read_bytes())) as archive:
        require(archive.testzip() is None and len(archive.infolist()) == len(expected), 'Source ZIP CRC/count differs')
        require(set(archive.namelist()) == {row['path'] for row in expected}, 'Source ZIP membership differs')
        result = {path: archive.read(path) for path in archive.namelist()}
    for row in expected:
        actual = pin(result[row['path']]); canonical = entries[row['path']]
        require(actual['git_blob'] == row['sha'] == canonical['sha'] and actual['bytes'] == row['size'] == canonical['size']
                and row['mode'] == canonical['mode'], 'Source ZIP Git identity differs: ' + row['path'])
    return result


def main():
    files = js((DOCS / 'ARTIFACTS.json').read_bytes())['files']
    require(len(files) == len({row['path'] for row in files}), 'Duplicate manifest path')
    for row in files:
        path = ROOT / row['path']
        require(path.is_file() and not path.is_symlink(), 'Missing/linked sealed input')
        require(pin(path.read_bytes()) == {key: row[key] for key in ('bytes', 'sha256', 'git_blob')},
                'Sealed input changed: ' + row['path'])
    canonical = js((DOCS / 'SOURCE_AUTHORITY.json').read_bytes())
    proof = js((DOCS / 'REBIND_PROOF.json').read_bytes())
    commit, m_tree = compressed_json('M_COMMIT.json'), compressed_json('M_TREE.json')
    prior_commit, prior_tree = compressed_json('PRIOR_F_COMMIT.json'), compressed_json('PRIOR_F_TREE.json')
    require(commit['sha'] == canonical['source'] == '1bf1da14c0c3d74bb790331d8df365accac905f9'
            and [row['sha'] for row in commit['parents']] == ['28befd6ef09310eb4becc8ee64e43cba1dc3e00d']
            and commit['tree']['sha'] == m_tree['sha'] == canonical['source_tree'], 'Actual M/parent/tree changed')
    require(prior_commit['sha'] == canonical['prior_f'] == '8bb0ab7e87895a85265132188ede021cef3a08ae'
            and prior_commit['tree']['sha'] == prior_tree['sha'], 'Actual prior F differs')
    entries, prior_entries = tree_entries(m_tree), tree_entries(prior_tree)
    base = source_zip('M_SOURCE_INPUTS.zip', canonical['entries'], entries)
    prior = source_zip('PRIOR_ROUTE_INPUTS.zip', canonical['prior_entries'], prior_entries)
    g = runpy.run_path(str(ROOT / 'Scripts/CI/reader-inspector-focused-native.py'))
    require(g['BASE'] == commit['sha'] and g['TREES'] == canonical['trees']
            and g['TREES'] == {path: entries[path]['sha'] for path in g['TREES']}, 'Protected M trees differ')
    driver = (ROOT / g['SELF']).read_bytes()
    inverse = driver
    for item in reversed(proof['driver_replacements']):
        require(inverse.count(item['after'].encode()) == 1, 'Nonunique driver metadata inverse')
        inverse = inverse.replace(item['after'].encode(), item['before'].encode())
    require(inverse == prior[g['SELF']] and len(proof['driver_replacements']) == 5, 'Whole original v2 driver differs')
    require((ROOT / g['TESTS']).read_bytes() == prior[g['TESTS']], 'Original27 control source changed')
    workflow = (ROOT / g['WORKFLOW']).read_bytes()
    branch = g['REF'].removeprefix('refs/heads/')
    require(workflow.count(branch.encode()) == 1 and workflow.replace(branch.encode(),
            b'codex/otzaria-reader-inspector-focused-native-v2-20261120') ==
            prior['.github/workflows/otzaria-reader-inspector-focused-native-v2.yml'], 'Whole workflow inverse differs')
    require(b'python3 Scripts/CI/sefaria-toc-apple55.py' in workflow and b'timeout-minutes: 360' in workflow
            and b'run: python3 Scripts/CI/runtime27.py' in workflow, 'Original full-app/Apple55 executor changed')
    g['validate_manifest'](js((ROOT / g['MANIFEST']).read_bytes()), js(base[g['MANIFEST']]))
    g['validate_pins'](js((ROOT / g['INPUTS']).read_bytes()), js(base[g['INPUTS']]),
                       (ROOT / g['ADDITIONS']).read_bytes(), base[g['ADDITIONS']],
                       (ROOT / g['RUNTIME']).read_bytes(), base[g['RUNTIME']])
    require(pin(base['Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift'])['sha256'] == g['NEW_R27'],
            'Actual R27 pin differs')
    require(pin(base['Maktabah.xcodeproj/project.pbxproj'])['git_blob'] == g['NEW_PROJECT'], 'Actual project pin differs')
    matrix = base['Scripts/CI/run-faithful-ipad-matrix.py']
    require(b'"-default-test-execution-time-allowance", "600"' in matrix
            and b'"-maximum-test-execution-time-allowance", "600"' in matrix, 'Original600s case bounds changed')
    require(b'["swiftc", "-frontend", "-dump-parse", "-D", "DEBUG", str(source)]' in
            base['Scripts/CI/verify-faithful-xctest.py'], 'Original actual Swift declaration gate changed')
    faithful_path = 'Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift'
    before = b'                return palette.isHittable && input.isHittable && result.isHittable\n'
    after = (b'                // The palette accessibility container groups these original controls.\n'
             b'                // Require the actionable controls to be hittable inside its verified bounds.\n'
             b'                return input.isHittable && result.isHittable\n')
    require(base[faithful_path].count(after) == 1, 'Motion source correction differs')
    faithful_inverse = base[faithful_path].replace(after, before)
    require(pin(faithful_inverse)['git_blob'] == prior_entries[faithful_path]['sha'], 'Other Faithful methods or helper bytes changed')
    require(entries['Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift']['sha'] ==
            prior_entries['Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift']['sha'], 'Original Commentary method changed')
    require(entries['Scripts/CI/runtime27-release-manifest.json']['sha'] ==
            prior_entries['Scripts/CI/runtime27-release-manifest.json']['sha'], 'Original Release114 manifest changed')
    command = compressed_json('controls-COMMAND.json')
    stdout = gzip.decompress((DOCS / 'raw/controls-stdout.log.gz').read_bytes())
    stderr = gzip.decompress((DOCS / 'raw/controls-stderr.log.gz').read_bytes())
    require(command['returncode'] == 0 and command['source_before'] == command['source_after'] and command['source_unchanged'],
            'Actual local control exit/source changed')
    require(pin(stdout)['sha256'] == command['stdout_sha256'] and pin(stderr)['sha256'] == command['stderr_sha256'],
            'Actual local control log changed')
    names = sorted(node.name for node in ast.walk(ast.parse(prior[g['TESTS']]))
                   if isinstance(node, ast.FunctionDef) and node.name.startswith('test_'))
    passed = re.findall(rb'^(test_\w+) \([^\n]+\) \.\.\. ok$', stderr, re.MULTILINE)
    require(len(names) == 27 and sorted(name.decode() for name in passed) == names
            and b'Ran 27 tests' in stderr and stderr.rstrip().endswith(b'OK'), 'Original27 current results differ')
    require(proof['native_executions'] == 0 and proof['actual_Apple_build'] == 'NOT_RUN'
            and proof['full_native116_or_release114_credit'] is False, 'Preparation credit changed')
    print(json.dumps({'status': 'PASS_READONLY_FOCUSED4_V3_BINDING_AND_INVERSES', 'source': g['BASE'],
                      'canonical_M_inputs': len(base), 'prior_route_inputs': len(prior), 'actual_local_controls': 27,
                      'original_native_catalog_rows': 116, 'selected_cases': len(g['SELECTED']),
                      'M_tree_nodes': len(entries), 'prior_F_tree_nodes': len(prior_entries),
                      'new_Swift_or_Native_executed': 0}, sort_keys=True))


if __name__ == '__main__': main()
