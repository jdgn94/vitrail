# Manual checks

Lo que necesita a una persona delante de la máquina: una sección por tarea
terminada, con los pasos y lo que se debe ver. Se marca al pasar; cuando una
sección está completa se borra.

## Bar element foundation (2026-11-21)

Código en `bar-foundation`. Verificar con el bar corriendo:

- [ ] Ajustes → Bar elements: aparece el bloque "Sample" con el selector "Siempre / Solo cuando está activo".
- [ ] Añadir `sample` a la barra desde el editor (clic derecho → Editar, mostrarlo): aparece el botón; al pasar el ratón el tooltip dice "Instantánea de ejemplo n.º N" y debajo el detalle.
- [ ] Un clic abre el popup con el número de la instantánea y la hora; el engranaje abre Ajustes → Bar elements ya desplazado al bloque "Sample".
- [ ] Con "Solo cuando está activo" el botón sigue visible mientras haya datos; ejecutar `chmod a-w ~/.cache/vitrail` y esperar un minuto tras caducar la caché (5 min): el botón desaparece; restaurar permisos y reaparece.
- [ ] Con el elemento fuera de la barra (oculto, el estado por defecto) no hay ningún proceso `python3 -m vitrail.sample` en `ps`.
- [ ] Rueda y clic central sobre el botón no rompen nada (la base los emite; el sample no los usa).

## Volume bar element (2026-11-21)

Código en `bar-volume-ui`. Con la barra corriendo, una aplicación reproduciendo sonido (un vídeo o `mpv`) y una segunda salida (auriculares, HDMI o USB):

- [ ] Mostrar `volume` desde el editor de la barra (está oculto por defecto): aparece el icono; el tooltip dice el nombre de la salida y debajo "N%" (o "Silenciado (N%)").
- [ ] Rueda arriba/abajo sobre el icono sube/baja el volumen en el paso de Ajustes → Bar elements → Volume (5 % por defecto); el tooltip y el icono siguen el cambio en pocos segundos; no pasa de 100 % ni baja de 0 %.
- [ ] Clic central silencia y vuelve a activar la salida; el icono cambia a "silenciado".
- [ ] Clic abre el popup: el deslizador maestro, con el nombre de la salida y su silencio, mueve el volumen real (`wpctl get-volume @DEFAULT_AUDIO_SINK@`); arrastrar no hace saltar el deslizador hacia atrás.
- [ ] Hay una fila por la aplicación que suena, con su icono, su deslizador y su silencio; mover el deslizador cambia solo el volumen de esa aplicación.
- [ ] El selector "Reproducir en" de la aplicación la manda a la otra salida y el sonido sale por ella (`pactl list sink-inputs short`); volver a elegir la primera la devuelve.
- [ ] Los selectores de dispositivo de salida y de entrada cambian el dispositivo por defecto (`wpctl status`); el interruptor "Silenciar el micrófono" silencia y activa el micrófono por defecto.
- [ ] Pausar el vídeo y activar Ajustes → Volume → "Ocultar flujos en silencio": su fila desaparece del popup; al reanudar, vuelve. Con la opción apagada la fila pausada sigue.
- [ ] "Mostrar el nivel" escribe el porcentaje junto al icono (y lo quita mientras está silenciado).
- [ ] El engranaje del popup abre Ajustes → Bar elements ya desplazado al bloque "Volume".
- [ ] Parar PipeWire (`systemctl --user stop pipewire pipewire-pulse wireplumber`, y `socket` si reactiva): el icono queda en gris/silenciado sin error, el popup dice que no puede leer el servidor de audio y no muestra deslizadores; rueda y clic central no hacen nada; al reiniciarlo todo vuelve solo.
- [ ] Con el elemento fuera de la barra no hay ningún proceso `python3 -m vitrail.audio` en `ps`.

## Updates bar element (2026-11-21)

Código en `bar-updates-ui`. Para falsear el conjunto sin tocar pacman, paru ni Flatpak, y arrancar la barra con esos programas delante:

