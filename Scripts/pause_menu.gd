extends Control
 
@onready var main = $"../../"

func _on_resume_pressed() -> void:
	main.PauseMenu()

func _on_leave_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/offline selection.tscn")
