# Finny the Dragon — proyecto actualizado

Base: `Finny_Actualizado_Niveles_1_y_2.zip` (versión con cooperativo), derivada de `Finnys Dragons(1).zip`, con sus personajes, cofres, música y las tres zonas de la cueva. El proyecto se probó con Godot 4.5.1, renderer Compatibility.

## Cómo abrirlo

1. Descomprime el ZIP en una **carpeta nueva**.
2. Importa su `project.godot` en Godot y espera a que termine de importar los recursos.
3. Ejecuta el proyecto completo con F5 desde el editor. La escena principal es `scenes/main.tscn`.
4. Pulsa **New Game** para la campaña, **Continue** para cargarla o **Multiplayer Mode** para jugar entre dos en el mismo teclado. En campaña, tras pagar 1.200 al Rey y terminar el día 3, se desbloquea el nivel 2.

No hace falta reemplazar scripts individualmente ni reasignar escenas. Conserva tu versión anterior mientras pruebas esta copia. Se entrega código fuente y recursos, no un ejecutable de Windows. No se modificó ningún repositorio remoto.

## Controles

| Control | Acción |
| --- | --- |
| WASD / flechas | Mover a Finny sobre el suelo |
| E junto a un cliente que espera | Hacer el show y cobrar |
| R mirando al enemigo | Atacar |
| E a la izquierda de la sala, al cerrar | Entrar al pasillo |
| E a la izquierda del pasillo | Entrar al cuarto |
| E a la derecha del pasillo | Volver a la sala |
| E a la izquierda del cuarto | Volver al pasillo |
| E junto a un cofre | Depositar el dinero de la billetera |
| E junto a la cama | Libreta nocturna y descanso |
| B / Ledger | Dinero, expansión, empleados y préstamos |
| F5 / Save, dentro del juego | Guardar |
| Esc / Backspace / Pause | Pausa, guardado y regreso al menú |
| F11 | Pantalla completa |

## Correcciones y mejoras

- Puertas con interacción E repetible, sin bloqueo de controles. El pasillo abre cuando terminan los clientes del día.
- Fondo del pasillo completamente interior, sin la entrada exterior. Se conserva el cuarto de la versión recibida.
- Finny y los clientes entran por la puerta de la ilustración. Los dos goblins acompañan al ogro y regresan por esa misma entrada.
- Origen de los personajes en sus pies, colisiones pequeñas y movimiento restringido al suelo. Es un juego 2D desde arriba: no necesita gravedad de plataformas.
- Ogro con tres segundos de paciencia; los goblins solo se vuelven hostiles con él. Finny puede atacar y recibe daño.
- Resolución base 1152×648, escalado proporcional, cámara limitada a cada zona y fondos que cubren la ventana.
- Menú inspirado en la referencia de cristales: título verde pixel, Finny respirando, moneda que gira y flota, botones New Game / Continue / Multiplayer Mode / Quit.
- Textos visibles, botones y diálogos del juego en inglés.
- Música original conservada; se incluye una copia OGG importable y exportable por Godot.
- Nivel 2 completo: días 4–7, expansión, préstamos, crédito, fraude, sueldos, Héroe Real, reparación y finales.

## Guardado

Continue se habilita cuando existe una partida compatible. Hay guardado automático al empezar el día y al comenzar la noche, además de F5, Save y Pause → Save Game.

Se conservan nivel, día, habitación, posición, salud, dinero, clientes y goblins activos, paciencia, estados de combate, préstamos, crédito pendiente, empleados, mejoras y decisiones. No se vuelve al inicio del día ni se cobra dos veces un show.

Termina un show, una animación de depósito o un evento narrativo antes de guardar. La pausa indica cuándo debes esperar: así no se registra una transacción a medias.

Se escribe primero un archivo temporal y se conserva una copia de respaldo. Si el guardado principal está dañado, se intenta recuperar el anterior. Archivos: `user://campaign_v3.cfg` y `.bak`, en la carpeta de datos de Godot del usuario bajo `Finny_Boss_Fight_Campaign`. En Windows suele ser `%APPDATA%/Finny_Boss_Fight_Campaign/`. Esta versión no mezcla sus guardados con los anteriores.

## Nivel 2 y decisiones de implementación

