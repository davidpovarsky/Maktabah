#!/usr/bin/env python3
"""Owned macOS PF window for original Simulator UI, never physical-airplane-mode.

Importing this module has no effects. Deployment/activation are explicit and
require a separately coordinated private lease. Source controls use pure policy
functions; neither a control fixture nor a claimed status is network evidence.

This self-contained file is copied to a fresh root-owned directory before its
launchd watchdog can run. Privileged entry points accept only that sealed copy.
All full receipts contain private control addresses and stay OUTSIDE public Git.
"""
import argparse
import contextlib
import datetime as dt
import hashlib
import ipaddress
import importlib.util
import json
import math
import os
from pathlib import Path
import plistlib
import re
import shlex
import signal
import stat
import subprocess
import sys
import threading
import time
import uuid

VERSION = "otzaria.owned-offline-window/1"
BASE = Path("/Library/Application Support/OtzariaOffline")
DAEMONS = Path("/Library/LaunchDaemons")
PYTHON = "/usr/bin/python3"
MAX_DENIAL_SECONDS = 900
HEARTBEAT_TIMEOUT = 30
MAX_WATCHDOG_GAP = 8
MAX_PRIVATE_BYTES = 16 * 1024 * 1024
MAX_COMMAND_BYTES = 4 * 1024 * 1024
CASE_IDS = {
    "zayit": "Maktabah-iOSUITests/PublishedProductionSearchDataTests/testPublishedV40ZayitPages50_100_150RetainSQLIdentity",
    "otzaria": "Maktabah-iOSUITests/PublishedProductionSearchDataTests/testPublishedV40OtzariaPagesRetainCumulativeSQLMetadata",
}
ENDPOINTS = {
    "github-v40": "https://api.github.com/repos/Otzaria/SeforimLibrary/releases/455390662",
    "sefaria-psalms": "https://www.sefaria.org/api/index/Psalms",
}
TRANSPORT_ERRORS = {-1001, -1003, -1004, -1005, -1006, -1009}
PF_DIAGNOSTICS = {
    "No ALTQ support in kernel", "ALTQ related functions disabled",
    "pfctl: Use of -f option, could result in flushing of rules",
    "present in the main ruleset added by the system at startup.",
    "See /etc/pf.conf for further details.",
}
ROOT_FILTER = ['scrub-anchor "com.apple/*" all fragment reassemble', 'anchor "com.apple/*" all']
PS_ROW = re.compile(r"\s*(\d+)\s+(\d+)\s+([A-Za-z]{3}\s+[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}\s+\d{4})\s+(.+)\Z")
SSHD_IMAGES = {"/usr/sbin/sshd", "/usr/libexec/sshd-session", "/usr/libexec/sshd-keygen-wrapper"}
VNC_IMAGE = "/System/Library/CoreServices/RemoteManagement/screensharingd.bundle/Contents/MacOS/screensharingd"


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def strict_json(raw):
    def pairs(values):
        result = {}
        for key, value in values:
            require(key not in result, "Repeated JSON key")
            result[key] = value
        return result
    def invalid(value):
        raise ValueError("Nonfinite JSON number")
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid)


def finite(value, minimum=0):
    return type(value) in (int, float) and math.isfinite(value) and value >= minimum


def window_id(value):
    require(isinstance(value, str) and re.fullmatch(r"[a-f0-9]{32}", value), "Invalid owned window identifier")
    require(uuid.UUID(hex=value).hex == value, "Noncanonical owned identifier")
    return value


def anchor_name(value):
    return "com.apple/000.otzaria-offline-" + window_id(value)


def label_name(value):
    return "com.otzaria.offline." + window_id(value)


def canonical(path, directory=False):
    p = Path(path)
    require(p.is_absolute() and p.resolve(strict=True) == p and not p.is_symlink(), "Noncanonical path")
    s = p.lstat()
    require(stat.S_ISDIR(s.st_mode) if directory else stat.S_ISREG(s.st_mode), "Wrong path kind")
    return p


def stamp(s):
    return [s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns]


def read_bytes(path, maximum=MAX_COMMAND_BYTES):
    p = canonical(path)
    before = p.lstat()
    require(before.st_size <= maximum and before.st_nlink == 1, "Oversized or linked file")
    with p.open("rb") as handle:
        require(stamp(os.fstat(handle.fileno())) == stamp(before), "File changed before read")
        raw = handle.read(maximum + 1)
        require(stamp(os.fstat(handle.fileno())) == stamp(before), "File changed while reading")
    require(len(raw) == before.st_size and stamp(p.lstat()) == stamp(before), "File changed after read")
    return raw


def witness(path):
    raw = read_bytes(path, MAX_PRIVATE_BYTES)
    return {"path": str(path), "bytes": len(raw), "sha256": digest(raw)}


