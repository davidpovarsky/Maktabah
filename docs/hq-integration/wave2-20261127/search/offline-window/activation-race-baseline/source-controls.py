#!/usr/bin/env python3
"""Synthetic source controls ONLY: no Mac, network, PF or launchd operation."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "study-ui-offline-window.py"
if not SOURCE.exists():
    SOURCE = HERE.parents[4] / "Scripts/CI/study-ui-offline-window.py"
spec = importlib.util.spec_from_file_location("offline_candidate", SOURCE)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
IDENTIFIER = "0123456789abcdef0123456789abcdef"
INCOMING = {"direction": "incoming", "transport": "ssh-tcp", "localAddress": "192.0.2.20",
            "localPort": 22, "peerAddress": "192.0.2.10", "peerPort": 44000, "interface": "en0"}
OUTGOING = {"direction": "outgoing", "transport": "ssh-tcp", "localAddress": "192.0.2.20",
            "localPort": 44002, "peerAddress": "198.51.100.9", "peerPort": 22, "interface": "en0"}


def lease():
    return {"schema": m.VERSION, "status": "COORDINATED_EXCLUSIVE_OFFLINE_WINDOW", "windowID": IDENTIFIER,
            "controllerSourceSHA256": "a" * 64, "mode": "network-denial", "selectedCaseID": m.CASE_IDS["zayit"],
            "coordinatingOwners": ["root", "wave3"], "allOtherNetworkAndNativeWorkPaused": True,
            "notBeforeUnix": 1000, "hardDeadlineUnix": 1100, "controls": [INCOMING, OUTGOING],
            "oracleHeartbeatPeer": "192.0.2.10", "controllerPID": 100,
            "simulatorUDID": "11111111-2222-3333-4444-555555555555"}


def translated():
    raw = "ALL tcp 127.0.0.1:5900 <- 192.0.2.20:59010 <- 198.51.100.7:34300 ESTABLISHED:ESTABLISHED"
    return {"stateLine": raw, "stateLineSHA256": m.digest(raw.encode()), "state": m.vnc_state(raw),
            "coordinatorConfirmedControlOnly": True, "interface": "en0", "filterRulesSHA256": "b" * 64,
            "translationRulesSHA256": "c" * 64,
            "owner": {"pid": 42, "parentPID": 1, "startUTC": "Fri Nov 27 05:00:00 2026", "command": m.VNC_IMAGE},
            "ownerImageStat": [1, 2, 1000, 10, 10],
            "connection": {"pid": 42, "name": "screensharingd", "fd": "5", "P": "TCP", "ST": "ESTABLISHED",
                           "n": "127.0.0.1:5900->198.51.100.7:34300"}}


def probe(phase="before"):
    value = {"schema": "otzaria.foundation-transport-probe/1", "phase": phase, "nonce": IDENTIFIER,
             "endpoint": "github-v40", "requestedURL": m.ENDPOINTS["github-v40"] + "?otzariaOfflineNonce=" + IDENTIFIER,
             "environment": "simulator", "simulatorUDID": lease()["simulatorUDID"], "processID": 200,
             "deadlineExpired": False, "taskCompleted": True, "startedUnix": 1000, "finishedUnix": 1001,
             "startedUptime": 10, "finishedUptime": 11, "ephemeral": True, "URLCacheDisabled": True,
             "waitsForConnectivity": False, "redirects": [], "HTTPStatus": 200, "responseBytes": 100,
             "errorDomain": None, "errorCode": None, "transactions": [{"resourceFetchType": "networkLoad",
             "proxyConnection": False, "reusedConnection": False}]}
    if phase == "during":
        value.update(HTTPStatus=None, responseBytes=0, errorDomain="NSURLErrorDomain", errorCode=-1004, transactions=[])
    return value


def check_probe(value):
    return m.probe_valid(value, phase=value["phase"], kind="simulator", udid=lease()["simulatorUDID"], nonce=IDENTIFIER, endpoint="github-v40")


class Controls(unittest.TestCase):
    def test_no_import_side_effect(self):
        self.assertFalse(hasattr(m, "active_window"))

    def test_exact_owned_anchor(self):
        self.assertEqual(m.anchor_name(IDENTIFIER), "com.apple/000.otzaria-offline-" + IDENTIFIER)

    def test_root_or_foreign_anchor_cannot_be_addressed(self):
        for value in ["", "com.apple", "../scaleway", IDENTIFIER.upper(), "a" * 31, "a" * 33]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                m.anchor_name(value)

    def test_exit_zero_pf_diagnostic_still_fails(self):
        with self.assertRaises(ValueError):
            m.pf_output("partial rules", "DIOCGETRULES: Invalid argument\n")

    def test_only_known_altq_diagnostics(self):
        self.assertEqual(m.pf_output("rules\n", "No ALTQ support in kernel\nALTQ related functions disabled\n"), "rules")

    def test_full_recursive_children_preserve_names(self):
        self.assertEqual(m.parse_anchor_children("  com.apple/200.AirDrop\n  com.apple/scaleway\n", "com.apple"),
                         ["com.apple/200.AirDrop", "com.apple/scaleway"])

    def test_recursive_listing_cannot_hide_depth_or_wildcard(self):
        for value in ["com.apple/other/child", "com.apple/*", "../root", "a\na"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                m.parse_anchor_children(value, "com.apple")

    def test_rules_keep_incoming_and_exact_outgoing_ssh(self):
        rules = m.make_rules(IDENTIFIER, [INCOMING, OUTGOING])
        self.assertIn("from 192.0.2.20 port 22 to 192.0.2.10 flags any no state", rules)
        self.assertIn("from 192.0.2.20 port 44002 to 198.51.100.9 port 22", rules)
        self.assertTrue(rules.splitlines()[-1].startswith("block return out quick on ! lo0 all"))
        self.assertNotIn("pass in", rules)

    def test_source_or_destination_port_wildcard_not_admitted(self):
        for key, value in [("localPort", "any"), ("peerPort", 0), ("interface", "utun0"), ("transport", "socks")]:
            bad = {**INCOMING, key: value}
            with self.subTest(key=key), self.assertRaises((ValueError, TypeError)):
                m.normalize_control(bad)

    def test_explicit_ssh_states_are_admitted(self):
        rows = "ALL tcp 192.0.2.20:22 <- 192.0.2.10:44001 ESTABLISHED:ESTABLISHED\n" \
             + "en0 tcp 192.0.2.20:44002 -> 198.51.100.9:22 ESTABLISHED:ESTABLISHED\n"
        self.assertEqual(len(m.admit_pf_states(rows, [INCOMING, OUTGOING])), 2)

    def test_old_public_connection_cannot_bypass_new_filter(self):
        for row in ["ALL tcp 192.0.2.20:44002 -> 198.51.100.9:443 ESTABLISHED:ESTABLISHED",
                    "ALL udp 192.0.2.20:30000 -> 198.51.100.7:443 MULTIPLE:MULTIPLE",
                    "ALL tcp 192.0.2.20:22 <- 198.51.100.7:44001 ESTABLISHED:ESTABLISHED"]:
            with self.subTest(row=row), self.assertRaises(ValueError):
                m.admit_pf_states(row, [INCOMING, OUTGOING])

    def test_natural_empty_state_table_is_eligible(self):
        self.assertEqual(m.admit_pf_states("", [INCOMING]), [])

    def test_exact_translated_vnc_preserves_existing_control_only(self):
        value = translated()
        self.assertEqual(len(m.admit_pf_states(value["stateLine"], [INCOMING], [value])), 1)
        candidate = lease(); candidate["translatedVNC"] = [value]
        self.assertEqual(m.admit_lease(candidate, "a" * 64, now=1001)["translatedVNC"], [value])
        self.assertNotIn("5900", m.make_rules(IDENTIFIER, [INCOMING]))

    def test_translated_vnc_partial_or_different_chain_fails(self):
        value = translated()
        for row in [value["stateLine"].replace("34300", "34301"), value["stateLine"].replace("127.0.0.1", "192.0.2.99"),
                    value["stateLine"].replace("ESTABLISHED:ESTABLISHED", "TIME_WAIT:TIME_WAIT"), ""]:
            with self.subTest(row=row), self.assertRaises(ValueError):
                m.admit_pf_states(row, [INCOMING], [value])

    def test_unowned_vnc_translation_not_exempt(self):
        with self.assertRaises(ValueError):
            m.admit_pf_states(translated()["stateLine"], [INCOMING])

    def test_vnc_listener_without_actual_connection_is_not_admitted(self):
        value = translated(); candidate = lease(); candidate["translatedVNC"] = [value]
        value["connection"]["ST"] = "LISTEN"
        with self.assertRaises(ValueError):
            m.admit_lease(candidate, "a" * 64, now=1001)

    def test_no_general_nat_or_vnc_owner_bypass(self):
        for mutation in [lambda v: v.update(coordinatorConfirmedControlOnly=False),
                         lambda v: v["owner"].update(command="/usr/bin/curl"),
                         lambda v: v["connection"].update(n="127.0.0.1:5900->198.51.100.7:443")]:
            candidate = lease(); value = translated(); mutation(value); candidate["translatedVNC"] = [value]
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                m.admit_lease(candidate, "a" * 64, now=1001)

    def test_lsof_uses_actual_process_socket_ownership(self):
        rows = m.parse_lsof("p42\ncsshd-session\nf5\nPTCP\nn192.0.2.20:22->192.0.2.10:44001\nTST=ESTABLISHED\nTQR=0\nTQS=0\n")
        self.assertEqual(m.admitted_socket(rows[0], [INCOMING]), INCOMING)

    def test_nonssh_process_cannot_use_control_exclusion(self):
        row = {"name": "curl", "P": "TCP", "ST": "ESTABLISHED", "n": "192.0.2.20:22->192.0.2.10:44001"}
        with self.assertRaises(ValueError):
            m.admitted_socket(row, [INCOMING])

    def test_ssh_forward_listener_is_not_control(self):
        with self.assertRaises(ValueError):
            m.admitted_socket({"name": "ssh", "P": "TCP", "ST": "LISTEN", "n": "127.0.0.1:1080"}, [INCOMING])

    def test_negative_request_pending_socket_only_after_active_rule(self):
        control = {"pid": 10, "name": "sshd-session", "P": "TCP", "ST": "ESTABLISHED", "n": "192.0.2.20:22->192.0.2.10:44001"}
        pending = {"pid": 20, "name": "probe", "P": "TCP", "ST": "SYN_SENT", "n": "192.0.2.20:54000->198.51.100.8:443"}
        with patch.object(m, "process", return_value={"command": "/usr/libexec/sshd-session"}):
            with self.assertRaises(ValueError):
                m.admit_connections([control, pending], [INCOMING])
            self.assertEqual(len(m.admit_connections([control, pending], [INCOMING], allow_denied_pending=True)), 2)
            with self.assertRaises(ValueError):
                m.admit_connections([control, {**pending, "ST": "ESTABLISHED"}], [INCOMING], allow_denied_pending=True)

    def test_duplicate_json_cannot_replace_gate(self):
        with self.assertRaises(ValueError):
            m.strict_json('{"active":false,"active":true}')

    def test_nonfinite_json_cannot_extend_deadline(self):
        with self.assertRaises(ValueError):
            m.strict_json('{"deadline":NaN}')

    def test_explicit_finite_bounded_coordinated_lease(self):
        self.assertEqual(m.admit_lease(lease(), "a" * 64, now=1001)["windowID"], IDENTIFIER)

    def test_uncoordinated_or_expired_lease_fails(self):
        changes = [("status", "PASS"), ("controllerSourceSHA256", "b" * 64), ("allOtherNetworkAndNativeWorkPaused", False),
                   ("hardDeadlineUnix", 1000), ("hardDeadlineUnix", 2000), ("notBeforeUnix", 1002),
                   ("selectedCaseID", "other/test"), ("oracleHeartbeatPeer", "198.51.100.7")]
        for key, value in changes:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                m.admit_lease({**lease(), key: value}, "a" * 64, now=1001)

    def test_true_online_foundation_control(self):
        self.assertEqual(check_probe(probe())["HTTPStatus"], 200)

    def test_true_transport_error_shape(self):
        self.assertEqual(check_probe(probe("during"))["errorCode"], -1004)

    def test_HTTP_failure_cancellation_TLS_and_empty_receipt_fail(self):
        for change in [{"HTTPStatus": 503}, {"errorCode": -999}, {"errorCode": -1200}, {"errorDomain": "SyntheticError"},
                       {"deadlineExpired": True}, {"taskCompleted": False}, {"responseBytes": 1}, {"transactions": [], "errorCode": None}]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                check_probe({**probe("during"), **change})

    def test_cached_proxy_reused_or_redirected_online_success_fails(self):
        for transaction in [{"resourceFetchType": "localCache", "proxyConnection": False, "reusedConnection": False},
                            {"resourceFetchType": "networkLoad", "proxyConnection": True, "reusedConnection": False},
                            {"resourceFetchType": "networkLoad", "proxyConnection": False, "reusedConnection": True}]:
            with self.subTest(transaction=transaction), self.assertRaises(ValueError):
                check_probe({**probe(), "transactions": [transaction]})
        with self.assertRaises(ValueError):
            check_probe({**probe(), "redirects": ["https://elsewhere.example"]})

    def test_wrong_simulator_nonce_or_nonphysical_condition_fails(self):
        for key, value in [("simulatorUDID", "wrong"), ("environment", "host"), ("nonce", "different"), ("phase", "offline-icon")]:
            v = probe("during"); v[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                check_probe(v)

    def test_counter_uses_packets_not_evaluations(self):
        raw = "otzaria-denial-" + IDENTIFIER + " 1000 7 100 0 0 7 100 0"
        self.assertEqual(m.blocking_packets(raw, IDENTIFIER), 7)

    def test_unqualified_counter_shape_fails(self):
        for raw in ["", "otzaria-denial-" + IDENTIFIER + " 1000", "dropped packet events"]:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                m.blocking_packets(raw, IDENTIFIER)

    def policy(self, **changes):
        values = {"now_mono": 120, "now_unix": 1020, "last_tick": 119,
                  "sealed": {"bootSession": "boot", "hardDeadlineMonotonic": 200, "lease": {"hardDeadlineUnix": 1100}},
                  "heartbeat": {"bootSession": "boot", "observedMonotonic": 119}, "controller_alive": True,
                  "actual_boot": "boot", "original_unchanged": True, "own_rules_match": True, "activated": True, "finish": False}
        values.update(changes)
        return m.watchdog_reason(**values)

    def test_healthy_finite_window_continues(self):
        self.assertIsNone(self.policy())

    def test_controller_death_rolls_back(self):
        self.assertEqual(self.policy(controller_alive=False), "controller-identity-missing")

    def test_hard_monotonic_deadline_cannot_be_renewed_by_heartbeat(self):
        self.assertEqual(self.policy(now_mono=201, last_tick=200, heartbeat={"bootSession": "boot", "observedMonotonic": 201}), "hard-deadline")

    def test_wall_clock_rollback_does_not_extend_monotonic_limit(self):
        self.assertEqual(self.policy(now_mono=201, now_unix=1001, last_tick=200), "hard-deadline")

    def test_oracle_control_loss_rolls_back_even_with_live_controller(self):
        self.assertEqual(self.policy(heartbeat={"bootSession": "boot", "observedMonotonic": 80}), "authenticated-oracle-heartbeat-expired")

    def test_unknown_heartbeat_boot_is_not_a_renewal(self):
        self.assertEqual(self.policy(heartbeat={"bootSession": "other", "observedMonotonic": 119}), "authenticated-oracle-heartbeat-missing")

    def test_new_boot_cannot_reuse_old_lease(self):
        self.assertEqual(self.policy(actual_boot="other"), "boot-session-changed")

    def test_observation_gap_invalidates_continuity(self):
        self.assertEqual(self.policy(last_tick=100), "watchdog-observation-gap")

    def test_original_drift_and_early_restoration_are_failures(self):
        self.assertEqual(self.policy(original_unchanged=False), "original-network-or-pf-drift")
        self.assertEqual(self.policy(own_rules_match=False), "owned-rules-missing-or-changed")

    def test_normal_finish_is_explicit(self):
        self.assertEqual(self.policy(finish=True), "normal-finish-requested")

    def test_finish_cannot_hide_observed_drift(self):
        self.assertEqual(self.policy(finish=True, original_unchanged=False), "original-network-or-pf-drift")
        self.assertEqual(self.policy(finish=True, own_rules_match=False), "owned-rules-missing-or-changed")

    def test_rollback_never_addresses_global_pf_or_states(self):
        with tempfile.TemporaryDirectory() as directory:
            state, calls = {"rules": "the-owned-rule"}, []
            def pf(*args):
                calls.append(args)
                if args[-2:] == ("-F", "rules"):
                    state["rules"] = ""; return ""
                self.assertEqual(args, ("-a", m.anchor_name(IDENTIFIER), "-sr"))
                return state["rules"]
            with patch.object(m, "pf", pf):
                result = m.rollback(Path(directory), {"windowID": IDENTIFIER, "lease": {"mode": "network-denial"}, "baseline": {}}, "test", True, [])
            self.assertEqual(result["status"], "OWNED_RULES_EMPTY_ROLLBACK_VERIFIED")
            self.assertTrue(all(args[:2] == ("-a", m.anchor_name(IDENTIFIER)) for args in calls))
            self.assertNotIn(("-F", "states"), calls)

    def test_failed_cleanup_retries_only_owned_anchor_and_never_passes(self):
        with tempfile.TemporaryDirectory() as directory:
            calls = []
            def pf(*args):
                calls.append(args)
                raise RuntimeError("actual cleanup unavailable (synthetic source control)")
            with patch.object(m, "pf", pf), self.assertRaises(RuntimeError):
                m.rollback(Path(directory), {"windowID": IDENTIFIER, "lease": {"mode": "network-denial"}, "baseline": {}}, "test", True, [])
            self.assertEqual(len(calls), 3)
            self.assertFalse((Path(directory) / "cleanup.json").exists())

    def test_no_denial_rollback_never_loads_or_flushes_a_rule(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(m, "pf", return_value="") as pf:
                result = m.rollback(Path(directory), {"windowID": IDENTIFIER, "lease": {"mode": "watchdog-exercise-no-denial"}, "baseline": {}}, "hard-deadline", False, [])
            self.assertFalse(result["activated"])
            self.assertTrue(all(call.args == ("-a", m.anchor_name(IDENTIFIER), "-sr") for call in pf.call_args_list))

    def test_synthetic_receipt_cannot_waive_actual_watchdog_exercise(self):
        with self.assertRaises(ValueError):
            m.verify_actual_watchdog_exercises({"windowID": IDENTIFIER, "watchdogExerciseReceipts": {}}, "a" * 64)

    def test_receipt_write_after_activation_failure_still_rolls_back(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            sealed = {"windowID": IDENTIFIER, "bootSession": "boot", "preparedMonotonic": 100,
                      "hardDeadlineMonotonic": 200, "controller": {"pid": 100},
                      "lease": {"mode": "network-denial", "hardDeadlineUnix": 1100, "controls": [], "translatedVNC": []},
                      "baseline": {"pf": {}, "network": {}}, "normalizedRules": "owned"}
            m.private_write(directory / "heartbeat.json", {"bootSession": "boot", "observedMonotonic": 100})
            m.private_write(directory / "activate-request.json", {})
            original_write = m.private_write
            loaded, calls = {"value": False}, []
            def write(path, value, replace=False):
                if Path(path).name == "activated.json":
                    raise OSError("ENOSPC synthetic source boundary")
                return original_write(path, value, replace)
            def pf(*args):
                calls.append(args)
                if "-f" in args: loaded["value"] = True; return ""
                if "-F" in args: loaded["value"] = False; return ""
                return "owned" if loaded["value"] else ""
            with patch.object(m, "load_sealed", return_value=(directory, sealed)), patch.object(m, "private_write", side_effect=write), \
                 patch.object(m, "process", return_value={"pid": 200}), patch.object(m, "process_is_same", return_value=True), \
                 patch.object(m, "boot_identity", return_value="boot"), patch.object(m, "pf_snapshot", return_value={}), \
                 patch.object(m, "network_snapshot", return_value={}), patch.object(m, "connections", return_value=[]), \
                 patch.object(m, "admit_connections", return_value=[]), patch.object(m, "pf", side_effect=pf), \
                 patch.object(m.time, "monotonic", return_value=100), patch.object(m.time, "time", return_value=1000):
                with self.assertRaises(OSError):
                    m.watchdog(IDENTIFIER)
            self.assertFalse(loaded["value"])
            result = json.loads((directory / "cleanup.json").read_text())
            self.assertTrue(result["activated"])
            self.assertEqual(result["status"], "OWNED_RULES_EMPTY_ROLLBACK_VERIFIED")


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(Controls)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    record = {"scope": "SYNTHETIC_SOURCE_CONTROLS_ONLY_NO_MAC_PF_NETWORK_LAUNCHD_OR_UI",
              "testsRun": result.testsRun, "failures": len(result.failures), "errors": len(result.errors),
              "success": result.wasSuccessful(), "nativeExecutions": 0, "denialWindows": 0,
              "sourceSHA256": hashlib.sha256(SOURCE.read_bytes()).hexdigest()}
    (HERE / "SOURCE_CONTROLS.json").write_text(json.dumps(record, indent=2) + "\n")
    raise SystemExit(0 if result.wasSuccessful() else 1)
