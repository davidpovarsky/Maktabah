#!/usr/bin/env python3
import pathlib, subprocess, tempfile, json, hashlib
folder = pathlib.Path(__file__).resolve().parent
root = folder.parents[4]
relative = 'Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift'
base = '29a731e273f9a757c743c49e182fece0e8047d46'
baseline = subprocess.check_output(['git', '-C', str(root), 'show', base + ':' + relative], text=True)
candidate = (root / relative).read_text()
fixture = (folder / 'fixture.swift').read_text()
result = {'scope': 'original read-only history observer on disposable Foundation fixtures; not app or UI acceptance', 'base': base, 'runs': {}}
with tempfile.TemporaryDirectory(prefix='otzaria-history-observer-') as temporary:
    temp = pathlib.Path(temporary)
    for label, source in [('baseline', baseline), ('candidate', candidate)]:
        block = source[source.index('private func matchingTestSidecars('):source.index('/// Runs the supplied prototype')]
        swift = 'import Foundation\n' + block + fixture
        path = temp / (label + '.swift')
        path.write_text(swift)
        binary = temp / label
        compile_result = subprocess.run(['swiftc', '-swift-version', '6', '-module-cache-path', str(temp / 'module-cache'), str(path), '-o', str(binary)], capture_output=True, text=True)
        (folder / (label + '-compile.log')).write_text(compile_result.stdout + compile_result.stderr)
        assert compile_result.returncode == 0, compile_result.stderr
        run = subprocess.run([str(binary)], capture_output=True, text=True)
        (folder / (label + '-run.log')).write_text(run.stdout + run.stderr)
        result['runs'][label] = {'compileExit': compile_result.returncode, 'runExit': run.returncode, 'sourceSHA256': hashlib.sha256(source.encode()).hexdigest(), 'extractedBlockSHA256': hashlib.sha256(block.encode()).hexdigest(), 'passed': run.stdout.count('PASS '), 'failed': run.stdout.count('FAIL ')}
        if label == 'baseline':
            assert run.returncode == 1 and 'FAIL valid preferences above former 1 MiB cap' in run.stdout
        else:
            assert run.returncode == 0, run.stdout + run.stderr
(folder / 'RESULT.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
