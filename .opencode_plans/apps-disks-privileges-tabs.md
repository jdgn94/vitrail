# Plan — Aplicaciones, discos, diálogo de privilegios y scroll de tabs

> Estado: **planificado** (2026-11-07). No implementado todavía.
> Alcance: panel de Ajustes (nuevas categorías), ejecución privilegiada
> reutilizable y un arreglo del componente de tabs. Todo con el sistema de
> diseño de `kit/`, textos en los seis idiomas y pruebas.

## 1. Objetivos

1. **Aplicaciones**
   - Listar las apps instaladas, con buscador y datos útiles (nombre, versión,
     tamaño, descripción, icono).
   - Botón **Eliminar** solo para las que se pueden quitar desde aquí; las
     protegidas muestran por qué no.
   - Si la operación necesita contraseña, mostrar **nuestro diálogo** (el mismo
     estilo que el diálogo del sistema/polkit), nunca un prompt de terminal.
   - Segunda sección: **apps que arrancan con el sistema** y **en qué
     workspace** se abren; activar/desactivar, elegir workspace y monitor.
2. **Discos**
   - Listar discos/particiones instaladas y permitir elegir cuáles se
     **montan automáticamente** al iniciar, con punto de montaje y opciones
     seguras.
   - La operación privilegiada usa **el mismo diálogo de contraseña**, y ese
     diálogo es también el que aparece cuando el sistema pide `sudo`.
3. **Tabs con scroll horizontal**
   - Cuando las pestañas no caben, se pueden desplazar lateralmente (rueda,
     trackpad o arrastre) sin romper teclado, subrayado ni foco.
   - Si caben, no se activa ningún scroll.

## 2. No objetivos (por ahora)

- Desinstalar paquetes del sistema/AUR con resolución de dependencias
  conflictivas fuera de `pacman`.
- Formatear, particionar o cifrar discos; solo **montaje automático** de
  particiones existentes.
- Sustituir `hyprlock` o dibujar sobre la pantalla de bloqueo.
- Reemplazar `pacman`/`polkit`/`systemd`; se usan como base.
- Gestión de repositorios AUR o actualizaciones (ya existe `vitrail update`).

## 3. Arquitectura y patrones existentes

La ventana de Ajustes **no ejecuta comandos**. El patrón del proyecto es:

```
página QML  ──escribe──▶  fichero de petición en ~/.cache/vitrail/system/
                                  │
                     unidad .path / servicio oneshot
                                  │
                                  ▼
                    vitrail <acción> (Python)  ──▶ estado en un JSON
                                  │
página QML  ◀──poll──  estado / mensaje / error
```

Se reutiliza el patrón de `MonitorPage`/`monitors.py`, `wallpaperImport` y
`VpnConnection`:

- Petición con `nonce` para no repetir acciones.
- Estado con `phase` (`idle`, `running`, `done`, `error`), `message`, `jobs`.
- La página hace *poll* (700 ms) mientras espera y muestra el resultado.
- Nada de credenciales ni contraseñas en preferencias, logs o argv.

### 3.1 Privilegios: polkit primero, sudo con puente

Vitrail **ya es el agente polkit** (`PolkitAgent` en `bar/shell.qml`) y dibuja
las peticiones con `bar/dialogs/SystemDialog.qml`. Por tanto:

- Las acciones que puedan ir por **polkit** usan `pkexec`; el diálogo lo pinta
  la barra con el estilo de Vitrail y no hay que inventar nada.
- Para herramientas que exigen `sudo` (pacman directo, escritura de
  `/etc/fstab`, `mount`), se añade un **puente askpass**:

```
vitrail/privileged.py         # ejecuta con sudo -A y env SUDO_ASKPASS
scripts/vitrail-askpass.sh    # pide la contraseña al diálogo de Vitrail
```

Protocolo del puente (seguro y acotado):

1. `privileged.py` crea un id y un FIFO/directorio en
   `$XDG_RUNTIME_DIR/vitrail-askpass/<id>.req` (modo 0700).
2. `vitrail-askpass.sh` escribe `{id, prompt, action}` y espera
   `<id>.pass` (modo 0600) o `<id>.cancel`.
3. El **diálogo de contraseña** (componente de `kit/`, reutilizado por el
   panel y por la barra) lee la petición, muestra la acción, el campo secreto y
   las opciones Cancelar/Continuar; al aceptar escribe el secreto en el fichero
   y el helper lo lee **una vez**, lo borra y lo pasa a `sudo` por stdin.
4. Timeout (p. ej. 60 s) → cancelar y matar el hijo. Si no hay diálogo (sin
   barra), se cae a `pkexec` o se devuelve un error claro; nunca se deja un
   prompt colgado.

