# Cursor: una lista, interruptores y nombre estable

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (native). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Un solo listado de cursores con interruptores Adaptativo/Monocromático, un tema generado con nombre estable (`vitrail-cursor`) y propagación a las apps nuevas, sin tocar packs ni Hypraether.

**Architecture:** `fonts.ini` guarda el pack elegido, no el tema generado. `fonts.apply` resuelve el pack por modo (split claro/oscuro) y escribe siempre `~/.local/share/icons/vitrail-cursor`: generado con la paleta cuando Adaptativo está encendido, o un symlink al `cursors/` del pack cuando está apagado. Los `vitrail-<pack>` viejos se convierten en symlinks a `vitrail-cursor` para que una sesión con la env antigua siga viendo el cursor actual. La UI pierde las pestañas y gana dos interruptores.

**Tech Stack:** Python 3.12 (stdlib), QML/Quickshell, pytest/unittest, qmltestrunner.

**Spec:** diseño aprobado en la conversación (2026-11-14), resumido en este plan.

**Status:** implementado y verificado (950 tests Python, 93 comprobaciones QML). Los commits quedan pendientes: el árbol ya tenía 28 archivos modificados ajenos a este cambio y no se quiso mezclar.

## Global Constraints

- Un pack nunca se modifica ni se borra; solo se lee.
- `vitrail-cursor` es el único nombre aplicado (`XCURSOR_THEME`, GTK, Xresources, XSETTINGS, environment.d).
- `cursorAdaptive` por defecto `true`; `cursorMonochrome` por defecto `false`.
- Monocromático solo tiene efecto con Adaptativo encendido.
- Las claves nuevas van en `vitrail/prefs.map` y en `shell/Prefs.qml`, y sus textos en los **seis** `kit/i18n/*.json`.
- Nada de valores visuales crudos en QML: tokens del kit.
- No se borra `assets/cursors`, `vitrail/wincursor.py`, `vitrail/spinner.py` ni nada de Hypraether.

## Review Focus

- Un pack sin carpeta `cursors/` (solo `cursors_scalable`): no debe romper; se aplica el nombre del pack tal cual.
- Cambiar de pack con Adaptativo apagado: el symlink anterior debe retirarse, nunca escribir dentro del pack.
- `vitrail-cursor` no debe confundirse con un pack (`source_of` devuelve `""`).
- Una sesión cuya `XCURSOR_THEME` todavía diga `vitrail-<pack>` debe seguir funcionando (alias).
- Un valor legado `vitrail-X` en `fonts.ini` debe migrar a `X` + Adaptativo, sin dejar la app sin cursor.

---

### Task 1: Núcleo del cursor — nombre estable, modo mono y alias

**Files:**
- Modify: `vitrail/cursor.py`
- Test: `tests/test_cursor.py`

**Interfaces:**
- Produces:
  - `STABLE: str = "vitrail-cursor"`
  - `source_of(name: str) -> str` — `""` para `STABLE`
  - `build(pack: Path, target: Path, palette: dict, cache: Path, force: bool = False, spinner: bool = True, mono: bool = False, render=...) -> bool`
  - `alias(pack: Path, target: Path) -> bool`
  - `migrate_aliases(root: Path) -> int`

- [x] **Step 1: Escribir los tests que fallan**

En `tests/test_cursor.py`, añadir a `BuildTests`:

