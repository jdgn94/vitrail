"""Colors from an image: matugen as the engine, glass as our own layer.

matugen handles extraction and tonal math (Material You). This module only
resolves the image, derives the glass layer and writes the theme files that
applications read.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Mapping

SCHEMES = {
    "tonal": "scheme-tonal-spot",
    "content": "scheme-content",
    "expressive": "scheme-expressive",
    "fidelity": "scheme-fidelity",
    "vibrant": "scheme-vibrant",
    "neutral": "scheme-neutral",
    "monochrome": "scheme-monochrome",
    "rainbow": "scheme-rainbow",
    "fruit-salad": "scheme-fruit-salad",
    "smart": "scheme-smart",
}
MODES = ("dark", "light", "smart")
PREFERS = (
    "saturation",
    "less-saturation",
    "darkness",
    "lightness",
    "value",
    "closest-to-fallback",
)

GLASS_ALPHAS = {
    "base": 0.58,
    "raised": 0.66,
    "high": 0.74,
    "border": 0.10,
    "border_strong": 0.18,
    "accent": 0.16,
}
GLASS_BLUR_PX = 28
GLASS_SATURATION = 1.25

MAX_IMAGE_BYTES = 20 * 1024 * 1024
USER_AGENT = "vitrail/0.1"


class ColorExtractionError(Exception):
    """matugen could not extract colors from the image."""


@dataclass
class Theme:
    raw: dict

    @property
    def mode(self) -> str:
        return "dark" if self.raw.get("is_dark_mode") else "light"

    @property
    def colors(self) -> dict[str, str]:
        return {
            role: _flatten(entry, self.mode)
            for role, entry in self.raw["colors"].items()
        }

    @property
    def is_dark(self) -> bool:
        return bool(self.raw.get("is_dark_mode"))


def _flatten(entry: object, mode: str) -> str:
    """matugen 4 returns {dark: {color}, light: {color}} for every role."""
    if isinstance(entry, str):
        return entry
    if isinstance(entry, dict):
        for key in (mode, "default", "dark", "light"):
            value = entry.get(key)
            if isinstance(value, dict) and "color" in value:
                return value["color"]
            if isinstance(value, str):
                return value
    raise ValueError(f"Unexpected color format: {entry!r}")


def cache_dir() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache")
    return Path(base) / "vitrail"


def is_url(source: str) -> bool:
    return source.startswith(("http://", "https://"))


def image_cache_path(url: str, directory: Path) -> Path:
    suffix = Path(urllib.parse.urlparse(url).path).suffix or ".img"
    digest = hashlib.sha256(url.encode("utf-8")).hexdigest()[:16]
    return directory / "wallpapers" / f"{digest}{suffix}"


def fetch_image(
    source: str,
    directory: Path | None = None,
    opener: Callable[..., object] | None = None,
) -> Path:
    """Return a local path: pass the image through or download it from a URL."""
    if not is_url(source):
        path = Path(source).expanduser()
        if not path.is_file():
            raise FileNotFoundError(f"Image not found: {path}")
        return path

    directory = cache_dir() if directory is None else directory
    target = image_cache_path(source, directory)
    if target.is_file():
        return target

    target.parent.mkdir(parents=True, exist_ok=True)
    open_url = urllib.request.urlopen if opener is None else opener
    request = urllib.request.Request(source, headers={"User-Agent": USER_AGENT})
    with open_url(request, timeout=20) as response:
        data = response.read(MAX_IMAGE_BYTES + 1)
    if len(data) > MAX_IMAGE_BYTES:
        raise ValueError(f"Image exceeds {MAX_IMAGE_BYTES // (1024 * 1024)} MB.")
    target.write_bytes(data)
    return target


def build_command(
    image: Path,
    scheme: str = "tonal",
    mode: str = "dark",
    contrast: float = 0.0,
    prefer: str = "saturation",
    seed: str | None = None,
) -> list[str]:
    """matugen from an image, or from a seed colour when one is given."""
    if scheme not in SCHEMES:
        raise ValueError(f"Unknown scheme: {scheme}")
    if mode not in MODES:
        raise ValueError(f"Unknown mode: {mode}")
    if prefer not in PREFERS:
        raise ValueError(f"Unknown preference: {prefer}")
    source = ["color", "hex", seed] if seed else ["image", str(image)]
    return [
        "matugen",
        *source,
        "-t",
        SCHEMES[scheme],
        "-m",
        mode,
        "--contrast",
        f"{contrast:g}",
        "--prefer",
        prefer,
        "-j",
        "hex",
        "-q",
    ]


def generate(
    image: Path,
    scheme: str = "tonal",
    mode: str = "dark",
    contrast: float = 0.0,
    prefer: str = "saturation",
    run: Callable[..., subprocess.CompletedProcess] = subprocess.run,
    seed: str | None = None,
) -> Theme:
    command = build_command(image, scheme, mode, contrast, prefer, seed)
    try:
        result = run(command, capture_output=True, text=True)
    except FileNotFoundError as error:
        raise ColorExtractionError(
            "matugen is missing. Install it with: sudo pacman -S matugen"
        ) from error
    except OSError as error:
        raise ColorExtractionError(str(error)) from error
    if result.returncode != 0:
        detail = (result.stderr or "").strip().splitlines()
        raise ColorExtractionError(detail[-1] if detail else "matugen failed.")
    try:
        return Theme(raw=json.loads(result.stdout))
    except json.JSONDecodeError as error:
        raise ColorExtractionError("matugen did not return valid JSON.") from error


def _rgb(hex_color: str) -> tuple[int, int, int]:
    value = hex_color.lstrip("#")
    if len(value) != 6:
        raise ValueError(f"Unexpected color: {hex_color}")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16))


def rgba(hex_color: str, alpha: float) -> str:
    """CSS form: rgba(18, 20, 24, 0.58)."""
    red, green, blue = _rgb(hex_color)
    return f"rgba({red}, {green}, {blue}, {alpha:.2f})"


def qss_rgba(hex_color: str, alpha: float) -> str:
    """Qt expects #AARRGGBB, not rgba() with a float alpha."""
    value = hex_color.lstrip("#").upper()
    return f"#{round(alpha * 255):02X}{value}"


