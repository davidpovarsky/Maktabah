#!/usr/bin/env python3
"""Bounded original-source controls; never an app/native/provider runner."""
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
import time

SCOPE = Path('/home/ubuntu/.codex/artifacts/otzaria-wave3-profile-group-controls-20261127')
ROOT = Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
CORE = ROOT / '.git/search-continuation-integrated-controls-20261127'
BASE = '24cd9291dbc87d799c22a41f0bc73a82c6415bfa'
SWIFT = Path('/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc')
FLOOR = 1_342_177_280
CAP = 300 * 1024 * 1024
EXPECTED_MODULE = 'c45482e0c872e1378e9048b9f1b9fef473b0a9b8973ef0e17ee9e2df22a24103'
EXPECTED_LIBRARY = 'f7a7d43d27b341f53a32b5205306c6bcec69c7a05b1f381d6e2239d5803d049a'
EXPECTED_CORE_RESULT = 'adade63bed54c1b527e41d0d68f81ac652c6916d878235d82081c20f0f942d96'


def sha(data):
    return hashlib.sha256(data).hexdigest()


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
            p = Path(parent) / name
            s = p.lstat()
            if (s.st_dev, s.st_ino) not in seen:
                total += s.st_blocks * 512
                seen.add((s.st_dev, s.st_ino))
    return total


def git_blob(path):
    return subprocess.run(['git', '-C', str(ROOT), 'show', BASE + ':' + path],
                          capture_output=True, check=True).stdout


def proc_identity(pid):
    try:
        raw = Path('/proc', str(pid), 'stat').read_text()
        values = raw[raw.rfind(')') + 2:].split()
        return {'pid': pid, 'parent': int(values[1]), 'group': int(values[2]), 'startTicks': int(values[19])}
    except (FileNotFoundError, ProcessLookupError):
        return None


