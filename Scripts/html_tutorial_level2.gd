extends Control

func _on_next_pressed() -> void:
	get_tree().change_scene_to_file("res://Html Scenes/html_start_level2.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Html Scenes/html_level_selector.tscn")
