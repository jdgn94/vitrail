"""The VPN outlives the shell.

vitrail-vpn raises the tunnel as a system unit
(`vitrail-vpn@<id>.service`); Vitrail commands it and never owns the
process, so stopping or restarting the bar leaves the connection alone. What
must not depend on the shell is the login rule: a user unit runs
`vitrail-network autostart` at every login, so the tunnel comes up even when
Quickshell was never started.
"""

from __future__ import annotations

import stat
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UNIT = ROOT / "dots" / ".config" / "systemd" / "user" / "vitrail-vpn-autostart.service"
LAUNCHER = ROOT / "bin" / "vitrail-network"
INSTALL = ROOT / "install.sh"


class LoginRuleTests(unittest.TestCase):
    def test_the_login_rule_is_a_user_unit(self) -> None:
        self.assertTrue(UNIT.is_file(), "the VPN login rule has no user unit")
        text = UNIT.read_text(encoding="utf-8")
        self.assertRegex(text, r"(?m)^ExecStart=%h/\.local/bin/vitrail-network autostart$")
        self.assertRegex(text, r"(?m)^WantedBy=default\.target$")

    def test_the_launcher_runs_the_helper_with_the_repo_on_the_path(self) -> None:
        self.assertTrue(LAUNCHER.is_file(), "vitrail-network is not installable")
        self.assertTrue(LAUNCHER.stat().st_mode & stat.S_IXUSR)
        text = LAUNCHER.read_text(encoding="utf-8")
        self.assertIn('exec python3 -m vitrail.network "$@"', text)

    def test_the_installer_links_the_launcher_and_enables_the_unit(self) -> None:
        text = INSTALL.read_text(encoding="utf-8")
        self.assertRegex(text, r"for name in [^\n]*\bvitrail-network\b")
        self.assertIn("systemctl --user enable vitrail-vpn-autostart.service", text)
        self.assertIn("enable_vpn_autostart", text)

    def test_the_login_rule_is_only_enabled_when_the_vpn_is_installed(self) -> None:
        text = INSTALL.read_text(encoding="utf-8")
        body = text.split("enable_vpn_autostart() {", 1)
        self.assertEqual(len(body), 2, "the installer has no enable_vpn_autostart")
        function = body[1].split("\n}\n", 1)[0]
        self.assertIn('"none"', function)

    def test_the_shell_does_not_run_the_login_rule(self) -> None:
        # One caller, the unit: a bar restart must never repeat (or undo) what a
        # login did, and a login without the bar must still connect.
        for path in (ROOT / "bar").rglob("*.qml"):
            self.assertNotIn('"autostart"', path.read_text(encoding="utf-8"), str(path))

    def test_the_shell_never_starts_the_tunnel_itself(self) -> None:
        for folder in ("bar", "shell"):
            for path in (ROOT / folder).rglob("*"):
                if path.suffix in (".qml", ".js"):
                    text = path.read_text(encoding="utf-8")
                    self.assertFalse('"openvpn"' in text, f"{path} runs the tunnel itself")


if __name__ == "__main__":
    unittest.main()
