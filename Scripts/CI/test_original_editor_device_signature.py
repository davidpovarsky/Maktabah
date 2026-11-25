#!/usr/bin/env python3
"""Portable parser/tamper controls only; these are not device runtime evidence."""
from pathlib import Path
import runpy
import struct
import tempfile
import unittest
import uuid

M = runpy.run_path(str(Path(__file__).with_name("original_editor_device_signature.py")))


def image(*, signature_bytes=64, platform=2, code_byte=b"A", signature_byte=b"s", image_uuid=None):
    image_uuid = image_uuid or uuid.UUID("9f10e1bd-23d9-4ff7-9a2c-5c3a357bb1e6")
    signature_offset = 4096
    linkedit_offset = 2048
    filesize = signature_offset + signature_bytes - linkedit_offset
    segment = struct.pack("<II16sQQQQIIII", 0x19, 72, b"__LINKEDIT", 0x8000,
                          (filesize + 4095) // 4096 * 4096, linkedit_offset, filesize, 1, 1, 0, 0)
    uid = struct.pack("<II", 0x1B, 24) + image_uuid.bytes
    version = struct.pack("<6I", 0x32, 24, platform, 0x1B0000, 0x1B0000, 0)
    signature = struct.pack("<4I", 0x1D, 16, signature_offset, signature_bytes)
    commands = segment + uid + version + signature
    header = struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 6, 4, len(commands), 0, 0)
    payload = (header + commands).ljust(signature_offset, code_byte)
    blob = struct.pack(">III", 0xFADE0CC0, signature_bytes, 0) + signature_byte * (signature_bytes - 12)
    return bytearray(payload + blob)


def fat_image(payload, *, fat64=False):
    offset = 16384
    header = struct.pack(">II", 0xCAFEBABF if fat64 else 0xCAFEBABE, 1)
    entry = (struct.pack(">IIQQII", 0x0100000C, 0, offset, len(payload), 14, 0) if fat64
             else struct.pack(">IIIII", 0x0100000C, 0, offset, len(payload), 14))
    return bytearray((header + entry).ljust(offset, b"\0") + payload)


