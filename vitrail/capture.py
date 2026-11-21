"""Screenshots and screen recording through grim, magick and wf-recorder.

The overlay's backend: freeze the screen once, then compose what the user
selected from those images, or record it. No helper daemon:

    python3 -m vitrail.capture freeze
    python3 -m vitrail.capture grab --geometry X,Y,W,H [--copy|--save]
    python3 -m vitrail.capture ocr --geometry X,Y,W,H
    python3 -m vitrail.capture ask --geometry X,Y,W,H --text "question"
    python3 -m vitrail.capture detect --geometry X,Y,W,H
    python3 -m vitrail.capture qr --geometry X,Y,W,H
    python3 -m vitrail.capture palette --geometry X,Y,W,H
    python3 -m vitrail.capture translate --geometry X,Y,W,H
    python3 -m vitrail.capture pin --geometry X,Y,W,H
    python3 -m vitrail.capture edit --geometry X,Y,W,H
    python3 -m vitrail.capture finish <edited.png> --save|--copy [--size WxH]
    python3 -m vitrail.capture open <link>
    python3 -m vitrail.capture record start|stop|toggle [--geometry WxH+X+Y]
    python3 -m vitrail.capture window <x> <y>
    python3 -m vitrail.capture status

The bar calls these; the recording state lives in
`$XDG_RUNTIME_DIR/vitrail/record.json`, which the bar watches to light its
indicator and to offer "stop". The `PRINT` key asks the bar to open the
overlay; there is no slurp path any more.
"""

from __future__ import annotations

import base64
import html
import json
import os
import re
import shutil
import signal
import struct
import subprocess
import sys
import time
from pathlib import Path
from typing import Callable
from urllib.parse import urlencode
from xml.etree import ElementTree

Runner = Callable[[list[str]], str | None]
Spawner = Callable[..., int]

STAMP = "%Y-%m-%d_%H-%M-%S"


def log(message: str) -> None:
    print(f"vitrail-capture: {message}", file=sys.stderr, flush=True)


def run_text(argv: list[str]) -> str | None:
    try:
        found = subprocess.run(argv, capture_output=True, text=True, check=False)
    except OSError:
        return None
    return found.stdout if found.returncode == 0 else None


