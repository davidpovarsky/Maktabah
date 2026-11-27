#!/usr/bin/env python3
"""Local synthetic parser/ownership boundaries; no Apple/native execution."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import time
import types
from unittest.mock import patch
import uuid
from lxml import etree

parser = argparse.ArgumentParser()
parser.add_argument('--helper', type=Path, required=True)
parser.add_argument('--metadata-directory', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
spec = importlib.util.spec_from_file_location('trace_exports_candidate', args.helper)
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
checks = []

def check(name, action, reject=False):
    try:
        action()
        if reject: raise AssertionError('Boundary accepted malformed synthetic input')
        checks.append({'name':name,'passed':True})
    except (ValueError, KeyError, TypeError, OSError, m.ET.ParseError) as error:
        checks.append({'name':name,'passed':reject,'errorType':None if reject else type(error).__name__})
    except BaseException as error:
        checks.append({'name':name,'passed':False,'errorType':type(error).__name__,'error':str(error)})

def uid(number): return str(uuid.UUID(int=number)).upper()
udid = uid(1)
trace_path = Path('/synthetic/original/traces/original-full-v40.trace')
capture = {'status':m.CAPTURE_STATUS,'toc_export_exit':0,'recorder_pid':42,
    'command':['xcrun','xctrace','record','--template','Time Profiler','--all-processes','--device',udid,'--output',str(trace_path)],
    'started_host_monotonic':1.0,'ready_host_monotonic':2.0,'stopped_host_monotonic':10.0,
    'started_host_wall_ns':1795762374463540000,'ready_host_wall_ns':1795762375463540000,'stopped_host_wall_ns':1795762383463540000,
    'ready_signal':'xctrace --notify-tracing-started / Darwin notify',
    'owned_process_group_cleanup':{'owned_pgid':42,'group_state':'GONE_CHECKED'}}
start = {key:value for key,value in capture.items() if key not in ('status','toc_export_exit','stopped_host_monotonic','stopped_host_wall_ns','owned_process_group_cleanup')}
start['status']='READY_ACTUAL_APPLE_NOTIFICATION'
check('synthetic-original-start-stop-with-exact-owned-recorder-group',lambda:m.capture_identity(capture,start))
for name,mutation in [
    ('missing-capture',lambda c:c.clear()),('unknown-recording-exit-host-toy',lambda c:c.update(status='FAILED_OR_INCOMPLETE_SCHEMA_CONTROL')),
    ('unverified-owned-group',lambda c:c['owned_process_group_cleanup'].update(group_state='STILL_PRESENT_UNVERIFIED')),
    ('foreign-recorder-group',lambda c:c['owned_process_group_cleanup'].update(owned_pgid=43)),
    ('failed-TOC-export',lambda c:c.update(toc_export_exit=1)),('boolean-TOC-exit',lambda c:c.update(toc_export_exit=False)),
    ('clock-missing',lambda c:c.pop('ready_host_monotonic')),('clock-reversed',lambda c:c.update(stopped_host_monotonic=0)),
    ('float-wall-nanoseconds',lambda c:c.update(stopped_host_wall_ns=1.2)),
    ('different-original-command',lambda c:c['command'].append('--launch'))]:
    def action(fn=mutation):
        value=copy.deepcopy(capture);fn(value);m.capture_identity(value,start)
    check('reject-'+name,action,True)

toc=b'<trace-toc><run number="1"><data><table schema="thread-state" target-pid="ALL"/><table schema="thread-state" target-pid="ALL" group="second"/></data></run><run number="2"><data><table schema="runloop-intervals" target-pid="SINGLE"/></data></run></trace-toc>'
inventory=m.observed_tables(toc)
choice=lambda row:{key:row[key] for key in ('run_attributes','table_attributes')}
check('synthetic-complete-observed-run-and-table-selection',lambda:m.select_observed_tables(inventory,[choice(inventory[0])]))
check('strict-superset-table-is-excluded-by-attribute-count',lambda:m.require('count(@*)=2' in inventory[0]['xpath'] and 'count(@*)=3' in inventory[1]['xpath'],'selector admits a superset'))
check('actual-local-XPath-interpreter-selects-one-not-superset-table',lambda:m.require(
    len(etree.fromstring(toc).xpath(inventory[0]['xpath']))==1,'actual XPath combined different tables'))
check('absent-schema-cannot-be-guessed',lambda:m.select_observed_tables(inventory,[{'run_attributes':{'number':'1'},'table_attributes':{'schema':'invented-swift-executor'}}]),True)
check('schema-only-selection-cannot-omit-observed-target-pid',lambda:m.select_observed_tables(inventory,[{'run_attributes':{'number':'1'},'table_attributes':{'schema':'thread-state'}}]),True)
check('same-selected-table-cannot-be-repeated',lambda:m.select_observed_tables(inventory,[choice(inventory[0]),choice(inventory[0])]),True)
ambiguous=m.observed_tables(b'<trace-toc><run number="1"><data><table schema="x"/><table schema="x"/></data></run></trace-toc>')
check('identical-observed-table-attributes-remain-ambiguous',lambda:m.select_observed_tables(ambiguous,[choice(ambiguous[0])]),True)
check('duplicate-actual-run-number-rejected',lambda:m.observed_tables(b'<trace-toc><run number="1"/><run number="1"/></trace-toc>'),True)
check('wrong-TOC-root-rejected',lambda:m.observed_tables(b'<invented><run number="1"/></invented>'),True)
check('DTD-expansion-rejected',lambda:m.xml(b'<!DOCTYPE x [<!ENTITY a "expanded">]><trace-toc>&a;</trace-toc>'),True)
check('XPath-attribute-name-injection-rejected',lambda:m.exact_predicate({'x] | //table':'bad'}),True)
check('both-quote-kinds-are-literals-not-XPath-code',lambda:m.require(m.xpath_literal('a\'"b').startswith('concat('),'missing literal encoding'))
def quoted_selector():
    root=etree.Element('trace-toc');run=etree.SubElement(root,'run',number='1');data=etree.SubElement(run,'data')
    etree.SubElement(data,'table',schema='a\'"b');etree.SubElement(data,'table',schema='other')
    table=m.observed_tables(etree.tostring(root))[0]
    assert len(root.xpath(table['xpath']))==1 and root.xpath(table['xpath'])[0].get('schema')=='a\'"b'
check('actual-local-XPath-interpreter-keeps-both-quotes-literal',quoted_selector)
for name,raw in [('duplicate-key',b'{"schema":1,"schema":2}'),('NaN',b'{"value":NaN}'),('infinite-exponent',b'{"value":1e9999}')]:
    check('reject-'+name,lambda value=raw:m.decode(value),True)

exe=f'/synthetic/devices/{udid}/data/Containers/Bundle/Application/OWNED/Maktabah.app/ChavrusaText'
images={'Maktabah.app':{'installed_app_container':str(Path(exe).parent),'images':{'ChavrusaText':{'bytes':10,'sha256':'a'*64}}}}
epoch={'epoch':uid(2),'status':'OBSERVED_NOT_PERFORMANCE_ACCEPTANCE','processID':51,'executable':exe,
    'resource_start_host_monotonic':3.0,'resource_end_host_monotonic':4.0,
    'resource_start_host_wall_ns':1795762376463540000,'resource_end_host_wall_ns':1795762377463540000,
    'samples':[{'processID':51,'host_query_started_monotonic':v-.01,'host_monotonic':v,'host_wall_ns':1795762376463540000+i}
               for i,v in enumerate((3.0,3.9))]}
check('synthetic-original-epoch-binds-actual-recorded-PID-executable-clocks',lambda:m.epoch_identity(epoch,capture,udid,images))
for name,mutation in [('different-PID',lambda v:v.update(processID=52)),('foreign-executable',lambda v:v.update(executable=exe+'other')),
    ('before-trace-ready',lambda v:v.update(resource_start_host_monotonic=1.0)),('after-trace-stop',lambda v:v.update(resource_end_host_monotonic=11.0)),
    ('partial-epoch',lambda v:v.update(status='ACTIVE_NOT_ACCEPTED')),('reversed-samples',lambda v:v['samples'].reverse()),
    ('fractional-wall-ns',lambda v:v.update(resource_start_host_wall_ns=1.1))]:
    def action(fn=mutation):
        value=copy.deepcopy(epoch);fn(value);m.epoch_identity(value,capture,udid,images)
    check('reject-epoch-'+name,action,True)

metadata=json.loads((args.metadata_directory/'metadata.json').read_text())
primary=[]
for index in range(3):
    path=args.metadata_directory/f'input-{index}.xml';raw=path.read_bytes();expected=metadata[index]
    def actual(path=path,raw=raw,expected=expected):
        assert len(raw)==expected['bytes'] and hashlib.sha256(raw).hexdigest()==expected['sha256']
        element=m.xml(raw);assert element.tag=='schemas'
    check('actual-retained-installed-schema-snapshot-'+str(index),actual)
    primary.append({'originalPath':expected['path'],'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),
                    'scope':'Actual retained installed declaration, not trace data/coverage'})

with tempfile.TemporaryDirectory(prefix='source-only-trace-export-') as temporary:
    root=Path(temporary)
    original=root/'original.trace';original.mkdir();(original/'data').write_bytes(b'original trace control bytes')
    manifest=[m.file_record(original/'data')[0]]
    check('actual-tiny-regular-manifest-membership',lambda:m.trace_manifest({'files':manifest},original))
    (original/'extra').write_bytes(b'extra')
    check('extra-trace-member-is-not-hidden',lambda:m.trace_manifest({'files':manifest},original),True)
    (original/'extra').unlink();(original/'alias').symlink_to(original/'data')
    check('trace-alias-is-not-followed',lambda:m.trace_manifest({'files':manifest},original),True)
    (original/'alias').unlink()
    snapshot=m.file_record(original/'data')[0];(original/'data').write_bytes(b'changed')
    check('mutated-immutable-witness-rejected',lambda:m.verify(snapshot),True)
    for name,raw in [('rows',b'<trace-query-result><row><time>1</time></row></trace-query-result>'),
                     ('no-row-elements',b'<trace-query-result/>'),('namespace',b'<x:root xmlns:x="urn:synthetic"><x:row/></x:root>')]:
        path=root/(name+'.xml');path.write_bytes(raw)
        def inspect(path=path):
            value=m.inspect_raw_xml(path,1024);assert 'UNQUALIFIED' in value['qualification'] or 'NOT_QUALIFIED' in value['qualification']
        check('raw-'+name+'-never-qualifies-a-performance-metric',inspect)
    path=root/'malformed.xml';path.write_bytes(b'<result><row>')
    check('partial-XML-rejected-with-raw-file-retained',lambda:m.inspect_raw_xml(path,1024),True)
    check('partial-XML-file-is-never-trimmed',lambda:m.require(path.read_bytes()==b'<result><row>','raw bytes changed'))

    class Child:
        pid=8765
        returncode=None
        def poll(self):return self.returncode
        def wait(self,timeout):raise m.subprocess.TimeoutExpired('synthetic exporter',timeout)
    def lifetime(mode):
        folder=root/mode;folder.mkdir();child=Child();stops=[];created=[];calls=0
        def popen(*argv,**kwargs):
            created.append(argv);(folder/'partial.xml').write_bytes(b'partial remains');return child
        def allocation(_):
            nonlocal calls
            calls+=1
            return 0 if calls==1 else 2000
        def stop(p, **kwargs):
            stops.append(p);p.returncode=-2;return {'owned_pgid':p.pid,'group_state':'GONE_CHECKED'}
        def kernel(pid):
            return None if child.returncode is not None else {'pid':pid,'parentPID':m.os.getpid(),
                'startUTC':'Fri Nov 27 09:00:00 2026','command':'xcrun xctrace export --input synthetic'}
        with patch.object(m.subprocess,'Popen',side_effect=popen),patch.object(m,'allocated',side_effect=allocation),\
             patch.object(m.shutil,'disk_usage',return_value=types.SimpleNamespace(free=10**9)),\
             patch.object(m,'kernel_process',side_effect=kernel),patch.object(m.os,'getpgid',return_value=child.pid):
            try:
                m.export_child(['xcrun','xctrace','export','--input','synthetic'],directory=folder,stem='table',timeout=1,
                    hard_deadline=time.monotonic()+(-1 if mode=='expired-before-launch' else 10),output_budget=1000,free_reserve=100,
                    interruption={'stop_owned_process_group':stop})
            except ValueError:pass
            else:raise AssertionError('bounded failure did not propagate')
        report=json.loads((folder/'table.execution.json').read_text())
        assert report['status']=='FAILED_OR_INCOMPLETE_EXPORT'
        if mode=='expired-before-launch':assert not created and not stops
        else:
            assert len(created)==1 and stops==[child] and report['owned_cleanup_verified'] is True
            assert report['actual_exit_observed_after_cleanup']==-2
            assert (folder/'partial.xml').read_bytes()==b'partial remains'
    check('synthetic-output-cap-stops-exact-created-child-and-retains-partial-file',lambda:lifetime('post-launch-cap'))
    check('synthetic-expired-whole-session-refuses-new-child',lambda:lifetime('expired-before-launch'))

report={'schema':'otzaria.trace-export-source-controls/1',
    'status':'SOURCE_CONTROLS_PASSED_NOT_PERF_ACCEPTANCE' if all(v['passed'] for v in checks) else 'SOURCE_CONTROLS_FAILED',
    'helper':m.file_record(args.helper.resolve())[0],'primarySchemaSnapshots':primary,'controls':checks,
    'passed':sum(v['passed'] for v in checks),'total':len(checks),
    'appleToolsExecuted':0,'nativeExecutions':0,'corpusQueries':0,'actualExportedTraceTables':0,'performanceAcceptance':False}
args.output.parent.mkdir(parents=True,exist_ok=True);m.write_new(args.output,report)
print(json.dumps({k:v for k,v in report.items() if k not in ('controls','primarySchemaSnapshots')}))
if not all(v['passed'] for v in checks):
    print(json.dumps([v for v in checks if not v['passed']],indent=2));raise SystemExit(1)
