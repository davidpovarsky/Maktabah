import pathlib,subprocess,json,hashlib,datetime
w=pathlib.Path("/mnt/development/projects/worktrees/Maktabah-wave2-firstpage-guard-20261127")
path="Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneBindings.swift"
p=w/path; d=w/"docs/hq-integration/wave2-20261127/reader/firstpage-guard"
g=["git","-c","gc.auto=0","-C",str(w)]
base="15d283aa0ccbbfe6966f26a2c182810cb39fdafa"
assert subprocess.check_output(g+["rev-parse","HEAD"]).decode().strip()==base
old_candidate=p.read_bytes()
assert hashlib.sha256(old_candidate).hexdigest()=="70d64d593d22dbfb512b74bd8d6ed9d259c9404b8a47072ced30f5bc18d989a2"
assert old_candidate==(d/"candidate.swift").read_bytes()
b=(d/"baseline.swift").read_bytes();assert b==subprocess.check_output(g+["show",base+":"+path])
replacements=[
(b"            guard session.submissionRevision == submissionRevision, session.query.utf8.elementsEqual(query.search.text.utf8),\n",b"            guard session.submissionRevision == submissionRevision, session.query.utf8.elementsEqual(query.search.text.utf8),\n                  session.paginationRevision == initialPagination,\n"),
(b"        guard submissionRevision != nil, session.hasSubmitted, !session.isSearching,\n",b"        guard submissionRevision != nil, session.hasSubmitted, !session.isSearching, !session.isLoadingMore,\n")]
candidate=b
for old,new in replacements:
 assert candidate.count(old)==1
 candidate=candidate.replace(old,new,1)
reverse=candidate
for old,new in reversed(replacements):
 assert reverse.count(new)==1
 reverse=reverse.replace(new,old,1)
assert reverse==b
assert not (d/"candidate-final.swift").exists()
p.write_bytes(candidate);(d/"candidate-final.swift").write_bytes(candidate)
patch=subprocess.check_output(g+["diff","HEAD","--binary","--",path]);(d/"SOURCE_FINAL.patch").write_bytes(patch)
begin=b.index(b"    func validate() throws {",b.index(b"@MainActor final class MaktabahNativeSearchResultsBinding"))
branch=b.index(b"        if let submissionRevision {",begin)
pre=b[b.index(b"        } else {",branch):b.index(b"    func apply(",branch)]
assert candidate[begin:candidate.index(b"        if let submissionRevision {",begin)]==b[begin:branch]
assert pre==candidate[candidate.index(b"        } else {",candidate.index(b"        if let submissionRevision {",begin)):candidate.index(b"    func apply(",begin)]
proof={"schema":1,"utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"base":base,"path":path,"supersedesUncommittedCandidateSHA256":hashlib.sha256(old_candidate).hexdigest(),"baselineSHA256":hashlib.sha256(b).hexdigest(),"candidateBytes":len(candidate),"candidateSHA256":hashlib.sha256(candidate).hexdigest(),"patchSHA256":hashlib.sha256(patch).hexdigest(),"originalCommonGuardByteIdentical":True,"originalPreSubmissionBranchByteIdentical":True,"reverseTwoReplacementsReproducesWholeBaseline":True,"refinementReason":"Root review preserves original pre-submit error code and guard priority by adding pagination equality only to post-submit branch; final no-loading-more guard retained","behavioralValidation":"NOT_RUN"}
(d/"PRESERVATION_FINAL.json").write_text(json.dumps(proof,indent=2)+"\n")
print(json.dumps({"proof":proof,"patch":patch.decode()}))