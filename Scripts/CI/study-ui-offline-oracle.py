#!/usr/bin/env python3
"""Live, owned Oracle SSH bridge for one original full-v40 offline phase.

No import effects and no owner-approval producer. Runtime is authorized only by
the separately coordinated actual Mac window. Import/source controls never run
SSH, native UI, PF or launchd. The original controller owns all those actions.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import pwd
import queue
import re
import shlex
import shutil
import signal
import stat
import subprocess
import sys
import threading
import time
import uuid

SCHEMA = 'otzaria.owned-original-offline-oracle-coordinator/1'
LAUNCH_SCHEMA = 'otzaria.original-offline-oracle-launch/1'
EVENT_SCHEMA = 'otzaria.offline-controller-event/1'
INPUT_SCHEMA = 'otzaria.offline-coordinator-input/1'
EVENT_MARKER = 'OTZARIA_OFFLINE_COORDINATOR_EVENT '
BOOT_MARKER = 'OTZARIA_OFFLINE_ORACLE_LAUNCH '
OWNER_MARKER = 'OTZARIA_OFFLINE_ORACLE_READY '
PASS = 'ACTUAL_ORIGINAL_OFFLINE_PHASE_AND_RELAY_RETURNED_PASS'
MAX_INPUT = 131072
MAX_STREAM = 4 * 1024 * 1024
MAX_JSON = 16 * 1024 * 1024
MAX_RPC_RETURN = 48 * 1024 * 1024
CASE_IDS = {
    'offline-zayit': 'PublishedProductionSearchDataTests/testPublishedV40ZayitPages50_100_150RetainSQLIdentity',
    'offline-otzaria': 'PublishedProductionSearchDataTests/testPublishedV40OtzariaPagesRetainCumulativeSQLMetadata',
}
SOURCE_NAMES = (
    'study-ui-offline-oracle.py', 'study-ui-offline-exercises.py',
    'study-ui-offline-window.py', 'study-ui-offline-heartbeat.py',
    'study-ui-offline-execution.py', 'study-ui-settings-receipts.py',
    'runtime27_interruption.py', 'production-study-v40-ui.py',
)


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def strict_json(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'Repeated JSON key')
            result[key] = value
        return result
    def invalid(value):
        raise ValueError('Nonfinite JSON value')
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid)


def json_bytes(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode() + b'\n'


def absolute(value):
    require(type(value) is str and value and '\x00' not in value and '\n' not in value,
            'An explicit absolute path is required')
    path = Path(value)
    require(path.is_absolute() and '..' not in path.parts and str(path) == value,
            'Use a canonical absolute path without substitutions')
    return path


def witness_shape(value, maximum=MAX_JSON):
    require(isinstance(value, dict) and set(value) == {'path', 'bytes', 'sha256'}
            and type(value['bytes']) is int and 0 < value['bytes'] <= maximum
            and type(value['sha256']) is str and re.fullmatch('[a-f0-9]{64}', value['sha256']),
            'Malformed or oversized original FileWitness')
    absolute(value['path'])
    return value


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def validate_launch(value):
    keys = {'schema', 'phase', 'simulatorUDID', 'macRepository', 'python', 'controller',
            'argv', 'environment', 'inputs', 'outputDirectory', 'timeouts'}
    require(isinstance(value, dict) and set(value) == keys and value['schema'] == LAUNCH_SCHEMA
            and value['phase'] in CASE_IDS, 'Supply one exact original offline launch specification')
    require(type(value['simulatorUDID']) is str and str(uuid.UUID(value['simulatorUDID'])).upper() == value['simulatorUDID'],
            'Use the actual canonical Simulator UUID')
    root, output = absolute(value['macRepository']), absolute(value['outputDirectory'])
    require(output.is_relative_to(root / 'build/artifacts') and output != root / 'build/artifacts',
            'Original controller output must be a new child of its actual build/artifacts')
    python, controller = witness_shape(value['python']), witness_shape(value['controller'], 1024 * 1024)
    require(controller['path'] == str(root / 'Scripts/CI/production-study-v40-ui.py'), 'Wrong original main path')
    argv = value['argv']
    require(isinstance(argv, list) and 6 < len(argv) <= 22 and all(type(v) is str and v and '\x00' not in v and '\n' not in v for v in argv)
            and argv[:6] == [python['path'], '-I', '-B', '-u', controller['path'], 'execute']
            and argv[6] == value['phase'] and len(argv[7:]) % 2 == 0,
            'Use the explicitly supplied original Python/execute argv, with no shell program')
    options = dict(zip(argv[7::2], argv[8::2]))
    required = {'--owned-simulator', '--installation-result', '--output', '--reserved-other-bytes', '--offline-coordinator-wait-seconds'}
    require(len(options) * 2 == len(argv[7:]) and required <= set(options)
            and set(options) <= required | {'--runner-inputs'}
            and options['--owned-simulator'] == value['simulatorUDID']
            and options['--output'] == str(output), 'Repeated, foreign or unbound original controller arguments')
    require(re.fullmatch('[0-9]+', options['--reserved-other-bytes'])
            and re.fullmatch('[0-9]+', options['--offline-coordinator-wait-seconds'])
            and 0 < int(options['--offline-coordinator-wait-seconds']) <= 600,
            'Explicit current storage reserve and original bounded coordinator wait are required')
    inputs = value['inputs']
    expected_inputs = {'installationResult'} | ({'runnerInputs'} if '--runner-inputs' in options else set())
    require(isinstance(inputs, dict) and set(inputs) == expected_inputs, 'Bind every original supplied input file')
    for key, option in [('installationResult', '--installation-result'), ('runnerInputs', '--runner-inputs')]:
        if key in inputs:
            require(witness_shape(inputs[key])['path'] == options[option], 'Input witness differs from the actual argv')
    environment = value['environment']
    required_env = {'EXPECTED_CHECKOUT_SHA', 'FAITHFUL_RUNTIME27_IDENTIFIER', 'LC_ALL', 'TZ'}
    require(isinstance(environment, dict) and required_env <= set(environment)
            and set(environment) <= required_env | {'PATH', 'DEVELOPER_DIR'}
            and all(type(v) is str and v and '\x00' not in v and '\n' not in v for v in environment.values())
            and environment['LC_ALL'] == 'C' and environment['TZ'] == 'UTC'
            and re.fullmatch(r'[0-9a-f]{40}', environment['EXPECTED_CHECKOUT_SHA'])
            and re.fullmatch(r'com\.apple\.CoreSimulator\.SimRuntime\.iOS-27(?:-[0-9]+)+', environment['FAITHFUL_RUNTIME27_IDENTIFIER']),
            'Use explicit original immutable checkout/runtime/locale values; arbitrary runner, proxy or provider overrides are forbidden')
    if 'DEVELOPER_DIR' in environment: absolute(environment['DEVELOPER_DIR'])
    timeouts = value['timeouts']
    require(isinstance(timeouts, dict) and set(timeouts) == {'preReadySeconds', 'postRestorationSeconds'}
            and type(timeouts['preReadySeconds']) is int and 0 < timeouts['preReadySeconds'] <= 1800
            and type(timeouts['postRestorationSeconds']) is int and 0 < timeouts['postRestorationSeconds'] <= 900,
            'Supply bounded startup and post-restoration resource waits; they never extend a lease')
    return options


def validate_response(value, request_id):
    require(isinstance(value, dict) and set(value) == {'schema', 'requestID', 'lease', 'coordination', 'hostProbe', 'simulatorProbe'}
            and value['schema'] == INPUT_SCHEMA and value['requestID'] == request_id,
            'The owner response belongs to another actual runtime request')
    for key in ('lease', 'coordination'): witness_shape(value[key], MAX_INPUT)
    for key in ('hostProbe', 'simulatorProbe'):
        require(isinstance(value[key], dict) and set(value[key]) == {'binary', 'source', 'compileReceipt'},
                'Supply the original compiled Foundation probe manifest')
        for item in value[key].values(): witness_shape(item)
    return value


class EventState:
    """Only actual live source frames advance this single-controller machine."""
    def __init__(self, launch):
        self.launch = launch
        self.boot = self.ready = self.prepared = self.restored = self.pending = self.aborted = None
        self.sequence = 0

    def launch_frame(self, value):
        require(self.boot is None and isinstance(value, dict) and value.get('schema') == SCHEMA
                and value.get('event') == 'ORIGINAL_CONTROLLER_EXEC_READY'
                and type(value.get('actualControllerPID')) is int and value['actualControllerPID'] > 1
                and type(value.get('actualUID')) is int and value['actualUID'] > 0
                and value.get('argv') == self.launch['argv'] and value.get('macRepository') == self.launch['macRepository']
                and value.get('checkoutSHA') == self.launch['environment']['EXPECTED_CHECKOUT_SHA'],
                'Missing, duplicated or foreign actual remote launch identity')
        require(type(value.get('parentPID')) is int and value['parentPID'] > 1
                and type(value.get('startUTC')) is str and value['startUTC'], 'Actual controller start/parent identity is absent')
        self.boot = value

    def accept(self, value):
        require(self.boot is not None and not self.pending and not self.aborted
                and isinstance(value, dict) and value.get('schema') == EVENT_SCHEMA
                and type(value.get('sequence')) is int and value['sequence'] == self.sequence
                and value.get('actualControllerPID') == self.boot['actualControllerPID']
                and finite(value.get('observedAtUnix'))
                and value.get('controlDirectory') == str(Path(self.launch['outputDirectory']) / 'offline-control')
                and type(value.get('requestID')) is str and re.fullmatch('[a-f0-9]{32}', value['requestID']),
                'Foreign, duplicated or reordered original controller event')
        if self.ready:
            require(value['requestID'] == self.ready['requestID'], 'Original request identity changed')
        event = value.get('event')
        if event == 'CONTROLLER_READY':
            require(self.sequence == 0 and value.get('studyPhase') == self.launch['phase']
                    and value.get('selectedCaseID') == 'Maktabah-iOSUITests/' + CASE_IDS[self.launch['phase']]
                    and value.get('simulatorUDID') == self.launch['simulatorUDID'], 'Wrong original phase, case or Simulator')
            witness_shape(value['sourceBefore']); witness_shape(value['windowSource'], 1024 * 1024)
            self.ready = value
        elif event == 'WINDOW_PREPARED':
            require(self.sequence == 1 and self.ready is not None, 'Window prepared before original ready/coordination')
            item = value.get('rendezvous', {})
            require(item.get('schema') == 'otzaria.offline-oracle-rendezvous/1'
                    and item.get('actualControllerPID') == value['actualControllerPID']
                    and item.get('selectedCaseID') == self.ready['selectedCaseID']
                    and item.get('simulatorUDID') == self.ready['simulatorUDID']
                    and type(item.get('windowID')) is str and re.fullmatch('[a-f0-9]{32}', item['windowID'])
                    and finite(item.get('hardDeadlineUnix')), 'Foreign actual prepared window')
            for key in ('oracleRelaySource', 'coordinationReceipt', 'lease'): witness_shape(item[key])
            self.prepared = value
        elif event == 'TRANSPORT_RESTORED':
            require(self.sequence == 2 and self.prepared is not None
                    and value.get('windowID') == self.prepared['rendezvous']['windowID']
                    and type(value.get('cleanupSHA256')) is str and re.fullmatch('[a-f0-9]{64}', value['cleanupSHA256']),
                    'Restoration is not bound to the actual prepared window and root cleanup')
            self.restored = value
        elif event == 'CONTROLLER_POSTCHECKS_PENDING':
            require(self.sequence == 3 and self.restored is not None
                    and value.get('cleanupVerified') is True and value.get('nativeCaseCompleted') is True
                    and value.get('rootFinalResultPending') is True, 'Pending final postchecks are malformed')
            self.pending = value
        elif event == 'WINDOW_ABORTED':
            require(self.sequence > 0 and value.get('rootFinalResultPending') is True
                    and type(value.get('cleanupVerified')) is bool and type(value.get('nativeCaseCompleted')) is bool,
                    'Malformed original failure event')
            self.aborted = value
        else:
            raise ValueError('Unknown original controller event')
        self.sequence += 1
        return event


# This fixed remote program only verifies source, transfers bounded private
# files, collects original results, or interrupts the exact created controller.
# No caller-supplied Python/shell fragment, PF command or approval is accepted.
REMOTE_COMMON = r'''
import base64, hashlib, json, os, re, shlex, signal, stat, subprocess, sys, time, uuid
from pathlib import Path
def need(v, m):
    if not v: raise ValueError(m)
def digest(v): return hashlib.sha256(v).hexdigest()
def decode(raw):
    def pairs(items):
        result = {}
        for k,v in items:
            need(k not in result, 'duplicate key'); result[k] = v
        return result
    def invalid(v): raise ValueError('nonfinite JSON')
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid)
def stamp(s): return [s.st_dev,s.st_ino,s.st_size,s.st_mode,s.st_uid,s.st_gid,s.st_nlink,s.st_mtime_ns,s.st_ctime_ns]
def canonical(value, directory=False):
    p=Path(value); need(p.is_absolute() and p.resolve(strict=True)==p and not p.is_symlink(), 'noncanonical path')
    s=p.lstat(); need(stat.S_ISDIR(s.st_mode) if directory else stat.S_ISREG(s.st_mode), 'wrong path kind'); return p
def read(path, maximum=16777216, private=False):
    p=canonical(path); before=p.lstat()
    need(before.st_nlink==1 and 0<before.st_size<=maximum, 'linked/empty/oversized input')
    if private: need(before.st_uid==os.geteuid() and stat.S_IMODE(before.st_mode)==0o600, 'private owner/mode')
    fd=os.open(p,os.O_RDONLY|os.O_NOFOLLOW)
    with os.fdopen(fd,'rb') as h:
        need(stamp(os.fstat(h.fileno()))==stamp(before),'changed before read'); raw=h.read(maximum+1)
        need(stamp(os.fstat(h.fileno()))==stamp(before),'changed during read')
    need(len(raw)==before.st_size and stamp(p.lstat())==stamp(before),'changed after read')
    return raw, {'path':str(p),'bytes':len(raw),'sha256':digest(raw)}
def verified(w,maximum=16777216):
    need(set(w)=={'path','bytes','sha256'},'witness shape'); raw,actual=read(w['path'],maximum)
    need(actual==w,'original bytes differ'); return raw
def process(pid):
    q=subprocess.run(['/bin/ps','-ww','-p',str(pid),'-o','pid=,ppid=,lstart=,command='],capture_output=True,timeout=5,
                     env={**os.environ,'LC_ALL':'C','TZ':'UTC'})
    need(q.returncode in (0,1) and not q.stderr,'process read failed')
    rows=[r for r in q.stdout.decode().splitlines() if r.strip()]
    if not rows: return None
    need(len(rows)==1,'ambiguous process')
    m=re.fullmatch(r'\s*(\d+)\s+(\d+)\s+([A-Za-z]{3}\s+[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}\s+\d{4})\s+(.*)',rows[0])
    need(m is not None and int(m[1])==pid,'invalid process identity')
    return {'pid':pid,'parentPID':int(m[2]),'startUTC':m[3],'command':m[4]}
def sources(payload, enforce=True):
    root=canonical(payload['launch']['macRepository'],True); result={}
    for name,expected in payload['sources'].items():
        need(re.fullmatch(r'Scripts/CI/[A-Za-z0-9_.-]+\.py',name),'source path')
        path=root/name; raw,w=read(path,1048576); result[name]=w
        if enforce:
            need(w['bytes']==expected['bytes'] and w['sha256']==expected['sha256'],'Mac/Oracle source differs')
            commands=[['git','-C',str(root),'hash-object',str(path)],['git','-C',str(root),'rev-parse','HEAD:'+name]]
            checks=[subprocess.run(c,capture_output=True,timeout=5) for c in commands]
            need(all(q.returncode==0 and not q.stderr for q in checks) and checks[0].stdout==checks[1].stdout,'dirty original source')
    return result
def check_python(payload):
    w=payload['launch']['python']; verified(w)
    need(str(Path(sys.executable).resolve(strict=True))==w['path'],'actual interpreter differs')
    need(sys.platform=='darwin' and os.geteuid()>0,'actual nonroot Mac required')
def checkout(payload):
    root=canonical(payload['launch']['macRepository'],True)
    expected=payload['launch']['environment'].get('EXPECTED_CHECKOUT_SHA')
    need(type(expected) is str and re.fullmatch('[0-9a-f]{40}',expected),'explicit immutable checkout required')
    actual=subprocess.run(['git','-C',str(root),'rev-parse','HEAD'],capture_output=True,timeout=5)
    need(actual.returncode==0 and not actual.stderr,'actual immutable checkout read failed')
    observed=actual.stdout.decode('ascii').strip()
    need(observed==expected,'actual checkout differs from the explicit original source freeze')
    return observed
def control(payload, live=True):
    binding=payload['binding']; directory=canonical(binding['controlDirectory'],True); s=directory.lstat()
    need(str(directory)==str(Path(payload['launch']['outputDirectory'])/'offline-control') and s.st_uid==os.geteuid()
         and os.geteuid()==binding['actualUID'] and stat.S_IMODE(s.st_mode)==0o700,'actual private control directory owner')
    raw,w=read(directory/'00-CONTROLLER_READY.private.json',131072,True); ready=decode(raw)
    need(ready==binding['ready'],'original ready frame changed')
    if live:
        current=process(binding['process']['pid']); need(current==binding['process'],'created controller is absent or replaced')
    return directory
def publish(directory,name,raw):
    need(name in ('COORDINATION_INPUT.private.json','ORACLE_RELAY_INPUT.private.json') or re.fullmatch(r'oracle-relay-[a-f0-9]{32}\.jsonl',name),'unowned transfer path')
    need(0<len(raw)<=2097152,'bounded transfer required')
    target=directory/name; need(not target.exists() and not target.is_symlink(),'refuse existing destination')
    parent_stamp=stamp(directory.lstat()); temp=directory/('.'+name+'.'+uuid.uuid4().hex+'.stage')
    fd=os.open(temp,os.O_CREAT|os.O_EXCL|os.O_WRONLY|os.O_NOFOLLOW,0o600)
    try:
        with os.fdopen(fd,'wb') as h: h.write(raw); h.flush(); os.fsync(h.fileno())
        s=temp.lstat(); need(s.st_uid==os.geteuid() and stat.S_IMODE(s.st_mode)==0o600 and s.st_nlink==1,'staged owner/mode/link')
        # This newly created 0700 directory has one admitted writer. Refuse an
        # existing final name, then publish the complete file by atomic rename.
        now=stamp(directory.lstat())
        need(not target.exists() and not target.is_symlink() and all(now[i]==parent_stamp[i] for i in (0,1,3,4,5))
             and directory.resolve(strict=True)==directory,'destination changed before publication')
        os.rename(temp,target)
        d=os.open(directory,os.O_RDONLY)
        try: os.fsync(d)
        finally: os.close(d)
        actual,w=read(target,2097152,True); need(actual==raw,'transfer changed bytes'); return w
    finally:
        if temp.exists(): temp.unlink()
def packed(path, maximum=16777216):
    raw,w=read(path,maximum); return {'file':w,'rawBase64':base64.b64encode(raw).decode()}
payload_raw=sys.stdin.buffer.read(3145728+1)
need(0<len(payload_raw)<=3145728,'bounded input required'); payload=decode(payload_raw)
check_python(payload)
'''

REMOTE_START = REMOTE_COMMON + r'''
observed=sources(payload)
spec=payload['launch']; root=canonical(spec['macRepository'],True)
checkout_sha=checkout(payload)
need(spec['controller']==observed['Scripts/CI/production-study-v40-ui.py'],'actual main witness differs')
for w in spec['inputs'].values(): verified(w)
out=Path(spec['outputDirectory']); need(not out.exists() and not out.is_symlink() and out.is_relative_to(root/'build/artifacts'),'new owned output required')
canonical(out.parent,True)
argv=spec['argv']; need(argv[:7]==[spec['python']['path'],'-I','-B','-u',spec['controller']['path'],'execute',spec['phase']],'original argv required')
current=process(os.getpid()); need(current and current['parentPID']==os.getppid(),'actual launch identity')
value={'schema':'otzaria.owned-original-offline-oracle-coordinator/1','event':'ORIGINAL_CONTROLLER_EXEC_READY',
       'actualControllerPID':os.getpid(),'actualUID':os.geteuid(),'parentPID':os.getppid(),'startUTC':current['startUTC'],
       'argv':argv,'macRepository':str(root),'checkoutSHA':checkout_sha,'sources':observed,'python':spec['python'],
       'observedMacUnix':time.time(),'clockDomain':'Mac'}
print('OTZARIA_OFFLINE_ORACLE_LAUNCH '+json.dumps(value,separators=(',',':')),flush=True)
os.chdir(root)
environment={**os.environ,**spec['environment']}
os.execve(spec['python']['path'],argv,environment)
'''

REMOTE_RPC = REMOTE_COMMON + r'''
operation=payload['operation']; spec=payload['launch']; response={'schema':'otzaria.offline-oracle-rpc/1','operation':operation,'actualUID':os.geteuid(),'observedMacUnix':time.time()}
if operation=='inspect-ready':
    response['sources']=sources(payload)
    ready=payload['ready']; directory=canonical(ready['controlDirectory'],True); s=directory.lstat()
    need(s.st_uid==os.geteuid() and stat.S_IMODE(s.st_mode)==0o700,'control directory owner/mode')
    record=packed(directory/'00-CONTROLLER_READY.private.json',131072); actual=decode(base64.b64decode(record['rawBase64'],validate=True))
    need(actual==ready,'stdout event differs from original private frame')
    source=verified(ready['sourceBefore']); current=process(ready['actualControllerPID']); boot=payload['boot']
    need(current and current['parentPID']==boot['parentPID'] and current['startUTC']==boot['startUTC']
         and shlex.split(current['command'])==spec['argv'],'actual created controller command/start changed')
    response.update(readyRecord=record,sourceBefore={'file':ready['sourceBefore'],'rawBase64':base64.b64encode(source).decode()},process=current)
elif operation=='publish':
    response['sources']=sources(payload); directory=control(payload)
    raw=base64.b64decode(payload['rawBase64'],validate=True)
    need(digest(raw)==payload['sha256'] and len(raw)==payload['bytes'],'transfer payload differs')
    name=payload['name']
    if name in ('COORDINATION_INPUT.private.json','ORACLE_RELAY_INPUT.private.json'):
        need(len(raw)<=131072,'IPC size'); value=decode(raw)
        need(value['schema']=='otzaria.offline-coordinator-input/1' and value['requestID']==payload['binding']['ready']['requestID'],'IPC request identity')
        expected={'schema','requestID','lease','coordination','hostProbe','simulatorProbe'} if name=='COORDINATION_INPUT.private.json' else {'schema','requestID','oracleRelay'}
        need(set(value)==expected,'IPC key set')
        if name=='COORDINATION_INPUT.private.json':
            for key in ('lease','coordination'): verified(value[key],131072)
            for key in ('hostProbe','simulatorProbe'):
                need(set(value[key])=={'binary','source','compileReceipt'},'probe manifest')
                for w in value[key].values(): verified(w)
        else:
            need(value['oracleRelay']['path']==str(directory/('oracle-relay-'+value['requestID']+'.jsonl')),'relay destination is unbound')
            verified(value['oracleRelay'],2097152)
    else:
        need(name=='oracle-relay-'+payload['binding']['ready']['requestID']+'.jsonl','foreign relay name')
    response['file']=publish(directory,name,raw)
elif operation=='interrupt-controller':
    response['sources']=sources(payload)
    if payload.get('binding'):
        control(payload,live=False); expected=payload['binding']['process']; current=process(expected['pid'])
    else:
        boot=payload['boot']; need(boot['actualUID']==os.geteuid(),'actual startup owner changed')
        current=process(boot['actualControllerPID']); expected=current
        if current:
            need(current['parentPID']==boot['parentPID'] and current['startUTC']==boot['startUTC']
                 and shlex.split(current['command'])==spec['argv'],'refuse unqualified startup controller')
    if current is None: response['status']='ORIGINAL_CONTROLLER_ALREADY_ABSENT'
    else:
        need(current==expected,'refuse signal to replaced controller')
        os.kill(expected['pid'],signal.SIGINT); response['status']='SIGINT_SENT_ONLY_TO_CREATED_CONTROLLER'
    response['actualProcess']=current
elif operation=='collect':
    try: response['sources']=sources(payload,enforce=False)
    except Exception as error: response['sourceReadError']=type(error).__name__+': '+str(error)
    out=Path(spec['outputDirectory']); records={}
    if out.exists():
        canonical(out,True)
        for name in ('RESULT.json','PROGRESS.json'):
            path=out/name
            if path.exists() or path.is_symlink(): records[name]=packed(path)
        case=spec['phase']; methods={'offline-zayit':'testPublishedV40ZayitPages50_100_150RetainSQLIdentity','offline-otzaria':'testPublishedV40OtzariaPagesRetainCumulativeSQLMetadata'}
        case_dir=out/('01-'+methods[case]); native={}
        if case_dir.exists():
            canonical(case_dir,True)
            for name in ('RUN_ATTEMPT.json','RESULT.json'):
                path=case_dir/name
                if path.exists() or path.is_symlink(): native[name]=packed(path)
            xc=case_dir/'original.xcresult'
            native['xcresult']={'path':str(xc),'observedPresent':xc.exists()}
            if xc.exists():
                canonical(xc,True); native['xcresult']['identity']=stamp(xc.lstat())
        response['nativeRetained']=native
        phase=decode(base64.b64decode(records['RESULT.json']['rawBase64'],validate=True)) if 'RESULT.json' in records else None
        if phase and phase.get('offline_case'):
            record=phase['offline_case']; need(record['path']==str(out/'offline-host/CASE_RESULT.private.json'),'case receipt path')
            raw=verified(record); records['offline_case']={'file':record,'rawBase64':base64.b64encode(raw).decode()}
            original=decode(raw)
            for key in ('lease','rootReceipts','oracleRelay'):
                record=original[key]; original_raw=verified(record)
                records[key]={'file':record,'rawBase64':base64.b64encode(original_raw).decode()}
    response['records']=records
    if payload.get('binding'): response['currentControllerProcess']=process(payload['binding']['process']['pid'])
else: raise ValueError('unknown fixed operation')
raw=json.dumps(response,separators=(',',':'),allow_nan=False).encode()
need(len(raw)<=50331648,'bounded response exceeded')
sys.stdout.buffer.write(raw+b'\n'); sys.stdout.buffer.flush()
'''


def unpack(value, maximum=MAX_JSON):
    require(isinstance(value, dict) and set(value) == {'file', 'rawBase64'}, 'Original transfer envelope is absent')
    record = witness_shape(value['file'], maximum)
    raw = base64.b64decode(value['rawBase64'], validate=True)
    require(len(raw) == record['bytes'] and sha(raw) == record['sha256'], 'Original copied bytes differ from their source witness')
    return raw


def validate_sources(observed, expected, mac_root):
    require(isinstance(observed, dict) and set(expected) <= set(observed), 'Current source closure is incomplete')
    for name, value in expected.items():
        actual = witness_shape(observed[name], 1024 * 1024)
        require(actual == {'path': str(Path(mac_root) / name), 'bytes': value['bytes'], 'sha256': value['sha256']},
                'Original Mac source is not the current committed Oracle source: ' + name)


def validate_checkout_context(source, launch):
    require(source.get('checkout_sha') == launch['environment']['EXPECTED_CHECKOUT_SHA'],
            'Original source context differs from the explicitly supplied immutable checkout')


def validate_final(value, *, state, binding, source_before, expected_sources, response, relay_rows, ssh_exit, join):
    require(ssh_exit == 0 and state.pending is not None and state.aborted is None,
            'Actual controller exit0 and its complete ordered events are required')
    require(value.get('operation') == 'collect' and value.get('actualUID') == state.boot['actualUID']
            and value.get('currentControllerProcess') != binding['process'], 'Original controller is still alive or the actual Mac owner changed')
    spec, records = state.launch, value['records']
    validate_checkout_context(source_before, spec)
    validate_sources(value['sources'], expected_sources, spec['macRepository'])
    report = strict_json(unpack(records['RESULT.json']))
    require(records['RESULT.json']['file']['path'] == str(Path(spec['outputDirectory']) / 'RESULT.json')
            and report.get('status') == join.OFFLINE_PHASE_PASS and report.get('network_scope') == join.OFFLINE_NETWORK_SCOPE
            and report.get('study_phase') == spec['phase'] and report.get('selected_case_ids') == [CASE_IDS[spec['phase']]]
            and report.get('native_cases_completed') is True and report.get('post_verification_failures') == [],
            'A pending event, failed original RESULT or partial postchecks cannot qualify a phase')
    require(report.get('source_before') == report.get('source_after') == source_before
            and isinstance(report.get('build_before'), dict) and report['build_before']
            and report['build_before'] == report.get('build_after') and report.get('configuration') == 'Debug',
            'Original source/build identity changed during the completed phase')
    validate_sources(source_before['study_ui_execution_sources'], expected_sources, spec['macRepository'])
    require(report.get('runtime', {}).get('identifier') == spec['environment']['FAITHFUL_RUNTIME27_IDENTIFIER']
            and report.get('reused_external_owned_simulator') == spec['simulatorUDID']
            and report.get('original_installation', {}).get('result') == spec['inputs']['installationResult'],
            'Final original runtime/Simulator/installation differs from the actual launch')
    require(report.get('owned_cleanup', {}).get('status') == 'SHUTDOWN_RETAINED_FOR_INTEGRATION_OWNER'
            and report['owned_cleanup'].get('udid') == spec['simulatorUDID']
            and report['owned_cleanup'].get('actual_device', {}).get('state') == 'Shutdown'
            and report['owned_cleanup']['actual_device'].get('udid') == spec['simulatorUDID']
            and report.get('offline_host_cleanup', {}).get('verified') is True,
            'Original host/Simulator post-cleanup remains unverified')
    before_database = witness_shape(report.get('installation_before', {}).get('database'), 8 * 1024 * 1024 * 1024)
    after_database = witness_shape(report.get('database_after'), 8 * 1024 * 1024 * 1024)
    require(after_database['sha256'] == before_database['sha256'] and after_database['bytes'] == before_database['bytes']
            and report.get('installed_images_after') and report.get('original_installation_receipts_after'),
            'Original final corpus/image/input checks are missing')
    proof = strict_json(unpack(records['offline_case']))
    require(report.get('offline_case') == records['offline_case']['file']
            and proof.get('schema') == join.SCHEMA and proof.get('status') == join.CASE_PASS
            and proof.get('engine') == spec['phase'].removeprefix('offline-')
            and proof.get('caseID') == state.ready['selectedCaseID'] and proof.get('simulatorUDID') == spec['simulatorUDID']
            and proof.get('source') == source_before and proof.get('build') == report['build_before']
            and proof.get('runtime') == report['runtime'] and proof.get('sourceBeforeEqualsAfter') is True,
            'Final root phase did not retain its exact original joined case')
    require(proof.get('lease') == response['lease'] == records['lease']['file']
            and proof.get('coordination') == response['coordination']
            and proof.get('oracleRelay') == relay_rows == records['oracleRelay']['file'],
            'Final case used another actual lease, owner coordination or original relay transfer')
    require(join.validate_pages(proof['originalPages']['contents'], proof['engine']) == proof.get('pageIdentity'),
            'Actual original page/SQL identities do not match the retained join')
    lease = strict_json(unpack(records['lease']))
    require(lease.get('windowID') == state.restored['windowID'] and lease.get('controllerPID') == state.boot['actualControllerPID']
            and lease.get('selectedCaseID') == state.ready['selectedCaseID'] and lease.get('simulatorUDID') == spec['simulatorUDID'],
            'Original final lease differs from the live controller/window')
    exports = strict_json(unpack(records['rootReceipts']))
    cleanup = exports[lease['windowID']]['cleanup.json']
    raw_cleanup = base64.b64decode(cleanup['rawBase64'], validate=True)
    require(len(raw_cleanup) == cleanup['bytes'] and sha(raw_cleanup) == cleanup['sha256'] == state.restored['cleanupSHA256'],
            'Live restoration does not match the actual retained root cleanup bytes')
    native = value.get('nativeRetained', {})
    require(native.get('xcresult', {}).get('observedPresent') is True and 'RUN_ATTEMPT.json' in native and 'RESULT.json' in native,
            'Actual original native/xcresult files were not retained')
    rows = report.get('case_results')
    require(isinstance(rows, list) and len(rows) == 1 and rows[0].get('case') == CASE_IDS[spec['phase']]
            and rows[0].get('case_result') == native['RESULT.json']['file']
            and strict_json(unpack(native['RESULT.json'])) == {k: v for k, v in rows[0].items() if k != 'case_result'},
            'Final phase is not bound to the actual original native case RESULT')
    return {'phase': records['RESULT.json']['file'], 'case': records['offline_case']['file'],
            'windowID': lease['windowID'], 'cleanupSHA256': cleanup['sha256'],
            'pageIdentity': proof['pageIdentity'], 'network_scope': report['network_scope'],
            'scope': 'One original phase returned after its native/source/SQL/transport joins and final root postchecks; this coordinator is not a two-engine suite or physical-airplane-mode producer'}


def load(path):
    name = 'offline_oracle_' + Path(path).stem.replace('-', '_')
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec); sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def current_sources(root, window):
    require(root.is_absolute() and root.resolve(strict=True) == root, 'Use the actual canonical Oracle checkout')
    require(Path(__file__).resolve() == root / 'Scripts/CI/study-ui-offline-oracle.py', 'Execute this original committed coordinator')
    values = {}
    for name in SOURCE_NAMES:
        path = root / 'Scripts/CI' / name
        actual = subprocess.run(['git', '-C', str(root), 'hash-object', str(path)], capture_output=True, timeout=5, check=True)
        committed = subprocess.run(['git', '-C', str(root), 'rev-parse', 'HEAD:Scripts/CI/' + name], capture_output=True, timeout=5, check=True)
        require(not actual.stderr and not committed.stderr and actual.stdout == committed.stdout, 'Dirty or missing original coordinator dependency')
        raw = window.read_bytes(path, 1024 * 1024)
        values['Scripts/CI/' + name] = {'path': str(path), 'bytes': len(raw), 'sha256': sha(raw)}
    return values


def qualified_ssh_identity(window, child, identity, command, parent_pid):
    """Linux /proc preserves argv boundaries that ps cannot for the SSH -c arg."""
    status = child.poll()
    current = window.process(child.pid)
    if current is None:
        require(status is not None or child.poll() is not None, 'Live created SSH identity is unobserved')
        return identity
    require(status is None and current.get('parentPID') == parent_pid and current.get('pid') == child.pid,
            'Refuse adopting a reaped/replaced SSH child')
    path = Path('/proc') / str(child.pid) / 'cmdline'
    with path.open('rb') as handle: raw = handle.read(1024 * 1024 + 1)
    require(0 < len(raw) <= 1024 * 1024 and raw.endswith(b'\0')
            and [os.fsdecode(v) for v in raw[:-1].split(b'\0')] == command and child.poll() is None,
            'Actual SSH argv or original live Popen changed')
    require(identity is None or identity == current, 'Refuse signaling changed original SSH identity')
    return current


def local_private_bytes(window, path, maximum=MAX_INPUT):
    path = Path(path)
    before = path.lstat()
    require(stat.S_ISREG(before.st_mode) and before.st_uid == os.geteuid() and before.st_nlink == 1
            and stat.S_IMODE(before.st_mode) == 0o600, 'One original private response owned by this Oracle user is required')
    raw = window.read_bytes(path, maximum)
    signature = lambda s: (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns, s.st_mode, s.st_uid, s.st_nlink)
    require(signature(path.lstat()) == signature(before), 'Private input owner, identity or bytes changed during read')
    return raw


def private_raw(path, raw):
    """New artifact only; parent readers see it after the complete fsync/rename."""
    path = Path(path)
    require(not path.exists() and not path.is_symlink() and path.parent.resolve(strict=True) == path.parent, 'Refuse an existing or redirected private artifact')
    temp = path.with_name('.' + path.name + '.' + uuid.uuid4().hex + '.stage')
    fd = os.open(temp, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(fd, 'wb') as handle:
            handle.write(raw); handle.flush(); os.fsync(handle.fileno())
        require(not path.exists() and not path.is_symlink(), 'Private destination appeared')
        os.rename(temp, path)
        descriptor = os.open(path.parent, os.O_RDONLY)
        try: os.fsync(descriptor)
        finally: os.close(descriptor)
        return {'path': str(path), 'bytes': len(raw), 'sha256': sha(raw)}
    finally:
        if temp.exists(): temp.unlink()


class StreamCapture:
    def __init__(self, pipe, destination, events, channel, maximum=MAX_STREAM):
        self.pipe, self.destination, self.events, self.channel, self.maximum = pipe, Path(destination), events, channel, maximum
        self.error, self.finished, self.record = None, False, None
        self.start_attempted = False
        self.thread = threading.Thread(target=self.read, name='owned-offline-' + channel, daemon=True)

    def read(self):
        total, pending = 0, bytearray()
        descriptor = None
        try:
            descriptor = os.open(self.destination, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
            with os.fdopen(descriptor, 'wb') as handle:
                descriptor = None
                while True:
                    block = os.read(self.pipe.fileno(), 16384)
                    if not block: break
                    total += len(block)
                    require(total <= self.maximum, 'Owned SSH stream exceeded its bound; no truncated acceptance')
                    handle.write(block)
                    if self.channel == 'stdout':
                        pending.extend(block)
                        while b'\n' in pending:
                            line, _, tail = pending.partition(b'\n'); pending = bytearray(tail)
                            require(len(line) <= MAX_INPUT * 2, 'Original live event line exceeded its bound')
                            if line.startswith(EVENT_MARKER.encode()) or line.startswith(BOOT_MARKER.encode()):
                                self.events.put_nowait(line.decode('utf-8'))
                        require(len(pending) <= MAX_INPUT * 2, 'Original partial event line exceeded its bound')
                require(not pending, 'Original stdout ended with a partial line')
                handle.flush(); os.fsync(handle.fileno())
            raw = self.destination.read_bytes()
            self.record = {'path': str(self.destination), 'bytes': len(raw), 'sha256': sha(raw)}
        except BaseException as error:
            self.error = type(error).__name__ + ': ' + str(error)
        finally:
            if descriptor is not None: os.close(descriptor)
            self.finished = True


class OracleOfflineCoordinator:
    def __init__(self, *, repository, launch_spec, output_directory):
        require(sys.platform == 'linux' and os.geteuid() == 1001 and pwd.getpwuid(os.geteuid()).pw_name == 'ubuntu',
                'Use only the existing verified ubuntu pinned-SSH owner')
        self.root = Path(repository)
        self.exercises = load(self.root / 'Scripts/CI/study-ui-offline-exercises.py')
        _, _, self.window, self.join, self.settings, self.interruption = self.exercises.dependencies(self.root)
        self.sources = current_sources(self.root, self.window)
        raw = local_private_bytes(self.window, launch_spec)
        self.spec = strict_json(raw); self.options = validate_launch(self.spec)
        require(self.spec['controller']['bytes'] == self.sources['Scripts/CI/production-study-v40-ui.py']['bytes']
                and self.spec['controller']['sha256'] == self.sources['Scripts/CI/production-study-v40-ui.py']['sha256'],
                'Supplied Mac main is not the current original integrated controller')
        self.output = self.exercises.new_directory(output_directory)
        self.input_record = private_raw(self.output / 'LAUNCH_SPEC.private.json', raw)
        self.source_record = private_raw(self.output / 'SOURCES.private.json', json_bytes(self.sources))
        self.ssh = str(Path(shutil.which('ssh') or '').resolve(strict=True))
        require(Path(self.ssh).is_file() and os.access(self.ssh, os.X_OK), 'Existing original SSH executable is unavailable')
        self.state, self.binding, self.source_before = EventState(self.spec), None, None
        self.response = self.response_record = self.relay = self.relay_result = self.mac_relay_rows = None
        self.child = self.identity = self.owned_stop = self.final_collection = None
        self.command_argv, self.parent_pid = None, os.getpid()
        self.stdin_thread, self.stdin_error, self.stdin_start_attempted = None, None, False
        self.captures, self.rpc_records, self.event_records, self.errors = [], [], [], []
        self.events = queue.Queue(maxsize=64)
        self.started = time.monotonic()
        t = self.spec['timeouts']
        self.outer_deadline = self.started + t['preReadySeconds'] + int(self.options['--offline-coordinator-wait-seconds']) + 900 + t['postRestorationSeconds'] + 60
        self.stage_deadline = self.started + t['preReadySeconds']
        self.cleanup_receipt = None

    def write(self, name, value):
        return private_raw(self.output / name, json_bytes(value))

    def command(self, program):
        # Exactly the already verified alias and original fresh pinned route.
        return [self.ssh, '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=5', '-o', 'StrictHostKeyChecking=yes',
                '-o', 'ControlMaster=no', '-o', 'ControlPath=none', 'scaleway-mac',
                shlex.join([self.spec['python']['path'], '-I', '-B', '-u', '-c', program])]

    def payload(self):
        return {'launch': self.spec, 'sources': self.sources}

    def stop_child(self, child, identity, command):
        qualified = qualified_ssh_identity(self.window, child, identity, command, self.parent_pid)
        return self.exercises.stop_owned(self.window, self.interruption, child, qualified)

    def rpc(self, operation, *, cleanup=False, **payload):
        maximum = 30 if cleanup else min(30, self.outer_deadline - time.monotonic())
        require(maximum > 0, 'Original outer resource wait expired')
        number = len(self.rpc_records)
        directory = self.exercises.new_directory(self.output / ('rpc-' + str(number).zfill(2) + '-' + operation))
        command = self.command(REMOTE_RPC)
        body = json_bytes({**self.payload(), 'operation': operation, **payload})
        require(len(body) <= 3 * 1024 * 1024, 'Owned fixed RPC input exceeded its bound')
        child = identity = None
        record = {'operation': operation, 'startedOracleUnix': time.time(), 'commandSHA256': sha(json_bytes(command)), 'inputSHA256': sha(body)}
        self.rpc_records.append({'directory': str(directory)})
        try:
            child = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                     start_new_session=True, env={**os.environ, 'LC_ALL': 'C', 'TZ': 'UTC'})
            identity = qualified_ssh_identity(self.window, child, None, command, self.parent_pid)
            require(identity is not None, 'Fresh SSH RPC ended before its actual identity was observed')
            stdout, stderr = child.communicate(body, timeout=maximum)
            require(len(stdout) <= MAX_RPC_RETURN and len(stderr) <= MAX_INPUT, 'Fixed SSH RPC output exceeded its bound')
            record.update(process=identity, exit=child.returncode,
                          stdout=private_raw(directory / 'stdout.private.json', stdout), stderr=private_raw(directory / 'stderr.private.log', stderr))
            require(child.returncode == 0 and not stderr, 'Fresh pinned SSH RPC failed')
            value = strict_json(stdout)
            require(value.get('schema') == 'otzaria.offline-oracle-rpc/1' and value.get('operation') == operation,
                    'Unexpected fixed RPC response')
            if self.state.boot: require(value.get('actualUID') == self.state.boot['actualUID'], 'Actual Mac owner changed')
            return value
        finally:
            try:
                if child is not None: record['ownedStop'] = self.stop_child(child, identity, command)
            finally:
                record['finishedOracleUnix'] = time.time()
                self.rpc_records[number] = private_raw(directory / 'RESULT.private.json', json_bytes(record))

    def start(self):
        require(self.child is None, 'Start only one actual original controller')
        command = self.command(REMOTE_START)
        self.command_argv = command
        self.child = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                      start_new_session=True, env={**os.environ, 'LC_ALL': 'C', 'TZ': 'UTC'})
        # run()'s finally begins before start(), including receipt/thread errors.
        self.identity = qualified_ssh_identity(self.window, self.child, None, command, self.parent_pid)
        require(self.identity is not None, 'Created SSH controller ended before its actual identity was observed')
        for name, pipe in [('stdout', self.child.stdout), ('stderr', self.child.stderr)]:
            capture = StreamCapture(pipe, self.output / ('controller.' + name + '.private.log'), self.events, name)
            self.captures.append(capture); capture.start_attempted = True; capture.thread.start()
        self.write('SSH_START.private.json', {'schema': SCHEMA, 'process': self.identity,
                   'existingAlias': 'scaleway-mac', 'sources': self.sources, 'launchSpec': self.input_record,
                   'startedOracleUnix': time.time(), 'clockDomain': 'Oracle-local supervision; remote timestamps remain Mac-local'})
        def send_input():
            try:
                self.child.stdin.write(json_bytes(self.payload())); self.child.stdin.flush(); self.child.stdin.close()
            except BaseException as error:
                self.stdin_error = type(error).__name__ + ': ' + str(error)
        self.stdin_thread = threading.Thread(target=send_input, name='owned-offline-stdin', daemon=True)
        self.stdin_start_attempted = True
        self.stdin_thread.start()

    def publish(self, name, raw):
        result = self.rpc('publish', binding=self.binding, name=name, rawBase64=base64.b64encode(raw).decode(),
                          bytes=len(raw), sha256=sha(raw))
        validate_sources(result['sources'], self.sources, self.spec['macRepository'])
        file = witness_shape(result['file'], 2 * 1024 * 1024)
        require(file == {'path': str(Path(self.state.ready['controlDirectory']) / name), 'bytes': len(raw), 'sha256': sha(raw)},
                'Actual private transfer differs from the unchanged original bytes')
        return file

    def received(self, line):
        if line.startswith(BOOT_MARKER):
            value = strict_json(line[len(BOOT_MARKER):]); self.state.launch_frame(value)
            validate_sources(value['sources'], self.sources, self.spec['macRepository'])
            require(value.get('python') == self.spec['python'], 'Actual remote interpreter changed')
            self.write('MAC_LAUNCH.private.json', value)
            return
        value = strict_json(line[len(EVENT_MARKER):])
        event = self.state.accept(value)
        record = self.write(str(value['sequence']).zfill(2) + '-' + event + '.private.json', value)
        self.event_records.append(record)
        if event == 'CONTROLLER_READY':
            actual = self.rpc('inspect-ready', ready=value, boot=self.state.boot)
            validate_sources(actual['sources'], self.sources, self.spec['macRepository'])
            require(strict_json(unpack(actual['readyRecord'])) == value, 'Actual live private ready bytes differ')
            self.source_before = strict_json(unpack(actual['sourceBefore']))
            validate_checkout_context(self.source_before, self.spec)
            validate_sources(self.source_before['study_ui_execution_sources'], self.sources, self.spec['macRepository'])
            require(self.source_before.get('study_ui_phase') == self.spec['phase']
                    and self.source_before.get('executed_case_ids') == [CASE_IDS[self.spec['phase']]], 'Ready source has another phase/selector')
            expected_window = self.sources['Scripts/CI/study-ui-offline-window.py']
            require(value['windowSource'] == {'path': str(Path(self.spec['macRepository']) / 'Scripts/CI/study-ui-offline-window.py'),
                    'bytes': expected_window['bytes'], 'sha256': expected_window['sha256']}, 'Ready watchdog source differs')
            self.binding = {'actualUID': actual['actualUID'], 'process': actual['process'], 'ready': value,
                            'controlDirectory': value['controlDirectory']}
            ready = {'schema': SCHEMA, 'status': 'ACTUAL_CONTROLLER_READY_VERIFIED_WAITING_REAL_OWNER_INPUT',
                     'event': value, 'sourceAdmission': self.write('READY_ADMISSION.private.json', actual),
                     'responsePath': str(self.output / 'COORDINATION_RESPONSE.private.json'), 'originalEvent': record}
            ready_record = self.write('READY.private.json', ready)
            print(OWNER_MARKER + json.dumps({'ready': ready_record, **ready}, separators=(',', ':')), flush=True)
            self.stage_deadline = time.monotonic() + int(self.options['--offline-coordinator-wait-seconds'])
        elif event == 'WINDOW_PREPARED':
            require(self.response is not None, 'Prepared event arrived without this coordinator publishing the real response')
            item = value['rendezvous']
            require(item['lease'] == self.response['lease'] and item['coordinationReceipt'] == self.response['coordination'],
                    'Actual prepared window consumed another private owner input')
            self.relay = self.exercises.OwnedOracleRelay(repository=self.root, output_directory=self.output / 'owned-oracle-relay', rendezvous=item)
            self.write('RELAY_START_COPY.private.json', self.relay.start())
        elif event == 'TRANSPORT_RESTORED':
            require(self.relay is not None, 'No original relay belongs to this actual restored window')
            self.relay_result = self.relay.finish_after_restoration(window_id=value['windowID'], cleanup_sha256=value['cleanupSHA256'])
            rows = self.settings.verify_witness(self.relay_result['rows'], 2 * 1024 * 1024)
            self.mac_relay_rows = self.publish('oracle-relay-' + value['requestID'] + '.jsonl', rows)
            envelope = {'schema': INPUT_SCHEMA, 'requestID': value['requestID'], 'oracleRelay': self.mac_relay_rows}
            self.write('ORACLE_RELAY_INPUT_SENT.private.json', {'original': self.relay_result, 'copy': self.mac_relay_rows,
                       'input': self.publish('ORACLE_RELAY_INPUT.private.json', json_bytes(envelope))})
            self.stage_deadline = time.monotonic() + self.spec['timeouts']['postRestorationSeconds']
        elif event == 'WINDOW_ABORTED':
            raise RuntimeError('Actual original controller reported an aborted/incomplete window')
        # CONTROLLER_POSTCHECKS_PENDING deliberately changes no success state.

    def response_if_present(self):
        if not self.binding or self.response is not None: return
        path = self.output / 'COORDINATION_RESPONSE.private.json'
        if path.exists() or path.is_symlink():
            raw = local_private_bytes(self.window, path)
            value = validate_response(strict_json(raw), self.state.ready['requestID'])
            self.response_record = private_raw(self.output / 'OWNER_RESPONSE_RECEIVED.private.json', raw)
            self.publish('COORDINATION_INPUT.private.json', raw)
            self.response = value
            self.stage_deadline = time.monotonic() + 900

    def loop(self):
        while True:
            require(time.monotonic() < min(self.outer_deadline, self.stage_deadline), 'Bounded original controller wait expired; no lease extension')
            require(not any(c.error for c in self.captures), 'Owned SSH capture failed: ' + str([c.error for c in self.captures if c.error]))
            require(self.stdin_error is None, 'Owned SSH input failed: ' + str(self.stdin_error))
            self.response_if_present()
            try: line = self.events.get(timeout=.1)
            except queue.Empty: line = None
            if line is not None: self.received(line)
            if self.child.poll() is not None and all(c.finished for c in self.captures) and self.events.empty(): break
        require(not any(c.error for c in self.captures), 'Final owned SSH capture was partial')
        require(self.child.returncode == 0 and self.state.pending is not None, 'Original controller did not exit0 after all required events')

    def cleanup(self, failed):
        if self.cleanup_receipt is not None: return self.cleanup_receipt
        result = {'schema': SCHEMA, 'startedOracleUnix': time.time(), 'failedExecution': bool(failed), 'errors': []}
        if self.relay is not None:
            try: result['relay'] = self.relay.abort()
            except BaseException as error: result['errors'].append('relay: ' + type(error).__name__ + ': ' + str(error))
        if failed and self.child is not None and self.child.poll() is None and self.state.boot is not None:
            try:
                result['remoteInterrupt'] = self.rpc('interrupt-controller', cleanup=True, binding=self.binding, boot=self.state.boot)
                self.child.wait(timeout=30)
            except BaseException as error: result['errors'].append('remote controller: ' + type(error).__name__ + ': ' + str(error))
        try:
            if self.child is not None:
                self.owned_stop = self.stop_child(self.child, self.identity, self.command_argv)
                result['ssh'] = self.owned_stop
        except BaseException as error: result['errors'].append('owned SSH: ' + type(error).__name__ + ': ' + str(error))
        for capture in self.captures:
            try:
                require(not capture.start_attempted or capture.thread.ident is not None,
                        'owned stream start completion is unverified: ' + capture.channel)
                if capture.thread.ident is not None: capture.thread.join(timeout=2)
                require(not capture.thread.is_alive(), 'owned stream still alive: ' + capture.channel)
            except BaseException as error: result['errors'].append(str(error))
        if self.stdin_thread is not None:
            try:
                require(not self.stdin_start_attempted or self.stdin_thread.ident is not None, 'owned input start completion is unverified')
                if self.stdin_thread.ident is not None: self.stdin_thread.join(timeout=2)
                require(not self.stdin_thread.is_alive(), 'owned input still alive')
            except BaseException as error: result['errors'].append(str(error))
        result.update(finishedOracleUnix=time.time(), ownedLocalProcessesAndStreamsStopped=not result['errors'],
                      noRemoteCleanupInferredFromSSHExit=True)
        # The original root final RESULT/transport receipt remains mandatory.
        self.cleanup_receipt = self.write('OWNED_CLEANUP.private.json', result)
        return self.cleanup_receipt

    def run(self):
        failure, joined = None, None
        try:
            self.start(); self.loop()
            self.cleanup(False)
            require(self.window.strict_json(self.window.read_bytes(self.cleanup_receipt['path'])).get('ownedLocalProcessesAndStreamsStopped') is True,
                    'Owned local cleanup is unverified')
            self.final_collection = self.rpc('collect', binding=self.binding)
            require(current_sources(self.root, self.window) == self.sources, 'Oracle helper source changed during this actual phase')
            joined = validate_final(self.final_collection, state=self.state, binding=self.binding,
                source_before=self.source_before, expected_sources=self.sources, response=self.response,
                relay_rows=self.mac_relay_rows, ssh_exit=self.child.returncode, join=self.join)
            require(unpack(self.final_collection['records']['oracleRelay']) == self.settings.verify_witness(self.relay_result['rows'], 2 * 1024 * 1024),
                    'Original Oracle rows differ from the actual final Mac copy')
        except BaseException as error:
            failure = error
        finally:
            try: self.cleanup(failure is not None)
            except BaseException as error:
                self.errors.append('cleanup receipt: ' + type(error).__name__ + ': ' + str(error))
                if failure is None: failure = error
            if self.final_collection is None:
                try: self.final_collection = self.rpc('collect', cleanup=True, binding=self.binding)
                except BaseException as error: self.errors.append('original final/partial evidence unavailable: ' + type(error).__name__ + ': ' + str(error))
            collection = self.write('MAC_FINAL_OR_PARTIAL.private.json', self.final_collection) if self.final_collection is not None else None
            result = {'schema': SCHEMA, 'status': PASS if failure is None and not self.errors and joined else 'FAILED_OR_INCOMPLETE',
                      'launchSpec': self.input_record, 'sources': self.source_record, 'events': self.event_records,
                      'ownerResponse': self.response_record, 'relay': self.relay_result, 'macRelayRows': self.mac_relay_rows,
                      'originalMacEvidence': collection, 'rpcReceipts': self.rpc_records, 'ownedCleanup': self.cleanup_receipt,
                      'actualSSHExit': self.child.returncode if self.child is not None else None,
                      'streamReceipts': {c.channel: c.record for c in self.captures}, 'joined': joined,
                      'errors': self.errors, 'errorType': type(failure).__name__ if failure else None,
                      'error': str(failure) if failure else None, 'noOwnerApprovalGenerated': True,
                      'noPhysicalAirplaneModeClaim': True, 'noTwoEngineSuiteClaim': True,
                      'clockDomains': 'Oracle-local waits; Mac events retain Mac wall times without cross-host causal bracketing'}
            record = self.write('RESULT.private.json', result)
        if failure is not None: raise failure
        require(result['status'] == PASS, 'Original coordinator execution remains incomplete')
        return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['execute'])
    parser.add_argument('--repository', required=True, type=Path)
    parser.add_argument('--launch-spec', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    def interrupted(signum, frame):
        raise KeyboardInterrupt('Owned Oracle coordinator received signal ' + str(signum))
    signal.signal(signal.SIGTERM, interrupted)
    print(json.dumps(OracleOfflineCoordinator(repository=args.repository, launch_spec=args.launch_spec,
                                             output_directory=args.output).run(), sort_keys=True))


if __name__ == '__main__':
    main()
