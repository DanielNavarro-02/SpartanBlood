
extends Node

signal vida_cambiada(actual, maxima)
signal sangre_cambiada(actual, maxima)
signal obolos_cambiados(actual)
signal jugador_muerto

@export var vida_maxima: int = 3
@export var invulnerable: float = 1.0

@export var sangre_maxima: int = 2
@export var obolos: int = 0

var vida: int
var sangre: int
var reloj: float = 0.0
var muerto: bool = false


func _ready():
	vida = vida_maxima
	sangre = sangre_maxima
	
	vida_cambiada.emit(vida, vida_maxima)
	sangre_cambiada.emit(sangre, sangre_maxima)
	obolos_cambiados.emit(obolos)


func _physics_process(delta):
	reloj = maxf(reloj - delta, 0.0)
	
func agregar_sangre(cantidad: int):
	sangre = mini(sangre + cantidad, sangre_maxima)
	sangre_cambiada.emit(sangre, sangre_maxima)

	print("Sangre recuperada: ", sangre)

# RECIBIR DAÑO
func recibir_golpe(danio: int) -> bool:
	if reloj > 0.001 or muerto:
		return false
	
	vida = maxi(vida - danio, 0)
	reloj = invulnerable
	
	vida_cambiada.emit(vida, vida_maxima)
	print("Vida del jugador: ", vida)
	
	if vida == 0:
		muerto = true
		jugador_muerto.emit()
		print("El jugador perdió")
	return true


# CURARSE
func curarse():
	if muerto:
		return false
	
	if sangre <= 0:
		print("No tienes sangre")
		return false
	
	if vida >= vida_maxima:
		print("Ya tienes la vida completa")
		return false
	
	sangre -= 1
	vida = mini(vida + 1, vida_maxima)
	
	sangre_cambiada.emit(sangre, sangre_maxima)
	vida_cambiada.emit(vida, vida_maxima)
	
	print("Te has curado. Vida: ", vida)
	print("Sangre restante: ", sangre)
	
	return true


# CONSEGUIR ÓBOLOS
func agregar_obolos(cantidad: int):
	obolos += cantidad
	obolos_cambiados.emit(obolos)
	print("Óbolos: ", obolos)


# GASTAR ÓBOLOS
func gastar_obolos(cantidad: int):
	if cantidad <= 0 or obolos < cantidad:
		return false
	
	obolos -= cantidad
	obolos_cambiados.emit(obolos)
	return true
