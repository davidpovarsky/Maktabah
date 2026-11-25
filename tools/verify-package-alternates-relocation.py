#!/usr/bin/env python3
"""Exercise real Git alternate relocation and rejection of unsafe input metadata."""
import copy, hashlib, json, pathlib, runpy, shutil, subprocess, tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
MODULE = runpy.run_path(str(ROOT / "Scripts/CI/hq-stage2-focused-apple.py"))
FN = MODULE["relocate_verified_package_alternates"]
results = []

def git(*args):
    return subprocess.check_output(["git", *map(str,args)], text=True, stderr=subprocess.PIPE).strip()

with tempfile.TemporaryDirectory(prefix="otzaria-package-relocation-") as temporary:
    temp = pathlib.Path(temporary)
    fixture = temp / "fixture"
    base = fixture / "build/SourcePackages"
    source = temp / "source"
    source.mkdir()
    git("init", source)
    (source / "Package.swift").write_text("// Original fixture package.\n")
    git("-C", source, "add", "Package.swift")
    git("-C", source, "-c", "user.name=RelocationControl", "-c",
        "user.email=control@example.invalid", "commit", "-m", "Fixture original")
    revision = git("-C", source, "rev-parse", "HEAD")
    repository = base / "repositories/Sample-12345678"
    checkout = base / "checkouts/Sample"
    repository.parent.mkdir(parents=True)
    checkout.parent.mkdir()
    git("clone", "--bare", source, repository)
    git("clone", "--shared", "--no-checkout", repository, checkout)
    git("-C", checkout, "checkout", "--detach", revision)
    old = "/Users/runner/work/Maktabah/Maktabah/build/SourcePackages/repositories/Sample-12345678/objects\n"
    (checkout / ".git/objects/info/alternates").write_text(old)
    cases = ["relocate_exact_original_commit", "already_local", "outside_root", "parent_traversal",
             "symlink_object_store", "nested_alternate", "multiline_alternate", "wrong_pin",
             "dirty_source", "unverified_archive"]
    for name in cases:
        root = temp / name
        shutil.copytree(fixture, root)
        packages = root / "build/SourcePackages"
        checkout = packages / "checkouts/Sample"
        alternate = checkout / ".git/objects/info/alternates"
        target = packages / "repositories/Sample-12345678/objects"
        out = root / "evidence"; out.mkdir()
        report = {"artifact_inputs": [{"tar":"SourcePackages.tar","sha256":"control-digest",
                                       "verified_sha256":"control-digest"}],
                  "package_pins":{"sample":revision}}
        if name == "already_local": alternate.write_text(str(target) + "\n")
        if name == "outside_root": alternate.write_text(str(source / ".git/objects") + "\n")
        if name == "parent_traversal": alternate.write_text(old.replace("/Sample-", "/../Sample-"))
        if name == "symlink_object_store":
            moved = temp / "objects-outside"
            target.rename(moved)
            target.symlink_to(moved, target_is_directory=True)
        if name == "nested_alternate":
            (target / "info/alternates").write_text(str(source / ".git/objects") + "\n")
        if name == "multiline_alternate": alternate.write_text(old + old)
        if name == "wrong_pin": report["package_pins"]["sample"] = "0"*40
        if name == "dirty_source": (checkout / "Package.swift").write_text("// Changed input.\n")
        if name == "unverified_archive": report["artifact_inputs"][0]["verified_sha256"] = "different"
        FN.__globals__["ROOT"] = root
        FN.__globals__["OUT"] = out
        should_pass = name in ["relocate_exact_original_commit", "already_local"]
        try:
            FN(report)
            assert should_pass, "Unsafe input was accepted"
            assert git("-C", checkout, "rev-parse", "HEAD") == revision
            assert (checkout / "Package.swift").read_bytes() == (source / "Package.swift").read_bytes()
            assert not git("-C", checkout, "status", "--porcelain")
            receipt = json.loads((out / "package-alternates-relocation.json").read_text())
            assert receipt["verified_packages"] == 1
            assert receipt["relocated_alternates"] == (1 if name == "relocate_exact_original_commit" else 0)
            results.append({"case":name,"status":"PASS"})
        except RuntimeError as error:
            assert not should_pass, str(error)
            results.append({"case":name,"status":"PASS","expected_rejection":str(error)})
assert len(results) == 10
print(json.dumps({"status":"PASS","scope":"Portable real-Git relocation controls; no app/native acceptance",
                  "checks":len(results),"results":results},indent=2))
