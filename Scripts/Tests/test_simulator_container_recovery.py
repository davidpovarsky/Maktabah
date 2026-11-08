import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("container_recovery", Path(__file__).parents[1] / "CI/resolve_simulator_container.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class NativeContainerRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.home = Path(self.directory.name)
        self.udid = "1DA3F122-69BD-43D7-9512-4A1E0CB0C55A"
        self.bundle = "com.davidpovarsky.chavrusatext"
        self.container = self.home / "Library/Developer/CoreSimulator/Devices" / self.udid / "data/Containers/Data/Application/742A9065-AD26-4EC0-A512-54F2C196AFD1"
        self.container.mkdir(parents=True)
        self.receipt = self.home / "evidence/container.json"
        self.home_patch = patch.object(helper.Path, "home", return_value=self.home)
        self.home_patch.start()
        self.addCleanup(self.home_patch.stop)

    def resolve(self):
        return helper.app_data_container(self.udid, self.bundle, self.receipt)

    def test_actual_45_second_timeout_recovers_only_the_owned_device(self):
        timeout = subprocess.TimeoutExpired(["xcrun", "simctl", "get_app_container"], 45)
        with patch.object(helper.subprocess, "check_output", side_effect=[timeout, str(self.container)]) as query, patch.object(helper.subprocess, "run") as recovery:
            self.assertEqual(self.resolve(), self.container.resolve())
        self.assertEqual([call.kwargs["timeout"] for call in query.call_args_list], [45, 90])
        commands = [call.args[0] for call in recovery.call_args_list]
        self.assertEqual(len(commands), 3)
        self.assertTrue(all(self.udid in command for command in commands))
        self.assertFalse(any("delete" in command or "all" in command for command in commands))
        self.assertEqual([r["status"] for r in json.loads(self.receipt.read_text())["attempts"]], ["TIMEOUT", "RESOLVED"])

    def test_persistent_timeout_fails_after_one_recovery(self):
        with patch.object(helper.subprocess, "check_output", side_effect=subprocess.TimeoutExpired("get_app_container", 45)) as query, patch.object(helper.subprocess, "run") as recovery:
            with self.assertRaises(subprocess.TimeoutExpired): self.resolve()
        self.assertEqual(query.call_count, 2)
        self.assertEqual(recovery.call_count, 3)
        self.assertEqual([r["status"] for r in json.loads(self.receipt.read_text())["attempts"]], ["TIMEOUT", "TIMEOUT"])

    def test_not_installed_error_is_never_retried(self):
        with patch.object(helper.subprocess, "check_output", side_effect=subprocess.CalledProcessError(1, "get_app_container")) as query, patch.object(helper.subprocess, "run") as recovery:
            with self.assertRaises(subprocess.CalledProcessError): self.resolve()
        self.assertEqual(query.call_count, 1)
        recovery.assert_not_called()

    def test_existing_directory_outside_owned_device_is_rejected(self):
        with patch.object(helper.subprocess, "check_output", return_value=str(self.home)), patch.object(helper.subprocess, "run") as recovery:
            with self.assertRaises(RuntimeError): self.resolve()
        recovery.assert_not_called()

    def test_booted_alias_cannot_restart_someone_elses_device(self):
        with patch.object(helper.subprocess, "check_output") as query, patch.object(helper.subprocess, "run") as recovery:
            with self.assertRaises(ValueError): helper.app_data_container("booted", self.bundle, self.receipt)
        query.assert_not_called()
        recovery.assert_not_called()

    def test_actual_private_and_shared_native_receipts_seed_their_own_cache(self):
        shared = self.container.parents[2] / "Shared/AppGroup/CB8AE413-3741-4C46-913F-E9FBFD8BF09D"
        # Actual Debug AppConfig fallback and the actual baseline App Group
        # layout are deliberately different; never seed a guessed common root.
        private = self.container / "Library/Application Support/Maktabah-Debug"
        for root in (private, shared):
            with self.subTest(root=root):
                database = root / "Otzaria/Profiles/miniTest10/database/seforim.db"
                database.parent.mkdir(parents=True, exist_ok=True)
                database.touch()
                # macOS's /var temporary directory is a /private/var alias.
                self.assertEqual(helper.mini_lexical_root(database, self.container), root.resolve() / "Otzaria/SearchResources")

    def test_foreign_application_receipt_cannot_seed_another_apps_cache(self):
        database = self.container.parent / "048C2DBD-433B-4D77-B7A5-C30B8599378B/Library/Application Support/Maktabah-Debug/Otzaria/Profiles/miniTest10/database/seforim.db"
        database.parent.mkdir(parents=True)
        database.touch()
        with self.assertRaises(RuntimeError): helper.mini_lexical_root(database, self.container)

    def test_foreign_profile_receipt_is_rejected(self):
        database = self.container / "Otzaria/Profiles/external/database/seforim.db"
        database.parent.mkdir(parents=True)
        database.touch()
        with self.assertRaises(RuntimeError): helper.mini_lexical_root(database, self.container)


if __name__ == "__main__": unittest.main()