```sh
mkdir -p /tmp/vitrail-fake-updates
printf '#!/bin/sh\necho "linux 6.12.1-1 -> 6.12.2-1"\necho "mesa 1:24.2.7-1 -> 1:24.3.1-1"\n' > /tmp/vitrail-fake-updates/checkupdates
printf '#!/bin/sh\necho "claude-desktop 5.1-1 -> 6.2-1"\n' > /tmp/vitrail-fake-updates/paru
printf '#!/bin/sh\nprintf "org.mozilla.firefox\\t135.0\\n"\n' > /tmp/vitrail-fake-updates/flatpak
chmod +x /tmp/vitrail-fake-updates/*
PATH=/tmp/vitrail-fake-updates:$PATH bin/vitrail-bar &
```

- [ ] Mostrar `updates` desde el editor de la barra (está oculto por defecto): aparece el icono con "4"; el tooltip dice "4 actualizaciones" y debajo las fuentes que tienen alguna.
- [ ] Con el modo "Solo cuando está activo" (el valor por defecto de este elemento en Ajustes → Bar elements) el botón desaparece a cero: dejar los tres scripts imprimiendo nada (solo `#!/bin/sh`), esperar un ciclo y el icono se va; volver a poner las líneas y reaparece.
- [ ] Clic abre el popup: un bloque por fuente con su recuento y sus filas `nombre  versión → versión`; con más de cinco filas en una fuente, las cinco primeras y "y N más".
- [ ] Cada bloque con filas ofrece "Actualizar": abre kitty con `sudo pacman -Syu`, `paru -Sua` o `flatpak update -y` según la fuente (nada se ejecuta desde la barra). El botón de refrescar vuelve a lanzar el snapshot.
- [ ] Renombrar `/tmp/vitrail-fake-updates/flatpak` y esperar: el bloque de Flatpak queda a cero con una línea tranquila que dice "flatpak is not installed", y las otras fuentes siguen listadas.
- [ ] Cambiar el nombre de un paquete por otro (mismo número total) no debe notificar; añadir una línea nueva sí, una sola vez, con el recuento, y su botón "Ver actualizaciones" abre este popup. El primer snapshot tras arrancar la barra no notifica aunque haya actualizaciones, y con el elemento fuera de la barra tampoco hay aviso.
- [ ] Con el elemento fuera de la barra no hay ningún proceso `python3 -m vitrail.updates` en `ps`.
- [ ] Ajustes → Bar elements → Updates: el intervalo (60 min por defecto) cambia cada cuánto se comprueba; desactivar AUR quita su bloque y no ejecuta paru; el ayudante AUR automático usa paru si está, si no yay, y la elección explícita aparece en el comando de "Actualizar".
- [ ] El engranaje del popup abre Ajustes → Bar elements ya desplazado al bloque "Updates".

## P2.2 — Fuentes, iconos y cursor (2026-11-04)

Código en `master` (`5936834..36fab6a`). La automatización ya está verde
(557 Python, 592 QML, 83 smoke, 40 instalador); lo que falta es el lado vivo.

### Antes de empezar

- [s] Desde la raíz del repo (los comandos `uv run` lo necesitan):
      `cd ~/Projects/vitrail`
- [x] El árbol está enlazado: `ls -l ~/.local/bin/vitrail-settings ~/.local/bin/vitrail-apply-settings`
      (deben apuntar a `bin/vitrail-settings` y `scripts/apply-settings.sh`).
- [x] El bar corre el código nuevo: `pkill quickshell` y vuelve a lanzarlo con
      tu atajo habitual. La ventana se abre con `./bin/vitrail-settings`.
- [x] El watcher está armado: `systemctl --user status vitrail-settings.path`
      → `active (waiting)`. El servicio que aplica es
      `vitrail-settings.service` (oneshot, escribe su log en el journal).
- [x] Los logs, en otra terminal: `journalctl --user -u vitrail-settings -f`

### 1. Fuente del sistema (shell + GTK/Qt)

- [ ] `./bin/vitrail-settings --category fonts --tab text`
- [ ] Cambia **System font** a otra familia instalada (por ejemplo `Inter`).
      Al elegirla, el texto de esta misma ventana cambia al instante.
