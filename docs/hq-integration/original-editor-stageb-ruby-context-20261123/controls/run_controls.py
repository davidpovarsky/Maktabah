#!/usr/bin/env python3
"""Real portable Ruby mechanics with authored local gem fixtures; no CocoaPods/Apple qualification."""
import argparse
import ast
import copy
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import signal
import subprocess
import sys
import time

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--checkout", required=True)
    ap.add_argument("--ruby-admission", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()
    checkout, out = Path(args.checkout), Path(args.output)
    out.mkdir(parents=True, exist_ok=False)
    package_receipt = json.loads(Path(args.ruby_admission).read_text())
    assert package_receipt["status"] == "PORTABLE_RUBY_EXECUTED"
    ruby = Path(args.ruby_admission).parent / "root/usr/bin/ruby3.2"
    environment = dict(os.environ)
    environment.update(package_receipt["environment_overrides"])
    os.environ.update(package_receipt["environment_overrides"])
    sdk_path = checkout / "Scripts/CI/hq-original-editor-distribution.py"
    common_path = checkout / "Scripts/CI/hq-stage2-focused-apple.py"
    observer = checkout / "Scripts/CI/hq-original-editor-ruby-context.rb"
    sdk = runpy.run_path(str(sdk_path))
    common = runpy.run_path(str(common_path))
    result = {"scope": "PORTABLE_RUBY_AND_PYTHON_MECHANISM_CONTROLS_ONLY",
              "apple_cocoapods_native": "NOT_RUN", "fixture_gems_are_authored": True,
              "status": "RUNNING", "controls": [], "assertions": 0, "commands": [],
              "source": {str(p.relative_to(checkout)): {"bytes": p.stat().st_size, "sha256": sha(p)}
                         for p in [sdk_path, common_path, observer]},
              "portable_ruby_admission_sha256": sha(args.ruby_admission)}

    def save():
        (out / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")

    def check(value, message):
        result["assertions"] += 1
        if not value:
            raise AssertionError(message)

    def rejects(operation, message):
        try:
            operation()
        except Exception as error:
            check(True, message)
            return type(error).__name__
        check(False, message)

    def command(argv, *, env, cwd, label, timeout=30):
        stdout, stderr = out / (label + ".stdout"), out / (label + ".stderr")
        started = time.monotonic()
        timed_out = False
        with stdout.open("wb") as stream, stderr.open("wb") as error_stream:
            process = subprocess.Popen(argv, cwd=cwd, env=env, stdout=stream, stderr=error_stream,
                                       start_new_session=True)
            try:
                process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)
        try:
            os.killpg(process.pid, 0)
            drained = False
        except ProcessLookupError:
            drained = True
        row = {"command": list(map(str, argv)), "label": label, "returncode": process.returncode,
               "timed_out": timed_out, "child_reaped": process.poll() is not None,
               "owned_group_drained": drained, "elapsed_seconds": time.monotonic() - started,
               "stdout": {"path": stdout.name, "bytes": stdout.stat().st_size, "sha256": sha(stdout)},
               "stderr": {"path": stderr.name, "bytes": stderr.stat().st_size, "sha256": sha(stderr)}}
        result["commands"].append(row)
        save()
        check(not timed_out and row["child_reaped"] and drained, "Control command did not actually drain")
        return process.returncode, stdout.read_text(), stderr.read_text()

    def fixture(name):
        root = out / name
        scripts, bin_dir, gems = root / "Scripts/CI", root / "bin", root / "gems"
        scripts.mkdir(parents=True)
        bin_dir.mkdir()
        (gems / "specifications").mkdir(parents=True)
        shutil.copyfile(observer, scripts / observer.name)
        helper = scripts / "hq-original-editor-app-target.rb"
        helper.write_text('require "json"\nFile.write(ENV.fetch("FIXTURE_HELPER_MARKER"), JSON.generate({fixture: true, arguments: ARGV}))\nexit Integer(ENV.fetch("FIXTURE_HELPER_EXIT", "0"))\n')
        for gem_name, dependency in [("context_dependency", None), ("xcodeproj", "context_dependency"),
                                     ("cocoapods", None)]:
            directory = gems / "gems" / (gem_name + "-0.0.1")
            (directory / "lib").mkdir(parents=True)
            (directory / "lib" / (gem_name + ".rb")).write_text(
                ('require "context_dependency"\n' if dependency else "") +
                '# AUTHORED PORTABLE CONTROL FIXTURE; NOT THE ORIGINAL PACKAGE\n')
            specification = ('Gem::Specification.new do |s|\n' +
                f'  s.name = "{gem_name}"; s.version = "0.0.1"; s.summary = "Owned mechanism control fixture"; s.authors = ["Otzaria control"]\n' +
                f'  s.files = ["lib/{gem_name}.rb"]; s.require_paths = ["lib"]\n' +
                ('  s.add_runtime_dependency "context_dependency", "= 0.0.1"\n' if dependency else "") +
                'end\n')
            (gems / "specifications" / (gem_name + "-0.0.1.gemspec")).write_text(specification)
        pod = bin_dir / "pod"
        pod.write_text("#!" + str(ruby) + "\n" + r'''require 'rubygems'
require 'json'
require 'rbconfig'
Gem.use_paths(ENV.fetch('FIXTURE_GEMS'), [ENV.fetch('FIXTURE_GEMS')])
gem 'xcodeproj', '= 0.0.1'
require 'xcodeproj'
gem 'cocoapods', '= 0.0.1'
require 'cocoapods'
if ENV['FIXTURE_CHILD'] == '1'
  request = JSON.parse(File.read(ENV.fetch('OTZARIA_ORIGINAL_EDITOR_RUBY_REQUEST')))
  child_code = 'puts "ordinary-child-body"; exit 7'
  system(RbConfig.ruby, '-e', child_code)
  File.write(ENV.fetch('FIXTURE_CHILD_MARKER'), JSON.generate({exit: $?.exitstatus, receipt_before_parent_exit: File.exist?(request.fetch('receipt_path'))}))
end
puts 'authored-pod-fixture-return'
exit Integer(ENV.fetch('FIXTURE_POD_EXIT', '0'))
''')
        pod.chmod(0o755)
        (root / "Podfile.lock").write_text("COCOAPODS: 0.0.1\n")
        output = root / "build/hq-stage2"
        output.mkdir(parents=True)
        env = dict(environment)
        env.update(PATH=str(bin_dir) + os.pathsep + environment.get("PATH", ""),
                   FIXTURE_GEMS=str(gems), FIXTURE_HELPER_MARKER=str(root / "helper-called.json"),
                   FIXTURE_CHILD_MARKER=str(root / "child.json"), GEM_HOME=str(gems), GEM_PATH=str(gems),
                   RUBYOPT="-W0")
        # Only the command under test receives the original observer request.
        os.environ.update({k: env[k] for k in ["PATH", "GEM_HOME", "GEM_PATH", "RUBYOPT"]})
        context = sdk["prepare_pod_ruby_context"](root, output)
        context["environment"].update({k: v for k, v in env.items() if k.startswith("FIXTURE_")})
        return root, output, context, env

    def capture(name, *, child=False, exit_code=0):
        root, output, context, env = fixture(name)
        context["environment"].update(FIXTURE_CHILD="1" if child else "0",
                                       FIXTURE_POD_EXIT=str(exit_code))
        code, stdout, stderr = command(["pod", "install"], env=context["environment"], cwd=root,
                                       label=name + "-pod")
        return root, output, context, env, code

    def proof_for(root, context, code):
        return sdk["admit_pod_ruby_context"](root, context, code)

    def launch(root, context, proof, env, label):
        argv, actual_env = sdk["original_editor_ruby_launch"](
            root, proof, [root / "project.pbxproj", root / "plan.json", root / "configuration.json"])
        actual_env.update({k: v for k, v in env.items() if k.startswith("FIXTURE_")})
        check(argv[0] == str(ruby), "Captured Ruby executable was not used")
        return command(argv, env=actual_env, cwd=root, label=label)

    try:
        # Parse the whole unchanged-path candidate sources, not extracted copies.
        for path in [sdk_path, common_path]:
            ast.parse(path.read_text(), filename=str(path))
        code, _, _ = command([str(ruby), "-c", str(observer)], env=environment, cwd=checkout,
                             label="ruby-whole-source-syntax")
        check(code == 0, "Whole Ruby source parse failed")

        root, output, context, env, code = capture("same-context", child=True)
        check(code == 0, "Real fixture Ruby pod process failed")
        check(context["environment"]["RUBYOPT"] == "-W0 -r" + str(root / "Scripts/CI" / observer.name),
              "Inherited RUBYOPT was not preserved verbatim")
        child = json.loads((root / "child.json").read_text())
        check(child == {"exit": 7, "receipt_before_parent_exit": False},
              "Inherited child observer disrupted child exit or created a parent receipt")
        proof = proof_for(root, context, code)
        receipt = json.loads(Path(proof["receipt_path"]).read_text())
        check([r["name"] for r in receipt["xcodeproj_closure"]] == ["context_dependency", "xcodeproj"],
              "Actual dependency-first closure differs")
        check(receipt["pid"] != receipt["parent_pid"] and receipt["parent_pid"] == os.getpid(),
              "Parent command identity is not actual")
        code, _, _ = launch(root, context, proof, env, "same-context-helper")
        check(code == 0 and (root / "helper-called.json").is_file(), "Same-context original helper did not execute")
        result["controls"].append({"id": "same_context_and_inert_child", "status": "PASS"})

        root, output, context, env, code = capture("path-ruby")
        check(code == 0, "Fixture capture failed")
        proof = proof_for(root, context, code)
        fake_ruby = root / "bin/ruby"
        fake_ruby.write_text("#!/bin/sh\nexit 91\n")
        fake_ruby.chmod(0o755)
        code, _, _ = launch(root, context, proof, env, "captured-not-path-ruby")
        check(code == 0, "Helper selected unrelated PATH Ruby")
        result["controls"].append({"id": "unrelated_path_ruby_not_selected", "status": "PASS"})

        root, output, context, env, code = capture("pod-failure", exit_code=19)
        check(code == 19, "Observer changed original pod failure status")
        rejects(lambda: proof_for(root, context, code), "Nonzero parent pod was admitted")
        root2, output2, context2, env2 = fixture("missing-receipt")
        rejects(lambda: proof_for(root2, context2, 0), "Missing observer receipt was admitted")
        check(not (root / "helper-called.json").exists() and not (root2 / "helper-called.json").exists(),
              "Failed capture mutated through helper")
        result["controls"].append({"id": "nonzero_and_missing_parent_proof", "status": "PASS"})

        root, output, context, env = fixture("duplicate-receipt")
        receipt_path = Path(context["receipt_path"])
        original_bytes = b"exclusive-existing-receipt\n"
        receipt_path.write_bytes(original_bytes)
        code, _, _ = command(["pod", "install"], env=context["environment"], cwd=root,
                             label="duplicate-receipt-pod")
        check(code != 0 and receipt_path.read_bytes() == original_bytes,
              "Expected parent overwrote an existing accepted receipt")
        rejects(lambda: proof_for(root, context, code), "Duplicate receipt was admitted")
        result["controls"].append({"id": "exclusive_parent_receipt", "status": "PASS"})

        root, output, context, env, code = capture("source-drift")
        check(code == 0, "Fixture capture failed")
        proof = proof_for(root, context, code)
        receipt_path = Path(proof["receipt_path"])
        original_receipt = json.loads(receipt_path.read_text())
        altered = copy.deepcopy(original_receipt)
        altered["ruby"]["version"] = "unrelated-runtime"
        receipt_path.write_text(json.dumps(altered) + "\n")
        proof["receipt_sha256"] = sha(receipt_path)
        code, _, _ = launch(root, context, proof, env, "runtime-drift-helper")
        check(code != 0 and not (root / "helper-called.json").exists(), "Wrong runtime reached original helper")
        receipt_path.write_text(json.dumps(original_receipt) + "\n")
        proof["receipt_sha256"] = sha(receipt_path)
        source = root / "gems/gems/xcodeproj-0.0.1/lib/xcodeproj.rb"
        before = source.read_bytes()
        source.write_bytes(before + b"# drift\n")
        rejects(lambda: sdk["original_editor_ruby_launch"](root, proof, ["a", "b", "c"]),
                "Changed gem source was admitted")
        source.write_bytes(before)
        extra = source.parent / "unexpected.rb"
        extra.write_text("# new unrecorded source\n")
        code, _, _ = launch(root, context, proof, env, "extra-gem-source-helper")
        check(code != 0 and not (root / "helper-called.json").exists(), "Extra gem source reached original helper")
        extra.unlink()
        helper = root / "Scripts/CI/hq-original-editor-app-target.rb"
        before = helper.read_bytes()
        helper.write_bytes(before + b"# changed helper\n")
        rejects(lambda: sdk["original_editor_ruby_launch"](root, proof, ["a", "b", "c"]),
                "Changed original helper was admitted")
        helper.write_bytes(before)
        result["controls"].append({"id": "runtime_gem_membership_source_and_helper_drift", "status": "PASS"})

        root, output, context, env, code = capture("helper-failure")
        check(code == 0, "Fixture capture failed")
        proof = proof_for(root, context, code)
        env["FIXTURE_HELPER_EXIT"] = "23"
        code, _, _ = launch(root, context, proof, env, "original-helper-failure")
        check(code == 23 and (root / "helper-called.json").is_file(), "Original helper nonzero exit was lost")
        # Default logger retains the original command and inherited environment.
        globals_ = common["logged"].__globals__
        globals_["ROOT"], globals_["OUT"] = root, output
        report = {}
        command_line = [sys.executable, "-c", 'print("original-default-logger")']
        check(common["logged"](command_line, "default-path.log", report) == 0,
              "Existing no-context logger no longer returns successful command status")
        check(report["commands"] == [command_line] and
              (output / "default-path.log").read_text() == "original-default-logger\n",
              "Existing logger command/output changed")
        rejects(lambda: common["logged"]([sys.executable, "-c", "raise SystemExit(23)"],
                                         "original-nonzero.log", report),
                "Existing logger swallowed nonzero exit")
        result["controls"].append({"id": "original_helper_exit_and_default_logger", "status": "PASS"})
        result["status"] = "PASS"
    except BaseException as error:
        result["status"] = "FAIL"
        result["error"] = {"type": type(error).__name__, "message": str(error)}
        raise
    finally:
        result["passed"] = len(result["controls"])
        result["required"] = 6
        save()
        print(json.dumps({k: result[k] for k in ["status", "scope", "apple_cocoapods_native", "passed", "required", "assertions"]},
                         indent=2))
        print("RESULT_SHA256", sha(out / "RESULT.json"))

if __name__ == "__main__":
    main()
