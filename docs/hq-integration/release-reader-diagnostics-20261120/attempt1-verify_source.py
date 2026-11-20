#!/usr/bin/env python3
"""Exact source preservation and original Python collector only; no Swift/UI test."""
from pathlib import Path
import ast, hashlib, json, re

R=Path(__file__).resolve().parent
checks=[]
def check(name, ok):
    checks.append({'name':name,'passed':bool(ok)})
    if not ok: raise RuntimeError(name)
def text(root,path): return (R/root/path).read_text()
HOST='Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeSceneNavigationOrchestrator.swift'
APP='Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift'
VIEW='Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift'
for source in ['SOURCE_AUTHORITY.json','UNCHANGED_AUTHORITY.json']:
    for x in json.loads((R/source).read_text()):
        b=(R/'base'/x['path']).read_bytes()
        check('Git blob: '+x['path'],hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==x['gitBlob'])

h=text('candidate',HOST); a=text('candidate',APP); v=text('candidate',VIEW)
property_block=re.search(r'\n    #if DEBUG\n    /// Passive, default-off evidence.*?\n    #endif\n',h,re.S)
check('one declared DEBUG observation block',property_block is not None)
outer='''            #if DEBUG
            observeDebugFailure(error, boundary: .readerPlan, invocation: originalInvocation,
                                coreStarted: phase.coreStarted)
            #endif
'''
inner='''            #if DEBUG
            observeDebugFailure(error, boundary: .nativeCommit, invocation: command.invocation,
                                didDispatch: didDispatch)
            #endif
'''
check('one reader catch observation',h.count(outer)==1)
check('one native catch observation',h.count(inner)==1)
restored=h.replace(property_block.group(),'\n').replace(outer,'').replace(inner,'')
check('whole original orchestrator inverse including all guards catches returns budgets',restored==text('base',HOST))

app_block=re.search(r'        #if DEBUG\n        let diagnosticArguments.*?        #endif\n',a,re.S)
check('one app DEBUG opt-in block',app_block is not None)
check('whole original composition inverse including cold Core and Hanlin',a.replace(app_block.group(),'')==text('base',APP))
check('observer installed only after full registry initialization',a.index('        ])')<a.index('orchestrator.debugFailureObserver ='))
check('exact miniTest10 + commentary + UUID gate',all(s in app_block.group() for s in [
    'OtzariaDataProfileRegistry.activeProfileID == "miniTest10"',
    'diagnosticValue("-nativeActionAcceptanceKind") == "commentary"',
    'diagnosticValue("-nativeActionAcceptanceToken")', 'UUID(uuidString: rawToken) != nil']))
check('default optional observer and early return before clock',
    'public var debugFailureObserver: (@MainActor (DebugFailureObservation) -> Void)?' in h
    and h.index('guard let observer = debugFailureObserver else { return }')<h.index('let now = clock.now()'))
new=property_block.group()+outer+inner+app_block.group()
check('no task scheduling or raw error export in diagnostic additions',not any(x in new for x in ['Task {','Task.detached','DispatchQueue','localizedDescription','String(describing:', 'String(reflecting:']))
check('fixed code fallback and monotonic observation captured before sink',
    'allowedCodes.contains($0)' in new and '"other_fixed_failure"' in new
    and 'uptimeNanoseconds: now' in new and 'deadlineExpired: now >= invocation.deadlineUptimeNanoseconds' in new)
check('log contains no raw token source route query or scene ID',
    all(x not in next(s for s in app_block.group().splitlines() if 'OtzariaFileLogger.shared.log' in s)
        for x in ['rawToken','sceneID','requestId','query','destination','workKey','error']))

new_policy='''            // The shared-sidebar Inspector overlays the existing Reader at
            // every iPad width; it must never reserve a second host column.
            return true'''
old_policy='            return detailColumnWidth < 430 + Self.minimumPanelWidth + 18'
check('one shared-owner overlay policy change',v.count(new_policy)==1)
restored=v.replace(new_policy,old_policy).replace(
    '// changes; the original Inspector floats over that surface.',
    '// changes; only the inspector moves between docking/floating.')
check('whole original Reader workspace inverse incl text selection notes layout state',restored==text('base',VIEW))
check('legacy nil-owner predicate exact',
    '        return useWideLayout && librarySidebarIsOpen && contentsIsOpen\n' in v)
check('original FloatingPanel configuration and docked host condition unchanged',all(s in v for s in [
    'if showPanel && !(sidebarCoordinator != nil && shouldPresentPanelInContent)',
    'isEnabled: sidebarCoordinator != nil,', 'isFloating: shouldPresentPanelInContent,',
    '.floatingPanelContentMode(.fitToBounds)', '.floatingPanelLayout(StudyContentFloatingPanelLayout())']))

collector=text('base','Scripts/CI/run-faithful-ipad-matrix.py')
tree=ast.parse(collector)
node=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='requires_native_log_collection')
namespace={};exec(compile(ast.Module(body=[node],type_ignores=[]),'<exact original collector function>','exec'),namespace)
function=namespace[node.name]
for selection,expected in [
    (['NativeRoutingAcceptanceTests/testCoreCommentaryOpensVerifiedSourceLinkAndPreservesBaseOnPad'],True),
    (['NativeRoutingPhoneAcceptanceTests/testCoreCommentaryOpensVerifiedSourceLinkAndPreservesBaseOnPhone'],True),
    (['OtherTests/testCoreCommentaryOpensVerifiedSourceLinkAndPreservesBaseOnPad'],False),
    (['XNativeRoutingAcceptanceTests/testCoreCommentaryOpensVerifiedSourceLinkAndPreservesBaseOnPad'],False)]:
    check('executed original Python collector: '+selection[0],function(selection) is expected)
check('original collector retains persistent file after failed executed case result',
    'device["status"] = "EXECUTED_PASS" if code == 0 else "FAIL"' in collector
    and collector.index('device["status"] = "EXECUTED_PASS" if code == 0 else "FAIL"')<collector.index('if requires_native_log_collection(selection):')
    and 'Documents/OtzariaLogs/otzaria-reader.log' in collector and 'shutil.copyfile(actual_log, retained_log)' in collector)
result={'scope':'Git/source inverse and actual original Python collector function only','checks':checks,
    'passed':sum(x['passed'] for x in checks),'failed':sum(not x['passed'] for x in checks),
    'swift_compile':'NOT_RUN','apple_typecheck':'NOT_RUN','native_execution':0,
    'source_base':'064987c44a5b4ba8d2500c03bc6beba3e34f78e5'}
(R/'evidence/SOURCE_CHECKS.json').write_text(json.dumps(result,sort_keys=True,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='checks'},sort_keys=True))
