import pathlib,json,hashlib,subprocess,zipfile,stat,datetime
repo=pathlib.Path(r'C:\Users\DAVID\Code\Maktabah-completion-20261122')
packet=pathlib.Path(r'C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live7-artifact-20261122')
out=pathlib.Path(r'C:\Users\DAVID\AppData\Local\Temp\otzaria-continuation-20261122\live7_root_review.json')
head='d14f845f2b0760ce8d3bf186ca656db57f435f9f'
checkout='77c7df82ef5f822bf0b1dd7e08ff2b4b98d425d2'
app='0ea7218331d1441d37d06d43333e579f267056e3'
sha=lambda b:hashlib.sha256(b).hexdigest()
def need(v,m):
 if not v: raise AssertionError(m)
def git(*a): return subprocess.check_output(['git','-c','core.autocrlf=false',*a],cwd=repo)
need(git('rev-parse','HEAD').decode().strip()==head,'canonical head')
need(not git('status','--porcelain=v1').strip(),'canonical dirty')
need(not out.exists(),'review receipt already exists')
ib=(packet/'FILE_INDEX.json').read_bytes()
need(sha(ib)=='96b582b77ecee01b05cfd0c79d542c1ca4379c9953674899df17dd7f8a14e662','frozen index')
idx=json.loads(ib)
need(idx['schema']==1 and len(idx['files'])==28,'payload count')
seen=set()
for rec in idx['files']:
 name=rec['path']; pp=pathlib.PurePosixPath(name)
 need(not pp.is_absolute() and '..' not in pp.parts and '\\' not in name and name not in seen,'unsafe/duplicate payload')
 seen.add(name); data=(packet/name).read_bytes()
 need(len(data)==rec['bytes'] and sha(data)==rec['sha256'],'payload '+name)
actual={p.relative_to(packet).as_posix() for p in packet.rglob('*') if p.is_file()}
need(actual==seen|{'FILE_INDEX.json'},'packet extras/missing')
need(sum(r['bytes'] for r in idx['files'])==456797,'payload bytes')
archive=packet/'artifact-14743563942.zip'
ab=archive.read_bytes(); need(len(ab)==87598 and sha(ab)=='13b8464d57769bce384436b68c5b5230248f7fbcde189f2d84d9f365942aed35','archive identity')
artifact=json.loads((packet/'artifact-api.json').read_bytes()); run=json.loads((packet/'run-api.json').read_bytes())
need(artifact['id']==14743563942 and artifact['size_in_bytes']==len(ab) and artifact['digest']=='sha256:'+sha(ab),'API digest')
need(artifact['workflow_run']['id']==44993301949 and artifact['workflow_run']['head_sha']==checkout,'artifact run')
need(run['id']==44993301949 and run['run_attempt']==1 and run['head_sha']==checkout and run['status']=='completed' and run['conclusion']=='failure','terminal run')
with zipfile.ZipFile(archive) as z:
 infos=z.infolist(); need(len(infos)==22 and z.testzip() is None,'ZIP CRC/count')
 zn=set()
 for i in infos:
  p=pathlib.PurePosixPath(i.filename)
  need(not i.is_dir() and not p.is_absolute() and '..' not in p.parts and '\\' not in i.filename and i.filename not in zn and not stat.S_ISLNK(i.external_attr>>16),'ZIP entry')
  zn.add(i.filename)
  need(z.read(i)==(packet/'extracted'/i.filename).read_bytes(),'extracted '+i.filename)
ad=json.loads((packet/'extracted/admission.json').read_bytes())
need(ad['status']=='SCANNED_ALLOWLIST_ONLY' and len(ad['files'])==21 and set(ad['files'])|{'admission.json'}==zn,'admission allowlist')
for n,r in ad['files'].items():
 b=(packet/'extracted'/n).read_bytes(); need(len(b)==r['bytes'] and sha(b)==r['sha256'],'admission '+n)
need(all(ad[x] is True for x in ['private_input_removed','provider_file_excluded','raw_video_excluded','raw_xcresult_and_attachments_excluded']),'privacy admission')
bb=(packet/'extracted/source-before.json').read_bytes(); ba=(packet/'extracted/source-after.json').read_bytes()
need(bb==ba and sha(bb)=='de99e8605f2e1645454b2a9312a95fa474ab405739172f73a97ed58a40226bc8','source before/after')
source=json.loads(bb); ver=json.loads((packet/'SOURCE_VERIFICATION.json').read_bytes())
need(source['checkout_sha']==checkout and source['application_source_sha']==app and source['reviewed_source_sha']==app,'source identity')
need(len(source['execution_inputs'])==281,'input count')
records=source['execution_inputs']
need({r['path']:{k:r[k] for k in ['blob','bytes','sha256']} for r in ver['executionInputs']}==records,'independent verification index')
paths=list(records)
res=subprocess.run(['git','cat-file','--batch'],cwd=repo,input=(''.join(checkout+':'+p+'\n' for p in paths)).encode(),capture_output=True,timeout=90,check=True)
pos=0
for p in paths:
 end=res.stdout.index(b'\n',pos); header=res.stdout[pos:end].decode().split(); need(len(header)==3 and header[1]=='blob','Git blob '+p)
 size=int(header[2]); pos=end+1; b=res.stdout[pos:pos+size]; pos+=size
 need(res.stdout[pos:pos+1]==b'\n','batch delimiter');pos+=1
 r=records[p]; need(header[0]==r['blob'] and size==r['bytes'] and sha(b)==r['sha256'],'immutable Git input '+p)
