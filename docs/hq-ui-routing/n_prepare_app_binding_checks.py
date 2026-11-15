"""Compile actual new app adapter and exact changed native method bodies.
No app/R/manager source mutation. Reuses an isolated portable test snapshot.
"""
from pathlib import Path
import hashlib, json, subprocess, sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/hq-ui-routing'
TARGET = Path('C:/Users/DAVID/.codex/tmp/n-joint-d931-050/Source/ChavrusaText/UIRoutingHost/Tests/ChavrusaUIRoutingHostTests')
R = 'e8b81fe844a935109036f60252ab0f176065e877' if '--reconciled-e8' in sys.argv else '44f518fcccce6bd20127f39eea8462d7a7a9dd47'
manifest = {'N_P_package_source': '98e6c7b94fd5e4c06b83cdda57cd6c9d9f41db6e', 'R': R,
    'native_scope': 'Exact app adapter; exact session presentation/composition factory methods; explicit native shells and proposed-hook manager double; NOT Apple/UIKit proof', 'inputs': {}}
def record(path, data):
    manifest['inputs'][path] = hashlib.sha256(data).hexdigest()
def read(path):
    data = (ROOT / path).read_bytes(); record(path, data); return data
for path in json.loads((OUT / 'N-R-actual-producer-inputs.json').read_text())['inputs']:
    data = subprocess.check_output(['git', 'show', f'{R}:{path}'], cwd=ROOT)
    record(R + ':' + path, data)
    if Path(path).name in ['LibraryBackendModels.swift','BackendSessionIntegrityRepair.swift','StudyWorkspaceModels.swift','StudyWorkspacePersistence.swift','StudyWorkspaceMappingOwnership.swift','StudyWorkspaceStore.swift']:
        (TARGET / ('RActual_' + Path(path).name)).write_bytes(data)
if '--reconciled-e8' in sys.argv:
    adapter = subprocess.check_output(['git','show',R+':Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift'],cwd=ROOT).decode()
    block = adapter.split('// MARK: Native mapping producer',1)[1].split('// MARK: Workspace presentation',1)[0]
    def actual_method(marker):
        start=adapter.index(marker); end=adapter.index('{',start)+1; depth=1
        while depth:
            depth+=(adapter[end]=='{')-(adapter[end]=='}'); end+=1
        return adapter[start:end]
    startup='\n'.join(actual_method(m) for m in ['func attach(_ manager:','func switchGroup(to id:'])
    native = subprocess.check_output(['git','show',R+':tools/workspace_mapping_native_boundary_fixture.swift'],cwd=ROOT)
    record(R+':tools/workspace_mapping_native_boundary_fixture.swift',native)
    generated='import ChavrusaUIRoutingHost\n'+native.decode().replace('// ACTUAL_PRODUCER_BLOCK',block).replace('// ACTUAL_STARTUP_METHODS',startup)
    (TARGET/'RActualAdapterProducer_ProposedHookBoundaryDouble.swift').write_text(generated,encoding='utf-8',newline='\n')
    harness=subprocess.check_output(['git','show',R+':tools/test_workspace_mapping_startup_reconciliation.swift'],cwd=ROOT)
    record(R+':tools/test_workspace_mapping_startup_reconciliation.swift',harness)
    (TARGET/'RActualStartupReconciliationChecks.swift').write_bytes(harness)
    (TARGET/'NReconciledRStartupTests.swift').write_bytes(read('docs/hq-ui-routing/N_RECONCILED_R_STARTUP_TEST_20261115.swift'))
    manifest['actual_R_producer_block_sha256']=hashlib.sha256(block.encode()).hexdigest()
    manifest['actual_R_startup_methods_sha256']=hashlib.sha256(startup.encode()).hexdigest()
    manifest['generated_R_native_boundary_sha256']=hashlib.sha256(generated.encode()).hexdigest()
    manifest['R_dependency_base']=subprocess.check_output(['git','rev-parse',R+'^'],cwd=ROOT,text=True).strip()
