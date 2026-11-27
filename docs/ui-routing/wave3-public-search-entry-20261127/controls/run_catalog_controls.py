#!/usr/bin/env python3
"""Execute actual retained-catalog policy over explicit original-UI boundary."""
import ast
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import textwrap
import time

SCOPE = Path('/home/ubuntu/.codex/artifacts/otzaria-wave3-profile-group-controls-20261127')
ROOT = Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
CORE = ROOT / '.git/search-continuation-integrated-controls-20261127/output'
BASE = '24cd9291dbc87d799c22a41f0bc73a82c6415bfa'
SWIFT = Path('/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc')
PORTABLE = SCOPE / 'public-search-portable-attempt-1/output'
FLOOR, CAP = 1_342_177_280, 300 * 1024 * 1024


def sha(data): return hashlib.sha256(data).hexdigest()


def pin(path):
    b = path.read_bytes()
    return {'bytes': len(b), 'sha256': sha(b)}


def free():
    s = os.statvfs(SCOPE)
    return s.f_bavail * s.f_frsize


def allocated():
    total, seen = 0, set()
    for parent, dirs, files in os.walk(SCOPE, followlinks=False):
        for name in dirs + files:
            s = (Path(parent) / name).lstat()
            if (s.st_dev, s.st_ino) not in seen:
                total += s.st_blocks * 512
                seen.add((s.st_dev, s.st_ino))
    return total


def proc_identity(pid):
    try:
        raw = Path('/proc', str(pid), 'stat').read_text()
        values = raw[raw.rfind(')') + 2:].split()
        return {'pid': pid, 'parent': int(values[1]), 'group': int(values[2]), 'startTicks': int(values[19])}
    except (FileNotFoundError, ProcessLookupError): return None


