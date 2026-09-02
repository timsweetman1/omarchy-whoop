import importlib.machinery
import importlib.util
import unittest
from pathlib import Path


BRIDGE_PATH = Path(__file__).parents[1] / "bin" / "whoop-bridge"
LOADER = importlib.machinery.SourceFileLoader("whoop_bridge", str(BRIDGE_PATH))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
BRIDGE = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(BRIDGE)


class BridgeTests(unittest.TestCase):
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
