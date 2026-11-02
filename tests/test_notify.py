"""The notification centre's store: history, stats, and a snooze coming back."""

from __future__ import annotations

import json
import os
import stat
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from vitrail import notify


def mode(path: Path) -> int:
    return stat.S_IMODE(path.stat().st_mode)


class Home(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.env = mock.patch.dict(os.environ, {"XDG_STATE_HOME": str(self.root / "state")})
        self.env.start()
        self.addCleanup(self.env.stop)


class StoreTests(Home):
    def test_the_store_is_private(self) -> None:
        path = notify.save({"history": [], "stats": {}})
        self.assertEqual(path.parent, self.root / "state" / "vitrail")
        self.assertEqual(mode(path.parent), 0o700)
        self.assertEqual(mode(path), 0o600)

    def test_a_row_round_trips(self) -> None:
        row = {"arrived": 1000, "summary": "Hi", "body": "there", "appName": "Telegram Desktop",
               "icon": "telegram", "image": "", "conversation": "Juan", "urgent": True, "acted": False}
        notify.save({"history": [row], "stats": {"2026-11-01": {"Telegram Desktop": [2, 1]}}})
        self.assertEqual(notify.load(), {"history": [row], "stats": {"2026-11-01": {"Telegram Desktop": [2, 1]}}})

    def test_a_missing_or_broken_file_is_an_empty_history(self) -> None:
        self.assertEqual(notify.load(), {"history": [], "stats": {}})
        notify.save({"history": []})
        notify.store_path().write_text("{not json", encoding="utf-8")
        self.assertEqual(notify.load(), {"history": [], "stats": {}})

    def test_the_history_is_bounded(self) -> None:
        rows = [{"arrived": index, "summary": f"n{index}", "body": ""} for index in range(notify.LIMIT + 20)]
        notify.save({"history": rows})
        loaded = notify.load()["history"]
        self.assertEqual(len(loaded), notify.LIMIT)
        self.assertEqual(loaded[0]["summary"], "n0")
        self.assertEqual(loaded[-1]["summary"], f"n{notify.LIMIT - 1}")

    def test_the_stats_keep_the_newest_days_only(self) -> None:
        stats = {f"day-{index:03d}": {"App": [index, 0]} for index in range(notify.STATS_DAYS + 5)}
        notify.save({"history": [], "stats": stats})
        kept = list(notify.load()["stats"])
        self.assertEqual(len(kept), notify.STATS_DAYS)
        self.assertEqual(kept[0], "day-005")

    def test_a_row_without_text_is_dropped(self) -> None:
        notify.save({"history": [{"summary": "kept", "body": ""}, {"summary": "", "body": ""}, 5, None],
                     "stats": {"2026-11-01": {"App": [1, 0], "Bad": ["x", 1]}}})
        loaded = notify.load()
        self.assertEqual([row["summary"] for row in loaded["history"]], ["kept"])
        self.assertEqual(loaded["stats"], {"2026-11-01": {"App": [1, 0]}})

    def test_long_text_is_cut(self) -> None:
        notify.save({"history": [{"summary": "x" * (notify.MAX_TEXT + 10), "body": ""}], "stats": {}})
        self.assertEqual(len(notify.load()["history"][0]["summary"]), notify.MAX_TEXT)


class SendTests(unittest.TestCase):
    def test_a_snoozed_one_comes_back_as_a_new_notification(self) -> None:
        sent = []

        class Fake:
            def send(self, summary, body, actions=None, hints=None, replace=0, timeout=0):
                sent.append((summary, body, actions, hints, replace))
                return 7

        self.assertEqual(notify.send({"app": "Telegram Desktop", "icon": "telegram",
                                      "summary": "Juan", "body": "Hola"}, notifier=Fake()), 7)
        self.assertEqual(sent, [("Juan", "Hola", [], {}, 0)])

    def test_a_payload_that_is_not_an_object_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            notify.send("nope", notifier=object())


class MainTests(Home):
    def test_store_reads_a_json_document(self) -> None:
        document = {"history": [{"summary": "a", "body": ""}], "stats": {}}
        self.assertEqual(notify.main(["store", json.dumps(document)]), 0)
        self.assertEqual(notify.load()["history"][0]["summary"], "a")

    def test_store_reads_the_document_from_stdin(self) -> None:
        document = {"history": [{"summary": "b", "body": ""}], "stats": {}}
        import io

        with mock.patch("sys.stdin", io.StringIO(json.dumps(document))):
            self.assertEqual(notify.main(["store"]), 0)
        self.assertEqual(notify.load()["history"][0]["summary"], "b")

    def test_store_refuses_something_else(self) -> None:
        with mock.patch("sys.stderr"):
            self.assertEqual(notify.main(["store", "not json"]), 2)

    def test_show_prints_the_document(self) -> None:
        notify.save({"history": [{"summary": "a", "body": ""}]})
        import io
        from contextlib import redirect_stdout

        with redirect_stdout(io.StringIO()) as out:
            self.assertEqual(notify.main(["show"]), 0)
        self.assertEqual(json.loads(out.getvalue())["history"][0]["summary"], "a")


if __name__ == "__main__":
    unittest.main()