```python
def test_the_stable_name_is_not_a_pack(self) -> None:
    self.assertEqual(cursor.STABLE, "vitrail-cursor")
    self.assertEqual(cursor.source_of(cursor.STABLE), "")

def test_monochrome_paints_the_active_shape_with_the_ink(self) -> None:
    self.assertTrue(self.build(mono=True))
    hand = struct.unpack("<I", cursor.read_cursor(self.target / "cursors" / "hand2")[0]["pixels"][:4])[0]
    self.assertEqual(hand, 0xFFFF0000)

def test_a_static_pack_is_aliased_not_copied(self) -> None:
    self.assertTrue(cursor.alias(self.pack, self.target))
    self.assertTrue((self.target / "cursors").is_symlink())
    self.assertTrue((self.target / "cursors" / "left_ptr").is_file())
    self.assertIn("Inherits=Bibata", (self.target / "index.theme").read_text(encoding="utf-8"))

def test_building_over_an_alias_replaces_the_symlink(self) -> None:
    cursor.alias(self.pack, self.target)
    self.assertTrue(self.build())
    self.assertFalse((self.target / "cursors").is_symlink())
    arrow = cursor.read_cursor(self.target / "cursors" / "left_ptr")[0]["pixels"]
    self.assertEqual(struct.unpack("<I", arrow[:4])[0], 0xFFFF0000)

def test_a_stale_pack_does_not_leave_cursors_behind(self) -> None:
    self.build()
    (self.pack / "cursors" / "left_ptr").unlink()
    cursor.write_cursor([image()], self.pack / "cursors" / "new_shape")
    self.assertTrue(self.build(primary="#0000ff"))
    self.assertFalse((self.target / "cursors" / "left_ptr").exists())
    self.assertTrue((self.target / "cursors" / "new_shape").is_file())

def test_old_generated_themes_become_aliases(self) -> None:
    icons = self.pack.parent
    cursor.alias(self.pack, icons / cursor.STABLE)
    old = icons / "vitrail-Bibata"
    cursor.write_cursor([image()], old / "cursors" / "left_ptr")
    (old / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
    self.assertEqual(cursor.migrate_aliases(icons), 1)
    self.assertTrue(old.is_symlink())
    self.assertEqual(old.resolve(), (icons / cursor.STABLE).resolve())
    self.assertEqual(cursor.migrate_aliases(icons), 0)
```

Actualizar `self.build` para aceptar `mono`:

```python
def build(self, primary="#ff0000", spinner=False, render=None, mono=False) -> bool:
    palette = dict(PALETTE, on_surface=primary)
    return cursor.build(self.pack, self.target, palette, self.cache,
                        spinner=spinner, render=render or (lambda svg: None), mono=mono)
```

Y cambiar `self.target` a `root / "icons" / "vitrail-cursor"`.

- [x] **Step 2: Ejecutar y ver el fallo**

Run: `python3 -m unittest tests.test_cursor -q`
Expected: FAIL (`STABLE`, `alias`, `migrate_aliases` y `mono` no existen).

- [x] **Step 3: Implementar en `vitrail/cursor.py`**

- `STABLE = PREFIX + "cursor"`; `source_of` devuelve `""` para `STABLE`.
- `_stamp_value(pack, inks, spinner, mono)` incluye `mono`.
- `build(..., mono=False)`: `fill = inks["ink"] if mono or source.name not in ACTIVE else inks["accent"]`.
- Antes de escribir, si `target / "cursors"` es symlink, borrarlo; si es un directorio, `shutil.rmtree` para no dejar imágenes del pack anterior. Después `mkdir`.
- `index.theme`: `Name=Vitrail · Cursor`, `Comment=Vitrail's cursor (<pack.name>)`, `Inherits=<pack.name>`.
- `alias(pack, target)`: si `pack/"cursors"` no es directorio, `False`. Retira `target/"cursors"` (symlink o dir) y crea `os.symlink(pack/"cursors", target/"cursors")` con ruta absoluta. Escribe `index.theme` con `Name=Vitrail · Cursor`, `Comment=Vitrail's cursor: <pack.name>`, `Inherits=<pack.name>`. `True`.
- `migrate_aliases(root)`: por cada entrada de `root` que empiece por `PREFIX`, no sea `STABLE`, no sea symlink, tenga `cursors/` y no empiece por `"vitrail-icons-"`, bórrala y crea un symlink a `STABLE` (nombre relativo o absoluto). Devuelve cuántas convirtió. Si `root/STABLE` no existe, `0`.
- `main(["build", pack])` escribe `output/STABLE` (el CLI ya no crea `vitrail-<pack>`).

- [x] **Step 4: Ejecutar los tests**

