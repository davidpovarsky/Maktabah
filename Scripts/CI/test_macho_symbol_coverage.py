"""Focused inspector controls; no Apple product or application acceptance."""
import gzip
import hashlib
import json
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import time
import unittest

API = runpy.run_path(str(Path(__file__).with_name("macho_symbol_coverage.py")))


class FullSymbolCoverageControls(unittest.TestCase):
    def test_complete_stream_preserves_local_undefined_and_final_bytes(self):
        payload = b"00000001 t _local_HanlinMiniAppsBridge\n         U _HanlinNativeScriptRuntime\nfinal_without_newline"
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "symbols.gz"
            command = [sys.executable, "-c", "import sys;sys.stdout.buffer.write(" + repr(payload) + ")"]
            receipt = API["bounded_stream"](command, path, 5)
            self.assertEqual(gzip.decompress(path.read_bytes()), payload)
            self.assertEqual(receipt["raw_sha256"], hashlib.sha256(payload).hexdigest())
            self.assertEqual(receipt["status"], "PASS")

    def test_deadline_interrupts_a_process_that_never_closes_stdout(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "blocked.gz"
            started = time.monotonic()
            with self.assertRaises(subprocess.TimeoutExpired):
                API["bounded_stream"]([sys.executable, "-c",
                    "import time;print('retained_prefix',flush=True);time.sleep(20)"], path, 1)
            self.assertLess(time.monotonic() - started, 5)
            self.assertIn(b"retained_prefix", gzip.decompress(path.read_bytes()))
            receipt = json.loads(path.with_name(path.name + ".process.json").read_text())
            self.assertEqual(receipt["status"], "TIMEOUT")
            self.assertNotEqual(receipt["returncode"], 0)

    def test_deadline_also_handles_an_exited_parent_with_an_open_child_pipe(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "child.gz"
            child = "import time;print('child_pipe',flush=True);time.sleep(20)"
            code = "import subprocess,sys;subprocess.Popen([sys.executable,'-c'," + repr(child) + "])"
            started = time.monotonic()
            with self.assertRaises(subprocess.TimeoutExpired):
                API["bounded_stream"]([sys.executable, "-c", code], path, 1)
            self.assertLess(time.monotonic() - started, 5)
            self.assertIn(b"child_pipe", gzip.decompress(path.read_bytes()))
            receipt = json.loads(path.with_name(path.name + ".process.json").read_text())
            self.assertEqual(receipt["status"], "TIMEOUT")

    def test_nonzero_exit_keeps_original_stderr_and_cannot_pass(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "failed.gz"
            with self.assertRaises(RuntimeError):
                API["bounded_stream"]([sys.executable, "-c",
                    "import sys;print('original_failure',file=sys.stderr);sys.exit(7)"], path, 5)
            self.assertEqual(gzip.decompress(path.read_bytes()), b"original_failure\n")
            receipt = json.loads(path.with_name(path.name + ".process.json").read_text())
            self.assertEqual(receipt["returncode"], 7)
            self.assertEqual(receipt["status"], "FAIL")

    def test_an_existing_attempt_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "existing.gz"
            path.write_bytes(b"retained_prior_attempt")
            with self.assertRaises(FileExistsError):
                API["bounded_stream"]([sys.executable, "-c", "print('new')"], path, 5)
            self.assertEqual(path.read_bytes(), b"retained_prior_attempt")

    def test_every_original_export_kind_and_export_only_engine_symbol_is_retained(self):
        binary = Path("/actual/consumer")
        raw = str(binary) + " [arm64]:\n-exports:\n offset symbol\n" + (
            " 0x01 _ordinary\n 0x02 _weak [weak-def]\n"
            " 0x03 _local_thread [per-thread]\n 0x04 _HanlinNativeScriptRuntime [absolute]\n")
        names, kinds = API["export_names"](raw, binary, "arm64")
        self.assertEqual(names, {"_ordinary", "_weak", "_local_thread", "_HanlinNativeScriptRuntime"})
        self.assertEqual(kinds, {"regular": 1, "weak-def": 1, "per-thread": 1, "absolute": 1})

    def test_malformed_partial_duplicate_and_wrong_slice_exports_fail_closed(self):
        binary = Path("/actual/consumer")
        header = str(binary) + " [arm64]:\n-exports:\n offset symbol\n"
        variants = [header, header + "0x01 _a [unrecognized]\n",
                    header + "0x01 _a\n0x02 _a\n",
                    header.replace("[arm64]", "[x86_64]") + "0x01 _a\n",
                    header + "0x01 _a\nincomplete tail"]
        for raw in variants:
            with self.subTest(raw=raw):
                with self.assertRaises(RuntimeError):
                    API["export_names"](raw, binary, "arm64")

    def test_empty_exports_require_exact_native_load_command_evidence(self):
        text = ("image:\nMach header\n magic cputype cpusubtype caps filetype ncmds sizeofcmds flags\n"
                " 0xfeedfacf 16777228 0 0x00 6 2 64 0x00\n"
                "Load command 0\n cmd LC_DYLD_INFO_ONLY\n cmdsize 48\n"
                " export_off 0\n export_size 0\nLoad command 1\n"
                " cmd LC_DYLD_EXPORTS_TRIE\n cmdsize 16\n dataoff 4096\n datasize 128\n")
        self.assertEqual(API["export_sizes"](text), [
            {"command": "LC_DYLD_INFO_ONLY", "bytes": 0},
            {"command": "LC_DYLD_EXPORTS_TRIE", "bytes": 128}])
        for raw in ["", text.replace("datasize 128", "datasize -1"),
                    text.replace("datasize 128", "datasize 128\ndatasize 12")]:
            with self.subTest(raw=raw):
                with self.assertRaises(RuntimeError):
                    API["export_sizes"](raw)


    def test_empty_preview_needs_both_a_zero_nlist_and_the_original_slice(self):
        binary = Path("/actual/Maktabah.app/__preview.dylib")
        symbols = str(binary) + ": no symbols\n"
        loads = ("Load command 4\n cmd LC_SYMTAB\n nsyms 0\n"
                 "Load command 5\n cmd LC_BUILD_VERSION\n platform 7\n"
                 "Load command 6\n cmd LC_DYLD_EXPORTS_TRIE\n"
                 "Load command 7\n cmd LC_ID_DYLIB\n")
        exports = str(binary) + " [arm64]:\n -exports:\n offset symbol\n"

        self.assertTrue(API["is_symbol_free_xcode_preview"](binary, "arm64", symbols, loads))
        self.assertEqual(API["export_names"](exports, binary, "arm64", allow_empty_preview=True), (set(), {}))
        self.assertFalse(API["is_symbol_free_xcode_preview"](binary, "arm64", symbols, loads.replace("nsyms 0", "nsyms 1")))
        self.assertFalse(API["is_symbol_free_xcode_preview"](binary.with_name("ordinary.dylib"), "arm64", symbols, loads))
        with self.assertRaises(RuntimeError):
            API["export_names"](exports + "incomplete row", binary, "arm64", allow_empty_preview=True)

    def test_partial_missing_duplicate_and_size_mismatched_native_commands_fail(self):
        header = ("image:\nMach header\n magic cputype cpusubtype caps filetype ncmds sizeofcmds flags\n"
                  " 0xfeedfacf 16777228 0 0x00 6 2 48 0x00\n")
        first = "Load command 0\n cmd LC_UUID\n cmdsize 24\n"
        final = "Load command 1\n cmd LC_UUID\n cmdsize 24\n"
        self.assertEqual(API["export_sizes"](header + first + final), [])
        self.assertEqual(API["export_sizes"]((header + first + final) * 2), [])
        partial = ["image:\nLoad command 0\n", header,
                   header + first + "Load command 1\n",
                   header + first + "Load command 1\ncmd LC_UUID\n",
                   header + first + final.replace("command 1", "command 0"),
                   header + first + final.replace("cmdsize 24", "cmdsize 28"),
                   header.replace("6 2 48", "6 3 48") + first + final]
        for text in partial:
            with self.subTest(text=text):
                with self.assertRaises(RuntimeError):
                    API["export_sizes"](text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