| Elemento | Implementación |
| --- | --- |
| Días | 4, 5, 6 y 7; noche, pasillo, cuarto, libreta y descanso |
| Clientes programados | 6 / 7 / 7 / 8; rechazar ventas o cerrar por una emergencia reduce los atendidos |
| Show | Precio 200, suministros 50 |
| Segundo escenario | Cuesta 600 y añade 120 al precio del show; ampliación visible, conserva la fila de clientes existente |
| Empleados | Hasta dos goblins; cada uno añade 60 por show y cobra 120 por noche |
| Banco de Duendes | 800 al día siguiente; devolver 880 en total |
| Troll | 800 inmediatamente; devolver 1.600 en total |
| Caballero fiado | Paga a la mañana siguiente; límite de dos cobros pendientes y advertencia el último día |
| Moneda falsa | Días 5 y 7: revisar antes del show o perder ingresos por aceptar chocolate |
| Héroe Real | Día 6: 150 de vida, Finny puede detenerlo; si golpea el escenario, lo destruye |
| Reparación | Pagar 400 para reabrir o reconstruir por la noche y perder los clientes de ese día |
| Sueldos | Si falta dinero, los empleados renuncian |
| Cofre del Rey | Retirar dinero aplica multa del 20% |
| Victoria | Pagar 5.000 al Rey y saldar el préstamo antes de terminar el día 7 |
| Derrota | Finny derrotado, pago real incompleto o préstamo sin devolver; resumen, consejo y Retry |

**Cifra de la historia:** el documento menciona una deuda inicial de 5.000, un pago de 1.200 en el nivel 1 y también 4.700 pendientes. Estas cifras son incompatibles. Se mantiene el total de **5.000**, por lo que después de pagar 1.200 faltan **3.800**. Las cantidades pueden cambiarse en `scripts/economy.gd`.

Los importes concretos de préstamos, expansión, salarios y reparaciones son decisiones de balance donde el documento no fijaba números. Se conservó el balance original del nivel 1 para no alterar su lógica existente.

El Héroe Real reutiliza el esqueleto con un tono dorado; los empleados reutilizan los sprites de goblin. No se recibió un sprite exclusivo para el héroe.

## Pruebas

Se comprobaron la campaña de siete días, la transición conservando dinero, los eventos económicos, combate, guardado/carga, recorrido entre zonas, los botones del menú y el escalado. Se revisaron imágenes renderizadas a 1152×648, 1920×1080, formato ancho y 4:3. Las pruebas fueron en Linux con Godot 4.5.1; no se hizo una compilación nativa de Windows.

El cierre forzado desde el editor puede mostrar una advertencia de audio propia de Godot. El cierre normal con Quit deja que el mezclador libere el audio. La carpeta `.godot` se regenera al importar y no viene en el ZIP.

## Nuevo modo cooperativo local

En el menú, elige **Multiplayer Mode** y luego **Start the Raid**. Se juega entre dos personas en el mismo teclado y en una sola pantalla. No requiere conexión a Internet ni cambia el guardado de la campaña; **Continue** sigue cargando los niveles 1 y 2.

| Jugador | Movimiento | Ataque | Esquivar |
| --- | --- | --- | --- |
| P1: Finny verde | WASD | R | Q |
| P2: Finny azul | Flechas | Enter (también Enter numérico) | Shift |

Mueve a Finny hacia el enemigo para apuntar. Puedes mantener pulsado ataque para repetir los golpes. Los ataques cubren un arco delante del personaje y no dañan al compañero. Esquivar permite atravesar un golpe durante 0,18 segundos y tiene 1,2 segundos de recuperación.

**Esc / Pause** pausa a ambos jugadores; permite continuar, reiniciar el combate o volver al menú. **F11** cambia a pantalla completa. Los controles permanecen visibles durante el combate.

| Oleada | Enemigos |
| --- | --- |
| 1: The First Raid | 2 ogros + 6 goblins = 8 |
| 2: Goblin Horde | 1 ogro + 13 goblins = 14 |
| 3: Iron Raid | 4 ogros + 12 goblins = 16 |
| 4: Cave Siege | 5 ogros + 15 goblins = 20 |
| 5: The Ogre Warlord | 1 jefe + 4 ogros + 17 goblins = 22 |

