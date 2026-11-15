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

dispatch = runpy.run_path(str(Path(__file__).with_name('runtime27-hid.py')))['dispatch_request']


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
        self.assertIn('companion unavailable', result['error'])


if __name__ == '__main__':
    unittest.main()
