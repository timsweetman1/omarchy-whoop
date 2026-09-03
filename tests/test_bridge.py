import importlib.machinery
import importlib.util
import json
import stat
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock


BRIDGE_PATH = Path(__file__).parents[1] / "bin" / "whoop-bridge"
LOADER = importlib.machinery.SourceFileLoader("whoop_bridge", str(BRIDGE_PATH))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
BRIDGE = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(BRIDGE)


class BridgeTests(unittest.TestCase):
    def test_private_json_write_is_atomic_and_owner_only(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "private" / "value.json"
            BRIDGE.write_private_json(target, {"safe": True})
            self.assertEqual(json.loads(target.read_text()), {"safe": True})
            self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE(target.parent.stat().st_mode), 0o700)
            self.assertEqual(list(target.parent.glob("*.tmp")), [])

    def test_detail_never_reads_an_environment_selected_path(self):
        with tempfile.TemporaryDirectory() as directory:
            trusted = Path(directory) / "trusted.json"
            trusted.write_text('{"source":"trusted"}', encoding="utf-8")
            with (
                mock.patch.object(BRIDGE, "STATE_FILE", trusted),
                mock.patch.dict("os.environ", {"XDG_STATE_HOME": "/tmp/untrusted"}),
                mock.patch("builtins.print") as output,
            ):
                BRIDGE.command_detail(SimpleNamespace())
            self.assertIn('"source":"trusted"', output.call_args.args[0])

    def test_validate_token_rejects_header_injection(self):
        for token in ("", "safe\r\nInjected: true", "x" * 8193):
            with self.subTest(token_length=len(token)):
                with self.assertRaises(RuntimeError):
                    BRIDGE.validate_token(token, "access token")

    @mock.patch.object(BRIDGE.subprocess, "run")
    def test_bearer_token_is_not_exposed_in_process_arguments(self, run):
        run.return_value = SimpleNamespace(
            stdout='{"ok": true}\n200', stderr="", returncode=0
        )
        payload = BRIDGE.curl_json("https://api.prod.whoop.com/test", bearer="secret-token")
        command = run.call_args.args[0]
        self.assertEqual(payload, {"ok": True})
        self.assertNotIn("secret-token", command)
        self.assertIn("--disable", command)
        self.assertIn("--max-time", command)
        self.assertEqual(run.call_args.kwargs["input"], "Authorization: Bearer secret-token\n")

    @mock.patch.object(BRIDGE.subprocess, "run")
    @mock.patch.object(BRIDGE, "save_config")
    @mock.patch.object(BRIDGE, "load_config")
    @mock.patch.object(BRIDGE, "keyring_lookup", return_value="client-secret")
    def test_authorize_generates_strong_short_lived_state(
        self, _lookup, load_config, save_config, run
    ):
        load_config.return_value = {"client_id": "00000000-0000-4000-8000-000000000000"}
        before = int(BRIDGE.time.time())
        BRIDGE.command_authorize(SimpleNamespace())
        saved = save_config.call_args.args[0]
        self.assertEqual(len(saved["pending_state"]), 8)
        self.assertGreaterEqual(saved["pending_state_expires_at"], before + 599)
        opened_url = run.call_args.args[0][1]
        query = BRIDGE.urllib.parse.parse_qs(BRIDGE.urllib.parse.urlparse(opened_url).query)
        self.assertEqual(query["state"], [saved["pending_state"]])
        self.assertEqual(query["redirect_uri"], [BRIDGE.REDIRECT_URI])

    @mock.patch.object(BRIDGE, "log_callback")
    @mock.patch.object(BRIDGE, "load_config", return_value={})
    def test_callback_rejects_unregistered_target(self, _load, _log):
        with self.assertRaisesRegex(RuntimeError, "target was invalid"):
            BRIDGE.command_callback(
                SimpleNamespace(url="whoop://omarchy-whoop/callback?code=x&state=y")
            )

    @mock.patch.object(BRIDGE.subprocess, "run")
    @mock.patch.object(BRIDGE, "command_sync")
    @mock.patch.object(BRIDGE, "save_tokens")
    @mock.patch.object(
        BRIDGE,
        "token_request",
        return_value={
            "access_token": "a",
            "refresh_token": "r",
            "token_type": "bearer",
            "scope": "offline read:recovery read:cycles read:sleep",
            "expires_in": 3600,
        },
    )
    @mock.patch.object(BRIDGE, "keyring_lookup", return_value="client-secret")
    @mock.patch.object(BRIDGE, "save_config")
    @mock.patch.object(BRIDGE, "load_config")
    @mock.patch.object(BRIDGE, "log_callback")
    def test_callback_consumes_state_before_token_exchange(
        self, _log, load_config, save_config, _lookup, token_request,
        save_tokens, sync, _run
    ):
        load_config.return_value = {
            "client_id": "00000000-0000-4000-8000-000000000000",
            "pending_state": "expected",
            "pending_state_expires_at": int(BRIDGE.time.time()) + 60,
        }
        args = SimpleNamespace(
            url="omarchy-whoop://oauth/callback?code=one-time&state=expected"
        )
        BRIDGE.command_callback(args)
        consumed = save_config.call_args.args[0]
        self.assertNotIn("pending_state", consumed)
        self.assertNotIn("pending_state_expires_at", consumed)
        token_request.assert_called_once()
        save_tokens.assert_called_once_with(token_request.return_value, require_refresh=True)
        sync.assert_called_once_with(args)

    @mock.patch.object(BRIDGE, "keyring_clear")
    def test_disconnect_removes_all_local_sensitive_state(self, clear):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            paths = [base / "latest.json", base / "callback.log", base / "config.json"]
            for path in paths:
                path.write_text("sensitive", encoding="utf-8")
            with (
                mock.patch.object(BRIDGE, "STATE_FILE", paths[0]),
                mock.patch.object(BRIDGE, "CALLBACK_LOG", paths[1]),
                mock.patch.object(BRIDGE, "CONFIG_FILE", paths[2]),
            ):
                BRIDGE.command_disconnect(SimpleNamespace())
            self.assertEqual(
                [call.args[0] for call in clear.call_args_list],
                ["access-token", "refresh-token", "client-secret"],
            )
            self.assertTrue(all(not path.exists() for path in paths))

    @mock.patch.object(BRIDGE, "keyring_store")
    def test_save_tokens_fails_closed_on_missing_scopes(self, store):
        with self.assertRaisesRegex(RuntimeError, "granted scopes"):
            BRIDGE.save_tokens(
                {
                    "access_token": "a",
                    "refresh_token": "r",
                    "token_type": "bearer",
                    "expires_in": 3600,
                },
                require_refresh=True,
            )
        store.assert_not_called()

    @mock.patch.object(BRIDGE, "curl_json")
    def test_token_endpoint_error_does_not_echo_response(self, curl_json):
        curl_json.side_effect = BRIDGE.WhoopHttpError(
            400, "client_secret=should-never-be-printed"
        )
        with self.assertRaises(BRIDGE.WhoopHttpError) as raised:
            BRIDGE.token_request({"client_secret": "local-secret"})
        self.assertNotIn("should-never-be-printed", str(raised.exception))
        self.assertIn("token request was rejected", str(raised.exception))

    def test_compact_summary_uses_scored_metrics(self):
        summary = BRIDGE.compact_summary(
            {
                "score_state": "SCORED",
                "score": {"recovery_score": 72, "hrv_rmssd_milli": 51.25},
            },
            {"score_state": "SCORED", "score": {"strain": 10.5}},
            {
                "score_state": "SCORED",
                "score": {
                    "sleep_performance_percentage": 88,
                    "stage_summary": {
                        "total_light_sleep_time_milli": 14_400_000,
                        "total_slow_wave_sleep_time_milli": 5_400_000,
                        "total_rem_sleep_time_milli": 5_400_000,
                    },
                },
            },
        )
        self.assertEqual(summary["recovery"]["recovery_score"], 72)
        self.assertEqual(summary["recovery"]["hrv_rmssd_milli"], 51.25)
        self.assertEqual(summary["sleep"]["sleep_duration_hours"], 7.0)
        self.assertEqual(summary["cycle"]["day_strain"], 10.5)

    def test_weekly_trend_aligns_records_by_cycle_and_sorts_oldest_first(self):
        recoveries = [
            {"cycle_id": 2, "created_at": "2026-09-02T12:00:00Z", "score": {"recovery_score": 40}},
            {"cycle_id": 1, "created_at": "2026-09-01T12:00:00Z", "score": {"recovery_score": 80}},
        ]
        cycles = [
            {"id": 2, "score": {"strain": 12}},
            {"id": 1, "score": {"strain": 8}},
        ]
        sleeps = [
            {
                "cycle_id": 2,
                "end": "2026-09-02T12:00:00Z",
                "nap": False,
                "score": {"sleep_performance_percentage": 75, "stage_summary": {}},
            },
            {
                "cycle_id": 1,
                "end": "2026-09-01T12:00:00Z",
                "nap": False,
                "score": {"sleep_performance_percentage": 90, "stage_summary": {}},
            },
        ]
        trend = BRIDGE.weekly_trend(recoveries, cycles, sleeps)
        self.assertEqual([day["date"] for day in trend], ["2026-09-01", "2026-09-02"])
        self.assertEqual(trend[0]["day_strain"], 8)
        self.assertEqual(trend[1]["sleep_performance_percentage"], 75)


if __name__ == "__main__":
    unittest.main()
