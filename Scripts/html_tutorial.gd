extends Control

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/html tutorial start.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Language Selection.tscn")