Reglas de seguridad:

- El secreto nunca se guarda en preferencias, estado, argv, entorno ni logs.
- Ficheros 0600 y borrado inmediato; el directorio 0700; nombres no adivinables.
- Una sola petición a la vez; cancelar mata el proceso privilegiado.
- Opción de usar el timestamp de sudo ya válido (no volver a preguntar si no
  hace falta) y de invalidarlo al terminar una operación sensible.
- Los tests del helper usan un `sudo`/`askpass` falsos y comprueban que el
  secreto no aparece en la salida.

**Componente**: extraer el diálogo de contraseña a `kit/composed/
VitrailPasswordDialog.qml` (o reutilizar `SystemDialog` con `secret: true`) y
usarlo en:
- la barra (polkit/Hyprland, ya existe),
- la ventana de Ajustes (overlay propio),
- el modo de edición si alguna acción lo necesita.

## 4. Fase 1 — Página **Aplicaciones**

### 4.1 Modelo y backend

Nuevo `vitrail/apps.py` (stdlib; sin dependencias nuevas):

```
python3 -m vitrail.apps list      # JSON: apps y autostart
python3 -m vitrail.apps remove    # --request <json> (pacman)
python3 -m vitrail.apps autostart # list | set | apply
```

- **Instaladas**: `pacman -Qqen` (explícitas nativas) + `pacman -Qqem`
  (extranjeras/AUR) con `pacman -Qi` para versión/tamaño/descripción y
  `pacman -Ql` solo si hace falta. Filtrar duplicados y paquetes internos del
  sistema.
- **Icono**: resolver por `.desktop` (`DesktopEntries`) o por nombre del
  paquete; si no hay, icono genérico.
- **Protegidas / no eliminables**: lista blanca negra explícita
  (`base`, `base-devel`, `linux*`, `linux-firmware`, `systemd`, `pacman`,
  `hyprland`, `quickshell`, `vitrail`, `networkmanager`, `pipewire`,
  `wireplumber`, `greetd`/`sddm`, el gestor de arranque, etc.).
  Además, si `pacman -Qi` dice que otro paquete lo requiere
  (`Required By` no vacío) o es dependencia, no se ofrece eliminar.
- **Eliminar**: `pacman -Rns <pkg>` para explícitos; nunca `-Rdd`.
  Confirmación previa en el diálogo de Vitrail (acción + paquete + qué se
  elimina); después ejecutar. Si falla, mostrar la salida resumida y no dejar
  el sistema a medias (pacman es transaccional).

### 4.2 Página `AppsPage.qml`

Categoría nueva **Aplicaciones** (grupo `system` en `shell/main.qml`), con dos
pestañas usando `VitrailTabs`:

- **Instaladas**
  - Buscador (`VitrailField`), lista virtualizada (no cargar cientos de filas
    de golpe) con icono, nombre, versión, tamaño y descripción.
  - Fila: botón **Eliminar** (o candado con tooltip «protegida»).
  - Al pulsar: `ConfirmRow`/diálogo con la acción; si se necesita contraseña,
    el diálogo de privilegios; estado `running` con spinner y mensaje final.
- **Inicio**
  - Lista de apps de arranque: `.desktop` de `~/.config/autostart` y
    `/etc/xdg/autostart`, más las gestionadas por Vitrail.
  - Interruptor activar/desactivar; selector de **workspace** (1..N) y
    opcionalmente monitor.
  - Las entradas del sistema se desactivan con un override en
    `~/.config/autostart` (`Hidden=true`), no se editan a mano.
  - Las gestionadas por Vitrail van a un documento propio
    (`~/.config/vitrail/autostart.json`) y se aplican al login.

### 4.3 Arranque con workspace

- Servicio de usuario `vitrail-autostart.service` (oneshot tras
  `graphical-session.target`) ejecuta `vitrail apps autostart apply`:
  - `hyprctl dispatch exec -- <comando>` por app (o `systemd-run --user` si
    se quiere desacoplar).
  - `hyprctl keyword windowrulev2 "workspace <N> silent, class:^(<clase>)$"`
    para abrir en el workspace elegido.
  - Reaplicar al cambiar la lista o el workspace (el servicio puede exponer
    `vitrail apps autostart apply` y la página pedirlo).
- No se edita `dots/.config/hypr/hyprland.lua` (fichero del dueño); todo va por
  `hyprctl` en runtime y el JSON de Vitrail.
- Al desactivar, se quita la regla con `hyprctl keyword unset`/recarga segura y
  se elimina del JSON.

### 4.4 Textos y prefs

