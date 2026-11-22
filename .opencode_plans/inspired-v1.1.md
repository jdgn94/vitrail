# Inspirado en caelestia-shell y dots-hyprland (end-4)

> **Licencia decidida (2026-11-04): GPL-3.0** (`e801491`). Vitrail lleva
> `LICENSE`, `pyproject` y los PKGBUILD con `GPL-3.0-only`, y el README acredita
> a caelestia-shell y illogical-impulse. Desde ahora **se puede adaptar código
> de ambos con atribución**; este plan sigue prefiriendo ideas y flujos para no
> acoplar la pila.

## Qué se toma de cada uno

**caelestia-shell** (Quickshell, la misma pila que Vitrail):
- configuración **global + por monitor** (`barconfig`, `monitorConfigDir`);
- **dashboard** con pestañas (media, rendimiento, tiempo) abierto desde la barra;
- **presets de esquema** de color y unidades;
- servicios separados por dominio (`Audio`, `Brightness`, `Colours`, `Hypr`,
  `Nmcli`, `Players`, `Recorder`, `Screens`, `Wallpapers`, `Weather`);
- **reloj de escritorio** y **visualizador de audio** en la capa de fondo;
- lista de fondos **dentro del lanzador**.

**end-4 / illogical-impulse**:
- **ajustes buscables** (`settings.qml` + `GlobalStates`), con descripciones;
- **cheatsheet de atajos** generado del config de Hyprland;
- organización por **familias de panel** y estados globales;
- scripts por dominio (colores, cava, keyring, miniaturas).

**No se toma:** su lock (fuera de alcance por decisión del dueño), su launcher
(Vitrail tiene uno), su plugin C++ (acopla a una versión de Qt/Quickshell), el
chat de IA, Nix ni su instalador.

## Restricciones globales

- Todo visual sale de `kit/`; nada de colores, duraciones o tamaños literales.
- Cada preferencia nueva: `prefs.map`, `shell/Prefs.qml`, unidad de path,
  README y las seis lenguas, en el mismo cambio.
- Todo programa nuevo, en `packages/*.txt` + `PROVIDED_BY` + tabla del README.
- Componente nuevo de kit → galería; helper puro → test QML.
- Sin dependencias nuevas de ejecución salvo las que se declaren aquí.
- Las capturas de revisión y los fondos del dueño no se versionan.

## Review Focus

1. Monitor desconectado con overrides propios → la barra sigue en el primario,
   sin errores de binding ni elementos duplicados.
2. Sin red o API caída en el tiempo → la pestaña muestra «sin datos», no rompe
   el panel ni bloquea el hilo de UI.
3. Esquema de color no soportado por la versión de matugen instalada → se cae
   al esquema por defecto y el log lo dice.
4. Búsqueda de ajustes sin resultados → estado vacío claro; `Esc` limpia y
   devuelve el foco.
5. Cheatsheet sin Hyprland corriendo → muestra los atajos del config estático o
   un aviso, nunca una ventana vacía.

---

## Fase 1 — Configuración y temas (bajo riesgo, alto valor)

### Tarea 1: presets de esquema de color — **hecha (`3b3842f`)**

**Files:** `vitrail/colors.py`, `vitrail/prefs.map`, `shell/Prefs.qml`,
`shell/pages/ColorsPage.qml`, `README.md`, `tests/test_colors.py`

**Interfaces:** prefs `scheme` (default `tonal-spot`) y `contrast` (0, 0.5, 1);
`colors.generate(..., scheme, contrast)` pasa `--scheme`/`--contrast` a matugen
(versión sin soporte → se ignora con aviso); la página Colors los ofrece como
`VitrailSelect`/`VitrailSegmented` y regenera la paleta al cambiar.

- [ ] Test: un esquema desconocido cae a `tonal-spot`; el comando de matugen
  lleva los flags; la paleta se regenera al escribir la preferencia.
- [ ] Implementar, migrar claves y añadir textos en las seis lenguas.
- [ ] Commit: `feat(colors): matugen scheme and contrast presets`.

### Tarea 2: overrides por monitor — **hecha**

