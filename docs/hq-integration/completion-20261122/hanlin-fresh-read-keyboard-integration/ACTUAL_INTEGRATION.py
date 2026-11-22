import pathlib, subprocess, hashlib, json, datetime, sys
root=pathlib.Path(r"C:\Users\DAVID\Code\Maktabah-completion-20261122")
base="895bbcb54f86be0fc0463d7ed9d78f3599d6bdd2"
right="cad3742628a37ad4f9eaa3cdbd522d70cb6d0bd1"
temp=pathlib.Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-continuation-20261122")
out=temp/"fresh-keyboard-canonical-integration-01";out.mkdir(exist_ok=False)
(out/"ACTUAL_INTEGRATION.py").write_bytes(pathlib.Path(__file__).read_bytes())
commands=[]
def h(raw):return hashlib.sha256(raw).hexdigest()
def g(label,*args,allowed=(0,)):
 p=subprocess.run(["git","-c","core.autocrlf=false","-c","core.eol=lf","-C",str(root),*args],capture_output=True,timeout=120)
 (out/(label+".stdout")).write_bytes(p.stdout);(out/(label+".stderr")).write_bytes(p.stderr)
 commands.append({"label":label,"arguments":list(args),"returncode":p.returncode,"stdout_sha256":h(p.stdout),"stderr_sha256":h(p.stderr)})
 (out/"COMMANDS.json").write_bytes((json.dumps(commands,indent=2)+"\n").encode())
 if p.returncode not in allowed:raise RuntimeError(label+" failed")
 return p
