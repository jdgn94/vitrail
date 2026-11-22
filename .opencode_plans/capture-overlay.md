# Captura de pantalla con área editable (estilo GNOME)

> **Estado:** diseño aprobado por el dueño (2026-11-14). Pendiente: plan de
> tareas en detalle y ejecución.
>
> Sustituye al flujo `slurp` → `grim` para el botón de la barra y el panel.
> `PRINT` sigue siendo el atajo rápido de siempre.

## Spec (del dueño, 2026-11-14)

- Al lanzar la captura no se guarda nada: se **congela** la pantalla y aparece
  un **área editable** (asas, mover, guías) con una **barra de opciones fuera
  del área**.
- Barra, en este orden: **Capturar ⏎** (por defecto), **Guardar**,
  **Anotar**, **Grabar área**, **Temporizador**, **Ventana**, **Pantalla
  completa**, **Cerrar**. Todas las opciones entran; el antiguo "copiar" pasa a
  ser **Guardar**.
- **⏎ captura y copia directamente** al portapapeles (no escribe archivo);
  **Guardar** es la acción que escribe en el disco.
- La barra va **debajo del área si cabe**; si no, encima.
- **Todo por teclado**: atajos de las acciones, mover/redimensionar y ajuste
  fino del área.
- **Modo ventana**: clic sobre una ventana la captura (en esta misma pasada).
- Se reutiliza lo que ya hay: `wf-recorder -g`, el chip de grabación de la
  barra, `captureDir`/`captureRecordDir`/`captureRecordAudio` de `capture.ini`,
  `swappy`.
- **Una captura de área puede cruzar varios monitores.**
- `PRINT` abre el overlay (y `Super+PRINT` lo abre con todo el layout ya
  seleccionado). El atajo rápido con `slurp` desapareció: la capa de captura
  necesita la barra, así que las dos teclas la piden por IPC.
- **Sin ajustes**: este comportamiento es fijo; no hay claves nuevas ni página
  nueva.

## Decisiones (llamadas mías)

- **Congelado de verdad, no solo de vista**: se guarda un PNG por monitor antes
  de mostrar nada, y el archivo final sale de ese PNG (no de un `grim -g`
  posterior). Así lo que se ve es exactamente lo que se guarda aunque haya
  vídeo o notificaciones detrás.
- **Dónde vive cada cosa**: la geometría y el recorte, en Python
  (`vitrail/capture.py`, con sus tests); el área, las asas y la barra, en QML
  (`bar/capture/`); la matemática pura de la selección, en
  `bar/capture/capture.js` para poder probarla con `qmltestrunner` como
  `kit/frame.js`.
- **Backend nuevo en `vitrail/capture.py`**: `freeze` (PNG por monitor + tabla
  de monitores), `grab` (compone el área desde los congelados con `magick`,
  copia y/o escribe), `record --geometry` (geometría explícita en vez de
  `slurp`) y `window_at(x, y)` (`hyprctl clients -j`, la ventana bajo el
  puntero). `shot` se retira con el flujo viejo; `PRINT` no pasa por aquí.
- **Superficies**: una capa `Overlay` por monitor con foco de teclado
  exclusivo, como `bar/session/AlertLayer.qml` y `bar/MonitorEditLayer.qml`.
  La selección vive en coordenadas del layout (las de `hyprctl monitors -j`), y
  cada superficie dibuja la parte que le toca; al cruzar monitores se dibuja el
  contorno en cada uno y las asas en el monitor que las contiene.
- **Escala**: cada congelado está en píxeles físicos. El recorte convierte la
  intersección de cada monitor (`lógico × scale`) y compone el lienzo a la
  escala del monitor donde empezó la selección. Es la regla de GNOME y evita
  inventar una escala mixta.
- **La barra no se oculta**: sale en el congelado (y por tanto en el archivo).
  Ocultarla es un cambio aparte; hoy no hay mecanismo para esconder todas las
  superficies.
- **Temporizador** (nada → 3 s → 5 s): cuenta atrás antes de ejecutar la acción
  pedida. En **captura** se espera con la UI oculta y **se vuelve a congelar**
  la misma área (para abrir un menú); en **grabación** cuenta antes de arrancar
  `wf-recorder`.
- **Si el portapapeles rechaza la imagen** se avisa (`capture.copyFailed`): la
  captura ocurrió, sólo no se copió.
- **⏎ y Guardar no escriben lo mismo**: ⏎ copia (sin archivo, sin carpeta
  tocada); Guardar escribe `Screenshot_<fecha>.png` en `captureDir` y no toca el
  portapapeles. Anotar escribe un temporal, abre `swappy` y deja que swappy
  guarde donde quiera.
- **Modo ventana**: `window_at(x, y)` sobre `hyprctl clients -j` da el
  rectángulo de la ventana bajo el puntero; al elegirla se rellena el área, que
  sigue siendo editable. `W` entra y sale del modo.
