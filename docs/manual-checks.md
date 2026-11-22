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

## Disks bar element (2026-11-21)

Código en `bar-disks-ui`. Con la barra corriendo y un lápiz USB desmontado (o una tarjeta SD):

- [ ] Mostrar `disks` desde el editor de la barra (está oculto por defecto): con una unidad conectada aparece el icono; el tooltip dice su etiqueta (o "N unidades") y debajo el espacio usado/total.
- [ ] Con el modo "Solo cuando está activo" (el valor por defecto de este elemento en Ajustes → Bar elements) el botón desaparece al desenchufar la unidad y vuelve al enchufarla.
- [ ] Clic abre el popup: una tarjeta por unidad con su etiqueta, su tamaño, la barra usada/total y el punto de montaje ("Sin montar" si lo está). El engranaje abre Ajustes → Bar elements ya desplazado al bloque "Disks".
- [ ] **Montar** ejecuta `udisksctl mount -b /dev/sdX` (sin root); la tarjeta pasa a "Montada en /run/media/…" y la barra de espacio se llena en el siguiente ciclo.
- [ ] **Abrir** solo está activo con la unidad montada y abre su punto de montaje en el gestor de archivos del escritorio.
- [ ] **Desmontar** la deja "Sin montar"; **Expulsar** solo está activo mientras está desmontada (`udisksctl power-off`) y la unidad puede retirarse.
- [ ] Cada acción que el estado prohíbe (Montar con la unidad montada, Desmontar y Abrir sin montar, Expulsar con ella montada) está desactivada y debajo se lee el motivo; mientras una acción corre, todos los botones esperan.
- [ ] Provocar un fallo (por ejemplo, `chmod -x $(command -v udisksctl)` o montar una unidad ya montada por otro usuario): el popup muestra una línea tranquila con el texto devuelto, sin cerrarse ni romper la barra; restaurar el permiso.
- [ ] Ajustes → Bar elements → Disks → "Unidades que ignorar": añadir la etiqueta o el UUID de una unidad conectada quita su tarjeta y, si era la única, el botón de la barra; quitarla de la lista la devuelve.
- [ ] "Montar las unidades nuevas automáticamente" está apagado por defecto. Encendido, enchufar una unidad desmontada la monta sola en un ciclo; no se vuelve a montar mientras siga conectada, y al desenchufarla y volver a enchufarla se monta otra vez.
- [ ] Con el elemento fuera de la barra y el automontaje apagado no hay ningún proceso `python3 -m vitrail.disks` en `ps`; con el automontaje encendido sí hay uno, aunque el elemento no esté en la barra.

## Containers bar element (2026-11-22)

Código en `bar-containers-ui`. Con la barra corriendo y docker o podman instalado
(`docker ps -a --format json` o `podman ps -a --format json` responde):

- [ ] Mostrar `containers` desde el editor de la barra (está oculto por defecto): aparece el icono con el número de contenedores en marcha; el tooltip dice el motor y el número ("docker · 2 en marcha") y debajo los contenedores fijados que están parados, si hay alguno.
- [ ] Clic abre el popup: una fila por contenedor con su nombre, su imagen recortada, su estado y salud y sus puertos cuando los publica. Los fijados van primero y su chincheta está encendida.
- [ ] Un contenedor parado ofrece **Iniciar** y **Registros**; uno en marcha ofrece **Detener** y **Registros** (nunca los dos de estado a la vez). Pulsar **Iniciar** lo arranca y el recuento de la barra sube en el siguiente ciclo; pulsar **Detener** lo para y el recuento baja.
- [ ] **Registros** abre `docker logs --tail 200 <id>` (o `podman logs --tail 200 <id>`) en la terminal de la barra (kitty), sin ejecutar nada más.
- [ ] La chincheta de una fila la fija o la suelta; el popup la reordena al instante y el engranaje abre Ajustes → Bar elements ya desplazado al bloque "Containers".
- [ ] Ajustes → Bar elements → Containers: el motor (`Automático`, `docker`, `podman`) cambia el que consulta el snapshot; con `docker` elegido en una máquina sin docker el popup muestra una línea tranquila con el motivo, no una lista vacía.
- [ ] "Contenedores fijados": añadir un nombre lo pone primero; quitarlo lo devuelve al orden del motor. Un contenedor renombrado pierde su fijado (el nombre antiguo queda listado como parado); volver a fijar el nombre nuevo lo arregla.
- [ ] Con el modo "Solo cuando está activo" (el valor por defecto de este elemento) el botón desaparece en una máquina sin docker ni podman: no hay motor que contar. El popup, si se abriera por IPC, dice que se buscaron docker y podman.
- [ ] Con el elemento fuera de la barra no hay ningún proceso `python3 -m vitrail.containers` en `ps`.