need(pos==len(res.stdout),'batch remainder')
trees={'Source':'ac887bdbfbfce2d30d9591bb867d61b11da31cc6','Vendor':'4065c0e62af325e83a65fe0c70270985229807ae','Maktabah.xcodeproj':'8c0fa1ccfbcfae01fae3c267512864e00efcf078','Maktabah-iOSUITests':'24345d612f8c70398f4590977f8b4696021ae413'}
for p,want in trees.items():
 for ref in [checkout,app,head]:
  need(git('rev-parse',ref+':'+p).decode().strip()==want,'product tree '+p+' '+ref)
need(len(source['binaries'])==5 and source['binaries']==ver['recordedBinaryDigestsStable'],'recorded binary stability')
need(source['original_build_status']=='SIMULATOR_BUILD_FOR_REAL_UI_PASS','original build')
summary=json.loads((packet/'extracted/verified-11.summary.json').read_bytes())
need(tuple(summary[k] for k in ['totalTestCount','passedTests','failedTests','skippedTests'])==(1,0,1,0),'case counts')
need(summary['testFailures'][0]['failureText']=='XCTAssertTrue failed - The original native dismissal must issue the source-qualified read session','actual failure')
details=json.loads((packet/'extracted/original-test-details.json').read_bytes())
need(details['testResult']=='Failed' and details['durationInSeconds']==78.00888001918793,'case execution')
need(len(details['devices'])==1 and details['devices'][0]['modelName']=='iPad Pro 11-inch (M5)' and details['devices'][0]['osVersion']=='27.2','device')
result=json.loads((packet/'extracted/result.json').read_bytes())
need(result['status']=='FAIL' and result['verified_completed_provider_conversations']==0,'Live result')
for k in ['private_input_staged','private_input_consumed','private_input_removed','prior_artifacts_restored']: need(result[k] is True,k)
for k in ['credential_in_child_environment','credential_in_test_arguments','raw_container_or_result_bundle_published','native116_acceptance','release114_acceptance']:need(result[k] is False,k)
need(result['log_redactions']==0,'redactions')
life=json.loads((repo/'build/hanlin-live7-lifecycle/lifecycle.json').read_bytes())
cleanup=json.loads((repo/'build/hanlin-live7-lifecycle/cleanup.json').read_bytes())
need(life['state']==cleanup['state']=='DELETED_AND_ABSENCE_VERIFIED' and life['secret_cleanup_required'] is False,'cleanup state')
need(cleanup['delete_http_status']==204 and cleanup['after_http_status']==404 and cleanup['run_id']==44993301949 and cleanup['checkout_sha']==checkout,'cleanup proof')
need(cleanup['before_metadata']==life['metadata'] and cleanup['before_metadata']['created_at']==cleanup['before_metadata']['updated_at']=='2026-11-22T06:20:41Z','cleanup ownership')
need(life['observed_run']['head_sha']==checkout and life['observed_run']['run_attempt']==1 and life['observed_run']['conclusion']=='failure','observed terminal')
controller=pathlib.Path(r'C:\Users\DAVID\AppData\Local\Temp\otzaria-continuation-20261122\live7_lifecycle_77c7.py')
need(sha(controller.read_bytes())==life['controller_sha256']=='a434659cbf0e3ac4f678bf2ee514af3e7398e1e9314cf5380e904fd12d092637','controller')
need(git('rev-parse','HEAD').decode().strip()==head and not git('status','--porcelain=v1').strip(),'canonical unchanged')
proof={'status':'PASS','scope':'Independent evidence verification only; no test, build, download, credential or CI action','createdUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'canonicalHead':head,'checkout':checkout,'applicationSource':app,'run':44993301949,'attempt':1,'runConclusion':'failure','packetPayloadCount':28,'packetPayloadBytes':456797,'packetIndexSHA256':sha(ib),'zipSafeCRCFiles':22,'admittedFiles':21,'executionGitBlobsVerified':281,'fourProductTrees':trees,'beforeAfterBytesIdentical':True,'runnerRecordedStableBinaryDigests':5,'binaryBoundary':'Binary bytes excluded from artifact; no independent local binary-byte verification','caseCounts':{'total':1,'passed':0,'failed':1,'skipped':0},'caseDurationSeconds':details['durationInSeconds'],'completedProviderConversations':0,'cleanup':cleanup,'scriptSHA256':sha(pathlib.Path(__file__).read_bytes())}
out.write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'status':'PASS','receipt':str(out),'receiptSHA256':sha(out.read_bytes()),'script':str(pathlib.Path(__file__)),'scriptSHA256':proof['scriptSHA256'],'verifiedPayloads':28,'verifiedGitInputs':281,'caseCounts':proof['caseCounts'],'secretAbsent':True}))