- **Panel de la barra**: el botón de la barra y los de región/ventana del panel
  abren el overlay, igual que el de pantalla completa (que lo abre con `F` ya
  elegido); el de grabar usa `open record` si `captureRecordRegion` está
  encendido.
- **Errores**: si `grim` falla o no hay monitores, se cierra el overlay y se
  avisa por la notificación del sistema (`vitrail.notify`); nunca se queda la
  pantalla atrapada.
- **El panel se cierra antes de congelar**: abrir la captura desde el panel de
  la barra cierra el popup y espera una pasada de dibujo (~120 ms) antes de
  `freeze`; si no, el panel entero saldría dentro de la foto. El botón de la
  barra y el IPC hacen la misma espera aunque el popup ya esté cerrado.
- **Teclado en una sola superficie**: el foco exclusivo lo toma solo la
  superficie del **monitor donde se abre la captura** (el del puntero); las
  demás escuchan ratón y nada más, como `DesktopEditLayer` con el monitor
  enfocado. Esa misma superficie hospeda la `CaptureToolbar`, recortada dentro
  de su monitor, y la conserva aunque la selección cruce a otro.
- **Estado inicial sin área**: al abrir se ve sólo la cruz. Arrastrar crea el
  área y entonces aparece la barra, fuera de ella; con nada seleccionado, `⏎` y
  `F` capturan todo el layout (`bounds`) y `Tab` (asas) no hace nada (no hay
  área sobre la que actuar). Un clic suelto no deja un área de 0×0.
- **La superficie toma el ratón con `mask: Region { item: gestures }`**: sin
  `mask` Quickshell deja la capa *click-through* y el área no se puede dibujar
  (comprobado en vivo: los eventos no llegaban). La barra va declarada después
  de la zona de gestos en el fichero, para que sus botones reciban el clic en
  lugar del arrastre.
- **Modo ventana con un clic**: entrar con `W` (o el botón), la ventana bajo el
  puntero se resalta y **un clic la captura en el acto** con la acción por
  defecto (`⏎`/copiar, o grabar si se abrió para grabar). No hace falta
  arrastrar después, aunque el área quedaría editable si no se confirmara.
- **`open record` cambia la acción primaria**: `⏎` graba el área y el botón de
  grabar sale resaltado; `R` graba siempre. El botón de grabar del panel usa
  este modo cuando `captureRecordRegion` está encendido; si no, graba la
  pantalla completa de inmediato, como hoy.
- **`F` es todo el layout**: todos los monitores, igual que el `shot full` de
  hoy, rellenando el área con `bounds`.
- **Se retiran `captureCopy` y `captureAnnotate`**: con el comportamiento fijo
  nadie los lee (el botón de pantalla completa del panel también pasa por el
  overlay). Se van de `prefs.map`, `Prefs.qml`, `BarPage.qml`, las seis lenguas
  y el test de prefs. Quedan `captureDir`, `captureRecordDir`,
  `captureRecordAudio` y `captureRecordRegion`.
- **Se retira `shot`**: `capture.py` deja de invocar `slurp` y el panel ya no
  llama al comando viejo. El modo ventana pasa a `window_at(x, y)` sobre
  `hyprctl clients -j` (la ventana bajo el puntero, no la activa).

## Tareas

### 1. Backend: congelado, recorte y grabación con geometría

- `freeze(runtime, run)`: `hyprctl monitors -j` → por monitor `grim -o NAME`
  a `$XDG_RUNTIME_DIR/vitrail/capture/frozen-<name>.png`; devuelve
  `{"monitors": [{name,x,y,scale,width,height,image}], "bounds": {x,y,w,h}}`.
  Nada de `slurp`; limpia congelados previos.
- `crop_pieces(selection, monitors)`: puro, sin procesos. Por monitor
  intersectado devuelve `{image, crop (x,y,w,h en píxeles físicos),
  offset (x,y en el lienzo)}` y el tamaño del lienzo en la escala de referencia.
- `grab(selection, monitors, runtime, copy, directory, run, copy_run)`:
  `magick` recorta cada pieza y compone (`-composite`), escribe
  `Screenshot_<fecha>.png` si se pide carpeta, copia con `wl-copy` si se pide,
  borra los temporales y devuelve `{"path"?}` o `{"error"}`.
- `record(..., geometry=None)`: con geometría explícita no llama a `slurp`.
- `window_at(x, y, run)`: rectángulo de la ventana bajo el puntero desde
  `hyprctl clients -j` (posición del layout, sin decodificar el monitor).
- CLI: `freeze`, `grab --geometry WxH+X+Y [--copy|--save]`,
  `record start --geometry WxH+X+Y`, `window x y`, `status`. Se retiran `shot`
  y `geometry()` con sus casos (y sus tests), que ya no tienen llamador.
- Tests (`tests/test_capture.py`): tabla de monitores y piezas con escala
  distinta, selección que cruza monitores, recorte en el mismo monitor,
  geometría normalizada (arrastrar hacia arriba/izquierda), `magick` invocado
  con el orden correcto, `grab` que solo copia / solo escribe, `record` con
  geometría sin `slurp`, `window_at` con dos clientes solapados, error si `grim`
  falla.