adapter_path = 'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativePublicBindingAdapter.swift'
(TARGET / 'Actual_MaktabahNativePublicBindingAdapter.swift').write_bytes(read(adapter_path))
(TARGET / 'Actual_MaktabahNativeWorkspaceOwner.swift').write_bytes(read('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspaceOwner.swift'))
source = read('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift').decode()
start = source.index('    func publicBindingPresentation()')
end = source.index('\n    }', start) + len('\n    }')
session = source[start:end]
workspace_identity = source[source.index('    func usesWorkspaceOwner('):].split('\n', 1)[0]
source = read('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift').decode()
start = source.index('    @discardableResult\n    func configureFuturePublicBinding(')
end = source.index('\n    }', start) + len('\n    }')
composition = source[start:end]
start = source.index('    func workspaceProjectionDidUpdate(')
end = source.index('\n    }', start) + len('\n    }')
workspace_update = source[start:end]
start = source.index('    func invalidateContext(')
end = source.index('\n    }', start) + len('\n    }')
invalidate_context = source[start:end]
boundary = read('docs/hq-ui-routing/N_APP_BINDING_NATIVE_BOUNDARIES_20261115.swift').decode()
actual_r_adapter = subprocess.check_output(['git','show',R+':Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift'],cwd=ROOT).decode()
r_selection = next(x for x in actual_r_adapter.splitlines() if x.startswith('    var selection: StudySceneSelection?'))
boundary = boundary.replace('    // EXACT_R_SELECTION_GETTER','' if '--reconciled-e8' in sys.argv else r_selection)
manifest['exact_R_selection_getter_sha256'] = hashlib.sha256(r_selection.encode()).hexdigest()
boundary = boundary.replace('    // EXACT_SESSION_PRESENTATION_BODY', session).replace('    // EXACT_COMPOSITION_FACTORY_BODY', composition)
boundary = boundary.replace('    // EXACT_SESSION_WORKSPACE_IDENTITY_BODY', workspace_identity).replace('    // EXACT_COMPOSITION_WORKSPACE_UPDATE_BODY', workspace_update).replace('    // EXACT_COMPOSITION_INVALIDATE_CONTEXT_BODY', invalidate_context)
host_source = read('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingHost.swift').decode()
for name, marker in [('mountIfReady','EXACT_HOST_MOUNT_BODY'),('refreshProjection','EXACT_HOST_REFRESH_BODY')]:
    method_source = host_source
    if '--legacy-host-mount' in sys.argv and name == 'mountIfReady':
        method_source = subprocess.check_output(['git','show','4b68336f:Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingHost.swift'],cwd=ROOT).decode()
        manifest['negative_control'] = 'Exact immutable4b production mountIfReady only; other source unchanged; one discriminating test'
    start = method_source.index('    private func '+name+'(')
    end = method_source.index('\n    }',start)+len('\n    }')
    method = method_source[start:end]
    boundary = boundary.replace('    // '+marker,method)
    manifest['actual_host_'+name+'_sha256'] = hashlib.sha256(method.encode()).hexdigest()
manifest['extracted_session_method_sha256'] = hashlib.sha256(session.encode()).hexdigest()
manifest['extracted_composition_method_sha256'] = hashlib.sha256(composition.encode()).hexdigest()
manifest['extracted_workspace_identity_sha256'] = hashlib.sha256(workspace_identity.encode()).hexdigest()
manifest['extracted_workspace_update_sha256'] = hashlib.sha256(workspace_update.encode()).hexdigest()
manifest['extracted_invalidate_context_sha256'] = hashlib.sha256(invalidate_context.encode()).hexdigest()
(TARGET / 'ActualAppMethodBodies_ExplicitNativeBoundaries.swift').write_text(boundary, encoding='utf-8', newline='\n')
prior = read('docs/hq-ui-routing/N_R_ACTUAL_PRODUCER_CONSUMER_TESTS_20261115.swift')
tests = read('docs/hq-ui-routing/N_APP_BINDING_ADAPTER_TESTS_20261115.swift')
(TARGET / 'NRActualProducerConsumerTests.swift').write_bytes(prior + b'\n' + tests)
manifest['generated_boundaries_sha256'] = hashlib.sha256(boundary.encode()).hexdigest()
manifest['prior_R_adapter_boundary_sha256'] = hashlib.sha256((TARGET / 'RActualAdapterProducer_ProposedHookBoundaryDouble.swift').read_bytes()).hexdigest()
output = 'N-app-reconciled-e8-inputs.json' if '--reconciled-e8' in sys.argv else 'N-app-owner-negative-control-inputs.json' if '--legacy-host-mount' in sys.argv else 'N-app-owner-edge-inputs.json' if '--owner-edge-extension' in sys.argv else 'N-app-owner-correction-inputs.json'
(OUT / output).write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8', newline='\n')
print('Prepared actual app adapter and exact factory/session bodies; explicit remaining native boundaries.')
