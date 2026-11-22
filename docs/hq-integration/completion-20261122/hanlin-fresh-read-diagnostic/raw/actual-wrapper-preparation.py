from pathlib import Path
import subprocess,json,hashlib,difflib,datetime
repo=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-fresh-read-diagnostic-20261122")
base="ce5d11335c4b4769a25e0e8f48ba1d6f7efc6749"
temp=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-fresh-read-diagnostic-20261122")
replacements={
"Scripts/CI/completion-focused-native.py":[
('"""One original consent switch diagnostic; no credentials or full-phase acceptance."""','"""One fresh-read no-key native diagnostic; no Send or full-phase acceptance."""'),
('SOURCE = "0ea7218331d1441d37d06d43333e579f267056e3"','SOURCE = "PENDING_FRESH_READ_TEST_SOURCE"'),
("HanlinReaderConsumerAcceptanceTests/testOriginalIPadCurrentWorkConsentToggleWithoutConnection","HanlinReaderConsumerAcceptanceTests/testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending"),
("One original no-credential consent switch diagnostic; the three Native4 PASS cases remain separate immutable evidence; full Native116/Release114 remain unaccepted","One original fresh empty-conversation read diagnostic with explicit unused form values and no Send; prior Native PASS cases remain separate immutable evidence and are not replayed; full Native116/Release114 remain unaccepted"),
('"FOCUSED_CONSENT_ONLY"','"FOCUSED_FRESH_READ_NO_SEND_ONLY"'),
("The single original consent diagnostic must execute and pass","The single original fresh-read diagnostic must execute and pass")],
".github/workflows/otzaria-completion-focused-native.yml":[
("name: Original consent switch focused native diagnostic","name: Original fresh-read no-send native diagnostic"),
("branches: [codex/otzaria-completion-consent-native-20261122]","branches: [codex/otzaria-hanlin-fresh-read-diagnostic-20261122]"),
("name: One app build and one original consent diagnostic","name: One app build and one original fresh-read diagnostic"),
("name: Execute one original consent diagnostic without rebuilding or provider credentials","name: Execute one original fresh-read diagnostic without rebuilding or a provider key")]
}
files=[]
for path,rs in replacements.items():
 old=subprocess.check_output(["git","show",base+":"+path],cwd=repo);assert (repo/path).read_bytes()==old
 new=old
 for a,b in rs:
  assert new.count(a.encode())==1,(path,a);new=new.replace(a.encode(),b.encode(),1)
 inverse=new
 for a,b in reversed(rs):assert inverse.count(b.encode())==1;(a,b);inverse=inverse.replace(b.encode(),a.encode(),1)
 assert inverse==old
 (repo/path).write_bytes(new)
 label="DRIVER" if path.endswith(".py") else "WORKFLOW"
 (temp/(label+"_PREIMAGE")).write_bytes(old);(temp/(label+"_CANDIDATE")).write_bytes(new)
 diff="".join(difflib.unified_diff(old.decode().splitlines(keepends=True),new.decode().splitlines(keepends=True),fromfile="a/"+path,tofile="b/"+path)).encode()
 (temp/(label+".patch")).write_bytes(diff)
 files.append({"path":path,"preimageSHA256":hashlib.sha256(old).hexdigest(),"candidateSHA256":hashlib.sha256(new).hexdigest(),"patchSHA256":hashlib.sha256(diff).hexdigest(),"exactInverse":True,"replacements":rs})
receipt={"schema":"otzaria.fresh-read-one-case-wrapper-draft/1","status":"DRAFT_SOURCE_PLACEHOLDER_NOT_EXECUTABLE","base":base,"branch":"codex/otzaria-hanlin-fresh-read-diagnostic-20261122","selector":"HanlinReaderConsumerAcceptanceTests/testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending","cases":1,"files":files,"buildDriverCollectorsBinariesCleanupRetained":True,"priorPassedSelectorsAbsent":True,"nativeExecuted":False}
(temp/"WRAPPER_DRAFT.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf8",newline="\n")
(temp/"actual-wrapper-preparation.py").write_bytes(Path(__file__).read_bytes())
print(json.dumps(receipt))