Run: `python3 -m unittest tests.test_cursor -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add vitrail/cursor.py tests/test_cursor.py
git commit -m "feat(cursor): one stable theme, mono ink and aliases"
```

---

### Task 2: `fonts.apply` — preferencias nuevas, nombre estable y propagación

**Files:**
- Modify: `vitrail/fonts.py`
- Modify: `vitrail/prefs.map`
- Modify: `vitrail/prefs.py`
- Modify: `bin/vitrail-settings`
- Test: `tests/test_fonts.py`, `tests/test_prefs.py`

**Interfaces:**
- Consumes: `cursor.STABLE`, `cursor.build(..., mono=)`, `cursor.alias`, `cursor.migrate_aliases`.
- Produces:
  - `DEFAULT_CURSOR_ADAPTIVE = True`, `DEFAULT_CURSOR_MONO = False`
  - `cursor_env(theme: str, size: int) -> str`
  - `prefs._normalise_cursor(config: Path) -> bool`

- [x] **Step 1: Escribir los tests que fallan**

En `tests/test_fonts.py`, cambiar el helper para no escribir en el HOME real:

```python
def apply(self, values: dict, run=None, mode=None) -> int:
    return fonts.apply(
        values, self.config, run=run or self.recording(FACES), roots=[self.icons],
        hyprland=True, data_home=self.root / "data", cache=self.root / "cache", mode=mode,
    )
```

Sustituir los tests de cursor por:

```python
def test_an_adaptive_cursor_builds_the_stable_theme(self) -> None:
    self.apply({"fontSystem": "Roboto", "iconTheme": "Adwaita", "cursorTheme": "Adwaita",
                "cursorAdaptive": "true", "cursorSize": 24})
    theme = self.root / "data" / "icons" / "vitrail-cursor"
    self.assertTrue((theme / "cursors").is_dir())
    self.assertIn("Inherits=Adwaita", (theme / "index.theme").read_text(encoding="utf-8"))
    env = (self.config / "environment.d/20-vitrail-cursor.conf").read_text(encoding="utf-8")
    self.assertIn("XCURSOR_THEME=vitrail-cursor", env)

def test_a_static_cursor_aliases_the_pack(self) -> None:
    self.apply({"fontSystem": "Roboto", "iconTheme": "Adwaita", "cursorTheme": "Adwaita",
                "cursorAdaptive": "false", "cursorSize": 24})
    theme = self.root / "data" / "icons" / "vitrail-cursor"
    self.assertTrue((theme / "cursors").is_symlink())
    self.assertEqual((theme / "cursors").resolve(), (self.icons / "Adwaita" / "cursors").resolve())

def test_a_legacy_vitrail_value_still_adapts(self) -> None:
    self.apply({"fontSystem": "Roboto", "iconTheme": "Adwaita",
                "cursorTheme": "vitrail-Adwaita", "cursorSize": 24})
    theme = self.root / "data" / "icons" / "vitrail-cursor"
    self.assertFalse((theme / "cursors").is_symlink())
    self.assertIn("Inherits=Adwaita", (theme / "index.theme").read_text(encoding="utf-8"))

def test_a_pack_without_cursors_falls_back_to_its_name(self) -> None:
    self.apply({"fontSystem": "Roboto", "iconTheme": "Adwaita", "cursorTheme": "OnlyCursor",
                "cursorAdaptive": "true", "cursorSize": 24})
    env = (self.config / "environment.d/20-vitrail-cursor.conf").read_text(encoding="utf-8")
    self.assertIn("XCURSOR_THEME=OnlyCursor", env)

def test_each_mode_aliases_its_own_pack_under_the_stable_name(self) -> None:
    values = {"fontSystem": "Roboto", "iconTheme": "Adwaita", "cursorTheme": "Adwaita",
              "cursorThemeLight": "Adwaita", "cursorThemeDark": "OnlyCursor",
              "cursorThemeSplit": "true", "cursorAdaptive": "false", "cursorSize": 24}
    self.apply(values, mode="light")
    theme = self.root / "data" / "icons" / "vitrail-cursor"
    self.assertEqual((theme / "cursors").resolve(), (self.icons / "Adwaita" / "cursors").resolve())
    self.apply(values, mode="dark")
    self.assertEqual((theme / "cursors").resolve(), (self.icons / "OnlyCursor" / "cursors").resolve())

def test_the_cursor_reaches_hyprland_env_and_the_user_bus(self) -> None:
    calls: list[list[str]] = []
    self.apply({"fontSystem": "Roboto", "iconTheme": "Adwaita", "cursorTheme": "Adwaita",
                "cursorAdaptive": "false", "cursorSize": 24}, run=self.recording(FACES, calls))
    self.assertIn(["hyprctl", "setcursor", "vitrail-cursor", "24"], calls)
    self.assertTrue(any(argv[:2] == ["hyprctl", "eval"] and "hl.env(\"XCURSOR_THEME\", \"vitrail-cursor\")" in argv[2]
                        for argv in calls))
    self.assertIn(["systemctl", "--user", "set-environment",
                   "XCURSOR_THEME=vitrail-cursor", "XCURSOR_SIZE=24"], calls)
    self.assertIn(["dbus-update-activation-environment", "--systemd",
                   "XCURSOR_THEME", "XCURSOR_SIZE"], calls)

def test_monochrome_is_applied_only_with_adaptive(self) -> None:
    # Con adaptativo apagado, monocromático no cambia el pack.
    self.apply({"fontSystem": "Roboto", "iconTheme": "Adwaita", "cursorTheme": "Adwaita",
                "cursorAdaptive": "false", "cursorMonochrome": "true", "cursorSize": 24})
    theme = self.root / "data" / "icons" / "vitrail-cursor"
    self.assertTrue((theme / "cursors").is_symlink())
```

