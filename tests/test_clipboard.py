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