try:
 assert g("head-before","rev-parse","HEAD").stdout.decode().strip()==base
 assert not g("clean-before","status","--porcelain=v1").stdout
 assert g("branch-before","branch","--show-current").stdout.decode().strip()=="codex/otzaria-completion-20261122"
 exists=g("exact-candidate-object","cat-file","-e",right+"^{commit}",allowed=(0,128))
 if exists.returncode:
  g("fetch-published-candidate","fetch","--no-tags","origin","codex/otzaria-hanlin-fresh-read-keyboard-evidence-20261122")
  assert g("exact-fetched-head","rev-parse","FETCH_HEAD").stdout.decode().strip()==right
 assert g("candidate-base","merge-base",base,right).stdout.decode().strip()==base
 reviewdir=temp/"fresh-keyboard-root-admission"
 reviewraw=(reviewdir/"ROOT_REVIEW.json").read_bytes()
 assert h(reviewraw)=="690f0dec0cc4fa25257ba344901b21677f34b28f15b895e04bf795b06eea63cf"
 review=json.loads(reviewraw);assert review["head"]==right and review["status"]=="PASS_FOR_ONE_NO_SEND_NATIVE_DIAGNOSTIC"
 assert review["source_evidence_payloads_verified"]==51 and review["execution_inputs_independently_git_verified"]==279
 product={"Source":"91c1adf6c97cd8676e8b2c76860a40f78924b1ec","Vendor":"4065c0e62af325e83a65fe0c70270985229807ae","Maktabah.xcodeproj":"8c0fa1ccfbcfae01fae3c267512864e00efcf078","Maktabah-iOSUITests":"86f07db3f58fe6d73c063b02ae3c1d31ae2d2468"}
 for name,oid in product.items(): assert g("candidate-tree-"+name.replace(".","-"),"rev-parse",right+":"+name).stdout.decode().strip()==oid
 testpaths=g("exact-test-delta","diff","--name-only",base,right,"--","Maktabah-iOSUITests").stdout.decode().splitlines()
 assert len(testpaths)==1
 assert h(g("exact-test-source","show",right+":"+testpaths[0]).stdout)=="9413eed5741bf3fec8b6c97da86ecb6caed026c7f9e85d80219beb57d037b0a7"
 report=root/"docs/hq-integration/completion-20261122/CONTINUATION_STATUS.md"
 old=report.read_bytes()
 assert h(old)=="d556e46104797b873f26a6658d45a63973a36a6ccd6b6e1af4db3710b0095bb5"
 g("merge-admitted-candidate","merge","--no-ff","--no-commit",right)
 assert not g("unmerged-after-merge","ls-files","-u").stdout
 candidate_tree=g("candidate-full-tree","rev-parse",right+"^{tree}").stdout.decode().strip()
 assert g("exact-merged-index-tree","write-tree").stdout.decode().strip()==candidate_tree
 g("commit-source-merge","commit","-m","merge(otzaria): integrate admitted native keyboard diagnostic and failure evidence [skip ci]")
 merge=g("source-merge-head","rev-parse","HEAD").stdout.decode().strip()
 assert g("source-merge-parents","show","-s","--format=%P","HEAD").stdout.decode().split()==[base,right]
 assert g("source-merge-tree","rev-parse","HEAD^{tree}").stdout.decode().strip()==candidate_tree
 observed=datetime.datetime.now(datetime.timezone.utc).isoformat()
 proofrel="docs/hq-integration/completion-20261122/hanlin-fresh-read-keyboard-integration"
 proof=root/proofrel;proof.mkdir(exist_ok=False)
 for p in reviewdir.rglob("*"):
  if p.is_file():
   t=proof/"root-admission"/p.relative_to(reviewdir);t.parent.mkdir(parents=True,exist_ok=True);t.write_bytes(p.read_bytes())
 (proof/"ACTUAL_INTEGRATION.py").write_bytes((out/"ACTUAL_INTEGRATION.py").read_bytes())
 (proof/"MERGE_COMMANDS.json").write_bytes((out/"COMMANDS.json").read_bytes())
 admission={"status":"SOURCE_AND_EVIDENCE_INTEGRATED_NATIVE_OUTCOME_PENDING","observed_at":observed,"merge_commit":merge,"parents":[base,right],"exact_candidate_tree":candidate_tree,"all_merged_git_entries_equal_candidate":True,"application_test_snapshot":"d49cedb3d5c163b7a008248d94b80a2eda28e3ce","product_trees":product,"original_root_admission_sha256":h(reviewraw),"published_candidate_payloads_verified_by_original_review":51,"execution_inputs_verified_by_original_review":279,"source_test_change":"12 native keyboard-hide lines only; original consent/Connect/reopen/revocation assertions retained","new_tests_compilers_downloads":0,"native_run":"45014115643","native_attempt":1,"native_checkout":right,"sole_observer":"job_795c24b6c364","scope":"Source and evidence union. No actual result for this run is admitted by the merge."}
 (proof/"INTEGRATION.json").write_bytes((json.dumps(admission,indent=2)+"\n").encode())
 (proof/".gitattributes").write_bytes(b"* -text\n**/*.py whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n")
 (proof/"README.md").write_bytes(("""# Native fresh-read keyboard diagnostic integration

The exact admitted candidate cad3742628a37ad4f9eaa3cdbd522d70cb6d0bd1 is integrated by true merge """+merge+""". The complete merged Git tree equals the candidate tree, including the retained first failure and source evidence. Business Source, Vendor and project trees are unchanged; only 12 reviewed UI-test lines hide the actual observed native keyboard and await its absence before the original assertions.

Root admission690f0dec verified all51 source payloads, all279 original execution Git inputs, exact inverse, full-file parse, source-only preparation and Host48 evidence reuse before dispatch. It is retained byte-for-byte. This integration did not rerun any test, compiler, preflight or download. The original focused Native run45014115643 owns its result, under sole observerjob_795c24b6c364.

The earlier run45006363282 failed its strict consent hit-test before Connect. The actual AX observed a keyboard; a later PNG did not show it, so neither pixel-proved occlusion nor a Live8 root cause is claimed. Current Native acceptance remains pending its measured result.
""").encode())
 index={p.relative_to(proof).as_posix():{"bytes":p.stat().st_size,"sha256":h(p.read_bytes())} for p in sorted(proof.rglob("*")) if p.is_file()}
 (proof/"INDEX.json").write_bytes((json.dumps({"files":index,"payload_count":len(index)},indent=2,sort_keys=True)+"\n").encode())
 top=f"""# Otzaria / Maktabah — current development checkpoint

Snapshot packaged at {observed}. This is the report packaging time; each result below retains its own observed source and time. Current sections above the historical snapshot supersede its older in-progress wording. No product task, full Native, Release or original-editor acceptance is declared complete.

## Current source integration

The canonical Maktabah branch is [codex/otzaria-completion-20261122](https://github.com/davidpovarsky/Maktabah/tree/codex/otzaria-completion-20261122). True merge [{merge}](https://github.com/davidpovarsky/Maktabah/commit/{merge}) integrates the exact candidate [cad3742628a37ad4f9eaa3cdbd522d70cb6d0bd1](https://github.com/davidpovarsky/Maktabah/commit/cad3742628a37ad4f9eaa3cdbd522d70cb6d0bd1), including the published prior failure ae9f63 and the reviewed 12-line native keyboard correction at application/test snapshot d49cedb3. The whole merged Git tree equals cad374. [Root integration](hanlin-fresh-read-keyboard-integration/INTEGRATION.json) retains admission690f0dec: all51 payloads, all279 execution Git inputs, exact source inverse, one complete parse, source preparation and Host48 reuse. No test, compiler, preflight or artifact download was repeated for this integration.

| Product tree | Exact current Git tree |
|---|---|
| Source | 91c1adf6c97cd8676e8b2c76860a40f78924b1ec |
| Vendor | 4065c0e62af325e83a65fe0c70270985229807ae |
| Maktabah.xcodeproj | 8c0fa1ccfbcfae01fae3c267512864e00efcf078 |
| Maktabah-iOSUITests | 86f07db3f58fe6d73c063b02ae3c1d31ae2d2468 |

[Native run45014115643](https://github.com/davidpovarsky/Maktabah/actions/runs/45014115643), attempt1, was created10:47:14UTC on cad374 after one push. Sole finite observerjob_795c24b6c364 and eventual single artifact intake belong to native_completion. The measured result is pending admission. Its only selected case is HanlinReaderConsumerAcceptanceTests/testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending. It uses the actual observed keyboard label Hide keyboard, a unique normal native tap and bounded keyboard absence before the unchanged consent/Connect/reopen/revocation assertions. It requires no temporary Live key and never calls Send.

The earlier [run45006363282](https://github.com/davidpovarsky/Maktabah/actions/runs/45006363282) is now terminal FAILURE: exactly0PASS/1FAIL/0SKIP,88.018757seconds, at the original line294 consent hit-test before consent tap or Connect. Original app/UI build and exact Host48 reuse passed; owned cleanup passed. Its complete once-downloaded result is retained in [the terminal packet](hanlin-fresh-read-terminal/raw). The actual AX and failed hit-test are bound to the result. The later PNG has no visible keyboard, so no pixel-proved keyboard occlusion or Live8 root cause is inferred.

## Original Anytype integration and SDK

Canonical original-source integration is now [c81f758ea071a6c8d79eb342cd0410c4ebcb63ad](https://github.com/davidpovarsky/anytype-swift/commit/c81f758ea071a6c8d79eb342cd0410c4ebcb63ad). It retains the previous original Owner/Participant/Space/held-read work, the selected-space repair and the new shared account-release completion seam. Selected-space source6ac09d/packet172c639 was true-merged through7cc89c and published58651e. Exactly10 new selected-space Swift Testing cases passed once; root independently verified all91 actual retained execution payloads, fresh10-case XML, all4 actual command receipts, compiled/original inputs and the emitted executable. The original post-test evidence-wrapper RED and its corrections were retained without replaying tests.

The shared release source15ea8755, exact SHA25665a20edfdacbb8c5a51d647b2746a16f75ca9865984026cca5b6235f4fa4933e, was published with actual six-case PASS evidence at18668c3e, then true-merged72d816c7. [Root review and integration](https://github.com/davidpovarsky/anytype-swift/tree/c81f758ea071a6c8d79eb342cd0410c4ebcb63ad/docs/pinkha/torah-integration/evidence/account-release-root-admission-20261122) verifies138 changed Git blobs,121 packet payloads, all3 successful commands, actual executable PID4420 and stable executable SHAad8035e5. The sole execution completed10:53:04UTC on Windows Swift6.3.3/Swift5 language with strict concurrency. finishAndWaitForRelease waits for actual admitted native drain plus completed release effects. Its Void return does not certify an account token, subscriptions or real Auth startup. Full Auth/LoginState/Hanlin exact-attempt/cancellation integration remains in implementation.

The composed SDK branch is now [b5162d777e3ebc5c4c0d044e02b52347c0c3dd6e](https://github.com/davidpovarsky/anytype-swift/commit/b5162d777e3ebc5c4c0d044e02b52347c0c3dd6e), pushed and remotely verified. True source mergesbfaa404e/0d643c40 join the original lifecycle source37f, producer5c1d and selected-space586; true merge0f6a98d1 adds canonicalc81f. All11,377 entries of that last union were checked, with no conflicts. [Source-union evidence](https://github.com/davidpovarsky/anytype-swift/tree/b5162d777e3ebc5c4c0d044e02b52347c0c3dd6e/docs/pinkha/torah-integration/evidence/composed-sdk-source-union-20261122) and [account-release union](https://github.com/davidpovarsky/anytype-swift/tree/b5162d777e3ebc5c4c0d044e02b52347c0c3dd6e/docs/pinkha/torah-integration/evidence/composed-sdk-account-release-20261122) retain actual commands/scripts/trees. These merges reran no component tests and do not qualify a combined SDK binary.

[Producer run45009422605](https://github.com/davidpovarsky/anytype-swift/actions/runs/45009422605) is terminal FAILURE. It built the actual original framework09:50:40–10:06:24UTC, passed the actual public/SPI surface gate and221 source controls, then failed the separate binary consumer at exit65 because six original Clang modules were unavailable: CAtomic, cmark_gfm, cmark_gfm_extensions, iosMath, FirebaseCore and FirebaseMessaging. The once-downloaded artifact14749911866 retains source evidence and diagnostics; it does not retain the original distribution/binary/swiftmodule, so an invented binary-only continuation is not available. Packaging correction is under full review: authentic compiler-selected19 module maps, pinned original header declarations, exact path-only generated-map relocation, exported-only search roots, explicit producer identity/inventory binding and separately labeled unqualified-product retention. The strict public gate and qualified-only artifact policy remain. One actual combined build remains necessary after reviewed source freeze.

## Heart and StageB

[Heart V6 run45012913358](https://github.com/davidpovarsky/anytype-swift/actions/runs/45012913358), attempt1 at [d8ea2be0f42e51b35001c35509dd27c9035c3c66](https://github.com/davidpovarsky/anytype-swift/commit/d8ea2be0f42e51b35001c35509dd27c9035c3c66), failed10:37:41UTC with actual18PASS/2FAIL/0SKIP after the original package compiled. The original per-tree key derivation and genuine LocalOnly ACL fixture now exercise their intended native paths, including the four previously masked negative cases. Remaining ActualLocalZeroCounterAccepted and NativeComputedRemoteCounterAccepted fail the final full fixed-schema observation with ErrFixedSchemaChanged/Changed. Actual row differences were not logged, so asynchronous head/storage mutation is a hypothesis, not established cause. The single artifact14751201046 was downloaded once, digest7e8890542a45c77d8c268f6c274a65652a118cb14633da90b1938e3b4fd231ea. A passive recorder and bounded fresh-observation fixture for only those two cases are being reviewed. The18 passed cases and earlier strict12 remain excluded; no V7 run is admitted.

StageB same-account process-relaunch source is concrete but not executed. The frozen SDK v3 uses the single shared release seam; original final Auth methods; genuine add-only SecureService storage; an exact private one-attempt checkpoint; WalletRecover then AccountSelect.localOnly; and the existing imported account/Space/object. The actual reopened Host is checked and the original owner drains UI/native writes before sealing. Exact owned credential cleanup covers failures and explicit Close; successful preparation intentionally retains it for the next process, where consumption deletes it before recovery. Peer source review found and corrected pending-write, cleanup and replaceable-Auth-service gaps. The matching Maktabah caller/UI/test and two-process evidence collector are being completed and reviewed. No second wallet/account/Space/object/import is authorized by resume. Distinct positive actual process IDs, durable annotation UUID/body/context and mixed Hebrew/English blocks still require real Native execution after a qualified SDK.

## Remaining acceptance and external blockers

No full116 Native, Release114 plus2 independent oracles across five configurations, physical-iPad, TestFlight VALID/internal availability or signed-device acceptance is complete. Historical focused passes remain bound to their original source; Release24-hour freshness must be measured against the final qualified source. The SDK path currently targets Debug Simulator, with Release/device embedding and production Auth/AppGroup integration separate.

Full native snapshot/body semantic comparison, source mapping/schema creation and COMMIT/identity ACK remain incomplete; nativeSnapshotDigest stays nil. A local saved archive/body digest and an ObjectView/root-detail observation do not establish semantic native body equality. The r14 codec's exact11 local metadata exclusions are source-audited only. Authentic owner Ed25519 keys/signatures, a physical Apple execution bridge and the authoritative Books7-row/6-column backend/schema/database/migration contract are still unavailable. No key, signature, backend contract or acceptance receipt was fabricated. The retained inventory has31 open product tasks of49; the completed administrative handoff is separate.

## Requested runs and Live-secret state

The requested [Native44969361774](https://github.com/davidpovarsky/Maktabah/actions/runs/44969361774) and [HanlinLive44969637013](https://github.com/davidpovarsky/Maktabah/actions/runs/44969637013) were checked and retained as failures. Native executed3PASS/3FAIL; Live stopped at its locator assertion before consent, Connect or provider completion. Later diagnostic results and their exact source limits are retained below.

Every temporary OTZARIA_LIVE_GEMINI_API_KEY instance used in the four retained Live attempts was deleted after its owned terminal run with DELETE204 and subsequent GET404. The most recent Live8 cleanup was08:40:19.546333UTC, independently rechecked absent08:41:10.195829UTC. [Cleanup](hanlin-live8-lifecycle/SECRET_CLEANUP.json) and [independent absence](hanlin-live8-lifecycle/ROOT_SECRET_ABSENCE.json) remain unchanged. All Live lifecycle owners are terminal; the current no-Send Native diagnostic creates no Live secret.

## Historical checkpoint retained verbatim

The following10:04UTC snapshot is retained as source-bound history. Its in-progress/current language describes that earlier observation and is superseded by the current sections above.

---

"""
 report.write_bytes(top.encode()+old)
 assert report.read_bytes().endswith(old)
 g("stage-report-proof","add","--",proofrel,report.relative_to(root).as_posix())
 changed=g("staged-doc-paths","diff","--cached","--name-only","-z").stdout.decode().strip("\0").split("\0")
 assert all(p.startswith(proofrel+"/") or p==report.relative_to(root).as_posix() for p in changed)
 g("doc-diff-check","diff","--cached","--check")
 g("commit-report-proof","commit","-m","docs(otzaria): integrate focused Native evidence and refresh current acceptance status [skip ci]")
 head=g("final-head","rev-parse","HEAD").stdout.decode().strip()
 assert not g("final-clean","status","--porcelain=v1").stdout
 result={"status":"COMMITTED_EXACT_CANDIDATE_AND_CURRENT_REPORT_PENDING_PUSH","head":head,"source_merge":merge,"candidate":right,"proof_payloads":len(index),"proof_index_sha256":h((proof/"INDEX.json").read_bytes()),"report_sha256":h(report.read_bytes()),"report_packaged_at":observed,"old_report_retained_verbatim_sha256":h(old),"tests_compilers_preflights_downloads_repeated":0,"native_result":"NOT_CLAIMED_PENDING_OWNER"}
except BaseException as e:
 result={"status":"FAIL","type":type(e).__name__,"error":str(e),"traceback":__import__("traceback").format_exc()}
 (out/"RESULT.json").write_bytes((json.dumps(result,indent=2)+"\n").encode());print(json.dumps(result));sys.exit(1)
(out/"RESULT.json").write_bytes((json.dumps(result,indent=2)+"\n").encode())
print(json.dumps(result))