def glass_tokens(theme: Theme) -> dict[str, str]:
    colors = theme.colors
    return {
        "glass_base": rgba(colors["surface"], GLASS_ALPHAS["base"]),
        "glass_raised": rgba(colors["surface_container"], GLASS_ALPHAS["raised"]),
        "glass_high": rgba(
            colors["surface_container_high"], GLASS_ALPHAS["high"]
        ),
        "border": rgba(colors["on_surface"], GLASS_ALPHAS["border"]),
        "border_strong": rgba(
            colors["on_surface"], GLASS_ALPHAS["border_strong"]
        ),
        "accent": colors["primary"],
        "accent_soft": rgba(colors["primary"], GLASS_ALPHAS["accent"]),
        "text": colors["on_surface"],
        "text_muted": colors["on_surface_variant"],
    }


def render_gtk(theme: Theme, tokens: Mapping[str, str]) -> str:
    colors = theme.colors
    return f"""/* Generated by Vitrail. Do not edit by hand. */
@define-color window_bg_color {tokens["glass_base"]};
@define-color window_fg_color {tokens["text"]};
@define-color view_bg_color {tokens["glass_raised"]};
@define-color view_fg_color {tokens["text"]};
@define-color headerbar_bg_color {tokens["glass_raised"]};
@define-color headerbar_fg_color {tokens["text"]};
@define-color card_bg_color {tokens["glass_high"]};
@define-color accent_bg_color {tokens["accent"]};
@define-color accent_fg_color {colors["on_primary"]};
@define-color accent_color {tokens["accent"]};
@define-color theme_fg_color {tokens["text"]};
@define-color theme_text_color {tokens["text"]};
@define-color borders {tokens["border"]};
@define-color error_color {colors["error"]};
"""


def render_qss(theme: Theme, tokens: Mapping[str, str]) -> str:
    colors = theme.colors
    return f"""/* Generated by Vitrail. Do not edit by hand. */
QWidget {{
    background-color: {qss_rgba(colors["surface"], GLASS_ALPHAS["base"])};
    color: {colors["on_surface"]};
}}
QToolTip, QMenu {{
    background-color: {qss_rgba(colors["surface_container_high"], GLASS_ALPHAS["high"])};
    color: {colors["on_surface"]};
    border: 1px solid {qss_rgba(colors["on_surface"], GLASS_ALPHAS["border"])};
}}
QPushButton {{
    background-color: {qss_rgba(colors["primary"], GLASS_ALPHAS["accent"])};
    color: {colors["primary"]};
    border: 1px solid {qss_rgba(colors["primary"], GLASS_ALPHAS["border_strong"])};
    border-radius: 10px;
    padding: 6px 14px;
}}
QPushButton:hover {{
    background-color: {qss_rgba(colors["primary"], GLASS_ALPHAS["high"] - 0.1)};
}}
"""


