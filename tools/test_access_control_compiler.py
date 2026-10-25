import os
import sys
import tempfile
import pathlib
import subprocess

print("=== Running Swift Access-Level Compiler Verification Fixture ===")

with tempfile.TemporaryDirectory() as td:
    td_path = pathlib.Path(td)
    
    # 1. Negative Test: Old buggy declaration with 'public' exposing internal types
    bad_source = td_path / "BadAccessControl.swift"
    bad_source.write_text("""
struct BackendIDInternal: Sendable {}
struct BooksDataInternal: Sendable {}

public protocol TargetBackendBookResolverProtocol: Sendable {
    func resolveBook(
        id: Int,
        in backend: BackendIDInternal
    ) throws -> BooksDataInternal
}

public final class ChavrusaTextTargetBackendBookResolver: TargetBackendBookResolverProtocol {
    public static let shared = ChavrusaTextTargetBackendBookResolver()
    public func resolveBook(
        id: Int,
        in backend: BackendIDInternal
    ) throws -> BooksDataInternal {
        return BooksDataInternal()
    }
}
""", encoding="utf-8")

    res_bad = subprocess.run(["swiftc", "-typecheck", str(bad_source)], capture_output=True, text=True)
    assert res_bad.returncode != 0, "Expected compilation failure on public protocol with internal types"
    assert "cannot be declared public because its parameter uses an internal type" in res_bad.stderr or \
           "cannot be declared public because its result uses an internal type" in res_bad.stderr, \
           f"Unexpected compiler error: {res_bad.stderr}"
    print(f"  [PASS] Negative test passed: Compiler correctly rejected public signature exposing internal types:")
    for line in res_bad.stderr.splitlines():
        if "error:" in line:
            print(f"         {line.strip()}")

    # 2. Positive Test: Corrected internal declaration
    good_source = td_path / "GoodAccessControl.swift"
    good_source.write_text("""
struct BackendIDInternal: Sendable {}
struct BooksDataInternal: Sendable {}

protocol TargetBackendBookResolverProtocol: Sendable {
    func resolveBook(
        id: Int,
        in backend: BackendIDInternal
    ) throws -> BooksDataInternal
}

final class ChavrusaTextTargetBackendBookResolver: TargetBackendBookResolverProtocol {
    static let shared = ChavrusaTextTargetBackendBookResolver()
    func resolveBook(
        id: Int,
        in backend: BackendIDInternal
    ) throws -> BooksDataInternal {
        return BooksDataInternal()
    }
}
""", encoding="utf-8")

    res_good = subprocess.run(["swiftc", "-typecheck", str(good_source)], capture_output=True, text=True)
    assert res_good.returncode == 0, f"Expected clean compilation of internal signature, got: {res_good.stderr}"
    print("  [PASS] Positive test passed: Compiler cleanly accepted module-internal signature (exit code 0)")

print("RESULT: Swift Access-Level Fixture ALL TESTS PASSED\n")
