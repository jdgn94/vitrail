# Plan v1 — instalable, actualizable y distribuible

> **Hecho 2026-11-04** (13 tareas, commits `f3ebf87`…`c8361cd`).
> `vitrail version`/`update` por método, PKGBUILDs `vitrail`/`vitrail-git` +
> `vitrail-install`, `release.sh` con `git archive`, CI (tests + release al
> etiquetar), manual de usuario en `docs/`, `uninstall.sh`, `--repair`,
> `doctor --report`, GPU por vendor, snapshots btrfs/timeshift en `update`, y
> `vitrail welcome`. Versión `1.0.0`. Gates: 676 Python, 600 QML, 84 smoke,
> 40 instalador, 7 desinstalador, `ruff check` limpio, release `--dry-run` OK.
>
> **Pendiente del dueño:** crear y subir la etiqueta `v1.0.0` (el workflow de
> release se dispara con ella), elegir la licencia (los PKGBUILD usan
> `custom`) y publicar en el AUR; las comprobaciones vivas de
> `docs/manual-checks.md`.

> **Para el ejecutor:** tarea por tarea, con su test antes del código (TDD) y su
> commit. Marcar `[ ]` al terminar. Los planes anteriores de `.opencode_plans/`
> usan el mismo formato.

**Goal:** que Vitrail se pueda instalar sin clonar a mano, actualizar con un
comando seguro, publicar como paquete y mantener sin el árbol de trabajo del
autor.

**Estado de partida:** `bootstrap.sh` + `vitrail update` ya existen
(`89f04d4`); el instalador es idempotente y guarda `install.json`. Falta
empaquetado, releases, CI, documentación de usuario, desinstalación/repair,
GPU, snapshots y primer arranque.

**Spec:** `docs/roadmap.md` §1.0 (P6.1 docs, P6.2 packaging, P6.3 update) y §0.7
(P2.5 GPU, P2.9 snapshots). Decisiones del dueño: instalar sin clonar, update
contra la rama principal, excluir lock/login/teclado de este plan.

## Restricciones globales

- Sin dependencias de ejecución nuevas sin declararlas en `packages/*.txt` y en
  `PROVIDED_BY` (`tests/test_dependencies.py` es la puerta).
- Todo lo que corre en Python se prueba con `uv run python -m unittest`; el
  instalador, en `tests/install_test.sh` (sourced, sin root real).
- Nada de `~/.config` del usuario se sobrescribe sin copia; los tests usan
  `HOME`/`XDG_*` temporales.
- Las capturas de revisión no entran al repo (`screenshots/` ignorado); los
  fondos tampoco.
- Cada cambio de UI lleva sus cadenas en las seis lenguas y su preferencia en
  `prefs.map`.

## Review Focus

1. `vitrail update` corrido dos veces seguidas → la segunda no cambia nada y no
   relanza el instalador si no hay commit nuevo.
2. Una instalación por paquete (`/usr/share/vitrail`, sin `.git`) → `update` no
   intenta git, avisa que actualice con pacman y re-ejecuta el instalador.
3. `uninstall.sh` en un HOME con enlaces ajenos → solo borra enlaces que
   apuntan al root instalado; nunca toca `~/.config` sin `--purge`.
4. Snapshot antes de actualizar en btrfs sin `sudo` no interactivo → avisa y
   actualiza igual (o se niega con `--require-snapshot`).
5. Un tag de release con árbol sucio → `scripts/release.sh` se niega.

---

## Fase 1 — Versión y registro de instalación

### Tarea 1: `vitrail version` y `method` en `install.json`

**Files:** `vitrail/update.py`, `vitrail/cli.py`, `install.sh`,
`tests/test_update.py`

**Interfaces:**
- `update.installed_version(root) -> str` (ya existe; leer también
  `importlib.metadata` cuando no hay `pyproject.toml`).
- `update.state()["method"]` ∈ `git|package|copy`.
- CLI `vitrail version` imprime `vitrail <versión> (<method>, <commit7>)`.

