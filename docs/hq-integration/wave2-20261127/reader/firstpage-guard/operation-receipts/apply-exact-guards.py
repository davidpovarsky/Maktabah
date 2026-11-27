import subprocess,pathlib,json,hashlib,datetime,os
w=pathlib.Path("/mnt/development/projects/worktrees/Maktabah-wave2-firstpage-guard-20261127")
path="Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneBindings.swift"
p=w/path;g=["git","-c","gc.auto=0","-C",str(w)]
base="15d283aa0ccbbfe6966f26a2c182810cb39fdafa"
assert subprocess.check_output(g+["rev-parse","HEAD"]).decode().strip()==base
assert subprocess.check_output(g+["status","--porcelain=v1"])==b""
b=p.read_bytes();assert hashlib.sha256(b).hexdigest()=="607f0a9abd68b361a609f59725d798deda6566c8327ed43996521b8638591079"
needle=b"@MainActor final class MaktabahNativeSearchResultsBinding {"
assert b.count(needle)==1
prefix,body=b.split(needle,1)
replacements=[
 (b"              session.cancellationRevision == initialCancellation else {",b"              session.cancellationRevision == initialCancellation,\n              session.paginationRevision == initialPagination else {"),
 (b"                  session.paginationRevision == initialPagination,\n",b""),
 (b"        guard submissionRevision != nil, session.hasSubmitted, !session.isSearching,\n",b"        guard submissionRevision != nil, session.hasSubmitted, !session.isSearching, !session.isLoadingMore,\n")]
cbody=body
for old,new in replacements:
 assert cbody.count(old)==1,(old,cbody.count(old))
 cbody=cbody.replace(old,new,1)
candidate=prefix+needle+cbody
assert candidate.split(needle,1)[0]==prefix
d=w/"docs/hq-integration/wave2-20261127/reader/firstpage-guard"
assert not d.exists()
assert os.statvfs(w).f_bavail*os.statvfs(w).f_frsize>696254464
d.mkdir(parents=True)
(d/"baseline.swift").write_bytes(b)
p.write_bytes(candidate)
(d/"candidate.swift").write_bytes(candidate)
patch=subprocess.check_output(g+["diff","--binary","--",path])
(d/"SOURCE.patch").write_bytes(patch)
proof={"schema":1,"utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"base":base,"path":path,"baselineBytes":len(b),"baselineSHA256":hashlib.sha256(b).hexdigest(),"candidateBytes":len(candidate),"candidateSHA256":hashlib.sha256(candidate).hexdigest(),"patchSHA256":hashlib.sha256(patch).hexdigest(),"unchangedPrefixBytes":len(prefix),"unchangedPrefixSHA256":hashlib.sha256(prefix).hexdigest(),"reverseReplacementReproducesBaseline":True,"scope":"only three exact textual replacements implementing two guards inside original binding; no behavioral execution"}
reverse=cbody
for old,new in reversed(replacements):
 if new:
  assert reverse.count(new)==1
  reverse=reverse.replace(new,old,1)
 else:
  anchor=b"            guard session.submissionRevision == initialSubmission,\n"
  assert reverse.count(anchor)==1
  reverse=reverse.replace(anchor,anchor+old,1)
assert prefix+needle+reverse==b
(d/"PRESERVATION.json").write_text(json.dumps(proof,indent=2)+"\n")
check=subprocess.run(g+["diff","--check","--",path],capture_output=True,text=True,timeout=15)
print(json.dumps({"proof":proof,"sourceDiff":patch.decode(),"diffCheck":{"exit":check.returncode,"stdout":check.stdout,"stderr":check.stderr}}))