def main():
    payload = json.loads(Path(sys.argv[1]).read_text())
    assert re.fullmatch(r'public-search-catalog-attempt-[1-9][0-9]*', payload['attempt'])
    attempt = SCOPE / payload['attempt']
    assert not attempt.exists()
    if free() < FLOOR + 8 * 1024 * 1024 or allocated() > CAP - 16 * 1024 * 1024:
        raise RuntimeError('Owned disk admission refused')
    attempt.mkdir(mode=0o750)
    result = {'base': BASE, 'scope': 'Actual catalog policy, actual Metadata lifecycle, actual one-shot Observation latch; original UI/window/provider explicitly substituted. No Apple/OS/real model/geometry acceptance.',
              'nativeRuns': 0, 'appleSDK': 'NOT_RUN', 'steps': [], 'sourceBindings': [], 'rootfsFloorBytes': FLOOR,
              'ownedCapBytes': CAP, 'started': datetime.datetime.now(datetime.timezone.utc).isoformat()}

    def save(): (attempt / 'RESULT.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')

    # Reuse the already-reviewed exact process-ownership/timeout cleanup body.
    driver = SCOPE / 'public-search-portable-runner-attempt-2.py'
    assert pin(driver)['sha256'] == 'ff27bc9c964c9a86c0869e83f679e105ff773807a73777fc32241f36538c9b0c'
    source = driver.read_text()
    parsed = ast.parse(source)
    outer = next(x for x in parsed.body if isinstance(x, ast.FunctionDef) and x.name == 'main')
    function = next(x for x in outer.body if isinstance(x, ast.FunctionDef) and x.name == 'run')
    run_source = textwrap.dedent(''.join(source.splitlines(keepends=True)[function.lineno - 1:function.end_lineno]))
    environment = dict(globals(), attempt=attempt, result=result, save=save)
    exec(compile(run_source, str(driver) + ':exact-run-body', 'exec'), environment)
    run = environment['run']
    result['runnerBody'] = {'driver': pin(driver), 'segmentSHA256': sha(run_source.encode())}
    try:
        successful = SCOPE / 'public-search-portable-attempt-2/RESULT.json'
        assert pin(successful)['sha256'] == 'ed10f3e1e6324c585d8b545e7f4435b631b4808ab7a44c4baf296071fb4b44df'
        previous = json.loads(successful.read_text())
        assert previous['xctestSummary'] == ['40', '0']
        result['readOnlyProducts'] = {'portableResult': pin(successful), 'artifacts': []}
        for artifact in previous['readOnlyPortableReuse']['artifacts']:
            p = PORTABLE / artifact['path']
            assert pin(p) == {k: artifact[k] for k in ['bytes', 'sha256']}
            result['readOnlyProducts']['artifacts'].append({'path': str(p), **pin(p)})
        for name, expected in [('OtzariaActionCore.swiftmodule', 'c45482e0c872e1378e9048b9f1b9fef473b0a9b8973ef0e17ee9e2df22a24103'),
                               ('libOtzariaActionCore.so', 'f7a7d43d27b341f53a32b5205306c6bcec69c7a05b1f381d6e2239d5803d049a')]:
            assert pin(CORE / name)['sha256'] == expected
            result['readOnlyProducts']['artifacts'].append({'path': str(CORE / name), **pin(CORE / name)})
        inputs, output = attempt / 'inputs', attempt / 'output'
        inputs.mkdir(); output.mkdir()
        for row in payload['files']:
            p = Path(row['path']); assert not p.is_absolute() and '..' not in p.parts
            b = row['text'].encode(); assert len(b) == row['bytes'] and sha(b) == row['sha256']
            path = inputs / p; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(b)
            result['sourceBindings'].append({k: v for k, v in row.items() if k != 'text'})
        obs = inputs / 'NativeComponentSourceObservation.swift'
        original = subprocess.check_output(['git', '-C', str(ROOT), 'show', BASE + ':Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeComponentSourceObservation.swift'])
        assert obs.read_bytes() == original
        result['originalObservationSourceJoin'] = pin(obs)
        catalog = (inputs / 'MaktabahNativeSearchContinuationCatalog.swift').read_text()
        marker = '    /// Read the actual original parent/workspace/window without retaining a\n'
        assert catalog.startswith('#if os(iOS)\n') and catalog.count(marker) == 1
        actual_policy = catalog[len('#if os(iOS)\n'):catalog.index(marker)]
        accessor = '\nextension MaktabahNativeSearchContinuationCatalog {\n    func testOnlySetRevisionAtOverflowBoundary() { revision = UInt64.max }\n}\n'
        policy = actual_policy + '}\n' + accessor
        (inputs / 'ActualCatalogPolicy.swift').write_text(policy)
        metadata_source = (inputs / 'MaktabahNativeSearchContinuation.swift').read_text()
        start = metadata_source.index('    struct MetadataHit {\n')
        end = metadata_source.index('    /// Capture original metadata without inventing an invocation')
        actual_metadata = metadata_source[start:end]
        metadata = ('import Foundation\nimport OtzariaActionCore\nimport ChavrusaUIRoutingHost\n'
                    '@MainActor final class MaktabahNativeSearchContinuationBinding {\n'
                    '    typealias Check = @MainActor () throws -> Void\n' + actual_metadata + '}\n')
        (inputs / 'ActualMetadataLifecycle.swift').write_text(metadata)
        result['exactSegments'] = [
            {'source': 'MaktabahNativeSearchContinuationCatalog.swift', 'bytes': len(actual_policy.encode()), 'sha256': sha(actual_policy.encode()),
             'omitted': 'Only os(iOS) wrapper and app-specific static captureOriginal factory; general policy bodies verbatim', 'testAccessor': accessor},
            {'source': 'MaktabahNativeSearchContinuation.swift', 'bytes': len(actual_metadata.encode()), 'sha256': sha(actual_metadata.encode()),
             'omitted': 'App/UIKit execution and actual-model capture remain outside this source-control harness'}]
        if payload.get('counterfactual') == 'no-observation-invalidation':
            before = obs.read_text(); needle = '            self?.invalidate()'
            assert before.count(needle) == 1
            obs.write_text(before.replace(needle, '            _ = self // counterfactual only: omit original invalidation'))
            result['counterfactual'] = {'kind': payload['counterfactual'], 'original': {'bytes': len(before.encode()), 'sha256': sha(before.encode())},
                                        'changed': pin(obs), 'product': False}
        elif payload.get('counterfactual') == 'no-consumption':
            before = (inputs / 'ActualCatalogPolicy.swift').read_text()
            needle = '              !source.consumed.contains(request.target.reference.metadataID),\n'
            assert before.count(needle) == 1
            (inputs / 'ActualCatalogPolicy.swift').write_text(before.replace(needle, ''))
            result['counterfactual'] = {'kind': payload['counterfactual'], 'original': {'bytes': len(before.encode()), 'sha256': sha(before.encode())},
                                        'changed': pin(inputs / 'ActualCatalogPolicy.swift'), 'product': False}
        tests = (inputs / 'SearchReferenceCatalogControls.swift').read_text()
        methods = re.findall(r'^    @MainActor func (test\w+)\(\) ([^\n{]*)\{', tests, re.M)
        assert len(methods) == 19
        if selected := payload.get('selectedTests'):
            methods = [(name, signature) for name, signature in methods if name in selected]
            assert {x[0] for x in methods} == set(selected)
        entries = []
        for name, signature in methods:
            method = 'SearchReferenceCatalogControls.' + name
            entries.append('(' + json.dumps(name) + ', ' + ('asyncTest(' + method + ')' if 'async' in signature else method) + ')')
        main_file = inputs / 'CatalogMain.swift'
        main_file.write_text('import XCTest\n@main struct CatalogMain { @MainActor static func main() {\nXCTMain([testCase([\n'
                             + ',\n'.join(entries) + '\n])])\n} }\n')
        result['executedTestSelectors'] = [x[0] for x in methods]
        result['compiledFiles'] = [{'path': name, **pin(inputs / name)} for name in
            ['ActualCatalogPolicy.swift', 'ActualMetadataLifecycle.swift', 'NativeComponentSourceObservation.swift', 'SearchReferenceCatalogControls.swift', 'CatalogMain.swift']]
        result['compiler'] = {'path': str(SWIFT), **pin(SWIFT)}
        assert result['compiler']['sha256'] == '39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a'
        executable = output / 'catalog-policy-controls'
        argv = [str(SWIFT), '-swift-version', '6', '-strict-concurrency=complete', '-parse-as-library',
                '-module-cache-path', str(SCOPE / 'module-cache-local'), '-I', str(CORE), '-L', str(CORE), '-lOtzariaActionCore',
                '-Xlinker', '-rpath', '-Xlinker', str(CORE), '-I', str(PORTABLE), '-L', str(PORTABLE),
                '-lOtzariaUIRouting', '-lChavrusaUIRoutingHost', '-Xlinker', '-rpath', '-Xlinker', str(PORTABLE),
                '-module-name', 'SearchReferenceCatalogSourceControls']
        argv += [str(inputs / item['path']) for item in result['compiledFiles']] + ['-o', str(executable)]
        run('compile-actual-catalog-policy', argv, timeout=120)
        run('run-actual-catalog-policy', [str(executable)], timeout=60)
        log = (attempt / 'run-actual-catalog-policy.stdout').read_text()
        summary = re.findall(r'Executed (\d+) tests?, with (\d+) failures?', log)
        result['xctestSummary'] = list(summary[-1]) if summary else None
        assert result['xctestSummary'] == [str(len(methods)), '0']
        result['status'] = 'PASS_ACTUAL_POLICY_EXPLICIT_UI_BOUNDARY'
        result['executable'] = pin(executable)
    except BaseException as error:
        result['status'] = 'FAILED_OR_BLOCKED'; result['errorType'] = type(error).__name__; result['error'] = str(error)
    finally:
        result['finished'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        result['freeFinal'], result['allocatedFinal'] = free(), allocated()
        save()
        print(json.dumps({'path': str(attempt), 'status': result['status'], 'result': pin(attempt / 'RESULT.json'),
                          'xctestSummary': result.get('xctestSummary'), 'error': result.get('error')}))
    return 0 if result['status'].startswith('PASS') else 1


if __name__ == '__main__': sys.exit(main())
