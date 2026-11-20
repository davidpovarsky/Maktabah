#!/usr/bin/env python3
"""Read-only route/source packet verification; no Swift or Native invocation."""
import argparse,hashlib,json,os,pathlib,shutil,subprocess,sys,tempfile,zipfile
M='353888ed645c135da9cb229713d17a4594d1edb6'
D=pathlib.Path('docs/hq-integration/native-study-sheet-apple-route-20261120')
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--root',type=pathlib.Path,required=True);p.add_argument('--run-python-controls',action='store_true');a=p.parse_args();r=a.root.resolve();d=r/D
 m=json.loads((d/'ARTIFACTS.json').read_bytes());seen=set()
 for row in m['files']:
  path=pathlib.PurePosixPath(row['path']);assert not path.is_absolute() and '..' not in path.parts and str(path) not in seen;seen.add(str(path))
  f=r/path;assert f.is_file() and not f.is_symlink();b=f.read_bytes();assert len(b)==row['bytes'] and sha(b)==row['sha256'] and blob(b)==row['git_blob'],row['path']
 inputs=json.loads((d/'CANONICAL_BASE_INPUTS.json').read_bytes());binding=json.loads((d/'SOURCE_BINDING.json').read_bytes())
 assert binding['source_sealed'] is True and binding['source_commit']==inputs['source_commit']==M
 assert binding['source_tree']==inputs['tree']=='324aad3ea57a4d4807c4d01998a1fd89a10e179e'
 records={row['path']:row for row in inputs['records']};assert len(records)==len(inputs['records'])==22
 result=json.loads((d/'PYTHON_RESULT.json').read_bytes());assert (result['executed'],result['passed'],result['failed'],result['errors'],result['Swift_executed'],result['Native_executed'])==(47,47,0,0,0,0)
 for row in result['sources']:assert sha((r/row['path']).read_bytes())==row['sha256']
 with tempfile.TemporaryDirectory(prefix='study-sheet-route-verify-') as t:
  base=pathlib.Path(t)/'base';projection=pathlib.Path(t)/'projection'
  with zipfile.ZipFile(d/'BASE_INPUTS.zip') as z:
   assert z.testzip() is None and len(z.namelist())==len(set(z.namelist()))==22 and set(z.namelist())==set(records)
   for name in z.namelist():
    path=pathlib.PurePosixPath(name);assert not path.is_absolute() and '..' not in path.parts;b=z.read(name);entry=records[name]
    assert len(b)==entry['bytes'] and sha(b)==entry['sha256'] and blob(b)==entry['git_blob']
    f=base/path;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(b)
  text=(r/'Scripts/CI/runtime27.py').read_text();edits=json.loads((d/'RUNTIME_EXACT_EDIT.json').read_bytes())
  assert sha(text.encode())==edits['candidate_sha256']
  for e in reversed(edits['replacements']):assert text.count(e['after'])==1;text=text.replace(e['after'],e['before'],1)
  assert text.count(edits['new_r27_pin'])==1;text=text.replace(edits['new_r27_pin'],edits['old_r27_pin'],1)
  assert text.encode()==(base/'Scripts/CI/runtime27.py').read_bytes()
  original=json.loads((base/'docs/hq-integration/runtime27/R27_CASES.json').read_bytes());old=original['cases']+original['supplemental_cases'];assert len(old)==116
  selected=[]
  for name,count in [('ipad11',11),('iphone',1)]:
   current=json.loads((r/f'docs/hq-integration/runtime27/native-study-sheet-{name}.json').read_bytes());rows=current['cases']+current['supplemental_cases']
   assert rows[:116]==old and len(rows)==128 and len({row['case_id'] for row in rows})==128
   assert len(current['execution_case_ids'])==count and current['native_cases_executed']==0
   selected+=current['execution_case_ids']
  assert len(selected)==len(set(selected))==12
  assert len(binding['foundation_inputs'])==8
  for path,entry in binding['foundation_inputs'].items():assert records[path]==entry
  code=(base/'Maktabah-iOSUITests/NativeStudySheetAcceptanceTests.swift').read_text()
  for case in selected:
   cls,method=case.split('/');assert 'final class '+cls+':' in code and code.count('func '+method+'(')==1
  if a.run_python_controls:
   shutil.copytree(base,projection)
   for path in seen|{str(D/'ARTIFACTS.json')}:
    f=projection/path;f.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(r/path,f)
   run=subprocess.run([sys.executable,str(projection/'Scripts/CI/test-native-study-sheet-native.py'),'--base-dir',str(base)],capture_output=True,text=True,timeout=60,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
   print(run.stdout+run.stderr);assert run.returncode==0 and 'Ran 47 tests' in run.stderr and run.stderr.rstrip().endswith('OK')
 print(json.dumps({'status':'PASS_SOURCE_PACKET_ONLY','manifested_files':len(seen),'canonical_M_inputs':22,'original_rows_preserved':116,'selected':{'ipad11':11,'iphone':1},'Foundation_candidate_declared':25,'Foundation_baseline_declared':5,'Python_controls_replayed':47 if a.run_python_controls else 0,'Swift_executed':0,'Native_executed':0},indent=2))
if __name__=='__main__':main()
