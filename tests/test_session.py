"""The session guard: what a shutdown, reboot or logout would interrupt."""

from __future__ import annotations

import io
import json
import os
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

from vitrail import session


class Home(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.downloads = self.root / "Downloads"
        self.downloads.mkdir()
        self.jobs = self.root / "jobs"
        self.jobs.mkdir()

    def check(self, commands=None) -> list[dict]:
        return session.running([self.downloads], commands or [], self.jobs)

    def job(self, pid: int, name: str) -> Path:
        path = self.jobs / f"{pid}-x.json"
        path.write_text(json.dumps({"pid": pid, "name": name, "app": "Vitrail", "started": 1}), encoding="utf-8")
        return path


class DownloadTests(Home):
    def test_a_file_still_being_written_is_a_download(self) -> None:
        (self.downloads / "big.iso.part").write_bytes(b"x" * 100)
        self.assertEqual(self.check(), [{"kind": "download", "label": "big.iso.part"}])

    def test_a_leftover_partial_is_not(self) -> None:
        path = self.downloads / "old.iso.part"
        path.write_bytes(b"")
        os.utime(path, (1.0, 1.0))
        self.assertEqual(self.check(), [])

    def test_a_finished_file_is_not_a_download(self) -> None:
        (self.downloads / "big.iso").write_bytes(b"x" * 100)
        self.assertEqual(self.check(), [])


class UpdateTests(Home):
    def test_a_package_manager_is_an_update(self) -> None:
        commands = [["/usr/bin/pacman", "-Syu"], ["bash"], ["yay", "-Syu"], ["/usr/bin/paru", "-Syu"]]
        self.assertEqual(self.check(commands),
                         [{"kind": "update", "label": "pacman"}, {"kind": "update", "label": "paru"},
                          {"kind": "update", "label": "yay"}])

    def test_an_unrelated_program_is_not(self) -> None:
        self.assertEqual(self.check([["kitty"], ["python3", "-m", "vitrail.jobs", "run"]]), [])


class JobTests(Home):
    def test_a_registered_job_is_running(self) -> None:
        self.job(os.getpid(), "Copying photos")
        self.assertEqual(self.check(), [{"kind": "job", "label": "Copying photos"}])

    def test_a_job_whose_process_is_gone_is_forgotten(self) -> None:
        path = self.job(2_000_000_000, "Old job")
        self.assertEqual(self.check(), [])
        self.assertFalse(path.exists())

    def test_a_broken_registry_file_is_ignored(self) -> None:
        (self.jobs / "1-bad.json").write_text("not json", encoding="utf-8")
        self.assertEqual(self.check(), [])


class OrderTests(Home):
    def test_everything_running_is_listed_downloads_first(self) -> None:
        (self.downloads / "a.zip.crdownload").write_bytes(b"x" * 10)
        self.job(os.getpid(), "Backup")
        kinds = [one["kind"] for one in self.check([["pacman", "-Syu"]])]
        self.assertEqual(kinds, ["download", "update", "job"])


class MainTests(unittest.TestCase):
    def test_check_prints_json(self) -> None:
        with mock.patch.object(session, "running", return_value=[{"kind": "job", "label": "Copy"}]):
            with redirect_stdout(io.StringIO()) as out:
                self.assertEqual(session.main(["check"]), 0)
        self.assertEqual(json.loads(out.getvalue()), {"jobs": [{"kind": "job", "label": "Copy"}]})

    def test_an_unknown_command_prints_the_usage(self) -> None:
        with redirect_stderr(io.StringIO()) as err:
            self.assertEqual(session.main([]), 2)
        self.assertIn("session check", err.getvalue())


if __name__ == "__main__":
    unittest.main()
