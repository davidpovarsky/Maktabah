from pathlib import Path
import os, sys, json, hashlib, shutil, subprocess, signal, time, zipfile, base64, traceback

TASK = Path('/mnt/development/projects/diagnostics/otzaria-wave3-annotations-selection-20261127')
OWN = TASK / 'expansion-followup-attempt-1'
REPO = Path('/home/ubuntu/otzaria-wave3-annotation-selection-published-20261127/source')
SWIFT = Path('/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc')
DATA_FLOOR = 2147483648
ROOT_FLOOR = 1342177280
CAP = 104857600
def sha(b): return hashlib.sha256(b).hexdigest()
def footprint(): return sum(p.stat().st_blocks * 512 for p in TASK.rglob('*') if p.is_file())
def capacity():
    value = {'data_free': shutil.disk_usage(TASK).free, 'root_free': shutil.disk_usage(REPO).free, 'task_bytes': footprint()}
    if value['data_free'] < DATA_FLOOR or value['root_free'] < ROOT_FLOOR or value['task_bytes'] > CAP:
        raise RuntimeError('shared capacity floor or own task cap')
    return value
def save(name, value): (OWN / name).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
steps = []
def run(name, argv, expected):
    before = capacity()
    step = {'name': name, 'argv': list(map(str, argv)), 'started': time.time(), 'before': before}
    steps.append(step)
    with (OWN/(name+'.stdout')).open('wb') as out, (OWN/(name+'.stderr')).open('wb') as err:
        process = subprocess.Popen(list(map(str,argv)),stdout=out,stderr=err,start_new_session=True,
            env={**os.environ,'TMPDIR':str(OWN/'tmp')})
        step['pid'] = process.pid
        save('STATUS.json', {'steps':steps})
        end = time.monotonic() + 100
        try:
            while process.poll() is None:
                capacity()
                if time.monotonic() > end: raise RuntimeError('own process deadline')
                time.sleep(.5)
        except BaseException:
            os.killpg(process.pid,signal.SIGTERM)
            try: process.wait(timeout=5)
            except subprocess.TimeoutExpired: os.killpg(process.pid,signal.SIGKILL);process.wait()
            raise
        finally:
            step.update(exit=process.returncode,finished=time.time())
            save('STATUS.json', {'steps':steps})
    if process.returncode != expected: raise RuntimeError(name+' unexpected exit '+str(process.returncode))

if OWN.exists(): raise RuntimeError('fresh output required')
before = capacity()
OWN.mkdir()
(OWN/'tmp').mkdir();(OWN/'output').mkdir()
try:
    data = base64.b64decode(PAYLOAD_B64)
    if sha(data) != PAYLOAD_SHA: raise RuntimeError('transport hash')
    (OWN/'INPUTS.zip').write_bytes(data)
    with zipfile.ZipFile(OWN/'INPUTS.zip') as archive:
        if any(Path(x).is_absolute() or '..' in Path(x).parts for x in archive.namelist()): raise RuntimeError('archive path')
        archive.extractall(OWN/'inputs')
    inputs = json.loads((OWN/'inputs/INPUTS.json').read_text())
    for row in inputs:
        raw=(OWN/'inputs'/row['path']).read_bytes()
        if len(raw)!=row['bytes'] or sha(raw)!=row['sha256']: raise RuntimeError('input mismatch '+row['path'])
    if sha(SWIFT.read_bytes())!='39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a': raise RuntimeError('compiler identity')
    proof=json.loads((OWN/'inputs/SOURCE_INVERSE.json').read_text())
    original=subprocess.run(['git','-C',str(REPO),'-c','gc.auto=0','-c','maintenance.auto=false','show',proof['base_commit']+':'+proof['path']],capture_output=True,check=True).stdout
    if sha(original)!=proof['before_sha256'] or original!=(OWN/'inputs/baseline'/proof['path']).read_bytes(): raise RuntimeError('original Git source join')
    candidate=(OWN/'inputs/candidate'/proof['path']).read_text()
    inverse=candidate
    for edit in reversed(proof['edits']):
        if inverse.count(edit['after'])!=1: raise RuntimeError('exact inverse span')
        inverse=inverse.replace(edit['after'],edit['before'],1)
    if inverse.encode()!=original: raise RuntimeError('whole source inverse')
    controls=OWN/'inputs/controls';output=OWN/'output'
    flags=[SWIFT,'-swift-version','6','-strict-concurrency=complete','-parse-as-library','-module-cache-path',TASK/'attempt-1/module-cache']
    run('candidate-full-ios-syntax',[SWIFT,'-frontend','-parse','-target','arm64-apple-ios27.0',OWN/'inputs/candidate'/proof['path']],0)
    for name,expected in [('OriginalExpansion',1),('CandidateExpansion',0)]:
        run(name+'-compile',flags+[controls/'ExplicitUIKitBoundary.swift',controls/(name+'.swift'),controls/'ExpansionControls.swift','-o',output/name],0)
        run(name+'-controls',[output/name],expected)
    old=json.loads((OWN/'OriginalExpansion-controls.stdout').read_text())
    new=json.loads((OWN/'CandidateExpansion-controls.stdout').read_text())
    if (old['passed'],old['failed'])!=(3,8) or (new['passed'],new['failed'])!=(11,0): raise RuntimeError('actual bounded counts')
    save('RESULT.json',{'status':'PASS_SOURCE_CONTROLS_ONLY','before':before,'after':capacity(),'steps':steps,
        'source':proof,'inputs':inputs,'baseline':{'passed':old['passed'],'failed':old['failed']},
        'candidate':{'passed':new['passed'],'failed':new['failed']},
        'boundary':'Verbatim original and candidate expansion helpers. Only private access modifier removed for invocation. Explicit UIKit/domain callback doubles, no app/SDK/UIKit/native execution. Ordinary route inverse exact.'})
except BaseException as error:
    save('RESULT.json',{'status':'FAILED','error':repr(error),'traceback':traceback.format_exc(),'steps':steps,'before':before})
    raise
finally:
    result=OWN/'RESULT.json'
    if result.exists():
        report=json.loads(result.read_text())
        print(json.dumps({'path':str(result),'sha256':sha(result.read_bytes()),'status':report['status'],'steps':[{'name':s['name'],'exit':s.get('exit')} for s in steps]}))
