"""The clipboard store's settings: the history size lands where cliphist reads it."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from vitrail import clipboard, cli, prefs


class ApplyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.env = mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": self.tmp.name})
        self.env.start()
        self.addCleanup(self.env.stop)

    def test_the_size_lands_in_the_cliphist_config(self) -> None:
        path = clipboard.apply(300)
        self.assertEqual(path, Path(self.tmp.name) / "cliphist" / "config")
        self.assertEqual(path.read_text(encoding="utf-8"), "-max-items 300\n")

    def test_the_cli_writes_both_the_preference_and_the_store(self) -> None:
        self.assertEqual(cli.main(["config", "set", "clipboardMax", "250"]), 0)
        config = Path(self.tmp.name) / "vitrail"
        self.assertEqual(prefs.read_prefs(config)["clipboardMax"], "250")
        self.assertEqual(clipboard.config_path().read_text(encoding="utf-8"), "-max-items 250\n")

    def test_apply_uses_the_preference_or_the_default(self) -> None:
        self.assertEqual(cli.main(["clipboard", "apply"]), 0)
        self.assertEqual(clipboard.config_path().read_text(encoding="utf-8"), "-max-items 100\n")
        prefs.write_pref(Path(self.tmp.name) / "vitrail", "clipboardMax", "640")
        self.assertEqual(cli.main(["clipboard", "apply"]), 0)
        self.assertEqual(clipboard.config_path().read_text(encoding="utf-8"), "-max-items 640\n")

    def test_the_cli_refuses_a_size_outside_the_range(self) -> None:
        self.assertEqual(cli.main(["config", "set", "clipboardMax", "10"]), 2)
        self.assertFalse(clipboard.config_path().exists())


class ForgetColourTests(unittest.TestCase):
    """A colour is not a copy: the picker copies it, then the store drops it."""

    def runner(self, listing: bytes) -> tuple[list[tuple[list[str], bytes | None]], mock.Mock]:
        calls: list[tuple[list[str], bytes | None]] = []

        def run(argv, data=None):
            calls.append((argv, data))
            return listing if argv[:2] == ["cliphist", "list"] else b""

        return calls, mock.Mock(side_effect=run)

    def forget(self, text: str, listing: bytes = b"") -> tuple[list, int]:
        calls, run = self.runner(listing)
        removed = clipboard.forget_color(text, delay=0, run=run, sleep=lambda _seconds: None)
        return calls, removed

    def test_only_an_exact_colour_entry_is_deleted(self) -> None:
        listing = b"4\t#AABBCC\n3\ttext\n2\t#aabbcc\n1\tkeep #AABBCC\n"
        calls, removed = self.forget("#AABBCC", listing)
        self.assertEqual(removed, 2)
        self.assertEqual(calls[-1], (["cliphist", "delete"], b"4\n2\n"))

    def test_rgb_and_hsl_copies_are_colours_too(self) -> None:
        listing = b"2\trgb(1, 2, 3)\n1\thsla(0, 100%, 50%, 1)\n"
        calls, removed = self.forget("rgb(1, 2, 3)", listing)
        self.assertEqual(removed, 1)
        self.assertEqual(calls[-1][1], b"2\n")

    def test_text_and_images_are_never_deleted(self) -> None:
        listing = b"3\tpassword=hunter2\n2\t[[ binary data 12 KiB png 80x60 ]]\n"
        calls, removed = self.forget("password=hunter2", listing)
        self.assertEqual(removed, 0)
        self.assertNotIn(["cliphist", "delete"], [call[0] for call in calls])

    def test_the_watcher_gets_a_moment_to_store_it_first(self) -> None:
        slept: list[float] = []
        calls, run = self.runner(b"1\t#FFFFFF\n")
        clipboard.forget_color("#FFFFFF", run=run, sleep=slept.append)
        self.assertEqual(len(slept), 1)
        self.assertGreater(slept[0], 0)

    def test_the_cli_forgets_the_colour_it_copied(self) -> None:
        with mock.patch.object(clipboard, "forget_color") as forget:
            self.assertEqual(cli.main(["clipboard", "forget-colour", "#ABCDEF"]), 0)
            forget.assert_called_once_with("#ABCDEF")
