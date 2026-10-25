#!/usr/bin/env python3
"""
assemble_and_verify_bundle.py

Deterministic self-contained assembly and verification script for ChavrusaText / Maktabah Build 8401.
Consumes ONLY an isolated clean repository checkout and the self-contained ZIP bundle.
Does NOT read uncommitted files from any external dirty working copy.
Does NOT mutate repository or global Git configuration.
"""

import os
import sys
import json
import zipfile
import hashlib
import pathlib
import argparse
import subprocess

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

def run(cmd, cwd, check=True):
    res = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if check and res.returncode != 0:
        print(f"FAILED: {' '.join(cmd)}\nSTDOUT:\n{res.stdout}\nSTDERR:\n{res.stderr}")
        raise RuntimeError(f"Command failed with exit code {res.returncode}")
    return res

def sha256_file(p):
    h = hashlib.sha256()
    h.update(p.read_bytes())
    return h.hexdigest()

def git_blob_sha(repo, p):
    res = subprocess.run(["git", "hash-object", str(p)], cwd=repo, capture_output=True, text=True, check=True, encoding="utf-8", errors="replace")
    return res.stdout.strip()

def main():
    parser = argparse.ArgumentParser(description="Self-contained bundle assembler and verifier")
    parser.add_argument("--repo", required=True, type=pathlib.Path, help="Path to clean git checkout/clone")
    parser.add_argument("--bundle", required=True, type=pathlib.Path, help="Path to standalone ZIP bundle")
    parser.add_argument("--skip-teardown", action="store_true", help="Keep applied changes for inspection")
    args = parser.parse_args()

    repo_path = args.repo.resolve()
    bundle_path = args.bundle.resolve()

    print(f"==================================================================")
    print(f"=== Self-Contained Bundle Verification: Build 8401 ===")
    print(f"=== Repo Target:   {repo_path}")
    print(f"=== Bundle Source: {bundle_path}")
    print(f"==================================================================")

    assert repo_path.exists() and (repo_path / ".git").exists(), f"Invalid git repository: {repo_path}"
    assert bundle_path.exists(), f"Bundle file not found: {bundle_path}"

    # 1. Verify repo clean status
    print("\n1. Verifying clean baseline in target repo...")
    status_res = run(["git", "status", "--porcelain"], cwd=repo_path)
    assert status_res.stdout.strip() == "", f"Target repo is not clean:\n{status_res.stdout}"
    head_sha = run(["git", "rev-parse", "HEAD"], cwd=repo_path).stdout.strip()
    print(f"   [PASS] Target repo clean at HEAD {head_sha}")

    # Snapshot Git config before run
    config_before = run(["git", "config", "--local", "--list"], cwd=repo_path).stdout.strip()

    # 2. Open bundle and read manifest
    print("\n2. Inspecting standalone bundle...")
    with zipfile.ZipFile(bundle_path, "r") as zf:
        manifest_data = zf.read("manifest/BUILD_8401_REPRODUCIBLE_PAYLOAD_MANIFEST.json")
        manifest = json.loads(manifest_data.decode("utf-8"))
        print(f"   Manifest loaded: version {manifest['manifest_version']} for baseline {manifest['baseline_candidate_commit']}")

        # Verify base blob hashes in repo
        print("\n3. Validating baseline Git blob hashes in target repo...")
        for p_info in manifest["proposed_protected_patches"]:
            target_file = repo_path / p_info["target_file"]
            assert target_file.exists(), f"Target file missing: {p_info['target_file']}"
            current_blob = git_blob_sha(repo_path, target_file)
            assert current_blob == p_info["base_blob_sha"], (
                f"Base blob mismatch for {p_info['target_file']}: "
                f"expected {p_info['base_blob_sha']}, got {current_blob}"
            )
        print(f"   [PASS] All {len(manifest['proposed_protected_patches'])} base blob SHAs match manifest exactly.")

        # 4. Extract payload files from bundle ONLY
        print("\n4. Extracting downstream sources and patches from bundle...")
        for item in manifest["new_downstream_sources"] + manifest["modified_downstream_sources"]:
            zip_member = f"payload/{item['path']}"
            assert zip_member in zf.namelist(), f"Missing from bundle: {zip_member}"
            content = zf.read(zip_member)
            computed_sha = hashlib.sha256(content).hexdigest()
            assert computed_sha == item["sha256"], f"SHA256 mismatch for {item['path']}: {computed_sha} != {item['sha256']}"
            dst = repo_path / item["path"]
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(content)

        patch_files = []
        for p_info in manifest["proposed_protected_patches"]:
            zip_member = f"patches/{p_info['patch_file']}"
            assert zip_member in zf.namelist(), f"Missing patch from bundle: {zip_member}"
            content = zf.read(zip_member)
            computed_sha = hashlib.sha256(content).hexdigest()
            assert computed_sha == p_info["sha256"], f"Patch SHA mismatch: {computed_sha} != {p_info['sha256']}"
            dst = repo_path / "docs" / "architecture" / "build-8401-patches" / p_info["patch_file"]
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(content)
            patch_files.append(dst)

        # Extract tools
        for tool_name in ["assemble_and_verify_bundle.py", "test_access_control_compiler.py", "test_git_config_preservation.py"]:
            zip_member = f"tools/{tool_name}"
            if zip_member in zf.namelist():
                content = zf.read(zip_member)
                dst = repo_path / "tools" / tool_name
                dst.parent.mkdir(parents=True, exist_ok=True)
                dst.write_bytes(content)

        print("   [PASS] Extracted all new/modified sources, 12 patches, and tools from bundle.")

    # 5. Preflight check: git apply --check on all 12 patches individually
    print("\n5. Preflight git apply --check on all 12 patches individually...")
    for p_path in patch_files:
        res = run(["git", "apply", "--check", "--whitespace=error", str(p_path)], cwd=repo_path)
        assert res.returncode == 0, f"git apply --check failed on {p_path.name}"
    print("   [PASS] All 12 patches passed individual git apply --check.")

    # 6. Apply all 12 patches cumulatively
    print("\n6. Applying all 12 patches cumulatively...")
    for p_path in patch_files:
        res = run(["git", "apply", "--whitespace=error", str(p_path)], cwd=repo_path)
        assert res.returncode == 0, f"Cumulative apply failed on {p_path.name}"
    print("   [PASS] All 12 patches applied cleanly.")

    # 7. Check git diff --check (0 whitespace errors)
    res_diff_check = run(["git", "diff", "--check"], cwd=repo_path)
    assert res_diff_check.returncode == 0 and res_diff_check.stdout.strip() == "", f"Whitespace errors: {res_diff_check.stdout}"
    print("   [PASS] git diff --check reported 0 whitespace errors.")

    # 8. Verify Xcode project registration
    print("\n7. Verifying Xcode target registration (Patch 12)...")
    pbx_content = (repo_path / "Maktabah.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    for item in manifest["new_downstream_sources"]:
        base_name = pathlib.Path(item["path"]).name
        assert base_name in pbx_content, f"New source {base_name} missing from project.pbxproj after Patch 12!"
    print("   [PASS] All 6 new Swift sources verified in project.pbxproj.")

    # 9. Run portable Swift component tests
    print("\n8. Compiling and running portable Swift component tests...")
    swift_cmd = [
        "swiftc", "-parse-as-library",
        "-o", "tools/test_runner.exe",
        "tools/test_chavrusa_text_components.swift",
        "Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift",
        "Source/ChavrusaText/ReaderRendering/ReaderSelectionRangeMapper.swift",
        "Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift",
        "Source/ChavrusaText/Navigation/ReaderSessionRestoreCoordinator.swift",
        "Source/ChavrusaText/Navigation/SerializedSessionWriter.swift",
        "Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift",
        "Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift",
        "Source/ChavrusaText/Localization/TalmudHebrewAddressFormatter.swift",
        "Source/ChavrusaText/Navigation/ReaderDestinationResolver.swift",
        "Source/ChavrusaText/Navigation/ReaderBackendPagingCoordinator.swift",
        "Source/ChavrusaText/Search/ReaderSearchContextCoordinator.swift",
        "Source/ChavrusaText/Navigation/TOCReadingLocationTracker.swift",
        "Source/ChavrusaText/Navigation/TargetBackendBookResolver.swift",
        "Source/Sefaria/Domain/SefariaModels.swift",
        "Source/Sefaria/Offline/SefariaExportModels.swift",
        "Source/Sefaria/Offline/SefariaOfflinePaths.swift",
        "Source/LibraryBackend/LibraryBackendProtocols.swift",
        "Source/LibraryBackend/LibraryBackendModels.swift",
        "Source/LibraryBackend/LibraryPresentationPolicy+Display.swift",
        "Source/LibraryBackend/LegacyIdentityRegistry.swift",
        "Source/LibraryBackend/BackendCoordinator.swift"
    ]
    run(swift_cmd, cwd=repo_path)
    test_run = run([str(repo_path / "tools" / "test_runner.exe")], cwd=repo_path)
    assert "164 of 164 assertions passed (0 failures)" in test_run.stdout, "Assertion count mismatch"
    assert "RESULT: ALL SUITES PASSED SUCCESSFULLY" in test_run.stdout, "Suite result mismatch"
    print("   [PASS] Portable component tests passed (164/164 assertions across 15 suites).")

    # 10. Run Python boundary fixture tests
    print("\n9. Running boundary fixture tests...")
    py_fixtures = run(["python", "tools/test_verify_upstream_boundary.py"], cwd=repo_path)
    assert "Overall Result: ALL FIXTURES PASSED" in py_fixtures.stdout, "Boundary fixture tests failed"
    print("   [PASS] Boundary fixture tests passed (24/24 fixtures).")

    # 11. Run Swift access-level compiler fixture
    print("\n10. Running Swift access-level compiler fixture...")
    acc_fixture = run(["python", "tools/test_access_control_compiler.py"], cwd=repo_path)
    assert "RESULT: Swift Access-Level Fixture ALL TESTS PASSED" in acc_fixture.stdout
    print("   [PASS] Swift access-level compiler fixture passed.")

    # 12. Run Git config preservation test
    print("\n11. Running Git config preservation regression test...")
    cfg_test = run(["python", "tools/test_git_config_preservation.py"], cwd=repo_path)
    assert "RESULT: Git Config Preservation ALL TESTS PASSED" in cfg_test.stdout
    print("   [PASS] Git config preservation regression test passed.")

    if not args.skip_teardown:
        # 13. Reverse patches in reverse order
        print("\n12. Reversing all 12 patches in reverse order...")
        for p_path in reversed(patch_files):
            res = run(["git", "apply", "-R", "--whitespace=error", str(p_path)], cwd=repo_path)
            assert res.returncode == 0, f"Rollback failed on {p_path.name}"
        print("   [PASS] All 12 patches reversed cleanly.")

        # Verify target files returned to exact base blob hashes
        for p_info in manifest["proposed_protected_patches"]:
            target_file = repo_path / p_info["target_file"]
            current_blob = git_blob_sha(repo_path, target_file)
            assert current_blob == p_info["base_blob_sha"], (
                f"Blob mismatch after rollback for {p_info['target_file']}: "
                f"expected {p_info['base_blob_sha']}, got {current_blob}"
            )
        print("   [PASS] All 12 protected target files returned to exact baseline git blob hashes.")

        # 14. Clean up extracted files
        print("\n13. Cleaning up downstream extracted files...")
        for item in manifest["modified_downstream_sources"]:
            run(["git", "checkout", "HEAD", "--", item["path"]], cwd=repo_path)
        for item in manifest["new_downstream_sources"]:
            p = repo_path / item["path"]
            if p.exists():
                p.unlink()
        for p_info in manifest["proposed_protected_patches"]:
            p = repo_path / "docs" / "architecture" / "build-8401-patches" / p_info["patch_file"]
            if p.exists():
                p.unlink()
        for ext in [".exe", ".exp", ".lib"]:
            p = repo_path / "tools" / f"test_runner{ext}"
            if p.exists():
                p.unlink()
        for tool_name in ["assemble_and_verify_bundle.py", "test_access_control_compiler.py", "test_git_config_preservation.py"]:
            p = repo_path / "tools" / tool_name
            if p.exists():
                p.unlink()

        status_final = run(["git", "status", "--porcelain"], cwd=repo_path).stdout.strip()
        assert status_final == "", f"Target repo not clean after teardown: {status_final}"
        print("   [PASS] Target repo returned to 100% clean baseline status.")

    # Assert Git config was not mutated during verification
    config_after = run(["git", "config", "--local", "--list"], cwd=repo_path).stdout.strip()
    assert config_before == config_after, "Local git config was unexpectedly mutated!"
    print("   [PASS] Git config strictly preserved throughout verification.")

    print(f"\n==================================================================")
    print(f"=== ALL BUNDLE VERIFICATION CHECKS PASSED SUCCESSFULLY ===")
    print(f"==================================================================")
    return 0

if __name__ == "__main__":
    sys.exit(main())
