extends Control

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var question: Label = $CanvasLayer/Question
@onready var next: Button = $CanvasLayer/Next

func _ready() -> void:
	canvas_layer.visible = false
	if $Control:
		$Control.visible = true
	question.visible = true
	next.visible = true

func _on_next_pressed() -> void:
	get_tree().change_scene_to_file("res://Html Scenes/final_mastery_test_quiz_topic2_level2.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Html Scenes/html_level_selector.tscn")


func _on_yes_pressed() -> void:
	canvas_layer.visible = true
	$Control.visible = false

func _on_no_pressed() -> void:
	get_tree().change_scene_to_file("res://Html Scenes/html_level_selector.tscn")