**Files:** `vitrail/prefs.map` (`barMonitors`), `shell/Prefs.qml`,
`bar/shell.qml`, `bar/BarItems.qml`, `shell/pages/MonitorsPage.qml`,
`shell/barview.js` (nuevo), `tests/qml/tst_barview.qml`,
`tests/test_prefs_map.py`

**Interfaces:** `barMonitors` es un objeto JSON `{"DP-1": {"edge": "top",
"size": 40, "panelSize": 420}}`; `BarView.forMonitor(json, name, defaults)`
devuelve la configuración efectiva; `bar/shell.qml` la aplica por pantalla.

- [ ] Test QML: sin override devuelve los valores globales; con override solo
  cambia ese monitor; JSON inválido → globales.
- [ ] Test Python: la clave está en `bar.ini` y el README.
- [ ] Página Monitors: una sección por salida con borde/tamaño/panel.
- [ ] Commit: `feat(bar): per-monitor layout overrides`.

### Tarea 3: ajustes buscables — **hecha**

**Files:** `shell/main.qml`, `shell/SearchIndex.qml` (o `shell/search.js`),
`shell/pages/*` (etiquetas de sección), `tests/qml/tst_search.qml`,
`kit/i18n/*.json`

**Interfaces:** `Search.matches(index, query)` devuelve
`[{category, tab, label}]`; el índice se construye de categorías + pestañas +
filas (las páginas exponen `searchEntries` cuando hace falta); el campo vive en
la cabecera, `↑/↓` mueven, `Enter` abre la categoría y pestaña.

- [ ] Test: buscar «cursor» lleva a Fonts/Cursor; «snapshot» no existe → vacío;
  buscar sin acentos coincide.
- [ ] Implementar el índice, el campo y el salto; `Esc` limpia.
- [ ] Commit: `feat(settings): search every page`.

---

## Fase 2 — Dashboard y datos

### Tarea 4: servicio de tiempo — **hecha**

**Files:** `vitrail/weather.py`, `vitrail/cli.py` (`weather state|set-location`),
`bin/vitrail-weather` (o CLI), pref `weatherLocation`, `weatherUnits`,
`tests/test_weather.py`, `packages/base.txt` (curl ya está)

**Interfaces:** Open-Meteo (`api.open-meteo.com`, sin clave) + geocoding; caché
de 15 min en `~/.cache/vitrail/weather.json`; `state()` devuelve
`{city, temp, code, humidity, wind, forecast[]}` o `{"error"}`; sin red, la
última caché.

- [ ] Test con un HTTP falso: parseo, caché, error de red, unidades.
- [ ] Declarar la dependencia si se usa `curl`; si es `urllib`, ninguna.
- [ ] Commit: `feat(weather): a keyless weather service`.

### Tarea 5: recursos — **hecha**

**Files:** `vitrail/resources.py`, `vitrail/cli.py` (`resources state`),
`tests/test_resources.py`

**Interfaces:** lee `/proc/stat`, `/proc/meminfo`, `/sys/class/thermal/*`,
`/proc/net/dev` y `statvfs`; `state()` devuelve CPU %, RAM usada/total, temp,
red y disco; sin dependencias externas.

- [ ] Test con ficheros fixture: porcentajes, primera lectura sin delta, red.
- [ ] Commit: `feat(resources): cpu, memory, temperature and disk`.

### Tarea 6: dashboard — **hecha**

**Files:** `bar/dashboard/Dashboard.qml`, `Tabs.qml`, `CalendarTab.qml`,
`WeatherTab.qml`, `PerformanceTab.qml`, `MediaTab.qml`,
`bar/shell.qml` (popup `dashboard`), `bar/BarItems.qml` (botón/reloj),
`gallery/`, `tests/qml/tst_dashboard.qml`, i18n

- [ ] El reloj abre el dashboard; `Esc`/clic fuera cierra; teclado completo.
- [ ] Pestañas: calendario (mes, semana), tiempo (estado + 4 días),
  rendimiento (CPU/RAM/temp/disco/red) y media (reusa `MediaPanel`).
- [ ] Test: pestaña por defecto, cambio con flechas, estado sin datos.
- [ ] Commit: `feat(dashboard): weather, performance and media at a glance`.

---

## Fase 3 — Atajos y extras

### Tarea 7: cheatsheet — **hecha**

