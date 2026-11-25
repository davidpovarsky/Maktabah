from pathlib import Path
import hashlib,json,runpy,subprocess,sys
root=Path(sys.argv[1]).resolve()
selector=runpy.run_path(str(root/'Scripts/CI/select-runtime27-toolchain.py'))
contract=selector['original_editor_toolchain'](Path('Scripts/CI/runtime27-original-editor.inputs.json'),root)
config=json.loads((root/'Scripts/CI/runtime27-original-editor.inputs.json').read_bytes())
assert contract['toolchain']==config['framework_producer']['toolchain']
common=runpy.run_path(str(root/'Scripts/CI/original_editor_continuation_admission.py'))
sdk=runpy.run_path(str(root/'Scripts/CI/hq-original-editor-distribution.py'))
destination=common['validate_paths'](root,config,sdk)
print(json.dumps({'status':'UNCHANGED_CONFIGURATION_FUNCTIONS_PASS','checkout_sha':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'source_gate':contract,'owned_distribution_destination':str(destination),'functions_executed':['select-runtime27-toolchain.py:original_editor_toolchain','original_editor_continuation_admission.py:validate_paths'],'actual_installed_toolchain_inspected':False,'artifacts_downloaded':0,'sdk_distribution_restored':False,'native_builds_or_tests':0,'historical_controls_reexecuted':0},indent=2))
