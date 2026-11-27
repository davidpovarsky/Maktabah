#!/usr/bin/env python3
"""Exact-source standalone Swift controls; never app/SDK/native qualification."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def sha(data):
    return hashlib.sha256(data).hexdigest()


def replace_once(source, before, after):
    assert source.count(before) == 1, before
    return source.replace(before, after)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source-root', type=Path, required=True)
    parser.add_argument('--shared-proposal', type=Path, required=True)
    parser.add_argument('--shared-baseline', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--module-cache', type=Path, required=True)
    args = parser.parse_args()
    root, shared, out = args.source_root.resolve(), args.shared_proposal.resolve(), args.output.resolve()
    assert not out.exists(), 'Preserve every previous attempt'
    assert shutil.disk_usage(root).free >= 687865856 + 300000000, 'Original source-control reserve'
    out.mkdir(parents=True)
    sources = {
        'bridge': root / 'Source/SefariaEmbedded/Bridge/SefariaJSRPCBridge.swift',
        'models': root / 'Source/SefariaEmbedded/Bridge/SefariaRPCModels.swift',
        'contract': root / 'Source/SefariaEmbedded/UI/SefariaEmbeddedSurfaceContract.swift',
        'semantic': root / 'Source/SefariaEmbedded/UI/SefariaEmbeddedSemanticNavigation.swift',
        'observation': shared / 'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeComponentSourceObservation.swift',
        'rootPublication': shared / 'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSearchEntry.swift',
        'windowSource': shared / 'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift',
        'windowObservation': args.shared_baseline / 'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWindowObservation.swift',
        'originalManager': shared / 'Source/UI/iOS/Managers/iOSNavigationManager.swift',
        'controls': root / 'tools/test_sefaria_semantic_handoff.swift',
        'runner': Path(__file__).resolve(),
    }
    texts = {name: path.read_text() for name, path in sources.items()}
    rows = [{'name': name, 'path': str(path), 'bytes': len(path.read_bytes()), 'sha256': sha(path.read_bytes())}
            for name, path in sources.items()]
    # Retain actual complete source inputs before compiling the exact selected
    # types. No production method is rewritten to satisfy the control boundary.
    captured = out / 'source-inputs'; captured.mkdir()
    for name, path in sources.items():
        (captured / (name + path.suffix)).write_bytes(path.read_bytes())
    bridge = texts['bridge'][:texts['bridge'].index('actor SefariaJSRPCBridge {')]
    models = texts['models']
    error = models[models.index('struct SefariaRPCError:'):models.index('\nstruct SefariaRPCEvent:')]
    observation = replace_once(texts['observation'], 'import OtzariaUIRouting\n', '')
    semantic = replace_once(texts['semantic'], 'import ChavrusaUIRoutingHost\n', '')
    root_publication = texts['rootPublication']
    root_publication = root_publication[root_publication.index('@MainActor\nfinal class MaktabahNativeRootPublicationSource'):root_publication.index('/// Expected publications')]
    window_source = texts['windowSource']
    window_source = window_source[window_source.index('@MainActor final class MaktabahNativeWindowSource'):window_source.index('/// The RN sheet may cover')]
    window_observation = texts['windowObservation']
    window_observation = window_observation[window_observation.index('@MainActor\nfinal class MaktabahNativeWindowObservation'):window_observation.index('\n#endif')]
    mode_source = texts['originalManager']
    mode_source = mode_source[mode_source.index('    @ObservationIgnored let nativeModePresentationPublication'):mode_source.index('    var selectedBook:')]
    mode_source = '@MainActor @Observable final class SemanticOriginalMode {\n' + mode_source + '\n}\n'
    session_source = texts['windowSource']
    attachment = session_source[session_source.index('    func attachWindowSource('):session_source.index('    func retainOriginalWindowObservation(')]
    attachment = '@MainActor final class SemanticWindowSession {\n    var mounted = true\n    var windowSource: MaktabahNativeWindowSource?\n    var windowSourceRevision: UInt64? = 0\n    var sefariaRootSources: [UUID: NativeComponentSourceObservation] = [:]\n    var completedSefariaRootSource: NativeComponentSourceObservation?\n' + attachment + '\n}\n'
    # SwiftUI Binding storage/Transaction and iOSTab are explicit platform/domain
    # boundaries. Both original wrapper bodies and the exact original counter
    # function above are compiled verbatim, including original transaction use.
    root_boundary = '''
enum iOSTab { case library, search }
struct Transaction {}
@MainActor struct Binding<Value> {
    private let get: @MainActor () -> Value
    private let set: @MainActor (Value, Transaction) -> Void
    init(get: @escaping @MainActor () -> Value, set: @escaping @MainActor (Value, Transaction) -> Void) {
        self.get = get; self.set = set
    }
    var wrappedValue: Value { get { get() } nonmutating set { set(newValue, Transaction()) } }
    func transaction(_ transaction: Transaction) -> Self { self }
}
@MainActor private final class SemanticOriginalTab { var value = iOSTab.library }
extension MaktabahNativeRootPublicationSource {
    // Test-only reachability of UInt64.max before capture; production initializer
    // and the two original wrapper/counter bodies are not changed.
    fileprivate func seedMaximumRevisionForControl() { selectionRevision = .max }
}
extension MaktabahNativeWindowSource {
    fileprivate var controlOriginalRevision: UInt64? { observationRevision }
}
extension NativeComponentSourcePublication {
    fileprivate var controlRetainedCount: Int { retained.count }
}
@MainActor private final class SemanticWrites { var count = 0; var reentered = false }
enum AppMode: Int { case viewer, search }
struct UIStableID { let rawValue: String }
@MainActor class UIView { weak var window: UIWindow? }
@MainActor final class UIWindow: UIView {
    var isKeyWindow = true; var isHidden = false; var alpha: Double = 1
    var windowScene: UIWindowScene? = UIWindowScene()
    var rootViewController: UIViewController?
}
@MainActor final class UIWindowScene {
    enum ActivationState { case foregroundActive, background }
    final class Session { var persistentIdentifier = "original-native-scene" }
    var session = Session(); var activationState = ActivationState.foregroundActive
}
@MainActor final class UIViewController {
    var viewIfLoaded: UIView?; var presentedViewController: UIViewController?
    var isBeingPresented = false; var isBeingDismissed = false
    var transitionCoordinator: Int?; var children: [UIViewController] = []
}
'''
    # The error shell only preserves the portable latch's unchanged error API;
    # it is not used to model permission, runtime, source, claim or cancellation.
    error_boundary = '''
private enum UIRouteErrorCode { case staleState }
private struct UIRouteError: Error {
    let code: UIRouteErrorCode; let detail: String
    init(_ code: UIRouteErrorCode, _ detail: String) { self.code = code; self.detail = detail }
}
'''
    actual = '\n'.join(['import Foundation\nimport Observation\nimport Synchronization\n', error_boundary,
                         error, root_boundary, root_publication, mode_source, window_observation,
                         window_source, observation, attachment, bridge, texts['contract'], semantic, texts['controls']])
    report = {'schema': 'otzaria.rn-semantic-swift-source-controls.v1',
              'scope': 'Actual original Observation/runtime/source-locked ticket bodies; standalone Swift, no UIKit/React/Core-grant/app/Apple SDK/native execution',
              'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'inputs': rows,
              'extraction': {'runtimePrefixSHA256': sha(bridge.encode()), 'actualRPCErrorSHA256': sha(error.encode()),
                             'moduleJoin': 'Only two imports removed to put actual types in one standalone compilation unit',
                             'errorBoundary': error_boundary, 'rootBindingBoundary': root_boundary,
                             'actualRootPublicationSHA256': sha(root_publication.encode()),
                             'actualWindowSourceSHA256': sha(window_source.encode()),
                             'actualWindowObservationSHA256': sha(window_observation.encode()),
                             'actualOriginalModeSHA256': sha(mode_source.encode()),
                             'actualWindowAttachmentSHA256': sha(attachment.encode()),
                             'candidateSourceSHA256': sha(actual.encode())},
              'compiler': subprocess.check_output(['swiftc', '--version'], text=True).strip(),
              'runs': []}
    (out / 'INPUTS.json').write_text(json.dumps(report, indent=2) + '\n')
    variants = {
        'candidate': actual,
        'omit-source-claim-latch': replace_once(actual, 'guard !retired else { return false }', '// Counterfactual: omitted only retained source latch guard.'),
        'omit-runtime-claim-guard': replace_once(actual, 'guard state == expected, state.canPresent else { return false }', '// Counterfactual: omitted only retained runtime guard.'),
        'rejected-observable-root-counter': replace_once(actual, '@MainActor\nfinal class MaktabahNativeRootPublicationSource', '@MainActor @Observable\nfinal class MaktabahNativeRootPublicationSource'),
        'rejected-observable-window-counter': replace_once(actual, '@MainActor final class MaktabahNativeWindowSource', '@MainActor @Observable final class MaktabahNativeWindowSource'),
        'rejected-observable-mode-counter': replace_once(actual, '    @ObservationIgnored private(set) var nativeModePresentationRevision: UInt64? = 0', '    private(set) var nativeModePresentationRevision: UInt64? = 0'),
        'omit-original-closed-publication': replace_once(actual, 'for item in original { item.value?.invalidate() }', 'for _ in original {} // Counterfactual: retain original setters but omit their closed latch publication.'),
    }
    for name, source in variants.items():
        assert shutil.disk_usage(root).free >= 687865856 + 200000000, 'Original source-control reserve'
        run = out / name; run.mkdir()
        src = run / 'ActualSourceWithControls.swift'; src.write_text(source)
        executable = run / 'controls'
        argv = ['swiftc', '-swift-version', '6', '-strict-concurrency=complete', '-parse-as-library',
                '-module-cache-path', str(args.module_cache), str(src), '-o', str(executable)]
        item = {'name': name, 'sourceSHA256': sha(source.encode()), 'compileArgv': argv,
                'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        with (run / 'compile.stdout.log').open('wb') as stdout, (run / 'compile.stderr.log').open('wb') as stderr:
            process = subprocess.run(argv, stdout=stdout, stderr=stderr, timeout=90)
        item['compileExit'] = process.returncode
        if process.returncode == 0:
            with (run / 'run.stdout.json').open('wb') as stdout, (run / 'run.stderr.log').open('wb') as stderr:
                process = subprocess.run([str(executable)], stdout=stdout, stderr=stderr, timeout=30)
            item['runExit'] = process.returncode
            result = json.loads((run / 'run.stdout.json').read_text())
            item['passed'], item['failed'] = result['passed'], result['failed']
            item['expectedOutcomeObserved'] = (process.returncode == 0 and result['failed'] == 0) if name == 'candidate' else (process.returncode != 0 and result['failed'] > 0)
        else:
            item['expectedOutcomeObserved'] = False
        item['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        item['artifacts'] = [{'path': str(p.relative_to(out)), 'bytes': p.stat().st_size, 'sha256': sha(p.read_bytes())}
                             for p in sorted(run.iterdir()) if p.is_file() and p.name != 'controls']
        (run / 'RESULT.json').write_text(json.dumps(item, indent=2) + '\n')
        report['runs'].append(item)
        (out / 'RESULT.json').write_text(json.dumps(report, indent=2) + '\n')
        if not item['expectedOutcomeObserved']:
            print(json.dumps({'status': 'FAILED', 'run': name, 'compileExit': item['compileExit'],
                              'result': str(out / 'RESULT.json')}))
            return 1
    report['status'] = 'SOURCE_CONTROLS_PASS_NATIVE_NOT_RUN'
    report['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    (out / 'RESULT.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'status': report['status'], 'runs': [{k: r.get(k) for k in ['name', 'compileExit', 'runExit', 'passed', 'failed']} for r in report['runs']],
                      'result': str(out / 'RESULT.json'), 'sha256': sha((out / 'RESULT.json').read_bytes())}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