- [ ] A los pocos segundos (el path unit aplica al guardar `fonts.ini`):
      `cat ~/.config/fontconfig/conf.d/50-vitrail-font.conf` →
      dos `<family>Inter</family>` (los alias `sans-serif` y `system-ui`) y la
      cabecera `Generated by Vitrail`.
- [ ] `fc-match sans-serif` → `Inter` (y no `Roboto`/`DejaVu`).
- [ ] Abre una app GTK nueva (`nautilus`): su texto sale con esa familia.
- [ ] El texto de la barra también cambió (misma familia que la ventana).

### 2. El tamaño de fuente no se toca (el bug crítico de la revisión)

- [ ] `gsettings get org.gnome.desktop.interface font-name` → p. ej. `'Sans 13'`
- [ ] Cambia **cualquier** preferencia, de fuentes o no (o
      `uv run python -m vitrail.cli config set fontSystem Inter`).
- [ ] `gsettings get org.gnome.desktop.interface font-name` → sigue con el
      **mismo tamaño** (`'Inter 13'`, no `'Inter 11'`). Si el número cambió,
      esto es una regresión y hay que avisar.

### 3. Fuente de consola (kitty)

- [ ] En la misma pestaña, cambia **Console font** a `Hack Nerd Font`.
- [ ] `cat ~/.config/vitrail/kitty-user.conf` → `font_family Hack Nerd Font`
      como primera línea, con `font_size` y `window_padding_width` intactos.
- [ ] Abre una ventana de kitty nueva: sale con esa familia; el tamaño sigue
      siendo el de la página Terminal.

### 4. Iconos de la shell (Material Symbols)

- [ ] Pestaña **Icons** → **Shell icons**: pasa de `Rounded` a `Sharp` y a
      `Outlined`. Los iconos del bar y de esta ventana cambian de forma al
      instante, sin aparecer texto en su lugar.
- [ ] `uv run python -m vitrail.cli config set uiIcons nope` → la shell cae en `Rounded` (no hay
      familia inventada) y el journal muestra
      `vitrail-fonts: refused: UI icons 'nope' is not one of rounded, sharp, outlined`.
- [ ] Vuelve a `Rounded` desde la página.

### 5. Pack de iconos de las apps

- [ ] `ls /usr/share/icons` y elige un pack que no sea `Adwaita`
      (por ejemplo `Papirus`). Si solo hay Adwaita, instala uno o sáltate este
      bloque anotándolo.
- [ ] `gsettings get org.gnome.desktop.interface icon-theme` → el elegido.
- [ ] Abre una app GTK nueva: usa los iconos de ese pack.

### 6. Cursor

- [ ] **Cursor**: elige un pack instalado (por ejemplo
      `Bibata-Modern-Classic`) y tamaño `32`. La lista es una sola: no hay
      pestañas Normal/Adaptativo.
- [ ] El puntero del compositor y las apps GTK cambian **en el acto** (lo
      aplica `hyprctl setcursor`).
- [ ] `cat ~/.config/environment.d/20-vitrail-cursor.conf` →
      `XCURSOR_THEME=vitrail-cursor` y `XCURSOR_SIZE=32`.
- [ ] Cierra sesión y vuelve a entrar: el cursor sigue siendo ese (se lee de
      `environment.d` en el arranque).

### 7. Un valor que no está instalado

- [ ] `uv run python -m vitrail.cli config set fontSystem "No Such Font"`
- [ ] El journal muestra
      `vitrail-fonts: refused: font 'No Such Font' is not installed; using Roboto`
      y `~/.config/fontconfig/conf.d/50-vitrail-font.conf` sigue nombrando
      `Roboto` (no se escribió el valor malo).
- [ ] Abre **Fonts & icons**: la página muestra `No Such Font` seleccionado (es
      lo guardado) pero el sistema sigue con Roboto.
- [ ] Restaura con `uv run python -m vitrail.cli config set fontSystem Inter`.

### 8. La página, en los dos temas

- [ ] Con `appearance=light` y `appearance=dark`, las tres pestañas
      (Text / Icons / Cursor) se ven como en
      `screenshots/p2.2-fonts-icons-cursor/fonts/<tab>/<tema>.png`, y los
      diálogos en `.../<tab>/dialog-<tema>.png`.