Ambos jugadores tienen 100 HP, indicadores P1/P2 y barras independientes. El segundo Finny es azul mediante un shader que conserva ojos, cuernos y barriga. Cada ataque de Finny hace 30 de daño. Los goblins escalan de 80 a 120 HP, de 10 a 14 de daño y de 145 a 165 de velocidad. Los ogros normales escalan de 220 a 300 HP, de 22 a 30 de daño y de 95 a 111 de velocidad. También se reducen progresivamente la preparación y recuperación de sus ataques. El jefe tiene **1.600 HP y hace 44 de daño**, es más grande y tiene su barra superior. Son 80 enemigos en total.

Los enemigos persiguen al jugador vivo más cercano. Antes de golpear muestran un círculo rojo en el suelo: sal de ese círculo o esquiva. El golpe cae en el lugar marcado; no sigue al jugador durante la preparación.

Si cae un jugador, el otro continúa. Entre oleadas hay cinco segundos de descanso; el superviviente recupera 30 HP y su compañero revive con 60 HP. Si caen ambos, aparece **Team Defeated**. Al eliminar al jefe y todos sus escoltas aparece **Cave Defenders!**. Se puede reintentar desde la oleada 1 con ambos jugadores al 100%.

El modo cooperativo es una partida de arena de cinco oleadas: se reinicia al salir y no usa el guardado económico de la campaña. Los valores de balance se encuentran en `scripts/arena_player.gd`, `scripts/arena_enemy.gd` y `scripts/multiplayer_arena.gd`. La escena es `scenes/multiplayer_arena.tscn` y se abre desde el menú principal.

### Verificación de esta actualización

Pruebas automatizadas en Godot 4.5.1: controles físicos separados y simultáneos, animación y daño de ambos jugadores, ausencia de fuego amigo, daño enemigo, esquiva, cambio de objetivo tras una muerte, las cinco oleadas, recuperación, pausa, derrota, victoria, reinicio y vuelta al menú. Se comprobó que el archivo de guardado de campaña conserva exactamente sus bytes y que Continue vuelve a cargarlo. También pasó la campaña completa de siete días. Revisión visual con renderizado a 1152×648, 1920×1080, 1024×768 y formato ancho. No se ha probado una exportación nativa de Windows.

## Intro de historia y sonidos — actualización de octubre de 2026

**New Game** reproduce cuatro viñetas animadas con texto en inglés antes del nivel 1. Duran aproximadamente **42 segundos** en total si no pulsas nada (9 / 11 / 9 / 11 segundos de lectura más transiciones). Se mantienen completas las tres ilustraciones adjuntas, incluidos sus bocadillos, y se añade una cuarta para la idea de cobrar por las peleas y la llegada del goblin.

- **Espacio / Enter / Next**: avanzar una viñeta; en la última, comenzar a jugar.
- **Esc / Skip Story**: saltar toda la historia, incluso durante una transición.
- **Continue** carga directamente tu partida. **Multiplayer Mode** abre la arena sin reproducir la intro.
- No hay vídeo externo ni conexión necesaria: el movimiento suave, zoom y fundidos se hacen con Tweens de Godot.

Los seis efectos originales se incluyen como WAV PCM de 44,1 kHz en `assets/sfx/`: monedas, cofre, decepción, llegada del Rey, idea y fuego. Los sonidos de la historia se sincronizan con cada capítulo y se detienen al saltarlo. El fuego suena una vez en el fotograma del ataque de Finny, tanto en campaña como con P1 y P2 a la vez. No se duplica durante un show de pago. La música original sigue incluida.

`tools/generate_sfx.py` permite regenerar los WAV con Python 3 sin librerías adicionales; **no es necesario ejecutarlo para jugar**. `scripts/sound_fx.gd` es el autoload que maneja las voces de audio. `scripts/intro_story.gd` contiene el guion, imágenes y duración de cada viñeta; `scenes/intro_story.tscn` se conecta al menú desde `scripts/main.gd`.

Se verificaron reproducción automática (41,83 segundos), avance manual, pulsaciones rápidas, salto durante un fundido, carga del nivel 1, sonidos independientes de ambos jugadores, cinco oleadas y victoria solo después de la quinta. También se repitieron las pruebas de combate y campaña completa con guardado/carga. Los WAV tienen encabezados válidos, no están vacíos ni saturados. La intro se revisó renderizada en 16:9, 4:3 y formato ancho con Godot 4.5.1 Compatibility en Linux.
