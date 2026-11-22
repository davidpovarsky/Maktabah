from pathlib import Path
import ast
import hashlib
import json

HERE = Path(__file__).resolve().parent
AUDIT = HERE.parents[1]
read = lambda p: json.loads(p.read_bytes())
sha = lambda b: hashlib.sha256(b).hexdigest()
def identity(p):
    b = p.read_bytes()
    return {'bytes':len(b),'sha256':sha(b),'git_blob':hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()}
def bodies(p):
    text = p.read_text()
    return {node.name:ast.get_source_segment(text,node) for node in ast.parse(text).body
            if isinstance(node,(ast.FunctionDef,ast.ClassDef))}

manifest = read(HERE/'EXECUTION_INPUTS.json')
readbacks = read(HERE/'EXACT_INPUT_READBACK.json')
assert len(readbacks['rows']) == readbacks['input_count'] == 48
groups = {'gate_inputs':12,'origin_inputs':8,'owned_inputs':17,'lifetime_inputs':11}
for name,count in groups.items():
    rows = [r for r in readbacks['rows'] if r['group']==name]
    assert len(rows)==len(manifest[name])==count
    for row in rows:
        expected = next(r for r in manifest[name] if r['path']==row['path'])
        assert identity(Path(row['local_path'])) == {k:expected[k] for k in ('bytes','sha256','git_blob')}
old_path = AUDIT/'gate-tree-binding-fix/run_original_importer_compile.py'
assert sha(old_path.read_bytes())=='bc403e79507d5b70b275aee9ca898be3f7cbdd32703697e240bc430f42341506'
old,new = bodies(old_path),bodies(HERE/'run_original_application_compile.py')
unchanged = ['digest','write_json','safe_path','check_file','git','Commands','read_json_stream','native_library_inputs']
for name in unchanged:
    assert old[name] == new[name],name
assert old['dependency_inputs'].replace('github.com/anyproto/anytype-heart/core/block/import','github.com/anyproto/anytype-heart/core/application') == new['dependency_inputs']
preceding = manifest['preceding_twenty_product_hashes']
lifetime = manifest['lifetime_product_hashes']
assert len(preceding)==20 and len(lifetime)==8 and not set(preceding)&set(lifetime)
assert manifest['final_product_hashes'] == preceding|lifetime
prior_result_path = AUDIT/'evidence/run-45056548826/retained/downloaded-evidence/RESULT.json'
assert sha(prior_result_path.read_bytes())==manifest['preceding_native_compile']['result_sha256']
prior_result=read(prior_result_path)
assert prior_result['status']=='PASS_COMPILE_ONLY'
for p,h in preceding.items():
    assert prior_result['composed_source_hashes'][p]==h
packet = AUDIT/'lifetime/packet'
source_rows=read(packet/'SOURCE_MANIFEST.json')
assert len(source_rows)==8 and {r['path']:r['sha256'] for r in source_rows}==lifetime
assert sum(r['preimage'] is not None for r in source_rows)==6
assert sum(r['preimage'] is None for r in source_rows)==2
for row in source_rows:
    assert identity(packet/'native'/row['path'])=={k:row[k] for k in ('bytes','sha256','git_blob')}
compiled_receipt=read(packet/'PRECEDING_COMPILED_CLOSURE.json')
assert compiled_receipt['product_hashes']==preceding
assert compiled_receipt['result_sha256']==manifest['preceding_native_compile']['result_sha256']
assert compiled_receipt['run_id']==45056548826
assert manifest['compile_selection']==['go','test','-c','-p','2','-o','<owned-output>/original-application.test','./core/application']
assert manifest['preserved_lifetime_unit_leaf_pass']==23
assert manifest['preserved_lifetime_unit_result_sha256']=='4325bbe6be2344db032275f6faed8d7d9e9f98e018f9dedc42d74632217cc819'
workflow=(HERE/'otzaria-native-owned-import-lifetime-compile.yml').read_text()
assert 'workflow_dispatch' not in workflow and 'github.run_attempt == 1' in workflow
assert 'cancel-in-progress: false' in workflow and '+ 6900' in workflow
assert sha((HERE/'EXECUTION_INPUTS.json').read_bytes()) in workflow
publication=read(AUDIT/'lifetime/GATE_PUBLICATION_FILES.json')
assert len(publication)==22
for row in publication:
    assert identity(Path(row['local_path']))=={k:row[k] for k in ('bytes','sha256','git_blob')}
remote=read(HERE/'ROOT_IMMUTABLE_GATE_READBACK.json')
assert remote['head']=='afe22a1ed462b6e3601f866b582802fe514b31dd'
assert len(remote['exact_new_files'])==22
receipt={'status':'PASS_ROOT_ORIGINAL_APPLICATION_COMPILE_GATE_SOURCE_REVIEW',
         'head':remote['head'],'runner':identity(HERE/'run_original_application_compile.py'),
         'execution_manifest':identity(HERE/'EXECUTION_INPUTS.json'),
         'source_and_evidence_inputs_hashed':48,'publication_files_hashed':22,
         'unchanged_full_helpers_or_classes':unchanged,
         'dependency_reader_change':'Only the selected original package changes; input reader body otherwise identical.',
         'preceding_actual_compile_run':45056548826,'preceding_exact_native_inputs_preserved':20,
         'additional_disjoint_native_inputs':8,'total_native_inputs_required':28,
         'installer_review':'Exact original Heart HEAD, previous20 afterimages, safe target paths, all8 source bytes, six original preimages and two absent targets are checked before the first write.',
         'compile_selection':manifest['compile_selection'],'owned_finite_command_lifecycle_preserved':True,
         'source_postchecks_and_actual_go_list_input_coverage_required':28,
         'root_installer_compiler_or_test_executions':0,'old_controls_replayed':0,
         'scope':'Source review and immutable publication only. The actual original application compilation is pending; native lifetime behavior, production callsite, storage and ACK remain unqualified.'}
(HERE/'ROOT_GATE_SOURCE_REVIEW.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'status':receipt['status'],'source_inputs_hashed':48,'remote_and_local_publication_files':22,'preserved_native_inputs':20,'new_native_inputs':8,'native_execution':False}))
