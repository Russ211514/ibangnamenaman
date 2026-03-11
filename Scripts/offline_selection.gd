extends Control

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Selection Scene.tscn")

func _on_python_pressed() -> void:
	get_tree().change_scene_to_file("res://Python Scenes/python_difficulty_selection.tscn")

func _on_html_pressed() -> void:
	get_tree().change_scene_to_file("res://Html Scenes/Singleplayer/difficulty_selection.tscn")

func _on_java_pressed() -> void:
	get_tree().change_scene_to_file("res://Java Scenes/java_difficulty_selection.tscn")
