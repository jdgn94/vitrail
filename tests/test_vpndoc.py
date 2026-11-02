"""The VPN's private storage: one folder per system user, mode 0700, files 0600.

Vitrail keeps its VPN document in ~/.config/vitrail-vpn and the .ovpn files it
owns in ~/.local/share/vitrail-vpn; both follow $HOME, so two system users never
share a document, a credential or a rule. The one-time migration moves the old
`vpnSettings` out of misc.ini.
"""

from __future__ import annotations

import json
import os
import stat
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from vitrail import prefs, vpndoc


def mode(path: Path) -> int:
    return stat.S_IMODE(path.stat().st_mode)


class Home(unittest.TestCase):
    """A temporary $HOME with its own config and data folders."""

    def setUp(self) -> None:
        self.home = tempfile.TemporaryDirectory()
        self.addCleanup(self.home.cleanup)
        self.root = Path(self.home.name)
        self.env = mock.patch.dict(os.environ, {
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "XDG_DATA_HOME": str(self.root / "share"),
        })
        self.env.start()
        self.addCleanup(self.env.stop)

    def config(self) -> Path:
        folder = self.root / "config" / "vitrail"
        folder.mkdir(parents=True, exist_ok=True)
        return folder


class FoldersTests(Home):
    def test_the_folders_are_private(self) -> None:
        vpndoc.migrate(self.config())
        document = vpndoc.write_doc({"connections": {}})
        self.assertEqual(document.parent, self.root / "config" / "vitrail-vpn")
        self.assertEqual(mode(document.parent), 0o700)
        self.assertEqual(mode(document), 0o600)
        self.assertEqual(mode(vpndoc.data_dir()), 0o700)

    def test_an_existing_world_readable_folder_and_file_are_narrowed(self) -> None:
        folder = self.root / "config" / "vitrail-vpn"
        folder.mkdir(parents=True)
        os.chmod(folder, 0o755)
        document = folder / vpndoc.SETTINGS
        document.write_text("[vpn]\n", encoding="utf-8")
        os.chmod(document, 0o644)
        vpndoc.read_doc()
        self.assertEqual((mode(folder), mode(document)), (0o700, 0o600))

    def test_two_system_users_get_two_folders(self) -> None:
        os.environ["XDG_CONFIG_HOME"] = str(self.root / "juan" / "config")
        os.environ["XDG_DATA_HOME"] = str(self.root / "juan" / "share")
        juan = vpndoc.write_doc({"connections": {"us-1": {"auto": False}}})
        os.environ["XDG_CONFIG_HOME"] = str(self.root / "ana" / "config")
        os.environ["XDG_DATA_HOME"] = str(self.root / "ana" / "share")
        ana = vpndoc.write_doc({"connections": {}})
        self.assertNotEqual(juan, ana)
        self.assertEqual(vpndoc.read_doc(), {"connections": {}})

    def test_without_xdg_variables_the_home_is_used(self) -> None:
        os.environ.pop("XDG_CONFIG_HOME")
        os.environ.pop("XDG_DATA_HOME")
        os.environ["HOME"] = str(self.root / "home")
        self.assertEqual(vpndoc.config_dir(), self.root / "home" / ".config" / "vitrail-vpn")
        self.assertEqual(vpndoc.data_dir(), self.root / "home" / ".local" / "share" / "vitrail-vpn")


class DocumentTests(Home):
    def test_the_document_round_trips_as_qsettings_writes_it(self) -> None:
        document = {"connections": {"us-1": {"auto": False}, "us-2": {"auto": False}}}
        vpndoc.write_doc(document)
        self.assertEqual(vpndoc.read_doc(), document)
        text = (vpndoc.config_dir() / vpndoc.SETTINGS).read_text(encoding="utf-8")
        # One key, quoted and escaped: what Qt.labs.settings understands.
        self.assertIn('vpnSettings="{\\"connections\\"', text)

    def test_a_missing_or_broken_document_is_empty(self) -> None:
        self.assertEqual(vpndoc.read_doc(), {})
        vpndoc.write_doc({"connections": {}})
        (vpndoc.config_dir() / vpndoc.SETTINGS).write_text("[vpn]\nvpnSettings=not json\n", encoding="utf-8")
        self.assertEqual(vpndoc.read_doc(), {})

    def test_a_value_qsettings_left_unquoted_is_read_too(self) -> None:
        folder = vpndoc.config_dir()
        folder.mkdir(parents=True)
        (folder / vpndoc.SETTINGS).write_text(
            '[vpn]\nvpnSettings={\\"connections\\":{\\"us-1\\":{\\"auto\\":false}}}\n', encoding="utf-8")
        self.assertEqual(vpndoc.read_doc(), {"connections": {"us-1": {"auto": False}}})


