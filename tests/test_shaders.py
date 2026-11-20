"""The committed QML shaders are the baked version of their GLSL sources."""

from __future__ import annotations

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHADERS = ROOT / "kit" / "shaders"


def qsb() -> str | None:
    found = shutil.which("qsb")
    if found:
        return found
    local = Path("/usr/lib/qt6/bin/qsb")
    return str(local) if local.is_file() else None


class ShaderTests(unittest.TestCase):
    def test_every_shader_is_baked_from_its_source(self) -> None:
        tool = qsb()
        if tool is None:
            self.skipTest("qsb (qt6-shadertools) is missing")
        sources = sorted(SHADERS.glob("*.frag"))
        self.assertTrue(sources, "no shaders in kit/shaders")
        for source in sources:
            with self.subTest(shader=source.name):
                baked = source.with_name(source.name + ".qsb")
                self.assertTrue(baked.is_file(), f"{baked.name} is missing: run scripts/build-shaders.sh")
                with tempfile.TemporaryDirectory() as tmp:
                    out = Path(tmp) / baked.name
                    subprocess.run(
                        [tool, "--qt6", "-o", str(out), str(source)],
                        check=True,
                        capture_output=True,
                        text=True,
                    )
                    self.assertEqual(
                        out.read_bytes(),
                        baked.read_bytes(),
                        f"{baked.name} is stale: run scripts/build-shaders.sh",
                    )


if __name__ == "__main__":
    unittest.main()