- [ ] Se puede recorrer entera con el teclado: `Tab` para entrar en cada
      selector, flechas para cambiar, `Enter` para abrir/cerrar.

### 9. Los mosaicos (los selectores nuevos)

- [ ] **Text → System font**: al pulsar se abre un diálogo con "Aa" dibujado
      en cada familia y el nombre debajo; abre en la familia elegida.
- [ ] Escribe `inter` en **Search**: la rejilla se queda con las que coinciden.
- [ ] Flechas mueven la selección, `Enter` elige, `Esc` y clic fuera cierran.
- [ ] **Icons → App icon pack**: el campo muestra cuatro iconos del pack y su
      nombre; el mosaico enseña ocho iconos por pack con el nombre debajo
      (Adwaita, Papirus, breeze…).
- [ ] **Cursor → Cursor theme**: cada celda enseña seis cursores reales de ese
      pack (flecha, mano, texto, redimensionar y mover; Bibata naranja/blanca,
      Adwaita…), no un icono genérico.
- [ ] El diálogo tiene el tamaño justo de su contenido (sin franja vacía
      abajo) y no se puede redimensionar; con más filas de las que caben, la
      rejilla hace scroll.
- [ ] **Shell icons** sigue siendo el selector horizontal; el icono que tiene a
      su izquierda cambia de forma al pasar de Rounded a Sharp a Outlined.
- [ ] Elegir en un mosaico aplica igual que antes (journal, `fc-match`, o
      `gsettings get … cursor-theme`).

### 10. Al terminar

- [ ] Todo lo anterior en verde.
- [ ] Marca P2.2 como hecha en `docs/roadmap.md`
      (`| P2.2 Fonts, icons, cursor …` → `| ✅ P2.2 …`) y borra esta sección.

## Cursor adaptativo: una lista y dos interruptores (2026-11-14)

- [ ] **Cursor → Adaptativo** encendido: el pack elegido se escribe en
      `~/.local/share/icons/vitrail-cursor` y se enlaza en `~/.icons/vitrail-cursor`;
      el puntero cambia a cuerpo `primary` (el acento del sistema) en **todas**
      las formas, con borde `surface`.
- [ ] **Import .zip**: en el picker de cursor, importa un tema Xcursor
      (`<tema>/index.theme` + `cursors/`). Aparece en la lista, se escribe en
      `~/.icons/<tema>` y el mensaje dice "Pack de cursor importado".
- [ ] **Delete pack**: elimina un pack de usuario (`~/.icons/...` o
      `~/.local/share/icons/...`); el mensaje dice "Pack de cursor eliminado".
      Los `vitrail-*` generados y los packs del sistema no se pueden borrar.
- [ ] **Monocromático**: activo, todas las formas pierden el acento y usan
      `on_surface`, con borde `surface`. Apagado, vuelven al acento. El
      interruptor está deshabilitado mientras Adaptativo esté apagado.
- [ ] Apaga **Adaptativo**: `vitrail-cursor/cursors` pasa a ser un symlink al
      `cursors/` del pack y el puntero es el original, sin copias.
- [ ] Cambia el fondo desde Wallpaper: en la siguiente aplicación de ajustes
      (unos segundos) el cursor se retinta solo, en el mismo nombre, y el
      compositor lo recarga (cambia a Adwaita y vuelve).
- [ ] **Sin cerrar sesión**: abre una app desde el lanzador o un atajo de
      Hyprland y comprueba que nace con el cursor actual (`hyprctl eval` y
      `systemctl --user set-environment` lo dejan listo).
- [ ] **Al iniciar sesión**: el cursor ya sale adaptado, sin esperar a que se
      aplique ningún ajuste. `cat ~/.config/hypr/vitrail-cursor.lua` muestra el
      tema y el tamaño, y `hyprland.lua` lo carga al principio; su bloque de
      arranque ejecuta `hyprctl setcursor`.
- [ ] **Primer inicio tras instalar** (sin `~/.config/hypr/vitrail-cursor.lua`):
      el bloque de arranque ejecuta `vitrail-apply-settings` una vez, crea el
      archivo y aplica el cursor.
