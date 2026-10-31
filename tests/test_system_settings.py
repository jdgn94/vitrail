"""apply-settings.sh: numlock, time zone, NTP and the system language.

Every command that changes the system is a stub in PATH and VITRAIL_DRY_RUN=1
prints it instead of running it, so nothing here touches the real machine.
"""

from __future__ import annotations

import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

from vitrail import prefs

ROOT = Path(__file__).resolve().parent.parent
APPLY = ROOT / "scripts" / "apply-settings.sh"
HELPER = ROOT / "scripts" / "vitrail-locale-helper.sh"

STUBS = {
    # Reads answer from the environment; any set-* lands in $STUB_LOG.
    "timedatectl": r'''
case "$*" in
    "show -p Timezone --value") echo "${STUB_TZ:-Europe/Madrid}" ;;
    "show -p NTP --value") echo "${STUB_NTP:-yes}" ;;
    *) echo "timedatectl $*" >>"$STUB_LOG" ;;
esac
''',
    "localectl": r'''
case "$1" in
    status) echo "   System Locale: LANG=${STUB_LANG:-en_US.UTF-8}" ;;
    list-locales) printf '%s\n' ${STUB_LOCALES:-C.UTF-8 en_US.UTF-8} ;;
    *) echo "localectl $*" >>"$STUB_LOG" ;;
esac
''',
    "pkexec": 'echo "pkexec $*" >>"$STUB_LOG"',
    "hyprctl": 'echo "hyprctl $*" >>"$STUB_LOG"; echo ok',
    "python3": "exit 0",
    "pkill": "exit 0",
}


