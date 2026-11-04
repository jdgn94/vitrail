"""Snapshots pick the backend and build the right command."""

from __future__ import annotations

import tempfile
import unittest
from unittest import mock

from vitrail import snapshot


class BackendTests(unittest.TestCase):
    def test_btrfs_is_preferred(self) -> None:
        with mock.patch.object(snapshot.shutil, "which", return_value="/usr/bin/x"):
            self.assertEqual(snapshot.backend(lambda argv: "btrfs\n"), "btrfs")

    def test_timeshift_is_the_fallback(self) -> None:
        with mock.patch.object(snapshot.shutil, "which", return_value="/usr/bin/x"):
            self.assertEqual(snapshot.backend(lambda argv: "ext4\n"), "timeshift")

    def test_no_backend(self) -> None:
        with mock.patch.object(snapshot.shutil, "which", return_value=None):
            self.assertEqual(snapshot.backend(lambda argv: "ext4\n"), "")


class CreateTests(unittest.TestCase):
    def test_a_btrfs_snapshot_uses_sudo_and_the_read_only_flag(self) -> None:
        calls: list[list[str]] = []

        def run(argv: list[str]) -> str:
            calls.append(argv)
            return ""

        result = snapshot.create("lab", run, kind="btrfs")
        self.assertEqual(result["path"], "/.snapshots/lab")
        self.assertIn(["sudo", "-n", "btrfs", "subvolume", "snapshot", "-r", "/", "/.snapshots/lab"], calls)

    def test_a_timeshift_snapshot_is_scripted(self) -> None:
        calls: list[list[str]] = []
        result = snapshot.create("lab", lambda argv: calls.append(argv) or "", kind="timeshift")
        self.assertEqual(result["backend"], "timeshift")
        self.assertIn("--scripted", calls[0])

    def test_a_failed_command_is_reported(self) -> None:
        self.assertIn("error", snapshot.create("lab", lambda argv: None, kind="btrfs"))

    def test_without_a_backend_there_is_no_snapshot(self) -> None:
        self.assertIn("error", snapshot.create("lab", lambda argv: "", kind=""))


class ListingTests(unittest.TestCase):
    def test_a_btrfs_listing_is_read(self) -> None:
        with mock.patch.object(snapshot.shutil, "which", return_value="/usr/bin/x"):
            lines = snapshot.listing(lambda argv: "ID 256 /vitrail-update-1\n" if "list" in argv else "btrfs\n")
        self.assertEqual(lines, ["ID 256 /vitrail-update-1"])


if __name__ == "__main__":
    unittest.main()
