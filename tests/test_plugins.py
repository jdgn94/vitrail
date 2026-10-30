"""Plugin discovery contract."""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from vitrail import plugins


def write_plugin(root: Path, name: str, manifest: str, entry: bool = True) -> None:
    folder = root / name
    folder.mkdir(parents=True)
    (folder / "plugin.json").write_text(manifest, encoding="utf-8")
    if entry:
        (folder / "P.qml").write_text("import QtQuick\nItem {}\n", encoding="utf-8")


class DiscoveryTests(unittest.TestCase):
    def test_reads_manifests_and_skips_broken_ones(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "vitrail" / "plugins"
            write_plugin(
                root,
                "good",
                json.dumps({"name": "good", "version": "1.0", "entry": "P.qml"}),
            )
            write_plugin(root, "broken", "{not json at all")
            write_plugin(
                root,
                "incomplete",
                json.dumps({"name": "incomplete", "version": "1.0"}),
            )

            with mock.patch.dict(os.environ, {"XDG_DATA_HOME": tmp}):
                found = plugins.discover()

            self.assertEqual([plugin["name"] for plugin in found], ["good"])
            self.assertTrue(found[0]["entry"].endswith("P.qml"))


if __name__ == "__main__":
    unittest.main()
