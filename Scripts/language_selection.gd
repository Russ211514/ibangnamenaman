extends Control

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _on_html_pressed() -> void:
	get_tree().change_scene_to_file("res://Html Scenes/html_level_selector.tscn")

func _on_java_pressed() -> void:
	get_tree().change_scene_to_file("res://Java Scenes/java level selector.tscn")

func _on_python_pressed() -> void:
	get_tree().change_scene_to_file("res://Python Scenes/python_level_selector.tscn")
