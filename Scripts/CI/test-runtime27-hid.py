"""Transport boundary checks; none represent native UI acceptance."""
import asyncio
import json
import os
from pathlib import Path
import runpy
import sys
import tempfile
import time
from contextlib import asynccontextmanager
from types import ModuleType, SimpleNamespace
import unittest
from unittest.mock import AsyncMock, Mock, patch

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

    async def test_server_writes_actual_success_and_rejection_exports_without_credential(self):
        class StopAfterCycle(Exception):
            pass

        @asynccontextmanager
        async def build(*args, **kwargs):
            self.assertFalse('R27_HID_AUTH_TOKEN' in os.environ)
            yield SimpleNamespace(companion=SimpleNamespace(udid='OWN-UDID'), key=self.client.key)

        async def stop(*args):
            raise StopAfterCycle()

        modules = {name: ModuleType(name) for name in
                   ['idb', 'idb.grpc', 'idb.grpc.client', 'idb.common', 'idb.common.types']}
        modules['idb.grpc.client'].Client = SimpleNamespace(build=build)
        modules['idb.common.types'].DomainSocketAddress = lambda path: SimpleNamespace(path=path)
        folder = Path(self.folder.name)
        documents = folder / 'app' / 'Documents'
        documents.mkdir(parents=True)
        self.path = documents / self.path.name
        args = SimpleNamespace(socket='unused-local-test-socket', udid='OWN-UDID', containers=str(folder),
                               ready=str(folder / 'ready.json'), evidence=str(folder / 'evidence.jsonl'))
        for key, delivered in [(41, True), (self.token, False)]:
            self.payload['key'] = key
            self.path.write_text(json.dumps(self.payload))
            with patch.dict(sys.modules, modules), patch.dict(os.environ, {'R27_HID_AUTH_TOKEN': self.token}), \
                    patch.object(provider['asyncio'], 'sleep', stop):
                with self.assertRaises(StopAfterCycle):
                    await provider['serve'](args)
            exported = Path(args.evidence).read_text()
            ack = self.path.with_name(self.path.name.replace('.request.json', '.ack.json')).read_text()
            self.assertNotIn(self.token, exported)
            self.assertNotIn(self.token, ack)
            self.assertEqual(json.loads(ack)['delivered'], delivered)
        self.client.key.assert_awaited_once_with(41, duration=0.05)

    async def test_startup_argv_is_credential_free_and_auth_is_server_only(self):
        folder = Path(self.folder.name)
        instance = provider['HIDComparison'].__new__(provider['HIDComparison'])
        instance.udid, instance.token, instance.label = 'OWN-UDID', self.token, 'local'
        instance.container = folder / 'app'
        instance.tools = {'companion': 'unused-companion', 'python': 'unused-python'}
        instance.directory, instance.artifacts = folder, folder
        instance.socket, instance.ready = folder / 'socket', folder / 'ready.json'
        instance.socket.touch()
        instance.ready.write_text(json.dumps(dict(udid=instance.udid)))
        instance.logs, instance.processes = [], []
        process = Mock()
        process.poll.return_value = 0
        with patch.object(provider['subprocess'], 'Popen', return_value=process) as spawn, \
                patch.dict(os.environ, {'R27_HID_AUTH_TOKEN': 'inherited-fake'}):
            private_environment = instance.start()
        try:
            self.assertEqual(len(spawn.call_args_list), 2)
            for call in spawn.call_args_list:
                self.assertNotIn(self.token, ' '.join(call.args[0]))
                self.assertNotIn('--token', call.args[0])
            self.assertFalse('R27_HID_AUTH_TOKEN' in spawn.call_args_list[0].kwargs['env'])
            self.assertTrue(spawn.call_args_list[1].kwargs['env'].get('R27_HID_AUTH_TOKEN') == self.token)
            self.assertTrue(private_environment.get('TEST_RUNNER_R27_HID_TOKEN') == self.token)
        finally:
            instance.stop()


if __name__ == '__main__':
    unittest.main()