## Peripherals battery bar element (2026-11-22)

Código en `bar-battery-ui`. Con la barra corriendo y al menos un ratón, teclado,
auriculares o mando inalámbrico emparejado que UPower vea (`upower -e` lo lista,
`upower -i <ruta>` enseña su porcentaje):

- [ ] Mostrar `peripherals` desde el editor de la barra (está oculto por defecto): aparece el icono con el porcentaje más bajo de los dispositivos vistos; el tooltip dice su nombre y su nivel, y debajo los demás dispositivos ("Nombre 30% · Nombre 80%") o, si solo hay uno, su estado.
- [ ] Con dos dispositivos, uno descargándose al 55 % y otro cargándose al 30 %, la barra muestra 55 % (el que se descarga manda); el icono del que se carga solo aparece cuando no queda ninguno descargándose.
- [ ] Clic abre el popup: una fila por dispositivo con su icono de tipo, su barra de nivel, su porcentaje y su estado ("En carga", "Descargando", "Llena"), con "Quedan 4 h 30 min" cuando UPower lo sabe. El engranaje abre Ajustes → Bar elements ya desplazado al bloque "Peripherals battery".
- [ ] Ajustes → Bar elements → Peripherals battery → *Dispositivos que ocultar*: marcar "Ratón" quita su fila del popup y, si era el más bajo, la barra pasa al siguiente porcentaje; desmarcarlo lo devuelve. "Auriculares" oculta el tipo `headphones` y "Mando" el `gamepad`.
- [ ] *Aviso de batería baja* (20 % por defecto, de 5 a 50): con un dispositivo descargándose por debajo del nivel, el icono y el número cambian al tono de aviso; por encima vuelven al normal. Un dispositivo cargándose no avisa aunque esté bajo (lleva el rayo y el tono primario).
- [ ] Sin ningún dispositivo que informe de un porcentaje y con el modo "Solo cuando está activo" (el valor por defecto de este elemento), el botón desaparece de la barra; con "Siempre" se queda con el icono vacío y el tooltip "Ningún periférico informa de su batería". El popup, sin dispositivos, muestra una sola línea tranquila, no una tarjeta vacía.
- [ ] Parar UPower (`systemctl stop upower`, y `systemctl start upower` al terminar): la barra se vacía, el popup dice que no puede leer las baterías y no se rompe nada.
- [ ] Con el elemento fuera de la barra no hay ningún proceso `python3 -m vitrail.battery` en `ps`.
## Brightness bar element (2026-11-22)

Código en `bar-brightness-ui`. Con la barra corriendo, un portátil (panel interno) o un monitor externo por DDC/CI, y `hyprsunset` instalado:

