#!/usr/bin/env python3
"""Synthetic boundary controls only. No native UI, corpus or performance acceptance."""
from pathlib import Path
import hashlib
import importlib.util
import json
import math
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
DRIVER = ROOT / "Scripts/CI/reader-full-v32-ui-observation.py"
spec = importlib.util.spec_from_file_location("full_v32_original_observation", DRIVER)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class EvidenceBoundaryControls(unittest.TestCase):
    def test_bounded_read_accepts_exact_regular_file(self):
        with tempfile.TemporaryDirectory(prefix="full-v32-control-") as directory:
            p = Path(directory) / "owned"
            p.write_bytes(b"A" * 16384)
            self.assertEqual(module.bounded_read(p, 16384), b"A" * 16384)

    def test_bounded_read_rejects_oversize(self):
        with tempfile.TemporaryDirectory(prefix="full-v32-control-") as directory:
            p = Path(directory) / "owned"
            p.write_bytes(b"A" * 16385)
            with self.assertRaises(ValueError): module.bounded_read(p, 16384)

    def test_bounded_read_rejects_empty(self):
        with tempfile.TemporaryDirectory(prefix="full-v32-control-") as directory:
            p = Path(directory) / "owned"
            p.write_bytes(b"")
            with self.assertRaises(ValueError): module.bounded_read(p, 16384)

    def test_bounded_read_rejects_symlink(self):
        with tempfile.TemporaryDirectory(prefix="full-v32-control-") as directory:
            p, link = Path(directory) / "owned", Path(directory) / "link"
            p.write_bytes(b"abc")
            link.symlink_to(p)
            with self.assertRaises(OSError): module.bounded_read(link, 16)

    def test_bounded_read_rejects_replacement_during_read(self):
        with tempfile.TemporaryDirectory(prefix="full-v32-control-") as directory:
            p = Path(directory) / "owned"
            p.write_bytes(b"abc")
            original = module.os.fdopen
            class ReplacingReader:
                def __enter__(self): return self
                def __exit__(self, *args): self.stream.close()
                def __init__(self, descriptor, mode): self.stream = original(descriptor, mode)
                def read(self, limit):
                    result = self.stream.read(limit)
                    replacement = p.with_suffix(".replacement")
                    replacement.write_bytes(b"abc")
                    replacement.replace(p)
                    return result
            module.os.fdopen = ReplacingReader
            try:
                with self.assertRaises(ValueError): module.bounded_read(p, 16)
            finally: module.os.fdopen = original

    def test_bounded_read_rejects_growth_during_read(self):
        with tempfile.TemporaryDirectory(prefix="full-v32-control-") as directory:
            p = Path(directory) / "owned"
            p.write_bytes(b"abc")
            original = module.os.fdopen
            class GrowingReader:
                def __enter__(self): return self
                def __exit__(self, *args): self.stream.close()
                def __init__(self, descriptor, mode): self.stream = original(descriptor, mode)
                def read(self, limit):
                    result = self.stream.read(limit)
                    with p.open("ab") as destination: destination.write(b"def")
                    return result
            module.os.fdopen = GrowingReader
            try:
                with self.assertRaises(ValueError): module.bounded_read(p, 16)
            finally: module.os.fdopen = original

    def comparison_fixture(self, directory):
        text = "א\u05b0ב😀ג\u05b8\u200fדה\n"  # original UTF16/UTF8, combining marks and surrogate pair
        p = Path(directory) / "source.txt"
        p.write_bytes(text.encode("utf-8"))
        utf16 = text.encode("utf-16-le")
        target = {"sourceFile": p.name, "sourceSHA256": hashlib.sha256(p.read_bytes()).hexdigest(),
                  "sourceUTF16Length": len(utf16) // 2}
        view = {"requestID": "00000000-0000-4000-8000-000000000001", "source": 3,
                "fullV32SourceObservation": {"schema": 1, "status": "AVAILABLE", "rangeLocation": 0,
                    "rangeLength": len(utf16) // 2, "sourceUTF16Length": len(utf16) // 2,
                    "sourceUTF8": text, "processID": 123, "observedUptime": 1.0}}
        return target, view

    def test_exact_source_preserves_hebrew_combining_surrogate_and_rtl_bytes(self):
        with tempfile.TemporaryDirectory(prefix="full-v32-control-") as directory:
            target, view = self.comparison_fixture(directory)
            result = module.exact_source_comparison(directory, target, view)
            self.assertEqual(result["status"], "EXACT_UTF16_RANGE_AND_UTF8_SOURCE_MATCH")

    def test_exact_source_rejects_equal_length_changed_content(self):
        with tempfile.TemporaryDirectory(prefix="full-v32-control-") as directory:
            target, view = self.comparison_fixture(directory)
            view["fullV32SourceObservation"]["sourceUTF8"] = view["fullV32SourceObservation"]["sourceUTF8"].replace("ב", "ז")
            with self.assertRaises(ValueError): module.exact_source_comparison(directory, target, view)

    def test_exact_source_rejects_over_cap(self):
        with tempfile.TemporaryDirectory(prefix="full-v32-control-") as directory:
            target, view = self.comparison_fixture(directory)
            view["fullV32SourceObservation"]["rangeLength"] = 257
            with self.assertRaises(ValueError): module.exact_source_comparison(directory, target, view)

    def test_exact_source_rejects_source_index_outside_sample(self):
        with tempfile.TemporaryDirectory(prefix="full-v32-control-") as directory:
            target, view = self.comparison_fixture(directory)
            view["source"] = target["sourceUTF16Length"]
            with self.assertRaises(ValueError): module.exact_source_comparison(directory, target, view)

    def test_native_row_containment_has_no_epsilon(self):
        outer = {"x": 0.0, "y": 0.0, "width": 1210.0, "height": 834.0}
        exact = {"x": 1200.0, "y": 824.0, "width": 10.0, "height": 10.0}
        self.assertTrue(module.contains(outer, exact))
        self.assertFalse(module.contains(outer, dict(exact, x=1200.0000000001)))

    def test_native_row_rect_rejects_nonfinite_and_zero(self):
        for value in ({"x": math.nan, "y": 0.0, "width": 1.0, "height": 1.0},
                      {"x": 0.0, "y": 0.0, "width": 0.0, "height": 1.0}):
            with self.assertRaises(ValueError): module.rect(value)

    def test_cpu_field_preserves_actual_reported_units(self):
        self.assertAlmostEqual(module.cpu_seconds("1:23.45"), 83.45)
        self.assertAlmostEqual(module.cpu_seconds("1:02:03.45"), 3723.45)
        self.assertAlmostEqual(module.cpu_seconds("2-03:04:05.6"), 183845.6)
        with self.assertRaises(ValueError): module.cpu_seconds("unavailable")

    def test_percentiles_retain_all_individual_values(self):
        result = module.percentiles(list(range(1, 21)))
        self.assertEqual((result["n"], result["p50"], result["p95"]), (20, 10, 19))
        self.assertEqual(result["individual"], list(range(1, 21)))
        with self.assertRaises(ValueError): module.percentiles([1, math.nan])

    def host_fence(self, active=None, pending=None):
        host = module.ObservationHost.__new__(module.ObservationHost)
        host.active, host.pending_inspector = active, pending
        return host

    def test_resource_epoch_rejects_pending_post_resource_observation(self):
        host = self.host_fence(pending={"request_id": "owned"})
        with self.assertRaises(ValueError): host.begin({})

    def test_inspector_observation_rejects_active_resource_epoch(self):
        host = self.host_fence(active={"epoch": "owned"})
        with self.assertRaises(ValueError): host.arm_inspector({}, Path("/unused"))

    def test_source_observation_rejects_active_resource_epoch(self):
        host = self.host_fence(active={"epoch": "owned"})
        with self.assertRaises(ValueError): host.validate_source({}, Path("/unused"))

    def test_source_observation_rejects_pending_cache_observation(self):
        host = self.host_fence(pending={"request_id": "owned"})
        with self.assertRaises(ValueError): host.validate_source({}, Path("/unused"))

    def test_response_rejects_unowned_uuid_without_releasing_other_fence(self):
        pending = {"request_id": "owned", "container": "/unused"}
        host = self.host_fence(pending=pending)
        with self.assertRaises(ValueError): host.validate_inspector({"requestID": "different"}, Path("/unused"))
        self.assertIs(host.pending_inspector, pending)

if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(EvidenceBoundaryControls)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    print(json.dumps({"scope": "synthetic boundary controls; no native UI/corpus/performance acceptance",
        "testsRun": result.testsRun, "failures": len(result.failures), "errors": len(result.errors),
        "skipped": len(result.skipped), "driverSHA256": hashlib.sha256(DRIVER.read_bytes()).hexdigest(),
        "nativeUIExecuted": 0, "productionCorpusUsed": False}, sort_keys=True))
    raise SystemExit(not result.wasSuccessful())