def render_qml(theme: Theme, tokens: Mapping[str, str]) -> str:
    colors = theme.colors
    lines = "\n".join(
        f'    readonly property color {role}: "{value}"'
        for role, value in sorted(colors.items())
    )
    return f"""// Generated by Vitrail. Do not edit by hand.
pragma Singleton
import QtQuick

QtObject {{
{lines}

    // Glass layer: apply it with Qt.alpha(Theme.surface, Theme.glassAlpha)
    readonly property bool isDark: {"true" if theme.is_dark else "false"}
    readonly property real glassAlpha: {GLASS_ALPHAS["base"]}
    readonly property real glassAlphaRaised: {GLASS_ALPHAS["raised"]}
    readonly property real glassAlphaHigh: {GLASS_ALPHAS["high"]}
    readonly property real borderAlpha: {GLASS_ALPHAS["border"]}
    readonly property int blurRadius: {GLASS_BLUR_PX}
    readonly property real glassSaturation: {GLASS_SATURATION}
}}
"""


def render_hypr(theme: Theme, tokens: Mapping[str, str]) -> str:
    colors = theme.colors
    return f"""# Generated by Vitrail. Do not edit by hand.
$vitrail_glass = rgba({colors["surface"].lstrip("#")}{round(GLASS_ALPHAS["base"] * 255):02x})
$vitrail_accent = rgb({colors["primary"].lstrip("#")})
$vitrail_text = rgb({tokens["text"].lstrip("#")})
$vitrail_border = rgba({colors["on_surface"].lstrip("#")}{round(GLASS_ALPHAS["border"] * 255):02x})
"""


def render_kitty(theme: Theme, tokens: Mapping[str, str]) -> str:
    base16 = theme.raw.get("base16", {})

    def base(key: str) -> str:
        entry = base16.get(key, {})
        chosen = entry.get("default") or entry.get("dark") or {}
        return chosen.get("color", "#000000")

    lines = [
        "# Generated by Vitrail. Do not edit by hand.",
        f"background {base('base00')}",
        f"foreground {base('base05')}",
        f"selection_background {base('base02')}",
        f"selection_foreground {base('base05')}",
        f"cursor {tokens['accent']}",
    ]
    lines += [f"color{i} {base(f'base{i:02x}')}" for i in range(16)]
    return "\n".join(lines) + "\n"


RENDERERS = {
    "gtk-3.0/gtk.css": render_gtk,
    "gtk-4.0/gtk.css": render_gtk,
    "qt/vitrail.qss": render_qss,
    "qml/VitrailTheme.qml": render_qml,
    "hypr/colors.conf": render_hypr,
    "terminal/kitty.conf": render_kitty,
}


def summary(theme: Theme) -> dict:
    """Stable payload consumed by the Qt app."""
    return {
        "colors": theme.colors,
        "glass": glass_tokens(theme),
        "is_dark": theme.is_dark,
    }


def write_summary(theme: Theme, path: Path) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(summary(theme), indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return path


def write_outputs(theme: Theme, out_dir: Path) -> list[Path]:
    tokens = glass_tokens(theme)
    written: list[Path] = []
    for relative, render in RENDERERS.items():
        path = out_dir / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(render(theme, tokens), encoding="utf-8")
        written.append(path)

    written.append(write_summary(theme, out_dir / "theme.json"))
    raw = out_dir / "colors.json"
    raw.write_text(
        json.dumps(theme.raw, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    written.append(raw)
    return written


def reload_commands(
    environ: Mapping[str, str] | None = None,
    which: Callable[[str], str | None] | None = None,
) -> list[list[str]]:
    environ = os.environ if environ is None else environ
    which = shutil.which if which is None else which
    commands: list[list[str]] = []
    if environ.get("HYPRLAND_INSTANCE_SIGNATURE") and which("hyprctl"):
        commands.append(["hyprctl", "reload"])
    return commands


def write_theme(
    image: Path,
    out_dir: Path,
    scheme: str = "tonal",
    mode: str = "dark",
    contrast: float = 0.0,
    prefer: str = "saturation",
    seed: str | None = None,
    run: Callable[..., subprocess.CompletedProcess] = subprocess.run,
) -> tuple[Theme, list[Path]]:
    """Every theme file for one source, in `mode`, plus both modes' summaries
    and terminal palettes, so light and dark can switch without extracting."""
    theme = generate(image, scheme, mode, contrast, prefer, run, seed)
    written = write_outputs(theme, out_dir)
    for variant_mode in ("dark", "light"):
        variant = generate(image, scheme, variant_mode, contrast, prefer, run, seed)
        written.append(write_summary(variant, out_dir / f"theme-{variant_mode}.json"))
        kitty = out_dir / "terminal" / f"kitty-{variant_mode}.conf"
        kitty.parent.mkdir(parents=True, exist_ok=True)
        kitty.write_text(render_kitty(variant, glass_tokens(variant)), encoding="utf-8")
        written.append(kitty)
    return theme, written