- [ ] **X11 incluido**: con una app GTK en X11 abierta (o `xterm`/`xeyes`),
      cambia el diseño; el puntero sobre ella cambia sin reiniciarla.
      `xrdb -query | grep Xcursor` responde `vitrail-cursor`.
- [ ] Una app XWayland/Chromium **ya abierta** (Spotify): sigue con el cursor
      viejo hasta reiniciarla; tras reiniciarla usa el actual. Es la caché del
      proceso, no un fallo de la aplicación de ajustes.
- [ ] Con el split encendido, cada modo usa su pack bajo el mismo nombre:
      `readlink ~/.local/share/icons/vitrail-cursor/cursors` cambia al cambiar
      de tema claro/oscuro.
- [ ] Un pack borrado a mano mientras está elegido: el log dice `refused` y el
      cursor cae en Adwaita, sin dejar el puntero sin tema.

## Iconos adaptativos: carpetas (2026-11-14)

- [ ] **Icons → Adaptativo** encendido y **Folder fill → Solid** (por defecto):
      se crea `~/.local/share/icons/vitrail-icons-<pack>@solid` con solo las
      carpetas. El cuerpo de **todas** las carpetas (genéricas y especiales:
      Documentos, Música, Descargas…) es exactamente el `primary` del sistema;
      el contorno y los símbolos siguen siendo del pack.
- [ ] **Folder fill → Light** / **Pack**: cuerpo claro o el sombreado del pack
      con el tono movido al sistema. El picker es **una sola lista** de packs.
- [ ] El `index.theme` generado lleva las secciones `[64x64/places]`, etc.
      (`Size`, `Type`, `Context`); sin ellas GTK ignora el tema y vuelve al
      pack original.
- [ ] Las carpetas especiales del pack (Documents, Downloads, Music, Pictures,
      Desktop, Home…) conservan su símbolo; solo cambia el color del cuerpo.
      Un tema padre solo aporta los nombres que el pack no tiene
      (`folder-open`), nunca sustituye a `folder-documents`/`folder-download`.
- [ ] Los iconos simbólicos de 16x16 (`fill:currentColor`) también toman el
      `primary`; ya no se quedan grises/azules.
- [ ] Apaga **Adaptativo**: se aplica el pack original sin capa generada.
- [ ] Abre el gestor de archivos (Nautilus u Orca): las carpetas salen con el
      color de acento exacto. Si la app ya estaba abierta, reiníciala: los temas
      de iconos no se recargan en caliente.
- [ ] `gsettings get org.gnome.desktop.interface icon-theme` →
      `'vitrail-icons-<pack>@solid'`; `qt6ct.conf` lleva el mismo nombre.

## P2.8 — Flatpak y Firefox siguen la paleta (2026-11-04)

- [ ] `flatpak override --user --show` lista `xdg-config/gtk-3.0:ro`,
      `gtk-4.0:ro`, `fontconfig:ro`, `qt5ct/6ct:ro` y `xdg-data/icons:ro`.
- [ ] Abre la app Flatpak instalada después de un cambio de fondo: usa los
      colores y los iconos de la paleta.
- [ ] Arranca Firefox una vez si nunca lo has hecho; vuelve a cambiar el fondo
      y comprueba que aparece `~/.mozilla/firefox/*/user.js` con
      `toolkit.legacyUserProfileCustomizations.stylesheets` y
      `chrome/userChrome.css` con `--vitrail-surface`.
- [ ] Reinicia Firefox: la barra de pestañas, la de navegación y la URL siguen
      la paleta.
- [ ] Un flatpak o un Firefox ya abiertos mantienen los colores viejos hasta
      reiniciarse (documentado, no es un fallo).

## P3.1 + P3.2 — Capturas y grabación (2026-11-04)

> Sustituida por el overlay: la lista viva es la sección "Captura — overlay con
> área editable". Lo que queda aquí ya no se comporta así.

- [ ] Abre el panel de notificaciones: la fila de captura tiene tres botones
      (región, ventana, pantalla completa) y el de grabar; los tres abren el
      overlay.