- [ ] Test: `version` imprime la versión del `pyproject` y el método del
  registro; sin registro, `unknown`.
- [ ] `install.sh` escribe `method`: `git` si `ROOT_DIR` tiene `.git`, si no
  `package` cuando `ROOT_DIR` empieza por `/usr/`, si no `copy`; y `version`
  desde `pyproject.toml`.
- [ ] `vitrail update` incluye `version` en `--check`.
- [ ] Commit: `feat(update): report the installed version and method`.

### Tarea 2: `update` según el método

**Files:** `vitrail/update.py`, `tests/test_update.py`

- [ ] Test: con `method=package`, `update` no llama a git, re-ejecuta el
  instalador y avisa de pacman; con `method=copy`, informa y sale con 0 sin
  tocar nada.
- [ ] Test: `apply` de un estado sin `root` sigue dando error claro.
- [ ] Implementar `apply` por método y un mensaje por método en `--check`.
- [ ] Commit: `feat(update): respect how Vitrail was installed`.

---

## Fase 2 — Empaquetado AUR

### Tarea 3: `vitrail` (release) y `vitrail-git` (rama)

**Files:** `packaging/vitrail/PKGBUILD`, `packaging/vitrail-git/PKGBUILD`,
`install.sh` (modo `--system-install` si hace falta), `tests/test_packaging.py`

**Decisión:** el paquete no escribe en `$HOME`. Instala el árbol en
`/usr/share/vitrail` y una orden `vitrail-install` que corre
`install.sh --root /usr/share/vitrail` (el instalador ya enlaza en `$HOME`).
El estado queda `method=package`, así `update` sabe que actualiza pacman.

**Interfaces:**
- `pkgname=vitrail` / `vitrail-git`, `pkgver` desde `pyproject.toml`, sin
  `build()` (es un árbol de ficheros + Python estándar).
- `depends` desde `packages/base.txt` + `packages/hyprland.txt` (sin AUR de
  fuentes: las fuentes van en `optdepends`).
- `install` script: `post_install` avisa de `vitrail-install`, `post_upgrade`
  sugiere `vitrail update`.

- [ ] Test (Python): los PKGBUILD citan `pkgver` de `pyproject`, instalan en
  `/usr/share/vitrail`, no escriben en `$HOME` (grep de `$HOME` en la función
  `package()`) y declaran `vitrail-install`.
- [ ] `bin/vitrail-install`: `exec install.sh --root /usr/share/vitrail "$@"`
  (con guardia si ya hay una instalación git en `~/.local/share/vitrail`).
- [ ] `makepkg --printsrcinfo` en un contenedor Arch (CI) y `install_test.sh`
  con un `--dry-run` del paquete.
- [ ] Commit: `feat(packaging): an AUR package for the shell and the installer`.

### Tarea 4: `release.sh` y tarball

**Files:** `scripts/release.sh`, `tests/test_release.py`, `CHANGELOG.md`

- [ ] Test: `--dry-run` se niega con el árbol sucio; con árbol limpio imprime
  la versión, el nombre `vitrail-<v>.tar.gz` y el hash sin escribir nada fuera
  del directorio de salida.
- [ ] `release.sh` usa `git archive` (solo ficheros versionados), escribe
  `dist/vitrail-<v>.tar.gz` + `.sha256`, y **no** incluye
  `assets/wallpapers|adaptive|animation`.
- [ ] `CHANGELOG.md` con la sección `1.0.0` y el enlace a releases.
- [ ] Subir `version` en `pyproject.toml` a `1.0.0` cuando la v1 esté cerrada
  (tarea aparte al final).
- [ ] Commit: `feat(release): a reproducible tarball and a changelog`.

---

## Fase 3 — CI

### Tarea 5: tests en cada push

**Files:** `.github/workflows/tests.yml`, `tests/test_ci.py`

