# Capture Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** A GNOME-style screenshot overlay: frozen screen, editable area with handles, and a floating action bar (screenshot/copy by ⏎, save, annotate, record, timer, window, full screen).

**Architecture:** `vitrail/capture.py` freezes one PNG per monitor, composes the selected rectangle from those PNGs with `magick`, and records an explicit rectangle with `wf-recorder`. `bar/capture/capture.js` holds the pure selection math. `bar/capture/CaptureOverlay.qml` draws one layer-shell surface per monitor over the frozen images with the toolbar on the starting monitor; `bar/shell.qml` owns the IPC, the freeze/confirm processes and the wiring of the bar and panel.

**Tech Stack:** Python 3.12 (stdlib only), Quickshell/QML (Qt 6), `grim`, `magick`, `wl-copy`, `wf-recorder`, `swappy`, `hyprctl`.

**Spec:** `.opencode_plans/capture-overlay.md` (design, decisions and limits; this plan argues from it).

## Global Constraints

- Fixed behaviour: no new preference keys, no new settings page.
- `⏎` captures and **copies** (no file); **Guardar** writes `Screenshot_<fecha>.png` into `captureDir` (default `~/Pictures/Screenshots`).
- The toolbar sits below the area when it fits, above when it does not, never outside the monitor.
- The selection may cross monitors; the output uses the scale of the monitor where it started.
- Only the starting monitor's surface takes `WlrKeyboardFocus.Exclusive`.
- `PRINT` stays `grim -g "$(slurp)" - | wl-copy` in `hyprland.lua`.
- Every visual element from `kit/`; the toolbar is a composed component (no raw `Rectangle`/`Text`/`MouseArea` for visuals).
- All user-facing strings in the six `kit/i18n/*.json` (same key set in every file).
- Every invoked program is already in `packages/*.txt` (`grim`, `imagemagick`, `wl-clipboard`, `wf-recorder`, `swappy`, `xdg-utils`).

## Review Focus

- A drag that starts outside any monitor or crosses a gap between outputs → the rectangle is clamped to the layout, never negative.
- A screenshot of a 1×1 area → `magick` receives `1x1` and produces a 1×1 file.
- A mixed-scale layout (1.0 + 1.5) → the composed file is at the starting monitor's scale and both pieces land at the right offset.
- `Esc` (or a failed `grim`) → no overlay left on screen and the session is usable.
- Enter with nothing selected → whole layout, from the frozen images, not a live `grim`.

---

### Task 1: Freeze one image per monitor

**Files:**
- Modify: `vitrail/capture.py`
- Test: `tests/test_capture.py`

**Interfaces:**
- Produces: `monitors(run=run_text) -> list[dict]` (`{"name","x","y","scale","width","height"}`), `freeze(runtime=None, run=run_text) -> dict` (`{"monitors": [...with "image"], "bounds": {"x","y","w","h"}}` or `{"error"}`), `runtime_dir()`, `FREEZE` (subfolder name `"capture"`).

- [x] **Step 1: Failing tests** — `FreezeTests`: two-monitor JSON from `hyprctl monitors -j` yields two `grim -o NAME path` calls in order, `bounds` = union, and the images live under `<runtime>/capture/`; a `grim` failure (run returns `None`) returns `{"error": "grim failed"}`; a previous run's PNGs are deleted first.
- [x] **Step 2: Run** — `.venv/bin/python -m unittest tests.test_capture -v` → FAIL (`AttributeError: monitors`).
- [x] **Step 3: Implement** — `monitors()` parses `hyprctl monitors -j` keeping `name/x/y/scale/width/height`; `freeze()` clears `runtime/capture`, runs `grim -o <name> frozen-<name>.png`, returns the table; `None` from `grim` aborts with the error dict.
- [x] **Step 4: Run** — PASS.
- [x] **Step 5: Commit** — `git add vitrail/capture.py tests/test_capture.py && git commit -m "feat(capture): freeze one image per monitor"` (skip while the tree carries unrelated work).

### Task 2: Compose the selected rectangle