- [ ] Mostrar `brightness` desde el editor de la barra (está oculto por defecto): aparece el sol; el tooltip dice el nombre del monitor principal y debajo "N%".
- [ ] Rueda arriba/abajo sobre el icono sube/baja el brillo del monitor principal en el paso de Ajustes → Bar elements → Brightness (5 % por defecto); no pasa de 100 % ni baja de 0 %, y una vuelta rápida no lanza una orden por muesca (el escritor del OSD las agrupa).
- [ ] Clic abre el popup: una fila por monitor con su deslizador y su porcentaje. En el panel interno mueve el brillo real (`brightnessctl get`); en el externo, el valor DDC (`ddcutil getvcp 10 --bus N`).
- [ ] **Monitor externo sin DDC** (o con el bus i2c sin permisos): su fila sale sin deslizador, con el motivo ("Esta pantalla no responde por DDC/CI" o el de acceso), nunca un deslizador muerto; los demás monitores siguen funcionando.
- [ ] **Luz nocturna**: el interruptor enciende el filtro a la temperatura del deslizador; `hyprctl hyprsunset temperature` responde el valor. Bajarlo calienta la pantalla; subirlo a 6500 K la deja neutra.
- [ ] **Horario fijo que cruza medianoche** (por ejemplo 20:00 → 07:00): con el interruptor encendido, a las 20:00 la pantalla se calienta y a las 07:00 vuelve a neutra; el popup muestra "Se enciende a las 20:00" o "Se apaga a las 07:00" según la hora. Dejar la barra corriendo y el popup cerrado: el cambio ocurre igual (una orden `vitrail.nightlight apply` por minuto como mucho).
- [ ] **Horario de sol**: elegir "Del atardecer al amanecer" muestra el atardecer y el amanecer que trae el tiempo; el siguiente cambio coincide con esa hora. Sin datos de sol, se usan las horas fijas y el popup lo dice.
- [ ] Apagar el interruptor devuelve la pantalla a neutra en el acto (`hyprctl hyprsunset identity get` → `true`).
- [ ] Ajustes → Bar elements → Brightness: el paso de la rueda, el interruptor, la temperatura y el horario (modo + horas) cambian lo mismo que el popup; una hora inválida marca el campo en error y no se guarda.
- [ ] Sin `hyprsunset`, el popup muestra una línea tranquila con el error y los monitores siguen ajustándose; no rompe la barra.
- [ ] El engranaje del popup abre Ajustes → Bar elements ya desplazado al bloque "Brightness".
- [ ] Con el elemento fuera de la barra y el interruptor apagado no hay ningún proceso `python3 -m vitrail.nightlight` en `ps` (el brillo de los monitores lo lee el OSD, que solo consulta `vitrail.cli brightness list` cuando hace falta); con el interruptor encendido solo corre el `apply` del horario una vez por minuto.

## Resources bar element (2026-11-22)

Código en `bar-resources-ui`. Para tener un proceso ocupado, y deshacerlo: `yes > /dev/null &` (y `kill %1` al terminar); para uno que ignora SIGTERM: `bash -c 'trap "" TERM; sleep 600' &`.

- [ ] Mostrar `resources` desde el editor de la barra (está oculto por defecto): dos barras finas (CPU y RAM) que se mueven; en una barra vertical caben sin desbordar. En Ajustes → Bar elements → Resources, *En la barra* cambia a solo CPU, solo RAM y números; cada opción se aplica al momento.
- [ ] El tooltip dice «CPU x % · RAM y % · t °C» y debajo el disco libre y la velocidad de red (↓ ↑).
- [ ] Abrir el popup: cinco gráficas que avanzan con cada lectura, con el valor actual y su unidad, y los cinco procesos más activos. Con `yes > /dev/null &` en marcha aparece arriba con ~100 % de CPU en pocos segundos.
- [ ] **Terminar** en `yes`: desaparece de la lista en la lectura siguiente. Con el proceso que ignora SIGTERM: **Terminar** lo deja y el botón pasa a **Forzar cierre**; al pulsarlo pide «¿Seguro?» con una ✕ para cancelar (cancelar no mata nada); confirmar lo mata y se va. Ningún proceso muere sin un clic.
- [ ] Un proceso de otro usuario (por ejemplo `systemd` de root): **Terminar** dice «No tienes permiso para terminar ese proceso.». `vitrail`… `python3 -m vitrail.resources kill 1` devuelve `{"error":"refused"}` y no hace nada.
- [ ] En una máquina sin zona térmica (`ls /sys/class/thermal` vacío, o una VM): la barra y el tooltip no mencionan la temperatura y en el popup la gráfica de temperatura es una línea «No se encontró ningún sensor de temperatura…»; las demás gráficas siguen.
- [ ] El intervalo de Ajustes (1–10 s) cambia el ritmo de la gráfica; *Unidades* en binario o decimal cambia KiB↔kB en memoria, disco y red.
- [ ] Con el elemento fuera de la barra no hay ningún proceso `python3 -m vitrail.resources` en `ps` (ni siquiera cada segundo); con él puesto y el popup cerrado hay uno cada intervalo, nunca dos a la vez.
- [ ] El engranaje del popup abre Ajustes → Bar elements ya desplazado al bloque «Resources».

## Network usage bar element (2026-11-22)

Código en `bar-netusage-ui`. Para una descarga de verdad: `curl -o /dev/null https://speed.cloudflare.com/__down?bytes=200000000` (o cualquier archivo grande), y para una subida, `dd if=/dev/zero bs=1M count=200 | curl -T - -o /dev/null https://speed.cloudflare.com/__up`.