- Nuevas claves en los seis `kit/i18n/*.json`:
  `apps.title`, `apps.tab.installed`, `apps.tab.startup`, `apps.search`,
  `apps.remove`, `apps.remove.confirm`, `apps.protected`, `apps.startup`,
  `apps.workspace`, `apps.workspace.help`, `apps.startup.applied`, …
- No hacen falta preferencias nuevas: el documento de autostart es JSON propio.
- Dependencias: `pacman` (base), `polkit`/`pkexec` (ya agente), `hyprctl`
  (Hyprland). Declarar en `packages/base.txt`/README solo si falta alguna.

## 5. Fase 2 — Página **Discos**

### 5.1 Modelo y backend

Nuevo `vitrail/disks.py`:

```
python3 -m vitrail.disks list     # lsblk -J + findmnt + fstab (solo lectura)
python3 -m vitrail.disks apply    # --request <json> (privilegiado)
```

- **Listar**: `lsblk -J -o NAME,TYPE,FSTYPE,LABEL,UUID,SIZE,MOUNTPOINT,TRAN,RO`
  y `findmnt` para el estado real. Solo particiones con sistema de ficheros
  soportado (ext4, btrfs, xfs, vfat, exfat, ntfs3, f2fs…). Excluir el disco de
  sistema, `/boot`, swap y dispositivos ópticos/loop.
- **Modelo**: por partición `{ uuid, label, fstype, size, currentMount,
  automount, mountPoint, options }`.
- **Montaje automático**: bloque gestionado en `/etc/fstab` entre
  `# BEGIN VITRAIL` y `# END VITRAIL`. Nunca tocar líneas ajenas.
  - Punto por defecto `/mnt/<label-saneado>`; editable y validado
    (sin `..`, sin solapar con `/`, `/boot`, `/home`…).
  - Opciones por defecto: `defaults,nofail,x-systemd.device-timeout=5` y
    `uid=`/`gid=`/`umask=` para vfat/exfat/ntfs (usuario actual).
  - Escribir con backup (`/etc/fstab.vitrail.bak`), escritura atómica y
    validación `findmnt --verify` + `mount -a`; si falla, **rollback** y error.
  - Alternativa considerada: unidades `.mount`/`.automount` en
    `/etc/systemd/system`; se prefiere `fstab` por familiaridad, con rollback.
- **Privilegios**: la petición la ejecuta el broker con `pkexec` (polkit) o el
  puente askpass; el diálogo muestra «Se necesita la contraseña para montar
  <disco> en <punto>».

### 5.2 Página `DisksPage.qml`

- Categoría **Discos** (grupo `system`).
- Lista de particiones con etiqueta, tamaño, sistema, montaje actual y un
  interruptor **Montar al iniciar**.
- Al activar: mini-formulario (punto de montaje, opciones avanzadas en un
  desplegable) y confirmación con el diálogo; estado de la operación.
- Avisos claros: disco de sistema (no permitido), partición ya montada a mano
  (se conserva hasta reiniciar), `nofail` para que un disco ausente no bloquee
  el arranque, y «esto no formatea nada».

### 5.3 Tests

- `tests/test_disks.py`: parseo de `lsblk`, selección de candidatos, generación
  del bloque fstab, punto válido, rollback ante `mount -a` fallido, no tocar
  líneas ajenas, idempotencia (activar dos veces no duplica).
- QML: lista, interruptor, validación del punto, estado de error.

## 6. Fase 3 — Scroll horizontal en `kit/VitrailTabs.qml`

Problema: hoy `implicitWidth: row.implicitWidth` y un `RowLayout` sin scroll;
con muchas pestañas se salen o se comprimen. (La captura muestra las categorías
del lanzador; hay que revisar si usa `VitrailTabs` o una tira propia y
reutilizar el componente.)

Diseño:

- Envolver la fila en un `Flickable` (o `ScrollView` horizontal) con:
  - `contentWidth: row.implicitWidth`
  - `interactive: contentWidth > width` (sin arrastre si caben)
  - `boundsBehavior: Flickable.StopAtBounds`, `clip: true`
  - `ScrollBar.horizontal` solo cuando hay overflow (o indicador de degradado
    en los bordes).
- El subrayado y el anillo de foco deben vivir **dentro** del contenido
  desplazable y seguir a la pestaña actual.
- `WheelHandler`/`WheelArea` sobre el componente: rueda vertical → scroll
  horizontal **solo si hay overflow**; si no cabe, no consume el evento (para
  que la página siga scrolleando).
- Teclado: izquierda/derecha siguen moviendo la pestaña y se hace
  `ensureVisible` de la actual; el foco no cambia.