class DeviceSignatureControls(unittest.TestCase):
    def identity(self, data):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "original"
            path.write_bytes(data)
            return M["macho_identity"](path)

    def test_only_signature_and_linkedit_lengths_may_change(self):
        self.assertEqual(self.identity(image()), self.identity(image(signature_bytes=8192, signature_byte=b"z")))

    def test_one_changed_code_byte_is_not_a_resign(self):
        changed = image()
        changed[1900] ^= 1
        self.assertNotEqual(self.identity(image()), self.identity(changed))

    def test_single_arm64_fat_wrapper_remains_bound_across_signing(self):
        for fat64 in [False, True]:
            with self.subTest(fat64=fat64):
                self.assertEqual(self.identity(fat_image(image(), fat64=fat64)),
                                 self.identity(fat_image(image(signature_bytes=8192), fat64=fat64)))

    def test_multiple_architectures_are_rejected(self):
        changed = fat_image(image())
        struct.pack_into(">I", changed, 4, 2)
        with self.assertRaises(RuntimeError):
            self.identity(changed)

    def test_wrapper_cannot_hide_payload_or_redirect_slice(self):
        for offset in [1000, 19]:
            changed = fat_image(image())
            changed[offset] ^= 1
            with self.subTest(offset=offset), self.assertRaises(RuntimeError):
                self.identity(changed)

    def test_uuid_is_bound(self):
        self.assertNotEqual(self.identity(image()), self.identity(image(image_uuid=uuid.uuid4())))

    def test_simulator_is_not_device_code(self):
        with self.assertRaises(RuntimeError):
            self.identity(image(platform=7))

    def test_fat_and_wrong_cpu_are_rejected(self):
        for offset, value in [(0, 0xCAFEBABE), (4, 0x01000007), (8, 2)]:
            changed = image()
            struct.pack_into("<I", changed, offset, value)
            with self.subTest(offset=offset), self.assertRaises(RuntimeError):
                self.identity(changed)

    def test_trailing_unsigned_bytes_are_rejected(self):
        with self.assertRaises(RuntimeError):
            self.identity(image() + b"foreign")

    def test_command_extent_is_bounded(self):
        changed = image()
        struct.pack_into("<I", changed, 36, 80)
        with self.assertRaises(RuntimeError):
            self.identity(changed)

    def test_signature_cannot_overlap_load_commands(self):
        changed = image()
        struct.pack_into("<I", changed, 32 + 72 + 24 + 24 + 8, 64)
        with self.assertRaises(RuntimeError):
            self.identity(changed)

    def test_non_signature_resources_and_permissions_are_kept(self):
        records = {".": {"mode": 493}, "Core": {"sha256": "code"},
                   "Info.plist": {"sha256": "info", "mode": 420},
                   "Resources/a": {"sha256": "resource", "mode": 420},
                   "_CodeSignature": {"mode": 493}, "_CodeSignature/CodeResources": {"sha256": "signature"}}
        expected = {k: records[k] for k in [".", "Info.plist", "Resources/a"]}
        self.assertEqual(M["resources_without_signature"](records, "Core"), expected)

    def test_real_signing_context_required(self):
        admitted = {"signing_team_id": "NA6HPWARQ2"}
        environment = {"TARGET_NAME": "Maktabah-iOS", "PRODUCT_BUNDLE_IDENTIFIER": M["BUNDLE"],
                       "CONFIGURATION": "Release", "PLATFORM_NAME": "iphoneos", "CODE_SIGNING_ALLOWED": "YES",
                       "EXPANDED_CODE_SIGN_IDENTITY": "A" * 40, "DEVELOPMENT_TEAM": "NA6HPWARQ2"}
        self.assertEqual(M["signing_environment"](admitted, environment), ("A" * 40, "NA6HPWARQ2"))
        for field, value in [("CONFIGURATION", "Debug"), ("PLATFORM_NAME", "iphonesimulator"),
                             ("CODE_SIGNING_ALLOWED", "NO"), ("EXPANDED_CODE_SIGN_IDENTITY", "-"),
                             ("DEVELOPMENT_TEAM", "WRONGTEAM1"), ("TARGET_NAME", "Other")]:
            with self.subTest(field=field), self.assertRaises(RuntimeError):
                M["signing_environment"](admitted, {**environment, field: value})

    def test_signature_directory_cannot_hide_an_extra_payload(self):
        with self.assertRaises(RuntimeError):
            M["resources_without_signature"]({"_CodeSignature/extra.dylib": {"sha256": "extra"}}, "Core")

    def test_receipt_cannot_be_attached_to_another_committed_producer(self):
        original = {"source_sha": "1" * 40, "control_sha": "2" * 40, "native_source_tree": "3" * 40,
                    "configuration": "Release", "platform": "iphoneos", "qualification_sha256": "4" * 64,
                    "signing_team_id": "NA6HPWARQ2", "distribution_root": "build/qualified-sdk",
                    "run_id": "local-9f10e1bd-23d9-4ff7-9a2c-5c3a357bb1e6", "run_attempt": 1,
                    "local_execution_sha256": "5" * 64}
        M["bind_reviewed_configuration"](original, dict(original))
        for field, value in [("source_sha", "6" * 40), ("local_execution_sha256", "7" * 64),
                             ("run_id", "local-223e1c86-05e8-4807-89ac-3d5973b4b389"),
                             ("distribution_root", "build/another-sdk")]:
            with self.subTest(field=field), self.assertRaises(RuntimeError):
                M["bind_reviewed_configuration"](original, {**original, field: value})

    def test_unchanged_signature_cannot_hide_changed_resources(self):
        before = {"executable": "Core", "executable_mode": 493, "identifier": "a.b", "code": {"sha": "same"},
                  "resources": {"Info.plist": {"sha": "original"}}}
        with self.assertRaises(RuntimeError):
            M["same_code_and_resources"](before, {**before, "resources": {"Info.plist": {"sha": "modified"}}})

    def test_code_file_permissions_are_also_preserved(self):
        before = {"executable": "Core", "executable_mode": 493, "identifier": "a.b", "code": {"sha": "same"},
                  "resources": {"Info.plist": {"sha": "original"}}}
        with self.assertRaises(RuntimeError):
            M["same_code_and_resources"](before, {**before, "executable_mode": 420})


