"""The release script builds from tracked files and never ships wallpapers."""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "release.sh"


class ReleaseTests(unittest.TestCase):
    def test_the_dry_run_answers_with_the_version(self) -> None:
        import shutil
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "scripts").mkdir()
            shutil.copy(SCRIPT, root / "scripts" / "release.sh")
            (root / "pyproject.toml").write_text('[project]\nversion = "9.9.9"\n', encoding="utf-8")
            env = ["git", "-C", str(root)]
            subprocess.run(env + ["init", "-q"], check=True)
            subprocess.run(env + ["add", "."], check=True)
            subprocess.run(
                env + ["-c", "user.email=t@example.com", "-c", "user.name=t", "commit", "-qm", "x"], check=True
            )
            found = subprocess.run(
                ["bash", str(root / "scripts" / "release.sh"), "--dry-run"],
                cwd=root,
                capture_output=True,
                text=True,
                check=False,
            )
        self.assertEqual(found.returncode, 0, found.stderr)
        self.assertIn("vitrail-9.9.9.tar.gz", found.stdout)

    def test_the_archive_is_built_from_tracked_files_only(self) -> None:
        text = SCRIPT.read_text(encoding="utf-8")
        self.assertIn('git -C "$ROOT" archive', text)
        self.assertIn("--untracked-files=no", text)

    def test_the_changelog_exists(self) -> None:
        changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
        self.assertIn("## 1.0.0", changelog)


if __name__ == "__main__":
    unittest.main()
