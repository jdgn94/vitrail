"""Long jobs: the same live card as a download, through one small API."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from vitrail import jobs


class FakeNotifier:
    def __init__(self) -> None:
        self.sent: list[dict] = []

    def send(self, summary, body, actions=None, hints=None, replace=0, timeout=0) -> int:
        self.sent.append({"summary": summary, "body": body, "actions": actions, "hints": hints, "replace": replace})
        return len(self.sent)


class Clock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now

    def tick(self, seconds: float) -> None:
        self.now += seconds


class JobTests(unittest.TestCase):
    def job(self, **extra) -> tuple[jobs.Job, FakeNotifier, Clock]:
        clock = Clock()
        notifier = FakeNotifier()
        return jobs.Job("Copying photos", notifier=notifier, language="en", clock=clock, **extra), notifier, clock

    def test_a_job_starts_live_with_a_cancel_action(self) -> None:
        job, notifier, _clock = self.job()
        job.start()
        first = notifier.sent[0]
        self.assertEqual(first["summary"], "Copying photos")
        self.assertEqual(first["hints"]["x-vitrail-state"], "live")
        self.assertNotIn("value", first["hints"])
        self.assertEqual(first["actions"], ["cancel", "Cancel"])

    def test_progress_is_a_percentage_only_with_a_total(self) -> None:
        job, notifier, _clock = self.job()
        job.start()
        job.update(50, 200)
        self.assertEqual(notifier.sent[-1]["hints"]["value"], 25)
        self.assertIn("50 of 200", notifier.sent[-1]["body"])
        job.update(60)
        self.assertEqual(notifier.sent[-1]["hints"]["value"], 30)

    def test_the_end_keeps_the_name_and_drops_the_actions(self) -> None:
        job, notifier, clock = self.job()
        job.start()
        clock.tick(125)
        job.finish()
        last = notifier.sent[-1]
        self.assertEqual(
            (last["summary"], last["hints"]["x-vitrail-state"], last["actions"]), ("Copying photos", "done", [])
        )
        self.assertIn("2:05", last["body"])

    def test_a_failure_and_a_cancel_say_so(self) -> None:
        job, notifier, _clock = self.job()
        job.start()
        job.fail("exit 1")
        self.assertEqual(notifier.sent[-1]["hints"]["x-vitrail-state"], "failed")
        self.assertIn("exit 1", notifier.sent[-1]["body"])
        job.cancel()
        self.assertEqual(notifier.sent[-1]["hints"]["x-vitrail-state"], "cancelled")

    def test_the_context_manager_ends_the_job(self) -> None:
        job, notifier, _clock = self.job()
        with job:
            job.update(1, 2)
        self.assertEqual([one["hints"]["x-vitrail-state"] for one in notifier.sent], ["live", "live", "done"])

    def test_an_exception_in_the_block_marks_it_failed(self) -> None:
        job, notifier, _clock = self.job()
        with self.assertRaises(RuntimeError):
            with job:
                raise RuntimeError("boom")
        self.assertEqual(notifier.sent[-1]["hints"]["x-vitrail-state"], "failed")

    def test_every_send_replaces_the_previous_one(self) -> None:
        job, notifier, _clock = self.job()
        job.start()
        job.update(1, 2)
        self.assertEqual([one["replace"] for one in notifier.sent], [0, 1])


@unittest.skipIf(sys.platform != "linux", "the command line is exercised on Linux")
class RunTests(unittest.TestCase):
    def test_a_command_runs_and_the_job_finishes(self) -> None:
        notifier = FakeNotifier()
        code = jobs.run(["/bin/sh", "-c", "true"], "A small job", notifier=notifier, language="en", poll=0.05)
        self.assertEqual(code, 0)
        self.assertEqual(notifier.sent[-1]["hints"]["x-vitrail-state"], "done")

    def test_a_failing_command_is_reported(self) -> None:
        notifier = FakeNotifier()
        code = jobs.run(["/bin/sh", "-c", "exit 3"], "A failing job", notifier=notifier, language="en", poll=0.05)
        self.assertEqual(code, 3)
        self.assertEqual(notifier.sent[-1]["hints"]["x-vitrail-state"], "failed")


class RegistryTests(unittest.TestCase):
    def test_a_running_job_registers_itself_and_is_removed_at_the_end(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            notifier = FakeNotifier()
            job = jobs.Job("Copying photos", notifier=notifier, language="en", registry=Path(folder))
            job.start()
            self.assertEqual([one["name"] for one in jobs.jobs_running(Path(folder))], ["Copying photos"])
            job.finish()
            self.assertEqual(jobs.jobs_running(Path(folder)), [])
            self.assertEqual(notifier.sent[-1]["hints"]["x-vitrail-state"], "done")

    def test_a_job_whose_process_is_gone_is_forgotten(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "1-dead.json"
            path.write_text(json.dumps({"pid": 2_000_000_000, "name": "Old", "app": "Vitrail"}), encoding="utf-8")
            self.assertEqual(jobs.jobs_running(Path(folder)), [])
            self.assertFalse(path.exists())


class ArgvTests(unittest.TestCase):
    def test_the_command_line_takes_a_name_an_app_and_a_total(self) -> None:
        seen = {}

        def fake_run(argv, name, app="Vitrail", total=None, **_rest):
            seen.update({"argv": argv, "name": name, "app": app, "total": total})
            return 0

        with mock.patch.object(jobs, "run", fake_run):
            self.assertEqual(
                jobs.main(
                    ["run", "--name", "Backup", "--app", "rsync", "--total", "10", "--", "rsync", "-a", "a", "b"]
                ),
                0,
            )
        self.assertEqual(seen, {"argv": ["rsync", "-a", "a", "b"], "name": "Backup", "app": "rsync", "total": 10})

    def test_a_command_is_required(self) -> None:
        with mock.patch("sys.stderr"):
            self.assertEqual(jobs.main(["run", "--name", "x"]), 2)
            self.assertEqual(jobs.main([]), 2)


if __name__ == "__main__":
    unittest.main()
