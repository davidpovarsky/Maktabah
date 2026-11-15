"""Transport boundary checks; none represent native UI acceptance."""
import asyncio
import json
import os
from pathlib import Path
import runpy
import tempfile
import time
import unittest
from unittest.mock import AsyncMock

provider = runpy.run_path(str(Path(__file__).with_name('runtime27-hid.py')))
dispatch = provider['dispatch_request']


class HIDBoundaryTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.path = Path(self.folder.name) / 'r27-hid-own-nonce.request.json'
        self.payload = dict(token='own', nonce='nonce', key=41)
        self.client = AsyncMock()

    async def send(self):
        self.path.write_text(json.dumps(self.payload))
        return await dispatch(self.path, 'own', 'OWN-UDID', self.client)

    async def test_one_whitelisted_press_is_transport_only(self):
        result = await self.send()
        self.client.key.assert_awaited_once_with(41, duration=0.05)
        self.assertTrue(result['delivered'])
        self.assertEqual(result['udid'], 'OWN-UDID')
        self.assertNotIn('ui_pass', result)
        self.assertNotIn('request', result)

    async def test_other_job_token_never_sends(self):
        self.payload['token'] = 'other'
        self.assertFalse((await self.send())['delivered'])
        self.client.key.assert_not_awaited()

    async def test_nonwhitelisted_and_boolean_keys_never_send(self):
        for key in [40, True, -1, '41']:
            self.payload['key'] = key
            self.assertFalse((await self.send())['delivered'])
        self.client.key.assert_not_awaited()

    async def test_mismatched_nonce_never_sends(self):
        self.payload['nonce'] = 'different'
        self.assertFalse((await self.send())['delivered'])
        self.client.key.assert_not_awaited()

    async def test_stale_or_future_request_never_sends(self):
        self.path.write_text(json.dumps(self.payload))
        for age in [31, -60]:
            when = time.time() - age
            os.utime(self.path, (when, when))
            self.assertFalse((await dispatch(self.path, 'own', 'OWN-UDID', self.client))['delivered'])
        self.client.key.assert_not_awaited()

    async def test_companion_failure_is_never_delivery_success(self):
        self.client.key.side_effect = RuntimeError('companion unavailable')
        result = await self.send()
        self.assertFalse(result['delivered'])
        self.assertEqual(result['error'], 'HID transport failed')


class HIDEvidencePrivacyTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.token = '0123456789abcdef0123456789abcdef'  # Fixed fake test credential.
        self.nonce = '11111111-2222-4333-8444-555555555555'
        self.path = Path(self.folder.name) / f'r27-hid-{self.token}-{self.nonce}.request.json'
        self.payload = dict(token=self.token, nonce=self.nonce, key=41)
        self.client = AsyncMock()

    async def record(self):
        self.path.write_text(json.dumps(self.payload))
        result = await dispatch(self.path, self.token, 'OWN-UDID', self.client)
        # The same serialization is used for retained JSONL and ACK data.
        serialized = json.dumps(result).casefold()
        self.assertNotIn(self.token.casefold(), serialized)
        self.assertNotIn(self.path.name.casefold(), serialized)
        self.assertNotIn('request', result)
        return result

    async def test_successful_record_preserves_nonce_key_udid_without_credential(self):
        result = await self.record()
        self.assertTrue(result['delivered'])
        self.assertEqual(result['nonce'], self.nonce)
        self.assertEqual(result['key'], 41)
        self.assertEqual(result['udid'], 'OWN-UDID')
        self.assertTrue(result['request_id'])

    async def test_rejected_auth_and_key_never_echo_credential(self):
        for field in ['token', 'key']:
            self.payload = dict(token=self.token, nonce=self.nonce, key=41)
            self.payload[field] = 'wrong' if field == 'token' else self.token
            self.assertFalse((await self.record())['delivered'])
        self.client.key.assert_not_awaited()

    async def test_credential_in_nonce_is_rejected_without_echo(self):
        self.payload['nonce'] = 'nonce-' + self.token.upper()
        self.path = self.path.with_name(f'r27-hid-{self.token}-{self.payload["nonce"]}.request.json')
        self.assertFalse((await self.record())['delivered'])
        self.client.key.assert_not_awaited()

    async def test_transport_exception_private_path_never_reaches_export(self):
        self.client.key.side_effect = RuntimeError('failed path: ' + str(self.path))
        result = await self.record()
        self.assertFalse(result['delivered'])
        self.assertEqual(result['error'], 'HID transport failed')

    async def test_malformed_private_request_never_echoes_filename(self):
        self.path.write_text('{')
        result = await dispatch(self.path, self.token, 'OWN-UDID', self.client)
        self.assertNotIn(self.token, json.dumps(result))
        self.assertFalse(result['delivered'])
        self.client.key.assert_not_awaited()

    async def test_runner_evidence_redacts_raw_environment_and_private_paths(self):
        instance = provider['HIDComparison'].__new__(provider['HIDComparison'])
        instance.token = self.token
        raw = f'R27_HID_TOKEN={self.token.upper()} path={self.path} nonce={self.nonce}'
        exported = instance.redact_evidence(raw)
        self.assertNotIn(self.token.casefold(), exported.casefold())
        self.assertIn(self.nonce, exported)


if __name__ == '__main__':
    unittest.main()