- [ ] **Región**: arrastra el área en el overlay; `G` escribe
      `~/Pictures/Screenshots/Screenshot_*.png` y `⏎` la copia
      (`wl-paste --type image/png | file -`). Escape cancela sin crear fichero.
- [ ] **Ventana**: `W` y un clic sobre la ventana la capturan.
- [ ] **Pantalla completa**: `F` y `⏎` copian todo el layout.
- [ ] **Grabar**: el botón se pone rojo y en el bar aparece el chip de stop;
      para desde el chip y comprueba que el `.mp4` de `~/Videos/Recordings` se
      reproduce.
- [ ] Cambia las carpetas en **Bar → Captura** y repite: guarda donde dijiste.
- [ ] El audio solo se graba con el interruptor de audio encendido.
- [ ] **Editar**: `A` abre el editor en una ventana de cristal centrada; dibuja
      con cada herramienta, **Guardar** deja en la carpeta de capturas un PNG
      del tamaño exacto del área y **Copiar** lo pone en el portapapeles.
- [ ] **Color propio**: en el editor, el color propio abre la rueda de color,
      la barra de tono y el código hex; mover uno mueve los otros, un código
      inválido pone el campo en error y `⏎` usa el color. Lo mismo en
      Ajustes → Fondo → Color del sistema → personalizado.
- [ ] **Grabar región**: enciende *Grabar una región*; el botón de grabar abre
      el overlay y `⏎`/`R` graban esa zona (Escape cancela sin grabar).

## P6.3 — Instalación sin clonar y `vitrail update` (2026-11-04)

- [ ] En una máquina nueva (o un HOME de prueba), `curl .../bootstrap.sh | bash`
      clona en `~/.local/share/vitrail` y lanza el instalador.
- [ ] `vitrail update --check` imprime el commit instalado, el remoto y
      `behind`; con la rama al día, `behind` es `false`.
- [ ] Con un commit nuevo en `master`: `vitrail update` mueve el checkout y
      vuelve a lanzar el instalador con las opciones guardadas.
- [ ] Con cambios locales sin commitear, el update se niega; con `--force` los
      descarta (comprobado en una copia, no en la instalación buena).
- [ ] `vitrail update --dry-run` muestra el plan del instalador sin cambiar
      nada.

## v1 — paquete, update, desinstalación, GPU, snapshots, primer arranque

- [ ] `vitrail version` responde con versión, método y commit.
- [ ] `vitrail update --check` con la rama al día: `behind: false`; con un
  commit nuevo: `behind: true`.
- [ ] `vitrail update` en una copia de prueba mueve el checkout, toma snapshot
  (`vitrail snapshot list` lo enseña) y relanza el instalador.
- [ ] `vitrail doctor --report /tmp/r.txt` escribe el informe sin rutas de
  usuario y sale 1 si hay problemas.
- [ ] `./uninstall.sh --dry-run` no cambia nada; `./uninstall.sh` quita solo
  los enlaces; `--purge` mueve `~/.config/vitrail` a un backup.
- [ ] `pacman -Q mesa vulkan-radeon` (o el de tu GPU) coincide con lo que el
  instalador eligió; `--gpu nvidia` en `--dry-run` lo cambia.
- [ ] En una máquina sin fondo elegido, `vitrail welcome` pone uno, aplica la
  paleta y abre Appearance.
- [ ] `scripts/release.sh --dry-run` con el árbol limpio anuncia
  `vitrail-1.0.0.tar.gz`; con un cambio versionado se niega.
- [ ] `yay -S vitrail`/`vitrail-git` en una VM instala y `vitrail-install`
  enlaza el home; `vitrail update` entonces solo re-ejecuta el instalador.

### Diferidos (decide si lo quieres)

- Selector vacío si una clave guardada está vacía **y** la lista en vivo
  también (requiere que `fc-list` falle; arreglarlo duplicaría en Python los
  defaults que viven en QML).
- No hay un test de comportamiento de la línea de kitty de
  `scripts/apply-settings.sh`; la familia ya está cubierta por
  `fonts.console_family` y el script la escribe solo si no está vacía.

## Selector de archivos — uno solo, el GTK 4 del portal

