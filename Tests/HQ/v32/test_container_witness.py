import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("v32_native_driver", ROOT / "Scripts/CI/hq-v32-prebuilt-native.py")
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)


class ContainerWitnessTests(unittest.TestCase):
    udid = "44A35130-BCBE-421F-9467-03D18E8511B3"
    app = "01234567-89AB-CDEF-0123-456789ABCDEF"
    bundle = "com.davidpovarsky.chavrusatext"
    nonce = "a4" * 32

    def witness(self):
        return {
            "schema_version": 1,
            "simulator_udid": self.udid,
            "bundle_id": self.bundle,
            "data_container": "/Users/runner/Library/Developer/CoreSimulator/Devices/" + self.udid
                + "/data/Containers/Data/Application/" + self.app,
            "invocation_nonce": self.nonce,
        }

    def resolve(self, value):
        return driver.validated_container_witness(value, self.udid, self.bundle, self.nonce)

    def rejects(self, **changes):
        value = self.witness()
        value.update(changes)
        with self.assertRaises(RuntimeError):
            self.resolve(value)

    def test_exact_original_container_is_retained_without_service_lookup(self):
        original = self.witness()
        self.assertEqual(self.resolve(original), original["data_container"])

    def test_foreign_simulator_cannot_supply_container(self):
        self.rejects(simulator_udid=self.app)

    def test_foreign_bundle_cannot_supply_container(self):
        self.rejects(bundle_id="foreign.app")

    def test_previous_invocation_nonce_cannot_be_replayed(self):
        self.rejects(invocation_nonce="b5" * 32)

    def test_missing_nonce_is_not_inferred(self):
        self.rejects(invocation_nonce="")

    def test_container_path_must_contain_this_exact_owned_device(self):
        self.rejects(data_container=self.witness()["data_container"].replace(self.udid, self.app))

    def test_simulator_path_cannot_target_another_app_directory_shape(self):
        self.rejects(data_container=self.witness()["data_container"].replace("/Application/", "/Shared/"))

    def test_relative_container_is_rejected(self):
        self.rejects(data_container=self.witness()["data_container"].lstrip("/"))

    def test_traversal_cannot_escape_the_recorded_container(self):
        self.rejects(data_container=self.witness()["data_container"] + "/../" + self.app)

    def test_noncanonical_paths_are_rejected(self):
        for path in ["/" + self.witness()["data_container"], self.witness()["data_container"] + "/",
                     self.witness()["data_container"].replace("/data/", "/./data/")]:
            with self.subTest(path=path):
                self.rejects(data_container=path)

    def test_control_and_windows_separator_paths_are_rejected(self):
        for character in ["\0", "\r", "\n", "\\"]:
            with self.subTest(character=repr(character)):
                self.rejects(data_container=self.witness()["data_container"] + character)

    def test_oversized_path_is_rejected(self):
        self.rejects(data_container="/" + "a" * 4096)

    def test_future_or_boolean_schema_cannot_be_accepted(self):
        for value in [2, True, "1"]:
            with self.subTest(value=value):
                self.rejects(schema_version=value)

    def test_missing_and_unknown_fields_are_rejected(self):
        for key in self.witness():
            value = self.witness()
            del value[key]
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                self.resolve(value)
        self.rejects(unknown="untrusted")

    def test_invalid_container_uuid_is_rejected(self):
        self.rejects(data_container=self.witness()["data_container"].replace(self.app, "not-an-app-uuid"))

    def test_invalid_owned_device_identity_is_rejected(self):
        with self.assertRaises(RuntimeError):
            driver.validated_container_witness(self.witness(), "unknown", self.bundle, self.nonce)

    def test_caller_requires_fresh_strong_nonce(self):
        for nonce in ["", "a" * 63, "g" * 64]:
            with self.subTest(nonce=nonce), self.assertRaises(RuntimeError):
                driver.validated_container_witness(self.witness(), self.udid, self.bundle, nonce)


if __name__ == "__main__":
    unittest.main(verbosity=2)
