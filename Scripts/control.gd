extends Control

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Selection Scene.tscn")

func _on_html_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/menu_&_server.tscn")