def main():
    payload = json.loads(Path(sys.argv[1]).read_text())
    name = payload['attempt']
    assert re.fullmatch(r'public-search-portable-attempt-[1-9][0-9]*', name)
    attempt = SCOPE / name
    if attempt.exists():
        raise RuntimeError('Immutable attempt already exists')
    if free() < FLOOR + 8 * 1024 * 1024 or allocated() > CAP - 16 * 1024 * 1024:
        raise RuntimeError('Owned budget/floor not available before materialization')
    attempt.mkdir(mode=0o750)
    result = {'scope': 'Actual Core module + actual candidate UIRouting/Host sources; explicit synthetic native callbacks. No Apple/native/provider execution.',
              'base': BASE, 'steps': [], 'nativeRuns': 0, 'appleSDK': 'NOT_RUN',
              'sourceBindings': [], 'coreSourceJoins': [], 'rootfsFloorBytes': FLOOR, 'ownedCapBytes': CAP}

    def save():
        (attempt / 'RESULT.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')

    def run(name, argv, timeout=120, env=None):
        if free() < FLOOR + 4 * 1024 * 1024 or allocated() >= CAP:
            raise RuntimeError('Owned budget/floor before ' + name)
        step = {'name': name, 'argv': [str(x) for x in argv], 'startAttempted': False,
                'freeBefore': free(), 'allocatedBefore': allocated(),
                'started': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        result['steps'].append(step)
        save()
        process = None
        try:
            with (attempt / (name + '.stdout')).open('wb') as stdout, (attempt / (name + '.stderr')).open('wb') as stderr:
                step['startAttempted'] = True
                save()
                process = subprocess.Popen(step['argv'], stdout=stdout, stderr=stderr,
                                           start_new_session=True, env=env)
                owner = proc_identity(process.pid)
                step['owner'] = owner
                save()
                until = time.monotonic() + timeout
                while process.poll() is None:
                    cause = ('timeout' if time.monotonic() >= until else
                             'rootfs_floor' if free() < FLOOR else
                             'owned_cap' if allocated() >= CAP else None)
                    if cause:
                        step['interruption'] = cause
                        live = proc_identity(process.pid)
                        if owner is None or live != owner or live['group'] != process.pid:
                            step['cleanup'] = 'UNCERTAIN_OWNERSHIP_NO_SIGNAL'
                            save()
                            raise RuntimeError('Cannot prove exact live process group')
                        os.killpg(process.pid, signal.SIGTERM)
                        try:
                            process.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            if proc_identity(process.pid) != owner:
                                step['cleanup'] = 'UNCERTAIN_OWNERSHIP_NO_ESCALATION'
                                save()
                                raise RuntimeError('Cannot prove escalation owner')
                            os.killpg(process.pid, signal.SIGKILL)
                            process.wait(timeout=5)
                        step['cleanup'] = 'EXACT_OWNED_GROUP_STOPPED_AND_REAPED'
                        break
                    time.sleep(0.2)
                step['exit'] = process.wait()
        finally:
            if process is not None and process.poll() is None:
                live = proc_identity(process.pid)
                if live is not None and live == step.get('owner') and live['group'] == process.pid:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        if proc_identity(process.pid) == step.get('owner'):
                            os.killpg(process.pid, signal.SIGKILL)
                            process.wait(timeout=5)
                        else:
                            step['cleanup'] = 'UNCERTAIN_OWNERSHIP_NO_ESCALATION'
                else:
                    step['cleanup'] = 'UNCERTAIN_OWNERSHIP_NO_SIGNAL'
            step['finished'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
            step['freeAfter'], step['allocatedAfter'] = free(), allocated()
            step['logs'] = {suffix: pin(attempt / (name + '.' + suffix)) for suffix in ['stdout', 'stderr']
                            if (attempt / (name + '.' + suffix)).exists()}
            save()
        if step.get('exit') != 0:
            raise RuntimeError(name + ' exited ' + str(step.get('exit')))

    try:
        assert pin(CORE / 'RESULT.json')['sha256'] == EXPECTED_CORE_RESULT
        assert pin(CORE / 'output/OtzariaActionCore.swiftmodule')['sha256'] == EXPECTED_MODULE
        assert pin(CORE / 'output/libOtzariaActionCore.so')['sha256'] == EXPECTED_LIBRARY
        source_root = CORE / 'inputs/Source/Otzaria/Actions/Sources/OtzariaActionCore'
        for p in sorted(source_root.rglob('*.swift')):
            rel = p.relative_to(CORE / 'inputs').as_posix()
            b = p.read_bytes()
            assert b == git_blob(rel)
            result['coreSourceJoins'].append({'path': rel, **pin(p)})
        assert len(result['coreSourceJoins']) == 31
        result['reusedCore'] = {'result': pin(CORE / 'RESULT.json'),
            'module': pin(CORE / 'output/OtzariaActionCore.swiftmodule'),
            'library': pin(CORE / 'output/libOtzariaActionCore.so'),
            'resourceAccessor': pin(CORE / 'inputs/original-generated-resource_bundle_accessor.swift'),
            'additionalSource': 'Original generated resource bundle accessor only; no altered Core bodies/test authority entry.'}
        result['compiler'] = {'path': str(SWIFT), **pin(SWIFT)}
        assert result['compiler']['sha256'] == '39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a'
        inputs, output = attempt / 'inputs', attempt / 'output'
        inputs.mkdir(); output.mkdir()
        for value in payload['files']:
            rel = Path(value['path'])
            assert not rel.is_absolute() and '..' not in rel.parts
            b = value['text'].encode()
            assert len(b) == value['bytes'] and sha(b) == value['sha256']
            p = inputs / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(b)
            result['sourceBindings'].append({k: v for k, v in value.items() if k != 'text'})
        # Original generated Core accessor finds the genuine resource bundle
        # beside the new executable. Copy only these small verified resources.
        bundle = output / 'OtzariaActionCore_OtzariaActionCore.bundle'
        shutil.copytree(CORE / 'output/OtzariaActionCore_OtzariaActionCore.bundle', bundle)
        result['coreResources'] = []
        for p in sorted(bundle.rglob('*')):
            if p.is_file():
                rel = p.relative_to(bundle).as_posix()
                original = CORE / 'output/OtzariaActionCore_OtzariaActionCore.bundle' / rel
                assert p.read_bytes() == original.read_bytes()
                result['coreResources'].append({'path': rel, **pin(p)})
        fixture_bundle = output / 'OtzariaUIRouting_OtzariaUIRoutingTests.bundle/Fixtures'
        fixture_bundle.mkdir(parents=True)
        fixtures = inputs / 'Source/Otzaria/UIRouting/Tests/OtzariaUIRoutingTests/Contracts/Fixtures'
        for p in fixtures.iterdir():
            shutil.copy2(p, fixture_bundle / p.name)
        accessor = inputs / 'GeneratedTestResourceAccessor.swift'
        accessor.write_text('import Foundation\nextension Bundle { static let module = Bundle(path: '
                            + json.dumps(str(fixture_bundle.parent)) + ')! }\n')
        result['generatedTestResourceAccessor'] = pin(accessor)
        core_out = CORE / 'output'
        common = [str(SWIFT), '-swift-version', '6', '-strict-concurrency=complete', '-parse-as-library',
                  '-module-cache-path', str(SCOPE / 'module-cache-local')]
        links = ['-I', str(core_out), '-L', str(core_out), '-lOtzariaActionCore',
                 '-Xlinker', '-rpath', '-Xlinker', str(core_out)]
        ui = inputs / 'Source/Otzaria/UIRouting/Sources/OtzariaUIRouting'
        host = inputs / 'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost'
        portable_output = output
        if previous_name := payload.get('reusePortableFrom'):
            assert re.fullmatch(r'public-search-portable-attempt-[1-9][0-9]*', previous_name)
            previous = SCOPE / previous_name
            prior_result = json.loads((previous / 'RESULT.json').read_text())
            for phase in ['compile-actual-uirouting', 'compile-actual-host-service']:
                assert any(step['name'] == phase and step.get('exit') == 0 for step in prior_result['steps'])
            joins = []
            for directory in [ui, host]:
                for p in sorted(directory.rglob('*.swift')):
                    rel = p.relative_to(inputs)
                    old = previous / 'inputs' / rel
                    assert p.read_bytes() == old.read_bytes()
                    joins.append({'path': rel.as_posix(), **pin(p)})
            portable_output = previous / 'output'
            artifacts = [{'path': p.name, **pin(p)} for p in sorted(portable_output.iterdir())
                         if p.is_file() and (p.name.startswith('OtzariaUIRouting.')
                            or p.name.startswith('ChavrusaUIRoutingHost.') or p.name.endswith('.so'))]
            assert (portable_output / 'libOtzariaUIRouting.so').is_file()
            assert (portable_output / 'libChavrusaUIRoutingHost.so').is_file()
            result['readOnlyPortableReuse'] = {'attempt': previous_name, 'result': pin(previous / 'RESULT.json'),
                                             'exactSourceJoins': joins, 'artifacts': artifacts}
        else:
            run('compile-actual-uirouting', common + links + ['-emit-module', '-emit-library', '-enable-testing',
                '-module-name', 'OtzariaUIRouting', '-emit-module-path', str(output / 'OtzariaUIRouting.swiftmodule'),
                '-o', str(output / 'libOtzariaUIRouting.so')] + [str(p) for p in sorted(ui.rglob('*.swift'))])
            run('compile-actual-host-service', common + links + ['-I', str(output), '-L', str(output), '-lOtzariaUIRouting',
                '-Xlinker', '-rpath', '-Xlinker', str(output), '-emit-module', '-emit-library', '-enable-testing',
                '-module-name', 'ChavrusaUIRoutingHost', '-emit-module-path', str(output / 'ChavrusaUIRoutingHost.swiftmodule'),
                '-o', str(output / 'libChavrusaUIRoutingHost.so')] + [str(p) for p in sorted(host.glob('*.swift'))])
        test_paths = [inputs / p for p in payload['testFiles']]
        main_file = inputs / 'PortableXCTestMain.swift'
        groups = []
        result['executedTestSelectors'] = []
        for item in payload['testClasses']:
            text = (inputs / item['path']).read_text()
            methods = re.findall(r'^    (?:@MainActor )?func (test\w+)\(\) ([^\n{]*)\{', text, re.M)
            entries = []
            for name, signature in methods:
                method = item['class'] + '.' + name
                reference = ('asyncTest(' + method + ')') if 'async' in signature else method
                entries.append('(' + json.dumps(name) + ', ' + reference + ')')
                result['executedTestSelectors'].append(method)
            assert methods
            groups.append('testCase([' + ',\n'.join(entries) + '])')
        main_file.write_text('import XCTest\n@main struct PortableXCTestMain { @MainActor static func main() {\nXCTMain([\n'
                             + ',\n'.join(groups) + '\n])\n} }\n')
        result['generatedXCTestMain'] = pin(main_file)
        executable = output / 'public-search-reference-tests'
        run('compile-actual-selected-tests', common + links + ['-I', str(portable_output), '-L', str(portable_output),
            '-lOtzariaUIRouting', '-lChavrusaUIRoutingHost', '-Xlinker', '-rpath', '-Xlinker', str(portable_output),
            '-module-name', 'PublicSearchContinuationControls'] + [str(p) for p in test_paths]
            + [str(accessor), str(main_file), '-o', str(executable)])
        run('run-actual-selected-tests', [str(executable)], timeout=60)
        log = (attempt / 'run-actual-selected-tests.stdout').read_text()
        summaries = re.findall(r'Executed (\d+) tests?, with (\d+) failures?', log)
        result['xctestSummary'] = summaries[-1] if summaries else None
        assert result['xctestSummary'] == [str(len(result['executedTestSelectors'])), '0'] or result['xctestSummary'] == (str(len(result['executedTestSelectors'])), '0')
        result['status'] = 'PASS_ACTUAL_PORTABLE_SOURCES_NOT_NATIVE'
        result['outputFiles'] = [{'path': p.relative_to(attempt).as_posix(), **pin(p)}
                                 for p in sorted(output.iterdir()) if p.is_file()]
    except BaseException as error:
        result['status'] = 'FAILED_OR_BLOCKED'
        result['errorType'] = type(error).__name__
        result['error'] = str(error)
    finally:
        result['finished'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        result['freeFinal'], result['allocatedFinal'] = free(), allocated()
        save()
        print(json.dumps({'path': str(attempt), 'status': result['status'], 'result': pin(attempt / 'RESULT.json'),
                          'xctestSummary': result.get('xctestSummary'), 'error': result.get('error')}))
    return 0 if result['status'].startswith('PASS') else 1


if __name__ == '__main__':
    sys.exit(main())
