#!/usr/bin/env python3
"""One affected real shell→exec Ruby control; authored fixtures, no Apple/CocoaPods credit."""
import argparse, hashlib, json, os, runpy, shutil, signal, subprocess, sys
from pathlib import Path

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--checkout",required=True);ap.add_argument("--diagnostics",required=True)
    a=ap.parse_args();w=Path(a.checkout);b=Path(a.diagnostics);out=b/"wrapper-control"
    out.mkdir(exist_ok=False)
    portable=json.loads((b/"portable-ruby/ADMISSION.json").read_text())
    ruby=b/"portable-ruby/root/usr/bin/ruby3.2"
    env=dict(os.environ);env.update(portable["environment_overrides"]);os.environ.update(portable["environment_overrides"])
    old="3d0ff5b7043b23b64110c87510ed2e76cbd371ca"
    paths=["Scripts/CI/hq-original-editor-distribution.py","Scripts/CI/hq-original-editor-ruby-context.rb"]
    old_data={p:subprocess.check_output(["runuser","-u","ubuntu","--","git","-C",str(w),"show",old+":"+p]) for p in paths}
    old_module_path=out/"before-driver.py";old_module_path.write_bytes(old_data[paths[0]])
    before=runpy.run_path(str(old_module_path));after=runpy.run_path(str(w/paths[0]))
    result={"scope":"PORTABLE_ACTUAL_SHELL_EXEC_RUBY_MECHANISM_ONLY","apple_cocoapods_native":"NOT_RUN",
            "status":"RUNNING","required":1,"passed":0,"assertions":0,"commands":[],
            "before_source":old,"after_inputs":{p:{"bytes":(w/p).stat().st_size,"sha256":sha(w/p)} for p in paths},
            "old_six_controls":"NOT_REPLAYED; retained at3d0ff5b source"}
    def check(v,message):
        result["assertions"]+=1
        if not v:raise AssertionError(message)
    def save(): (out/"RESULT.json").write_text(json.dumps(result,indent=2)+"\n")
    def cmd(argv,environment,cwd,label):
        so,se=out/(label+".stdout"),out/(label+".stderr")
        with so.open("wb") as o,se.open("wb") as e:
            p=subprocess.Popen(argv,cwd=cwd,env=environment,stdout=o,stderr=e,start_new_session=True)
            timed=False
            try:p.wait(timeout=30)
            except subprocess.TimeoutExpired:
                timed=True;os.killpg(p.pid,signal.SIGTERM)
                try:p.wait(timeout=5)
                except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait(timeout=5)
        try:os.killpg(p.pid,0);drained=False
        except ProcessLookupError:drained=True
        result["commands"].append({"command":list(map(str,argv)),"label":label,"pid":p.pid,"returncode":p.returncode,
            "timed_out":timed,"child_reaped":p.poll() is not None,"owned_group_drained":drained,
            "stdout_sha256":sha(so),"stderr_sha256":sha(se)})
        save();check(not timed and drained and p.poll() is not None,"Owned control process did not drain")
        return p.returncode,p.pid
    def fixture(label,observer_bytes,module):
        root=out/label;scripts=root/"Scripts/CI";scripts.mkdir(parents=True)
        source=b/"controls-1/same-context"
        shutil.copytree(source/"gems",root/"gems")
        shutil.copyfile(source/"Scripts/CI/hq-original-editor-app-target.rb",scripts/"hq-original-editor-app-target.rb")
        (scripts/"hq-original-editor-ruby-context.rb").write_bytes(observer_bytes)
        (root/"bin").mkdir();(root/"libexec/bin").mkdir(parents=True)
        entry=root/"libexec/bin/pod";shutil.copyfile(source/"bin/pod",entry)
        # This is an actual shell wrapper and actual exec, not an argv-only mock.
        wrapper=root/"bin/pod"
        wrapper.write_text("#!/bin/sh\nexec '"+str(ruby)+"' '"+str(entry)+"' \"$@\"\n")
        wrapper.chmod(0o755)
        (root/"Podfile.lock").write_text("COCOAPODS: 0.0.1\n")
        output=root/"build/hq-stage2";output.mkdir(parents=True)
        environment=dict(env);environment.update(PATH=str(root/"bin")+os.pathsep+env.get("PATH",""),
            GEM_HOME=str(root/"gems"),GEM_PATH=str(root/"gems"),RUBYOPT="-W0")
        os.environ.update({k:environment[k] for k in ["PATH","GEM_HOME","GEM_PATH","RUBYOPT"]})
        context=module["prepare_pod_ruby_context"](root,output)
        context["environment"].update(FIXTURE_GEMS=str(root/"gems"),
            FIXTURE_HELPER_MARKER=str(root/"helper-called.json"),FIXTURE_HELPER_EXIT="0")
        return root,wrapper,entry,context
    try:
        root,wrapper,entry,context=fixture("before",old_data[paths[1]],before)
        rc,pid=cmd(["pod","install"],context["environment"],root,"before-exec-wrapper")
        check(rc==0,"Original authored pod body did not succeed through shell exec")
        check(not Path(context["receipt_path"]).exists(),"Old program predicate unexpectedly admitted exec wrapper")
        try:before["admit_pod_ruby_context"](root,context,rc)
        except RuntimeError as e:
            check("Missing" in str(e),"Old failure was not the actual missing receipt boundary")
            result["old_predicate_error"]=str(e)
        else:check(False,"Old predicate did not refuse missing runtime receipt")
        root,wrapper,entry,context=fixture("after",(w/paths[1]).read_bytes(),after)
        rc,pid=cmd(["pod","install"],context["environment"],root,"after-exec-wrapper")
        check(rc==0,"Candidate observer disrupted original shell exec")
        proof=after["admit_pod_ruby_context"](root,context,rc)
        receipt=json.loads(Path(proof["receipt_path"]).read_text())
        check(receipt["pid"]==pid and receipt["parent_pid"]==os.getpid(),"Observed Ruby is not the actual owned parent command")
        check(receipt["program"]["path"]==str(wrapper.resolve()) and
              receipt["ruby_entry"]["path"]==str(entry.resolve()) and
              receipt["program"]["path"]!=receipt["ruby_entry"]["path"],
              "Actual launched source and Ruby entry were not distinguished")
        argv,launch_env=after["original_editor_ruby_launch"](root,proof,["project","plan","configuration"])
        launch_env.update(FIXTURE_HELPER_MARKER=str(root/"helper-called.json"),FIXTURE_HELPER_EXIT="0")
        rc,_=cmd(argv,launch_env,root,"after-exact-runtime-helper")
        check(rc==0 and (root/"helper-called.json").is_file(),"Captured runtime did not run unchanged helper fixture")
        (root/"helper-called.json").unlink()
        entry.write_bytes(entry.read_bytes()+b"# actual entry drift\n")
        try:after["original_editor_ruby_launch"](root,proof,["project","plan","configuration"])
        except RuntimeError as e:check("entry changed" in str(e),"Actual entry drift refused for wrong reason")
        else:check(False,"Changed actual Ruby entry reached helper")
        rc,_=cmd(argv,launch_env,root,"ruby-entry-drift-refusal")
        check(rc!=0 and not (root/"helper-called.json").exists(),"Ruby launcher did not independently refuse entry drift")
        result["status"]="PASS";result["passed"]=1
    except BaseException as e:
        result["status"]="FAIL";result["error"]={"type":type(e).__name__,"message":str(e)}
        raise
    finally:
        save();print(json.dumps({k:result[k] for k in ["status","scope","passed","required","assertions"]},indent=2))
        print("RESULT_SHA256",sha(out/"RESULT.json"))

if __name__=="__main__":main()
