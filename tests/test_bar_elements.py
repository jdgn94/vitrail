"""Tests for the sample bar element's Python module (vitrail/sample.py)."""

from __future__ import annotations

import json
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class SampleModuleTests(unittest.TestCase):
    def setUp(self) -> None:
        # Isolate cache under a temp dir each run.
        import tempfile

        self._tmp = tempfile.TemporaryDirectory()
        self._cache = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _state(self, **kwargs):
        from vitrail.sample import state

        return state(cache=self._cache, **kwargs)

    def test_state_returns_dict(self) -> None:
        result = self._state()
        self.assertIsInstance(result, dict)

    def test_state_has_required_keys(self) -> None:
        result = self._state()
        for key in ("message", "counter", "updated"):
            self.assertIn(key, result)

    def test_counter_increments_after_cache_expires(self) -> None:
        t0 = time.time()
        first = self._state(now=t0)
        # Far future: cache is cold.
        later = self._state(now=t0 + 3600)
        self.assertEqual(later["counter"], first["counter"] + 1)

    def test_counter_stable_within_cache_window(self) -> None:
        t0 = time.time()
        first = self._state(now=t0)
        second = self._state(now=t0 + 10)
        self.assertEqual(first["counter"], second["counter"])

    def test_cache_file_created(self) -> None:
        self._state()
        cache_path = self._cache / "sample.json"
        self.assertTrue(cache_path.exists())

    def test_cache_file_is_valid_json(self) -> None:
        self._state()
        cache_path = self._cache / "sample.json"
        data = json.loads(cache_path.read_text(encoding="utf-8"))
        self.assertIsInstance(data, dict)
        self.assertIn("state", data)

    def test_main_state_subcommand(self) -> None:
        from vitrail.sample import main

        code = main(["state"])
        self.assertEqual(code, 0)

    def test_main_bad_subcommand(self) -> None:
        from vitrail.sample import main

        code = main(["bad"])
        self.assertNotEqual(code, 0)


class SampleFileTests(unittest.TestCase):
    def test_module_file_exists(self) -> None:
        self.assertTrue((ROOT / "vitrail" / "sample.py").exists())

    def test_module_has_state_function(self) -> None:
        from vitrail import sample

        self.assertTrue(callable(sample.state))

    def test_module_has_main_function(self) -> None:
        from vitrail import sample

        self.assertTrue(callable(sample.main))


if __name__ == "__main__":
    unittest.main()