class DeviceBuildProductControls(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.products = self.root / "build/DerivedData/BuildProductsPath/Release-iphoneos"
        self.target_parent = self.root / "build/DerivedData/InstallationBuildProductsLocation/Applications"
        self.target = self.target_parent / "Maktabah.app"
        self.target.mkdir(parents=True)
        self.pods = ["FirebaseCore", "nanopb"]
        self.libraries = {}
        for index, pod in enumerate(self.pods):
            library = self.products / pod / ("lib" + pod + ".a")
            library.parent.mkdir(parents=True)
            library.write_bytes(b"!<arch>\n" + bytes([index]) * 128)
            self.libraries[pod] = library
        self.environment = {"ACTION": "install", "CONFIGURATION": "Release", "PLATFORM_NAME": "iphoneos",
                            "TARGET_NAME": M["TARGET"], "PRODUCT_BUNDLE_IDENTIFIER": M["BUNDLE"], "ARCHS": "arm64",
                            "BUILT_PRODUCTS_DIR": str(self.products), "TARGET_BUILD_DIR": str(self.target_parent),
                            "WRAPPER_NAME": "Maktabah.app", "FULL_PRODUCT_NAME": "Maktabah.app"}
        self.source = "a" * 40

    def capture(self):
        return M["host_products_context"](self.root, self.target, self.environment, self.pods, self.source)

    def verify(self, captured):
        return M["verify_host_products"](self.root, captured, self.pods, self.source, str(self.target))

    def test_observed_products_remain_bound_after_app_moves_to_archive(self):
        captured = self.capture()
        archive = self.root / "build/App.xcarchive/Products/Applications"
        archive.mkdir(parents=True)
        self.target.rename(archive / self.target.name)
        self.assertEqual(self.verify(captured), captured)
        self.assertEqual(captured["host_libraries"]["FirebaseCore"]["canonical_path"], str(self.libraries["FirebaseCore"]))

    def test_owned_archive_file_alias_is_recorded_and_must_not_be_retargeted(self):
        library = self.libraries["FirebaseCore"]
        actual = self.root / "build/DerivedData/UninstalledProducts/iphoneos/libFirebaseCore.a"
        actual.parent.mkdir(parents=True)
        library.rename(actual)
        library.symlink_to("../../../UninstalledProducts/iphoneos/libFirebaseCore.a")
        captured = self.capture()
        self.assertEqual(self.verify(captured), captured)
        row = captured["host_libraries"]["FirebaseCore"]
        self.assertEqual(row["canonical_path"], str(actual))
        self.assertEqual(len(row["observed_paths"][0]["alias_hops"]), 1)
        same_bytes = actual.with_name("another.a")
        same_bytes.write_bytes(actual.read_bytes())
        library.unlink()
        library.symlink_to(same_bytes)
        with self.assertRaises(RuntimeError):
            self.verify(captured)

    def test_archive_alias_cannot_leave_owned_build(self):
        library = self.libraries["FirebaseCore"]
        outside = self.root / "external.a"
        library.rename(outside)
        library.symlink_to(outside)
        with self.assertRaises(RuntimeError):
            self.capture()

    def test_parent_segments_cannot_hide_an_intermediate_escaping_alias(self):
        library = self.libraries["FirebaseCore"]
        actual = library.with_name("same.a")
        library.rename(actual)
        outside = self.root / "external-directory"
        outside.mkdir()
        intermediate = library.parent / "redirect"
        intermediate.symlink_to(outside, target_is_directory=True)
        library.symlink_to("redirect/../same.a")
        with self.assertRaises(RuntimeError):
            self.capture()

    def test_library_byte_tamper_and_new_ambiguous_archive_are_refused(self):
        captured = self.capture()
        library = self.libraries["nanopb"]
        original = library.read_bytes()
        library.write_bytes(original[:-1] + b"x")
        with self.assertRaises(RuntimeError):
            self.verify(captured)
        library.write_bytes(original)
        duplicate = self.products / "another" / library.name
        duplicate.parent.mkdir()
        duplicate.write_bytes(original)
        with self.assertRaises(RuntimeError):
            self.capture()

    def test_actual_target_configuration_and_checkout_cannot_be_rebound(self):
        captured = self.capture()
        for key, value in [("TARGET_BUILD_DIR", str(self.products)), ("PLATFORM_NAME", "iphonesimulator"),
                           ("CONFIGURATION", "Debug"), ("ARCHS", "arm64 x86_64")]:
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                M["host_products_context"](self.root, self.target, {**self.environment, key: value}, self.pods, self.source)
        with self.assertRaises(RuntimeError):
            M["verify_host_products"](self.root, captured, self.pods, "b" * 40, str(self.target))


if __name__ == "__main__":
    unittest.main(verbosity=2)
