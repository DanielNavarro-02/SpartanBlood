# Spartan Blood — actualización (modelos, combate, Rhaxos, herrero, botas, mapa)

## Cómo abrirlo
Abre la carpeta en Godot 4.x. La primera vez importará los 6 FBX (carpeta `modelos/`). Si Godot muestra
errores de "class_name" no encontrado, usa *Proyecto > Recargar proyecto actual*.
Acciones nuevas en el Mapa de Entrada: `interactuar` (E) y `mapa` (M). Autoload nuevo: `Juego` (juego.gd).

## Controles
Mover A/D · Saltar Espacio · Atacar clic izq. · Dash clic der. (solo con las Botas) · Curar Q · Hablar E · Mapa M

## Combate (personaje.gd)
- Combo de 3 golpes: tajo → tajo ascendente → remate pesado (2 de daño, más retroceso). Golpe aéreo al atacar saltando.
- Buffer de 0.22 s, cancelación al encadenar, pequeño avance en cada golpe, ventana activa por golpe (tabla ATAQUES al inicio del script).
- Impactos con hit-stop, sacudida de cámara, chispas, números de daño y retroceso.
- Recibir daño: aturdimiento, retroceso, parpadeo; el dash da invulnerabilidad. Muerte animada y reinicio (los objetos
  conseguidos se conservan entre muertes).
## Enemigos
- Esqueleto gladiador (gladiador.gd): telegrafía el golpe (levanta la espada y brilla en rojo), se aturde al ser golpeado,
  huye 3 s con poca vida y vuelve, no te ve hasta 16 m (`radio_deteccion`). Ahora hay 3 en la arena.
- Rhaxos (rhaxos.gd): 40 de vida, 2 fases. Raíces (púas con marcas rojas), onda de suelo (se salta), lluvia de frutos.
  Barra de vida abajo. Al morir suelta las Botas de Hermes.
## Objetos y NPC
- Botas de Hermes (botas_hermes.gd): desbloquean el dash. Sin ellas, el clic derecho avisa.
- Herrero (npc_herrero.gd) en el campamento: [E] abre la tienda; mapa a 10 óbolos (`precio_mapa`). Con M se abre el mapa
  (dibujado desde el GridMap real, con zonas, herrero, Rhaxos y tu posición).
## Animaciones
Los FBX no traen huesos, así que `rig/rig_segmentado.gd` los anima por piezas leyendo `rig/datos/*.json`
(poses clave y osciladores). Para retocar una animación edita el JSON del personaje.
Si algún personaje saliera mirando al revés o con tamaño raro, ajusta `"altura"` en su JSON.

## Archivos viejos sin usar
`personaje/Untitled.glb` y `character-male-d.glb` ya no se usan en main.tscn. Se corrigió `celda_camara.gd` (decía "xtends").