def run_bytes(argv: list[str], data: bytes) -> bool:
    """Feeds `data` to a command; its output is discarded, not piped back.

    `wl-copy` forks to keep the selection and the child inherits the pipes, so
    capturing them would wait for it until something else takes the clipboard.
    """
    try:
        found = subprocess.run(argv, input=data, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    except OSError:
        return False
    return found.returncode == 0


def spawn(argv: list[str], log_path: Path) -> int:
    """Starts a detached process and returns its pid."""
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with open(log_path, "ab") as log_file:
        process = subprocess.Popen(
            argv, stdout=log_file, stderr=log_file, stdin=subprocess.DEVNULL, start_new_session=True
        )
    return process.pid


def runtime_dir() -> Path:
    base = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
    return Path(base) / "vitrail"


def status_file(runtime: Path | None = None) -> Path:
    return (runtime or runtime_dir()) / "record.json"


def pictures() -> str:
    return str(Path.home() / "Pictures" / "Screenshots")


def videos() -> str:
    return str(Path.home() / "Videos" / "Recordings")


# --- the frozen screen -------------------------------------------------------

# Where the overlay's images live inside the runtime folder, and the name grim
# gives each one.
FREEZE = "capture"


def monitors(run: Runner = run_text) -> list[dict]:
    """The layout from Hyprland: one entry per output, in its own order."""
    answer = run(["hyprctl", "monitors", "-j"])
    try:
        document = json.loads(answer or "")
    except (TypeError, ValueError):
        return []
    if not isinstance(document, list):
        return []
    found: list[dict] = []
    for one in document:
        try:
            found.append(
                {
                    "name": str(one["name"]),
                    "x": int(one["x"]),
                    "y": int(one["y"]),
                    "scale": float(one.get("scale") or 1.0),
                    "width": int(one["width"]),
                    "height": int(one["height"]),
                }
            )
        except (KeyError, TypeError, ValueError):
            continue
    return found


def bounds_of(monitors: list[dict]) -> dict:
    """The rectangle that contains every monitor, in layout coordinates."""
    left = min(one["x"] for one in monitors)
    top = min(one["y"] for one in monitors)
    right = max(one["x"] + one["width"] for one in monitors)
    bottom = max(one["y"] + one["height"] for one in monitors)
    return {"x": left, "y": top, "w": right - left, "h": bottom - top}


def _rect(selection: dict) -> dict:
    """The selection as a positive rectangle: a reversed drag is a drag."""
    x = int(selection.get("x") or 0)
    y = int(selection.get("y") or 0)
    width = int(selection.get("w") or 0)
    height = int(selection.get("h") or 0)
    if width < 0:
        x, width = x + width, -width
    if height < 0:
        y, height = y + height, -height
    return {"x": x, "y": y, "w": width, "h": height}


def _clamp(rect: dict, bounds: dict) -> dict:
    left = max(rect["x"], bounds["x"])
    top = max(rect["y"], bounds["y"])
    right = min(rect["x"] + rect["w"], bounds["x"] + bounds["w"])
    bottom = min(rect["y"] + rect["h"], bounds["y"] + bounds["h"])
    return {"x": left, "y": top, "w": max(0, right - left), "h": max(0, bottom - top)}


def _holds(rect: dict, x: float, y: float) -> bool:
    return (
        rect["w"] > 0
        and rect["h"] > 0
        and rect["x"] <= x < rect["x"] + rect["w"]
        and rect["y"] <= y < rect["y"] + rect["h"]
    )


def _monitor_rect(one: dict) -> dict:
    return {"x": one["x"], "y": one["y"], "w": one["width"], "h": one["height"]}


def crop_pieces(selection: dict, monitors: list[dict]) -> tuple[dict, list[dict]]:
    """The canvas and the pieces of the frozen images that fill it.

    Coordinates are physical pixels: each piece is cropped at its own monitor's
    scale, and laid on the canvas at the scale of the monitor the selection
    starts on (what GNOME does when a selection crosses differently scaled
    outputs). Raises ValueError for an empty selection.
    """
    if not monitors:
        raise ValueError("no monitors")
    rect = _clamp(_rect(selection), bounds_of(monitors))
    if rect["w"] <= 0 or rect["h"] <= 0:
        raise ValueError("empty selection")
    reference = next(
        (
            float(one.get("scale") or 1.0)
            for one in monitors
            if _holds(_monitor_rect(one), rect["x"] + 0.5, rect["y"] + 0.5)
        ),
        None,
    )
    pieces: list[dict] = []
    for one in monitors:
        hit = _clamp(rect, _monitor_rect(one))
        if hit["w"] <= 0 or hit["h"] <= 0:
            continue
        if reference is None:
            reference = float(one.get("scale") or 1.0)
        scale = float(one.get("scale") or 1.0)
        if not one.get("image"):
            raise ValueError("the screen is not frozen")
        pieces.append(
            {
                "image": one["image"],
                "crop": [
                    round((hit["x"] - one["x"]) * scale),
                    round((hit["y"] - one["y"]) * scale),
                    round(hit["w"] * scale),
                    round(hit["h"] * scale),
                ],
                "offset": [
                    round((hit["x"] - rect["x"]) * reference),
                    round((hit["y"] - rect["y"]) * reference),
                ],
            }
        )
    if reference is None:
        raise ValueError("empty selection")
    canvas = {"w": max(1, round(rect["w"] * reference)), "h": max(1, round(rect["h"] * reference))}
    return canvas, pieces


def compose(
    selection: dict,
    monitors: list[dict],
    runtime: Path | None = None,
    run: Runner = run_text,
    name: str = "selection",
) -> dict:
    """Composes the selection from the frozen images: {"image", "w", "h"} or {"error"}.

    `name` is the file in the capture folder: background work (detection,
    translation) composes into its own so it never races an action.
    """
    if shutil.which("magick") is None:
        return {"error": "imagemagick is missing"}
    try:
        canvas, pieces = crop_pieces(selection, monitors)
    except ValueError as problem:
        return {"error": "the screen is not frozen" if "frozen" in str(problem) else "empty selection"}
    folder = (runtime or runtime_dir()) / FREEZE
    folder.mkdir(parents=True, exist_ok=True)
    composed = folder / f"{name}.png"
    command = ["magick", "-size", f"{canvas['w']}x{canvas['h']}", "xc:none"]
    for piece in pieces:
        x, y, width, height = piece["crop"]
        offset_x, offset_y = piece["offset"]
        command += [
            "(",
            piece["image"],
            "-crop",
            f"{width}x{height}+{x}+{y}",
            "+repage",
            ")",
            "-geometry",
            f"+{offset_x}+{offset_y}",
            "-composite",
        ]
    command.append(str(composed))
    if run(command) is None:
        return {"error": "magick failed"}
    return {"image": str(composed), "w": canvas["w"], "h": canvas["h"]}


def grab(
    selection: dict,
    monitors: list[dict],
    runtime: Path | None = None,
    directory: str | None = None,
    copy: bool = False,
    run: Runner = run_text,
    copy_run=run_bytes,
    now: float | None = None,
) -> dict:
    """Composes the selection from the frozen images; {"copied"/"path"} or {"error"}."""
    composed = compose(selection, monitors, runtime, run)
    if "error" in composed:
        return composed
    image = Path(composed["image"])
    result: dict = {}
    if directory:
        path = target(directory, now)
        try:
            shutil.copyfile(image, path)
        except OSError:
            return {"error": "the screenshot could not be written"}
        result["path"] = str(path)
    if copy:
        try:
            copied = copy_run(["wl-copy"], image.read_bytes())
        except OSError:
            copied = False
        if not copied:
            log("the screenshot was composed but not copied")
        result["copied"] = bool(copied)
    return result


def pointer(run: Runner = run_text) -> dict | None:
    """Where the cursor is, in layout coordinates (the overlay's start monitor)."""
    answer = (run(["hyprctl", "cursorpos"]) or "").strip()
    try:
        x, y = (int(part) for part in answer.split(","))
    except (TypeError, ValueError):
        return None
    return {"x": x, "y": y}


def freeze(runtime: Path | None = None, run: Runner = run_text) -> dict:
    """One PNG per monitor, taken before the overlay shows anything.

    The selection is composed from these images, so what the overlay shows is
    exactly what gets saved even if the screen changes behind it.
    """
    screens = monitors(run)
    if not screens:
        return {"error": "no monitors"}
    folder = (runtime or runtime_dir()) / FREEZE
    shutil.rmtree(folder, ignore_errors=True)
    folder.mkdir(parents=True, exist_ok=True)
    for one in screens:
        image = folder / f"frozen-{one['name']}.png"
        if run(["grim", "-o", one["name"], str(image)]) is None:
            return {"error": "grim failed"}
        one["image"] = str(image)
    document = {"monitors": screens, "bounds": bounds_of(screens), "pointer": pointer(run)}
    frozen_path(runtime).write_text(json.dumps(document, separators=(",", ":")), encoding="utf-8")
    return document


def frozen_path(runtime: Path | None = None) -> Path:
    return (runtime or runtime_dir()) / FREEZE / "frozen.json"


def read_frozen(runtime: Path | None = None) -> dict:
    """The document `freeze` left, so `grab` keeps the images it must crop."""
    try:
        document = json.loads(frozen_path(runtime).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return document if isinstance(document, dict) else {}


# --- screenshots -------------------------------------------------------------


def target(directory: str, now: float | None = None, suffix: str = "png") -> Path:
    folder = Path(directory).expanduser()
    folder.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime(STAMP, time.localtime(now))
    return folder / f"Screenshot_{stamp}.{suffix}"


GEOMETRY = re.compile(
    r"^\s*(?:(?P<w>\d+)x(?P<h>\d+)\+(?P<x>-?\d+)\+(?P<y>-?\d+)"
    r"|(?P<x2>-?\d+),(?P<y2>-?\d+),(?P<w2>\d+),(?P<h2>\d+))\s*$"
)


def parse_geometry(text: str) -> dict:
    """A rectangle from `WxH+X+Y` (grim, wf-recorder) or `X,Y,W,H` (our own)."""
    match = GEOMETRY.match(text or "")
    if not match:
        raise ValueError(f"not a geometry: {text!r}")
    groups = match.groupdict()
    if groups["w"] is not None:
        return {"x": int(groups["x"]), "y": int(groups["y"]), "w": int(groups["w"]), "h": int(groups["h"])}
    return {"x": int(groups["x2"]), "y": int(groups["y2"]), "w": int(groups["w2"]), "h": int(groups["h2"])}


def geometry_text(rect: dict) -> str:
    """The `-g` form of a rectangle."""
    return f"{int(rect['w'])}x{int(rect['h'])}+{int(rect['x'])}+{int(rect['y'])}"


def window_at(x: float, y: float, run: Runner = run_text) -> dict | None:
    """The topmost visible window under a layout point, as a rectangle."""
    answer = run(["hyprctl", "clients", "-j"])
    try:
        clients = json.loads(answer or "")
    except (TypeError, ValueError):
        return None
    if not isinstance(clients, list):
        return None
    best: dict | None = None
    best_focus = None
    for one in clients:
        if not isinstance(one, dict) or one.get("hidden") or one.get("mapped") is False:
            continue
        try:
            left, top = (int(value) for value in one["at"])
            width, height = (int(value) for value in one["size"])
        except (KeyError, TypeError, ValueError):
            continue
        if width <= 0 or height <= 0:
            continue
        if not (left <= x < left + width and top <= y < top + height):
            continue
        focus = one.get("focusHistoryID")
        focus = focus if isinstance(focus, int) else 1 << 30
        if best is None or focus < best_focus:
            best, best_focus = {"x": left, "y": top, "w": width, "h": height}, focus
    return best


def wf_geometry(geometry: str, monitors: list[dict] | None = None) -> str:
    """The `-g` form wf-recorder takes (`x,y wxh`), from `WxH+X+Y` or `X,Y,W,H`.

    wf-recorder records one output: an area that crosses a monitor is cut to
    the part on the monitor it starts on, and its log says so otherwise.
    """
    rect = _rect(parse_geometry(geometry))
    if monitors:
        start = next(
            (one for one in monitors if _holds(_monitor_rect(one), rect["x"] + 0.5, rect["y"] + 0.5)),
            None,
        )
        if start is not None:
            rect = _clamp(rect, _monitor_rect(start))
            if rect["w"] <= 0 or rect["h"] <= 0:
                raise ValueError("empty selection")
    return f"{rect['x']},{rect['y']} {rect['w']}x{rect['h']}"


# --- text from a picture -----------------------------------------------------

# The settings' language (ISO 639-1) -> the traineddata tesseract names it by.
OCR_NAMES = {"en": "eng", "es": "spa", "de": "deu", "fr": "fra", "it": "ita", "pt": "por"}


def installed_languages(run: Runner = run_text) -> list[str]:
    """The traineddata tesseract can load (its `osd` helper is not a language)."""
    answer = run(["tesseract", "--list-langs"]) or ""
    names = [line.strip() for line in answer.splitlines()[1:]]
    return [name for name in names if name and name != "osd"]


def default_languages(language: str) -> str:
    """The system language and English, as tesseract writes them (`spa+eng`)."""
    code = OCR_NAMES.get(re.split(r"[_.@-]", (language or "").lower())[0], "eng")
    return code if code == "eng" else f"{code}+eng"


def wanted_languages(values: dict) -> str:
    """`ocrLanguages` when set, else the system language plus English."""
    return str(values.get("ocrLanguages") or "").strip() or default_languages(str(values.get("language") or ""))


def pick_languages(wanted: str, installed: list[str]) -> str:
    """The wanted languages that are installed, in the wanted order.

    None of them installed: English, else whatever is (a reading in the wrong
    language beats none); "" when nothing is, and tesseract's default stands.
    """
    chosen: list[str] = []
    for name in re.split(r"[+,\s]+", wanted or ""):
        if name in installed and name not in chosen:
            chosen.append(name)
    if not chosen and installed:
        chosen = ["eng" if "eng" in installed else installed[0]]
    return "+".join(chosen)


def clean_text(raw: str) -> str:
    """What tesseract printed, without its form feeds, trailing blanks and blank runs."""
    lines = [line.rstrip() for line in raw.replace("\r", "").replace("\x0c", "").split("\n")]
    return re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip()


def preview(text: str, limit: int = 160) -> str:
    """One short line of the text for a notification, escaped for its markup."""
    line = " ".join(text.split())
    if len(line) > limit:
        line = line[:limit].rstrip() + "…"
    return html.escape(line, quote=False)


def ocr_scale(width: int, height: int) -> int:
    """How much to enlarge the area: screen text is small for tesseract."""
    area = width * height
    return 3 if area < 100_000 else 2 if area < 2_000_000 else 1


def ocr_psm(width: int, height: int) -> int:
    """Page segmentation: a line for a thin strip, a uniform block otherwise."""
    return 7 if height <= 48 else 6


def ocr_image(composed: dict, wanted: str, run: Runner = run_text) -> dict:
    """Reads a composed image with tesseract (local only): {"text", "languages"} or {"error"}."""
    languages = pick_languages(wanted, installed_languages(run))
    image = Path(composed["image"])
    source = image.with_name(f"{image.stem}-ocr.png")
    scale = ocr_scale(composed["w"], composed["h"])
    prepare = ["magick", composed["image"], "-background", "white", "-alpha", "remove", "-colorspace", "Gray"]
    prepare += ["-resize", f"{scale * 100}%"] if scale > 1 else []
    if run(prepare + [str(source)]) is None:
        return {"error": "magick failed"}
    command = ["tesseract", str(source), "stdout", "--psm", str(ocr_psm(composed["w"], composed["h"]))]
    raw = run(command + (["-l", languages] if languages else []))
    source.unlink(missing_ok=True)
    if raw is None:
        return {"error": "tesseract failed"}
    return {"text": clean_text(raw), "languages": languages}


def read_text(
    selection: dict,
    monitors: list[dict],
    wanted: str,
    runtime: Path | None = None,
    run: Runner = run_text,
    copy_run=run_bytes,
) -> dict:
    """Reads the selection with tesseract (local only) and copies the text.

    {"text", "preview", "copied", "languages"}; `text` is "" when nothing was
    found, and {"error"} when the area or the tools failed.
    """
    if shutil.which("tesseract") is None:
        return {"error": "tesseract is missing"}
    composed = compose(selection, monitors, runtime, run)
    if "error" in composed:
        return composed
    read = ocr_image(composed, wanted, run)
    if "error" in read:
        return read
    text = read["text"]
    if not text:
        return {"text": "", "languages": read["languages"]}
    try:
        copied = copy_run(["wl-copy"], text.encode("utf-8"))
    except OSError:
        copied = False
    if not copied:
        log("the text was read but not copied")
    return {"text": text, "preview": preview(text), "copied": bool(copied), "languages": read["languages"]}


def has_text(text: str) -> bool:
    """Whether a reading is text and not the specks tesseract finds in a picture."""
    return len(re.findall(r"\w", text or "")) >= 3


# --- codes ---------------------------------------------------------------------


def parse_codes(xml: str) -> list[dict]:
    """The symbols of `zbarimg --xml`: [{"type", "data"}] in reading order."""
    try:
        root = ElementTree.fromstring(xml)
    except ElementTree.ParseError:
        return []
    found: list[dict] = []
    for symbol in root.iter():
        if not symbol.tag.endswith("symbol"):
            continue
        data = next((child.text or "" for child in symbol if child.tag.endswith("data")), "")
        found.append({"type": symbol.get("type", ""), "data": data})
    return found


def scan_codes(image: str, run: Runner = run_text) -> list[dict]:
    """QR and bar codes in the image (zbar, local); none when zbar finds nothing."""
    return parse_codes(run(["zbarimg", "--quiet", "--xml", image]) or "")


def is_url(text: str) -> bool:
    """A single http(s) link: the only thing the overlay offers to open."""
    return re.fullmatch(r"https?://[^\s]+", text or "") is not None


def open_link(url: str, log_path: Path, spawner: Spawner = spawn) -> dict:
    """Opens a web link with the desktop's handler; anything else is refused."""
    if not is_url(url):
        return {"error": "not a web link"}
    if shutil.which("xdg-open") is None:
        return {"error": "xdg-open is missing"}
    spawner(["xdg-open", url], log_path)
    return {"opened": True}


def read_codes(
    selection: dict,
    monitors: list[dict],
    runtime: Path | None = None,
    run: Runner = run_text,
    copy_run=run_bytes,
) -> dict:
    """The codes in the selection; the first one's content is copied.

    {"codes": [{"type", "data"}], "copied", "url"}: `url` is the first code when
    it is a web link ("" otherwise), so the overlay can offer to open it.
    """
    composed = compose(selection, monitors, runtime, run, name="qr")
    if "error" in composed:
        return composed
    codes = scan_codes(composed["image"], run)
    if not codes:
        return {"codes": [], "copied": False, "url": ""}
    first = codes[0]["data"]
    try:
        copied = copy_run(["wl-copy"], first.encode("utf-8"))
    except OSError:
        copied = False
    if not copied:
        log("the code was read but not copied")
    return {"codes": codes, "copied": bool(copied), "url": first if is_url(first) else ""}


def detect(
    selection: dict,
    monitors: list[dict],
    wanted: str,
    runtime: Path | None = None,
    run: Runner = run_text,
) -> dict:
    """What the selection holds, for the overlay's buttons: {"text": bool, "codes": n}.

    Local, no clipboard, and in a file of its own. The reading is the same as
    the Copy text action's, so a button enabled here finds the text there.
    """
    composed = compose(selection, monitors, runtime, run, name="detect")
    if "error" in composed:
        return composed
    read = ocr_image(composed, wanted, run)
    text = "text" in read and has_text(read["text"])
    return {"text": text, "codes": len(scan_codes(composed["image"], run))}


# --- translate -----------------------------------------------------------------

TRANSLATE_WAIT = 20
TARGET = re.compile(r"[A-Za-z]{2,3}(?:-[A-Za-z]{2,4})?")


def run_limited(argv: list[str]) -> str | None:
    """`run_text` that gives up after `TRANSLATE_WAIT` seconds (a network call)."""
    try:
        found = subprocess.run(argv, capture_output=True, text=True, check=False, timeout=TRANSLATE_WAIT)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return found.stdout if found.returncode == 0 else None


def target_language(values: dict) -> str:
    """`translateTarget`, else the system language, else English (a language code only)."""
    for key in ("translateTarget", "language"):
        value = str(values.get(key) or "").strip()
        if TARGET.fullmatch(value):
            return value
    return "en"


def translate(
    selection: dict,
    monitors: list[dict],
    target: str,
    wanted: str,
    runtime: Path | None = None,
    run: Runner = run_text,
) -> dict:
    """Reads the area and translates it with translate-shell (online, Google).

    {"source", "text"} or {"error"}. The text goes to `trans` in a private file,
    not on its command line.
    """
    if shutil.which("trans") is None:
        return {"error": "translate-shell is missing"}
    composed = compose(selection, monitors, runtime, run, name="translate")
    if "error" in composed:
        return composed
    read = ocr_image(composed, wanted, run)
    if "error" in read:
        return read
    if not has_text(read["text"]):
        return {"error": "no text"}
    path = Path(composed["image"]).with_name("translate.txt")
    try:
        _private_file(path, read["text"].encode("utf-8"))
        answer = run(["trans", "-b", f":{target}", "-i", str(path)])
    except OSError:
        return {"error": "translation failed"}
    finally:
        path.unlink(missing_ok=True)
    text = clean_text(answer or "")
    if not text:
        return {"error": "translation failed"}
    return {"source": read["text"], "text": text}


# --- palette -------------------------------------------------------------------

# The colours of the area, local: the area is shrunk (box average), quantized
# to PALETTE_QUANTIZE colours without dithering and counted by ImageMagick; the
# ranking and the merging of near-duplicates are here. `capturePaletteSize` is
# the number of colours, between PALETTE_MIN and PALETTE_MAX (the settings
# slider's range, `ranges.capturePalette` in kit/tokens.js).
PALETTE_MIN = 3
PALETTE_MAX = 10
PALETTE_DEFAULT = 6
PALETTE_QUANTIZE = 24
PALETTE_SAMPLE = "128x128>"
# Two colours closer than this in OKLab are one colour (a shade of it), and a
# colour under this share of the pixels is noise.
PALETTE_MERGE = 0.07
PALETTE_FLOOR = 0.02
HISTOGRAM_LINE = re.compile(r"^\s*(\d+):\s*\([^)]*\)\s*(#[0-9A-Fa-f]{6})\b")


def palette_size(values: dict) -> int:
    """`capturePaletteSize` kept inside its bounds; the default when it is not a number."""
    try:
        size = int(str(values.get("capturePaletteSize") or PALETTE_DEFAULT).strip())
    except ValueError:
        return PALETTE_DEFAULT
    return max(PALETTE_MIN, min(PALETTE_MAX, size))


def parse_histogram(text: str) -> list[tuple[str, int]]:
    """The lines of `magick -format %c histogram:info:` as [("#RRGGBB", pixels)]."""
    found: list[tuple[str, int]] = []
    for line in text.splitlines():
        match = HISTOGRAM_LINE.match(line)
        if match:
            found.append((match.group(2).upper(), int(match.group(1))))
    return found


def oklab(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
    """An sRGB colour (0-255) in OKLab, where distance follows what the eye tells apart."""

    def linear(value: int) -> float:
        channel = value / 255
        return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4

    r, g, b = (linear(value) for value in rgb)
    long = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    medium = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    short = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (
        0.2104542553 * long + 0.7936177850 * medium - 0.0040720468 * short,
        1.9779984951 * long - 2.4285922050 * medium + 0.4505937099 * short,
        0.0259040371 * long + 0.7827717662 * medium - 0.8086757660 * short,
    )


def oklab_distance(first: tuple[float, float, float], second: tuple[float, float, float]) -> float:
    return sum((a - b) ** 2 for a, b in zip(first, second)) ** 0.5


def _rgb(hex_color: str) -> tuple[int, int, int]:
    return int(hex_color[1:3], 16), int(hex_color[3:5], 16), int(hex_color[5:7], 16)


def rank_palette(
    entries: list[tuple[str, int]], size: int, merge: float = PALETTE_MERGE, floor: float = PALETTE_FLOOR
) -> list[dict]:
    """The main colours, most pixels first: [{"hex", "share"}], `share` of all the pixels.

    Each colour joins the nearest bigger one closer than `merge` (its pixels are
    added, the bigger one's value stays: a real colour of the area, not an
    average); a colour under `floor` is dropped, except the first.
    """
    total = sum(count for _, count in entries)
    if total <= 0:
        return []
    clusters: list[dict] = []
    for hex_color, count in sorted(entries, key=lambda entry: (-entry[1], entry[0])):
        point = oklab(_rgb(hex_color))
        near = min(clusters, key=lambda one: oklab_distance(one["point"], point), default=None)
        if near is not None and oklab_distance(near["point"], point) < merge:
            near["count"] += count
        else:
            clusters.append({"hex": hex_color, "point": point, "count": count})
    clusters.sort(key=lambda one: -one["count"])
    kept = [one for index, one in enumerate(clusters) if index == 0 or one["count"] / total >= floor]
    return [{"hex": one["hex"], "share": round(one["count"] / total, 4)} for one in kept[:size]]


def palette(
    selection: dict,
    monitors: list[dict],
    size: int,
    runtime: Path | None = None,
    run: Runner = run_text,
) -> dict:
    """The main colours of the selection: {"colors": [{"hex", "share"}]} or {"error"}."""
    composed = compose(selection, monitors, runtime, run, name="palette")
    if "error" in composed:
        return composed
    counted = run(
        [
            "magick",
            composed["image"],
            "-scale",
            PALETTE_SAMPLE,
            "-alpha",
            "off",
            "-depth",
            "8",
            "-dither",
            "None",
            "-colors",
            str(PALETTE_QUANTIZE),
            "-format",
            "%c",
            "histogram:info:",
        ]
    )
    if counted is None:
        return {"error": "magick failed"}
    colors = rank_palette(parse_histogram(counted), size)
    return {"colors": colors} if colors else {"error": "no colours"}


# --- pin and edit --------------------------------------------------------------


def _keep(
    selection: dict,
    monitors: list[dict],
    folder_name: str,
    prefix: str,
    failure: str,
    runtime: Path | None,
    run: Runner,
    now: float | None,
) -> dict:
    """The composed area as a private file of its own: {"image", "w", "h"} or {"error"}.

    It lives in `folder_name` of the runtime folder, not in `capture/`: the next
    freeze empties that one, and a pin or an edit outlives the overlay.
    """
    composed = compose(selection, monitors, runtime, run, name=prefix)
    if "error" in composed:
        return composed
    folder = (runtime or runtime_dir()) / folder_name
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(folder, 0o700)
    path = folder / f"{prefix}-{int((time.time() if now is None else now) * 1000)}.png"
    try:
        _private_file(path, Path(composed["image"]).read_bytes())
    except OSError:
        return {"error": failure}
    return {"image": str(path), "w": composed["w"], "h": composed["h"]}


def pin_image(
    selection: dict,
    monitors: list[dict],
    runtime: Path | None = None,
    run: Runner = run_text,
    now: float | None = None,
) -> dict:
    """The composed area, kept as a file of its own for a pin: {"image"} or {"error"}."""
    kept = _keep(selection, monitors, "pins", "pin", "the pin could not be written", runtime, run, now)
    return kept if "error" in kept else {"image": kept["image"]}


def edit_image(
    selection: dict,
    monitors: list[dict],
    runtime: Path | None = None,
    run: Runner = run_text,
    now: float | None = None,
) -> dict:
    """The composed area, kept for the editor: {"image", "w", "h"} or {"error"}."""
    return _keep(selection, monitors, "edits", "edit", "the picture could not be written", runtime, run, now)


def png_size(path: Path) -> tuple[int, int] | None:
    """The width and height in a PNG's header; None when it is not one."""
    try:
        with open(path, "rb") as handle:
            head = handle.read(24)
    except OSError:
        return None
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", head[16:24])


def finish(
    source: str,
    directory: str | None = None,
    copy: bool = False,
    runtime: Path | None = None,
    copy_run=run_bytes,
    now: float | None = None,
    size: tuple[int, int] | None = None,
    run: Runner = run_text,
) -> dict:
    """Saves or copies what the editor rendered, then deletes that file.

    {"path"} for a save into `directory`, {"copied": bool} for the clipboard,
    {"error"} otherwise. Only files of the runtime `edits/` folder are taken:
    the bar passes a path and must not be able to delete anything else.
    A failed save keeps the file, so the editor can try again. `size` is the
    picture's own size: a render a pixel off it (a fractional monitor scale) is
    resized to it, so the result always has the pixels of the area.
    """
    path = Path(source)
    folder = ((runtime or runtime_dir()) / "edits").resolve()
    if path.resolve().parent != folder or not path.is_file():
        return {"error": "not an edit"}
    if size is not None and png_size(path) not in (None, size):
        if run(["magick", str(path), "-resize", f"{size[0]}x{size[1]}!", str(path)]) is None:
            return {"error": "magick failed"}
    result: dict
    if directory:
        try:
            target_path = target(directory, now)
            shutil.copyfile(path, target_path)
        except OSError:
            return {"error": "the screenshot could not be written"}
        result = {"path": str(target_path)}
    else:
        try:
            copied = copy_run(["wl-copy"], path.read_bytes())
        except OSError:
            copied = False
        if not copied:
            log("the edited screenshot was not copied")
        result = {"copied": bool(copied)}
    path.unlink(missing_ok=True)
    return result


# --- ask AI --------------------------------------------------------------------

# Google has no documented way to open AI Mode with a picture. What works is
# Lens' own upload form (`encoded_image`, multipart; the page behind a plain
# POST): `q` rides along as the question, the picture and the question land in
# one Lens search whose AI Overview answers it, and its "AI Mode" tab carries
# both on with one click. The POST has to come from the user's browser (the
# result's `vsrid` only resolves with the cookie that upload set; from here
# the thumbnail breaks), and `udm=50` on the upload is ignored, so the page
# below builds the form in the browser and submits it. Checked live in
# Firefox, 2026-11-19. Nothing leaves the machine before the user submits,
# and only to this address.
LENS = "https://lens.google.com/v3/upload"
# Longest side of the picture sent, and how long the files stay on disk.
ASK_PIXELS = 2000
ASK_KEEP = 60
QUESTION_MAX = 500

PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><title>Vitrail</title>
<style>:root{{color-scheme:light dark}}body{{font:16px sans-serif;margin:2em}}</style></head>
<body>
<form id="f" method="post" action="{action}" enctype="multipart/form-data">
<input type="file" name="encoded_image" id="i">
</form>
<p>Sending the picture to Google Lens&hellip;</p>
<noscript>This page needs JavaScript to attach the picture.</noscript>
<script>
const raw = atob("{image}");
const bytes = new Uint8Array(raw.length);
for (let n = 0; n < raw.length; n++) bytes[n] = raw.charCodeAt(n);
const files = new DataTransfer();
files.items.add(new File([bytes], "vitrail.png", {{ type: "image/png" }}));
document.getElementById("i").files = files.files;
document.getElementById("f").submit();
</script>
</body></html>
"""


def question(text: str) -> str:
    """The typed question on one line, capped."""
    return " ".join((text or "").split())[:QUESTION_MAX]


def lens_url(text: str, stamp: int) -> str:
    """Lens' upload address; the question (when there is one) rides in `q`."""
    query = {"re": "df", "ep": "gisbubb", "st": str(stamp)}
    if text:
        query["q"] = text
    return f"{LENS}?{urlencode(query)}"


def lens_page(png: bytes, text: str, stamp: int) -> str:
    """A page that posts the picture (inline, as base64) to Lens from the browser."""
    return PAGE.format(
        action=html.escape(lens_url(text, stamp), quote=True), image=base64.b64encode(png).decode("ascii")
    )


def _private_file(path: Path, data: bytes) -> None:
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "wb") as handle:
        os.fchmod(handle.fileno(), 0o600)
        handle.write(data)


def forget(paths: list[str], delay: float, sleep: Callable[[float], None] = time.sleep) -> None:
    """Deletes the files once the browser has had time to read them."""
    sleep(delay)
    for path in paths:
        Path(path).unlink(missing_ok=True)


def ask(
    selection: dict,
    monitors: list[dict],
    text: str,
    runtime: Path | None = None,
    run: Runner = run_text,
    spawner: Spawner = spawn,
    now: float | None = None,
) -> dict:
    """Opens the default browser on Google Lens with the area and the question.

    The picture goes into a private page (0600, in the runtime folder) the
    browser submits to Lens; both files are deleted after `ASK_KEEP` seconds.
    {"opened": True, "page"} or {"error"}.
    """
    composed = compose(selection, monitors, runtime, run)
    if "error" in composed:
        return composed
    if shutil.which("xdg-open") is None:
        return {"error": "xdg-open is missing"}
    folder = Path(composed["image"]).parent / "ask"
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(folder, 0o700)
    image = folder / "ask.png"
    if run(["magick", composed["image"], "-resize", f"{ASK_PIXELS}x{ASK_PIXELS}>", str(image)]) is None:
        return {"error": "magick failed"}
    os.chmod(image, 0o600)
    stamp = int((time.time() if now is None else now) * 1000)
    page = folder / "lens.html"
    try:
        _private_file(page, lens_page(image.read_bytes(), question(text), stamp).encode("utf-8"))
    except OSError:
        return {"error": "the page could not be written"}
    log_path = (runtime or runtime_dir()) / "capture.log"
    spawner(["xdg-open", page.as_uri()], log_path)
    spawner(
        [sys.executable, "-m", "vitrail.capture", "forget", "--after", str(ASK_KEEP), str(page), str(image)],
        log_path,
    )
    return {"opened": True, "page": str(page)}


# --- recording ---------------------------------------------------------------


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def status(runtime: Path | None = None, alive: Callable[[int], bool] = _alive) -> dict:
    path = status_file(runtime)
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    pid = document.get("pid")
    if not isinstance(pid, int) or not alive(pid):
        return {}
    return document


def _write_status(document: dict, runtime: Path | None = None) -> None:
    path = status_file(runtime)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.part")
    temporary.write_text(json.dumps(document, separators=(",", ":")), encoding="utf-8")
    os.replace(temporary, path)


def record(
    action: str,
    directory: str | None = None,
    geometry: str | None = None,
    monitors: list[dict] | None = None,
    audio: bool = False,
    runtime: Path | None = None,
    run: Runner = run_text,
    spawner: Spawner = spawn,
    killer: Callable[[int, int], None] = os.kill,
    alive: Callable[[int], bool] = _alive,
    now: float | None = None,
) -> dict:
    """start / stop / toggle; {"path"} or {"recording": bool}."""
    current = status(runtime, alive)
    if action == "toggle":
        action = "stop" if current else "start"
    if action == "stop":
        if not current:
            return {"recording": False}
        try:
            killer(current["pid"], signal.SIGINT)
        except OSError:
            pass
        for _ in range(20):
            if not alive(current["pid"]):
                break
            time.sleep(0.05)
        _write_status({}, runtime)
        return {"recording": False, "path": current.get("path", "")}
    if action != "start":
        return {"error": f"unknown action {action!r}"}
    if current:
        return {"recording": True, "path": current.get("path", "")}

    area = ""
    if geometry:
        try:
            area = wf_geometry(geometry, monitors)
        except ValueError:
            return {"error": f"unknown geometry {geometry!r}"}
    folder = Path(directory or videos()).expanduser()
    folder.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime(STAMP, time.localtime(now))
    path = folder / f"Recording_{stamp}.mp4"
    command = ["wf-recorder"] + (["-a"] if audio else []) + (["-g", area] if area else []) + ["-f", str(path)]
    pid = spawner(command, (runtime or runtime_dir()) / "record.log")
    _write_status({"pid": pid, "path": str(path), "started": int(time.time())}, runtime)
    return {"recording": True, "path": str(path)}


# --- entry -------------------------------------------------------------------


def _preferences() -> dict:
    from . import prefs

    try:
        return prefs.read_prefs(prefs.config_dir())
    except OSError:
        return {}


def _flag(value: object, fallback: bool) -> bool:
    if value is None or value == "":
        return fallback
    return str(value).strip().lower() in ("true", "1", "yes", "on")


USAGE = (
    "usage: capture freeze | grab --geometry <X,Y,W,H> [--copy] [--save]"
    " | record <start|stop|toggle> [--geometry <WxH+X+Y>] [--audio]"
    " | ocr|detect|qr|palette|translate|pin|edit --geometry <X,Y,W,H> | ask --geometry <X,Y,W,H> --text <question>"
    " | finish <edited.png> --save|--copy [--size <WxH>] | open <link>"
    " | window <x> <y> | status"
)


def _geometry_argument(args: list[str]) -> dict | None:
    if "--geometry" not in args:
        return None
    index = args.index("--geometry")
    if index + 1 >= len(args):
        raise ValueError("--geometry needs a rectangle")
    return parse_geometry(args[index + 1])


def _background() -> None:
    """Lowest priority and one thread for tesseract: detection must not be felt."""
    os.environ.setdefault("OMP_THREAD_LIMIT", "1")
    try:
        os.nice(10)
    except OSError:
        pass


def size_argument(args: list[str]) -> tuple[int, int] | None:
    """The `--size WxH` of `finish`, None without one; ValueError when it is not a size."""
    if "--size" not in args:
        return None
    index = args.index("--size")
    match = re.fullmatch(r"(\d+)x(\d+)", args[index + 1] if index + 1 < len(args) else "")
    if not match:
        raise ValueError("--size needs WxH")
    return int(match.group(1)), int(match.group(2))


def _text_argument(args: list[str]) -> str:
    """The value after `--text` (it may itself start with dashes), "" without one."""
    if "--text" not in args:
        return ""
    index = args.index("--text")
    return args[index + 1] if index + 1 < len(args) else ""


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    values = _preferences()
    try:
        geometry = _geometry_argument(args)
    except ValueError as problem:
        log(str(problem))
        return 2

    if args[:1] == ["freeze"]:
        result = freeze()
    elif args[:1] == ["grab"]:
        if geometry is None:
            log(USAGE)
            return 2
        saved = "--save" in args
        frozen = read_frozen()
        result = grab(
            geometry,
            frozen.get("monitors") or monitors(),
            directory=(values.get("captureDir") or pictures()) if saved else None,
            copy="--copy" in args or not saved,
        )
    elif args[:1] == ["ocr"]:
        if geometry is None:
            log(USAGE)
            return 2
        result = read_text(geometry, read_frozen().get("monitors") or monitors(), wanted_languages(values))
    elif args[:1] in (["detect"], ["qr"], ["palette"], ["translate"], ["pin"], ["edit"]):
        if geometry is None:
            log(USAGE)
            return 2
        screens = read_frozen().get("monitors") or monitors()
        if args[0] == "detect":
            _background()
            result = detect(geometry, screens, wanted_languages(values))
        elif args[0] == "qr":
            result = read_codes(geometry, screens)
        elif args[0] == "palette":
            result = palette(geometry, screens, palette_size(values))
        elif args[0] == "pin":
            result = pin_image(geometry, screens)
        elif args[0] == "edit":
            result = edit_image(geometry, screens)
        else:
            result = translate(geometry, screens, target_language(values), wanted_languages(values), run=run_limited)
    elif args[:1] == ["open"]:
        if len(args) < 2:
            log(USAGE)
            return 2
        result = open_link(args[1], runtime_dir() / "capture.log")
    elif args[:1] == ["ask"]:
        if geometry is None:
            log(USAGE)
            return 2
        if not _flag(values.get("captureAi"), True):
            result = {"error": "ai mode is off"}
        else:
            result = ask(geometry, read_frozen().get("monitors") or monitors(), _text_argument(args))
    elif args[:1] == ["forget"] and "--after" in args:
        index = args.index("--after")
        try:
            forget(args[index + 2 :], float(args[index + 1]))
        except (IndexError, ValueError):
            log(USAGE)
            return 2
        return 0
    elif args[:1] == ["window"] and len(args) >= 3:
        try:
            found = window_at(float(args[1]), float(args[2]))
        except ValueError:
            log(USAGE)
            return 2
        print(json.dumps(found or {}, separators=(",", ":")))
        return 0 if found else 1
    elif args[:1] == ["finish"] and len(args) >= 3 and args[2] in ("--save", "--copy"):
        try:
            size = size_argument(args)
        except ValueError as problem:
            log(str(problem))
            return 2
        result = finish(
            args[1],
            directory=(values.get("captureDir") or pictures()) if args[2] == "--save" else None,
            copy=args[2] == "--copy",
            size=size,
        )
    elif args[:1] == ["record"] and len(args) >= 2:
        result = record(
            args[1],
            directory=values.get("captureRecordDir") or videos(),
            geometry=geometry_text(geometry) if geometry else None,
            monitors=read_frozen().get("monitors"),
            audio=_flag(values.get("captureRecordAudio"), False),
        )
    elif args[:1] == ["status"]:
        print(json.dumps(status(), separators=(",", ":")))
        return 0
    else:
        print(USAGE, file=sys.stderr)
        return 2

    print(json.dumps(result, separators=(",", ":")))
    return 0 if "error" not in result else 1


if __name__ == "__main__":
    raise SystemExit(main())