- [ ] Mostrar `netusage` desde el editor de la barra (está oculto por defecto): dos líneas cortas, ↓ y ↑, que se mueven con el tráfico; en una barra vertical caben sin desbordar.
- [ ] En Ajustes → Bar elements → Network usage, *En la barra* cambia entre las dos líneas, solo la bajada y solo la subida, y cada opción se aplica al momento. *Unidades* en binario cambia kB↔KiB en las velocidades y en los totales de hoy.
- [ ] Durante la descarga real la línea ↓ sube en la barra y su curva en el popup; al terminar, la gráfica baja sola. El eje es el mismo para las dos direcciones (una subida grande también lo estira) y nunca hay una línea plana pegada al borde.
- [ ] El tooltip dice «↓ x/s ↑ y/s» y debajo «Hoy: x recibidos · y enviados». Con el popup abierto, esas cifras son las mismas que las dos filas del popup.
- [ ] **Cambio de día**: dejar el portátil dormido pasada la medianoche (o en una VM, `sudo date -s` al día siguiente y volver a la hora real): la primera lectura del día nuevo pone «Hoy» en 0 B, no en el total de ayer ni en un número negativo, y sigue contando desde ahí. Un salto de varios días hace lo mismo.
- [ ] **Reinicio**: reiniciar el equipo el mismo día; los contadores del kernel vuelven a cero y «Hoy» tampoco resta (empieza de nuevo en esa dirección). El archivo `~/.cache/vitrail/netusage.json` guarda `{"date": "AAAA-MM-DD", "rx": …, "tx": …}`.
- [ ] Sin ninguna interfaz de red (o con el sampler recién arrancado, sin contadores): la barra muestra «--» (nunca 0) y el popup una línea tranquila; la barra no se rompe. Una red inactiva sí muestra 0 B/s.
- [ ] Con `netusage` y `resources` en la barra a la vez, `ps` muestra **un** `python3 -m vitrail.resources state --tick` por intervalo, nunca dos en paralelo ni un proceso propio del elemento de red; con ninguno de los dos, ninguno.
- [ ] El engranaje del popup abre Ajustes → Bar elements ya desplazado al bloque «Network usage».

## System health bar element (2026-11-22)

Código en `bar-health-ui`. Para provocar los problemas sin romper nada, y deshacerlos:

```sh
# Un servicio de usuario fallido
systemd-run --user --unit=vitrail-health-test /bin/false
# deshacer
systemctl --user reset-failed vitrail-health-test.service

# Un disco lleno (imagen ext4 de 64 MB en un loop, casi llena)
truncate -s 64M /tmp/health.img && mkfs.ext4 -q /tmp/health.img
sudo mkdir -p /mnt/health && sudo mount -o loop /tmp/health.img /mnt/health
sudo fallocate -l 60M /mnt/health/fill
# deshacer
sudo umount /mnt/health && rm /tmp/health.img && sudo rmdir /mnt/health
```

- [ ] Mostrar `health` desde el editor de la barra (está oculto por defecto): en una máquina sana el botón no se ve (modo "Solo cuando está activo"); con "Siempre" aparece el icono tranquilo y el tooltip dice «Todo está bien».
- [ ] Lanzar el servicio fallido: en menos de un minuto (o al abrir el popup) aparece el icono de aviso; el tooltip dice «El servicio vitrail-health-test.service ha fallado». Con un solo problema no hay número.
- [ ] El popup tiene una fila para ese servicio con su punto de severidad, el título, el detalle, **Registros** y **Arreglar**. **Registros** abre una terminal kitty con `journalctl --user -u vitrail-health-test.service`; **Arreglar** abre kitty con `systemctl --user restart …` (vuelve a fallar: sigue en la lista). Nada se ejecuta sin que se abra la terminal.
- [ ] Montar la imagen casi llena: aparece una fila «Poco espacio en disco en /mnt/health» con el porcentaje libre y los tamaños, sin botones; el botón pasa a mostrar «2». Subir el umbral a 50 % en Ajustes → Bar elements → System health hace aparecer también `/`; bajarlo a 1 % quita la imagen casi llena si tiene más de 1 % libre.
- [ ] Desactivar «Espacio en disco» en los ajustes quita sus filas en cuanto se refresca; desactivar los cuatro deja la barra sin icono aunque haya servicios fallidos, y el popup dice «Todo está bien».
- [ ] Deshacer los dos casos: el icono desaparece en el siguiente ciclo (o al pulsar el botón de refrescar del popup) y el popup muestra la línea tranquila, no una tarjeta vacía.
- [ ] Opcional: escribir un error en `~/.config/hypr/` y `hyprctl reload`: aparece «Errores en la configuración de Hyprland» con el texto de `hyprctl configerrors` y un botón **Arreglar** (`hyprctl reload`) y otro **Registros** (`hyprctl configerrors`); revertir el cambio y recargar lo quita.
- [ ] Un servicio del sistema fallido (`sudo systemd-run --unit=vitrail-health-test /bin/false`, deshacer con `sudo systemctl reset-failed vitrail-health-test.service`) sale con el tono de error (el icono cambia de color frente al aviso).
- [ ] El engranaje del popup abre Ajustes → Bar elements ya desplazado al bloque «System health».
- [ ] Con el elemento fuera de la barra no hay ningún proceso `python3 -m vitrail.health` en `ps`.
- [ ] Un elemento de la barra que no cargue (no se puede provocar sin tocar el código: un error de compilación aborta toda la barra; solo se detecta el fallo al crear el componente) aparecería como «Un elemento de la barra no se pudo cargar», con los ids en el detalle; la señal está cubierta por `tests/qml/tst_bar_entry.qml`.

