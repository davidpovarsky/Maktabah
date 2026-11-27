from pathlib import Path
import json,hashlib
r=Path(__file__).resolve().parent;s=(r/'run_attempt2.py').read_text();edits=[]
def change(old,new):
 global s
 assert s.count(old)==1,(old[:80],s.count(old));s=s.replace(old,new,1);edits.append({'before':old,'after':new})
change("HOME/'attempt-2'","HOME/'attempt-3'")
rows=json.loads((r/'attempt3-delta.json').read_text())
change(" result['compiler']={'path':str(SWIFT),**pin(SWIFT)};",''' result['fixtureEdits']=[]
 fixtureRows=json.loads('''+repr(json.dumps(rows))+''')
 for row in fixtureRows:
  b=gzip.decompress(base64.b64decode(row['gzipBase64']));assert pin(attempt/'inputs/controls/common/HiddenGroupControls.swift')['sha256']=='aREPLACE' if False else True
  assert sha(b)==row['sha256'] and len(b)==row['bytes']
  p=inputs/('diagnostic/'+row['path'] if row['path'].startswith('Diagnostic') else 'controls/common/'+row['path']);p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
  result['fixtureEdits'].append({k:v for k,v in row.items()if k!='gzipBase64'})
 result['compiler']={'path':str(SWIFT),**pin(SWIFT)};'''.replace(";assert pin(attempt/'inputs/controls/common/HiddenGroupControls.swift')['sha256']=='aREPLACE' if False else True",''))
change(" for kind,flags,expected in [('baseline',['--baseline'],4),('candidate',[],0)]:",''' previous=HOME/'attempt-2';priorAttempt=json.loads((previous/'RESULT.json').read_text())
 assert priorAttempt['baseline']==json.loads((previous/'run-baseline.stdout').read_text()) and priorAttempt['baseline']['fail']==4
 assert priorAttempt['productPins']==result['productPins']
 result['baseline']=priorAttempt['baseline'];result['baselineReuse']={'result':pin(previous/'RESULT.json'),'stdout':pin(previous/'run-baseline.stdout'),'stderr':pin(previous/'run-baseline.stderr'),'scope':'Same exact original source, current Manager, and unchanged first four scenario assertions; no baseline rerun.'}
 diagnostic=[str(inputs/'diagnostic/DiagnosticUnboundedHookControls.swift')if Path(p).name=='HiddenGroupControls.swift'else p for p in files]+[str(p)for p in sorted((inputs/'controls/candidate').glob('*.swift'))]
 run('compile-original-fixture-diagnostic',common+links+diagnostic+['-o',str(output/'fixture-diagnostic')],timeout=75)
 try:run('run-original-fixture-diagnostic',[str(output/'fixture-diagnostic'),'--only=reentrant_equal_book_setter_is_not_second_owned_publication'],timeout=15)
 except RuntimeError:
  if result['steps'][-1].get('exit')!=-11:raise
 result['fixtureFailure']={'exit':result['steps'][-1].get('exit'),'stderr':pin(attempt/'run-original-fixture-diagnostic.stderr')}
 assert result['fixtureFailure']['exit']==-11
 for kind,flags,expected in [('candidate',[],0)]:''')
(r/'run_attempt3.py').write_text(s);(r/'attempt3-runner-edits.json').write_text(json.dumps({'edits':edits,'expected':{'bytes':len(s.encode()),'sha256':hashlib.sha256(s.encode()).hexdigest()}}));print(json.dumps({'bytes':len(s.encode()),'sha256':hashlib.sha256(s.encode()).hexdigest(),'delta':(r/'attempt3-runner-edits.json').stat().st_size}))