- [ ] Jobs: `python` (`astral-sh/setup-uv`, `uv run python -m unittest
  discover -s tests`, `uv run ruff check .`), `shell` (`bash -n` de los
  scripts, `bash tests/install_test.sh`), `qml` (contenedor
  `archlinux:latest`, `pacman -S --noconfirm qt6-declarative quickshell …`,
  `bash tests/qml_smoke.sh`).
- [ ] Test: los workflows son YAML válido, cada script que invocan existe y
  cada job tiene `runs-on`.
- [ ] Cache de uv; `timeout-minutes` en cada job.
- [ ] Commit: `ci: run the gates on every push`.

### Tarea 6: release al etiquetar

**Files:** `.github/workflows/release.yml`

- [ ] En `push` de tags `v*`: `release.sh`, publicar Release con el tarball y
  el `.sha256` (`softprops/action-gh-release`), y comprobar que el tag coincide
  con `pyproject`.
- [ ] Test: el workflow existe y referencia `scripts/release.sh` y `dist/`.
- [ ] Commit: `ci: publish the tarball on a tag`.

---

## Fase 4 — Documentación de usuario

### Tarea 7: índice y guías

**Files:** `docs/index.md`, `docs/install.md`, `docs/features.md`,
`docs/theming.md`, `docs/troubleshooting.md`, `README.md`,
`tests/test_docs.py`

- [ ] `docs/index.md` enlaza todo (roadmap, manual-checks, cursors, icons, apps,
  install, features, theming, troubleshooting).
- [ ] `install.md`: bootstrap, paquete, requisitos, primer arranque, update,
  uninstall; `theming.md`: paleta, fuentes/iconos/cursor, Flatpak/Firefox;
  `troubleshooting.md`: doctor, safe mode, logs (`journalctl --user -u
  vitrail-settings`), cómo reiniciar el bar.
- [ ] `tests/test_docs.py`: todos los enlaces relativos de `docs/*.md` y del
  README resuelven a ficheros existentes; las órdenes `vitrail <cmd>` citadas
  existen en el CLI (`cli` expone `<cmd>`).
- [ ] README: sección corta "Documentation" con el índice.
- [ ] Commit: `docs: a user manual for install, features and theming`.

---

## Fase 5 — Desinstalar y reparar

### Tarea 8: `uninstall.sh`

**Files:** `uninstall.sh`, `tests/uninstall_test.sh` (o dentro de
`install_test.sh`), `README.md`

**Interfaces:** lee `~/.local/share/vitrail/install.json` (`root`); recorre los
mismos enlaces que `link_dotfiles`/`link_binaries` y borra **solo** los que
apuntan dentro de `root`; deshabilita las unidades de Vitrail; `--purge` mueve
`~/.config/vitrail*` a `.backup/`; `--packages` lista (no borra) los paquetes
del manifiesto.

- [ ] Test (HOME temporal): un enlace ajeno y un fichero real en `~/.config` no
  se tocan; los enlaces a `root` sí; sin `--purge` los configs quedan.
- [ ] Runbook en el README (qué borra y qué no).
- [ ] Commit: `feat(install): uninstall what the installer linked`.

### Tarea 9: `install.sh --repair` y `vitrail doctor --report`

**Files:** `install.sh`, `vitrail/doctor.py`, `vitrail/cli.py`,
`tests/test_doctor.py`, `tests/install_test.sh`

- [ ] `--repair`: salta paquetes y preguntas, re-enlaza dotfiles/binarios,
  re-habilita unidades y reaplica la paleta (`vitrail theme apply`), con
  `--yes`.
- [ ] `vitrail doctor --report PATH`: escribe el informe saneado (sin rutas de
  usuario ni secretos) y sale 1 si algo falla.
- [ ] Test: `--repair --dry-run` no escribe; el informe no contiene `$HOME`.
- [ ] Commit: `feat: repair an installation and export a doctor report`.

---

## Fase 6 — GPU y snapshots

### Tarea 10: detección de GPU en el instalador

**Files:** `install.sh`, `packages/gpu.txt` (nuevo), `tests/install_test.sh`,
`README.md`