## Privacy bar element (2026-11-22)

Código en `bar-privacy-ui`. Para capturar a propósito (sin aplicaciones de terceros) y deshacerlo:

```sh
# Micrófono: una captura de audio de 60 s (Ctrl+C la termina)
pw-record --media-category Capture /tmp/privacy-mic.wav
# Cámara: cualquier lector de la cámara, p. ej.
ffplay -f v4l2 /dev/video0        # o: pw-v4l2 ffplay /dev/video0
# Pantalla: compartirla desde un navegador (getDisplayMedia) o con OBS (fuente «Captura de pantalla (PipeWire)»)
# deshacer: Ctrl+C en cada comando, y rm /tmp/privacy-mic.wav
```

- [ ] Mostrar `privacy` desde el editor de la barra (oculto por defecto): sin ninguna captura el botón no se ve (modo "Solo cuando está activo"); con "Siempre" aparece un escudo apagado y el tooltip dice «Nada está usando el micrófono, la cámara ni la pantalla».
- [ ] Lanzar `pw-record`: en un par de segundos aparece un punto del color elegido; el tooltip dice «En uso: Micrófono» y debajo «pw-record».
- [ ] El popup tiene un bloque «Micrófono · En uso» con una fila «pw-record» y su flujo, y un botón **Cortar**; no aparecen bloques de cámara ni de pantalla vacíos, y en ningún sitio dice «grabando».
- [ ] **Cortar**: el flujo de `pw-record` se destruye (el proceso termina o se queda sin audio), el punto desaparece en el siguiente ciclo y el popup muestra la línea tranquila. La aplicación no se mata.
- [ ] Lanzar la captura y terminarla con Ctrl+C: el punto **desaparece** solo, sin tocar nada (y con el modo "Siempre" vuelve el escudo).
- [ ] Un reproductor (`pw-play`, un vídeo) y un medidor de volumen **no** encienden el punto; un navegador con la cámara solo presente (sin abrirla) tampoco.
- [ ] Cámara: el punto aparece mientras `ffplay` la tiene abierta y el bloque dice «Cámara». Compartir pantalla: el bloque dice «Pantalla compartida» (no «Cámara»).
- [ ] Ajustes → Bar elements → Privacy: apagar «Vigilar el micrófono» y lanzar `pw-record` no enciende el punto ni muestra el bloque; apagar los tres deja la barra sin punto aunque haya capturas.
- [ ] El selector «Color del punto» cambia el punto a rojo, acento o azul de la paleta al momento, y respeta el tema claro y el oscuro.
- [ ] Con un solo proceso `pw-record` y dos aplicaciones más, el tooltip nombra las dos primeras y «y N más».
- [ ] Sin PipeWire (`systemctl --user stop pipewire pipewire-pulse wireplumber`; volver a arrancarlos después) el popup dice la línea tranquila «No se puede leer PipeWire…» y el botón no muestra ningún punto.
- [ ] El engranaje del popup abre Ajustes → Bar elements ya desplazado al bloque «Privacy».
- [ ] Con el elemento fuera de la barra no hay ningún proceso `python3 -m vitrail.privacy` ni `pw-dump` en `ps`.

## Weather bar element (2026-11-22)

Código en `bar-weather-ui`. Con la barra corriendo:

