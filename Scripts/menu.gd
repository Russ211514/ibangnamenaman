extends Control

@onready var buttons: VBoxContainer = $Buttons
@onready var options_menu: Panel = $"Options menu"

func _ready() -> void:
	buttons.visible = true
	options_menu.visible = false

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_options_pressed() -> void:
	buttons.visible = false
	options_menu.visible = true

func _on_x_button_pressed() -> void:
	_ready()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Selection Scene.tscn")

func _on_offline_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Language Selection.tscn")
