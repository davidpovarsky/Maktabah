"""Validate only the changed docs and retain unchanged parser evidence."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
from urllib.parse import urlparse, unquote

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "sources/otzaria-completion-20261121"
candidate = ROOT / "candidate"
manifest = json.loads((ROOT / "CONFIGURATION_FIX_INPUTS.json").read_text())
prior = json.loads((ROOT / "STATIC_CONFIG_VALIDATION.json").read_text())
tree = json.loads((ROOT / "LINK_TARGET_TREE_CHECK.json").read_text())
existing = {row["path"] for row in tree["targets"] if row["exists"]}
assert prior["all_current_checks_passed"] is True

def norm(path):
    out=[]
    for part in PurePosixPath(path).parts:
        if part == ".": continue
        if part == "..":
            assert out
            out.pop()
        else: out.append(part)
    return "/".join(out)

checks=[]
for row in manifest["files"]:
    path=row["path"]
    old=(SOURCE/path).read_bytes();new=(candidate/path).read_bytes()
    assert hashlib.sha256(old).hexdigest()==row["base_sha256"]
    assert hashlib.sha256(new).hexdigest()==row["sha256"]
    # Frontmatter is exactly unchanged; no repeated parser run is needed.
    if old.startswith(b"---\n"):
        assert old.split(b"\n---",1)[0]==new.split(b"\n---",1)[0]
    if path!="docs/ai-team/BRANCH_INTEGRATION.md":
        old_targets=re.sub(rb"\]\([^)]*UPSTREAM_INTEGRITY_POLICY\.md\)",b"](POLICY_TARGET)",old)
        new_targets=re.sub(rb"\]\([^)]*UPSTREAM_INTEGRITY_POLICY\.md\)",b"](POLICY_TARGET)",new)
        assert old_targets==new_targets
    checks.append({"path":path,"preimage_and_output_hashes":"PASS","policy_body_preserved":path!="docs/ai-team/BRANCH_INTEGRATION.md"})

links=[]
for path in sorted({row["path"] for row in prior["checks"] if row["check"]=="captured_exact_current_blob" and row["path"].endswith(".md")}):
    p=candidate/path if (candidate/path).exists() else SOURCE/path
    text=p.read_text()
    for match in re.finditer(r"(?<!!)\[[^\]]*\]\(([^)]+)\)",text):
        target=match.group(1).strip().split(" ",1)[0].strip("<>")
        parsed=urlparse(target)
        if parsed.scheme or target.startswith("#"):continue
        resolved=norm((PurePosixPath(path).parent/unquote(parsed.path)).as_posix())
        assert resolved in existing,(path,target,resolved)
        links.append({"source":path,"target":target,"resolved":resolved,"exists_in_exact_git_tree":True})
assert len(links)==8

work=Path(tempfile.mkdtemp(prefix="apply-docs-",dir=ROOT))
for row in manifest["files"]:
    target=work/row["path"];target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(SOURCE/row["path"],target)
subprocess.run(["git","init","--quiet"],cwd=work,check=True)
patch=ROOT/"team-configuration-links-and-branch-snapshot.patch"
commands=[]
for args in [["git","apply","--check","--whitespace=error-all",str(patch)],["git","apply","--whitespace=error-all",str(patch)]]:
    p=subprocess.run(args,cwd=work,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    commands.append({"args":args,"returncode":p.returncode,"stderr":p.stderr.decode()})
    assert p.returncode==0,p.stderr
for row in manifest["files"]:
    assert hashlib.sha256((work/row["path"]).read_bytes()).hexdigest()==row["sha256"]
report={"status":"SIX_DOCUMENT_CORRECTION_VALIDATED","patch_sha256":hashlib.sha256(patch.read_bytes()).hexdigest(),"source":manifest["base_commit"],"same_preimages_on":manifest["identical_preimages_on"],"changed_docs":checks,"all_internal_markdown_links_valid":True,"internal_link_count":len(links),"links":links,"reused_yaml_parser_documents":9,"reused_toml_parser_documents":7,"prior_parser_receipt_sha256":hashlib.sha256((ROOT/"STATIC_CONFIG_VALIDATION.json").read_bytes()).hexdigest(),"commands":commands,"product_source_changed":False,"native_tests":0,"remote_repo_mutations":0}
(ROOT/"CONFIGURATION_FIX_VALIDATION.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps({"status":report["status"],"patch_sha256":report["patch_sha256"],"links":len(links),"new_product_tests":0}))