def write_executable(path: Path, body: str) -> None:
    path.write_text("#!/bin/bash\n" + body + "\n", encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


class Sandbox(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir, True)
        self.stubs = self.dir / "stubs"
        self.stubs.mkdir()
        for name, body in STUBS.items():
            write_executable(self.stubs / name, body)
        self.log = self.dir / "log"
        self.log.touch()
        self.config = self.dir / "config"
        (self.config / "vitrail").mkdir(parents=True)
        self.helper = self.dir / "locale-helper"
        write_executable(self.helper, "exit 0")

    def settings(self, **values: str) -> None:
        for old in (self.config / "vitrail").glob("*.ini"):
            old.unlink()
        for key, value in values.items():
            prefs.write_pref(self.config / "vitrail", key, value)

    def apply(self, hyprland: bool = False, **env: str) -> str:
        base = {
            "PATH": f"{self.stubs}:/usr/bin:/bin",
            "HOME": str(self.dir),
            "XDG_CONFIG_HOME": str(self.config),
            "XDG_CACHE_HOME": str(self.dir / "cache"),
            "VITRAIL_DRY_RUN": "1",
            "VITRAIL_LOCALE_HELPER": str(self.helper),
            "STUB_LOG": str(self.log),
        }
        if hyprland:
            base["HYPRLAND_INSTANCE_SIGNATURE"] = "test"
        result = subprocess.run(["bash", str(APPLY)], capture_output=True, text=True,
                                env={**base, **env}, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def calls(self) -> str:
        return self.log.read_text(encoding="utf-8")


class NumLockTests(Sandbox):
    def test_numlock_on_is_the_default(self) -> None:
        self.settings()
        self.apply(hyprland=True)
        self.assertIn("numlock_by_default = true", self.calls())

    def test_numlock_off(self) -> None:
        self.settings(numlockOnStart="false")
        out = self.apply(hyprland=True)
        self.assertIn("numlock_by_default = false", self.calls())
        self.assertIn("numlock=false", out)


class TimezoneTests(Sandbox):
    def test_a_different_zone_is_set_through_the_dry_run(self) -> None:
        self.settings(timezone="Europe/Paris", language="en", languageSystem="false")
        out = self.apply()
        self.assertIn("dry-run: timedatectl set-timezone Europe/Paris", out)
        self.assertNotIn("set-timezone", self.calls())

    def test_the_current_zone_changes_nothing(self) -> None:
        self.settings(timezone="Europe/Madrid", languageSystem="false")
        self.assertNotIn("set-timezone", self.apply())

    def test_no_zone_changes_nothing(self) -> None:
        self.settings(languageSystem="false")
        self.assertNotIn("timedatectl", self.apply())

    def test_a_zone_that_is_not_in_tzdata_is_refused(self) -> None:
        for bad in ("../etc/passwd", "Europe/../../etc/passwd", "Nowhere/Land", "/etc/passwd",
                    "Europe/Paris;reboot"):
            with self.subTest(zone=bad):
                self.settings(timezone=bad, languageSystem="false")
                out = self.apply()
                self.assertNotIn("dry-run: timedatectl set-timezone", out)
                self.assertIn("ignored", out)


class NtpTests(Sandbox):
    def test_turning_it_off_when_on(self) -> None:
        self.settings(ntp="false", languageSystem="false")
        self.assertIn("dry-run: timedatectl set-ntp false", self.apply(STUB_NTP="yes"))

    def test_turning_it_on_when_off(self) -> None:
        self.settings(ntp="true", languageSystem="false")
        self.assertIn("dry-run: timedatectl set-ntp true", self.apply(STUB_NTP="no"))

    def test_already_in_that_state(self) -> None:
        self.settings(ntp="true", languageSystem="false")
        self.assertNotIn("set-ntp", self.apply(STUB_NTP="yes"))

    def test_unset_or_unknown_leaves_the_clock_alone(self) -> None:
        for value in ({}, {"ntp": "maybe"}):
            with self.subTest(value=value):
                self.settings(languageSystem="false", **value)
                self.assertNotIn("set-ntp", self.apply())
        self.assertEqual(self.calls(), "")


class LocaleTests(Sandbox):
    def test_a_missing_locale_is_generated_then_set(self) -> None:
        self.settings(language="es")
        out = self.apply()
        lines = [line for line in out.splitlines() if line.startswith("dry-run:")]
        self.assertEqual(lines, [
            f"dry-run: pkexec {self.helper} es_ES.UTF-8",
            "dry-run: localectl set-locale LANG=es_ES.UTF-8",
        ])
        self.assertEqual(self.calls(), "")

    def test_an_available_locale_is_only_set(self) -> None:
        self.settings(language="es")
        out = self.apply(STUB_LOCALES="C.UTF-8 en_US.UTF-8 es_ES.UTF-8")
        self.assertNotIn("pkexec", out)
        self.assertIn("dry-run: localectl set-locale LANG=es_ES.UTF-8", out)

    def test_the_current_system_language_changes_nothing(self) -> None:
        self.settings(language="en")
        self.assertNotIn("dry-run", self.apply())

    def test_the_switch_off_leaves_the_system_alone(self) -> None:
        self.settings(language="es", languageSystem="false")
        self.assertNotIn("dry-run", self.apply())

    def test_the_switch_is_on_by_default(self) -> None:
        self.settings(language="de")
        self.assertIn("localectl set-locale LANG=de_DE.UTF-8", self.apply())

    def test_without_the_installed_helper_nothing_runs_as_root(self) -> None:
        self.settings(language="fr")
        out = self.apply(VITRAIL_LOCALE_HELPER=str(self.dir / "missing"))
        self.assertNotIn("dry-run", out)
        self.assertIn("run ./install.sh", out)

    def test_the_ui_locale_file_is_still_written(self) -> None:
        self.settings(language="it", languageSystem="false")
        self.apply()
        conf = (self.config / "environment.d" / "10-vitrail-locale.conf").read_text()
        self.assertIn("LANG=it_IT.UTF-8", conf)


class StampTests(Sandbox):
    def run_lib(self, script: str, dry: str = "0") -> subprocess.CompletedProcess:
        return subprocess.run(
            ["bash", "-c", f'source "{ROOT}/scripts/lib/system.sh"; {script}'],
            capture_output=True, text=True, timeout=30,
            env={"PATH": f"{self.stubs}:/usr/bin:/bin", "HOME": str(self.dir),
                 "XDG_CACHE_HOME": str(self.dir / "cache"), "VITRAIL_DRY_RUN": dry},
        )

    def test_a_request_is_remembered_and_only_a_new_value_acts_again(self) -> None:
        self.assertEqual(self.run_lib("stamp_differs locale es_ES.UTF-8").returncode, 0)
        self.run_lib("stamp_write locale es_ES.UTF-8")
        self.assertEqual(self.run_lib("stamp_differs locale es_ES.UTF-8").returncode, 1)
        self.assertEqual(self.run_lib("stamp_differs locale de_DE.UTF-8").returncode, 0)

    def test_a_dry_run_leaves_no_stamp(self) -> None:
        self.run_lib("stamp_write locale es_ES.UTF-8", dry="1")
        self.assertFalse((self.dir / "cache").exists())


class LocaleHelperTests(Sandbox):
    """The helper with its three system paths pointed at a sandbox."""

    def setUp(self) -> None:
        super().setUp()
        self.supported = self.dir / "SUPPORTED"
        self.supported.write_text(
            "en_US.UTF-8 UTF-8\nes_ES.UTF-8 UTF-8\nes_ES ISO-8859-1\n",
            encoding="utf-8")
        self.gen = self.dir / "locale.gen"
        self.gen.write_text("#en_US.UTF-8 UTF-8\n#  es_ES.UTF-8 UTF-8\n", encoding="utf-8")
        write_executable(self.dir / "locale-gen", f'echo generated >>"{self.log}"')
        text = HELPER.read_text(encoding="utf-8")
        for old, new in (("/usr/share/i18n/SUPPORTED", self.supported),
                         ("/etc/locale.gen", self.gen),
                         ("/usr/bin/locale-gen", self.dir / "locale-gen")):
            self.assertIn(old, text)
            text = text.replace(old, str(new))
        self.script = self.dir / "helper.sh"
        write_executable(self.script, text.split("\n", 1)[1])

    def run_helper(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(["bash", str(self.script), *args], capture_output=True, text=True)

    def test_enables_a_commented_locale_and_generates(self) -> None:
        result = self.run_helper("es_ES.UTF-8")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.gen.read_text(), "#en_US.UTF-8 UTF-8\nes_ES.UTF-8 UTF-8\n")
        self.assertEqual(self.calls(), "generated\n")

    def test_appends_a_supported_locale_that_is_not_listed(self) -> None:
        self.gen.write_text("", encoding="utf-8")
        self.assertEqual(self.run_helper("en_US.UTF-8").returncode, 0)
        self.assertEqual(self.gen.read_text(), "en_US.UTF-8 UTF-8\n")

    def test_an_enabled_locale_is_not_duplicated(self) -> None:
        self.gen.write_text("es_ES.UTF-8 UTF-8\n", encoding="utf-8")
        self.assertEqual(self.run_helper("es_ES.UTF-8").returncode, 0)
        self.assertEqual(self.gen.read_text(), "es_ES.UTF-8 UTF-8\n")

    def test_rejects_anything_that_is_not_a_supported_utf8_locale(self) -> None:
        before = self.gen.read_text()
        for bad in ("", "xx_YY.UTF-8", "es_ES", "es_ES.UTF-8 UTF-8", "../../etc/passwd",
                    "es_ES.UTF-8\nfoo", "es_ES.UTF-8;rm -rf /", "es_.*", "-n", "ES_es.UTF-8"):
            with self.subTest(locale=bad):
                result = self.run_helper(bad)
                self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.gen.read_text(), before)
        self.assertEqual(self.calls(), "")

    def test_takes_exactly_one_argument(self) -> None:
        self.assertEqual(self.run_helper().returncode, 2)
        self.assertEqual(self.run_helper("es_ES.UTF-8", "en_US.UTF-8").returncode, 2)
        self.assertEqual(self.gen.read_text(), "#en_US.UTF-8 UTF-8\n#  es_ES.UTF-8 UTF-8\n")


if __name__ == "__main__":
    unittest.main()
