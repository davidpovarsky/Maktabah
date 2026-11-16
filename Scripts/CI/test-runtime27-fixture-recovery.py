import copy
from pathlib import Path
import runpy
import unittest

eligible = runpy.run_path(str(Path(__file__).with_name('runtime27-fixture-recovery.py')))['verified_fixture_cleanup_timeout']


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


if __name__ == '__main__':
    unittest.main()
