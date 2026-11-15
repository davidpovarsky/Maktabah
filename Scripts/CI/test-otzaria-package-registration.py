"""Adversarial graph checks for local packages versus explicit app sources."""
from pathlib import Path
import json, re, runpy, subprocess, sys, tempfile

root = Path(__file__).resolve().parents[2]
text = (root/'Maktabah.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
parse = runpy.run_path(str(root/'docs/hq-integration/verify_source_registration.py'))['parse']
project, _ = parse(text)
objects = project['objects']
target_id = 'F30576DD2FA46222005732C6'
target = objects[target_id]
product = next(p for p in target['packageProductDependencies'] if objects[p]['productName']=='OtzariaActionCore')
framework_id = next(p for p in target['buildPhases'] if objects[p]['isa']=='PBXFrameworksBuildPhase')
source_id = next(p for p in target['buildPhases'] if objects[p]['isa']=='PBXSourcesBuildPhase')
linked = next(p for p in objects[framework_id]['files'] if objects[p].get('productRef')==product)
source_ref = next(p for p,v in objects.items() if v.get('path')=='Actions/Integration/ActionLiveBackendBridge.swift')
source_build = next(p for p in objects[source_id]['files'] if objects[p].get('fileRef')==source_ref)

def remove_item(identity, item):
    pattern = re.compile(r'(\t\t'+identity+r' /\*[^\n]*\*/ = \{\n)(.*?)(\n\t\t\};)',re.S)
    match = pattern.search(text)
    assert match
    body, count = re.subn(r'^[ \t]*'+item+r' /\*[^\n]*\*/,\n','',match[2],count=1,flags=re.M)
    assert count==1
    return text[:match.start(2)]+body+text[match.end(2):]

cases = {'baseline':(text,0),
    'product_not_on_app':(remove_item(target_id,product),1),
    'product_not_linked':(remove_item(framework_id,linked),1),
    'wrong_package_root':(text.replace('relativePath = Source/Otzaria/Actions;','relativePath = Source/Otzaria/Wrong;',1),1),
    'missing_integration_source':(remove_item(source_id,source_build),1),
    'package_not_on_project':(remove_item(project['rootObject'],objects[product]['package']),1)}
host_products = [p for p in target['packageProductDependencies'] if objects[p]['productName']=='ChavrusaUIRoutingHost']
if host_products:
    host_product = host_products[0]
    host_link = next(p for p in objects[framework_id]['files'] if objects[p].get('productRef')==host_product)
    host_ref = next(p for p,v in objects.items() if v.get('path')=='Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift')
    host_build = next(p for p in objects[source_id]['files'] if objects[p].get('fileRef')==host_ref)
    cases.update({
        'host_product_not_on_app':(remove_item(target_id,host_product),1),
        'host_product_not_linked':(remove_item(framework_id,host_link),1),
        'host_integration_source_missing':(remove_item(source_id,host_build),1),
        'wrong_host_package_root':(text.replace('relativePath = Source/ChavrusaText/UIRoutingHost;','relativePath = Source/ChavrusaText/Wrong;',1),1)})
outcomes=[]
with tempfile.TemporaryDirectory(prefix='otzaria-registration-') as temp:
    for name,(candidate,expected) in cases.items():
        path=Path(temp)/(name+'.pbxproj')
        path.write_text(candidate,encoding='utf-8')
        result=subprocess.run([sys.executable,str(root/'Scripts/CI/verify-otzaria-xcode-project.py'),'--project-path',str(path)],capture_output=True,text=True)
        passed=(result.returncode==0)==(expected==0)
        outcomes.append({'case':name,'exit':result.returncode,'expected_success':expected==0,'passed':passed})
        if not passed:
            print(result.stdout+result.stderr,file=sys.stderr)
print(json.dumps(outcomes,indent=2))
assert all(item['passed'] for item in outcomes)
