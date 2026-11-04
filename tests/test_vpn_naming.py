"""The VPN is Vitrail's own program: nothing keeps the name it was vendored under.

Vitrail is installed on clean systems, so there is no upgrade path to carry:
a path, a unit, a command or a message that still names the old project is a
bug, never a compatibility shim.
"""

from __future__ import annotations

import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
OLD_NAME = "hypraether"
# The historical plans describe how the code arrived here; they are a record.
SKIP_DIRS = {".git", "graphify-out", ".opencode_plans", "__pycache__", ".venv", "vitrail.egg-info", ".backup"}
SUFFIXES = {
    ".py",
    ".qml",
    ".js",
    ".sh",
    ".md",
    ".json",
    ".service",
    ".path",
    ".conf",
    ".rules",
    ".example",
    ".txt",
    ".toml",
    ".lua",
    ".css",
    ".html",
}


def sources() -> list[Path]:
    found = []
    for path in ROOT.rglob("*"):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if path == Path(__file__).resolve():
            continue
        if path.is_file() and path.suffix.lower() in SUFFIXES:
            found.append(path)
    return found


def vpn_manager():
    """`vpn/scripts/vpn_manager.py`, loaded without installing it."""
    path = ROOT / "vpn" / "scripts" / "vpn_manager.py"
    spec = importlib.util.spec_from_file_location("vpn_manager", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class NameTests(unittest.TestCase):
    def test_the_old_name_is_gone(self) -> None:
        found = []
        for path in sources():
            text = path.read_text(encoding="utf-8", errors="ignore")
            for number, line in enumerate(text.splitlines(), 1):
                if OLD_NAME in line.lower():
                    found.append(f"{path.relative_to(ROOT)}:{number}")
        self.assertEqual(found, [], "the old name survives in the sources")

    def test_the_marker_and_the_vault_live_in_the_same_folder(self) -> None:
        # The CLI writes the marker next to the vault it uses; the shell reads
        # it to decide the login rule. Drift between the two disables the rule.
        with (
            tempfile.TemporaryDirectory() as home,
            mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(Path(home) / "config")}),
        ):
            from vitrail import network

            self.assertEqual(network.marker_path(), Path(home) / "config" / "vitrail-vpn" / "enabled")
            self.assertEqual(vpn_manager().ENABLED_FILE, network.marker_path())

    def test_the_installer_points_the_root_helper_at_the_user_folder(self) -> None:
        text = (ROOT / "vpn" / "install.sh").read_text(encoding="utf-8")
        self.assertIn("printf 'VPN_VAULT=%s/.config/vitrail-vpn/vault.db\\n' \"$user_home\"", text)
        self.assertIn("printf 'VPN_CONF_DIR=%s/.config/vitrail-vpn/connections\\n' \"$user_home\"", text)


if __name__ == "__main__":
    unittest.main()
