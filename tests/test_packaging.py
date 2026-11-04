"""The AUR package and the release tarball stay in step with the repository."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PACKAGES = ROOT / "packaging"


def manifest_packages() -> set[str]:
    names: set[str] = set()
    for manifest in ("base.txt", "hyprland.txt", "aur.txt"):
        for line in (ROOT / "packages" / manifest).read_text(encoding="utf-8").splitlines():
            line = line.split("#", 1)[0].strip()
            if line and line != "base-devel":
                names.add(line)
    return names


class PkgbuildTests(unittest.TestCase):
    def pkgbuild(self, name: str) -> str:
        return (PACKAGES / name / "PKGBUILD").read_text(encoding="utf-8")

    def test_both_flavours_install_the_tree_and_the_commands(self) -> None:
        for name in ("vitrail", "vitrail-git"):
            with self.subTest(package=name):
                text = self.pkgbuild(name)
                self.assertIn("/usr/share/vitrail", text)
                self.assertIn('"$pkgdir/usr/bin/vitrail"', text)
                self.assertIn("vitrail-install", text)

    def test_the_package_never_writes_into_the_home(self) -> None:
        for name in ("vitrail", "vitrail-git"):
            with self.subTest(package=name):
                body = self.pkgbuild(name).split("package() {", 1)[1]
                self.assertNotIn("$HOME", body)

    def test_depends_lists_every_manifest_package(self) -> None:
        text = self.pkgbuild("vitrail")
        match = re.search(r"depends=\((.*?)\)", text, re.S)
        self.assertIsNotNone(match)
        declared = set(re.findall(r"'([^']+)'", match.group(1)))
        self.assertEqual(manifest_packages() - declared, set())

    def test_the_install_script_mentions_the_update(self) -> None:
        text = (PACKAGES / "vitrail" / "vitrail.install").read_text(encoding="utf-8")
        self.assertIn("vitrail-install", text)
        self.assertIn("vitrail update", text)


class CommandTests(unittest.TestCase):
    def test_the_two_commands_exist_and_are_executable(self) -> None:
        for name in ("vitrail", "vitrail-install"):
            path = ROOT / "bin" / name
            self.assertTrue(path.is_file(), name)
            self.assertTrue(path.stat().st_mode & 0o111, name)

    def test_the_installer_links_them(self) -> None:
        text = (ROOT / "install.sh").read_text(encoding="utf-8")
        self.assertIn("vitrail vitrail-install", text)


if __name__ == "__main__":
    unittest.main()