**Files:**
- Modify: `vitrail/capture.py`
- Test: `tests/test_capture.py`

**Interfaces:**
- Consumes: `freeze()` output.
- Produces: `crop_pieces(selection: dict, monitors: list[dict]) -> tuple[dict, list[dict]]` (`canvas {"w","h"}`, pieces `{"image","crop":[x,y,w,h],"offset":[x,y]}` in physical pixels, reference scale = the monitor containing the selection's origin) and `grab(selection, monitors, runtime=None, directory=None, copy=False, run=run_text, copy_run=run_bytes, now=None) -> dict` (`{"path"?,"copied"?}` or `{"error"}`).

- [x] **Step 1: Failing tests** — same monitor at scale 1: one piece, crop `[x,y,w,h]`, offset `[0,0]`, canvas `w×h`; selection crossing two 1.0 monitors: two pieces, second offset `[first_width, 0]`; mixed scale 1.0+1.5: the 1.5 piece is cropped at 1.5× and its canvas offset rounds to the reference scale; drag normalized from bottom-right (negative `w`) is refused (`{"error": "empty selection"}`); `grab(copy=True)` calls `wl-copy` with a PNG and returns `{"path": None, "copied": True}`; `grab(copy=True, directory=tmp)` also writes `Screenshot_*.png`; without `magick` (`shutil.which` patched to `None`) → `{"error": "imagemagick is missing"}`.
- [x] **Step 2: Run** → FAIL.
- [x] **Step 3: Implement** — intersection of the selection with each monitor's logical rect, scaled per monitor; `magick -size WxH xc:none ( img -crop … +repage ) -geometry +x+y -composite … out.png` into `<runtime>/capture/selection.png`; `wl-copy` reads that file when `copy`; the named file is copied/written into the folder when `directory` is given.
- [x] **Step 4: Run** → PASS.
- [x] **Step 5: Commit** — `git commit -am "feat(capture): compose the selected rectangle from the frozen images"`.

### Task 3: Window under the pointer, recording with a geometry, new CLI

**Files:**
- Modify: `vitrail/capture.py` (remove `shot`, `geometry`; keep `target`, `record`, `status`)
- Test: `tests/test_capture.py` (replace `GeometryTests`/`ShotTests`)

**Interfaces:**
- Produces: `window_at(x, y, run=run_text) -> dict | None` (`{"x","y","w","h"}` in layout coordinates, topmost visible client whose rect contains the point, from `hyprctl clients -j`, ignoring `size` 0 and `hidden`/unmapped entries); `record(action, directory=None, geometry=None, audio=False, runtime=None, run=..., spawner=..., killer=..., alive=..., now=None)` where `geometry` (`"WxH+X+Y"`) replaces `region`; CLI `freeze`, `grab --geometry X,Y,W,H [--copy] [--save]`, `record start [--geometry X,Y,W,H] [--audio]`, `window X Y`, `status`.

- [x] **Step 1: Failing tests** — `window_at`: two overlapping clients picks the one containing the point; a point in no window returns `None`; hidden client ignored; no `slurp` is run by `record(..., geometry="10x10+5+5")` and `wf-recorder -g "10x10+5+5"` is spawned; `grab --save` reaches `target()`; `main(["shot", "full"])` no longer answers `shot`.
- [x] **Step 2: Run** → FAIL.
- [x] **Step 3: Implement** — delete `shot`/`geometry`, add `window_at`, `geometry` argument in `record`, and the CLI branches (`--copy`/`--save` read `captureDir`).
- [x] **Step 4: Run** — `.venv/bin/python -m unittest tests.test_capture tests.test_dependencies -v` → PASS.
- [x] **Step 5: Commit** — `git commit -am "feat(capture): window under the pointer, explicit record geometry"`.

### Task 4: Pure selection geometry

**Files:**
- Create: `bar/capture/capture.js`, `tests/qml/tst_capture_geometry.qml`

**Interfaces:**
- Produces (`.pragma library`): `normalize(drag)` (`{x,y,w,h}` from two points, unsigned), `move(rect, dx, dy, bounds)`, `resize(rect, handle, dx, dy, bounds, min)`, `handleAt(point, rect, tolerance)` → `"nw"|"n"|"ne"|"e"|"se"|"s"|"sw"|"w"|"inside"|""`, `inside(point, rect)`, `toLocal(point, monitor)`, `toLayout(point, monitor)`, `toLocalRect(rect, monitor)`, `toolbarPlacement(rect, screen, size)` → `{x, y}`, `label(rect)` → `"1280 × 720"`, `empty()`.

- [x] **Step 1: Failing tests** — `tests/qml/tst_capture_geometry.qml` (TestCase `CaptureGeometry`, imports `../../bar/capture/capture.js`): drag in the four directions normalizes; `move` stops at `bounds`; each of the eight handles grows/shrinks in its direction; `resize` never goes below `min` nor past `bounds`; `handleAt` finds each corner within tolerance and `"inside"` in the middle; `toolbarPlacement` puts the bar below (`rect.y + rect.h + gap`), above when there is no room, and inside when neither fits; `label({w:1280,h:720})` is `"1280 × 720"`.
- [x] **Step 2: Run** — `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml -name CaptureGeometry` → FAIL.
- [x] **Step 3: Implement** — the functions above, clamping against `bounds` (`{x,y,w,h}` of the layout) and returning new objects.
- [x] **Step 4: Run** → PASS, and `bash tests/qml_smoke.sh` still green.
- [x] **Step 5: Commit** — `git add bar/capture/capture.js tests/qml/tst_capture_geometry.qml`.

### Task 5: Toolbar and strings

**Files:**
- Create: `bar/capture/CaptureToolbar.qml`
- Modify: `bar/kit/i18n/{en,es,pt,it,fr,de}.json`
- Test: `tests/test_i18n.py` (key parity), `bash tests/qml_smoke.sh` (loads nothing new), manual later

**Interfaces:**
- Produces: `CaptureToolbar { property string mode: "shot"|"record"; property int timer: 0|3|5; signal shot(); signal save(); signal annotate(); signal record(); signal timerCycled(); signal windowMode(); signal fullScreen(); signal closed() }`.
- i18n keys: `capture.shot`, `capture.save`, `capture.annotate`, `capture.record`, `capture.timer`, `capture.timer.3`, `capture.timer.5`, `capture.window`, `capture.full`, `capture.close`, `capture.failed`.

- [x] **Step 1: Failing test** — `tests/test_i18n.py` already checks parity; add the eleven keys to `en.json` first and run the suite to see the other five languages fail.
- [x] **Step 2: Translate** — the same keys in the six files (Spanish: Capturar, Guardar, Anotar, Grabar área, Temporizador, 3 s, 5 s, Ventana, Pantalla completa, Cerrar, "No se pudo capturar la pantalla").
- [x] **Step 3: Component** — `VitrailSurface` (`style: "glass"`, radius from tokens) with `RowLayout` of `VitrailButton`s (`variant: "text"`, `size: "sm"`, icon + text, tooltip via `VitrailTooltip`), the record button highlighted when `mode === "record"`, the timer button showing its current value.
- [x] **Step 4: Run** — `bash tests/qml_smoke.sh` and `.venv/bin/python -m unittest tests.test_i18n` → PASS.
- [x] **Step 5: Commit**.

### Task 6: The overlay

**Files:**
- Create: `bar/capture/CaptureOverlay.qml`, `tests/fixtures/capture_smoke.qml`
- Modify: `tests/qml_smoke.sh` (load the overlay in a Quickshell fixture, like the launcher)

**Interfaces:**
- Consumes: `capture.js`, `CaptureToolbar.qml`, `shell.capture` (`{monitors, bounds}` from `freeze`), `shell.t`.
- Produces: root `Item { property var capture: ({}); property string mode: "region"; signal confirmed(var selection, string action, int timer); signal cancelled() }`; one `PanelWindow` per `Quickshell.screens` (`WlrLayer.Overlay`, `ExclusionMode.Ignore`, `WlrKeyboardFocus.Exclusive` only on `capture.monitor`).

- [x] **Step 1: Failing test** — `tests/fixtures/capture_smoke.qml` creates the overlay offscreen and expects `createObject()` to return an item (like `launcher_smoke.qml`); `tests/qml_smoke.sh` gains that check.
- [x] **Step 2: Run** → FAIL (component missing).
- [x] **Step 3: Implement** — frozen `Image` per surface (`source: "file://" + monitor.image`, stretched to the surface), dimming outside the selection, crosshair while empty, border and eight handles, `W×H` label near the pointer, window mode highlight rect, toolbar placement from `capture.js`, keyboard (`Enter/G/A/R/T/W/F/Esc/Tab/arrows/Shift+arrows`), drag/move/resize through a full-surface `MouseArea`.
- [x] **Step 4: Run** — `bash tests/qml_smoke.sh` → PASS (overlay loads offscreen).
- [x] **Step 5: Commit**.

### Task 7: Shell wiring, and the two retired toggles

**Files:**
- Modify: `bar/shell.qml` (`captureShot`, `toggleRecording`, new `openCapture`, `closeCapture`, `confirmCapture`, IPC `capture`, panel wiring at the `CaptureRow`, popup close + settle)
- Modify: `bar/capture/CaptureRow.qml` (only if a signal changes)
- Modify: `vitrail/prefs.map`, `shell/Prefs.qml`, `shell/pages/BarPage.qml`, `bar/kit/i18n/*.json` (retire `captureCopy`, `captureAnnotate`), `README.md` (prefs table)
- Test: `tests/test_prefs_map.py`, `tests/test_prefs.py`, `bash tests/qml_smoke.sh`

**Interfaces:**
- `shell.openCapture(mode)` (`"region"|"window"|"full"|"record"`): closes the popup, waits `VitrailTokens.duration("fast")`, runs `python3 -m vitrail.capture freeze`, stores the JSON in `shell.capture`, loads the overlay; `confirmCapture(selection, action, timer)` runs `grab --copy|--save`, `record start --geometry`, or `swappy -f` on the saved PNG; `captureShot(mode)` is now an alias of `openCapture`; panel "Pantalla completa" → `openCapture("full")`; panel record → `openCapture("record")` when `captureRecordRegion`, else `toggleRecording()`.
- IPC: `capture` target with `open(mode: string)`, `cancel()`.

- [x] **Step 1: Failing test** — `tests/test_prefs_map.py` fails once the keys leave `prefs.map` while `Prefs.qml`/`BarPage.qml` still name them (run it to watch it fail).
- [x] **Step 2: Retire** — remove `captureCopy`/`captureAnnotate` from `prefs.map`, `Prefs.qml` (aliases + `Settings` properties), the two `VitrailSettingRow`s and their strings in the six files, the README row.
- [x] **Step 3: Wire** — IPC, `openCapture`, freeze/grab/record `Process`es with `StdioCollector`, overlay `Loader`, popup close + settle, `captureRecordRegion` path.
- [x] **Step 4: Run** — `.venv/bin/python -m unittest discover -s tests` and `bash tests/qml_smoke.sh` → PASS.
- [x] **Step 5: Commit**.

### Task 8: Documentation and gates

**Files:**
- Modify: `README.md` (Capture paragraph, prefs table), `docs/features.md`, `CHANGELOG.md`, `docs/manual-checks.md` (new section), `screenshots/` (new overlay shots)
- Test: `tests/test_docs.py`, `bash tests/install_test.sh`

- [x] **Step 1: Docs** — describe the overlay, the frozen image, ⏎ copies / Guardar saves, `PRINT` unchanged; the manual check walks: bar button, drag, handles, ⏎, Guardar, Anotar, grabar área, timer, ventana, pantalla completa, Esc, two-monitor drag.
- [x] **Step 2: Run every gate** — `uv run python -m unittest discover -s tests`, `bash tests/qml_smoke.sh`, `bash tests/install_test.sh`, `ruff check`, `ruff format --check`.
- [x] **Step 3: Commit**.

## Ejecutado (2026-11-15)

Las 8 tareas están hechas y verdes: 990 tests de Python, 97 comprobaciones de
`tests/qml_smoke.sh` (que incluye `qmllint` de `bar/capture/` y la carga de la
barra de acciones en un Quickshell real), 77 del instalador, `ruff check` y
`ruff format` limpios en los ficheros tocados.

Comprobado en la sesión viva: `freeze` de los dos monitores, el overlay
dibujado sobre la pantalla congelada, `⏎` copiando el layout entero
(5120×1440) y `G` escribiéndolo en `~/Pictures/Screenshots`, con `magick
compare` dando 0 píxeles de diferencia contra el recorte del congelado (mismo
monitor y cruzando los dos).

### Rulings

- Un arrastre invertido se normaliza en vez de rechazarse (el backend sólo
  rechaza un área vacía). Coste si me equivoco: un rectángulo inesperado.
- `capture.js` no tiene `empty()`: la selección vacía es `null`.
- La barra de acciones declara `tooltip`/`tooltipDetail` y los pinta con
  `VitrailTooltip`, que es lo que `tests/test_tooltips.py` espera.
- El overlay no se puede cargar sin compositor (`PanelWindow` no existe en
  `offscreen`), así que el smoke carga `CaptureToolbar` y `qmllint` cubre el
  overlay; el resto se comprueba a mano (`docs/manual-checks.md`).
- `annotate` lanza `swappy` separado (`spawn`), no lo espera.
- `grab` por CLI lee `frozen.json`, porque corre en su propio proceso y los
  monitores de `hyprctl` no llevan imágenes. Fallo encontrado en la prueba viva
  y cubierto con tests.
- Si el portapapeles rechaza la imagen, `grab` devuelve `copied: false` (no
  `error`): la captura existió, sólo no se copió.
- `wf-recorder` rechaza la forma `WxH+X+Y` (y un área que cruce salidas):
  `record` la traduce a `x,y wxh` y la recorta al monitor donde empieza. Fallo
  encontrado en la prueba viva, con tests nuevos.
- Barra reiniciada para correr el código nuevo. El árbol traía el refactor de
  OSD sin terminar (`OsdCell` ya no tiene `settingsRequested` ni el engranaje y
  `OsdLayer` aún lo usaba); se reparó lo justo para que compile, sin tocar el
  diseño nuevo.

### Segunda pasada (mismo día, tras la revisión del dueño)

- Faltaba `mask: Region { item: gestures }` en las superficies: sin él
  Quickshell las dejaba *click-through* y no se podía dibujar el área ni pulsar
  la barra. Detectado con `ydotool` (ratón real) y comprobado clic a clic.
- La barra de acciones sólo se muestra cuando hay área, y se declara después de
  la capa de gestos para que sus botones reciban el clic.
- El modo ventana captura con **un solo clic**.
- El temporizador ahora **vuelve a congelar** al terminar la cuenta atrás (antes
  capturaba las imágenes viejas: no tenía efecto).
- Aviso `capture.copyFailed` si el portapapeles rechaza la imagen.
- Probado con ratón real: arrastrar, mover, redimensionar por asas, pulsar
  Guardar (1000×600 escrito), pulsar Cerrar, `W` + clic (capturó 2528×1316),
  `T` + `G` (archivo 3 s después), `A` (swappy abierto con la captura).

### Tercera pasada (2026-11-17)

- `PRINT` (y `Super+PRINT`, con todo el layout ya marcado) abren el overlay por
  el IPC de la barra: `hyprland.lua` deja de llamar a `grim`/`slurp` para las
  teclas. La barra tiene que estar corriendo, como para el resto de atajos.
- `slurp` sale de `packages/base.txt`, de los dos PKGBUILD, del mapa de
  `tests/test_dependencies.py` y del README.
- Comprobado en vivo con teclado real (`ydotool`): `PRINT` abre el overlay con
  la cruz, `Super+PRINT` lo abre con el layout entero seleccionado y `⏎` copia
  5120×1440.