- API compatible: mismas propiedades (`tabs`, `current`, `foreground`,
  `accent`, `selected`); `implicitWidth` pasa a ser el ancho disponible.
- Tests QML:
  - pocas pestañas → `contentWidth <= width`, sin scroll y rueda no consumida;
  - muchas → contenido mayor, rueda mueve `contentX`, límites respetados;
  - seleccionar una pestaña fuera de vista la trae a la vista;
  - subrayado/foco siguen a la pestaña tras el scroll;
  - teclado sigue funcionando.
- Aplicar al lanzador (categorías) y a cualquier tira de subcategorías de
  Ajustes; una sola implementación.

## 7. Fase 4 — Integración en Ajustes

- Nuevas categorías en `shell/main.qml` (grupo `system`):
  `{ key: "apps", glyph: "apps", label: section.apps }` y
  `{ key: "disks", glyph: "hard_drive", label: section.disks }`, con sus
  páginas en `shell/pages/` y lazy loading como el resto.
- La ventana inyecta el estado inicial (`--apps`, `--disks`) y recibe las
  peticiones por fichero; el broker las ejecuta con `vitrail`.
- Nuevo servicio/unidad que procesa peticiones (reutiliza el patrón
  `vitrail-settings.path`) y escribe el estado; la página hace *poll*.
- Todos los textos en los seis `kit/i18n/*.json`; las etiquetas de las
  categorías nuevas también.
- README: sección «Apps y discos», dependencias (`pacman`, `polkit`,
  `util-linux`, `systemd`), y nota de seguridad del diálogo.
- Comprobaciones manuales en `docs/manual-checks.md` (no se toca en este plan
  hasta implementar).

## 8. Orden de ejecución y commits

1. **Privilegios y diálogo** (base para 1 y 2)
   - `feat(privileges): a Vitrail password dialog and an askpass bridge`
   - Tests del protocolo, timeout, cancelación y no-filtración.
2. **Apps instaladas**
   - `feat(apps): list installed apps and remove the removable ones`
3. **Arranque y workspace**
   - `feat(apps): startup apps and their workspace`
4. **Discos**
   - `feat(disks): choose the disks that mount at boot`
5. **Scroll de tabs**
   - `fix(kit): horizontal scrolling tabs when they do not fit`

Cada fase: tests primero donde sea puro, seis idiomas, puertas completas
(`unittest`, `qmllint`, `qml_smoke`, `qmltestrunner`, `install_test`, `ruff`,
bar real) y sin tocar `screenshots/`, `assets/`, `dots/.config/hypr/
hyprland.lua` ni `docs/manual-checks.md`.

## 9. Riesgos y casos límite

- **Eliminar un paquete equivocado**: lista de protegidos + confirmación con
  nombre/versión + `pacman -Rns` (nunca `-Rdd`); si hay dependencias, se
  muestra y no se elimina.
- **`fstab` roto**: backup, escritura atómica, `findmnt --verify` y rollback;
  `nofail` por defecto; nunca tocar líneas ajenas.
- **Contraseña**: no persistir, borrar el secreto, timeout, cancelar mata el
  hijo; no mostrarla en logs/argv; directorio 0700 y ficheros 0600.
- **Sin agente polkit** (barra caída): error claro en la página, sin prompt
  colgado; para sudo, el diálogo de Ajustes es el respaldo.
- **Discos extraíbles**: `nofail` + timeout; no bloquear el arranque.
- **Apps con nombre/icono raro**: resolver por `.desktop`, fallback a texto;
  no romper la lista.
- **Tabs**: con overflow el foco/teclado no debe cambiar de pestaña al hacer
  scroll; la rueda no debe consumir eventos si no hay overflow.
- **i18n**: las seis lenguas; una clave que falte se ve como clave, no como
  texto vacío.

## 10. Criterios de aceptación

- [ ] Ajustes → **Aplicaciones** lista las instaladas, marca las protegidas y
      elimina las permitidas con confirmación y contraseña cuando haga falta.
- [ ] Ajustes → **Aplicaciones → Inicio** activa/desactiva apps y elige
      workspace; al reiniciar, se abren en ese workspace.
- [ ] Ajustes → **Discos** permite marcar particiones para montaje automático;
      el `fstab` resultante valida y sobrevive a un fallo con rollback.
- [ ] El diálogo de contraseña es el de Vitrail, se usa para sudo y polkit, y
      no filtra el secreto.
- [ ] `VitrailTabs` scrollea horizontalmente solo cuando no cabe, con rueda,
      arrastre, teclado y subrayado correctos; aplicado al lanzador.
- [ ] Todo en los seis idiomas, con tests y puertas verdes.
