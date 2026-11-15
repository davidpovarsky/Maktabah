"""Generate/apply only a minimal backport in the isolated exact-fca snapshot."""
from pathlib import Path
import difflib, hashlib, json, subprocess

ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = Path('C:/Users/DAVID/.codex/tmp/n-v1-fca92176-inputs')
BASE = 'fca92176d48017ee0cd22831a1ae31f40958eed9'
PROD = 'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeSceneNavigationOrchestrator.swift'
TEST = 'Source/ChavrusaText/UIRoutingHost/Tests/ChavrusaUIRoutingHostTests/NativeSceneNavigationOrchestratorTests.swift'
original = subprocess.check_output(['git', 'show', f'{BASE}:{PROD}'], cwd=ROOT).decode()
needle = '            try prepared.authorizeCommit(current: current)\n'
assert original.count(needle) == 1
guard = '''            // Synchronous callbacks in the Core guard may detach/re-register
            // even the same object. Preserve the ORIGINAL live dispatch token.
            guard let liveDriver = drivers[sceneID], liveDriver === driver,
                  let dispatch = dispatches[requestID], dispatch.token == token,
                  dispatch.active, !dispatch.dispatched else {
                throw UIRouteError(.staleState, "scene_lifetime_changed")
            }
'''
corrected = original.replace(needle, needle + guard)
(SNAPSHOT / PROD).write_text(corrected, encoding='utf-8', newline='\n')
patch = ''.join(difflib.unified_diff(original.splitlines(True), corrected.splitlines(True), fromfile='a/' + PROD, tofile='b/' + PROD))
(ROOT / 'docs/hq-ui-routing/N_V1_FCA_POST_GUARD_DRIVER_TOKEN_UNAPPLIED.diff').write_text(patch, encoding='utf-8', newline='\n')
original_test = subprocess.check_output(['git', 'show', f'{BASE}:{TEST}'], cwd=ROOT).decode()
regression = (ROOT / 'docs/hq-ui-routing/N_V1_FCA_DETACHED_OWNER_REGRESSION_20261115.swift').read_text(encoding='utf-8')
assert (SNAPSHOT / TEST).read_text(encoding='utf-8') == original_test + '\n' + regression
test_patch = ''.join(difflib.unified_diff(original_test.splitlines(True), (original_test + '\n' + regression).splitlines(True), fromfile='a/' + TEST, tofile='b/' + TEST))
(ROOT / 'docs/hq-ui-routing/N_V1_FCA_REGRESSION_UNAPPLIED.diff').write_text(test_patch, encoding='utf-8', newline='\n')
manifest = {'base': BASE, 'production_original_git_blob': subprocess.check_output(['git', 'rev-parse', f'{BASE}:{PROD}'], cwd=ROOT, text=True).strip(),
    'production_corrected_sha256': hashlib.sha256(corrected.encode()).hexdigest(), 'production_patch_sha256': hashlib.sha256(patch.encode()).hexdigest(),
    'inputs': {}}
for path in sorted(SNAPSHOT.rglob('*')):
    if path.is_file():
        manifest['inputs'][path.relative_to(SNAPSHOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
(ROOT / 'docs/hq-ui-routing/N-v1-fca-inputs.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
print('Generated separate unapplied production/test diffs; changed isolated snapshot only.')
