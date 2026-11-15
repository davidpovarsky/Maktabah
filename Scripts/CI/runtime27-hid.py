#!/usr/bin/env python3
"""Optional, isolated real HID comparison for the existing native XCTest target.

No app callbacks, AX writes, default idb registry, global install or other UDID.
An ACK proves transport only; native XCTest must assert the actual visible UI.
"""
import argparse
import asyncio
import hashlib
import json
import logging
import os
from pathlib import Path
import platform
import secrets
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request
import venv

VERSION = "1.7.8"
ASSETS = {
    "idb-companion.macos-arm64.tar.gz": "44369a2df0b62e3a1764de61bd09280999c7e9b27ea8f20bff1ea3a9db0302a2",
    "fb_idb-1.7.8-py3-none-any.whl": "ed8557a4c54ffee53006c1fe63f070cda567949312ab24be56faf987c5a3d04b",
}
KEYS = {4, 41, 42, 81, 82}  # A, Escape, Backspace, Down, Up; Apple HID usages.


def prepare(out):
    if sys.platform != "darwin" or platform.machine() != "arm64" or sys.version_info < (3, 12):
        raise RuntimeError("Pinned HID comparison requires arm64 macOS and Python3.12+")
    destination = Path(tempfile.mkdtemp(prefix="r27-hid-tools-", dir=os.environ["RUNNER_TEMP"]))
    for name, digest in ASSETS.items():
        data = urllib.request.urlopen(f"https://github.com/meta/idb/releases/download/v{VERSION}/{name}", timeout=90).read()
        if hashlib.sha256(data).hexdigest() != digest:
            raise RuntimeError(f"Pinned idb asset hash mismatch: {name}")
        (destination / name).write_bytes(data)
    companion_dir = destination / "companion"
    companion_dir.mkdir()
    with tarfile.open(destination / "idb-companion.macos-arm64.tar.gz") as archive:
        archive.extractall(companion_dir, filter="data")
    companion = companion_dir / "idb_companion"
    if not companion.is_file() or not (companion_dir / "Resources/libShimulator-iOS.dylib").is_file():
        raise RuntimeError("Pinned companion layout/resources missing")
    client_dir = destination / "client"
    venv.create(client_dir, with_pip=True)
    python = client_dir / "bin/python"
    subprocess.run([str(python), "-m", "pip", "install", "--disable-pip-version-check", "--no-cache-dir",
                    str(destination / "fb_idb-1.7.8-py3-none-any.whl")], check=True, timeout=180)
    version = subprocess.check_output([str(companion), "--version"], text=True, timeout=20)
    dependencies = subprocess.check_output([str(python), "-m", "pip", "freeze"], text=True, timeout=20)
    # Import before expensive app compilation; the server uses this direct API.
    subprocess.run([str(python), "-c", "from idb.grpc.client import Client; from idb.common.types import DomainSocketAddress"],
                   check=True, timeout=20)
    result = dict(version=VERSION, companion=str(companion), python=str(python),
                  asset_sha256=ASSETS, companion_version=version, client_dependencies=dependencies,
                  registry="NOT_USED_DIRECT_DOMAIN_SOCKET", ui_acceptance="NOT_RUN")
    out.write_text(json.dumps(result, indent=2) + "\n")
    return result


class HIDComparison:
    def __init__(self, udid, container, label, tools, artifacts):
        self.udid = udid
        self.container = Path(container)
        self.label = label
        self.tools = tools
        self.artifacts = artifacts
        self.token = secrets.token_hex(16)
        self.directory = Path(tempfile.mkdtemp(prefix="r27-hid-", dir="/tmp"))
        self.socket = self.directory / "companion.sock"
        self.ready = self.directory / "ready.json"
        self.processes = []
        self.logs = []

    def start(self):
        environment = os.environ.copy()
        environment.update(IDB_COMPANION_TMPDIR=str(self.directory), TMPDIR=str(self.directory))
        commands = [
            [self.tools["companion"], "--udid", self.udid, "--grpc-domain-sock", str(self.socket)],
            [self.tools["python"], str(Path(__file__).resolve()), "serve", "--socket", str(self.socket),
             "--udid", self.udid, "--containers", str(self.container.parent), "--token", self.token,
             "--ready", str(self.ready), "--evidence", str(self.artifacts / f"hid-{self.label}.jsonl")],
        ]
        for index, command in enumerate(commands):
            log = (self.artifacts / f"hid-{self.label}-{index}.log").open("w")
            self.logs.append(log)
            self.processes.append(subprocess.Popen(command, env=environment, stdout=log, stderr=subprocess.STDOUT))
            limit = time.monotonic() + 60
            expected = self.socket if index == 0 else self.ready
            while not expected.exists():
                if self.processes[-1].poll() is not None or time.monotonic() > limit:
                    raise RuntimeError(f"Owned HID process{index} did not become ready; see retained log")
                time.sleep(0.1)
        report = json.loads(self.ready.read_text())
        if report["udid"] != self.udid:
            raise RuntimeError("HID target does not match owned disposable simulator")
        return {"TEST_RUNNER_R27_HID_TOKEN": self.token}

    def stop(self):
        for process in reversed(self.processes):
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
        for log in self.logs:
            log.close()
        # Preserve unique scratch/socket directories; do not clear any idb state.


async def dispatch_request(request, token, udid, client):
    result = {"request": request.name, "udid": udid, "transport": "idb-real-HID", "delivered": False}
    try:
        data = json.loads(request.read_text())
        nonce = data["nonce"]
        key = data["key"]
        if (data["token"] != token or key not in KEYS or isinstance(key, bool)
                or not isinstance(nonce, str) or request.name != f"r27-hid-{token}-{nonce}.request.json"
                or not 0 <= time.time() - request.stat().st_mtime < 30):
            raise ValueError("Invalid/stale/non-whitelisted owned HID request")
        result.update(nonce=nonce, key=key)
        await asyncio.wait_for(client.key(key, duration=0.05), timeout=10)
        result["delivered"] = True
    except Exception as error:
        result["error"] = str(error)
    result["time"] = time.time()
    return result


async def serve(args):
    from idb.grpc.client import Client
    from idb.common.types import DomainSocketAddress
    seen = set()
    async with Client.build(DomainSocketAddress(args.socket), logging.getLogger("r27-hid"), exchange_metadata=False) as client:
        if client.companion.udid.upper() != args.udid.upper():
            raise RuntimeError("Direct companion returned an unexpected UDID")
        Path(args.ready).write_text(json.dumps({"udid": args.udid, "transport": "idb-real-HID"}))
        while True:
            for request in Path(args.containers).glob(f"*/Documents/r27-hid-{args.token}-*.request.json"):
                if request in seen:
                    continue
                seen.add(request)
                result = await dispatch_request(request, args.token, args.udid, client)
                with Path(args.evidence).open("a") as evidence:
                    evidence.write(json.dumps(result) + "\n")
                ack = request.with_name(request.name.replace(".request.json", ".ack.json"))
                temporary = ack.with_suffix(".tmp")
                temporary.write_text(json.dumps(result))
                temporary.replace(ack)
            await asyncio.sleep(0.1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["prepare", "serve"])
    for name in ["socket", "udid", "containers", "token", "ready", "evidence", "out"]:
        parser.add_argument("--" + name)
    args = parser.parse_args()
    if args.mode == "prepare":
        prepare(Path(args.out))
    else:
        asyncio.run(serve(args))