- [ ] Mostrar `weather` desde el editor de la barra (está oculto por defecto): aparece el glifo de la condición y la temperatura redondeada con su unidad ("18 °C"); el tooltip dice «Madrid · Parcialmente nublado» y debajo «Máx 21° · Mín 10°».
- [ ] Clic abre el popup: la lectura actual (condición, temperatura, máxima/mínima y viento cuando lo hay), la tira de las próximas doce horas y las cinco filas de los próximos días; el engranaje abre Ajustes → Bar elements ya desplazado al bloque «Weather».
- [ ] Ajustes → Bar elements → Weather: añadir «Valencia» a las ciudades la ofrece en el selector del popup; elegirla escribe `weatherLocation=Valencia` en `weather.ini`, el snapshot se refresca y el tooltip y la temperatura pasan a Valencia. Quitarla de la lista la quita del selector sin cambiar la ciudad actual.
- [ ] Cambiar «Unidades» de métrico a imperial cambia la misma lectura a °F y el viento a mph en el siguiente snapshot (sin esperar al intervalo); volver a métrico la devuelve a °C y km/h.
- [ ] Sin red con caché tibia (desconectar la red después de un snapshot bueno y esperar a que caduque el caché de 15 min): el botón sigue mostrando la última temperatura y el popup añade una línea tranquila «No se pudo actualizar el último pronóstico: …» sin perder horas ni días.
- [ ] Ciudad desconocida (añadir «Atlantis» a las ciudades, elegirla): el popup muestra una línea tranquila con el motivo, no una traza ni una tarjeta vacía; con caché de otra ciudad mantiene la última lectura, y sin caché el botón desaparece en «Solo cuando está activo».
- [ ] Apagar y encender el elemento con «Solo cuando está activo»: sin temperatura no ocupa sitio en la barra y con un snapshot bueno vuelve; con «Siempre» queda el glifo de nube.
- [ ] `weatherInterval` (15 min por defecto) cambia cada cuánto corre `python3 -m vitrail.weather state`; con el elemento fuera de la barra y el night light apagado no hay ningún proceso del módulo en `ps`.
## Market bar element (2026-11-22)

Código en `bar-market-ui`. Con la barra corriendo y conexión a internet:

- [ ] Mostrar `market` desde el editor de la barra (oculto por defecto): aparece el precio de Bitcoin en euros y un icono de tendencia; el tooltip dice el símbolo y su cambio del día («BTC +1.37%») y debajo el resto de símbolos elegidos.
- [ ] Clic abre el popup: una fila por símbolo con su nombre, su precio, la flecha y el porcentaje del día coloreados por el signo y su minigráfica; el botón de refrescar lleva al lado la edad («actualizado ahora mismo» o «actualizado hace 3 min»).
- [ ] La línea pequeña «Precios de CoinGecko por internet» está al pie del popup. Ningún texto dice comprar ni vender.
- [ ] Cambiar la moneda a USD en el popup (o en Ajustes → Bar elements → Markets): los precios cambian a dólares y la edad vuelve a «ahora mismo»; volver a EUR los devuelve.
- [ ] En Ajustes → Bar elements → Markets, añadir `ethereum` a la lista: aparece una segunda fila en el popup, con otra minigráfica, y el tooltip del botón la nombra debajo del primer símbolo.
- [ ] Escribir un id que no existe (por ejemplo `no-existe`) y añadirlo: su fila dice «Sin precio» (no desaparece en silencio); si es el único símbolo, el popup muestra una línea tranquila y el botón queda sin precio.
- [ ] Con caché caliente, desconectar la red y esperar a que caduque (5 min): el botón conserva el último precio, el popup dice «en caché · actualizado hace X min» y muestra una línea tranquila con el error; el elemento sigue visible.
- [ ] Sin red y sin caché (`rm ~/.cache/vitrail/market.json`), con «Solo cuando está activo» el botón desaparece; con «Siempre» queda el icono y el tooltip dice que no hay datos de mercado.
- [ ] El intervalo mínimo es 5 minutos (el del caché del módulo); el valor por defecto es 15. Abrir el popup o pulsar refrescar dentro de esos 5 minutos no lanza una petición nueva a CoinGecko.
- [ ] El engranaje del popup abre Ajustes → Bar elements ya desplazado al bloque «Markets».
- [ ] Con el elemento fuera de la barra no hay ningún proceso `python3 -m vitrail.market` en `ps`.

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