- [ ] `gpu_vendor()` con `lspci` (mismo criterio que `doctor`), flag
  `--gpu auto|amd|nvidia|intel`, paquetes por vendor en `packages/gpu.txt`
  (`mesa`, `vulkan-radeon`, `nvidia-open`, …), `--dry-run` lo muestra.
- [ ] Test con un `lspci` falso en `PATH`: cada vendor elige sus paquetes; un
  vendor desconocido avisa y sigue con `mesa`.
- [ ] Commit: `feat(install): pick the graphics stack by GPU vendor`.

### Tarea 11: snapshots antes de actualizar

**Files:** `vitrail/snapshot.py`, `vitrail/update.py`, `vitrail/cli.py`,
`tests/test_snapshot.py`, `docs/troubleshooting.md`

**Interfaces:**
- `snapshot.backend(run) -> "btrfs"|"timeshift"|""`.
- `snapshot.create(label, run) -> {"path"}` o `{"error"}`.
- `vitrail snapshot create|list`; `vitrail update` crea uno antes de mover el
  checkout, `--no-snapshot` lo omite, `--require-snapshot` aborta si no puede.

- [ ] Test: backend btrfs con un `run` falso llama a
  `btrfs subvolume snapshot -r / <ruta>`; timeshift usa `--create
  --scripted`; sin backend, `create` da error claro y `update` avisa.
- [ ] `snapshot list` lee `.snapshots/` o `timeshift --list` y ordena por
  fecha.
- [ ] Documentar restauración (btrfs y timeshift) en `troubleshooting.md`.
- [ ] Commit: `feat(update): snapshot before moving the checkout`.

---

## Fase 7 — Primer arranque

### Tarea 12: `vitrail welcome`

**Files:** `vitrail/welcome.py`, `vitrail/cli.py`, `install.sh`,
`tests/test_welcome.py`, `docs/install.md`

**Decisión:** sin página QML nueva. `vitrail welcome` elige el primer fondo de
`assets/wallpapers/` si el usuario no tiene uno, aplica la paleta
(`vitrail wallpaper apply`), abre los ajustes en Appearance y lista los
siguientes pasos (wallpaper, fuentes, barra). El instalador lo ofrece al final.

- [ ] Test: con prefs vacías elige un fondo y lo escribe; con fondo ya elegido
  no lo cambia; `--no-open` no lanza la ventana.
- [ ] `install.sh` pregunta al final (con `--yes` lo omite) y `doctor` sugiere
  `vitrail welcome` si no hay paleta.
- [ ] Commit: `feat: a guided first run`.

---

## Fase 8 — Cierre de la v1

### Tarea 13: versión, roadmap y manual

- [ ] Subir `version = "1.0.0"` en `pyproject.toml` y `CHANGELOG.md`.
- [ ] `docs/roadmap.md`: marcar P6.1/P6.2/P6.3 y lo de esta tanda cuando sus
  comprobaciones vivas pasen; añadir al roadmap lo que queda post-v1.
- [ ] `docs/manual-checks.md`: sección por tarea de este plan.
- [ ] Puertas completas: `bash tests/install_test.sh`,
  `bash tests/qml_smoke.sh`, `qmltestrunner`, `uv run python -m unittest
  discover -s tests`, `uv run ruff check .`, `shellcheck` si está.
- [ ] `bash tests/install_test.sh` al final y `git status` limpio.

---

## Orden y dependencias

```
1 → 2 → 3 → 4 → 5/6 → 7 → 8 → 9 → 10 → 11 → 12 → 13
```

- 3 y 4 pueden ir en paralelo con 5/6 (CI valida lo que ya existe).
- 8 depende de 1 (necesita `install.json` con `root`).
- 11 depende de 2 (update por método) para el snapshot antes de mover.
- 12 depende de 1 y de que `wallpaper apply` ya exista (sí).

## Fuera de este plan

Lock/login (excluido por el dueño), polkit, overlay de atajos, accesibilidad,
plugin API, Flatpak/AppImage lifecycle, los seis diseños de cursor (bloqueados
por vsthemes) y los detalles visuales de captura.