class MigrationTests(Home):
    def legacy(self, text: str) -> Path:
        config = self.config()
        (config / "misc.ini").write_text(f"[misc]\n{text}\n", encoding="utf-8")
        return config

    def test_the_document_moves_out_of_misc_ini_once(self) -> None:
        document = {"connections": {"us-1": {"auto": False}}}
        config = self.legacy("vpnSettings=" + json.dumps(json.dumps(document)))
        self.assertTrue(vpndoc.migrate(config))
        self.assertEqual(vpndoc.read_doc(), document)
        self.assertNotIn("vpnSettings", (config / "misc.ini").read_text(encoding="utf-8"))
        self.assertFalse(vpndoc.migrate(config))

    def test_a_quoted_legacy_value_is_read_as_qsettings_stored_it(self) -> None:
        config = self.legacy('vpnSettings="{\\"connections\\":{\\"us-1\\":{\\"auto\\":false}}}"')
        vpndoc.migrate(config)
        self.assertEqual(vpndoc.read_doc(), {"connections": {"us-1": {"auto": False}}})

    def test_a_broken_legacy_value_still_removes_the_key(self) -> None:
        config = self.legacy("vpnSettings=not json")
        vpndoc.migrate(config)
        self.assertEqual(vpndoc.read_doc(), {})
        self.assertNotIn("vpnSettings", (config / "misc.ini").read_text(encoding="utf-8"))

    def test_an_existing_document_wins_and_the_old_key_still_goes(self) -> None:
        vpndoc.write_doc({"connections": {"new": {"auto": False}}})
        config = self.legacy('vpnSettings={"connections":{"old":{"auto":false}}}')
        vpndoc.migrate(config)
        self.assertEqual(vpndoc.read_doc(), {"connections": {"new": {"auto": False}}})
        self.assertNotIn("vpnSettings", (config / "misc.ini").read_text(encoding="utf-8"))

    def test_migration_without_a_legacy_file_creates_the_private_folder(self) -> None:
        self.assertTrue(vpndoc.migrate(self.config()))
        self.assertEqual(mode(vpndoc.config_dir()), 0o700)
        self.assertEqual(vpndoc.read_doc(), {})

    def test_the_other_keys_of_misc_ini_stay(self) -> None:
        config = self.config()
        (config / "misc.ini").write_text('[misc]\nquickNotes=["a"]\nvpnSettings={"connections":{}}\n',
                                         encoding="utf-8")
        vpndoc.migrate(config)
        self.assertEqual(prefs.read_prefs(config).get("quickNotes"), '["a"]')


class OwnedFilesTests(Home):
    def source(self, name: str = "server.ovpn", text: str = "client\n") -> Path:
        folder = self.root / "picked"
        folder.mkdir(exist_ok=True)
        path = folder / name
        path.write_text(text, encoding="utf-8")
        return path

    def test_a_picked_file_is_copied_into_the_data_folder_privately(self) -> None:
        picked = self.source()
        stored = vpndoc.store_file(picked)
        self.assertEqual(stored.parent, vpndoc.data_dir())
        self.assertEqual(stored.name, "server.ovpn")
        self.assertEqual(stored.read_text(encoding="utf-8"), "client\n")
        self.assertEqual(mode(stored), 0o600)
        self.assertTrue(picked.exists())

    def test_moving_removes_the_original_only_after_the_copy_is_verified(self) -> None:
        picked = self.source()
        stored = vpndoc.store_file(picked, move=True)
        self.assertFalse(picked.exists())
        self.assertEqual(stored.read_text(encoding="utf-8"), "client\n")

    def test_two_files_with_the_same_name_do_not_overwrite_each_other(self) -> None:
        first = vpndoc.store_file(self.source(text="one\n"))
        second = vpndoc.store_file(self.source(text="two\n"))
        self.assertNotEqual(first, second)
        self.assertEqual(first.read_text(encoding="utf-8"), "one\n")
        self.assertEqual(second.read_text(encoding="utf-8"), "two\n")

    def test_the_same_file_again_reuses_its_copy(self) -> None:
        picked = self.source()
        first = vpndoc.store_file(picked)
        self.assertEqual(vpndoc.store_file(picked), first)

    def test_a_name_that_is_not_a_config_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            vpndoc.store_file(self.source("notes.txt"))

    def test_a_missing_file_is_an_error(self) -> None:
        with self.assertRaises(OSError):
            vpndoc.store_file(self.root / "nowhere" / "server.ovpn")

    def test_a_name_with_awkward_characters_is_flattened(self) -> None:
        self.assertEqual(vpndoc.store_file(self.source("a:b c.ovpn")).name, "a_b_c.ovpn")


if __name__ == "__main__":
    unittest.main()