En `tests/test_prefs.py`, en `MigrationTests`:

```python
def test_a_vitrail_cursor_becomes_a_pack_plus_adaptive(self) -> None:
    self.config.mkdir(parents=True)
    (self.config / "fonts.ini").write_text(
        "[fonts]\ncursorTheme=vitrail-Bibata\ncursorThemeLight=vitrail-cursor\n", encoding="utf-8"
    )
    self.assertTrue(prefs.migrate(self.config))
    values = prefs.read_prefs(self.config)
    self.assertEqual(values["cursorTheme"], "Bibata")
    self.assertEqual(values["cursorThemeLight"], "vitrail-cursor")
    self.assertEqual(values["cursorAdaptive"], "true")
    self.assertFalse(prefs.migrate(self.config))
```

- [x] **Step 2: Ejecutar y ver el fallo**

Run: `python3 -m unittest tests.test_fonts tests.test_prefs -q`
Expected: FAIL.

- [x] **Step 3: Implementar**

`vitrail/prefs.map` (en la sección de fonts, junto a `cursorTheme*`):

```
# The palette tints the chosen pack; monochrome drops the accent ink.
fonts cursorAdaptive
fonts cursorMonochrome
```

`vitrail/prefs.py`:
- `_normalise_cursor(config) -> bool`: lee `fonts.ini`; por cada `cursorTheme`, `cursorThemeLight`, `cursorThemeDark`, si el valor empieza por `cursor.PREFIX` y no es `cursor.STABLE`, escribe el valor sin prefijo y `cursorAdaptive=true` en una sola escritura (`_write_keys`). Devuelve si cambió.
- Llamarlo desde `migrate()` junto a `_normalise_dock_magnify`.