- [ ] `hyprctl dispatch 'hl.dsp.exec_cmd("sh -c \"env | grep GTK_USE_PORTAL > /tmp/e\"")'`
      y `cat /tmp/e` → `GTK_USE_PORTAL=1` (lo pone `hyprland.lua`; una sesión
      nueva ya lo trae).
- [ ] Cierra y reabre el navegador con el lanzador: hereda ese entorno.
- [ ] En una web con `<input type="file">`, **Open file**: sale el mismo
      diálogo que al descargar (cabecera libadwaita, mosaico de carpetas,
      campo **Name**, barra de ruta), no el GTK 3 con **Enable preview**.
- [ ] `ls -l ~/.config/xdg-desktop-portal/hyprland-portals.conf` → apunta al
      repo y nombra `phrosh`; `pacman -Q xdg-desktop-portal-phosh` responde.
- [ ] La ventana de ajustes (importar fondo, fuente, cursor, VPN) abre ese
      mismo diálogo.

## Captura — overlay con área editable (2026-11-15)

- [ ] `pkill quickshell` y vuelve a lanzar la barra (`~/.local/bin/vitrail-bar &`).
- [ ] Pulsa el botón de captura de la barra (o el del panel): la pantalla se
      queda quieta y aparece la cruz, sin barra todavía.
- [ ] Arrastra un área: al soltar salen las asas y la barra de iconos fuera del
      área; el tamaño sale al lado del puntero. Mueve el área desde dentro;
      redimensiona desde cada asa y con `Tab` + flechas.
- [ ] Pasa el puntero por los iconos: cada uno dice qué hace. Pulsa uno con el
      ratón (Guardar, Cerrar) y comprueba que responde.
- [ ] `⏎`: no se crea ningún archivo en `~/Pictures/Screenshots` y la imagen
      está en el portapapeles (`wl-paste -t image/png > /tmp/a.png`).
- [ ] `G`: aparece `Screenshot_<fecha>.png` en la carpeta de `capture.ini`, y
      el portapapeles no cambia.
- [ ] `Ctrl`+`C` copia la imagen igual que `⏎` (no abre la paleta) y sale la
      notificación «Captura copiada» con el tamaño; `Ctrl`+`S` guarda igual que
      `G` y la notificación «Captura guardada» trae la ruta completa. `C` sin
      modificadores sigue abriendo la paleta; `Ctrl`+`G` y `Alt`+letra no hacen nada.
- [ ] Con una tarjeta (paleta, QR, traducción) `Ctrl`+`C` copia su contenido
      y avisa («Colores copiados», «Contenido del QR copiado», «Traducción copiada»).
- [ ] Cada acción avisa de lo que hizo: `P` («Área
      fijada»), `T` y una captura («Temporizador iniciado: Capturando en 3 s»; el
      aviso no debe salir en la imagen), `R` («Grabación iniciada» con la ruta del
      vídeo) y el chip rojo («Grabación guardada» con la ruta), `I` + `⏎`
      («Abriendo Google…»). `W` y `F` no avisan.
- [ ] `A`: se abre el editor con esa captura; `Esc` sin dibujar lo cierra al
      instante, con trazos pregunta antes de descartar.
- [ ] `R`: graban las mismas coordenadas; el chip rojo de la barra la para.
- [ ] `T` dos veces (3 s, 5 s) y `G`: la captura sale 3 o 5 s más tarde, sin la
      UI en la imagen.
- [ ] `W`: la ventana bajo el puntero se resalta; **un clic la captura en el
      acto** (mismo resultado que `⏎`).
- [ ] `F`: área = todos los monitores; `G` escribe la imagen del layout entero.
- [ ] Arrastra de un monitor al otro: el borde cruza, la barra no se sale del
      monitor donde empezó, y el archivo guardado tiene las dos partes (comparar
      con `magick compare`).
- [ ] Pasa el puntero por cada icono: todos dicen su tecla («Intro · …», «G · …»).
- [ ] Un área sin texto: *Copiar texto* y *Traducir* salen apagados y su tooltip
      dice «No se detectó texto»; sobre texto se encienden al medio segundo.
      El icono de QR solo aparece si el área contiene un código.
