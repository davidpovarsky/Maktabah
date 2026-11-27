from pathlib import Path
import base64, gzip, hashlib, json

r = Path(__file__).resolve().parent
pin = lambda b: {"bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}
old = (r / "HiddenGroupControls.swift").read_text()
assert pin(old.encode())["sha256"] == "b5020058854f01bd39e40109f493b22f6ce1460fab04c04a02866e5231616632"
(r / "PreservedAttempt4HiddenGroupControls.swift").write_text(old)
s = old
fixture_edits = []
def fixture_change(before, after):
    global s
    assert s.count(before) == 1
    s = s.replace(before, after, 1)
    fixture_edits.append({"before": before, "after": after})

fixture_change('''        if !counter {
''', '''        if CommandLine.arguments.contains("--annotation-fixture") {
            await test("explicit_annotation_boundary_nil_to_nil_does_not_emit") {
                let f=try hidden(),tab=try selected(f);var calls=0
                watch({tab.viewModel.annotationEvent}){calls += 1}
                tab.viewModel.annotationEvent=nil
                try require(calls==0,"actual Observation equal optional Int fixture does not emit")
            }
            await test("explicit_annotation_boundary_existing_event_clear_emits_once") {
                let f=try hidden(),tab=try selected(f);var calls=0
                tab.viewModel.annotationEvent=91
                watch({tab.viewModel.annotationEvent}){calls += 1}
                tab.viewModel.annotationEvent=nil
                try require(calls==1,"existing fixture event clear invokes exactly one callback")
            }
            return
        }
        if !counter {
''')
fixture_change('''                let f=try hidden(),tab=try selected(f),b=try f.retain();defer{b.release()};try await f.prepare(b)
                watch({_ = tab.viewModel.annotationEvent}){b.release()}
''', '''                let f=try hidden(),tab=try selected(f)
                tab.viewModel.annotationEvent=91
                let b=try f.retain();defer{b.release()};try await f.prepare(b)
                watch({_ = tab.viewModel.annotationEvent}){b.release()}
''')
fixture_change('''                let f=try hidden(),tab=try selected(f),b=try f.retain();defer{b.release()};try await f.prepare(b)
                watch({tab.viewModel.annotationEvent}) {
''', '''                let f=try hidden(),tab=try selected(f)
                tab.viewModel.annotationEvent=91
                let b=try f.retain();defer{b.release()};try await f.prepare(b)
                watch({tab.viewModel.annotationEvent}) {
''')
(r / "HiddenGroupControls.swift").write_text(s)
fixture = {"path": "HiddenGroupControls.swift", **pin(s.encode()),
           "gzipBase64": base64.b64encode(gzip.compress(s.encode(), mtime=0)).decode()}
runner_before = (r / "run_attempt4.py").read_text()
t = runner_before
edits = []
def change(before, after):
    global t
    assert t.count(before) == 1
    t = t.replace(before, after, 1)
    edits.append({"before": before, "after": after})
change("HOME/'attempt-4'", "HOME/'attempt-5'")
change(" result['compiler']={'path':str(SWIFT),**pin(SWIFT)};", ''' fixture = json.loads(''' + repr(json.dumps(fixture)) + ''')
 b=gzip.decompress(base64.b64decode(fixture['gzipBase64']))
 assert pin(inputs/'controls/common/HiddenGroupControls.swift')['sha256']=='b5020058854f01bd39e40109f493b22f6ce1460fab04c04a02866e5231616632'
 assert len(b)==fixture['bytes'] and sha(b)==fixture['sha256']
 (inputs/'diagnostic/PreservedAttempt4HiddenGroupControls.swift').write_bytes((inputs/'controls/common/HiddenGroupControls.swift').read_bytes())
 (inputs/'controls/common/HiddenGroupControls.swift').write_bytes(b)
 result['fixtureEdits'].append({k:v for k,v in fixture.items()if k!='gzipBase64'})
 result['annotationFixtureScope']='Only an existing event is seeded BEFORE retained capture in the three callback cases. Original product and all prior after-effect assertions are unchanged. Diagnostic explicitly proves the optional Int domain-shell equality behavior; it does not claim actual ReaderAnnotationEvent equality semantics.'
 previousCompleted=HOME/'attempt-4';previousRun=json.loads((previousCompleted/'run-candidate.stdout').read_text())
 assert previousRun['pass']==19 and previousRun['fail']==3
 result['previousCompleted']={'result':pin(previousCompleted/'RESULT.json'),'stdout':pin(previousCompleted/'run-candidate.stdout'),'stderr':pin(previousCompleted/'run-candidate.stderr'),'pass':19,'fail':3}
 result['compiler']={'path':str(SWIFT),**pin(SWIFT)};''')
change("  try:run('run-'+kind,[str(output/(kind+'-controls'))]+flags,timeout=40)", '''  run('run-annotation-fixture',[str(output/(kind+'-controls')),'--annotation-fixture'],timeout=15)
  result['annotationFixture']=json.loads((attempt/'run-annotation-fixture.stdout').read_text());assert result['annotationFixture']['pass']==2 and result['annotationFixture']['fail']==0
  try:run('run-'+kind,[str(output/(kind+'-controls'))]+flags,timeout=40)''')
(r / "run_attempt5.py").write_text(t)
proof = {"runnerBefore": pin(runner_before.encode()), "runnerAfter": pin(t.encode()), "edits": edits,
         "fixtureBefore": pin(old.encode()), "fixtureAfter": pin(s.encode()), "fixtureEdits": fixture_edits,
         "productChanged": False, "priorAssertionsChanged": False}
(r / "attempt5-delta.json").write_text(json.dumps(proof, indent=2) + "\n")
print(json.dumps({k:v for k,v in proof.items() if k not in ["edits", "fixtureEdits"]}))