`vitrail/fonts.py`:
- Constantes `DEFAULT_CURSOR_ADAPTIVE = True`, `DEFAULT_CURSOR_MONO = False`.
- `_flag(values, key, default) -> bool`.
- `cursor_env(theme, size) -> str`: `f'hl.env("XCURSOR_THEME", {json.dumps(theme)}); hl.env("XCURSOR_SIZE", "{size}")'`.
- En `apply`, sustituir el bloque `designs`/`cursor`:
  - `adaptive = _flag(values, "cursorAdaptive", DEFAULT_CURSOR_ADAPTIVE)`.
  - `monochrome = adaptive and _flag(values, "cursorMonochrome", DEFAULT_CURSOR_MONO)`.
  - Resolver `requested` con el split como hoy; si `requested` empieza por `PREFIX` y no es `STABLE`, `requested = source_of(requested)` y `adaptive = True`.
  - `pack = pick(requested, live["cursorDesigns"], DEFAULT_CURSOR, ...)`.
  - `source = theme_dir(pack, roots or DEFAULT_ROOTS)`; si no, `pack = DEFAULT_CURSOR`, `replaced = True`, y reintentar `source`.
  - `target = (data_home / "icons" if data_home else cursor.output_root()) / cursor.STABLE`.
  - Adaptativo: `cursor.build(source, target, palette or active_palette(), cache / "themes", spinner=False, mono=monochrome, render=render)`; si `False`, `applied = pack`.
  - Estático: `cursor.alias(source, target)`; si `False`, `applied = pack`.
  - `applied` por defecto `cursor.STABLE`; `cursor_engine.migrate_aliases(target.parent)`.
  - `cursor = applied`.
- Tras `gsettings`/`hyprctl setcursor`: añadir `hyprctl eval cursor_env(cursor, size)`, `systemctl --user set-environment XCURSOR_THEME=... XCURSOR_SIZE=...` y `dbus-update-activation-environment --systemd XCURSOR_THEME XCURSOR_SIZE`.

`bin/vitrail-settings`: añadir `"cursorDesigns":[]` al JSON vacío.

- [x] **Step 4: Ejecutar los tests**

Run: `python3 -m unittest tests.test_fonts tests.test_prefs tests.test_prefs_map -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add vitrail/fonts.py vitrail/prefs.py vitrail/prefs.map bin/vitrail-settings tests/test_fonts.py tests/test_prefs.py
git commit -m "feat(cursor): adaptive and monochrome preferences with one applied theme"
```

---

### Task 3: Pantalla — lista única, interruptores y traducciones

**Files:**
- Modify: `shell/pages/FontsPage.qml`
- Modify: `shell/Prefs.qml`
- Modify: `kit/i18n/en.json`, `es.json`, `de.json`, `fr.json`, `it.json`, `pt.json`
- Test: `tests/qml/tst_fonts_options.qml`

**Interfaces:**
- Consumes: `prefs.cursorAdaptive`, `prefs.cursorMonochrome`; `fonts.cursorDesigns`.
- Produces: objectNames `cursorAdaptiveSwitch`, `cursorMonochromeSwitch`; `cursorOptions(current, inherit)` sin `tab`.

- [x] **Step 1: Escribir el test QML que falla**

En `tests/qml/tst_fonts_options.qml`, añadir al `QtObject prefs`:

```qml
property bool cursorAdaptive: true
property bool cursorMonochrome: false
```

Sustituir los dos tests de pestañas por:

```qml
function test_the_cursor_list_is_one_list_of_packs() {
    var rows = page.item.cursorOptions("", false)
    verify(rows.length > 0)
    for (var i = 0; i < rows.length; i++) {
        compare(rows[i].key.indexOf("vitrail-"), -1)
        compare(rows[i].tab, undefined)
    }
}

function test_the_cursor_picker_has_no_tabs() {
    prefs.cursorThemeSplit = false
    page.item.tab = "cursor"
    wait(50)
    var card = findObject(page.item, "cursorSharedCard")
    var picker = findObject(card, "cursorThemePicker")
    compare(picker.tabs.length, 0)
}

function test_the_switches_write_the_preferences() {
    page.item.tab = "cursor"
    wait(50)
    var adaptive = findObject(page.item, "cursorAdaptiveSwitch")
    var mono = findObject(page.item, "cursorMonochromeSwitch")
    verify(adaptive !== null && mono !== null)
    adaptive.toggled(false)
    compare(prefs.cursorAdaptive, false)
    compare(mono.enabled, false)
    adaptive.toggled(true)
    compare(prefs.cursorAdaptive, true)
    compare(mono.enabled, true)
    mono.toggled(true)
    compare(prefs.cursorMonochrome, true)
}
```