### 2. `bar/capture/capture.js` (geometría pura)

- `normalize(drag)`, `move(rect, dx, dy, bounds)`, `resize(rect, handle, dx,
  dy, bounds, min)`, `handleAt(point, rect, tolerance)`, `inside(point, rect)`,
  `toolbarPlacement(rect, screen, size)` (debajo si cabe, si no encima, si no
  dentro), `label(rect)`, `windowRect(client)`.
- Test: `tests/qml/tst_capture_geometry.qml` (arrastres en las ocho
  direcciones, límites del monitor, mínimo 1×1, barra que salta arriba al
  quedarse sin sitio debajo, etiqueta `1280 × 720`).

### 3. Overlay

- `bar/capture/CaptureOverlay.qml`: una superficie por monitor (patrón de
  `bar/MonitorEditLayer.qml`), imagen congelada a tamaño de la superficie,
  velo fuera del área, cruz de guías, área con borde y asas, etiqueta `W×H`
  junto al puntero, captura del ratón; **el foco exclusivo (`Exclusive`) solo
  en la superficie del monitor inicial, `None` en las demás**.
- `bar/capture/CaptureToolbar.qml`: compuesta solo de `kit/base`
  (`VitrailSurface`/`VitrailButton`/`VitrailText`), variante `glass`, tamaño
  `sm`, tooltips como todo elemento de la barra; acciones por señales. Vive en
  la superficie del monitor inicial; abajo-centro mientras no hay área y fuera
  del área (debajo si cabe, si no encima) después.
- Teclado: `⏎` capturar, `G` guardar, `A` anotar, `R` grabar, `T` temporizador,
  `W` ventana, `F` pantalla completa, `Esc` cerrar, flechas mover 1 px
  (`Shift` 10 px), `Tab`/`Shift+Tab` asa siguiente (solo con área), asas con
  flechas cuando hay un asa activa. `⏎`/`F` sin área capturan todo el layout.
- Modo ventana: al entrar, la ventana bajo el puntero se resalta con
  `hyprctl clients -j`; clic la toma como área (editable después).
- Al confirmar: se oculta el overlay, se pide el `grab` (o `record`) al
  backend y se cierra; si venía de la barra/panel, no queda nada en pantalla.
- Test: carga del componente en `tests/qml_smoke.sh` y `tst_capture_geometry`.

### 4. Enganches

- IPC `capture` en `bar/shell.qml`: `open`, `open window`, `open record`,
  `cancel`, con el modo en el argumento. `open record` deja `⏎` grabando y
  resalta ese botón. Todo `open` cierra el popup y espera ~120 ms antes de
  congelar.
- Botón de la barra, fila de captura del panel y botón de pantalla completa del
  panel: sin cambios de aspecto, todos pasan por el overlay (región/ventana, o
  `F`). El botón de grabar usa `open record` si `captureRecordRegion`, si no
  graba todo de inmediato.
- Retirada de `captureCopy`/`captureAnnotate`: `prefs.map`, `shell/Prefs.qml`,
  `shell/pages/BarPage.qml`, las seis `kit/i18n/*.json` y `tests/test_prefs.py`.
  Sin claves nuevas ni página nueva.
- i18n: claves nuevas de la barra en las seis lenguas (`capture.action.shot`,
  `.save`, `.annotate`, `.record`, `.timer`, `.window`, `.full`, `.close`,
  `.size`, `.failed`).

### 5. Puertas y documentación

- `uv run python -m unittest discover -s tests`, `bash tests/qml_smoke.sh`,
  `qmltestrunner` con `tst_capture_geometry.qml`, `bash tests/install_test.sh`.
- `README.md` (párrafo de captura), `docs/features.md`, `CHANGELOG.md`,
  `docs/manual-checks.md` (sección nueva) y capturas en `screenshots/`.

## Límites

- Los congelados son PNG temporales en `$XDG_RUNTIME_DIR/vitrail/capture/`;
  una captura de 4K son unos pocos MB y se borran al terminar.
- La barra sale en la foto (decisión de arriba), y las notificaciones abiertas
  también.
- Con monitores de escalas distintas, el archivo se compone a la escala del
  monitor donde empezó la selección: la zona del otro monitor se reescala.
- Los vídeos se graban en vivo (`wf-recorder`), no del congelado, y **en un
  solo monitor**: `wf-recorder` no acepta un área que cruce salidas, así que un
  área de varios monitores se recorta al monitor donde empieza (el log de
  `wf-recorder` lo diría igual). Las capturas sí cruzan.
- `wf-recorder` quiere la geometría en su forma (`x,y wxh`), no la de `grim`
  (`WxH+X+Y`); la traducción vive en `vitrail/capture.py`.
- `slurp` ya no lo usa nadie (`PRINT` pasa por el overlay), así que sale del
  manifiesto y de los PKGBUILD: `grim` es el único programa de captura.
