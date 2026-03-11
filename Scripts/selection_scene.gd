extends Control

func _on_singleplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/offline selection.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _on_pvp_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/pvp language selection.tscn")