- [x] **Step 2: Ejecutar y ver el fallo**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml 2>&1 | tail -30`
Expected: FAIL en los tests nuevos.

- [x] **Step 3: Implementar**

`shell/Prefs.qml`:
- Alias `cursorAdaptive` y `cursorMonochrome`.
- En `fontsSettings`: `property bool cursorAdaptive: true`, `property bool cursorMonochrome: false`.

`shell/pages/FontsPage.qml`:
- Quitar `property string cursorTab`.
- `cursorOptions`: solo `(page.fonts.cursorDesigns || [])`, sin `tab`, sin `cursorDesigns` duplicado; `label` = nombre del pack; la fila heredada primero. Eliminar `cursorLabel` si queda sin usos.
- `CursorCard`: quitar `tabs`, `currentTab`, `onCurrentTabChanged`; `emptyText: page.t("fonts.cursor.empty")`.
- En la sección Cursor, tras la fila del split, añadir dos `VitrailSettingRow` con `VitrailSwitch`:
  - Adaptativo: `icon: "palette"`, `objectName: "cursorAdaptiveSwitch"`.
  - Monocromático: `icon: "tonality"`, `objectName: "cursorMonochromeSwitch"`, `enabled: page.prefs.cursorAdaptive`, `opacity: page.prefs.cursorAdaptive ? 1 : 0.45`.

`kit/i18n/*.json` (los seis):
- `fonts.cursor.help`: explicar la lista única.
- `fonts.cursor.adaptive`: singular ("Adaptativo" / "Adaptive" / …).
- `fonts.cursor.adaptive.help`: "Tiñe el pack elegido con la paleta del fondo."
- `fonts.cursor.monochrome`: "Cursor monocromático".
- `fonts.cursor.monochrome.help`: "Un solo tono, sin acento en mano, resize o move. Requiere Adaptativo."
- `fonts.cursor.empty`: "No hay temas de cursor instalados".
- Borrar `fonts.cursor.normal` (ya no hay pestaña).

- [x] **Step 4: Ejecutar QML y lint**

Run: `tests/qml_smoke.sh`
Expected: todo `ok`, sin errores de `qmllint`.

- [ ] **Step 5: Commit**

```bash
git add shell/pages/FontsPage.qml shell/Prefs.qml kit/i18n tests/qml/tst_fonts_options.qml
git commit -m "feat(settings): one cursor list with adaptive and monochrome switches"
```

---

### Task 4: Documentación

**Files:**
- Modify: `docs/cursors.md`
- Modify: `README.md`
- Modify: `docs/manual-checks.md`
- Modify: `CHANGELOG.md`

- [x] **Step 1: Actualizar el texto**

- `docs/cursors.md`: la lista única, los dos interruptores, el nombre fijo `vitrail-cursor`, el alias estático, la migración y la tabla de propagación (incluye `hl.env`, `systemctl --user set-environment`, `dbus-update-activation-environment`). Dejar claro que una app XWayland ya abierta necesita reinicio.
- `README.md`: la sección de cursor, sin pestañas, con `vitrail-cursor`.
- `docs/manual-checks.md`: la comprobación del cursor, con `cat ~/.config/environment.d/20-vitrail-cursor.conf` → `XCURSOR_THEME=vitrail-cursor`.
- `CHANGELOG.md`: una línea en 1.0.0.

- [x] **Step 2: Verificar referencias muertas**

Run: `grep -rn "vitrail-Adwaita\|cursorThemeSplit\|Normal.*Adaptativo\|fonts.cursor.normal" docs README.md kit/i18n shell/pages/FontsPage.qml`
Expected: solo referencias históricas justificadas.

- [x] **Step 3: Ejecutar la suite completa**

Run: `python3 -m unittest discover -s tests && tests/qml_smoke.sh`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add docs/cursors.md docs/manual-checks.md README.md CHANGELOG.md
git commit -m "docs(cursor): single list, adaptive ink and the stable theme name"
```

---

## Seguimiento: el cursor blanco seguía blanco (2026-11-14)

**Síntoma:** con un pack blanco (`MaterialDesign-Light`) y Adaptativo encendido, el puntero seguía blanco en tema claro.

**Causa raíz:** `tint` elegía el cuerpo por **número de píxeles**; el borde negro anti-aliased del pack supera al relleno blanco, así que `surface` y `on_surface` caían invertidos (blanco → `surface`, casi blanco). La barra `xterm` fallaba al revés: su borde blanco casi igualaba al cuerpo negro.

**Arreglo:** el cuerpo se elige por **área interior** (`_interior`: mínimo alfa del píxel y sus cuatro vecinos), que ignora el borde que toca el fondo transparente. `TINT_VERSION` entra en el stamp para que los temas ya generados se reconstruyan.

**Tests:** `test_the_rim_touching_transparency_is_not_the_body`, `test_a_small_body_outweighs_more_transparent_rim_pixels`, `test_a_new_tint_version_forces_a_rebuild`.

**Estado:** aplicado a la sesión real (`fonts apply`); la flecha, la mano y la barra de texto usan el acento en todas las formas (ver el seguimiento siguiente). 950 tests Python, 93 comprobaciones QML.

## Seguimiento: todas las formas y la ruta que lee el compositor (2026-11-14)

- **Todas las formas toman el acento.** Antes la flecha usaba `on_surface` y
  solo mano/resize/move usaban `primary`. Ahora `cursor.build` pinta el cuerpo
  de **todas** las formas con `primary` (y `on_surface` en monocromático), con
  el borde `surface`. `TINT_VERSION = 3` obliga a reconstruir.
- **`~/.icons` es obligatorio.** Hyprland, libwayland-cursor y Xcursor no
  buscan `~/.local/share/icons`; sin el symlink `~/.icons/vitrail-cursor` el
  compositor caía al tema por defecto. `cursor.link_user` lo crea y
  `cursor.mirror_aliases` replica los nombres viejos.
- **El compositor cachea por nombre.** `hyprctl setcursor vitrail-cursor` no
  recarga un tema reconstruido. `fonts.apply` cambia a `Adwaita` y vuelve solo
  cuando el contenido cambió (`changed or linked`).
- **Iconos: una lista + Adaptativo + relleno.** `iconTheme` guarda el pack;
  `iconAdaptive` (on) construye `vitrail-icons-<pack>[@light|@solid]` con
  **solo las carpetas**; `iconFill` elige `pack`/`light`/`solid`. Migración de
  `vitrail-icons-X[@style]` y fuera las pestañas Normal/Adaptativo y las
  previews por estilo.

**Estado:** aplicado a la sesión real. 950 tests Python, 93 comprobaciones QML, `ruff` limpio.

## Seguimiento: el cursor antes de que corra ningún ajuste (2026-11-14)

- **`environment.d` llega tarde.** SDDM arranca Hyprland antes de que el gestor
  de usuario de systemd aplique `20-vitrail-cursor.conf`; la sesión nacía con el
  cursor por defecto.
- `fonts.apply` escribe `~/.config/hypr/vitrail-cursor.lua` con
  `VITRAIL_CURSOR_THEME`/`VITRAIL_CURSOR_SIZE` y `hl.env(...)`.
- `dots/.config/hypr/hyprland.lua` lo carga al principio (`pcall(dofile, …)`) y
  su bloque `hyprland.start` ejecuta `hyprctl setcursor` con esos valores, así
  que el compositor ya arranca con `vitrail-cursor`.
- Si el archivo no existe (primer login tras instalar), el bloque de arranque
  ejecuta `vitrail-apply-settings` una vez y así crea el tema y el archivo.
- Tests: `test_the_cursor_writes_the_hyprland_startup_file`,
  `test_the_hyprland_config_loads_the_generated_cursor`.

**Estado:** aplicado a la sesión real; `~/.config/hypr/vitrail-cursor.lua`
escrito y la config enlazada al repo. 950 tests Python, 93 comprobaciones QML.

## Seguimiento: importar y eliminar cursores .zip (2026-11-14)

- `fonts.ini` guarda `cursorImport` / `cursorRemove`; `fonts.apply` los procesa
  en `_apply_cursor_requests` y escribe `~/.cache/vitrail/cursors-result.json`.
- `icons.import_zip(..., cursors=True, root=~/.icons)` acepta un tema Xcursor
  (`<tema>/index.theme` + `cursors/`, o ambos en la raíz), valida el zip con
  las mismas comprobaciones de rutas/tamaño y deja copia previa en
  `~/.icons/.vitrail-backups`.
- `icons.remove_pack(..., cursors=True, roots=[~/.icons, datos/icons])` borra
  solo packs de usuario; los `vitrail-*` generados y los del sistema quedan.
- La página de cursor añade **Import .zip** / **Delete pack** en cada tarjeta,
  un `FileDialog`, el sondeo del resultado y `cursorUser` para habilitar el
  borrado. Traducido en los seis idiomas.

**Estado:** 950 tests Python, 93 comprobaciones QML, `ruff` limpio.

## Seguimiento: las carpetas de cualquier pack toman el color del sistema (2026-11-14)

- El `index.theme` generado copia las secciones `[tamaño/contexto]`
  (`Size`, `Type`, `Context`) del pack y de su cadena de herencia. Sin ellas
  GTK ignora el tema y cae a `Inherits`: se veían las carpetas originales del
  pack (azul genérico, magenta especiales).
- Los SVG simbólicos (`fill:currentColor`, los 16x16) toman el `primary`; antes
  se copiaban tal cual y se quedaban grises/azules.
- **Solid** es el relleno por defecto: el cuerpo de todas las carpetas es
  exactamente el `primary` del sistema, con el contorno y los símbolos del
  pack. `Pack` y `Light` siguen disponibles. `_normalise_icon` migra `pack` o
  vacío a `solid`.
- `ICON_VERSION = 2` entra en el stamp: los temas generados por el algoritmo
  anterior se reconstruyen.
- Tests: secciones del índice, fallback sin sección, carpeta simbólica y
  versión (`BuildStyleTests`, `TintStyleTests`).

**Estado:** aplicado; `gsettings icon-theme=vitrail-icons-Papirus@solid`. GTK
resuelve `folder` y `folder-documents` a
`~/.local/share/icons/vitrail-icons-Papirus@solid/places/{16,64}/…`, no a
Papirus. 950 tests Python, 93 comprobaciones QML, `ruff` limpio.

## Seguimiento: las carpetas especiales conservan su símbolo (2026-11-14)

- El `solid` pintaba también el símbolo oscuro de `folder-documents`
  (`#1d344f`, mismo tono que el cuerpo) y las especiales quedaban como una
  carpeta lisa. El tinte ahora solo toca tonos **saturados y cercanos en
  luminosidad** al ancla; los oscuros/neutros (documento, flecha, nota) se
  conservan.
- `folder_files` usa el pack primero y solo añade del padre los **stems** que
  el pack no tiene (`folder-open`); un `places/64/folder-documents` genérico
  del padre ya no puede sustituir al especial del pack.
- El target se limpia en cada reconstrucción (`ICON_VERSION = 5`), así no
  quedan duplicados viejos que GTK pueda elegir.
- Tests: `test_a_special_folder_keeps_its_dark_symbol`,
  `test_the_pack_special_folder_wins_over_a_parent_generic`,
  `test_a_rebuild_removes_stale_files`.

**Estado:** aplicado; `vitrail-icons-Papirus@solid/64x64/places` conserva
`#1d344f` en Documents/Downloads/Music/… y el cuerpo es `#854b70`. 950 tests
Python, 93 comprobaciones QML, `ruff` limpio.