**Files:** `vitrail/binds.py` (`hyprctl binds -j` → filas),
`bar/launcher` (modo `?` o nuevo), `bar/shell.qml`, `tests/test_binds.py`,
`tests/qml/tst_binds.qml`, i18n, README

- [ ] Parser: modmask → `Super+Shift`; descripción, dispatcher y args legibles;
  sin Hyprland, lee el config estático si está disponible o avisa.
- [ ] Overlay buscable desde un atajo (pref `keybindShortcut`, default
  `Mod+S`? decidir) y desde el launcher.
- [ ] Test: modmask, teclas especiales, binds sin descripción, JSON inválido.
- [ ] Commit: `feat(binds): a searchable keybind cheatsheet`.

### Tarea 8: visualizador — **hecha** (A/B/C; círculo y ondas pendientes)

**Files:** `bar/background/*` (capa `vitrail-background` ya existe?),
`packages/base.txt` (`cava` solo si se hace el visualizador), i18n

- [ ] Reloj de escritorio por monitor, tamaño/posición en `bar.ini`, apagado
  por defecto.
- [ ] Visualizador con `cava` (nueva dependencia declarada) o se descarta si no
  se quiere el paquete.
- [ ] Commit: `feat(background): desktop clock and audio visualiser`.

### Tarea 9: fondos en el lanzador

**Files:** `bar/launcher/commands.js` (modo `wallpaper`), `bar/launcher/*`,
`tests/qml/tst_launcher_*`

- [ ] Modo `wallpaper:` con la lista de `assets/wallpapers`, vista previa y
  cambio con transición; reusa `vitrail wallpaper`.
- [ ] Commit: `feat(launcher): pick a wallpaper from the launcher`.

---

> **Ejecutado 2026-11-04 por orquestación (una instancia por tarea, sesión
> compartida entre tareas relacionadas).** Commits: `3b3842f` (esquemas),
> `56ae623` (bar por monitor), `ac0a84b` (búsqueda), `f53f35c` (tiempo),
> `2805392` (recursos), `20d4287` (dashboard), `1aeeb3a` (atajos),
> `3147136` (visualizador con A/B/C), `663126d` (efectos de fondo),
> `1f48f8f` (fondos por monitor), `b23e998` (fondos en el lanzador),
> `837fee6` (ajustes y textos del tiempo). Gates finales: 789 Python,
> 683 QML, 86 smoke, 40 instalador, 7 desinstalador, ruff limpio.

## Orden de ejecución

```
Fase 1: 1 (hecha) → 2 → 3
Fase 2: 4 → 5 → 6
Fase 3: 7 → 8 (visualizador A/B/C + variantes) → 9
Fase 4: 10 (efectos) → 11 (fondos por monitor) → 12 (lanzador)
```

Cada tarea: test primero, commit propio y las puertas completas
(`install_test`, `uninstall_test`, `qml_smoke`, `qmltestrunner`,
`unittest discover`, `ruff check`).

- 1, 2 y 3 son configuración/ajustes y no dependen del dashboard.
- 4 y 5 son datos puros (Python) y alimentan 6.
- 7 es independiente; 8 y 9 son extras al final.
- Cada tarea: test primero, commit propio, puertas completas
  (`install_test`, `qml_smoke`, `qmltestrunner`, `unittest`, `ruff`).

## Decisiones tomadas

1. **Licencia**: GPL-3.0-only (`e801491`), con atribución en el README.
2. **Atajo del cheatsheet**: `Mod+/`.
3. **Tiempo**: automático por IP (Open-Meteo), con ciudad editable si falla.
4. **Visualizador**: **se quieren los tres** (A barras gruesas al pie,
   B barras finas con reflejo, C panel suave) más estilos futuros (círculo,
   ondas) elegidos por el usuario. Se implementa como **variantes de un mismo
   componente** (`VitrailVisualiser` con `variant`), con `cava` en el
   manifiesto; la galería y la página de ajustes ofrecen la elección.
   Maquetas en `screenshots/inspired/visualiser-{a,b,c}.png` (no versionadas).


---

## Fase 4 — Fondos al estilo JaKooLit (Arch-Hyprland / Hyprland-Dots)

Revisado `JaKooLit/Hyprland-Dots` (GPL-3.0) en `config/hypr/UserScripts/` y
`config/rofi/`; el instalador `Arch-Hyprland` no trae los scripts, los baja de
Dots. Dos mecanismos distintos:

