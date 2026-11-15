"""Prepare isolated immutable N/P/R consumer evidence; never edits app/R sources."""
from pathlib import Path
import hashlib, json, subprocess

N = Path(__file__).resolve().parents[2]
R = Path('C:/Users/DAVID/Code/Maktabah-hq-reader-20261115')
SNAPSHOT = Path('C:/Users/DAVID/.codex/tmp/n-joint-d931-050')
TARGET = SNAPSHOT / 'Source/ChavrusaText/UIRoutingHost/Tests/ChavrusaUIRoutingHostTests'
COMMIT = '44f518fcccce6bd20127f39eea8462d7a7a9dd47'
paths = [
 'Source/LibraryBackend/LibraryBackendModels.swift',
 'Source/ChavrusaText/Navigation/BackendSessionIntegrityRepair.swift',
 'Source/ChavrusaText/StudyWorkspace/StudyWorkspaceModels.swift',
 'Source/ChavrusaText/StudyWorkspace/StudyWorkspacePersistence.swift',
 'Source/ChavrusaText/StudyWorkspace/StudyWorkspaceMappingOwnership.swift',
 'Source/ChavrusaText/StudyWorkspace/StudyWorkspaceStore.swift',
 'Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift',
 'tools/workspace_mapping_native_boundary_fixture.swift',
]
manifest = {'R_commit': COMMIT, 'N_P_snapshot': '98e6c7b94fd5e4c06b83cdda57cd6c9d9f41db6e', 'inputs': {}}
contents = {}
for path in paths:
    data = subprocess.check_output(['git', 'show', f'{COMMIT}:{path}'], cwd=R)
    blob = subprocess.check_output(['git', 'rev-parse', f'{COMMIT}:{path}'], cwd=R, text=True).strip()
    manifest['inputs'][path] = {'git_blob': blob, 'sha256': hashlib.sha256(data).hexdigest()}
    contents[path] = data
for path in paths[:6]:
    (TARGET / ('RActual_' + Path(path).name)).write_bytes(contents[path])
block = contents[paths[6]].decode().split('// MARK: Native mapping producer', 1)[1].split('// MARK: Workspace presentation', 1)[0]
boundary = 'import ChavrusaUIRoutingHost\n' + contents[paths[7]].decode().replace('// ACTUAL_PRODUCER_BLOCK', block)
(TARGET / 'RActualAdapterProducer_ProposedHookBoundaryDouble.swift').write_text(boundary, encoding='utf-8')
manifest['exact_adapter_block_sha256'] = hashlib.sha256(block.encode()).hexdigest()
manifest['generated_boundary_sha256'] = hashlib.sha256(boundary.encode()).hexdigest()
test = (N / 'docs/hq-ui-routing/N_R_ACTUAL_PRODUCER_CONSUMER_TESTS_20261115.swift').read_bytes()
(TARGET / 'NRActualProducerConsumerTests.swift').write_bytes(test)
manifest['N_test_sha256'] = hashlib.sha256(test).hexdigest()
(N / 'docs/hq-ui-routing/N-R-actual-producer-inputs.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
print('Prepared exact R inputs and N tests in isolated N/P snapshot; native boundary remains explicit double.')
