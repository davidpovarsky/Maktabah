"""Focused Linux source/parser controls. No app, native clock or corpus run."""
import argparse
import ast
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--helper', type=Path, required=True)
parser.add_argument('--retained-components', type=Path, required=True)
parser.add_argument('--original-common', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
args.output = args.output.resolve()
helper = args.helper.resolve(strict=True)
spec = importlib.util.spec_from_file_location('owned_sqlite_wait_source_controls', helper)
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
original_common=args.original_common.resolve(strict=True)
assert hashlib.sha256(original_common.read_bytes()).hexdigest()=='75e1f2a609d1807c481fd8a28110940e68d8c9e97a2eb0092750db2107765d49'
original_spec=importlib.util.spec_from_file_location('unchanged_original_source_comparator',original_common)
original=importlib.util.module_from_spec(original_spec);original_spec.loader.exec_module(original)
args.output.mkdir()
checks = []


def check(name, operation, *, rejects=False):
    try:
        operation()
        if rejects:
            raise AssertionError('Invalid input was accepted')
        checks.append({'name': name, 'passed': True})
    except Exception as error:
        if rejects and isinstance(error, (ValueError, OSError, KeyError, TypeError)):
            checks.append({'name': name, 'passed': True, 'actualRejection': type(error).__name__})
        else:
            checks.append({'name': name, 'passed': False, 'errorType': type(error).__name__, 'error': str(error)})


def assert_true(value):
    assert value


retained = args.retained_components.resolve(strict=True)
transfer_raw = (retained / 'TRANSFER.json').read_bytes()
transfer = m.decode(transfer_raw)
actual_result_raw = (retained / 'RESULT.json').read_bytes()
assert hashlib.sha256(actual_result_raw).hexdigest() == '00a7e67662d7b3a92511be1a85d99dfad665e69f02acb80e9ece83391c37a7ee'
inputs = []
for path in sorted(retained.rglob('*.json')):
    if 'snapshot' not in path.name and 'sqlite-fetch-wait' not in path.name:
        continue
    relative = path.relative_to(retained).as_posix()
    raw = path.read_bytes()
    expected = transfer['files'][relative]
    assert {'bytes': len(raw), 'sha256': m.sha(raw)} == expected
    inputs.append({'relativePath': relative, **expected,
                   'origin': 'EXPLICIT_SYNTHETIC_RECORDER_ADMISSION' if 'synthetic' in relative else 'RETAINED_ACTUAL_APPLE_COMPONENT_ONLY'})
    check('actual-retained-schema:' + relative, lambda raw=raw: m.validate_snapshot(m.decode(raw)))
assert len(inputs) == 13
basic = m.decode((retained / 'candidate-fixture-basic/actual-basic-snapshot.json').read_bytes())
companion = (retained / 'catalyst-companion-fixture/source-request.sqlite-fetch-wait.json').read_bytes()
native = m.decode(companion)


def corrupted(change):
    value = copy.deepcopy(basic)
    change(value)
    return m.validate_snapshot(value)


for name, mutation in [
    ('wrong-schema', lambda v: v.update(schema=True)),
    ('wrong-status', lambda v: v.update(status='PASS')),
    ('wrong-clock', lambda v: v.update(clock='wall-minus-CPU')),
    ('boolean-pid', lambda v: v.update(processID=True)),
    ('nonfinite-uptime', lambda v: v.update(observedUptime=float('nan'))),
    ('capacity-change', lambda v: v.update(completedCapacity=1025)),
    ('oversized-native-counter', lambda v: v.update(lifetimeStarted=2**64)),
    ('array-count-mismatch', lambda v: v.update(activeCount=1)),
    ('invented-complete-flag', lambda v: v.update(completeLifetimeCoverage=False)),
    ('missing-connection', lambda v: v.update(connections=[])),
    ('duplicate-operation', lambda v: (v['completed'].append(copy.deepcopy(v['completed'][0])), v.update(completedRetainedCount=2))),
    ('duplicate-connection', lambda v: v['connections'].append(copy.deepcopy(v['connections'][0]))),
    ('unavailable-identity-with-file', lambda v: v['connections'][0].update(identityStatus='UNAVAILABLE')),
    ('path-escape-in-opened-file', lambda v: v['connections'][0]['openedFile'].update(path='/tmp/../other')),
    ('nonpositive-thread', lambda v: v['completed'][0].update(nativeThreadID=0)),
    ('acquired-before-wait', lambda v: v['completed'][0].update(acquiredNanoseconds=v['completed'][0]['waitStartNanoseconds'] - 1)),
    ('terminal-after-snapshot', lambda v: v['completed'][0].update(terminalNanoseconds=v['snapshotNanoseconds'] + 1)),
    ('invented-wait-duration', lambda v: v['completed'][0].update(lockAcquisitionWaitSeconds=123.0)),
    ('normal-return-without-acquire', lambda v: v['completed'][0].update(acquiredNanoseconds=None)),
    ('unexplained-loss', lambda v: v.update(lifetimeDropped=1)),
    ('truncated-completion-ring', lambda v: (v.update(lifetimeFinished=1025, lifetimeStarted=1025, lifetimeOverwritten=1024, completeLifetimeCoverage=False))),
]:
    check(name, lambda mutation=mutation: corrupted(mutation), rejects=True)
check('normal-return-may-race-cancellation-flag', lambda: corrupted(lambda v: v['completed'][0].update(taskCancelledAtTerminal=True)))
check('native-modification-time-remains-signed-int64', lambda: corrupted(lambda v: v['connections'][0]['openedFile'].update(modifiedNanoseconds=-1)))
check('duplicate-json-key', lambda: m.decode(b'{"schema":1,"schema":1}'), rejects=True)
check('nonfinite-json-constant', lambda: m.decode(b'{"x":NaN}'), rejects=True)
check('stale-request-rejected', lambda: m.validate_snapshot(basic, request_id=str(uuid.uuid4()).upper()), rejects=True)
check('foreign-pid-rejected', lambda: m.validate_snapshot(basic, process_id=basic['processID'] + 1), rejects=True)

# Descriptor construction here is a parser model only. The retained raw native
# companion is unchanged; no original app viewport/descriptor is invented.
path_model = Path('/owned/model/source.sqlite-fetch-wait.json')
descriptor = {'schema': 1, 'status': 'AVAILABLE', 'requestID': native['requestID'], 'processID': native['processID'],
              'snapshotPath': str(path_model), 'bytes': len(companion), 'sha256': m.sha(companion)}
for key in ('completeLifetimeCoverage', 'activeCount', 'completedRetainedCount', 'lifetimeDropped', 'lifetimeOverwritten'):
    descriptor[key] = native[key]
check('descriptor-model-matches-retained-native-bytes', lambda: m.validate_descriptor(
    {'sqliteFetchWaitObservation': descriptor}, companion, path_model, native['requestID'], native['processID']))
for name, mutation in [
    ('descriptor-wrong-path', {'snapshotPath': '/foreign/old.json'}),
    ('descriptor-wrong-hash', {'sha256': '0' * 64}),
    ('descriptor-wrong-length', {'bytes': len(companion) + 1}),
    ('descriptor-wrong-request', {'requestID': str(uuid.uuid4()).upper()}),
    ('descriptor-wrong-pid', {'processID': native['processID'] + 1}),
    ('descriptor-wrong-complete-flag', {'completeLifetimeCoverage': not native['completeLifetimeCoverage']}),
    ('descriptor-over-bound', {'scope': 'x' * 2049}),
]:
    check(name, lambda mutation=mutation: m.validate_descriptor({'sqliteFetchWaitObservation': {**descriptor, **mutation}},
        companion, path_model, native['requestID'], native['processID']), rejects=True)
unavailable = {'schema': 1, 'status': 'UNAVAILABLE', 'requestID': native['requestID'], 'processID': native['processID'], 'reason': 'actual-write-failure'}
check('unavailable-remains-unavailable', lambda: assert_true(m.validate_descriptor({'sqliteFetchWaitObservation': unavailable},
    None, path_model, native['requestID'], native['processID']) is None))
check('unavailable-cannot-use-old-companion', lambda: m.validate_descriptor({'sqliteFetchWaitObservation': unavailable},
    companion, path_model, native['requestID'], native['processID']), rejects=True)

with tempfile.TemporaryDirectory(prefix='sqlite-wait-source-control-') as directory:
    root = Path(directory).resolve()
    good = root / 'actual.txt'; good.write_bytes(b'bounded-original')
    check('bounded-regular-read', lambda: assert_true(m.read(good, 32) == b'bounded-original'))
    check('read-cap', lambda: m.read(good, 2), rejects=True)
    alias = root / 'alias'; alias.symlink_to(good)
    check('leaf-symlink-refused', lambda: m.read(alias, 32), rejects=True)
    sub = root / 'directory'; sub.mkdir(); (sub / 'file').write_bytes(b'x')
    redirected = root / 'redirected'; redirected.symlink_to(sub, target_is_directory=True)
    check('parent-symlink-refused', lambda: m.read(redirected / 'file', 32), rejects=True)
    check('directory-not-file', lambda: m.read(sub, 32), rejects=True)
    old = m.witness(good)
    good.write_bytes(b'changed-original')
    check('immutable-receipt-mutation-refused', lambda: m.verify_witness(old), rejects=True)
    check('new-evidence-cannot-overwrite', lambda: m.write_new(good, b'x'), rejects=True)

# Synthetic isolated coverage models exercise decisions, not clocks or corpus.
def u(number):
    return str(uuid.UUID(int=number)).upper()


def model():
    a = copy.deepcopy(basic)
    a.update(completed=[], completedRetainedCount=0, lifetimeStarted=0, lifetimeFinished=0,
             snapshotNanoseconds=9_000_000_000, observedUptime=9.0, requestID=u(100), processID=42)
    connection = a['connections'][0]
    connection['capturedNanoseconds'] = 1_000_000_000
    opened = connection['openedFile']
    database = {'path': opened['path'], 'identity': {'device': opened['device'], 'inode': opened['inode'],
                'bytes': opened['bytes'], 'mtimeNs': opened['modifiedNanoseconds']}}
    b = copy.deepcopy(a)
    row = copy.deepcopy(basic['completed'][0])
    row.update(sequence=1, operationID=u(1), beginNanoseconds=12_000_000_000,
               waitStartNanoseconds=12_000_000_100, acquiredNanoseconds=12_000_000_400,
               terminalNanoseconds=13_000_000_000, lockAcquisitionWaitSeconds=0.0000003)
    b.update(completed=[row], completedRetainedCount=1, lifetimeStarted=1, lifetimeFinished=1,
             snapshotNanoseconds=21_000_000_000, observedUptime=21.0, requestID=u(101))
    epoch = {'epoch': u(200), 'processID': 42, 'status': 'OBSERVED_NOT_PERFORMANCE_ACCEPTANCE',
             'resource_start_host_monotonic': 10.0, 'resource_end_host_monotonic': 20.0}
    def capture(value):
        return {'qualification': 'SOURCE_AND_CURRENT_IDENTITY_VALIDATED',
                'clock': {'status': 'ACTUAL_NATIVE_REQUEST_BRACKET_VALIDATED'}, 'snapshot': value,
                'runID': u(300), 'admissionSHA256': 'a' * 64, 'currentIdentity': {'processID': 42, 'corpus': 'SYNTHETIC_MODEL_ONLY'},
                'requestID': value['requestID'], 'epoch': epoch['epoch']}
    return capture(a), capture(b), epoch, database


def decide(modify=None, *, expected=None, qualified=False):
    a, b, epoch, database = model()
    if modify:
        modified = modify(a, b, epoch, database)
        if modified is not None:
            a, b, epoch, database = modified
    result = m.evaluate_epoch(a, b, epoch, database, resolution_ns=1)
    assert result['full_performance_acceptance'] is False
    if qualified:
        assert result['status'] == 'EPOCH_COVERAGE_PROVEN_NOT_PERFORMANCE_ACCEPTANCE', result
    else:
        assert result['status'] == 'NOT_QUALIFIED' and 'metrics' not in result, result
        if expected:
            assert expected in result['reasons'], result
    return result


check('synthetic-fully-bracketed-model-only', lambda: decide(qualified=True))
for name, mutation, reason in [
    ('missing-baseline', lambda a,b,e,d: (None,b,e,d), 'NO_ACTUAL_PRE_EPOCH_BASELINE'),
    ('missing-post-ack-end', lambda a,b,e,d: (a,None,e,d), 'NO_ACTUAL_VALIDATED_POST_ACK_END_CAPTURE'),
    ('unvalidated-original-source', lambda a,b,e,d: b.update(qualification='NOT_VALIDATED'), 'END_NOT_VALIDATED'),
    ('missing-runtime-clock', lambda a,b,e,d: b.update(clock={'status':'NOT_CALIBRATED'}), 'END_CLOCK_NOT_CALIBRATED'),
    ('different-run', lambda a,b,e,d: b.update(runID=u(301)), 'SOURCE_BUILD_OWNER_OR_CORPUS_ADMISSION_CHANGED'),
    ('changed-corpus-image-owner', lambda a,b,e,d: b.update(currentIdentity={'processID':42,'corpus':'changed'}), 'CURRENT_PROCESS_IMAGE_OWNER_OR_CORPUS_CHANGED'),
    ('wrong-process', lambda a,b,e,d: e.update(processID=43), 'PROCESS_CHANGED'),
    ('reused-uuid', lambda a,b,e,d: b.update(requestID=a['requestID']), 'REQUEST_REUSED'),
    ('wrong-epoch', lambda a,b,e,d: b.update(epoch=u(201)), 'WRONG_EPOCH_LINK'),
    ('aborted-original-epoch', lambda a,b,e,d: e.update(status='ABORTED_NOT_ACCEPTED'), 'ORIGINAL_RESOURCE_EPOCH_NOT_COMPLETE'),
    ('end-before-resource-finish', lambda a,b,e,d: b['snapshot'].update(snapshotNanoseconds=19_000_000_000), 'NATIVE_SNAPSHOTS_DO_NOT_BRACKET_THE_ORIGINAL_EPOCH'),
    ('baseline-after-resource-begin', lambda a,b,e,d: a['snapshot'].update(snapshotNanoseconds=11_000_000_000), 'NATIVE_SNAPSHOTS_DO_NOT_BRACKET_THE_ORIGINAL_EPOCH'),
    ('unknown-native-thread', lambda a,b,e,d: b['snapshot']['completed'][0].update(nativeThreadID=None), 'UNKNOWN_NATIVE_THREAD_IDENTITY'),
    ('different-actual-opened-database', lambda a,b,e,d: d['identity'].update(inode=d['identity']['inode']+1), 'IN_EPOCH_CONNECTION_NOT_EXACT_ADMITTED_CORPUS'),
    ('operation-spans-resource-start', lambda a,b,e,d: b['snapshot']['completed'][0].update(beginNanoseconds=9_500_000_000), 'OPERATION_SPANS_OR_TOUCHES_UNCERTAIN_RESOURCE_BOUNDARY'),
    ('operation-touches-uncertain-boundary', lambda a,b,e,d: b['snapshot']['completed'][0].update(beginNanoseconds=10_000_000_000), 'OPERATION_SPANS_OR_TOUCHES_UNCERTAIN_RESOURCE_BOUNDARY'),
]:
    check('coverage-' + name, lambda mutation=mutation, reason=reason: decide(mutation, expected=reason))


def introduce_drop(a,b,e,d):
    b['snapshot'].update(lifetimeStarted=2, lifetimeDropped=1,
                        lifetimeDroppedForActiveCapacity=1, completeLifetimeCoverage=False)
    b['snapshot']['completed'][0]['sequence'] = 2
check('coverage-recent-gap-and-loss-not-filtered', lambda: decide(introduce_drop, expected='NEW_OPERATION_SEQUENCE_COVERAGE_INCOMPLETE'))


def pending(a,b,e,d):
    row = copy.deepcopy(b['snapshot']['completed'][0])
    keep = ('sequence','operationID','connectionID','beginNanoseconds','nativeThreadID','mainThread')
    row = {k:row[k] for k in keep};row.update(sequence=2,operationID=u(2),beginNanoseconds=14_000_000_000)
    b['snapshot'].update(active=[row],activeCount=1,lifetimeStarted=2,completeLifetimeCoverage=False)
check('coverage-pending-at-end-not-zero', lambda: decide(pending, expected='PENDING_OR_SPANNING_OPERATIONS_AT_SNAPSHOT'))


def old_overwrite(a,b,e,d):
    prior = []
    template = copy.deepcopy(b['snapshot']['completed'][0])
    for sequence in range(4,1028):
        row = copy.deepcopy(template)
        row.update(sequence=sequence,operationID=u(sequence),beginNanoseconds=2_000_000_000,
                   waitStartNanoseconds=2_000_000_100,acquiredNanoseconds=2_000_000_400,terminalNanoseconds=3_000_000_000)
        prior.append(row)
    a['snapshot'].update(completed=prior,completedRetainedCount=1024,lifetimeStarted=1027,
                         lifetimeFinished=1027,lifetimeOverwritten=3,completeLifetimeCoverage=False)
    new = b['snapshot']['completed'][0];new.update(sequence=1028,operationID=u(1028))
    b['snapshot'].update(completed=copy.deepcopy(prior[1:])+[new],completedRetainedCount=1024,
                         lifetimeStarted=1028,lifetimeFinished=1028,lifetimeOverwritten=4,completeLifetimeCoverage=False)
check('coverage-prior-ring-history-distinct-from-new-loss-model', lambda: decide(old_overwrite,qualified=True))


def prior_untracked_capacity_drop(a,b,e,d):
    # Exact original recorder semantics permit this visible state: 64 tracked
    # fetches were active, the 65th begin hit activeCapacity and returned nil,
    # and then the first 64 finished. That untracked fetch still executes the
    # ORIGINAL SQL path but its finish(nil) does not record any terminal time.
    # It can remain in SQL across this epoch while both active[] arrays and all
    # lifetime counters below stay unchanged. This is a source-only counterexample,
    # not an injected SQL delay or a claim of a new native execution.
    prior=[];template=copy.deepcopy(b['snapshot']['completed'][0])
    for sequence in range(1,65):
        row=copy.deepcopy(template)
        row.update(sequence=sequence,operationID=u(sequence),beginNanoseconds=2_000_000_000,
                   waitStartNanoseconds=2_000_000_100,acquiredNanoseconds=2_000_000_400,terminalNanoseconds=3_000_000_000)
        prior.append(row)
    for capture in (a,b):
        capture['snapshot'].update(completed=copy.deepcopy(prior),completedRetainedCount=64,
            lifetimeStarted=65,lifetimeFinished=64,lifetimeDropped=1,
            lifetimeDroppedForActiveCapacity=1,completeLifetimeCoverage=False)
check('prior-capacity-dropped-untracked-fetch-can-span-epoch-with-no-counter-change',
      lambda:decide(prior_untracked_capacity_drop,expected='PRIOR_DROPS_CAN_HIDE_UNTRACKED_SPANNING_OPERATIONS'))


def overflow(a,b,e,d):
    a['snapshot'].update(counterOverflowed=True,completeLifetimeCoverage=False)
    b['snapshot'].update(counterOverflowed=True,completeLifetimeCoverage=False)
check('coverage-native-counter-overflow-remains-unqualified',lambda:decide(overflow,expected='COUNTER_OVERFLOW'))


def no_operations(a,b,e,d):
    b['snapshot'].update(completed=[],completedRetainedCount=0,lifetimeStarted=0,lifetimeFinished=0)
check('coverage-measured-empty-interval-needs-real-fences-model', lambda: decide(no_operations,qualified=True))
check('unsupported-linux-clock-does-not-imply-native-equivalence', lambda: m.DarwinClock(), rejects=True)


def rejected_raw_retained(kind):
    # Explicit current-owner/process/clock boundaries isolate the collector's
    # real bounded filesystem copy/rejection behavior. This is not MCM, live
    # corpus, application, clock or UI qualification.
    with tempfile.TemporaryDirectory(prefix='sqlite-wait-retention-model-') as directory:
        root=Path(directory).resolve();docs=root/'Documents';docs.mkdir()
        collector=object.__new__(m.Collector)
        collector.host=SimpleNamespace(active=None,pending_inspector=None,epochs={})
        collector.admission={'owner':{'dataContainer':str(root)}}
        collector.admission_ref={'sha256':'a'*64};collector.run_id=u(900)
        collector.capture_root=root/'captures';collector.capture_root.mkdir()
        collector.seen=set();collector.total_bytes=0;collector.failed_records=[]
        collector._check_identity=lambda: {'processID':native['processID'],'model':'EXPLICIT_SOURCE_CONTROL_BOUNDARY'}
        collector.clock=SimpleNamespace(sample=lambda:{'machUpperNs':10**18},quantum=1,resolution_ns=1)
        collector.clock_ref={'scope':'EXPLICIT_SYNTHETIC_CLOCK_BOUNDARY_NOT_NATIVE'}
        basename='full-v32-reader-'+u(901);request_id=u(902)
        prefix=docs/basename
        paths={key:Path(str(prefix)+suffix) for key,suffix in [('request','.request'),('viewport','.viewport.json'),('companion','.sqlite-fetch-wait.json')]}
        paths['request'].write_text(request_id)
        body=copy.deepcopy(native);body['requestID']=request_id
        if kind=='schema':body['status']='MALFORMED_CONTROL_ONLY'
        raw=json.dumps(body,separators=(',',':')).encode();paths['companion'].write_bytes(raw)
        d={**descriptor,'requestID':request_id,'snapshotPath':str(paths['companion']),'bytes':len(raw),'sha256':m.sha(raw)}
        if kind=='hash':d['sha256']='0'*64
        if kind=='unavailable':d={'schema':1,'status':'UNAVAILABLE','requestID':request_id,'processID':native['processID'],'reason':'control-write-failure'}
        viewport={'requestID':request_id,'sqliteFetchWaitObservation':d}
        paths['viewport'].write_text(json.dumps(viewport))
        request={'viewportBasename':basename,'viewport':viewport,'targetKey':'model-target'}
        if kind=='unavailable':
            ticket=collector.stage_source(request,root)
            assert ticket['snapshot'] is None and 'companion' not in ticket['raw']
            assert not (collector.capture_root/request_id/'sqlite-fetch-wait.json').exists()
        else:
            try:
                collector.stage_source(request,root)
                raise AssertionError('Malformed real-file model accepted')
            except ValueError:
                retained=collector.capture_root/request_id
                assert (retained/'sqlite-fetch-wait.json').read_bytes()==raw
                rejected=m.decode((retained/'capture-rejected.json').read_bytes())
                assert rejected['qualification']=='NOT_VALIDATED' and rejected['full_performance_acceptance'] is False
                assert m.verify_witness(rejected['raw']['companion'])==raw
                assert len(collector.failed_records)==1 and not (retained/'capture.json').exists()


check('bounded-malformed-fresh-schema-retained-before-rejection-model',lambda:rejected_raw_retained('schema'))
check('bounded-fresh-hash-mismatch-retained-before-rejection-model',lambda:rejected_raw_retained('hash'))
check('unavailable-never-reads-or-retains-stale-companion-model',lambda:rejected_raw_retained('unavailable'))


def known_catalog_baseline(kind):
    # Real unchanged original Python source comparator, synthetic tiny text
    # vectors in a temporary directory. No real app/body/corpus attribution.
    with tempfile.TemporaryDirectory(prefix='sqlite-wait-catalog-model-') as directory:
        catalog=Path(directory).resolve()
        targets={}
        for key,text,book in [('away','abcXYZ',2),('target','defUVW',1)]:
            path=catalog/(key+'.txt');path.write_text(text)
            targets[key]={'key':key,'bookID':book,'sourceFile':path.name,'sourceSHA256':m.sha(path.read_bytes()),'sourceUTF16Length':6}
        collector=object.__new__(m.Collector)
        collector.host=SimpleNamespace(targets=targets,catalog={'targets':list(targets.values())},catalog_dir=catalog)
        collector.core=original
        text='abcXYZ' if kind in ('away','corrupted') else ('xxxxxx' if kind=='same-length-no-match' else 'unknown')
        viewport={'requestID':u(930),'source':0,'fullV32SourceObservation':{'schema':1,'status':'AVAILABLE',
            'sourceUTF16Length':len(text),'rangeLocation':0,'rangeLength':len(text),'sourceUTF8':text,
            'processID':42,'observedUptime':1.0}}
        if kind=='corrupted':(catalog/'away.txt').write_text('BADBAD')
        matched,attempts=collector._baseline_source(viewport,{'targetKey':'target','kind':'reader-open'},'target')
        if kind=='away':
            assert matched[0]=='away' and matched[1]['status']=='EXACT_UTF16_RANGE_AND_UTF8_SOURCE_MATCH'
            assert len(attempts)==1 and attempts[0]['status']=='ACTUAL_ORIGINAL_BOUNDED_SOURCE_MATCH'
        else:
            assert matched is None
            if kind=='same-length-no-match':assert len(attempts)==2


check('baseline-genuine-away-order-still-requires-original-byte-comparison-model',lambda:known_catalog_baseline('away'))
check('baseline-legitimate-unknown-reader-remains-unqualified-model',lambda:known_catalog_baseline('unknown'))
check('baseline-same-length-is-not-source-identity-model',lambda:known_catalog_baseline('same-length-no-match'))
check('baseline-corrupted-original-source-oracle-is-hard-rejected-model',lambda:known_catalog_baseline('corrupted'),rejects=True)

# Hook ordering uses explicit Python boundaries, never the Maktabah application.
events = []
class PreviousHost:
    def __init__(self): self.error=None
    def begin(self, request): events.append('original-begin'); return 'original-ACK'
    def end(self, request): events.append('original-end-ACK'); return 'unchanged-end'
    def validate_source(self, request, container): events.append('original-validation-and-retirement'); return {'proof':1}
    def run(self): events.append('original-run')
class CollectorBoundary:
    def __init__(self,core,host): self.out=args.output
    def before_begin(self,request): events.append('idle-baseline')
    def stage_source(self,request,container): events.append('retain-before-overwrite'); return {'ticket':1}
    def accept_source(self,ticket,proof): events.append('qualify-after-original-validation')
    def reject_source(self,ticket,error): events.append('retain-failed-validation')
    def finalize(self): events.append('finalize')
old = m.Collector
try:
    m.Collector = CollectorBoundary
    Combined = m.observation_host(PreviousHost, SimpleNamespace())
    instance = Combined()
    def order():
        assert 'end' not in Combined.__dict__
        assert instance.begin({}) == 'original-ACK'
        assert instance.end({}) == 'unchanged-end'
        assert instance.validate_source({},None)=={'proof':1}
        instance.run()
        assert events==['idle-baseline','original-begin','original-end-ACK','retain-before-overwrite',
            'original-validation-and-retirement','qualify-after-original-validation','original-run','finalize']
    check('explicit-boundary-hook-order-preserves-end-ACK',order)
    def finalization_failure():
        def failed(): raise ValueError('controlled-finalization-failure')
        instance.sqlite_wait_collector.finalize=failed
        instance.run()
        assert instance.error=='SQLiteWaitCollectorFinalizationFailed:ValueError'
        assert m.decode((args.output/'FINALIZATION_FAILED.json').read_bytes())['full_performance_acceptance'] is False
    check('daemon-finalization-failure-reaches-original-host-error-gate',finalization_failure)
finally:
    m.Collector=old

ast.parse(helper.read_text())
report={'schema':1,'status':'SOURCE_ONLY_CONTROLS_NOT_NATIVE_UI_OR_PERFORMANCE_ACCEPTANCE',
        'helper':{'path':str(helper),'bytes':helper.stat().st_size,'sha256':m.sha(helper.read_bytes())},
        'controlSource':{'path':str(Path(__file__).resolve()),'sha256':m.sha(Path(__file__).read_bytes())},
        'originalCommonSource':{'path':str(original_common),'bytes':original_common.stat().st_size,'sha256':m.sha(original_common.read_bytes())},
        'retainedOriginalCommit':'0b445db8a8ee5bc53a1a729c9b65693b51cc88fe',
        'retainedTransferSHA256':m.sha(transfer_raw),'retainedActualResultSHA256':m.sha(actual_result_raw),
        'retainedInputs':inputs,'checks':checks,'passed':sum(x['passed'] for x in checks),'total':len(checks),
        'nativeApplicationExecuted':False,'nativeClockExecuted':False,'productionCorpusRead':False,
        'scope':'Actual retained Apple component bytes are parser inputs only. Descriptor/epoch/order models are explicitly synthetic Python controls; no live admission, source request, Mach clock or UI/PERF acceptance.'}
(args.output/'RESULT.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'passed':report['passed'],'total':report['total'],'failures':[x for x in checks if not x['passed']]}))
raise SystemExit(0 if all(x['passed'] for x in checks) else 1)
