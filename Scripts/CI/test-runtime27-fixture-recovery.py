import copy
from pathlib import Path
import runpy
import unittest

eligible = runpy.run_path(str(Path(__file__).with_name('runtime27-fixture-recovery.py')))['verified_fixture_cleanup_timeout']
retry_download = runpy.run_path(str(Path(__file__).with_name('runtime27-fixture-recovery.py')))['transient_fixture_download_failure']


class FixtureRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.fixture = dict(passed=True, profileID='miniTest10', bookCount=10, shaMatched=True)
        self.termination = dict(status='TIMEOUT', nativeValidationFailurePreserved=False)

    def test_verified_cleanup_only_is_eligible_once(self):
        self.assertTrue(eligible(self.fixture, self.termination, 0))
        self.assertFalse(eligible(self.fixture, self.termination, 1))

    def test_invalid_or_other_profile_fixture_never_recovers(self):
        for key, value in [('passed', False), ('passed', None), ('profileID', 'production'),
                           ('bookCount', 9), ('shaMatched', False)]:
            fixture = copy.deepcopy(self.fixture)
            fixture[key] = value
            self.assertFalse(eligible(fixture, self.termination, 0))
        self.assertFalse(eligible({}, self.termination, 0))

    def test_original_native_validation_failure_never_recovers(self):
        self.termination['nativeValidationFailurePreserved'] = True
        self.assertFalse(eligible(self.fixture, self.termination, 0))

    def test_missing_or_other_termination_result_never_recovers(self):
        for termination in [{}, dict(status='PASS', nativeValidationFailurePreserved=False), dict(status='TIMEOUT')]:
            self.assertFalse(eligible(self.fixture, termination, 0))

    def test_native_download_transient_errors_retry_only_once(self):
        for error in ['HTTP 502', 'Request failed: HTTP 503', 'HTTP 504',
                      'A server with the specified hostname could not be found.']:
            with self.subTest(error=error):
                fixture = dict(passed=False, profileID='miniTest10', phase='install', errors=[error])
                self.assertTrue(retry_download(fixture, 0))
                self.assertFalse(retry_download(fixture, 1))

    def test_download_recovery_never_hides_data_validation_or_other_failures(self):
        fixture = dict(passed=False, profileID='miniTest10', phase='install', errors=['HTTP 503'])
        for key, value in [('passed', True), ('passed', None), ('phase', 'validate'),
                           ('profileID', 'production'), ('errors', []), ('errors', 'HTTP 503'),
                           ('errors', ['HTTP 503', 'SHA256 mismatch']), ('errors', ['HTTP 404']),
                           ('errors', ['The request timed out.']), ('errors', [None])]:
            with self.subTest(key=key, value=value):
                self.assertFalse(retry_download({**fixture, key: value}, 0))
        self.assertFalse(retry_download({}, 0))


if __name__ == '__main__':
    unittest.main()