- [ ] `Q` sobre un QR: la tarjeta muestra el contenido, «copiado», y el botón de
      abrir (solo si es un enlace) lo abre en el navegador; `wl-paste` da el contenido.
- [ ] `L` sobre texto (con `translate-shell` instalado): tarjeta «Traduciendo…» y
      luego la traducción en el idioma de *Traducir a*; el botón copia; sin red:
      «La traducción falló»; sin `trans`: «translate-shell no está instalado».
- [ ] `C` (o el icono de la paleta) sobre un área con varios colores: una tarjeta
      «Buscando los colores principales…» se convierte en una cuadrícula de
      muestras con su código y su porcentaje, la más usada primero y sin tonos
      casi iguales repetidos. Un clic en una muestra la copia, aparece «Color
      copiado» y el color está en la pestaña de colores de `Super+P`; el botón
      de copiar de la tarjeta toma todas (`wl-paste` da un código por línea y
      salen en el historial). `Esc` vuelve a la barra de iconos con el área
      intacta. Ajustes → Barra → Captura → *Colores en la paleta* cambia cuántas
      muestras salen.
- [ ] `P`: el área queda fija encima de todo en su monitor. Arrástrala; la rueda
      la agranda o reduce; `Ctrl`+rueda cambia la opacidad; al pasar el puntero
      sale la barra con el deslizador de opacidad y la `x`. `Esc` (tras un clic),
      doble clic o la `x` la cierran; dos pins a la vez funcionan; los pins
      siguen cuando se cierra el overlay y no roban el teclado.
- [ ] Ajustes → Barra → Captura: *Detectar texto y códigos* apagado ofrece
      siempre Copiar texto, Traducir y QR; *Traducir a* cambia el idioma de `L`.
- [ ] `Esc`: no queda nada en pantalla.
- [ ] `O` con un área sobre texto: llega una notificación «Texto copiado» con
      una vista previa, y `wl-paste` devuelve el texto. Sobre un área sin texto:
      «No se encontró texto en el área» y el portapapeles no cambia.
- [ ] Ajustes → Barra → Captura → *Idiomas del reconocimiento de texto*: pon
      `eng` y `O` sobre texto en español lee peor; vacío vuelve a `spa+eng`.
- [ ] `I` (o el icono de la IA): el área se queda, en lugar de la barra sale un
      campo «Pregunta sobre esta imagen…»; `Esc` vuelve a la barra de iconos con
      el área intacta. Escribe una pregunta y `⏎`: el navegador predeterminado
      abre Google Lens con la imagen y la pregunta, y la vista de IA la
      responde; la pestaña *Modo IA* sigue con las dos. Nada se envía antes de
      `⏎`; en el overlay no queda nada.
- [ ] Ajustes → Barra → Captura → *Preguntar a la IA sobre un área* apagado: el
      icono desaparece y `I` no hace nada.
- [ ] `PRINT` (la tecla de captura) abre este mismo overlay; `Super+PRINT` lo
      abre con todo el layout ya seleccionado, y `⏎` lo copia.

## Portapapeles con estilo

- [ ] Copia texto con estilos de una página (Firefox: `Ctrl+A`, `Ctrl+C`);
      aparece un `.html` en `~/.cache/vitrail/clipboard/`. Copiar desde un
      gestor de contraseñas no guarda nada.
- [ ] `Super+V` y pasa el puntero por la fila: tras el retardo del tooltip sale
      una tarjeta junto al panel con la fuente, tamaño, peso, cursiva, color y
      listas del origen; una imagen muestra la imagen; texto plano, texto plano.
      Las flechas del teclado muestran la tarjeta de la fila elegida.
- [ ] `Enter` sobre esa fila: `wl-paste --list-types` ofrece `text/html` y
      `text/plain`; pegar en un editor de texto enriquecido conserva el estilo,
      en una terminal (`Ctrl+Enter`) pega texto sin salto final.
- [ ] Borrar la fila (✕) o vaciar el historial borra también el `.html`.
- [ ] Ajustes → Lanzador → Portapapeles: *Conservar el estilo* apagado no
      guarda HTML nuevo ni ofrece `text/html`; *Vista previa al pasar* apagado
      no abre la tarjeta.