def private_write(path, value, replace=False):
    p = Path(path)
    raw = json.dumps(value, sort_keys=True, indent=2, allow_nan=False).encode() + b"\n"
    require(len(raw) <= MAX_PRIVATE_BYTES, "Private receipt exceeded its limit")
    if replace:
        tmp = p.with_name(p.name + "." + uuid.uuid4().hex + ".tmp")
    else:
        tmp = p
    descriptor = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(raw); handle.flush(); os.fsync(handle.fileno())
        if replace:
            require(not p.is_symlink(), "Refuse a symlink receipt")
            os.replace(tmp, p)
        directory = os.open(p.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if replace and tmp.exists():
            tmp.unlink()
    return {"path": str(p), "bytes": len(raw), "sha256": digest(raw)}


def run(command, timeout=6, maximum=MAX_COMMAND_BYTES, allowed=(0,)):
    require(isinstance(command, list) and all(isinstance(x, str) and x and "\0" not in x for x in command), "Invalid literal command")
    env = {**os.environ, "LC_ALL": "C", "TZ": "UTC"}
    result = subprocess.run(command, capture_output=True, timeout=timeout, env=env)
    require(len(result.stdout) + len(result.stderr) <= maximum, "Command output exceeded its limit")
    require(result.returncode in allowed, "Command failed: " + command[0] + " exit " + str(result.returncode))
    return result.returncode, result.stdout.decode("utf-8"), result.stderr.decode("utf-8")


def pf_output(stdout, stderr):
    require(all(line.strip() in PF_DIAGNOSTICS for line in stderr.splitlines() if line.strip()),
            "Unexpected PF diagnostic, even with exit zero")
    return stdout.strip()


def pf(*arguments):
    _, stdout, stderr = run(["/sbin/pfctl", *arguments])
    return pf_output(stdout, stderr)


def parse_anchor_children(raw, parent):
    result = []
    for line in raw.splitlines():
        name = line.strip()
        require(re.fullmatch(r"[A-Za-z0-9_.\-/]+", name) and not any(v in name for v in ("..", "//", "*")), "Unknown PF anchor listing")
        if parent and not name.startswith(parent + "/"):
            name = parent + "/" + name
        require(name.rsplit("/", 1)[0] == parent if "/" in name else parent == "", "PF listing is not a direct child")
        require(name not in result, "Repeated PF child")
        result.append(name)
    return sorted(result)


def vnc_state(line):
    match = re.fullmatch(r"(ALL|en[0-9]+) tcp (\S+) <- (\S+) <- (\S+)\s+([A-Z_]+):([A-Z_]+)", line.strip())
    require(match is not None, "Unsupported translated control state format")
    return {"interface": match[1], "server": list(parse_endpoint(match[2])),
            "public": list(parse_endpoint(match[3])), "peer": list(parse_endpoint(match[4])),
            "tcpStates": [match[5], match[6]]}


def admit_pf_states(raw, controls, translated_vnc=()):
    admitted = []
    seen_vnc = []
    for line in raw.splitlines():
        # A translated/NAT chain has a third endpoint. It cannot be silently
        # treated as an ordinary SSH tuple (the observed live VNC state has one).
        match = re.fullmatch(r"(ALL|en[0-9]+) tcp (\S+) (->|<-) (\S+)\s+([A-Z_]+):([A-Z_]+)", line.strip())
        if match is None and line.count("<-") == 2:
            observed = vnc_state(line)
            matches = [value for value in translated_vnc if observed == value["state"]]
            require(len(matches) == 1 and observed["tcpStates"] == ["ESTABLISHED", "ESTABLISHED"],
                    "Translated state is not the exact still-established admitted VNC control")
            seen_vnc.append(matches[0]["stateLineSHA256"])
            admitted.append({"state": line, "existingTranslatedVNC": matches[0]["stateLineSHA256"]})
            continue
        require(match is not None, "Unhandled, translated or non-TCP PF state remains")
        first, second = parse_endpoint(match[2]), parse_endpoint(match[4])
        eligible = []
        for control in controls:
            local, peer = (first, second) if first[0] == control["localAddress"] else (second, first)
            if local != (control["localAddress"], control["localPort"]) or peer[0] != control["peerAddress"]:
                continue
            if control["direction"] == "outgoing" and peer[1] != control["peerPort"]:
                continue
            if match[1] not in ("ALL", control["interface"]):
                continue
            eligible.append(control)
        require(len(eligible) == 1, "PF state is not one explicitly admitted control transport")
        require(match[5] in ("ESTABLISHED", "FIN_WAIT_1", "FIN_WAIT_2", "CLOSING", "TIME_WAIT", "CLOSED")
                and match[6] in ("ESTABLISHED", "FIN_WAIT_1", "FIN_WAIT_2", "CLOSING", "TIME_WAIT", "CLOSED"),
                "Unqualified control state")
        admitted.append({"state": line, "control": eligible[0]})
    require(sorted(seen_vnc) == sorted(value["stateLineSHA256"] for value in translated_vnc),
            "An admitted existing translated VNC control state disappeared or changed")
    return admitted


def pf_snapshot(owned, controls, translated_vnc=()):
    require(owned == anchor_name(owned.rsplit("-", 1)[-1]), "Invalid owned anchor")
    enabled = pf("-s", "info")
    require(re.search(r"(?m)^Status: Enabled\b", enabled), "PF is not already enabled")
    queue, nodes = [""], {}
    while queue:
        parent = queue.pop(0)
        require(len(nodes) < 128 and parent.count("/") < 8, "PF hierarchy exceeds bounded inspection")
        prefix = ["-a", parent] if parent else []
        children = parse_anchor_children(pf(*prefix, "-s", "Anchors"), parent)
        children = [child for child in children if child != owned]
        tables = []
        for name in pf(*prefix, "-s", "Tables").splitlines():
            name = name.strip()
            require(re.fullmatch(r"[A-Za-z0-9_.-]+", name), "Unknown PF table listing")
            tables.append({"name": name, "contents": pf(*prefix, "-t", name, "-T", "show")})
        nodes[parent] = {"children": children, "filter": pf(*prefix, "-sr"),
                         "translation": pf(*prefix, "-sn"), "tables": tables}
        queue.extend(children)
    require(nodes[""]["filter"].splitlines() == ROOT_FILTER, "Unsupported root dispatch or earlier quick rule")
    require("com.apple" in nodes and all(owned < child for child in nodes["com.apple"]["children"]),
            "Owned anchor would not be the first wildcard child")
    admit_pf_states(pf("-ss"), controls, translated_vnc)
    for value in translated_vnc:
        original = nodes.get("com.apple/scaleway", {})
        require(digest(original.get("filter", "").encode()) == value["filterRulesSHA256"]
                and digest(original.get("translation", "").encode()) == value["translationRulesSHA256"],
                "Translated VNC rules differ from their actual private source receipt")
        expected_rdr = "rdr on " + value["interface"] + " inet proto tcp from any to any port = " + str(value["state"]["public"][1]) \
            + " tag VNC_REDIRECT -> " + value["state"]["server"][0] + " port " + str(value["state"]["server"][1])
        require(original.get("translation", "").splitlines() == [expected_rdr], "Translated VNC chain is not the exact observed original Scaleway redirect")
    # Control states may change during fresh SSH heartbeat connections. Compare
    # immutable rule/configuration bytes; separately admit every current state.
    return {"enabled": True, "nodes": nodes, "statePolicy": "only-explicit-admitted-ssh-control-tuples"}


def process(pid, command=True):
    _, stdout, stderr = run(["/bin/ps", "-ww", "-p", str(pid), "-o", "pid=,ppid=,lstart=," + ("command=" if command else "comm=")], allowed=(0, 1))
    require(not stderr, "Process inventory diagnostic")
    lines = [line for line in stdout.splitlines() if line.strip()]
    if not lines:
        return None
    require(len(lines) == 1, "Ambiguous PID")
    match = PS_ROW.fullmatch(lines[0])
    require(match is not None and int(match[1]) == pid, "Unparseable actual process identity")
    return {"pid": pid, "parentPID": int(match[2]), "startUTC": match[3], "command": match[4]}


def process_is_same(expected):
    return process(expected["pid"]) == expected


def boot_identity():
    _, value, error = run(["/usr/sbin/sysctl", "-n", "kern.bootsessionuuid"])
    require(not error and re.fullmatch(r"[A-Fa-f0-9-]{36}\s*", value), "Missing actual boot-session identity")
    return str(uuid.UUID(value.strip()))


def parse_endpoint(value):
    match = re.fullmatch(r"\[([^\]]+)\]:(\d+)", value)
    if match:
        address, port = match[1], int(match[2])
    else:
        alternate = re.fullmatch(r"([^\[\]]+)\[(\d+)\]", value)
        if alternate:
            address, port = alternate[1], int(alternate[2])
        else:
            address, port_text = value.rsplit(":", 1)
            port = int(port_text)
    address = str(ipaddress.ip_address(address))
    require(0 < port <= 65535, "Invalid transport port")
    return address, port


def parse_lsof(raw):
    sockets, current_process, current = [], {}, None
    for line in raw.splitlines():
        require(line, "Empty lsof record")
        key, value = line[0], line[1:]
        if key == "p":
            current_process = {"pid": int(value)}; current = None
        elif key == "c":
            current_process["name"] = value
        elif key == "f":
            require("pid" in current_process and "name" in current_process, "Socket lacks an owner")
            current = {**current_process, "fd": value}; sockets.append(current)
        elif key in ("n", "P"):
            require(current is not None and key not in current, "Malformed lsof socket field")
            current[key] = value
        elif key == "T":
            require(current is not None and "=" in value, "Malformed lsof TCP state")
            a, b = value.split("=", 1)
            require(a not in current, "Repeated lsof state")
            current[a] = b
        else:
            raise ValueError("Unrecognized lsof field")
    return sockets


def connections():
    code, stdout, stderr = run(["/usr/sbin/lsof", "-nP", "-i", "-FpcfnPT"], allowed=(0, 1))
    require(not stderr and (code == 0 or not stdout), "Incomplete socket inventory")
    return parse_lsof(stdout)


def normalize_control(value):
    require(isinstance(value, dict), "Control tuple must be an object")
    require(value.get("direction") in ("incoming", "outgoing") and value.get("transport") == "ssh-tcp", "Unhandled control transport")
    result = {key: value[key] for key in ("direction", "transport", "localAddress", "localPort", "peerAddress", "peerPort", "interface")}
    result["localAddress"] = str(ipaddress.ip_address(result["localAddress"]))
    result["peerAddress"] = str(ipaddress.ip_address(result["peerAddress"]))
    require(ipaddress.ip_address(result["localAddress"]).version == ipaddress.ip_address(result["peerAddress"]).version,
            "Control address families differ")
    require(not ipaddress.ip_address(result["peerAddress"]).is_loopback, "Public control peer cannot be loopback")
    require(all(type(result[key]) is int and 0 < result[key] <= 65535 for key in ("localPort", "peerPort")), "Invalid control ports")
    require(re.fullmatch(r"en[0-9]+", result["interface"]), "Unhandled control interface/tunnel")
    require(result["localPort"] == 22 if result["direction"] == "incoming" else result["peerPort"] == 22,
            "Only admitted authenticated SSH transport is implemented")
    return result


def admitted_socket(row, controls):
    if "->" not in row.get("n", ""):
        # A forwarded SSH listening port could carry public traffic over a
        # permitted control channel; reject it, including a loopback listener.
        if row.get("name", "").startswith("ssh") and row.get("P") == "TCP":
            require(row.get("n", "").endswith(":22"), "SSH forwarding listener is unsupported")
        return None
    local, peer = map(parse_endpoint, row["n"].split("->"))
    if ipaddress.ip_address(local[0]).is_loopback and ipaddress.ip_address(peer[0]).is_loopback:
        require(not row.get("name", "").startswith("ssh"), "Loopback SSH forwarding is not eligible")
        return None
    require(row.get("P") == "TCP" and row.get("ST") == "ESTABLISHED", "Non-control or unfinished Internet transport remains")
    matches = []
    for control in controls:
        if local[0] != control["localAddress"] or peer[0] != control["peerAddress"] or local[1] != control["localPort"]:
            continue
        if control["direction"] == "outgoing" and peer[1] != control["peerPort"]:
            continue
        require(row.get("name", "").startswith("sshd") if control["direction"] == "incoming" else row.get("name") == "ssh",
                "A non-SSH process uses a reserved control tuple")
        matches.append(control)
    require(len(matches) == 1, "Unexpected/ambiguous non-loopback socket")
    return matches[0]


def admit_connections(rows, controls, translated_vnc=(), allow_denied_pending=False):
    found = set()
    for value in translated_vnc:
        owner = value["owner"]
        require(process(owner["pid"], command=False) == owner and owner["command"] == VNC_IMAGE,
                "Actual translated VNC owner process changed")
        require(stamp(root_file(VNC_IMAGE).stat()) == value["ownerImageStat"], "Original VNC image identity changed")
        owned = [row for row in rows if row["pid"] == owner["pid"]]
        require(any(row.get("P") == "TCP" and row.get("ST") == "LISTEN" and row.get("n", "").endswith(":5900") for row in owned),
                "Actual VNC owner no longer owns its original listener")
        active = [row for row in owned if row.get("P") == "TCP" and row.get("ST") == "ESTABLISHED" and "->" in row.get("n", "")]
        require(value["connection"] in active and len(active) == 1, "Actual exact translated VNC connection is absent or ambiguous")
    for row in rows:
        if any(row == value["connection"] for value in translated_vnc):
            continue
        if allow_denied_pending and "->" in row.get("n", ""):
            # An actual negative URLSession request may briefly have SYN_SENT,
            # or a connected DNS UDP socket, while PF denies its packets. These
            # are allowed ONLY after the exact active deny rule and complete PF
            # state table were verified in this same watchdog iteration. Never
            # allow an established public socket or an existing public PF state.
            if (row.get("P") == "TCP" and row.get("ST") in ("SYN_SENT", "CLOSED")) or row.get("P") == "UDP":
                continue
        control = admitted_socket(row, controls)
        if control is not None:
            owner = process(row["pid"])
            require(owner is not None, "Control process vanished")
            command = owner["command"]
            require(not re.search(r"(?:^|\s)-(?:[LRDWwJ]|o\s*(?:Proxy|LocalForward|RemoteForward|DynamicForward))", command),
                    "SSH tunnel/forward/proxy control is unsupported")
            found.add(json.dumps(control, sort_keys=True))
    # Incoming peer ports may change for fresh authenticated Oracle heartbeats,
    # but every distinct admitted address/interface must remain represented.
    require(found == {json.dumps(control, sort_keys=True) for control in controls}, "An admitted control tuple is missing")
    return rows


def route_identity(address):
    family = "-inet6" if ipaddress.ip_address(address).version == 6 else "-inet"
    _, raw, error = run(["/sbin/route", "-n", "get", family, address])
    require(not error, "Unqualified route diagnostic")
    fields = dict(re.findall(r"(?m)^\s*(destination|gateway|interface|flags):\s*(.*?)\s*$", raw))
    require(fields.get("interface") and not re.match(r"(?:utun|tun|tap|ppp|gif|stf|ipsec)", fields["interface"]), "Control route uses unsupported tunnel")
    return fields


def network_snapshot(controls, translated_vnc=()):
    _, proxy, error = run(["/usr/sbin/scutil", "--proxy"])
    require(not error and not re.search(r"(?:Enable\s*:\s*[1-9]|ProxyAutoConfigURLString\s*:)", proxy), "An enabled system proxy/PAC is unsupported")
    require(not any(key.lower() in ("http_proxy", "https_proxy", "all_proxy") and value
                    for key, value in os.environ.items()), "Proxy environment is unsupported")
    routes = {control["peerAddress"]: route_identity(control["peerAddress"]) for control in controls}
    require(all(routes[c["peerAddress"]]["interface"] == c["interface"] for c in controls), "Control route differs from lease")
    for value in translated_vnc:
        address = value["state"]["peer"][0]
        routes[address] = route_identity(address)
        require(routes[address]["interface"] == value["interface"], "Translated VNC peer route changed")
    return {"proxy": proxy, "controlRoutes": routes}


def make_rules(identifier, controls):
    name = window_id(identifier)
    rules = []
    for number, control in enumerate(controls):
        family = "inet6" if ipaddress.ip_address(control["localAddress"]).version == 6 else "inet"
        peer_port = " port " + str(control["peerPort"]) if control["direction"] == "outgoing" else ""
        rules.append('pass out quick on ' + control["interface"] + " " + family + " proto tcp from "
                     + control["localAddress"] + " port " + str(control["localPort"]) + " to "
                     + control["peerAddress"] + peer_port + ' flags any no state label "otzaria-ssh-' + name + '-' + str(number) + '"')
    rules.append('block return out quick on ! lo0 all label "otzaria-denial-' + name + '"')
    return "\n".join(rules) + "\n"


def admit_lease(value, source_sha, now=None):
    now = time.time() if now is None else now
    require(value.get("schema") == VERSION and value.get("status") == "COORDINATED_EXCLUSIVE_OFFLINE_WINDOW", "No coordinated exclusive window")
    window_id(value.get("windowID"))
    require(value.get("controllerSourceSHA256") == source_sha, "Coordinator approved another controller source")
    require(value.get("mode") in ("network-denial", "watchdog-exercise-no-denial"), "Unknown owned-window mode")
    require(value.get("selectedCaseID") in CASE_IDS.values(), "The original page selector is not admitted")
    require(isinstance(value.get("coordinatingOwners"), list) and len(set(value["coordinatingOwners"])) >= 2
            and all(isinstance(s, str) and s for s in value["coordinatingOwners"]), "Missing owner coordination")
    require(value.get("allOtherNetworkAndNativeWorkPaused") is True, "Shared Mac exclusivity is not agreed")
    start, end = value.get("notBeforeUnix"), value.get("hardDeadlineUnix")
    require(finite(start, 1) and finite(end, 1) and start <= now < end and end - now <= MAX_DENIAL_SECONDS,
            "Expired, premature or overlong window; no implicit extension")
    controls = [normalize_control(v) for v in value.get("controls", [])]
    require(controls and len(controls) <= 16 and len({json.dumps(v, sort_keys=True) for v in controls}) == len(controls), "Missing/repeated control tuples")
    incoming = [c for c in controls if c["direction"] == "incoming"]
    require(any(c["peerAddress"] == value.get("oracleHeartbeatPeer") for c in incoming), "Pinned Oracle peer is not an admitted incoming SSH peer")
    require(type(value.get("controllerPID")) is int and value["controllerPID"] > 1, "Missing actual controller PID")
    require(str(uuid.UUID(value.get("simulatorUDID", ""))).upper() == value["simulatorUDID"], "Invalid original Simulator identity")
    vnc = value.get("translatedVNC", [])
    require(isinstance(vnc, list) and len(vnc) <= 1, "Only one explicitly owned existing translated VNC control is implemented")
    for record in vnc:
        require(record.get("coordinatorConfirmedControlOnly") is True, "No explicit translated VNC control-owner coordination")
        observed = vnc_state(record["stateLine"])
        require(observed == record.get("state") and observed["tcpStates"] == ["ESTABLISHED", "ESTABLISHED"]
                and observed["server"][1] == 5900 and observed["public"][1] == 59010
                and all(ipaddress.ip_address(observed[key][0]).version == 4 for key in ("server", "public", "peer"))
                and re.fullmatch(r"en[0-9]+", record.get("interface", "")), "Unqualified original translated VNC chain")
        require(digest(record["stateLine"].encode()) == record.get("stateLineSHA256"), "Original VNC raw state identity differs")
        require(all(re.fullmatch(r"[a-f0-9]{64}", record.get(key, "")) for key in ("filterRulesSHA256", "translationRulesSHA256")), "Missing original VNC rule witnesses")
        owner, connection = record.get("owner", {}), record.get("connection", {})
        require(type(owner.get("pid")) is int and owner["pid"] > 1 and owner.get("command") == VNC_IMAGE
                and connection.get("pid") == owner["pid"] and connection.get("name") == "screensharingd"
                and connection.get("P") == "TCP" and connection.get("ST") == "ESTABLISHED",
                "Only the actual original screen-sharing owner/connection qualifies")
        endpoints = connection.get("n", "").split("->")
        require(len(endpoints) == 2 and list(parse_endpoint(endpoints[0])) == observed["server"]
                and list(parse_endpoint(endpoints[1])) == observed["peer"], "VNC process socket does not match the complete translated state")
        require(isinstance(record.get("ownerImageStat"), list) and len(record["ownerImageStat"]) == 5,
                "Missing actual original VNC image stat identity")
    return {**value, "controls": controls, "translatedVNC": vnc}


def watchdog_reason(*, now_mono, now_unix, last_tick, sealed, heartbeat, controller_alive,
                    actual_boot, original_unchanged, own_rules_match, activated, finish):
    """Pure earliest-failure policy shared by the actual watchdog and controls."""
    if actual_boot != sealed["bootSession"]:
        return "boot-session-changed"
    if now_mono >= sealed["hardDeadlineMonotonic"] or now_unix >= sealed["lease"]["hardDeadlineUnix"]:
        return "hard-deadline"
    if now_mono < last_tick or now_mono - last_tick > MAX_WATCHDOG_GAP:
        return "watchdog-observation-gap"
    if not controller_alive:
        return "controller-identity-missing"
    if heartbeat is None or heartbeat.get("bootSession") != actual_boot or not finite(heartbeat.get("observedMonotonic")):
        return "authenticated-oracle-heartbeat-missing"
    if not 0 <= now_mono - heartbeat["observedMonotonic"] <= HEARTBEAT_TIMEOUT:
        return "authenticated-oracle-heartbeat-expired"
    if activated and not original_unchanged:
        return "original-network-or-pf-drift"
    if activated and not own_rules_match:
        return "owned-rules-missing-or-changed"
    if finish:
        return "normal-finish-requested"
    return None


def sealed_dir(identifier):
    return BASE / window_id(identifier)


def root_file(path):
    p = canonical(path)
    s = p.lstat()
    require(s.st_uid == 0 and not s.st_mode & 0o022 and s.st_nlink == 1, "Sealed file is not exclusively root-owned")
    for parent in [p.parent, *p.parents[1:]]:
        st = parent.stat()
        require(st.st_uid == 0 and not st.st_mode & 0o022, "A sealed ancestor is writable by another account")
    return p


def load_sealed(identifier):
    require(os.geteuid() == 0 and sys.platform == "darwin", "Privileged entry requires macOS root")
    directory = sealed_dir(identifier)
    require(Path(__file__).resolve() == directory / "watchdog.py", "Only the sealed private copy can operate PF")
    raw = read_bytes(root_file(directory / "sealed.json"))
    sealed = strict_json(raw)
    require(sealed["windowID"] == identifier and sealed["sourceSHA256"] == digest(read_bytes(root_file(__file__))), "Sealed code/configuration mismatch")
    root_file(PYTHON)
    require(sealed["pythonSHA256"] == digest(read_bytes(PYTHON, 64 * 1024 * 1024)), "Apple system Python shim changed")
    return directory, sealed


def verify_actual_watchdog_exercises(lease, source_sha):
    expected = {"controller-death": "controller-identity-missing", "deadline": "hard-deadline",
                "heartbeat-loss": "authenticated-oracle-heartbeat-expired"}
    records = lease.get("watchdogExerciseReceipts")
    require(isinstance(records, dict) and set(records) == set(expected), "Real no-denial watchdog exercises are required before activation")
    seen = set()
    for key, reason in expected.items():
        record = records[key]
        require(witness(root_file(record["path"])) == record, "Exercise receipt bytes changed")
        value = strict_json(read_bytes(record["path"], MAX_PRIVATE_BYTES))
        identifier = window_id(value.get("windowID"))
        require(identifier not in seen and identifier != lease["windowID"], "Exercise window reused")
        seen.add(identifier)
        directory = sealed_dir(identifier)
        require(Path(record["path"]) == directory / "cleanup.json", "Exercise is not an actual root-owned watchdog receipt")
        sealed = strict_json(read_bytes(root_file(directory / "sealed.json")))
        unloaded = strict_json(read_bytes(root_file(directory / "unloaded.json")))
        armed = strict_json(read_bytes(root_file(directory / "armed.json")))
        require(sealed["sourceSHA256"] == source_sha and sealed["bootSession"] == boot_identity()
                and sealed["lease"]["mode"] == value.get("mode") == "watchdog-exercise-no-denial"
                and value.get("status") == "OWNED_RULES_EMPTY_ROLLBACK_VERIFIED" and value.get("reason") == reason
                and value.get("activated") is False and all(row.get("active") is False and row.get("counters") == "" for row in value.get("history", []))
                and type(armed.get("watchdog", {}).get("pid")) is int and armed["watchdog"]["pid"] > 1,
                "Exercise is not the actual unmodified no-denial watchdog lifecycle")
        require(value.get("attempts") and all(row.get("exit") == 0 and row.get("rulesBeforeSHA256") == digest(b"") for row in value["attempts"])
                and unloaded.get("status") == "OWNED_DAEMON_UNLOADED_PLIST_REMOVED_RULES_EMPTY"
                and unloaded.get("originalConfigurationMatches") is True
                and pf("-a", anchor_name(identifier), "-sr") == "", "Exercise cleanup/original configuration is unverified")


def heartbeat_actor(lease):
    pid, ancestry = os.getpid(), []
    for _ in range(12):
        row = process(pid)
        require(row is not None, "Fresh heartbeat process ancestry is missing")
        require(pid != lease["controllerPID"], "A local controller timer is not an independent Oracle SSH heartbeat")
        ancestry.append(row)
        comm = process(pid, command=False)
        if comm and comm["command"] in SSHD_IMAGES:
            rows = [s for s in connections() if s["pid"] == pid and "->" in s.get("n", "")]
            for socket in rows:
                control = admitted_socket(socket, lease["controls"])
                if control and control["direction"] == "incoming" and control["peerAddress"] == lease["oracleHeartbeatPeer"]:
                    start = dt.datetime.strptime(row["startUTC"], "%a %b %d %H:%M:%S %Y").replace(tzinfo=dt.timezone.utc).timestamp()
                    require(0 <= time.time() - start <= 10, "Heartbeat SSH transport is not a fresh independently opened connection")
                    return {"ancestry": ancestry, "authenticatedSSHSocket": socket}
        pid = row["parentPID"]
        if pid <= 1:
            break
    raise ValueError("Heartbeat did not arrive through a fresh actual pinned Oracle SSH process")


def record_heartbeat(identifier):
    directory, sealed = load_sealed(identifier)
    actor = heartbeat_actor(sealed["lease"])
    if (directory / "cleanup.json").exists():
        print(json.dumps({"windowID": identifier, "status": "WINDOW_ALREADY_CLEANED",
                          "cleanupSHA256": witness(directory / "cleanup.json")["sha256"]}))
        return
    if (directory / "heartbeat.json").exists():
        previous = strict_json(read_bytes(directory / "heartbeat.json"))
        require(actor["authenticatedSSHSocket"]["pid"] != previous["actor"]["authenticatedSSHSocket"]["pid"],
                "Heartbeat reused an old SSH transport instead of a fresh authenticated request")
    value = {"schema": VERSION, "windowID": identifier, "nonce": uuid.uuid4().hex,
             "bootSession": boot_identity(), "observedUnix": time.time(), "observedMonotonic": time.monotonic(), "actor": actor}
    require(value["bootSession"] == sealed["bootSession"] and value["observedMonotonic"] < sealed["hardDeadlineMonotonic"], "Heartbeat cannot renew an expired/other-boot window")
    private_write(directory / "heartbeat.json", value, replace=True)
    print(json.dumps({"windowID": identifier, "nonce": value["nonce"], "observedUnix": value["observedUnix"]}))


def rollback(directory, sealed, reason, active, history):
    """Always confined to this newly reserved UUID anchor; never global state."""
    name = anchor_name(sealed["windowID"])
    attempts = []
    for _ in range(3):
        try:
            before = pf("-a", name, "-sr")
            if sealed["lease"]["mode"] == "watchdog-exercise-no-denial":
                require(before == "", "No-denial exercise encountered unexpected owned rules")
            else:
                pf("-a", name, "-F", "rules")
            require(pf("-a", name, "-sr") == "", "Owned rules remain after rollback")
            attempts.append({"exit": 0, "observedUnix": time.time(), "rulesBeforeSHA256": digest(before.encode())})
            result = {"schema": VERSION, "status": "OWNED_RULES_EMPTY_ROLLBACK_VERIFIED", "windowID": sealed["windowID"],
                      "reason": reason, "mode": sealed["lease"]["mode"], "activated": active,
                      "cleanupUnix": time.time(), "cleanupMonotonic": time.monotonic(), "attempts": attempts,
                      "history": history, "originalBaselineSHA256": digest(json.dumps(sealed["baseline"], sort_keys=True).encode()),
                      "onlyOwnedAnchor": name, "postNetworkSuccessStillRequired": True}
            private_write(directory / "cleanup.json", result, replace=True)
            return result
        except Exception as error:
            attempts.append({"exit": 1, "observedUnix": time.time(), "error": type(error).__name__ + ": " + str(error)})
    with contextlib.suppress(Exception):
        private_write(directory / "rollback-failure.json", {"attempts": attempts, "reason": reason}, replace=True)
    raise RuntimeError("Owned PF cleanup unverified; launchd must restart this watchdog")


def emergency_rollback(identifier, error):
    # A sealed receipt read failure must not leave an already loaded rule. The
    # entry point is bound to this exact root-owned UUID directory and script;
    # it still has no permission to address any different/main anchor.
    directory = sealed_dir(identifier)
    require(os.geteuid() == 0 and Path(__file__).resolve() == directory / "watchdog.py", "Emergency cleanup has no owned directory")
    root_file(__file__)
    before = pf("-a", anchor_name(identifier), "-sr")
    if before:
        pf("-a", anchor_name(identifier), "-F", "rules")
    require(pf("-a", anchor_name(identifier), "-sr") == "", "Emergency owned rollback is unverified")
    with contextlib.suppress(Exception):
        private_write(directory / "emergency-cleanup.json", {"windowID": identifier,
                      "status": "OWNED_RULES_EMPTY_NO_ACCEPTANCE", "error": str(error),
                      "observedUnix": time.time(), "rulesBeforeSHA256": digest(before.encode())}, replace=True)


def watchdog(identifier):
    try:
        directory, sealed = load_sealed(identifier)
    except BaseException as error:
        emergency_rollback(identifier, error)
        raise
    history, active, last = [], False, time.monotonic()
    try:
        if (directory / "cleanup.json").exists():
            require(pf("-a", anchor_name(identifier), "-sr") == "", "Previously cleaned owned rules reappeared")
            return
        # Bootstrap grants only a short initial heartbeat arrival interval. It
        # cannot activate without an actual fresh authenticated SSH heartbeat.
        private_write(directory / "armed.json", {"windowID": identifier, "watchdog": process(os.getpid()),
                                                  "armedUnix": time.time(), "armedMonotonic": last}, replace=True)
        while True:
            now_mono, now_unix = time.monotonic(), time.time()
            heartbeat = strict_json(read_bytes(directory / "heartbeat.json")) if (directory / "heartbeat.json").exists() else None
            original_ok, own_ok = True, True
            if active:
                original_ok = pf_snapshot(anchor_name(identifier), sealed["lease"]["controls"], sealed["lease"].get("translatedVNC", [])) == sealed["baseline"]["pf"] \
                    and network_snapshot(sealed["lease"]["controls"], sealed["lease"].get("translatedVNC", [])) == sealed["baseline"]["network"]
                own_ok = pf("-a", anchor_name(identifier), "-sr") == sealed["normalizedRules"]
                require(own_ok, "Owned deny rule disappeared before pending-socket admission")
                admit_connections(connections(), sealed["lease"]["controls"], sealed["lease"].get("translatedVNC", []), allow_denied_pending=True)
            reason = watchdog_reason(now_mono=now_mono, now_unix=now_unix, last_tick=last, sealed=sealed,
                heartbeat=heartbeat, controller_alive=process_is_same(sealed["controller"]), actual_boot=boot_identity(),
                original_unchanged=original_ok, own_rules_match=own_ok, activated=active,
                finish=(directory / "finish-request.json").exists())
            if reason == "authenticated-oracle-heartbeat-missing" and not active \
                    and now_mono - sealed["preparedMonotonic"] < 20:
                reason = None
            if reason:
                rollback(directory, sealed, reason, active, history)
                return
            if not active and (directory / "activate-request.json").exists():
                require(heartbeat is not None and now_mono - heartbeat["observedMonotonic"] <= 10, "No fresh independent Oracle heartbeat")
                require(sealed["lease"]["mode"] == "network-denial", "No-denial exercise cannot activate PF")
                require(pf_snapshot(anchor_name(identifier), sealed["lease"]["controls"], sealed["lease"].get("translatedVNC", [])) == sealed["baseline"]["pf"]
                        and network_snapshot(sealed["lease"]["controls"], sealed["lease"].get("translatedVNC", [])) == sealed["baseline"]["network"], "Admission drift before activation")
                admit_connections(connections(), sealed["lease"]["controls"], sealed["lease"].get("translatedVNC", []))
                require(pf("-a", anchor_name(identifier), "-sr") == "", "Owned anchor is no longer empty")
                # Mark uncertainty before the mutating command so any exception
                # afterwards still rolls back, including an ENOSPC receipt error.
                active = True
                pf("-a", anchor_name(identifier), "-f", str(directory / "rules.pf"))
                require(pf("-a", anchor_name(identifier), "-sr") == sealed["normalizedRules"], "Applied PF rules differ from the sealed parsed rules")
                event = {"event": "activated", "observedUnix": time.time(), "observedMonotonic": time.monotonic()}
                history.append(event)
                private_write(directory / "activated.json", event)
            if active:
                counts = pf("-a", anchor_name(identifier), "-s", "labels")
            else:
                counts = ""
            status = {"windowID": identifier, "watchdog": process(os.getpid()), "observedUnix": time.time(),
                      "observedMonotonic": time.monotonic(), "active": active, "mode": sealed["lease"]["mode"],
                      "originalUnchanged": original_ok, "ownRulesMatch": own_ok, "counters": counts,
                      "heartbeatNonce": heartbeat.get("nonce") if heartbeat else None,
                      "heartbeatMonotonic": heartbeat.get("observedMonotonic") if heartbeat else None}
            private_write(directory / "status.json", status, replace=True)
            history.append({key: status[key] for key in ("observedUnix", "observedMonotonic", "active", "counters", "heartbeatNonce")})
            require(len(history) <= 600, "Watchdog evidence bound exceeded")
            last = now_mono
            time.sleep(1)
    except BaseException as error:
        rollback(directory, sealed, type(error).__name__ + ": " + str(error), active, history)
        raise


def deploy(lease_path, expected_source):
    require(os.geteuid() == 0 and sys.platform == "darwin", "Deploy requires authorized macOS root")
    raw = read_bytes(Path(__file__).resolve(), 1024 * 1024)
    require(digest(raw) == expected_source, "Deployment source changed")
    lease = admit_lease(strict_json(read_bytes(lease_path)), expected_source)
    if lease["mode"] == "network-denial":
        verify_actual_watchdog_exercises(lease, expected_source)
    controller = process(lease["controllerPID"])
    require(controller is not None, "Controller vanished before deployment")
    cursor = os.getpid()
    for _ in range(10):
        row = process(cursor)
        require(row is not None, "Deployment process ancestry missing")
        if cursor == controller["pid"]:
            break
        cursor = row["parentPID"]
    else:
        raise ValueError("Controller is not the actual deploying ancestor")
    require(cursor == controller["pid"], "Wrong deploying controller")
    identifier = lease["windowID"]
    directory, anchor = sealed_dir(identifier), anchor_name(identifier)
    require(not directory.exists() and not (DAEMONS / (label_name(identifier) + ".plist")).exists(), "Never reuse an owned window/daemon")
    root_file(PYTHON)
    original_pf = pf_snapshot(anchor, lease["controls"], lease.get("translatedVNC", []))
    require(anchor not in parse_anchor_children(pf("-a", "com.apple", "-s", "Anchors"), "com.apple"), "Owned anchor already exists")
    require(pf("-a", anchor, "-sr") == "", "Owned anchor already has rules")
    baseline = {"pf": original_pf, "network": network_snapshot(lease["controls"], lease.get("translatedVNC", []))}
    admitted = admit_connections(connections(), lease["controls"], lease.get("translatedVNC", []))
    if not BASE.exists():
        BASE.mkdir(mode=0o700)
    require(BASE.resolve() == BASE and BASE.stat().st_uid == 0 and not BASE.stat().st_mode & 0o077, "Private root directory is not exclusively owned")
    directory.mkdir(mode=0o700)
    created = True
    try:
        code = directory / "watchdog.py"
        descriptor = os.open(code, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o500)
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(raw); handle.flush(); os.fsync(handle.fileno())
        rules = make_rules(identifier, lease["controls"])
        (directory / "rules.pf").write_text(rules)
        os.chmod(directory / "rules.pf", 0o400)
        normalized = pf("-n", "-v", "-a", anchor, "-f", str(directory / "rules.pf"))
        require(normalized and pf_snapshot(anchor, lease["controls"], lease.get("translatedVNC", [])) == original_pf and pf("-a", anchor, "-sr") == "", "Parse-only preparation changed original PF state")
        prepared_unix, prepared_mono = time.time(), time.monotonic()
        sealed = {"schema": VERSION, "windowID": identifier, "sourceSHA256": expected_source,
                  "pythonSHA256": digest(read_bytes(PYTHON, 64 * 1024 * 1024)), "bootSession": boot_identity(),
                  "lease": lease, "controller": controller, "baseline": baseline, "admittedSockets": admitted,
                  "preparedUnix": prepared_unix, "preparedMonotonic": prepared_mono,
                  "hardDeadlineMonotonic": prepared_mono + lease["hardDeadlineUnix"] - prepared_unix,
                  "normalizedRules": normalized}
        private_write(directory / "sealed.json", sealed)
        os.chmod(directory / "sealed.json", 0o400)
        plist = {"Label": label_name(identifier), "ProgramArguments": [PYTHON, "-I", "-B", str(code), "watchdog", identifier],
                 "RunAtLoad": True, "KeepAlive": {"SuccessfulExit": False}, "ThrottleInterval": 2,
                 "ProcessType": "Background", "WorkingDirectory": str(directory), "Umask": 0o077,
                 "StandardOutPath": str(directory / "watchdog.stdout.log"), "StandardErrorPath": str(directory / "watchdog.stderr.log")}
        plist_path = DAEMONS / (label_name(identifier) + ".plist")
        with plist_path.open("xb") as handle:
            handle.write(plistlib.dumps(plist)); handle.flush(); os.fsync(handle.fileno())
        os.chmod(plist_path, 0o600)
        _, _, error = run(["/bin/launchctl", "bootstrap", "system", str(plist_path)])
        require(not error, "Watchdog bootstrap diagnostic")
        print(json.dumps({"windowID": identifier, "privateDirectory": str(directory), "sealedSHA256": witness(directory / "sealed.json")["sha256"]}))
    except BaseException:
        # No network rule is loaded during deployment. Preserve all inputs and
        # verify empty owned anchor; never erase another daemon or root rules.
        require(pf("-a", anchor, "-sr") == "", "Preparation unexpectedly encountered owned rules")
        if (DAEMONS / (label_name(identifier) + ".plist")).exists():
            run(["/bin/launchctl", "bootout", "system/" + label_name(identifier)], allowed=(0, 3, 113))
        raise


def privileged_action(action, identifier):
    directory, sealed = load_sealed(identifier)
    if action == "heartbeat":
        record_heartbeat(identifier); return
    if action == "status":
        values = {}
        for name in ("armed", "status", "activated", "cleanup", "rollback-failure"):
            path = directory / (name + ".json")
            if path.exists():
                values[name] = strict_json(read_bytes(path, MAX_PRIVATE_BYTES))
        print(json.dumps(values)); return
    if action == "activate":
        require(sealed["lease"]["mode"] == "network-denial", "No-denial exercise is ineligible for activation")
        require(process_is_same(sealed["controller"]), "Controller identity changed")
        require(not (directory / "cleanup.json").exists(), "An already cleaned window cannot reactivate")
        private_write(directory / "activate-request.json", {"observedUnix": time.time(), "requestID": uuid.uuid4().hex})
    elif action == "finish":
        private_write(directory / "finish-request.json", {"observedUnix": time.time()}, replace=True)
    elif action == "unload":
        require((directory / "cleanup.json").exists() and pf("-a", anchor_name(identifier), "-sr") == "", "Cannot unload an unverified rollback watchdog")
        _, _, error = run(["/bin/launchctl", "bootout", "system/" + label_name(identifier)], allowed=(0, 3, 113))
        require(not error or "No such process" in error or "Could not find service" in error, "Owned daemon unload failed")
        code, stdout, stderr = run(["/bin/launchctl", "print", "system/" + label_name(identifier)], allowed=(0, 3, 113))
        require(code != 0 and ("Could not find service" in stderr or "No such process" in stderr), "Owned daemon remains loaded or absence is ambiguous")
        require(pf("-a", anchor_name(identifier), "-sr") == "", "Owned rules reappeared after daemon unload")
        original_error = None
        try:
            original_matches = pf_snapshot(anchor_name(identifier), sealed["lease"]["controls"], sealed["lease"].get("translatedVNC", [])) == sealed["baseline"]["pf"] \
                and network_snapshot(sealed["lease"]["controls"], sealed["lease"].get("translatedVNC", [])) == sealed["baseline"]["network"]
        except Exception as error:
            original_matches, original_error = False, type(error).__name__ + ": " + str(error)
        path = DAEMONS / (label_name(identifier) + ".plist")
        payload = plistlib.loads(read_bytes(root_file(path)))
        require(payload["Label"] == label_name(identifier) and payload["ProgramArguments"] == [PYTHON, "-I", "-B", str(directory / "watchdog.py"), "watchdog", identifier], "Refuse another daemon's plist")
        path.unlink()
        unloaded = {"windowID": identifier, "status": "OWNED_DAEMON_UNLOADED_PLIST_REMOVED_RULES_EMPTY",
                    "originalConfigurationMatches": original_matches, "originalConfigurationError": original_error,
                    "observedUnix": time.time()}
        private_write(directory / "unloaded.json", unloaded, replace=True)
        print(json.dumps(unloaded)); return
    else:
        raise ValueError("Unknown privileged action")
    print(json.dumps({"windowID": identifier, "requested": action}))


def probe_valid(value, *, phase, kind, udid, nonce, endpoint):
    require(value.get("schema") == "otzaria.foundation-transport-probe/1" and value.get("phase") == phase
            and value.get("nonce") == nonce and value.get("endpoint") == endpoint
            and value.get("requestedURL") == ENDPOINTS[endpoint] + "?otzariaOfflineNonce=" + nonce, "Probe request identity differs")
    require(value.get("environment") == kind and (value.get("simulatorUDID") == udid if kind == "simulator" else value.get("simulatorUDID") is None), "Probe did not run in the admitted platform")
    require(type(value.get("processID")) is int and value["processID"] > 1 and value.get("deadlineExpired") is False
            and value.get("taskCompleted") is True,
            "Missing real probe PID or bounded request did not finish")
    require(all(finite(value.get(key), 1) for key in ("startedUnix", "finishedUnix", "startedUptime", "finishedUptime"))
            and value["startedUnix"] < value["finishedUnix"] and value["startedUptime"] < value["finishedUptime"], "Invalid actual probe interval")
    require(value.get("ephemeral") is True and value.get("URLCacheDisabled") is True
            and value.get("waitsForConnectivity") is False and value.get("redirects") == [], "Probe policy changed or redirect occurred")
    if phase == "during":
        require(value.get("HTTPStatus") is None and value.get("responseBytes") == 0
                and value.get("errorDomain") == "NSURLErrorDomain" and value.get("errorCode") in TRANSPORT_ERRORS,
                "Only a real transport error without any HTTP response qualifies")
    else:
        require(value.get("HTTPStatus") == 200 and value.get("responseBytes", 0) > 0
                and value.get("errorDomain") is None and value.get("errorCode") is None,
                "A genuine successful online response is required before and after denial")
        transactions = value.get("transactions")
        require(isinstance(transactions, list) and transactions
                and all(v.get("resourceFetchType") == "networkLoad" and v.get("proxyConnection") is False
                        and v.get("reusedConnection") is False for v in transactions),
                "Online request did not actually use the network")
    return value


def blocking_packets(raw, identifier):
    label = "otzaria-denial-" + window_id(identifier)
    rows = [line.split() for line in raw.splitlines() if line.split() and line.split()[0] == label]
    require(len(rows) == 1 and len(rows[0]) == 9 and all(v.isdigit() for v in rows[0][1:]), "Unqualified actual PF label counter format")
    # pfctl(8): label evaluations packets bytes in-packets in-bytes
    # out-packets out-bytes states. We use packets, not evaluations.
    return int(rows[0][2])


class OfflineWindow:
    """Root caller joins this transport receipt to its original native gate.

    private_lease is a coordinated file, NOT an acceptance override. Each probe
    manifest supplies binary/source/compile-receipt FileWitnesses already bound
    to the actual SDK compile; this module rehashes the binary before every run.
    """
    def __init__(self, *, private_lease, output_dir, simulator_probe, host_probe, image_path_resolver):
        require(sys.platform == "darwin" and os.geteuid() != 0, "The original UI coordinator must remain the Mac user")
        self.source_path = Path(__file__).resolve()
        self.source_sha = digest(read_bytes(self.source_path, 1024 * 1024))
        self.lease_path = canonical(private_lease)
        require(self.lease_path.stat().st_uid == os.getuid() and not self.lease_path.stat().st_mode & 0o077,
                "Private coordinator lease must be owned and readable only by the original Mac user")
        self.lease = admit_lease(strict_json(read_bytes(self.lease_path)), self.source_sha)
        require(self.lease["controllerPID"] == os.getpid(), "Lease belongs to another controller process")
        self.identifier, self.udid = self.lease["windowID"], self.lease["simulatorUDID"]
        self.output = Path(output_dir)
        require(self.output.is_absolute() and not self.output.exists(), "Use a fresh private output directory")
        self.output.mkdir(mode=0o700)
        require(canonical(self.output, True) == self.output, "Output path is not canonical")
        self.probes = {"simulator": simulator_probe, "host": host_probe}
        self.resolve_image = image_path_resolver
        self.samples, self.probe_records, self.app_samples, self.cases = [], [], [], []
        self.stop = threading.Event(); self.failure = None; self.monitor = None; self.probe_thread = None
        self.deployed = False; self.finished = False; self.activation = None
        self._lock = threading.Lock()
        helper = self.source_path.with_name("runtime27_interruption.py")
        repository = self.source_path.parents[2]
        for path in (self.source_path, self.source_path.with_name("OfflineTransportProbe.swift"), helper):
            _, actual, error = run(["git", "-C", str(repository), "show", "HEAD:" + path.relative_to(repository).as_posix()], timeout=10)
            require(not error and read_bytes(path, 1024 * 1024) == actual.encode(), "Offline execution source differs from committed checkout")
        spec = importlib.util.spec_from_file_location("owned_offline_interruption", helper)
        self.interruption = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.interruption)
        private_write(self.output / "LEASE.json", self.lease)

    def _private(self, action):
        path = sealed_dir(self.identifier) / "watchdog.py"
        _, stdout, stderr = run(["/usr/bin/sudo", "-n", PYTHON, "-I", "-B", str(path), action, self.identifier], timeout=12, maximum=MAX_PRIVATE_BYTES)
        require(not stderr, "Private controller diagnostic")
        return strict_json(stdout)

    def _fail(self, error):
        with self._lock:
            if self.failure is None:
                self.failure = type(error).__name__ + ": " + str(error)
        with contextlib.suppress(Exception):
            self._private("finish")

    def _assert_healthy(self):
        require(self.failure is None, self.failure or "Window failed")
        value = self._private("status")
        require("cleanup" not in value and "rollback-failure" not in value, "Watchdog ended before native work finished")
        require(value.get("status", {}).get("active") is True, "No active owned denial")
        require(0 <= time.monotonic() - value["status"]["observedMonotonic"] <= MAX_WATCHDOG_GAP, "Watchdog observation is stale")
        return value

    def prepare(self):
        try:
            _, stdout, stderr = run(["/usr/bin/sudo", "-n", PYTHON, "-I", "-B", str(self.source_path), "deploy",
                                     str(self.lease_path), self.source_sha], timeout=25)
            require(not stderr, "Watchdog preparation diagnostic")
            self.deployed = True
            private_write(self.output / "DEPLOYMENT.json", strict_json(stdout))
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                state = self._private("status")
                require("cleanup" not in state, "Watchdog failed before arming")
                if "armed" in state:
                    private_write(self.output / "ARMED.json", state)
                    return {"windowID": self.identifier,
                            "freshSSHCommand": ["/usr/bin/sudo", "-n", PYTHON, "-I", "-B", str(sealed_dir(self.identifier) / "watchdog.py"), "heartbeat", self.identifier],
                            "heartbeatMaximumIntervalSeconds": 10, "hardDeadlineUnix": self.lease["hardDeadlineUnix"]}
                time.sleep(.2)
            raise ValueError("Independent watchdog did not arm")
        except BaseException:
            # Deployment might have succeeded before stdout/receipt failure.
            self.deployed = True
            with contextlib.suppress(Exception):
                self.abort()
            raise

    def _probe(self, phase, kind, endpoint):
        manifest = self.probes[kind]
        require(isinstance(manifest, dict) and set(manifest) == {"binary", "source", "compileReceipt"}, "Probe requires actual source/compile/binary witnesses")
        for key in manifest:
            require(witness(manifest[key]["path"]) == manifest[key], "Qualified probe file changed")
        compiled = strict_json(read_bytes(manifest["compileReceipt"]["path"]))
        require(compiled.get("schema") == "otzaria.independent-foundation-probe-build/1"
                and compiled.get("status") == "COMPILED_ONLY_NO_NETWORK_OR_NATIVE_UI"
                and compiled.get("source") == manifest["source"], "Probe compile receipt does not bind its actual source")
        require(manifest["source"]["sha256"] == digest(read_bytes(self.source_path.with_name("OfflineTransportProbe.swift"))),
                "Probe source differs from the current controller's committed companion")
        builds = [row for row in compiled.get("builds", []) if row.get("kind") == kind]
        require(len(builds) == 1 and builds[0].get("exit") == 0 and builds[0].get("codeSignVerify", {}).get("exit") == 0
                and builds[0].get("binary") == manifest["binary"] and builds[0].get("sdkVersion") == "27.0"
                and builds[0].get("actualPlatform") == ("IOSSIMULATOR" if kind == "simulator" else "MACOS")
                and builds[0].get("command", [])[:4] == ["xcrun", "--sdk", "iphonesimulator" if kind == "simulator" else "macosx", "swiftc"],
                "Probe binary/SDK/platform is not the actual qualified compilation")
        nonce = uuid.uuid4().hex
        command = [manifest["binary"]["path"], "--window", self.identifier, "--phase", phase,
                   "--nonce", nonce, "--endpoint", endpoint]
        if kind == "simulator":
            command = ["/usr/bin/xcrun", "simctl", "spawn", self.udid, *command]
        before = time.time()
        child = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE, start_new_session=True)
        cleanup = None
        try:
            stdout_raw, stderr_raw = child.communicate(timeout=16)
            require(child.returncode == 0 and len(stdout_raw) + len(stderr_raw) <= 256 * 1024,
                    "Actual Foundation probe process failed or output exceeded bound")
            stdout, stderr = stdout_raw.decode("utf-8"), stderr_raw.decode("utf-8")
        finally:
            # Original owned-process helpers first. A Simulator runtime child
            # can be outside simctl's group; bind any survivor to the exact
            # random nonce + full binary command before signaling only that PID.
            cleanup = {"group": self.interruption.stop_owned_process_group(child, grace_seconds=1, kill_wait_seconds=.5),
                       "subprocess": self.interruption.stop_owned_subprocess(child), "runtimeSurvivors": []}
            expected = command[-9:]
            _, process_text, process_error = run(["/bin/ps", "-ww", "-axo", "pid=,ppid=,lstart=,command="])
            require(not process_error and child.poll() is not None, "Created probe wrapper cleanup is unverified")
            for line in process_text.splitlines():
                if not line.strip():
                    continue
                match = PS_ROW.fullmatch(line)
                require(match is not None, "Probe cleanup process inventory is unparseable")
                if nonce not in match[4]:
                    continue
                require(shlex.split(match[4]) == expected, "Ambiguous process carries this exact owned probe nonce")
                identity = {"pid": int(match[1]), "parentPID": int(match[2]), "startUTC": match[3], "command": match[4]}
                require(identity["pid"] != os.getpid() and process(identity["pid"]) == identity, "Owned runtime probe identity changed")
                os.kill(identity["pid"], signal.SIGTERM)
                until = time.monotonic() + 1
                while time.monotonic() < until and process(identity["pid"]) == identity:
                    time.sleep(.05)
                if process(identity["pid"]) == identity:
                    os.kill(identity["pid"], signal.SIGKILL)
                until = time.monotonic() + 1
                while time.monotonic() < until and process(identity["pid"]) == identity:
                    time.sleep(.05)
                require(process(identity["pid"]) is None, "Owned runtime probe cleanup is unverified")
                cleanup["runtimeSurvivors"].append(identity)
            private_write(self.output / ("probe-cleanup-" + nonce + ".json"), cleanup)
        require(not stderr, "Foundation probe diagnostic")
        value = probe_valid(strict_json(stdout), phase=phase, kind=kind, udid=self.udid, nonce=nonce, endpoint=endpoint)
        require(value["windowID"] == self.identifier and before - 1 <= value["startedUnix"] < value["finishedUnix"] <= time.time() + 1,
                "Probe output is not bound to this actual command interval")
        row = {"probe": value, "binary": manifest["binary"], "source": manifest["source"], "compileReceipt": manifest["compileReceipt"],
               "commandStartedUnix": before, "commandFinishedUnix": time.time(), "ownedProcessCleanup": cleanup}
        with self._lock:
            index = len(self.probe_records)
            self.probe_records.append(row)
        private_write(self.output / ("probe-" + str(index).zfill(4) + ".json"), row)
        return row

    def probe_round(self, phase):
        before = self._assert_healthy() if phase == "during" else None
        rows = [self._probe(phase, kind, endpoint) for kind in ("simulator", "host") for endpoint in ENDPOINTS]
        if phase == "during":
            after = self._assert_healthy()
            require(blocking_packets(after["status"]["counters"], self.identifier)
                    > blocking_packets(before["status"]["counters"], self.identifier), "Negative requests lack actual increasing owned block counters")
        return rows

    def _activate(self):
        require(self.deployed and self.lease["mode"] == "network-denial", "No denial activation is eligible")
        self.probe_round("before")
        self._private("activate")
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            value = self._private("status")
            require("cleanup" not in value, "Watchdog rejected activation")
            if value.get("status", {}).get("active") is True:
                self.activation = value["activated"]
                private_write(self.output / "ACTIVATION.json", value)
                self.monitor = threading.Thread(target=self._monitor, name="owned-offline-observer", daemon=True)
                self.monitor.start()
                self.probe_round("during")
                self.probe_thread = threading.Thread(target=self._periodic_probe, name="owned-offline-probes", daemon=True)
                self.probe_thread.start()
                return value
            time.sleep(.2)
        raise ValueError("Owned denial was not independently observed")

    def activate(self):
        try:
            return self._activate()
        except BaseException:
            self.abort()
            raise

    def _monitor(self):
        try:
            last = time.monotonic()
            while not self.stop.is_set():
                value = self._assert_healthy()
                now = time.monotonic()
                require(now - last <= MAX_WATCHDOG_GAP, "Controller active observation gap")
                path = str(canonical(self.resolve_image()))
                _, raw, error = run(["/bin/ps", "-ww", "-axo", "pid=,ppid=,lstart=,command="])
                require(not error, "App process inventory diagnostic")
                apps = []
                for line in raw.splitlines():
                    if not line.strip():
                        continue
                    match = PS_ROW.fullmatch(line)
                    require(match is not None, "Unparseable process inventory")
                    command = match[4]
                    if command == path or command.startswith(path + " "):
                        apps.append({"processID": int(match[1]), "parentPID": int(match[2]), "startUTC": match[3],
                                     "processImagePath": path, "arguments": shlex.split(command[len(path):].strip())})
                require(len(apps) <= 1, "Ambiguous original app process")
                # Zero or a new PID is possible at an original cold-relaunch
                # boundary. The root must bind the actual emitted native pages
                # to one observed fresh PID/image/namespace inside this interval.
                row = {"observedUnix": time.time(), "observedMonotonic": now, "watchdog": value["status"], "applications": apps}
                with self._lock:
                    self.samples.append(row)
                    require(len(self.samples) <= 1000, "Observation bound exceeded")
                last = now
                self.stop.wait(1)
        except BaseException as error:
            self._fail(error)

    def _periodic_probe(self):
        try:
            while not self.stop.wait(8):
                self.probe_round("during")
        except BaseException as error:
            self._fail(error)

    def observe_native_case(self, callback):
        require(not self.cases and self.activation is not None, "Exactly one original selector per window")
        self._assert_healthy()
        boundary = {"caseID": self.lease["selectedCaseID"], "startedUnix": time.time(), "startedMonotonic": time.monotonic()}
        private_write(self.output / "NATIVE_START.json", boundary)
        try:
            result = callback()
            boundary.update(finishedUnix=time.time(), finishedMonotonic=time.monotonic(), callbackReturned=True)
            self._assert_healthy()
            self.cases.append(boundary)
            private_write(self.output / "NATIVE_FINISH.json", boundary)
            return result
        except BaseException as error:
            self._fail(error)
            raise

    def _finish(self):
        require(not self.finished and len(self.cases) == 1, "No complete original case interval")
        # Stop only our periodic workers, keeping the independent watchdog
        # active while the final actual negative requests are observed.
        self.stop.set()
        for worker in (self.probe_thread, self.monitor):
            if worker:
                worker.join(55)
                require(not worker.is_alive(), "Owned observer did not stop")
        self._assert_healthy()
        self.probe_round("during")
        self._private("finish")
        cleanup = self._wait_cleanup()
        require(cleanup["reason"] == "normal-finish-requested" and cleanup["activated"] is True, "The active interval ended early")
        unloaded = self._private("unload")
        self.deployed = False
        require(unloaded.get("originalConfigurationMatches") is True, "Original host configuration changed across the window")
        self.probe_round("after")
        value = {"schema": VERSION, "status": "TRANSPORT_WINDOW_OBSERVED_ORIGINAL_NATIVE_JOIN_STILL_REQUIRED",
                 "windowID": self.identifier, "simulatorUDID": self.udid, "selectedCaseID": self.lease["selectedCaseID"],
                 "sourceSHA256": self.source_sha, "activation": self.activation, "cleanup": cleanup, "unloaded": unloaded,
                 "nativeIntervals": self.cases, "samples": self.samples, "probes": self.probe_records,
                 "physicalAirplaneMode": False, "originalNativeSQLPackageSourceBuildZeroSkipJoinRequired": True,
                 "privateControlData": True, "hardLimitSeconds": MAX_DENIAL_SECONDS}
        result = private_write(self.output / "RESULT.private.json", value)
        self.finished = True
        return {"proof": value, "witness": result}

    def finish(self):
        try:
            return self._finish()
        except BaseException:
            self.abort()
            raise

    def _wait_cleanup(self):
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            value = self._private("status")
            if "cleanup" in value:
                require(value["cleanup"]["status"] == "OWNED_RULES_EMPTY_ROLLBACK_VERIFIED", "Rollback receipt is unqualified")
                private_write(self.output / "CLEANUP.private.json", value, replace=True)
                return value["cleanup"]
            time.sleep(.25)
        raise ValueError("Independent rollback was not verified; preserve watchdog and escalate exact owned anchor")

    def abort(self):
        self.stop.set()
        if self.deployed:
            # Request rollback FIRST; do not wait on probes before restoring the
            # network. A failed CLI leaves the independent watchdog/deadline.
            self._private("finish")
            self._wait_cleanup()
            self._private("unload")
            self.deployed = False
        for worker in (self.probe_thread, self.monitor):
            if worker:
                worker.join(55)
                require(not worker.is_alive(), "Owned observer remains active after abort")
        if not self.finished:
            private_write(self.output / "ABORT.private.json", {"schema": VERSION, "windowID": self.identifier,
                          "status": "FAILED_OR_INCOMPLETE", "error": self.failure,
                          "noOfflineAcceptance": True, "ownedWatchdogUnloaded": not self.deployed}, replace=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("deploy", "watchdog", "heartbeat", "status", "activate", "finish", "unload"))
    parser.add_argument("value")
    parser.add_argument("source_sha", nargs="?")
    args = parser.parse_args()
    if args.action == "deploy":
        deploy(args.value, args.source_sha)
    elif args.action == "watchdog":
        watchdog(window_id(args.value))
    else:
        privileged_action(args.action, window_id(args.value))


if __name__ == "__main__":
    main()
