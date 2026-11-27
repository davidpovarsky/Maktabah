#!/usr/bin/env python3
"""No simulator/contact/network: exercise host state with original idb codec.

The client/probe below are explicit component test doubles. These controls do
not stand in for original app observers, HID delivery, or native UI acceptance.
"""
import asyncio
import copy
import importlib.util
import json
from pathlib import Path
import time
import uuid

from idb.grpc.hid import event_to_grpc

spec = importlib.util.spec_from_file_location("continuous_host", Path(__file__).with_name("reader-continuous-pull-host.py"))
host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(host)

UDID = "11111111-1111-4111-8111-111111111111"
TOKEN = "a" * 48
SCREEN = {"width": 2048, "height": 2732, "density": 2.0, "width_points": 1024, "height_points": 1366}


def request():
    return {"schema": 1, "token": TOKEN, "nonce": str(uuid.uuid4()).upper(), "udid": UDID,
            "mode": "paragraph", "orientation": "portrait",
            "viewportName": "full-v32-reader-" + str(uuid.uuid4()).upper(),
            "appPID": 123, "renderGeneration": 7, "textViewObject": 1234, "sourceUTF16Length": 20,
            "documentID": "22222222-2222-4222-8222-222222222222", "locator": "otzaria|book:28|line:20",
            "createdAt": time.time(), "window": {"x": 0, "y": 0, "width": 1024, "height": 1366},
            "readerFrame": {"x": 10, "y": 70, "width": 1004, "height": 1200},
            "points": [{"x": 512, "y": 300}, {"x": 512, "y": 540}, {"x": 512, "y": 320}]}


def sample(req, ident):
    sel = {"schema": 1, "requestID": ident, "processID": req["appPID"], "locator": req["locator"],
           "renderGeneration": req["renderGeneration"], "textViewObject": req["textViewObject"],
           "sourceUTF16Length": req["sourceUTF16Length"], "status": "EMPTY", "observedUptime": 10.1,
           "usesTextKit2BeforeObservation": True, "usesTextKit2AfterObservation": True}
    return {"requestID": ident, "capturedAt": time.time(), "object": req["textViewObject"],
            "nativeSelectionObservation": sel, "fullV32SourceObservation": {
                "schema": 1, "processID": req["appPID"], "sourceUTF16Length": req["sourceUTF16Length"],
                "status": "AVAILABLE", "observedUptime": 10.0},
            "usesTextKit2BeforeObservation": True, "usesTextKit2AfterObservation": True,
            "contentOffsetY": 0, "topInset": 0, "contentHeight": 3000, "viewportHeight": 1200}


class CodecOnlyClient:
    def __init__(self, break_stream=False):
        self.calls, self.events, self.active, self.break_stream = 0, [], False, break_stream

    async def hid(self, events):
        self.calls += 1
        self.active = True
        try:
            async for event in events:
                message = event_to_grpc(event)
                # Exercise the original installed generated protobuf too.
                message.ParseFromString(message.SerializeToString())
                self.events.append(message)
                if self.break_stream and len(self.events) == 3:
                    raise RuntimeError("explicit test-double transport failure")
        finally:
            await events.aclose()
            self.active = False

    async def send_events(self, events):
        self.calls += 1
        self.events.extend(event_to_grpc(event) for event in events)


class ControlledProbe:
    def __init__(self, client, fail_phase=None):
        self.client, self.fail_phase, self.samples = client, fail_phase, {}
        self.holds = []

    async def capture(self, phase, criterion):
        if phase in ("armed", "retreated"):
            assert self.client.active
            presses = [e for e in self.client.events if e.WhichOneof("event") == "press"]
            assert presses and all(e.press.direction == 0 for e in presses)
            self.holds.append((phase, len(presses)))
        if phase == self.fail_phase:
            raise ValueError("explicit test-double native criterion failure")
        value = {"before": 0, "armed": 105, "retreated": 11, "released": 0}[phase]
        assert criterion(value)
        result = {"requestID": str(uuid.uuid4()).upper(), "testDoubleOverscroll": value}
        self.samples[phase] = result
        return result


