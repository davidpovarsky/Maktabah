from pathlib import Path
import subprocess,json,hashlib,datetime
temp=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-fresh-read-diagnostic-20261122")
repos={
"Maktabah":(Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-fresh-read-diagnostic-20261122"),"ce5d11335c4b4769a25e0e8f48ba1d6f7efc6749"),
"Hanlin":(Path(r"C:\Users\DAVID\Code\hanlin-ai"),"e00498e33f106cc43be0476ffa2e09329c8ca300"),
"SwiftAISDK":(Path(r"C:\Users\DAVID\Code\swift-ai-sdk"),"e7bf34111e603ca977becd007dd4e5bb109af857")}
paths={
"Maktabah":["Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift","Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatOwner.swift","Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinHostAdapter.swift","Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatView.swift","Scripts/CI/hq-stage2-focused-apple.inputs.json"],
"Hanlin":["Packages/HanlinPlatform/Package.resolved","Packages/HanlinPlatform/Sources/HanlinChatCore/HanlinAISDKAgentEngine.swift","Packages/HanlinPlatform/Sources/HanlinChatCore/HanlinAISDKProviderFactory.swift","Packages/HanlinPlatform/Sources/HanlinChatCore/HanlinNonEmptyLanguageModel.swift","Packages/HanlinAgentSDK/Sources/HanlinAgentCore/HanlinAgentSession.swift","Packages/HanlinAgentSDK/Sources/HanlinAgentCore/HanlinHostDispatcher.swift","Packages/HanlinAgentSDK/Sources/HanlinHostContracts/HanlinHostContext.swift"],
"SwiftAISDK":["Sources/OpenAICompatibleProvider/OpenAICompatibleProvider.swift","Sources/OpenAICompatibleProvider/Chat/OpenAICompatibleChatLanguageModel.swift"]}
records=[]
for kind,files in paths.items():
 repo,ref=repos[kind]
 for path in files:
  b=subprocess.check_output(["git","show",ref+":"+path],cwd=repo)
  blob=subprocess.check_output(["git","rev-parse",ref+":"+path],cwd=repo).decode().strip()
  dest=temp/"source-audit"/kind/path;dest.parent.mkdir(parents=True,exist_ok=True);assert not dest.exists();dest.write_bytes(b)
  records.append({"repository":kind,"commit":ref,"path":path,"gitBlob":blob,"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest(),"retained":dest.relative_to(temp).as_posix()})
proof={"schema":"otzaria.fresh-read-no-send-source-audit/1","status":"SOURCE_REVIEWED_NOT_EXECUTED","utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"files":records,"facts":[
{"source":"Maktabah/OtzariaHanlinChatSession.swift","anchors":"320-375,378-387","finding":"Configure validates the original owner and immutable carried request, constructs engine, activates connection, revalidates host context and constructs AgentSession. It does not call stream, doGenerate, doStream or fetch."},
{"source":"Hanlin/HanlinAISDKAgentEngine.swift","anchors":"40-50","finding":"Constructor only stores configuration and resolves the provider/model."},
{"source":"Hanlin/HanlinAISDKProviderFactory.swift","anchors":"114-177,211-230","finding":"Google-compatible URL selects openAICompatible under app company OPENAI; resolve builds model configuration. makeFetch constructs URLSession and returns a closure; session.bytes(for:) is inside that closure, not the constructor."},
{"source":"SwiftAISDK/OpenAICompatibleProvider.swift","anchors":"55-75,147-213,300-312","finding":"Factory builds captured settings and synchronous model factory; chatModel constructs only the model/configuration."},
{"source":"SwiftAISDK/OpenAICompatibleChatLanguageModel.swift","anchors":"146-150,941-944;161-176,264-289","finding":"Initializers assign model/configuration; provider HTTP begins in async doGenerate/doStream."},
{"source":"Hanlin/HanlinNonEmptyLanguageModel.swift","anchors":"9-11","finding":"Wrapper initializer only retains its base model."},
{"source":"Hanlin/HanlinAgentSession.swift + HanlinHostDispatcher.swift","anchors":"63-73;30","finding":"Initializers retain dependencies and dispatcher host; they do not launch a producer Task or provider request."},
{"source":"Maktabah/OtzariaHanlinChatSession.swift","anchors":"390-425","finding":"App send creates streaming work and invokes agent.stream. The new diagnostic never taps Send or enters text in the composer."},
{"source":"Maktabah/OtzariaHanlinChatView.swift + OtzariaHanlinChatSession.swift","anchors":"56-65;165,198-203","finding":"End-access header is conditional only on the immutable currentWorkReadScope, outside the configured/transcript branch. Live8 proves that scope is passed to a mounted/configured reopened session but does not expose actual AX/rendering."},
{"source":"Hanlin/HanlinHostContext.swift","anchors":"93-99","finding":"Each reopened session uses a new UUID by default; conversationID reuse is distinct from presentation identity."}],
"diagnosticScope":"One fresh original read connection using Google-compatible URL and explicit unused form model/key. No genuine provider key, private Live input, Send/history workaround, product guard/identifier change or success fallback.",
"limits":["Static original-source path audit only; no instrumented whole-application network-silence claim.","No native UI case has executed for this candidate.","Existing Live8 artifact remains a failure; configuration completion is not provider conversation acceptance.","No raw credentialed AX or screenshot is copied; proposed Native capture uses only nonsecret dummy values."]}
p=temp/"NO_PROVIDER_REQUEST_SOURCE_AUDIT.json";p.write_text(json.dumps(proof,indent=2)+"\n",encoding="utf8",newline="\n")
(temp/"actual-no-send-source-audit.py").write_bytes(Path(__file__).read_bytes())
print(json.dumps({"path":str(p),"sha256":hashlib.sha256(p.read_bytes()).hexdigest(),"sourceFiles":len(records),"sourceBytes":sum(r["bytes"] for r in records),"status":proof["status"]}))