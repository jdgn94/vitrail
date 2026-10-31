"""Every bar element declares an informative tooltip (AGENTS.md)."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BAR = ROOT / "bar"
TOOLTIP = ROOT / "kit" / "base" / "VitrailTooltip.qml"
# `tooltip: ...` or `property string tooltip: ...`, with a value.
DECLARES = re.compile(r"(?m)^\s*(?:property\s+string\s+)?tooltip:\s*\S")


# Lay out the elements; each element sets its own tooltip.
CONTAINERS = {"BarItems.qml"}


def bar_sources() -> list[Path]:
    return sorted(p for p in BAR.rglob("*.qml") if not p.is_relative_to(BAR / "kit"))


def clickable_elements() -> list[Path]:
    """Files that define a clickable bar element: a *Button, or anything that
    emits `clicked` (the tray's delegates live in TrayItems)."""
    found = [
        p for p in bar_sources()
        if p.name not in CONTAINERS
        and (p.name.endswith("Button.qml") or re.search(r"signal clicked\(", p.read_text(encoding="utf-8")))
    ]
    return sorted({*found, BAR / "tray" / "TrayItems.qml"})


class BarTooltipTests(unittest.TestCase):
    def test_there_are_bar_buttons_to_check(self) -> None:
        names = {p.name for p in clickable_elements()}
        for expected in ("LauncherButton.qml", "ClockButton.qml", "NetworkButton.qml",
                         "VpnButton.qml", "PowerButton.qml", "TrayItems.qml"):
            self.assertIn(expected, names)

    def test_every_clickable_bar_element_sets_a_tooltip(self) -> None:
        for path in clickable_elements():
            with self.subTest(file=str(path.relative_to(ROOT))):
                self.assertRegex(
                    path.read_text(encoding="utf-8"), DECLARES,
                    "declare `tooltip` (and `tooltipDetail`): every bar element is informative",
                )

    def test_tray_icons_and_chevron_each_have_one(self) -> None:
        text = (BAR / "tray" / "TrayItems.qml").read_text(encoding="utf-8")
        self.assertGreaterEqual(len(DECLARES.findall(text)), 2)


class TooltipPrimitiveTests(unittest.TestCase):
    def test_delay_and_motion_come_from_tokens(self) -> None:
        text = TOOLTIP.read_text(encoding="utf-8")
        self.assertIn('VitrailTokens.duration("tooltip")', text)
        self.assertNotRegex(text, r"duration:\s*\d")
        self.assertNotRegex(text, r"interval:\s*\d")

    def test_it_never_takes_input(self) -> None:
        text = TOOLTIP.read_text(encoding="utf-8")
        for handler in ("MouseArea", "HoverHandler", "TapHandler"):
            self.assertNotIn(handler, text)


if __name__ == "__main__":
    unittest.main()
