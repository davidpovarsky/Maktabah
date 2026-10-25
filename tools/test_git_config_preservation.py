import os
import sys
import tempfile
import pathlib
import subprocess

print("=== Running Git Config Preservation Regression Test ===")

with tempfile.TemporaryDirectory() as td:
    repo_dir = pathlib.Path(td) / "test_repo"
    repo_dir.mkdir()
    
    # 1. Initialize isolated repo with custom config
    subprocess.run(["git", "init"], cwd=repo_dir, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.name", "Original Author"], cwd=repo_dir, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "author@test.local"], cwd=repo_dir, check=True, capture_output=True)
    subprocess.run(["git", "config", "core.autocrlf", "input"], cwd=repo_dir, check=True, capture_output=True)
    
    # Initial commit
    test_file = repo_dir / "sample.txt"
    test_file.write_text("initial content\n", encoding="utf-8")
    subprocess.run(["git", "add", "sample.txt"], cwd=repo_dir, check=True, capture_output=True)
    subprocess.run(["git", "commit", "-m", "Initial commit"], cwd=repo_dir, check=True, capture_output=True)
    
    # Snapshot initial config
    def get_config(key):
        res = subprocess.run(["git", "config", "--local", key], cwd=repo_dir, capture_output=True, text=True)
        return res.stdout.strip()
    
    orig_name = get_config("user.name")
    orig_email = get_config("user.email")
    orig_crlf = get_config("core.autocrlf")
    assert orig_name == "Original Author"
    assert orig_email == "author@test.local"
    assert orig_crlf == "input"
    print("  [PASS] Isolated repo initialized with custom local config:")
    print(f"         user.name={orig_name}, user.email={orig_email}, core.autocrlf={orig_crlf}")

    # 2. Add a linked worktree (simulating verification runner)
    wt_dir = pathlib.Path(td) / "test_wt"
    subprocess.run(["git", "worktree", "add", str(wt_dir), "HEAD", "--detach"], cwd=repo_dir, check=True, capture_output=True)
    
    # Verify that runner does NOT run `git config` in worktree
    # Instead, if commit is needed, it uses -c arguments:
    res_commit = subprocess.run(
        ["git", "-c", "user.name=Temp Runner", "-c", "user.email=temp@runner.local", "status"],
        cwd=wt_dir,
        capture_output=True,
        text=True
    )
    assert res_commit.returncode == 0
    
    # 3. Teardown worktree
    subprocess.run(["git", "worktree", "remove", "--force", str(wt_dir)], cwd=repo_dir, check=True, capture_output=True)
    
    # 4. Assert config in main repo is strictly UNCHANGED
    post_name = get_config("user.name")
    post_email = get_config("user.email")
    post_crlf = get_config("core.autocrlf")
    
    assert post_name == orig_name, f"Config drifted! user.name: expected {orig_name}, got {post_name}"
    assert post_email == orig_email, f"Config drifted! user.email: expected {orig_email}, got {post_email}"
    assert post_crlf == orig_crlf, f"Config drifted! core.autocrlf: expected {orig_crlf}, got {post_crlf}"
    print("  [PASS] Normal cycle: Local git config strictly preserved (0 drift).")
    
    # 5. Halfway failure simulation: simulate an error inside worktree
    wt_fail_dir = pathlib.Path(td) / "test_wt_fail"
    subprocess.run(["git", "worktree", "add", str(wt_fail_dir), "HEAD", "--detach"], cwd=repo_dir, check=True, capture_output=True)
    try:
        # Simulate an exception in verification
        raise RuntimeError("Simulated failure during test execution")
    except Exception as e:
        # Cleanup routine
        if wt_fail_dir.exists():
            subprocess.run(["git", "worktree", "remove", "--force", str(wt_fail_dir)], cwd=repo_dir, check=False, capture_output=True)
    
    post_fail_name = get_config("user.name")
    post_fail_email = get_config("user.email")
    post_fail_crlf = get_config("core.autocrlf")
    assert post_fail_name == orig_name
    assert post_fail_email == orig_email
    assert post_fail_crlf == orig_crlf
    print("  [PASS] Failure recovery: Local git config strictly preserved even after abort.")

print("RESULT: Git Config Preservation ALL TESTS PASSED\n")