async def controls():
    records = []
    def passed(name):
        records.append({"name": name, "status": "PASS", "scope": "host/codec component control; no UI"})
    host.validate_request(request(), TOKEN, UDID, SCREEN)
    passed("original portrait points admitted")
    cases = [
        ("wrong token", lambda r, s: r.update(token="b" * 48)),
        ("wrong UDID", lambda r, s: r.update(udid="33333333-3333-4333-8333-333333333333")),
        ("stale nonce request", lambda r, s: r.update(createdAt=time.time() - 60)),
        ("Boolean schema", lambda r, s: r.update(schema=True)),
        ("missing point dimensions", lambda r, s: s.update(width_points=None)),
        ("pixel/point confusion", lambda r, s: r["window"].update(width=2048, height=2732)),
        ("landscape mismatch", lambda r, s: r.update(orientation="landscapeLeft")),
        ("nonfinite coordinate", lambda r, s: r["points"][1].update(y=float("nan"))),
        ("viewport path escape", lambda r, s: r.update(viewportName="../elsewhere")),
        ("waypoint outside Reader", lambda r, s: r["points"][1].update(x=2000)),
    ]
    for name, change in cases:
        req, screen = request(), dict(SCREEN)
        change(req, screen)
        try:
            host.validate_request(req, TOKEN, UDID, screen)
        except (ValueError, TypeError, KeyError):
            passed(name + " rejected before contact")
        else:
            raise AssertionError(name)
    req = request()
    ident = str(uuid.uuid4()).upper()
    report = sample(req, ident)
    assert host.validate_native(report, req, ident, time.time() - 1, 9) == 10
    passed("fresh native identity shape admitted")
    for name, change in [
        ("stale viewport", lambda r: r.update(requestID=str(uuid.uuid4()).upper())),
        ("wrong original PID", lambda r: r["nativeSelectionObservation"].update(processID=321)),
        ("wrong render generation", lambda r: r["nativeSelectionObservation"].update(renderGeneration=8)),
        ("unavailable native source", lambda r: r["fullV32SourceObservation"].update(status="UNAVAILABLE")),
    ]:
        bad = copy.deepcopy(report)
        change(bad)
        try:
            host.validate_native(bad, req, ident, time.time() - 1, 9)
        except ValueError:
            passed(name + " rejected")
        else:
            raise AssertionError(name)
    client = CodecOnlyClient()
    probe = ControlledProbe(client)
    result = await host.one_contact(client, req, probe)
    presses = [e for e in client.events if e.WhichOneof("event") == "press"]
    assert result["accepted"] and result["rpcCount"] == client.calls == 1
    assert len(presses) == 48 and [e.press.direction for e in presses] == [0] * 47 + [1]
    assert probe.holds == [("armed", 25), ("retreated", 47)]
    assert presses[0].press.action.touch.point.y == 300
    assert presses[24].press.action.touch.point.y == 540
    assert presses[-2].press.action.touch.point.y == presses[-1].press.action.touch.point.y == 320
    passed("original codec preserves one RPC down-held-out-held-back-up")
    client = CodecOnlyClient()
    result = await host.one_contact(client, req, ControlledProbe(client, "retreated"))
    presses = [e for e in client.events if e.WhichOneof("event") == "press"]
    assert not result["accepted"] and result["rpcCount"] == client.calls == 1
    assert len([e for e in presses if e.press.direction == 1]) == 1
    passed("failed native criterion releases once in same stream and fails")
    client = CodecOnlyClient(break_stream=True)
    result = await host.one_contact(client, req, ControlledProbe(client))
    assert not result["accepted"] and result["rpcCount"] == client.calls == 2
    assert result["emergencyReleaseAttempted"] and result["emergencyReleaseDelivered"]
    passed("broken transport cleanup is separately logged and cannot pass")
    return {"schema": 1, "status": "HOST_CODEC_SOURCE_CONTROLS_PASS_NOT_NATIVE_UI",
            "controls": records, "passed": len(records), "failed": 0,
            "simulatorConnections": 0, "touchesSent": 0, "uiExecuted": 0,
            "scope": "Actual installed idb codec/protobuf; explicitly synthetic client/probe doubles only"}


if __name__ == "__main__":
    print(json.dumps(asyncio.run(controls()), indent=2))
