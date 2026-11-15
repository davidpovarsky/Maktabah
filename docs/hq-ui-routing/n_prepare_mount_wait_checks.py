from pathlib import Path
import hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/hq-ui-routing'
TARGET=Path('C:/Users/DAVID/.codex/tmp/n-joint-d931-050/Source/ChavrusaText/UIRoutingHost/Tests/ChavrusaUIRoutingHostTests')
PATH='Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift'
BASE='0436775d85893225005f29baf0aa3a20d7b88317'
before='--before' in sys.argv
raw=subprocess.check_output(['git','show',BASE+':'+PATH],cwd=ROOT) if before else (ROOT/PATH).read_bytes()
source=raw.decode().replace('\r\n','\n')
start=source.index('    private func waitForMount(');end=source.index('\n    }',start)+len('\n    }');method=source[start:end]
start=source.index('    private struct MountWaiter {');end=source.index('\n    }',start)+len('\n    }');waiter=source[start:end]
boundary=(OUT/'N_MOUNT_WAIT_NATIVE_BOUNDARY_20261115.swift').read_text(encoding='utf-8')
generated=boundary.replace('    // EXACT_WAITER_TYPE',waiter).replace('    // EXACT_WAIT_FOR_MOUNT_METHOD',method)
tests=(OUT/'N_MOUNT_WAIT_TESTS_20261115.swift').read_bytes()
(TARGET/'ActualWaitForMount_ExplicitNativeBoundary.swift').write_text(generated,encoding='utf-8',newline='\n')
(TARGET/'NMountWaitTests.swift').write_bytes(tests)
report={'mode':'BEFORE_EXACT_043' if before else 'AFTER_WORKING_SOURCE','base':BASE,'source_path':PATH,
    'source_sha256':hashlib.sha256(raw).hexdigest(),'complete_actual_method_sha256':hashlib.sha256(method.encode()).hexdigest(),
    'actual_waiter_type_sha256':hashlib.sha256(waiter.encode()).hexdigest(),'boundary_template_sha256':hashlib.sha256((OUT/'N_MOUNT_WAIT_NATIVE_BOUNDARY_20261115.swift').read_bytes()).hexdigest(),
    'generated_boundary_sha256':hashlib.sha256(generated.encode()).hexdigest(),'tests_sha256':hashlib.sha256(tests).hexdigest(),
    'scope':'Complete actual method/type; real Foundation Task/continuation/MainActor; native scene registration and deterministic ledger replacement shells; not Apple/UIKit'}
(OUT/('N-mount-wait-before-inputs.json' if before else 'N-mount-wait-after-inputs.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print(report['mode']+' complete actual method prepared.')