1. **Selector** (`WallpaperSelect.sh` + `config-wallpaper.rasi`): rofi con
   miniaturas, por monitor, transición de swww (fps, tipo, duración, bezier) y
   `wallust` para regenerar la paleta tras el cambio.
2. **Efectos** (`WallpaperEffects.sh` + `config-wallpaper-effect.rasi`): un menú
   con 18 recetas de ImageMagick aplicadas al fondo actual (blanco y negro,
   desenfoque, carboncillo, bordes, relieve, marcos, negativo, óleo, posterizar,
   polaroid, sepia, solarizar, enfocar, viñeta, viñeta negra, zoom cuadrado),
   escribe `~/.config/hypr/wallpaper_effects/.wallpaper_modified`, lo aplica en
   el monitor enfocado y **regenera la paleta con la imagen modificada**.
3. **Aleatorio** (`WallpaperRandom.sh`) y **cambio automático**
   (`WallpaperAutoChange.sh`): temporizador que cambia cada N minutos.

Qué tiene ya Vitrail: biblioteca y selector con miniaturas, tipo (imagen/SVG/
vídeo), transición, aleatorio, intervalo, importación, `awww`/`mpvpaper` y la
paleta derivada del fondo. Falta lo que hace distinto a JaKooLit: **efectos**
sobre el fondo actual y **por monitor**.

### Tarea 10: recetas de efectos — **hecha**

**Files:** `vitrail/effects.py`, `tests/test_effects.py`, `vitrail/prefs.map`
(`wallpaperEffect`), `shell/Prefs.qml`, `shell/pages/WallpaperPage.qml`,
`kit/i18n/*.json`, `README.md`

**Interfaces:**
- `effects.RECIPES: dict[str, list[str]]` — nombre → argumentos de `magick`
  (nunca `eval`: listas, sin shell).
- `effects.apply(source: Path, name: str, target: Path, run=run_text) -> Path | None`;
  `"none"` y desconocido → el original.
- Caché `~/.cache/vitrail/effects/<hash>-<name>.png` (hash del fichero de
  origen), para no repetir el `magick` en cada aplicación.
- `wallpaper.apply`/`wallpaperd` usan el fichero efectivo: si hay efecto y el
  fondo es una imagen, la paleta se genera del **derivado** y el sello incluye
  el efecto (cambiarlo regenera).
- Página Wallpaper: selector de efecto con vista previa del elegido.

- [ ] Test: las recetas son listas de argumentos; `none`/desconocido devuelve el
  original; la caché se reutiliza; el sello incluye el efecto.
- [ ] Vídeo/SVG: el efecto se omite con aviso (mpvpaper no lo admite); el SVG se
  rasteriza primero si se quiere efecto.
- [ ] Cadenas en las seis lenguas para los 18 nombres (o los 6 principales y el
  resto con nombre técnico).
- [ ] Commit: `feat(wallpaper): image effects from the current wallpaper`.

### Tarea 11: fondos por monitor — **hecha**

**Files:** `vitrail/prefs.map` (`wallpaperMonitors`), `vitrail/wallpaperd.py`,
`vitrail/wallpaper.py`, `shell/pages/MonitorsPage.qml`, `README.md`,
`tests/test_wallpaperd.py`

- [ ] JSON `{"DP-1": {"wallpaper": "...", "effect": "blur", "display": "fill"}}`;
  `wallpaperd` aplica por salida (`awww img -o <out>`) y cae al global.
- [ ] Test: sin override usa el global; override por nombre; monitor ausente no
  rompe el resto.
- [ ] Commit: `feat(wallpaper): per-monitor wallpapers`.

### Tarea 12: selector desde el lanzador — **hecha**

- [ ] Modo `wallpaper:` con miniaturas y efectos, la idea del rofi de JaKooLit
  pero con componentes de kit; teclado completo.
- [ ] Commit: `feat(launcher): pick a wallpaper and an effect`.

**Atribución:** las recetas de ImageMagick y el flujo selector→transición→paleta
están inspirados en JaKooLit/Hyprland-Dots (GPL-3.0); el README ya acredita a
los proyectos de los que Vitrail aprende y se añadirá este.
