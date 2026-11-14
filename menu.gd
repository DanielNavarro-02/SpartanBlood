extends Control

@onready var boton_jugar = $VBoxContainer/Play

func _ready():
	boton_jugar.grab_focus()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _on_salir_pressed() -> void:
	get_tree().quit()
